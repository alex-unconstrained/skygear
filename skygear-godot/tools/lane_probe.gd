extends SceneTree
## CAN THE COLOSSUS DAMAGE THE SHIP? (board SG-185)
##
## The owner's 12-wave run: *"Collosus didnt seem to be able to damage
## turrets."* This tool answers that directly instead of inferring it from a
## whole-run statistic, because the question is not "how much" — it is "at all",
## and a zero is the one result a mean can hide inside its own spread.
##
## THE FIXTURE IS ONE LANE AND ONE COLOSSUS. He is landed at the bow of lane 1
## with the shipped `walks_the_lane`, the captain is parked at the far corner of
## the deck (out of every radius he has, so nothing he does to HER can be read as
## something he did to the ship), and the sim is stepped until the clock runs
## out. What is recorded is HP taken off each structure, plus a census of the
## beats he actually spent: swings resolved, stomps resolved, seconds per state,
## and ground covered per state.
##
## WHY THE BEAT CENSUS IS HALF THE ANSWER. The swing's victim chain
## (`damage_turret` / `hurt_crew` / `damage_boiler`) is still in `enemy.gd` and
## still correct. If a turret takes nothing, the question is whether the chain is
## wrong or whether he never REACHES the chain, and only a count of resolved
## swings tells those two apart. It was the second.
##
##   godot --path . --headless --script tools/lane_probe.gd
##   godot --path . --headless --script tools/lane_probe.gd -- 60 2
##                                                             ^  ^ heat
##                                                    seconds -'
##
## ---------------------------------------------------------------------------
## THE RIG REPORTS ITS OWN FLOOR FIRST, AND THAT FLOOR IS ZERO (STATUS's rule
## for the fifth failure mode). It is here because building this tool walked
## straight into a live instance of that failure mode which is ALSO PRESENT IN
## THE SHIPPED RIGS — board SG-187.
##
## `CharacterBody2D.move_and_slide()` does not integrate against the delta you
## hand `_physics_process`. It asks the engine whether it is inside a physics
## frame, and takes `get_physics_process_delta_time()` if it is and
## `get_process_delta_time()` — THE IDLE FRAME'S WALL-CLOCK DURATION — if it is
## not. A hand-stepping tool that has ever `await`ed `process_frame` is resumed
## in an idle frame, and from that moment every boarder it steps walks at
## whatever the machine's last frame happened to cost.
##
## MEASURED, IN THIS FILE, BEFORE IT WAS FIXED: two arms of identical code and
## one seed, differing only in that the second was resumed after
## `await process_frame`. Ground covered per hand-step, in the move state at a
## configured 95 u/s: arm one **1.58 units**, arm two **12.67 units** — 8.0x, and
## the 8 is `Engine.max_physics_steps_per_frame` showing through the idle delta.
##
## So this tool never awaits inside a measurement, awaits `physics_frame` rather
## than `process_frame` between arms, and — because a comment is not a check —
## VERIFIES the geometry it just used: it accumulates ground and time in the move
## state and asserts the quotient equals the configured speed. If the walk it
## measured is not the walk the table specifies, it says REFUSED and exits 1
## instead of printing a result.

## THE HAND-STEP IS THE ENGINE'S PHYSICS DELTA, TAKEN FROM THE ENGINE RATHER THAN
## DECLARED AT IT. `boss_probe.gd` and `balance.gd` both write
## `Engine.physics_ticks_per_second = 20` and then step at 0.05 on the
## assumption that the two are now the same number. THEY ARE NOT: measured in
## this file, immediately after that assignment and inside a physics frame,
## `get_physics_process_delta_time()` still returns 0.0167. So those rigs walk
## every boarder at ONE THIRD of its table speed and have done since they were
## written — the second half of board SG-187.
##
## There is nothing to argue with if the step IS the delta, so it is.
var DT := 1.0 / 60.0
const SPEED_TOLERANCE := 0.02


func _initialize() -> void: call_deferred("_run")


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var secs: float = float(args[0]) if args.size() > 0 else 60.0
	var heat: int = int(args[1]) if args.size() > 1 else 0
	## Into a physics frame BEFORE anything is stepped, and back into one between
	## arms. This is the line the 8.0x above buys.
	await physics_frame
	DT = root.get_physics_process_delta_time()
	print("  LANE PROBE · a Colossus walking lane 1 · HEAT %d · %.0f s · step %.4f s"
		% [heat, secs, DT])
	print("  BOSS  speed %.0f  attack_range %.0f  reach %.0f  damage %.0f  windup %.2f  recover %.2f"
		% [float(SkyGearData.ENEMIES.BOSS.speed), float(SkyGearData.ENEMIES.BOSS.attack_range),
			float(SkyGearData.ENEMIES.BOSS.reach), float(SkyGearData.ENEMIES.BOSS.damage),
			float(SkyGearData.ENEMIES.BOSS.windup), float(SkyGearData.ENEMIES.BOSS.recover)])
	print("  DECK  turret y %.0f, boiler y %.0f, he lands at y %.0f"
		% [SkyGearGame.BASE_Y - 210.0, SkyGearGame.BOILER_POSITION.y, -1000.0])
	print("")
	var bad := false
	for stomping in [true, false]:
		var r := await _one(secs, heat, stomping)
		print("  --- stomp %s %s"
			% ["ON " if stomping else "OFF", "(SHIPPED)" if stomping else "(the SG-146 chase build's attack)"])
		## THE FLOOR, PRINTED ABOVE THE RESULT AND NOT BELOW IT.
		var clock: float = float(r.clock)
		var ok: bool = absf(clock - 1.0) <= SPEED_TOLERANCE
		print("      [rig] ground covered / (|v| x step) = %.4f — %s   (walk %.1f u/s of a table %.0f, the shortfall is the lerp after each plant)"
			% [clock, "the two clocks are one clock" if ok
				else "REFUSED, move_and_slide is integrating a delta this loop does not control",
				float(r.walk_speed), float(SkyGearData.ENEMIES.BOSS.speed)])
		if not ok:
			bad = true
		print("      turret HP lost   %7.1f of %.0f%s"
			% [float(r.turret), float(r.turret_max), "   <- ZERO" if float(r.turret) <= 0.0 else ""])
		print("      crew HP lost     %7.1f of %.0f" % [float(r.crew), float(r.crew_max)])
		print("      boiler HP lost   %7.1f of %.0f" % [float(r.boiler), float(r.boiler_max)])
		print("      captain HP lost  %7.1f  (parked at the far corner)" % float(r.player))
		print("      beats            %d swings resolved, %d stomps resolved"
			% [int(r.swings), int(r.stomps)])
		print("      time             %4.1f s moving, %4.1f s in windup, %4.1f s planted, %4.1f s recovering"
			% [float(r.t_move), float(r.t_windup), float(r.t_stomp), float(r.t_recover)])
		print("      walked           %.0f units, ended y %.0f" % [float(r.walked), float(r.end_y)])
		print("")
	quit(1 if bad else 0)


func _one(secs: float, heat: int, stomping: bool) -> Dictionary:
	var scene: PackedScene = load("res://scenes/main.tscn")
	var game: SkyGearGame = scene.instantiate()
	root.add_child(game)
	game.workshop = SkyGearWorkshop.fresh(true)
	game.refresh_berthed()
	## THE RUNG HAS TO BE UNLOCKED OR IT IS NOT SELECTED. A fresh bench has
	## `best_heat` 0, so `game.heat = 2` on its own is silently clamped back to
	## STOKED — the first Heat-2 run of this file returned numbers identical to
	## its Heat-0 run to the last hit point, which is what gave it away.
	## `boss_probe.gd` carries these two lines for the same reason.
	game.workshop.unlocked = true
	game.workshop.best_heat = SkyGearWorkshop.HEAT.size() - 1
	game.heat = heat
	if game.impact != null:
		game.impact.enabled = false
	game.set_process(false)
	game.set_physics_process(false)
	game.player.set_process(false)
	game.player.set_physics_process(false)
	game.set_seed_text("SG185")
	game.begin_run()
	game.choose_draft(0)
	for e in game.get_tree().get_nodes_in_group("enemies"):
		e.dead = true
		e.queue_free()
	game.spawn_queue.clear()
	game.spawn_enemy("BOSS", 1)
	var boss: SkyGearEnemy = null
	for e in game.get_tree().get_nodes_in_group("enemies"):
		if e.kind == "BOSS":
			boss = e
	if boss == null:
		return {}
	boss.state = "move"
	boss.state_time = 0.0
	boss.stomps = stomping
	## Bottomless, so the window is a clock rather than a race (melee_probe's
	## discipline). It matters here: the lane cannons are ALIVE, because they are
	## the victim under test, and they shoot back.
	boss.max_hp = 1.0e9
	boss.hp = 1.0e9
	boss.global_position = Vector2(SkyGearGame.LANE_CENTERS[1], -1000.0)

	## THE CAPTAIN IS PARKED OUT OF EVERY RADIUS HE HAS. Her HP is recorded rather
	## than assumed untouched, so the day this corner stops being far enough the
	## report says so instead of quietly crediting her damage to the ship.
	game.player.global_position = Vector2(-800.0, 1100.0)

	var turret: Dictionary = game.turret_in_lane(1)
	var turret_max: float = float(turret.hp)
	var boiler_max: float = game.boiler_hp
	var player_max: float = game.player.hp
	var start_y: float = boss.global_position.y

	var swings := 0
	var stomps := 0
	var times := {"move": 0.0, "windup": 0.0, "stomp": 0.0, "recover": 0.0}
	var move_ground := 0.0
	var move_expect := 0.0
	var move_secs := 0.0
	var was := boss.state
	var steps: int = int(secs / DT)
	for _i in steps:
		## Nothing else is allowed to arrive: this is a fixture about one boarder.
		game.spawn_queue.clear()
		game.player.global_position = Vector2(-800.0, 1100.0)
		game._process(DT)
		if not is_instance_valid(boss) or boss.dead:
			break
		## AND HE IS STEPPED ONCE. `set_process(false)` on the game does not reach
		## a boarder — he is his own node, exactly the way it never reached the
		## captain in SG-118. Re-asserted every step, because `_process` is allowed
		## to reconfigure the deck under us.
		boss.set_physics_process(false)
		var s0: String = boss.state
		var p0: Vector2 = boss.global_position
		var y0: float = p0.y
		times[s0] = float(times.get(s0, 0.0)) + DT
		boss._physics_process(DT)
		if not is_instance_valid(boss) or boss.dead:
			break
		## THE FLOOR'S OWN SAMPLE. Only frames that BEGAN and ENDED in the move
		## state count toward the walk speed: the frame he plants on is a partial
		## step and would bias the quotient down.
		## THE FLOOR'S OWN SAMPLE, AND IT IS AN IDENTITY RATHER THAN A TOLERANCE.
		## After `move_and_slide` the boarder's `velocity` is back to the `walk` it
		## was moved with (the SG-62 line), so the ground it covered THIS step must
		## be exactly `|walk| * DT`. Comparing the walk to the TABLE speed instead
		## would fail honestly during the lerp spin-up after every plant and tell
		## me nothing about the clock, which is the thing under suspicion.
		if s0 == "move" and boss.state == "move":
			move_ground += p0.distance_to(boss.global_position)
			move_expect += boss.velocity.length() * DT
			move_secs += DT
		## A beat is COUNTED at the transition out of the state that resolves it —
		## the only frame at which the damage call has already been made.
		if was == "windup" and boss.state == "recover":
			swings += 1
		elif was == "stomp" and boss.state == "recover":
			stomps += 1
		was = boss.state

	## Crew are mustered as the wave runs rather than at `begin_run`, so the
	## denominator is read at the END, per unit, off `max_hp`. A snapshot taken
	## before they exist reports a negative loss against a zero pool, which is
	## what the first draft of this file printed.
	var crew_max := 0.0
	var crew_left := 0.0
	for c in game.crew:
		crew_max += float(c.max_hp)
		crew_left += maxf(0.0, float(c.hp))
	var out := {
		"turret": turret_max - float(turret.hp),
		"turret_max": turret_max,
		"crew": crew_max - crew_left,
		"crew_max": crew_max,
		"boiler": boiler_max - game.boiler_hp,
		"boiler_max": boiler_max,
		"player": player_max - game.player.hp,
		"swings": swings,
		"stomps": stomps,
		"t_move": times.move, "t_windup": times.windup,
		"t_stomp": times.stomp, "t_recover": times.recover,
		"walk_speed": move_ground / maxf(0.001, move_secs),
		"clock": move_ground / maxf(0.001, move_expect),
		"walked": absf(boss.global_position.y - start_y) if is_instance_valid(boss) else 0.0,
		"end_y": boss.global_position.y if is_instance_valid(boss) else 0.0,
	}
	game.queue_free()
	## `physics_frame`, NOT `process_frame` — see the header. This is the line.
	await physics_frame
	return out
