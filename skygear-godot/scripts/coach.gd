class_name SkyGearCoach
extends RefCounted

## One line, when it will change what you do next.
##
## The game has a single idea that is not visible from the controls — the gauge
## fills from damage landed inside 210 units, so the safe play is the losing play
## — and the HOW TO PLAY page now says so. But a page you read once at the title
## is not where a player learns; a player learns in the third wave, while making
## the mistake. This watches for the four mistakes that actually end runs and
## says one short thing about the one they are making now.
##
## THE HARD PART IS SHUTTING UP. A coach that fires whenever a condition holds is
## a coach that reads as noise inside a minute, and noise is worse than silence
## because it teaches the player to ignore the place hints appear — which is the
## same strip the Boiler warnings use. Four rules, and they are the whole design:
##
##   1. ONE at a time, highest priority, never a queue. A player mid-wave reads
##      one line or none.
##   2. Every hint has to be EARNED over seconds, not caught on a frame. Kiting
##      for one second is repositioning; kiting for twelve is a strategy.
##   3. Each hint fires at most twice a run, with a long gap. If it did not land
##      the second time it is not going to.
##   4. Nothing fires in the first wave. The first wave is where you find the
##      keys, and being corrected while you do that is insulting.
##
## Read-only: it is handed the game each frame and returns a string. It cannot
## change the simulation, which means a bad hint is a wrong sentence rather than
## a wrong game.

## How long a mistake has to persist before it is a mistake.
const DWELL := {
	"kiting": 11.0,      ## long, because backing off IS correct sometimes
	"gauge": 8.0,        ## sitting on a full gauge with nothing to vent into
	"lane": 6.0,         ## a lane unattended while it is being walked down
	"idle_skill": 9.0,   ## a drafted weapon you have never pressed
	## Short, because this one is not a mistake being earned — it is a fact the
	## player has no other way to learn. Long enough that a gun dying in the last
	## second of a wave does not fire it at the draft screen.
	"broken_cannon": 3.5,
	## His, and short for the same reason `broken_cannon` is: it is not a mistake
	## being earned, it is a fact with no other way in. Long enough that walking
	## between two vents does not trip it.
	"empty_bank": 7.0,
	## The draggable crate is a verb with no on-screen tell, like the downed cannon.
	## Same dwell as `lane`: a lane has to be genuinely walking through before the
	## shaping tool is worth pointing at.
	"shape_lane": 6.0,
}
const MAX_SHOWS := 2
const REPEAT_GAP := 42.0
const HOLD := 4.5        ## how long a hint stays up once it fires
const FIRST_WAVE := 2    ## nothing before this

## Priority order. The first one whose condition holds is the one shown, so this
## list IS the editorial judgement about which mistake costs the most.
## `broken_cannon` leads. Every other line here corrects a mistake the player is
## already making and could in principle notice; this one announces a VERB THAT
## IS OTHERWISE INVISIBLE. Nothing on screen says a dead gun can come back, so
## without it the whole deckwork system is code no player ever runs.
const ORDER := ["broken_cannon", "empty_bank", "gauge", "kiting", "shape_lane", "lane", "idle_skill"]

const TEXT := {
	"kiting": "You have been at range a while — the gauge only fills inside 210 units.",
	"gauge": "Gauge is full. Get among them: it vents by itself and heals you for it.",
	## HIS. The reported confusion, in one line, at the moment it is costing him:
	## an empty bank is not a neutral state, it is a 45% damage cut, and nothing
	## in the game said so.
	"empty_bank": "Head is empty, so every weapon is hitting soft. Stand on a vent or crack a main with F.",
	"lane": "A lane is walking through. The cannon holds, it does not kill.",
	## The shaping verb, announced because nothing on screen says a crate can be
	## heaved to funnel a lane. `{key}` is the live binding, like `broken_cannon`.
	"shape_lane": "A lane is walking through. Stand at the crate and HOLD {key} to heave it across and funnel them.",
	"idle_skill": "You have a weapon you have never fired. Q and E are drafted too.",
	## `{key}` is filled from the live binding rather than written in, so a player
	## who rebinds the key is not told to press the one they replaced.
	"broken_cannon": "A cannon is down. Stand at it and HOLD {key} to bring it back.",
}

var _dwell := {}
var _shown := {}
var _last_at := {}
var _current := ""
var _current_until := -1.0


func reset() -> void:
	_dwell.clear()
	_shown.clear()
	_last_at.clear()
	_current = ""
	_current_until = -1.0


## Returns the line to draw, or "". Call every frame while playing.
func advise(game, delta: float) -> String:
	if game == null or game.state_name != "PLAY" or int(game.wave) < FIRST_WAVE:
		return _still_showing(game)

	var now: float = float(game.run_time)
	var holding := ""
	for id in ORDER:
		var wrong: bool = _is(id, game)
		var seconds: float = float(_dwell.get(id, 0.0))
		_dwell[id] = (seconds + delta) if wrong else 0.0
		if wrong and float(_dwell[id]) >= float(DWELL[id]) and holding == "":
			holding = id

	if holding != "" and _may_fire(holding, now):
		_current = holding
		_current_until = now + HOLD
		_shown[holding] = int(_shown.get(holding, 0)) + 1
		_last_at[holding] = now
		## The dwell resets on firing, so a hint that is still true does not fire
		## again the instant its gap expires — it has to be re-earned.
		_dwell[holding] = 0.0
	return _still_showing(game)


func _still_showing(game) -> String:
	if game == null or _current == "":
		return ""
	if float(game.run_time) > _current_until:
		_current = ""
		return ""
	return str(TEXT.get(_current, "")).replace(
		"{key}", SkyGearKeybinds.label("deckwork"))


func _may_fire(id: String, now: float) -> bool:
	if int(_shown.get(id, 0)) >= MAX_SHOWS:
		return false
	if now - float(_last_at.get(id, -999.0)) < REPEAT_GAP:
		return false
	## And never over another hint that is still up.
	return now > _current_until


## --- the four mistakes -------------------------------------------------------
func _is(id: String, game) -> bool:
	match id:
		"kiting":
			## HERS ONLY. "The gauge only fills inside 210 units" is false for the
			## Boilerwright — his fills from the ground he is standing on and
			## backing off a lane to hold a main is his correct play. A coach that
			## calls the right move a mistake stops being read, twice a run, in the
			## same strip the Boiler warnings use.
			if game.gauge_is_banked():
				return false
			## Not "far away" — far away with something to hit. A player alone on
			## an empty deck between waves is not kiting, and telling them they
			## are is how a coach loses its credibility on the first line.
			var near = game.nearest_enemy(game.player.global_position, 1e9)
			if near == null:
				return false
			var reach: float = float(SkyGearData.CLOSE.range)
			return game.player.global_position.distance_to(near.global_position) > reach * 1.6
		"gauge":
			## HERS ONLY, for the sharper version of the same reason: "it vents by
			## itself" is a promise the Boilerwright's gauge does not keep, and
			## sitting on a full bank is the single most correct thing he can do.
			if game.gauge_is_banked():
				return false
			## A full gauge is only wasted if there is something in reach of the
			## vent to waste it on.
			if float(game.pressure) < 99.0:
				return false
			return game.nearest_enemy(game.player.global_position,
				float(SkyGearData.CLOSE.vent_radius) * 2.2) != null
		"empty_bank":
			## HIS, and only while it is actually costing him something: an empty
			## bank on an empty deck is just a man walking to a vent.
			if not game.gauge_is_banked() or float(game.pressure) > 0.0:
				return false
			return game.nearest_enemy(game.player.global_position, 700.0) != null
		"lane":
			## A boarder past the halfway line with the captain nowhere near it.
			var deck: Rect2 = SkyGearGame.DECK_RECT
			var half: float = deck.get_center().y
			for enemy in game.get_tree().get_nodes_in_group("enemies"):
				if not is_instance_valid(enemy) or enemy.dead:
					continue
				if enemy.global_position.y < half:
					continue
				if game.player.global_position.distance_to(enemy.global_position) > 620.0:
					return true
			return false
		"shape_lane":
			## The same "a lane is walking through" as `lane`, but it only fires
			## while the crate is STILL STOWED and unused: the tool to shape the
			## ground is sitting there and the player has not found it. Goes quiet
			## the moment the crate is off its home, or while they are heaving it,
			## because then the verb is no longer invisible.
			if game.barricade == null or not is_instance_valid(game.barricade):
				return false
			if int(game.barricade_stage) != 0:
				return false
			var busy: Dictionary = game.deckwork
			if not busy.is_empty() and str((busy.get("spec", {}) as Dictionary).get("id", "")) == "heave_crate":
				return false
			var deck2: Rect2 = SkyGearGame.DECK_RECT
			var half2: float = deck2.get_center().y
			for enemy2 in game.get_tree().get_nodes_in_group("enemies"):
				if not is_instance_valid(enemy2) or enemy2.dead:
					continue
				if enemy2.global_position.y < half2:
					continue
				if game.player.global_position.distance_to(enemy2.global_position) > 620.0:
					return true
			return false
		"broken_cannon":
			## Only while one is actually down, and not while they are already
			## fixing it — a hint that tells you to do the thing you are visibly
			## doing is how a coach stops being read.
			if not (game.deckwork as Dictionary).is_empty():
				return false
			for turret in game.turrets:
				if bool(turret.get("dead", false)):
					return true
			return false
		"idle_skill":
			## Only once the hand is worth having: a slot drafted and never cast.
			## `casts` is already on the skill, so this costs nothing to know.
			if game.skills.size() < 3:
				return false
			for skill in game.skills:
				if int(skill.get("casts", 0)) == 0:
					return true
			return false
	return false
