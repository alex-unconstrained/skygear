extends SceneTree
## AB-01 forced Beam proof.
##
##   godot --path . --resolution 1600x900 --script tools/beam_probe.gd
##
## Writes start / held / release plates and prints BEAM_PROBE with an exact
## same-state noise measurement. The channel is stepped only through the
## simulation's clock and the view reads its endpoint from `active_channel`.
## It freezes the world before photographing, then advances only the Beam's
## accepted simulation delta by hand between plates.

const FRAME := Rect2i(0, 0, 1600, 900)
var _out := "../.codex-work/gameplay-expansion/AB-01/SG-202/visual"


func _init() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		_out = str(args[0])
	var out_res := "res://%s" % _out
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_res))
	var win := get_root()
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1600, 900))
	root.size = Vector2i(1600, 900)
	await process_frame

	var world: Node3D = load("res://scenes/main3d.tscn").instantiate()
	root.add_child(world)
	await process_frame
	var view := world as SkyGearView3D
	var game: SkyGearGame = world.get_node("SkyGear")
	view.cutscenes_enabled = false
	view.stop_cutscene()
	view.sway = false
	game.log_runs = false
	game.workshop = SkyGearWorkshop.fresh(true)
	game.set_seed_text("BEAM-PROBE")
	game.begin_run()
	game.choose_draft(0)
	game.spawn_queue.clear()
	for enemy in game.enemies():
		enemy.dead = true
		enemy.queue_free()
	game.skills = [SkyGearData.make_skill("RAY", "ARC")]
	game.player.global_position = Vector2(0, 360)
	game.player.aim_direction = Vector2.UP
	var hud := game.get_node_or_null("HUD")
	if hud != null:
		hud.visible = false
	for _i in 24:
		await process_frame

	## Freeze every ambient clock; manual zero-delta renderer syncs still work.
	await SkyGearStill.freeze(self, view, game)
	game.cast_skill(0, Vector2(0, -120))
	view._process(0.0)
	await process_frame
	await _save("beam-start.png", out_res)

	game._update_active_channel(0.18)
	view._process(0.0)
	await process_frame
	await _save("beam-held.png", out_res)
	var noise := await SkyGearStill.floor_pct(self, FRAME,
		func() -> void: view._process(0.0))

	game._update_active_channel(0.30)
	view._process(0.0)
	await process_frame
	await _save("beam-release.png", out_res)

	print("BEAM_PROBE start=beam-start.png held=beam-held.png release=beam-release.png")
	print("BEAM_PROBE noise=%.2f%% active_after_release=%s" % [noise,
		not game.active_channel.is_empty()])
	quit(0 if noise == 0.0 and game.active_channel.is_empty() else 1)


func _save(name: String, out_res: String) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path("%s/%s" % [out_res, name]))
