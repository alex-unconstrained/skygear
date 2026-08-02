extends SceneTree
## Frame cost under a load the game can actually produce, with nobody watching.
##
## Every performance conversation on this project has been "it felt laggy"
## against "it profiled clean", with the two sides measuring different things a
## week apart. This measures one thing, the same way, every time:
##
##   godot --path . --script tests/bench.gd
##   godot --path . --script tests/bench.gd -- 90     (boarders)
##
## Deliberately NOT headless — and since SG-54, ENFORCED, not just documented:
## run headless this bench completed happily and printed "PASS p99 6.90 ms"
## measured against no GPU at all (under --headless no rendering device even
## exists — SG-29). A verdict nobody can trust is worse than no verdict.
func _initialize() -> void: call_deferred("_run")

const WARMUP := 90        ## frames discarded: shader compilation lands here
const MEASURE := 420      ## then seven seconds at sixty

func _run() -> void:
	if not SkyGearRendererCheck.can_capture():
		print(SkyGearRendererCheck.capture_refusal())
		quit(2)
		return
	var args := OS.get_cmdline_user_args()
	var load_size: int = int(args[0]) if args.size() > 0 else 60
	var world = load("res://scenes/main3d.tscn").instantiate()
	root.add_child(world)
	await process_frame
	var game: SkyGearGame = world.get_node("SkyGear")
	var view: SkyGearView3D = world as SkyGearView3D
	game.set_seed_text("BENCH")
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

	print("SkyGear bench — %d boarders, %s" % [load_size,
		SkyGearRendererCheck.describe()])
	for i in WARMUP:
		_beat(game, i)
		await process_frame
	## Reset AFTER the warmup, so shader compilation stutter is excluded from
	## the numbers and reported on its own — it is a real problem but it is a
	## different problem from a slow frame.
	var warm := game.profiler.timings()
	game.profiler.reset()
	for i in MEASURE:
		_beat(game, i)
		await process_frame

	print(game.profiler.report(view, game))
	var t := game.profiler.timings()
	print("warmup worst %.1f ms  (shader compilation shows up here)" % float(warm.p99))
	## A verdict, so the run means something without someone interpreting it.
	var ok: bool = float(t.p99) <= 16.7
	print("%s  p99 %.2f ms against a 16.7 ms budget at 60 fps"
		% ["PASS" if ok else "OVER BUDGET", float(t.p99)])
	quit(0 if ok else 1)

## Something happening every frame, or the bench measures an idle deck.
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
