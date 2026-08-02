extends SceneTree
## One posed frame of the PRIMITIVE Boiler fallback — board SG-30.
##
## The mesh Boiler is on disk, so the game never shows the fallback tier on this
## machine — which is exactly how the old fallback got to be a 178-unit golden
## dome without anyone seeing it. This strips whatever `_build_boiler` erected
## and stands the primitive path (`_boiler_primitive` + `_boiler_fire`) in its
## place: the exact body the game shows when `assets/models/boiler/boiler.tscn`
## is absent, photographed at the shipped run-opening framing.
##
##   godot --path . --resolution 1600x900 --script tools/boiler_shot.gd -- <outdir>
##
## NOT `--headless`. There is no framebuffer to read back without a GPU (SG-29),
## and a tool whose whole output is a PNG cannot run on the flag that makes PNGs
## empty.
func _initialize() -> void: call_deferred("_run")


func _run() -> void:
	var argv := OS.get_cmdline_user_args()
	var out_dir: String = str(argv[0]) if argv.size() > 0 else "../.shots/boiler"
	DirAccess.make_dir_recursive_absolute(out_dir)
	var path: String = "%s/fallback.png" % out_dir
	var world = load("res://scenes/main3d.tscn").instantiate()
	root.add_child(world)
	await process_frame
	var game: SkyGearGame = world.get_node("SkyGear")
	## Driven, not left running — the same rule as every shot tool here.
	game.set_process(false)
	world.sway = false
	game.workshop = SkyGearWorkshop.fresh(true)
	game.set_class("captain")
	game.set_seed_text("BOILER")
	game.begin_run()
	game.choose_draft(0)
	game.spawn_queue.clear()

	## Find the Boiler holder by position, the way the harness's SG-27 check
	## does, and swap the mesh tier for the fallback tier in place. No await
	## between the strip and the rebuild: `_boiler_fire` must reassign
	## `_boiler_glow` before the renderer's next frame touches the freed lamp.
	var want: Vector3 = Vector3(SkyGearGame.BOILER_POSITION.x, 0.0,
		SkyGearGame.BOILER_POSITION.y) * SkyGearView3D.WORLD_SCALE
	var boiler: Node3D = null
	for child in world.get_children():
		if child is Node3D and (child as Node3D).position.distance_to(want) < 0.001:
			boiler = child
	if boiler == null:
		push_error("no Boiler holder found")
		quit(1)
		return
	for child in boiler.get_children():
		child.queue_free()
	world._boiler_primitive(boiler)
	world._boiler_fire(boiler)

	## Settle: the freed mesh leaves the tree, shadows land, the camera reaches
	## the captain — this is the run-opening framing, boiler bottom-centre.
	for _i in 8:
		game._process(1.0 / 60.0)
		await process_frame
	game.effects.clear()
	await process_frame
	await process_frame

	var img := root.get_texture().get_image()
	img.save_png(path.replace("\\", "/"))
	print("  fallback %s" % path)
	print("boiler shot ok")
	world.queue_free()
	await process_frame
	quit(0)
