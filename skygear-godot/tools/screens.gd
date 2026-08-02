extends RefCounted

## PRELOADED, not `class_name`. Nothing under `tools/` is in the global class
## cache — that is populated by an editor import scan and these scripts are only
## ever run headless with `--script`, so a `class_name` here parses in the editor
## and fails on the command line. Both callers `preload` it.

## THE LIST OF SCREENS, AND HOW TO PUT THE GAME INTO EACH ONE. Once.
##
## This was inside `tools/text_audit.gd`, which is the only place that had ever
## needed it — and then the Workshop got a visual pass and the thing that was
## actually missing turned out to be *looking at it*, repeatedly, at the four
## resolutions the audit poses. Copying the poser into a screenshot tool would
## have been the project's second-favourite bug: two functions that disagree
## about one thing, here "what a posed Workshop contains". A shot of a Workshop
## with different scrip and different nodes bought than the one the audit
## measures is a shot of a screen nobody is checking.
##
## So the audit and the camera share this. `tools/screen_shot.gd` photographs
## exactly what `tools/text_audit.gd` measures, by construction.

## Every state the player can be looking at. A screen that is not in this list is
## a screen neither tool covers, which is why the list is explicit rather than
## derived from the state enum.
const SCREENS := [
	{"name": "title", "state": "TITLE"},
	{"name": "title + heat", "state": "TITLE", "heat": true},
	{"name": "title + controls", "state": "TITLE", "keys": true},
	{"name": "settings", "state": "TITLE", "settings": true},
	{"name": "how to play", "state": "TITLE", "how": true},
	## THE DENSEST SHEET IN THE GAME: eight rows of prose in two columns plus a
	## four-row numeric spine, all of it sized to whatever the window allows. It
	## is the screen most likely to break at 1280 and the one nobody would think
	## to check at 2560.
	{"name": "compare the classes", "state": "TITLE", "compare": true},
	## ...and again mid-run, where the two SAIL AS buttons are replaced by one
	## BACK. A different widget set is a different layout.
	{"name": "compare the classes mid-run", "state": "PAUSE", "skills": 4,
		"compare": true},
	{"name": "the workshop", "state": "TITLE", "workshop": true},
	{"name": "how to play mid-run", "state": "PAUSE", "skills": 4, "how": true},
	{"name": "draft (weapons)", "state": "DRAFT", "skills": 0},
	{"name": "draft (upgrades)", "state": "DRAFT", "skills": 4},
	{"name": "playing", "state": "PLAY", "skills": 4},
	## THE OTHER CLASS'S HUD, WHICH NOTHING HAS EVER LOOKED AT. Every screen in
	## this list poses the captain, so the strip that carries the Boilerwright's
	## three bindings and his Overpressure readout has never been measured — and
	## the first time it was, "V BLOWDOWN" was eight pixels off the plate.
	{"name": "playing (the Boilerwright)", "state": "PLAY", "skills": 4,
		"class": "boilerwright", "head": 64.0},
	## And the same HUD with the bank empty, which is a different strip: the
	## multiplier reads ×1.00, all three bindings are unaffordable and dimmed, and
	## the loss flash is up.
	{"name": "playing (the Boilerwright, spent)", "state": "PLAY", "skills": 4,
		"class": "boilerwright", "head": 0.0, "spent": true},
	{"name": "paused", "state": "PAUSE", "skills": 4},
	{"name": "paused + controls", "state": "PAUSE", "skills": 4, "keys": true},
	{"name": "settings mid-run", "state": "PAUSE", "skills": 4, "settings": true},
	## TWO BANNERS AT ONCE. `start_wave` fires "WAVE n" with a 2.0s life and
	## clearing fires "WAVE CLEAR" with 1.6s, both centred at the same y with
	## no stacking between them — so any wave cleared inside two seconds of
	## starting prints one through the other. Every other screen here poses a
	## resting state; this one poses a MOMENT, which is the kind the list was
	## missing.
	{"name": "wave clear over wave start", "state": "PLAY", "skills": 4,
		"banners": true},
	{"name": "deck lost", "state": "GAMEOVER", "skills": 4},
	{"name": "deck lost + workshop", "state": "GAMEOVER", "skills": 4, "banked": true},
	{"name": "deck held", "state": "VICTORY", "skills": 4},
]

## Widths a player might actually run at, including the two where a fixed layout
## breaks: the smallest window the project allows, and an ultrawide.
const SIZES := [Vector2(1280, 720), Vector2(1600, 900), Vector2(1920, 1080),
	Vector2(2560, 1080)]


static func find(name: String) -> Dictionary:
	for screen in SCREENS:
		if str(screen.name) == name:
			return screen
	return {}


## A filename that survives a shell: "how to play mid-run" -> "how-to-play-mid-run".
static func slug(name: String) -> String:
	return name.to_lower().replace(" + ", "-").replace(" ", "-") 		.replace("(", "").replace(")", "")


## Put the game into the state a screen needs. Deliberately blunt — both callers
## are renderer tools, so the simulation only has to be plausible, not played.
static func pose(tree: SceneTree, game, hud, screen: Dictionary,
		size: Vector2) -> void:
	hud.size = size
	## Live again while the pose is being built; frozen once it is. See the note
	## at the foot of this function.
	game.set_process(true)
	game.settings_open = false
	game.keys_open = false
	game.how_open = false
	game.compare_open = false
	game.workshop_open = false
	game.go_to_title()
	game.set_seed_text("AUDIT")
	## BEFORE `begin_run`, or the body, the dash ceiling and the starting weapon
	## are all built for whoever was aboard last.
	game.set_class(str(screen.get("class", "captain")))

	var want := str(screen.state)
	if want != "TITLE":
		game.begin_run()
		if int(screen.get("skills", 0)) > 0:
			game.skills.clear()
			for pair in [["CLOSEHIT", "EMBER"], ["RANGED_AOE", "FROST"],
					["CHAIN", "ARC"], ["SENTRY", "STEAM"]]:
				game.skills.append(SkyGearData.make_skill(str(pair[0]), str(pair[1])))
		game.start_wave(7)
		for i in 8:
			game.spawn_enemy("SCRAPPER", i % 3)
		for i in 12:
			game._process(0.05)
			await tree.process_frame

	match want:
		"DRAFT":
			game.open_draft()
		"PAUSE":
			game._set_state(SkyGearGame.State.PAUSE)
		"GAMEOVER":
			game.end_reason = "the Boiler went cold on wave 7"
			game._set_state(SkyGearGame.State.GAMEOVER)
		"VICTORY":
			game.end_reason = "twelve waves repelled"
			game._set_state(SkyGearGame.State.VICTORY)
	if bool(screen.get("banners", false)):
		## Fired the way the game fires them, not drawn by hand — a hand-drawn
		## pair would prove the audit can see overlap and nothing about whether
		## the game produces it.
		game._fx({"kind": "banner", "text": "WAVE %d" % game.wave,
			"time": 0.0, "life": 2.0})
		game._fx({"kind": "banner", "text": "WAVE CLEAR", "time": 0.0,
			"life": 1.6})
	## The gauge, posed. Set after the wave has been stepped, because stepping it
	## is what would otherwise refill or spend the thing being posed.
	##
	## AND THE POSE HAS TO BE STILL. Both callers draw the frame twice — the
	## screenshot tool to let the plate settle, the audit to sample what is behind
	## each string — and anything that CHANGES between those two draws comes back
	## as one string printed through another. Standing on the Boiler ticks its HP
	## every frame, and a floating "OVERPRESSURE" drifts four pixels up; both were
	## reported as overprints and neither is a layout bug. Off the Boiler, and no
	## numbers in the air.
	if screen.has("head"):
		game.player.global_position = Vector2(-180.0, 240.0)
		game.pressure = float(screen.head)
		game.player.set_pressure(game.pressure)
		## Consume the edge here rather than letting the first captured frame do
		## it, or setting the gauge by hand posts an OVERPRESSURE floater that then
		## drifts between the two draws.
		game._watch_overpressure(0.0)
		game.floaters.clear()
	if bool(screen.get("spent", false)):
		game.overpressure_lost = 1.2
	game.keys_open = bool(screen.get("keys", false))
	game.settings_open = bool(screen.get("settings", false))
	game.how_open = bool(screen.get("how", false))
	game.compare_open = bool(screen.get("compare", false))
	if bool(screen.get("heat", false)):
		## Unlocked and part-climbed, so the Heat LADDER and the Workshop button
		## are both on the title at once — the fullest the screen ever gets. Three
		## rungs cleared, the fourth the next reachable, the fifth still locked,
		## and the pick sitting on the longest blurb (Boarders Aloft) so the strip
		## beneath the ladder is audited at its widest.
		game.workshop = SkyGearWorkshop.fresh(true)
		game.workshop.unlocked = true
		game.workshop.scrip = 240
		game.workshop.best_heat = 3
		game.heat = 4
	if bool(screen.get("banked", false)):
		game.workshop = SkyGearWorkshop.fresh(true)
		game.workshop.unlocked = true
		game.workshop.scrip = 400
		SkyGearWorkshop.buy(game.workshop, "ledger")
		game.talents = SkyGearWorkshop.resolved(game.workshop)
		game.banked = {"scrip": 193, "sigils": 1, "unlocked": true, "first_win": true}
	if bool(screen.get("workshop", false)):
		## Unlocked and part-bought, so both tools see bought, affordable and
		## locked nodes rather than one uniform dimmed column. Two sigils, because
		## the Articles have the same four states and one of them — barred — needs
		## an Article already owned to exist at all.
		game.workshop = SkyGearWorkshop.fresh(true)
		game.workshop.unlocked = true
		## 200, minus the 160 the four nodes below cost, leaves 40 — which is the
		## one balance that puts ALL FIVE fitting states on the board at once.
		## Everything above 100 scrip is in a tier that is still shut, so at any
		## richer purse the "open, and you cannot pay for it" state does not exist
		## anywhere on the screen: at 640 it was never once rendered, and a state
		## nothing poses is a state nothing checks.
		game.workshop.scrip = 200
		game.workshop.sigils = 2
		for id in ["padded_coat", "bootblacking", "manifest", "tally"]:
			SkyGearWorkshop.buy(game.workshop, id)
		SkyGearWorkshop.take(game.workshop, "brace")
		game.workshop.sigils = 2
		game.workshop_open = true
	await tree.process_frame
	## AND THEN NOTHING MOVES.
	##
	## Both callers draw the posed frame more than once — the camera to let the
	## plate settle, the audit to sample the pixels behind every string with the
	## glyphs suppressed — and the simulation was still running in between. On a
	## PLAY screen that means the lane counts, BOARDERS and the Boiler's HP tick
	## by one between the two draws, and the audit reports "6 is printed through
	## 7": a true observation about two frames and a false one about the layout.
	## It came and went with how the spawn timers happened to land, which is the
	## worst kind of red.
	##
	## The HUD keeps redrawing — it is a separate node — so what is captured is
	## still the real renderer against the real state. It is just the same state
	## twice, which is what a pose was always supposed to mean.
	game.set_process(false)
