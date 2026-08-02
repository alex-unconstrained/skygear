extends SceneTree
## The Godot half of `tools/parity.py`. Poses the game exactly as the browser
## build is posed and saves one frame.
##
## Driven rather than standalone: the scene comes in as JSON on the command line
## so both halves read the same description of the same moment. A tool where the
## two sides each decide for themselves what "wave 5" means is a tool that
## produces two different pictures and calls the difference a regression.
##
##   godot --path . --resolution 1600x900 --script tools/parity_shot.gd -- '{...}'
func _initialize() -> void: call_deferred("_run")


func _run() -> void:
	var argv := OS.get_cmdline_user_args()
	if argv.is_empty():
		print("no scene given")
		quit(1)
		return
	var scene = JSON.parse_string(str(argv[0]))
	if scene is not Dictionary:
		print("scene is not json")
		quit(1)
		return

	var world = load("res://scenes/main3d.tscn").instantiate()
	root.add_child(world)
	await process_frame
	var game: SkyGearGame = world.get_node("SkyGear")

	## HAND-STEPPED, so the engine must not step it too.
	##
	## The loop below calls `game._process` and then awaits a frame, and the game
	## node is in the tree — so the engine called `_process` on it as well, and
	## every parity image this tool has produced had roughly TWICE the ticks it
	## claimed. Which makes it exactly the wrong bug for this tool to carry: the
	## whole point of counting ticks rather than seconds is that neither build is
	## handed more simulation than the other.
	##
	## Found by the VFX agent, whose first draft of a different tool had it too.
	game.set_process(false)

	## No Workshop, no Heat. The browser build has neither, so a comparison with
	## either turned on is a comparison of two different games.
	game.workshop = SkyGearWorkshop.fresh(true)
	game.heat = 0
	game.set_class("captain")
	game.set_seed_text(str(scene.get("seed", "PARITY")))
	game.begin_run()
	game.choose_draft(0)
	## A comparable hand. The browser opens with one skill too, so anything past
	## the first is deliberate rather than drift.
	for pair in [["RANGED_AOE", "FROST"], ["CHAIN", "ARC"], ["CONE", "STEAM"]]:
		game.skills.append(SkyGearData.make_skill(str(pair[0]), str(pair[1])))

	## `choose_draft` ON THE OPENING DRAFT ALREADY STARTS WAVE ONE. Calling it
	## again here began the wave twice — two spawn schedules, two banners, and a
	## `wave_time` reset partway through the first. Invisible until banners
	## stopped printing pixel-on-pixel and a posed shot came back with "WAVE 1"
	## three times down the middle of the screen.
	var want_wave: int = int(scene.get("wave", 1))
	if game.wave != want_wave:
		game.start_wave(want_wave)
	## The wave's own queue is cleared: the scene lists exactly who is on the
	## deck, so both builds get the same boarders rather than each spawning its
	## own schedule at its own pace.
	game.spawn_queue.clear()
	var kinds: Array = scene.get("enemies", [])
	for i in kinds.size():
		game.spawn_enemy(str(kinds[i]), i % 3)

	var casts: Array = scene.get("casts", [])
	var cast_last: bool = bool(scene.get("cast_last", false))
	var _cast := func() -> void:
		for slot in casts:
			game.cast_skill(int(slot), game.player.global_position + Vector2(0, -260))
	if not cast_last:
		_cast.call()

	## Fixed ticks, not seconds. The browser steps its own `DT`; this steps the
	## same count at the same size, so neither build is given more simulation
	## than the other because it happened to run faster.
	var steps: int = int(scene.get("steps", 60))
	for _i in steps:
		game._process(1.0 / 60.0)
		await process_frame

	## cast_last leaves a cooldown sweep still on the slot; the settle steps roll
	## it back to a partial sweep with a countdown number, matching the browser.
	if cast_last:
		_cast.call()
		for _i in int(scene.get("settle", 0)):
			game._process(1.0 / 60.0)
			await process_frame

	## The two HUD gauges only a played run fills — the pressure dial and a spent
	## dash pip — seated to the same fixed values the browser pose seats, AFTER
	## the stepping that would otherwise reset them. `pressure` reads through the
	## clamp so a scene cannot ask for an impossible gauge.
	if scene.has("pressure"):
		game.player.set_pressure(float(scene.get("pressure", 0.0)))
	if scene.has("dash_spent"):
		game.player.dash_charges = maxi(0,
			game.player.max_dash_charges - int(scene.get("dash_spent", 0)))

	## The between-waves draft, opened over the posed deck. With four skills in
	## hand this rolls the three upgrade cards — the same three-card layout the
	## browser draws — and drops the game into DRAFT so the HUD dims the fight
	## behind it exactly as the browser's drawDraft does.
	if bool(scene.get("draft", false)):
		game.open_draft()
		await process_frame

	var out := str(scene.get("out", ""))
	if out == "":
		print("no output path")
		quit(1)
		return
	var img := root.get_texture().get_image()
	img.save_png(out.replace("\\", "/"))
	print("shot ok")
	quit(0)
