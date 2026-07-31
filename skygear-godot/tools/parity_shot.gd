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

	game.start_wave(int(scene.get("wave", 1)))
	## The wave's own queue is cleared: the scene lists exactly who is on the
	## deck, so both builds get the same boarders rather than each spawning its
	## own schedule at its own pace.
	game.spawn_queue.clear()
	var kinds: Array = scene.get("enemies", [])
	for i in kinds.size():
		game.spawn_enemy(str(kinds[i]), i % 3)

	for slot in (scene.get("casts", []) as Array):
		game.cast_skill(int(slot), game.player.global_position + Vector2(0, -260))

	## Fixed ticks, not seconds. The browser steps its own `DT`; this steps the
	## same count at the same size, so neither build is given more simulation
	## than the other because it happened to run faster.
	var steps: int = int(scene.get("steps", 60))
	for _i in steps:
		game._process(1.0 / 60.0)
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
