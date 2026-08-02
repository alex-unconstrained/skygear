extends SceneTree
## Pose evidence for the captain's cape (board SG-23): idle drape, run trail,
## dash crack — each as the game frame, plus a pulled-in detail shot, because
## at the locked 41 degree solve the cape is forty pixels tall and a judgement
## about cloth needs to see the cloth.
##
##   godot --path . --resolution 1600x900 --script tools/cloak_shot.gd -- <outdir>
##
## NOT `--headless` — the readback hangs without a swapchain on this machine
## (board SG-29), same as every other screenshot tool here.
##
## The simulation is DRIVEN, not left running (the vfx_shot lesson), and the
## sway is off, so the same command returns the same pictures: the cape's own
## deterministic-rest mode is exactly what makes the idle shot repeatable.

func _initialize() -> void: call_deferred("_run")


func _run() -> void:
	var argv := OS.get_cmdline_user_args()
	var out_dir: String = str(argv[0]) if argv.size() > 0 else ".shots/cloak"
	DirAccess.make_dir_recursive_absolute(out_dir)

	var world = load("res://scenes/main3d.tscn").instantiate()
	root.add_child(world)
	await process_frame
	var game: SkyGearGame = world.get_node("SkyGear")
	game.set_process(false)
	world.sway = false
	game.workshop = SkyGearWorkshop.fresh(true)
	game.heat = 0
	game.set_class("captain")
	game.set_seed_text("CLOAK")
	game.begin_run()
	game.choose_draft(0)
	game.start_wave(1)
	## An empty wave AUTO-CLEARS and the draft screen photobombs the run shot
	## (the SG-36 story, met first-hand: the second scene came back as three
	## upgrade cards). One spawn parked in the far future holds the wave open
	## without putting a boarder in any frame.
	game.spawn_queue.clear()
	game.spawn_queue.append({"time": 99999.0, "kind": "SCRAPPER", "lane": 1})
	game.effects.clear()

	## She faces up-deck for every scene, back to the camera — which is where
	## the cape is.
	var player := game.player
	game.set_cursor_ground(player.global_position + Vector2(0.0, -420.0))

	## IDLE — the rest drape, settled through the cape's own snap.
	for _i in 90:
		game._process(1.0 / 60.0)
		await process_frame
	game.effects.clear()
	await _snap(world, out_dir, "idle", Vector3(1.15, 1.55, 1.85))

	## RUN — a REAL run: the move action held, the player node's own physics
	## doing the moving, the chain trailing behind her.
	Input.action_press("move_up")
	for _i in 55:
		game._process(1.0 / 60.0)
		await process_frame
	await _snap(world, out_dir, "run", Vector3(1.85, 1.40, 1.30))

	## DASH — the real move through the real key, photographed mid-crack.
	Input.action_press("dash")
	for _i in 7:
		game._process(1.0 / 60.0)
		await process_frame
	Input.action_release("dash")
	await _snap(world, out_dir, "dash", Vector3(1.85, 1.40, 1.30))
	Input.action_release("move_up")

	print("cloak shots ok -> %s" % out_dir)
	quit(0)


## The game frame, then the detail: freeze the renderer where it stands and
## walk the camera in behind her shoulder, so the forty-pixel cape gets one
## picture at a size a cloth call can be made from.
func _snap(world, out_dir: String, id: String, eye_off: Vector3) -> void:
	await process_frame
	var img := root.get_texture().get_image()
	img.save_png(("%s/%s.png" % [out_dir, id]).replace("\\", "/"))

	world.set_process(false)
	var cam: Camera3D = world.camera
	var kept := cam.global_transform
	var at: Vector2 = world.game.player.global_position
	var eye := Vector3(at.x * 0.01, 0.0, at.y * 0.01) + eye_off
	var aim := Vector3(at.x * 0.01, 1.05, at.y * 0.01)
	cam.look_at_from_position(eye, aim, Vector3.UP)
	await process_frame
	await process_frame
	var close := root.get_texture().get_image()
	close.save_png(("%s/%s-close.png" % [out_dir, id]).replace("\\", "/"))
	cam.global_transform = kept
	world.set_process(true)
	await process_frame
