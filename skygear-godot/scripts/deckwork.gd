class_name SkyGearDeckwork
extends RefCounted

## Things you can do TO the deck, rather than to the boarders on it.
##
## Asked for as "repair broken turrets", and framed as the seed of something
## larger — the player eventually shaping the ground: laning, funnelling, moving
## the fight somewhere they chose. So this is a VERB TABLE from the first day
## rather than a repair button with a comment promising to generalise later. The
## difference is that adding "drag a crate into a lane" is one entry here, and
## adding it to a repair button is a rewrite.
##
## THE CURRENCY IS TIME, and only time.
##
## Not salvage, not health, not the gauge. On a deck where three lanes are
## walking toward the Boiler, the cost of standing still for two seconds is
## already the sharpest cost in the game — it is measured in whatever those
## lanes did while you were busy. A second resource on top would make deckwork a
## budgeting decision when it should be a positional one, which is the whole
## reason the class layer and the draft layer are kept apart.
##
## Interrupted by taking a hit, by moving, and by casting. That is not a
## punishment, it is what makes the choice real: you commit or you fight, and
## the wrong lane breaking while you commit is the game working.

## An action is: who it applies to, how long it takes, and what it does.
##
##   at        which family of thing it targets
##   reach     how close you have to stand, in ground units
##   seconds   how long you are out of the fight
##   can       is this target valid right now
##   apply     do it
##
## `verb` is what the prompt says. Deliberately a verb rather than a noun, so
## the prompt reads "REPAIR THE CANNON" rather than "CANNON".
const REPAIR_SECONDS := 2.4
const REPAIR_REACH := 96.0
## What a repaired cannon comes back at. NOT full: a cannon you can restore to
## new is a cannon that never really broke, and the lane pressure that broke it
## stops meaning anything. Enough to matter, little enough that losing one still
## hurts.
const REPAIR_FRACTION := 0.55

## Boarders standing on it stop you. Repairing a gun with a scrapper swinging at
## your back is not a decision, it is a free action with extra steps.
const CONTESTED := 150.0

## HEAVE THE CRATE — the second verb, and the first that shapes the ground rather
## than mends it (board SG-10). Repair is a coach line, a prompt, a progress bar
## and a refusal reason; every one of those is generic, so laning is one more row
## here and not a rewrite — which is the entire reason this was a table on day one.
##
## Slower than a repair: a loaded cargo stack is heavy, and the seconds ARE the
## limit. There is no second resource. One crate is 150 units against a 380-unit
## lane band, so a heave can narrow a lane and pin the fight to one side of it but
## can never wall the lane off — and it re-stows to its home every wave with the
## rest of the ordnance, so a flank you closed is a flank you pay to close again.
const HEAVE_SECONDS := 2.8
const HEAVE_REACH := 150.0


static func actions() -> Array[Dictionary]:
	return [
		{
			"id": "repair_turret", "verb": "REPAIR THE CANNON",
			"at": "turret", "reach": REPAIR_REACH, "seconds": REPAIR_SECONDS,
			"blocked": "boarders are on it",
		},
		{
			"id": "heave_crate", "verb": "HEAVE THE CRATE",
			"at": "crate", "reach": HEAVE_REACH, "seconds": HEAVE_SECONDS,
			"blocked": "boarders are on it",
		},
	]


## What you are standing next to that you could work on, or {}. One target, the
## nearest — a prompt that offers a choice is a prompt you have to read.
static func available(game) -> Dictionary:
	var best := {}
	var nearest := INF
	for spec in actions():
		for target in _targets(game, str(spec.at)):
			var gap: float = game.player.global_position.distance_to(
				Vector2(target.position))
			if gap > float(spec.reach) or gap >= nearest:
				continue
			if not _valid(game, spec, target):
				continue
			nearest = gap
			best = {"spec": spec, "target": target,
				"contested": _contested(game, target)}
	return best


static func _targets(game, family: String) -> Array:
	match family:
		"turret":
			return game.turrets
		"crate":
			## One draggable crate, offered as a target only while it is on the deck
			## — smashed, it is off the board until the next re-stow puts it back.
			var t: Dictionary = game.barricade_target()
			return [t] if not t.is_empty() else []
	return []


static func _valid(game, spec: Dictionary, target: Dictionary) -> bool:
	match str(spec.id):
		"repair_turret":
			## Only a dead one. A damaged gun still shoots, and letting you top it
			## up mid-wave turns deckwork into a maintenance chore you perform
			## constantly rather than a decision you make occasionally.
			return bool(target.get("dead", false))
		"heave_crate":
			## Always workable while it is there. A heave cycles the crate through
			## stow, narrow and funnel, so the same verb also RETRACTS it — there is
			## never a "nothing to do here" state to explain.
			return true
	return false


## Is something standing over it? Checked separately from validity so the prompt
## can say WHY it is refusing rather than simply not appearing — a prompt that
## vanishes teaches nothing.
static func _contested(game, target: Dictionary) -> bool:
	for enemy in game.get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or enemy.dead:
			continue
		if enemy.global_position.distance_to(Vector2(target.position)) <= CONTESTED:
			return true
	return false


static func perform(game, spec: Dictionary, target: Dictionary) -> void:
	match str(spec.id):
		"repair_turret":
			target.dead = false
			target.hp = float(target.max_hp) * REPAIR_FRACTION
			target.flash = 0.6
		"heave_crate":
			## The move lives in the sim, not here: this table says WHAT and HOW
			## LONG, and the game owns where the crate ends up and what pathes
			## against it. Keeps the one source of truth for cargo in one place.
			game.heave_barricade()
