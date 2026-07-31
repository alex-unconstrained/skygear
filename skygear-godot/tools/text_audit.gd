extends SceneTree
## Does any text fall outside the frame it belongs to?
##
## Reported: "the text spacing on a lot of cards is off and the text begins
## outside of the frame and continues over onto the right so it's hard to read."
## That is not one card. It is a class of bug, and a class of bug wants a
## detector rather than a fix — otherwise the next panel added reintroduces it
## and nobody notices until someone plays.
##
## HOW IT WORKS. `SkyGearHUD` routes every string it draws through `_say`, which
## when an auditor is attached records the string, the box it was given, the
## width it actually measured, and the interior of the panel that was open at the
## time. Two failures are possible and they are different bugs:
##
##   OVERFLOW  the string is wider than the width it was handed, so `draw_string`
##             clips it. "Boiler gains 150 max HP and re".
##   OUTSIDE   the box is fine but it sits on or past the panel's brass rail, so
##             the text is drawn over the frame art. This is the reported one.
##
## Both are measured against the SAME rail the renderer draws, which is the whole
## point: the bug was that `interior()` believed the rail was thirty pixels while
## `_nine` drew forty-eight, so every panel laid its content out against a frame
## eighteen pixels narrower than the one on screen.
##
##   godot --path . --script tools/text_audit.gd
##   godot --path . --script tools/text_audit.gd -- --verbose
##
## Exit code is the number of violations, so it can gate a build.
func _initialize() -> void: call_deferred("_run")

## Screens, and what has to be true for the HUD to draw each one. Every state the
## player can be looking at — a screen that is not in this list is a screen the
## audit does not cover, which is why the list is explicit rather than derived.
const SCREENS := [
	{"name": "title", "state": "TITLE"},
	{"name": "title + controls", "state": "TITLE", "keys": true},
	{"name": "settings", "state": "TITLE", "settings": true},
	{"name": "how to play", "state": "TITLE", "how": true},
	{"name": "the workshop", "state": "TITLE", "workshop": true},
	{"name": "how to play mid-run", "state": "PAUSE", "skills": 4, "how": true},
	{"name": "draft (weapons)", "state": "DRAFT", "skills": 0},
	{"name": "draft (upgrades)", "state": "DRAFT", "skills": 4},
	{"name": "playing", "state": "PLAY", "skills": 4},
	{"name": "paused", "state": "PAUSE", "skills": 4},
	{"name": "paused + controls", "state": "PAUSE", "skills": 4, "keys": true},
	{"name": "settings mid-run", "state": "PAUSE", "skills": 4, "settings": true},
	{"name": "deck lost", "state": "GAMEOVER", "skills": 4},
	{"name": "deck lost + workshop", "state": "GAMEOVER", "skills": 4, "banked": true},
	{"name": "deck held", "state": "VICTORY", "skills": 4},
]

## Widths a player might actually run at, including the two where a fixed layout
## breaks: the smallest window the project allows, and an ultrawide.
const SIZES := [Vector2(1280, 720), Vector2(1600, 900), Vector2(1920, 1080),
	Vector2(2560, 1080)]


func _run() -> void:
	var verbose := "--verbose" in OS.get_cmdline_user_args()
	var world = load("res://scenes/main3d.tscn").instantiate()
	root.add_child(world)
	await process_frame
	var game = world.get_node("SkyGear")
	var hud = game.hud

	var findings: Array = []
	for size in SIZES:
		for screen in SCREENS:
			await _pose(game, hud, screen, size)
			var batches: Array = [null]
			if str(screen.state) == "DRAFT" and size == SIZES[1]:
				batches = _every_card(game)
			for batch in batches:
				if batch != null:
					game.draft_options.clear()
					for card in batch:
						game.draft_options.append(card)
				hud.audit = []
				hud.queue_redraw()
				await process_frame
				for hit in hud.audit:
					hit["screen"] = str(screen.name)
					hit["at"] = "%dx%d" % [int(size.x), int(size.y)]
					findings.append(hit)
				hud.audit = null

	## Grouped by what is broken rather than by where it was found: the same
	## string wrong at four resolutions is one bug, and a list that reports it
	## four times reads as four.
	var groups := {}
	for f in findings:
		var key := "%s|%s|%s" % [str(f.screen), str(f.kind), str(f.text)]
		if not groups.has(key):
			groups[key] = {"count": 0, "sample": f, "sizes": []}
		groups[key].count += 1
		var at := str(f.at)
		if at not in groups[key].sizes:
			groups[key].sizes.append(at)

	print("")
	print("TEXT AUDIT  ·  %d screens x %d sizes" % [SCREENS.size(), SIZES.size()])
	print("")
	if groups.is_empty():
		print("  every string fits the box it was given and sits inside its frame.")
		quit(0)
		return

	## By screen, so the report reads as a list of places to go and fix rather
	## than a shuffled pile.
	var order: Array = groups.keys()
	order.sort_custom(func(a, b):
		var fa: Dictionary = groups[a].sample
		var fb: Dictionary = groups[b].sample
		if str(fa.screen) != str(fb.screen):
			return str(fa.screen) < str(fb.screen)
		return str(fa.kind) < str(fb.kind))
	var outside := 0
	var overflow := 0
	var last_screen := ""
	for key in order:
		var g: Dictionary = groups[key]
		var f: Dictionary = g.sample
		if str(f.kind) == "OUTSIDE":
			outside += 1
		else:
			overflow += 1
		if str(f.screen) != last_screen:
			last_screen = str(f.screen)
			print("  %s" % last_screen.to_upper())
		var quoted: String = str(f.text)
		if quoted.length() > 34:
			quoted = quoted.substr(0, 31) + "..."
		print("    %-8s \"%s\"" % [str(f.kind), quoted])
		if str(f.kind) == "OVERFLOW":
			print("             needs %.0f, given %.0f" % [float(f.measured), float(f.given)])
		else:
			print("             box %s, frame interior %s" % [_r(f.box), _r(f.frame)])
		if verbose:
			print("             at %s" % ", ".join(g.sizes))

	print("")
	print("%d distinct problems — %d text drawn over the frame, %d text clipped."
		% [groups.size(), outside, overflow])
	quit(groups.size())


## Every card the catalogue can offer, in threes. A draft screen is only ever
## three cards wide, but there are forty-one of them and the long titles are the
## ones that break the layout.
func _every_card(game) -> Array:
	var first := func(list: Array) -> int:
		return int(list[0]) if not list.is_empty() else 0
	var made: Array = []
	for entry in SkyGearCards.catalogue():
		if not (entry.get("can") as Callable).call(game):
			continue
		var card: Dictionary = (entry.get("make") as Callable).call(game, first)
		card["class_label"] = SkyGearCards.SCOPE_LABEL.get(str(entry.scope), "UPGRADE")
		card["color"] = SkyGearCards.SCOPE_COLOR.get(str(entry.scope), Color("#b0813f"))
		card["scope"] = str(entry.scope)
		made.append(card)
	var batches: Array = []
	for i in range(0, made.size(), 3):
		batches.append(made.slice(i, mini(i + 3, made.size())))
	return batches


func _r(v) -> String:
	var rect: Rect2 = v
	return "%.0f,%.0f %.0fx%.0f" % [rect.position.x, rect.position.y,
		rect.size.x, rect.size.y]


## Put the game into the state a screen needs. Deliberately blunt — this is a
## renderer audit, so the simulation only has to be plausible, not played.
func _pose(game, hud, screen: Dictionary, size: Vector2) -> void:
	hud.size = size
	game.settings_open = false
	game.keys_open = false
	game.how_open = false
	game.workshop_open = false
	game.go_to_title()
	game.set_seed_text("AUDIT")

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
			await process_frame

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
	game.keys_open = bool(screen.get("keys", false))
	game.settings_open = bool(screen.get("settings", false))
	game.how_open = bool(screen.get("how", false))
	if bool(screen.get("banked", false)):
		game.workshop = SkyGearWorkshop.fresh(true)
		game.workshop.unlocked = true
		game.workshop.scrip = 400
		SkyGearWorkshop.buy(game.workshop, "ledger")
		game.talents = SkyGearWorkshop.resolved(game.workshop)
		game.banked = {"scrip": 193, "sigils": 1, "unlocked": true, "first_win": true}
	if bool(screen.get("workshop", false)):
		## Unlocked and part-bought, so the audit sees bought, affordable and
		## locked nodes rather than one uniform dimmed column.
		game.workshop = SkyGearWorkshop.fresh(true)
		game.workshop.unlocked = true
		game.workshop.scrip = 640
		for id in ["padded_coat", "bootblacking", "manifest", "tally"]:
			SkyGearWorkshop.buy(game.workshop, id)
		game.workshop_open = true
	await process_frame
