extends SceneTree
## The boarding hulk at the bow, photographed in each of its three states —
## board SG-139/SG-140, off the owner's 2026-08-03 note: *"What is that 3D model
## that's sitting there in the middle? It is kind of distracting."*
##
## The deck tools all pose wave 1, which never carries a hulk, so there was no
## way to photograph the object he was asking about. This poses one directly.
##
##   godot --path . --script tools/hulk_shot.gd -- [outdir]
##
## Writes `<outdir>/hulk-<state>.png`, default `.shots/sg140`.
##
## FROZEN through `SkyGearStill` (SG-108), like every other tool that
## photographs this deck: the hulk's open state carries a `_spark` particle
## plume and the boarders around it are rigged, and neither stops for
## `set_process(false)`.

const W := 0.01                     ## WORLD_SCALE

var view
var game


func _initialize() -> void: call_deferred("_run")


func _run() -> void:
	var argv := OS.get_cmdline_user_args()
	var out_dir := str(argv[0]) if argv.size() > 0 else "res://.shots/sg140"
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1600, 900))
	root.size = Vector2i(1600, 900)
	await process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))

	var world = load("res://scenes/main3d.tscn").instantiate()
	root.add_child(world)
	await process_frame
	view = world
	game = world.get_node("SkyGear")
	game.workshop = SkyGearWorkshop.fresh(true)
	game.heat = 0
	game.set_class("captain")
	game.set_seed_text("HULK")
	game.begin_run()
	game.choose_draft(0)
	game.start_wave(1)
	game.spawn_queue.clear()
	view.sway = false
	for _i in 20:
		game._process(1.0 / 60.0)
		await process_frame
	var overlay = game.get_node_or_null("HUD")
	if overlay != null:
		overlay.visible = false

	## The captain stands where a player fighting a push actually stands: up the
	## centre lane, looking at the thing. The whole question is how much of that
	## lane the hulk takes, so the shot has to contain the lane.
	## Far enough up the lane that the WHOLE hull is in frame — the question is
	## how much of the lane it eats, and a shot with its roof cropped off cannot
	## answer that.
	game.player.global_position = Vector2(0.0, -640.0)
	game.player.velocity = Vector2.ZERO
	view._focus_set = false

	for state in ["sealed", "open", "destroyed"]:
		game.hulk = SkyGearLanes.make_hulk(SkyGearGame.BOW_Y, 1.0)
		game.hulk.vulnerable = state != "sealed"
		game.hulk.dead = state == "destroyed"
		## `make_hulk` writes no `grapple` — the push wave sets it separately —
		## so `_update_hulk` reads a default of 0, decides the grapple has landed
		## and flips a SEALED hulk open on the first frame. Held here, or this
		## tool photographs the open door three times and labels one of them
		## "sealed".
		game.hulk.grapple = 999.0 if state == "sealed" else 0.0
		## The wreck's fade is a renderer clock, so a destroyed shot has to be
		## taken AFTER it has run — otherwise this photographs a wreck at full
		## opacity and calls it the fade.
		## Guarded so this tool runs against the PRE-SG-139 renderer too, which
		## has no wreck clock at all — a before/after tool that only runs on the
		## "after" build cannot produce a before.
		if "_hulk_wreck_age" in view:
			view._hulk_wreck_age = 0.0
		var settle: int = 90 if state == "destroyed" else 8
		for _i in settle:
			view._process(1.0 / 60.0)
			await process_frame
		await SkyGearStill.freeze(self, view, game)
		var path := "%s/hulk-%s.png" % [out_dir, state]
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(path)
		await SkyGearStill.thaw(self, view, game)
		var node = view._prop_models.get("hulkm-" + state)
		var wide := 0.0
		if node != null:
			wide = view.measure_span(node).x * node.scale.x / W
		print("  %s   drawn %.0f ground units wide, hull %.0f  ->  %s"
			% [state, wide, float(game.hulk.radius) * 2.0, path.replace("res://", "")])
	quit(0)
