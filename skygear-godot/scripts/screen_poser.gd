extends RefCounted

## THE LIST OF SCREENS, AND HOW TO PUT A GAME INTO EACH ONE. Once, for everybody.
##
## This lived in `tools/screens.gd` (and before that inside `tools/text_audit.gd`),
## which was fine while the only callers were batch tools. Then the owner asked,
## for the second time, to edit the screens INTERACTIVELY (board SG-44): SG-42's
## editor could edit any screen it was ON, but reaching the results screen meant
## winning a run and reaching GAMEOVER meant dying, which is not an alignment
## workflow. The one thing the editor was missing — putting the game INTO a
## screen — is the one thing the batch tools already knew how to do.
##
## `scripts/hud.gd` may not depend on `tools/` (the game must not ship with a
## tools import), so the posing moved HERE and `tools/screens.gd` became a thin
## door over it. ONE poser, three callers: the text audit measures these poses,
## the batch camera photographs them, and the F4 picker hands them to a person
## with the editor up. A second copy of "what a posed Workshop contains" is the
## project's failure mode two, and the harness asserts the tool's list and this
## list are the same object (`editor · the picker poses the batch tool's own
## screens — one list`).
##
## PRELOADED, not `class_name`, same reason as everything the tools preload:
## the global class cache is populated by an editor import scan, and both the
## harness and the tools run with `--script` against whatever cache is on disk.
## Every caller does `preload("res://scripts/screen_poser.gd")` and cannot be
## broken by a stale cache.

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
	## THE BERTHS (SG-56): the ship's between-runs screen, posed at its
	## fullest mix of states — three berthed, one earned-and-ready, two locked
	## with their padlocks — so berthed/ready/locked all render, the berth row
	## shows filled and empty slots, and the foot strip's default line is up.
	{"name": "the berths", "state": "TITLE", "berths_screen": true},
	{"name": "how to play mid-run", "state": "PAUSE", "skills": 4, "how": true},
	{"name": "draft (weapons)", "state": "DRAFT", "skills": 0},
	{"name": "draft (upgrades)", "state": "DRAFT", "skills": 4},
	## THE OPENING BID's matrix (SG-26): thirty-two named cells where three
	## cards would be, plus the vow strip. A grid of 12pt labels at 1280 is
	## exactly the kind of screen that breaks first and gets looked at last.
	{"name": "draft (the bid)", "state": "DRAFT", "skills": 0,
		"article": "opening_bid"},
	{"name": "playing", "state": "PLAY", "skills": 4},
	## THE SECOND HAND's fifth well (SG-26): raised above the hand, keyless,
	## EMPTY with its invitation up — the pose with the most novel strings on
	## it. Armed it is just a fifth copy of a well the other poses measure.
	{"name": "playing (the second hand)", "state": "PLAY", "skills": 4,
		"article": "second_hand"},
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
	return name.to_lower().replace(" + ", "-").replace(" ", "-") \
		.replace("(", "").replace(")", "")


## Put the game into the state a screen needs. Deliberately blunt — every caller
## poses a game whose simulation only has to be plausible, not played. The
## editor's caller hands in a SANDBOX game (never the live run — see
## `SkyGearGame.pose_screen`), the batch tools hand in the one game they own;
## either way every pose starts from a clean ephemeral workshop, so nothing a
## pose signs or buys can leak into the next pose or onto the player's disk.
static func pose(tree: SceneTree, game, hud, screen: Dictionary,
		size: Vector2) -> void:
	hud.size = size
	## SUPPRESS THE SHIPPED CUTSCENES (board SG-33). The batch callers load
	## `main3d.tscn`, whose renderer runs `_watch_cues` every frame, and posing
	## GAMEOVER or VICTORY below trips the `defeat` / `victory` cues. Those HIDE
	## THE HUD and swing the camera off the deck: the audit would then sample a
	## blank screen behind every string it thinks it is measuring and report the
	## two GAMEOVER screens and the VICTORY screen CLEAN — a detector silenced by
	## the thing it was pointed at, which is exactly the failure this poser was
	## built to keep from happening. Off, so the endings are posed with their HUD
	## up on the gameplay solve. (The editor's sandbox has no view; the guard
	## simply does not fire there.)
	if game.view != null:
		game.view.cutscenes_enabled = false
		game.view.stop_cutscene()
	## A POSED ENDING IS A PICTURE, NOT A RUN (board SG-49). `_set_state` records
	## every finished run to `user://` — so every audit pass was quietly appending
	## a dozen fake GAMEOVER/VICTORY rows to the player's own run log, and the F4
	## picker would have added one per pose. Off for anything this poser drives;
	## the posed screen still reads "saved to the run log", because that healthy
	## string is the one being measured.
	game.log_runs = false
	## Live again while the pose is being built; frozen once it is. See the note
	## at the foot of this function.
	game.set_process(true)
	game.settings_open = false
	game.keys_open = false
	game.how_open = false
	game.compare_open = false
	game.workshop_open = false
	game.berths_open = false
	game.go_to_title()
	game.set_seed_text("AUDIT")
	## BEFORE `begin_run`, or the body, the dash ceiling and the starting weapon
	## are all built for whoever was aboard last.
	game.set_class(str(screen.get("class", "captain")))
	## An Article pose (SG-26) signs its vow BEFORE `begin_run`, because that is
	## the one moment a run resolves what the Workshop granted — set it later
	## and the pose is a screenshot of the Article NOT working. And EVERY pose
	## starts from a clean ephemeral bench: the game object is reused across the
	## whole matrix, so without this a vow signed for one screen would still be
	## live on every screen posed after it (and on a dev machine, whatever
	## workshop.json the local save holds would leak into the measurements).
	game.workshop = SkyGearWorkshop.fresh(true)
	## And the ship re-read from the clean bench (SG-56): without this a pose
	## on a dev machine inherits whatever wreck the local save has berthed,
	## and two machines audit two different backdrops.
	game.refresh_berthed()
	var vow := str(screen.get("article", ""))
	if vow != "":
		game.workshop.unlocked = true
		game.workshop.sigils = 9
		SkyGearWorkshop.take(game.workshop, vow)

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
	## AND THE POSE HAS TO BE STILL. Both batch callers draw the frame twice —
	## the screenshot tool to let the plate settle, the audit to sample what is
	## behind each string — and anything that CHANGES between those two draws
	## comes back as one string printed through another. Standing on the Boiler
	## ticks its HP every frame, and a floating "OVERPRESSURE" drifts four pixels
	## up; both were reported as overprints and neither is a layout bug. Off the
	## Boiler, and no numbers in the air.
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
		## And the run earned a fitting (SG-56), so the results screen's THE
		## SHIP KEEPS line is posed and measured with the rest of the payout.
		game.workshop.fittings = {"bow_barricade": true}
		game.workshop.berths = ["bow_barricade"]
		game.banked = {"scrip": 193, "sigils": 1, "unlocked": true,
			"first_win": true, "fitting": "bow_barricade"}
	if bool(screen.get("berths_screen", false)):
		## Four earned (three of them berthed, one ready), two still locked —
		## the one balance that puts every slate state and both slot states on
		## the screen at once, with the ready slate's teal tag and the padlocks'
		## earn rules all present to be measured.
		game.workshop = SkyGearWorkshop.fresh(true)
		game.workshop.unlocked = true
		for fit_id in ["wreck", "bow_barricade", "spare_gun", "winch"]:
			(game.workshop.fittings as Dictionary)[fit_id] = true
		game.workshop.berths = ["wreck", "bow_barricade", "spare_gun"]
		game.refresh_berthed()
		game.berths_open = true
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
	## Every caller draws the posed frame more than once — the camera to let the
	## plate settle, the audit to sample the pixels behind every string with the
	## glyphs suppressed, the editor for as long as a person cares to look — and
	## the simulation was still running in between. On a PLAY screen that means
	## the lane counts, BOARDERS and the Boiler's HP tick by one between two
	## draws, and the audit reports "6 is printed through 7": a true observation
	## about two frames and a false one about the layout. It came and went with
	## how the spawn timers happened to land, which is the worst kind of red.
	##
	## The HUD keeps redrawing — it is a separate node — so what is captured is
	## still the real renderer against the real state. It is just the same state
	## twice, which is what a pose was always supposed to mean.
	game.set_process(false)
