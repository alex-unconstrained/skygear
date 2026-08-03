extends SceneTree
## IS THE SCENE ACTUALLY STILL? The SG-108 check, in the only place it can
## honestly be run.
##
##   godot --path . --resolution 1600x900 --script tools/still_probe.gd
##
## NOT `--headless`: the whole check is a framebuffer readback and headless has
## no GPU (SG-29). It is registered in the hub as a WINDOWED check so `all` picks
## it up, the same way the text audit is.
##
## WHY THIS EXISTS AS A TOOL AND NOT AS A LINE IN `parity_test.gd`. The harness
## is headless, so it can guard the SOURCE of every photographing tool — and it
## does, see the four `still ·` checks there — but it cannot photograph anything.
## This is the half that needs a frame. Between them: no tool can omit the
## freeze, and the freeze is proved to actually freeze.
##
## THE PRE-COMMITTED ASSERTION, and it is exact rather than "small":
##
##     still · two plates of a frozen scene differ by exactly zero
##
## Zero, not "under the gate". A noise floor that is allowed to be 3% is a noise
## floor that can hide a 3% feature, and DECK-IDENTITY §7.5's whole history is
## answers that turned out to be the floor. SG-107's shadow rig read 53% and
## published three A/B answers against it.
##
## AND IT IS MEASURED THROUGH THE SAME DOOR THE TOOLS USE. An A/B tool toggles
## one thing and re-flushes the renderer between its two plates, so the control
## has to re-flush too. Measuring the bare readback only is how this check
## reported 0.00% while `shadow_probe.gd`'s real comparisons still carried
## everything the re-flush moved — which was 0.97% of the deck region, half of
## the answer it was about to publish.
const DECK_BOX := Rect2i(240, 200, 1160, 620)
## The whole frame, for the diff picture. A number tells you the scene moved; a
## picture tells you WHAT moved, which is the only thing that leads to a fix.
const FULL_BOX := Rect2i(0, 0, 1600, 900)

var _out_dir := "../.shots/still"


func _init() -> void:
	await process_frame
	var argv := OS.get_cmdline_user_args()
	if argv.size() > 0:
		_out_dir = str(argv[0])
	var out_dir := "res://%s" % _out_dir
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))

	var win := get_root()
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1600, 900))
	root.size = Vector2i(1600, 900)
	await process_frame

	var world: Node3D = load("res://scenes/main3d.tscn").instantiate()
	root.add_child(world)
	await process_frame
	var view: SkyGearView3D = world as SkyGearView3D
	var game: SkyGearGame = world.get_node("SkyGear")
	view.cutscenes_enabled = false
	view.stop_cutscene()
	game.log_runs = false
	if game.impact != null:
		game.impact.enabled = false
	game.workshop = SkyGearWorkshop.fresh(true)
	game.refresh_berthed()
	game.set_seed_text("STILL")
	game.begin_run()
	game.choose_draft(0)
	if game.wave != 8:
		game.start_wave(8)
	game.spawn_queue.clear()
	view.sway = false
	var overlay = game.get_node_or_null("HUD")
	if overlay != null:
		overlay.visible = false

	## THE WORST HONEST CASE: a deck carrying every clock this project owns —
	## sixteen rigged figures with walk cycles, the braziers, the vent plumes,
	## the ambient skyships and the drifting cloud bands. A stillness check on an
	## empty deck is a check that cannot fail.
	game.player.global_position = Vector2(0.0, 240.0)
	game.player.velocity = Vector2.ZERO
	var kinds := ["SCRAPPER", "ARMORED", "SWARM", "GUNNER"]
	for i in 16:
		game.spawn_enemy(kinds[i % kinds.size()], 1)
	var live: Array = game.get_tree().get_nodes_in_group("enemies")
	for i in live.size():
		live[i].global_position = Vector2(-540.0 + float(i % 4) * 360.0,
			-260.0 + float(i / 4) * 300.0)
		live[i].state = "move"
	view._focus_set = false
	view._zoom = 1.0
	view._zoom_target = 1.0
	for _i in 30:
		game._process(1.0 / 60.0)
		await process_frame

	var stopped := await SkyGearStill.freeze(self, view, game)
	print("")
	print("  IS THE SCENE ACTUALLY STILL?")
	print("  a wave-8 deck, sixteen boarders and the captain, zoom 1.00")
	print("  stopped: %d AnimationPlayers · %d GPUParticles3D · debanding · fog reprojection"
		% [int(stopped.animation_players), int(stopped.particles)])
	print("")

	var failures := 0

	## 1. THE BARE READBACK. Two exposures, nothing at all in between.
	var bare := await SkyGearStill.floor_pct(self, DECK_BOX)
	failures += _say("two plates of a frozen scene differ by exactly zero", bare)

	## 2. THROUGH THE RE-FLUSH, which is what every A/B tool actually does between
	## its plates. This is the one that caught `_sync_skyships` reading the WALL
	## CLOCK — `Time.get_ticks_msec()`, which answers to no `delta`, no
	## `Engine.time_scale` and no `set_process(false)`.
	var reflush := await SkyGearStill.floor_pct(self, DECK_BOX,
		func() -> void: view._process(0.0))
	failures += _say("and still zero across the re-flush an A/B tool does between plates",
		reflush)

	## 3. AND OVER THE WHOLE FRAME, not just the deck rectangle. A tool that
	## measures a sub-rectangle can be still inside it and moving everywhere else,
	## and the next tool to pick a different rectangle inherits the bug.
	var whole := await SkyGearStill.floor_pct(self, FULL_BOX,
		func() -> void: view._process(0.0))
	failures += _say("and zero over the whole frame, not just the rectangle in use",
		whole)

	## AND WHEN IT IS NOT ZERO, SAY WHERE. A percentage sends the next agent
	## guessing; a mask sends them to the code.
	if failures > 0:
		var a := await SkyGearStill.plate(self, FULL_BOX)
		view._process(0.0)
		var b := await SkyGearStill.plate(self, FULL_BOX,
			"%s/still-plate.png" % out_dir)
		_mask(a, b, "%s/still-diff.png" % out_dir)
		print("")
		print("  WHAT MOVED is in %s/still-diff.png — white is a pixel that changed."
			% _out_dir)

	print("")
	if failures == 0:
		print("  VERDICT: the scene is genuinely still. An A/B measured on this")
		print("           deck is measuring the thing it toggled and nothing else.")
	else:
		print("  VERDICT: THE SCENE IS NOT STILL. Every A/B number measured on it")
		print("           is that motion. Do not publish one until this is zero.")
	print("")
	quit(failures)


func _say(name: String, pct: float) -> int:
	if pct == 0.0:
		print("  ok   still · %s   %.2f%%" % [name, pct])
		return 0
	print("  FAIL still · %s   %.2f%%" % [name, pct])
	return 1


## Where the two plates differ, as a picture.
func _mask(a: PackedFloat32Array, b: PackedFloat32Array, path: String) -> void:
	var step := SkyGearStill.STEP
	var w: int = (FULL_BOX.size.x + step - 1) / step
	var h: int = (FULL_BOX.size.y + step - 1) / step
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	var i := 0
	var y := 0
	while y < h:
		var x := 0
		while x < w:
			var d: float = maxf(absf(a[i] - b[i]), maxf(absf(a[i + 1] - b[i + 1]),
				absf(a[i + 2] - b[i + 2])))
			var v: float = 1.0 if d >= SkyGearStill.MOVED else minf(1.0, d * 20.0)
			img.set_pixel(x, y, Color(v, v, v))
			i += 3
			x += 1
		y += 1
	img.save_png(path)
