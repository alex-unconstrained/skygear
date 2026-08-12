extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1600, 900))
	root.size = Vector2i(1600, 900)
	await process_frame
	var world: SkyGearView3D = load("res://scenes/main3d.tscn").instantiate()
	root.add_child(world)
	await process_frame
	var game: SkyGearGame = world.get_node("SkyGear")
	world.cutscenes_enabled = false
	world.stop_cutscene()
	world.sway = false
	game.log_runs = false
	game.workshop = SkyGearWorkshop.fresh(true)
	game.heat = 0
	game.set_class("captain")
	game.set_seed_text("WATCH2")
	game.begin_run()
	game.choose_draft(0)
	game.start_wave(8)
	game.set_process(false)
	world.set_process(false)
	## The event itself is the subject. Keep the start-of-wave deck empty so the
	## baseline does not accidentally turn into a hand-authored encounter pose.
	game.spawn_queue.clear()
	world.set("_zoom", 1.0)
	world.set("_zoom_target", 1.0)
	world.set("_focus", game.player.global_position)
	world.set("_focus_set", true)
	var out := ProjectSettings.globalize_path(
		"res://../.codex-work/gameplay-expansion/BASE-00/SG-196/visual")
	DirAccess.make_dir_recursive_absolute(out)
	## Same wave, seed, camera and tree. The event flag is the only difference.
	game._end_event()
	await _capture(world, game, out.path_join("blackout-control.png"))
	game._begin_event("blackout")
	if game.active_event != "blackout":
		push_error("BASE blackout fixture did not enter blackout")
		quit(1)
		return
	await _capture(world, game, out.path_join("blackout.png"))
	print("BASE blackout screenshot: active_event=%s enemies=%d" % [
		game.active_event, game.enemies().size()])
	game.set_process(true)
	quit(0)


func _capture(world: SkyGearView3D, game: SkyGearGame, path: String) -> void:
	world._process(1.0 / 60.0)
	await SkyGearStill.freeze(self, world, game)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
	await SkyGearStill.thaw(self, world, game)
