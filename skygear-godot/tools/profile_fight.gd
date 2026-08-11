extends SceneTree
## THE FIRST REAL PROFILE OF THE PORT (SG-25). A saturated wave-11 fight —
## forty boarders, skills casting, bolts in the air — measured windowed on the
## machine the game actually runs on, with the buckets separated:
##
##   frame    what the player feels: wall-clock ms per frame, vsync OFF so the
##            number is the COST of the frame, not the cadence of the monitor
##   script   every _process callback — the sim tick AND the view3d mirror
##            (they are siblings on the same callback; splitting them would
##            mean instrumenting game.gd, which a profiler must not). Bracketed
##            by two stamp nodes at process_priority ±1000, NOT by
##            Performance.TIME_PROCESS — that monitor updates once a second
##            and its snapshot frames read heavier than the frames around them
##   physics  the _physics_process side, bracketed the same way
##   rd-cpu   the RenderingServer's CPU cost preparing the frame
##   rd-gpu   the GPU actually drawing it
##
##   godot --path . --script tools/profile_fight.gd
##   godot --path . --script tools/profile_fight.gd -- 60    (boarders)
##
## Windowed ONLY — under --headless there is no rendering device and nothing
## here means anything (SG-29). Prints p50/p95/p99 per bucket plus what was on
## the deck, and takes no opinion: this tool records, it does not tune.

const WARMUP := 90         ## discarded: shader/pipeline compilation lands here
const MEASURE := 600       ## ten seconds at sixty

func _initialize() -> void: call_deferred("_run")


## The bracketing pair: First runs before every other node's callback, Last
## after, so Last holds the wall-clock span of everything between them.
class StampFirst extends Node:
	var proc_t0 := 0
	var phys_t0 := 0
	func _process(_d: float) -> void: proc_t0 = Time.get_ticks_usec()
	func _physics_process(_d: float) -> void: phys_t0 = Time.get_ticks_usec()


class StampLast extends Node:
	var first: StampFirst
	var proc_ms := 0.0
	var phys_ms := 0.0
	func _process(_d: float) -> void:
		proc_ms = float(Time.get_ticks_usec() - first.proc_t0) / 1000.0
	func _physics_process(_d: float) -> void:
		phys_ms = float(Time.get_ticks_usec() - first.phys_t0) / 1000.0


func _run() -> void:
	if not SkyGearRendererCheck.can_capture():
		print(SkyGearRendererCheck.capture_refusal())
		quit(2)
		return
	var args := OS.get_cmdline_user_args()
	var load_size: int = int(args[0]) if args.size() > 0 else 40

	## Vsync off and the cap released, or every number below is the monitor's
	## refresh interval wearing a lab coat.
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)

	var stamp_first := StampFirst.new()
	stamp_first.process_priority = -1000
	stamp_first.process_physics_priority = -1000
	var stamp_last := StampLast.new()
	stamp_last.first = stamp_first
	stamp_last.process_priority = 1000
	stamp_last.process_physics_priority = 1000
	root.add_child(stamp_first)
	root.add_child(stamp_last)

	var world = load("res://scenes/main3d.tscn").instantiate()
	root.add_child(world)
	await process_frame
	var game: SkyGearGame = world.get_node("SkyGear")
	var view: SkyGearView3D = world as SkyGearView3D
	game.set_seed_text("PROFILE")
	## THE OWNER'S SAVE IS NOT THIS TOOL'S TO TOUCH (board SG-222). Without
	## these two lines `begin_run` runs against the workshop loaded off disk,
	## and a profiling pass that reaches an ending banks scrip into it and
	## writes a fixture row into the real run log. `fresh(true)` sets the
	## `ephemeral` flag that `SkyGearWorkshop.save_state` early-returns on, so
	## nothing reaches `user://` no matter how the run ends.
	game.workshop = SkyGearWorkshop.fresh(true)
	game.log_runs = false
	game.begin_run()
	game.choose_draft(0)
	game.skills.append(SkyGearData.make_skill("AURA", "STEAM"))
	game.skills.append(SkyGearData.make_skill("CHAIN", "ARC"))
	game.start_wave(11)
	game.player.global_position = Vector2(0, 400)
	for i in load_size:
		game.spawn_enemy(["SCRAPPER", "SWARM", "GUNNER", "ARMORED"][i % 4], i % 3)
	for e in game.get_tree().get_nodes_in_group("enemies"):
		e.state = "move"
		e.global_position = game.player.global_position + Vector2(
			randf_range(-700, 700), randf_range(-900, -100))

	print("SkyGear profile — %d boarders, wave %d, %s, vsync off"
		% [load_size, game.wave, SkyGearRendererCheck.describe()])
	print("adapter: %s" % RenderingServer.get_video_adapter_name())

	for i in WARMUP:
		_beat(game, i)
		await process_frame
	game.profiler.reset()

	var frame_ms := PackedFloat64Array()
	var script_ms := PackedFloat64Array()
	var physics_ms := PackedFloat64Array()
	var rd_cpu_ms := PackedFloat64Array()
	var rd_gpu_ms := PackedFloat64Array()
	var counts_mid := {}
	var last_usec := Time.get_ticks_usec()
	for i in MEASURE:
		_beat(game, i)
		await process_frame
		var now := Time.get_ticks_usec()
		frame_ms.append(float(now - last_usec) / 1000.0)
		last_usec = now
		script_ms.append(stamp_last.proc_ms)
		physics_ms.append(stamp_last.phys_ms)
		rd_cpu_ms.append(RenderingServer.viewport_get_measured_render_time_cpu(
			root.get_viewport_rid()))
		rd_gpu_ms.append(RenderingServer.viewport_get_measured_render_time_gpu(
			root.get_viewport_rid()))
		if i == MEASURE / 2:
			counts_mid = SkyGearProfiler.scene_counts(view)
			counts_mid["boarders"] = game.enemy_count()
			counts_mid["effects"] = game.effects.size()
			counts_mid["bolts"] = game.projectiles.size()

	print("%-8s %8s %8s %8s %8s" % ["bucket", "p50", "p95", "p99", "worst"])
	_row("frame", frame_ms)
	_row("script", script_ms)
	_row("physics", physics_ms)
	_row("rd-cpu", rd_cpu_ms)
	_row("rd-gpu", rd_gpu_ms)
	print("mid-measure deck: draws %d   prims %s   vram %.0f MB   nodes %d"
		% [int(counts_mid.get("draw_calls", 0)),
			str(counts_mid.get("primitives", 0)),
			float(counts_mid.get("video_mem", 0)) / 1048576.0,
			int(counts_mid.get("objects", 0))])
	print("  decals %d (+%d free)   billboards %d (+%d free)   rigs %d   emitters %d"
		% [int(counts_mid.get("decals", 0)), int(counts_mid.get("decals_free", 0)),
			int(counts_mid.get("billboards", 0)),
			int(counts_mid.get("billboards_free", 0)),
			int(counts_mid.get("rigs", 0)), int(counts_mid.get("emitters", 0))])
	print("  boarders %d   effects %d   bolts %d"
		% [int(counts_mid.get("boarders", 0)), int(counts_mid.get("effects", 0)),
			int(counts_mid.get("bolts", 0))])
	print(game.profiler.report(view, game))
	quit(0)


func _row(label: String, samples: PackedFloat64Array) -> void:
	var sorted := samples.duplicate()
	sorted.sort()
	var n := sorted.size()
	print("%-8s %8.2f %8.2f %8.2f %8.2f" % [label,
		sorted[n / 2], sorted[mini(n - 1, int(n * 0.95))],
		sorted[mini(n - 1, int(n * 0.99))], sorted[n - 1]])


## Something happening every frame, or this profiles an idle deck. The same
## beat as tests/bench.gd so the two tools' numbers can be laid side by side.
func _beat(game: SkyGearGame, i: int) -> void:
	if i % 7 == 0:
		for slot in game.skills.size():
			game.skills[slot].cooldown_left = 0.0
		game.cast_skill(i % maxi(1, game.skills.size()),
			game.player.global_position + Vector2(randf_range(-300, 300), -280))
	if i % 11 == 0:
		game.spawn_enemy_bolt(game.player.global_position + Vector2(300, -400),
			game.player.global_position, 8.0, 352.0)
	game.player.velocity = Vector2(sin(float(i) * 0.06) * 220.0, cos(float(i) * 0.05) * 160.0)
