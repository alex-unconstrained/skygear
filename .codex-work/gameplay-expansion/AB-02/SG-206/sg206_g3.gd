extends SceneTree

## SG-206 / AB-02 preregistered G3.
##
## One observation from each distinct BAL1..BAL120 seed. The feature-off arm
## leaves Field unset (the shipped live-follow seam); the candidate arm anchors
## it at the scripted landing. The captain then leaves by 190 units: outside the
## 150 Field plus the boarder's body, but inside the unchanged close-pressure
## band. A matched boarder at the captain gives both arms exactly one authored
## Field hit, so damage opportunity and gameplay/visual RNG consumption remain
## paired while the left-behind target is the measured outcome.

const N := 120
const STEP := 0.05
const AUTHORED_TICK := 4.0


func _initialize() -> void:
	call_deferred("_run")


func _new_game(seed_text: String) -> SkyGearGame:
	var scene: PackedScene = load("res://scenes/main.tscn")
	var game: SkyGearGame = scene.instantiate()
	root.add_child(game)
	if game.impact != null:
		game.impact.enabled = false
	game.workshop = SkyGearWorkshop.fresh(true)
	game.refresh_berthed()
	game.set_seed_text(seed_text)
	game.begin_run()
	game.choose_draft(0)
	game.spawn_queue.clear()
	game.hulk = {}
	game.skills = [SkyGearData.make_skill("AURA", "STEAM")]
	game.tel = SkyGearTelemetry.fresh(1)
	game.mods.crit_chance = 0.0
	game.mods.crit_explode = 0.0
	game.mods.kill_explode = 0.0
	game.mods.knock_multiplier = 0.0
	game.player.global_position = Vector2.ZERO
	game._set_state(SkyGearGame.State.PLAY)
	return game


func _target(game: SkyGearGame, at: Vector2) -> SkyGearEnemy:
	game.spawn_enemy("SCRAPPER", 1)
	var newest: SkyGearEnemy = null
	for enemy in game.enemies():
		if newest == null or enemy.spawn_serial > newest.spawn_serial:
			newest = enemy
	newest.state = "move"
	newest.state_time = 0.0
	newest.global_position = at
	newest.hp = 100.0
	newest.max_hp = 100.0
	return newest


func _observe(game: SkyGearGame, target: SkyGearEnemy, matched: SkyGearEnemy,
		control: SkyGearEnemy, landing: Vector2, leave: Vector2, candidate: bool,
		gameplay_state: int, visual_state: int) -> Dictionary:
	for enemy in [target, matched, control]:
		enemy.hp = 100.0
		enemy.max_hp = 100.0
		enemy.dead = false
		enemy.knock_velocity = Vector2.ZERO
	game.player.global_position = leave
	game.pressure = 0.0
	game.player.set_pressure(0.0)
	game.tel = SkyGearTelemetry.fresh(1)
	game.floaters.clear()
	game.effects.clear()
	game.rng.state = gameplay_state
	game.visual_rng.state = visual_state
	game.skills[0].passive_timer = 0.0
	game.skills[0].field_anchor = landing
	game.skills[0].field_anchor_set = candidate
	game._update_passives(STEP)
	return {
		"target_damage": 100.0 - target.hp,
		"matched_damage": 100.0 - matched.hp,
		"control_hp": control.hp,
		"pair_hp": target.hp + matched.hp,
		"player_hp": game.player.hp,
		"pressure": game.pressure,
		"gameplay_rng": game.rng.state,
		"visual_rng": game.visual_rng.state,
		"floaters": game.floaters.size(),
		"effects": game.effects.size(),
		"timer": float(game.skills[0].passive_timer),
	}


func _fingerprint(row: Dictionary) -> String:
	return JSON.stringify({
		"control_hp": row.control_hp,
		"pair_hp": row.pair_hp,
		"player_hp": row.player_hp,
		"pressure": row.pressure,
		"gameplay_rng": row.gameplay_rng,
		"visual_rng": row.visual_rng,
		"floaters": row.floaters,
		"effects": row.effects,
		"timer": row.timer,
	})


func _sample(index: int) -> Dictionary:
	var seed_text := "BAL%d" % index
	var game := _new_game(seed_text)
	var column := (index - 1) % 12
	var row := (index - 1) / 12
	var landing := Vector2(-550.0 + float(column) * 100.0,
		-760.0 + float(row) * 150.0)
	var direction := -1.0 if landing.x > 0.0 else 1.0
	var leave := landing + Vector2(direction * 190.0, 0.0)
	var target := _target(game, landing)
	var matched := _target(game, leave)
	var control := _target(game, landing + Vector2(0.0, 330.0))
	var gameplay_state: int = game.rng.state
	var visual_state: int = game.visual_rng.state
	var follow := _observe(game, target, matched, control, landing, leave, false,
		gameplay_state, visual_state)
	var candidate := _observe(game, target, matched, control, landing, leave, true,
		gameplay_state, visual_state)
	var out := {
		"seed": seed_text,
		"seed_state": gameplay_state,
		"landing": [landing.x, landing.y],
		"leave": [leave.x, leave.y],
		"follow": follow,
		"candidate": candidate,
		"difference": float(candidate.target_damage) - float(follow.target_damage),
		"unrelated_match": _fingerprint(follow) == _fingerprint(candidate),
	}
	game.free()
	return out


func _run() -> void:
	var samples: Array[Dictionary] = []
	var seed_states := {}
	var landings := {}
	var sum := 0.0
	for index in range(1, N + 1):
		var sample := _sample(index)
		samples.append(sample)
		seed_states[int(sample.seed_state)] = true
		landings[str(sample.landing)] = true
		sum += float(sample.difference)
		print("SG206 %s follow %.1f candidate %.1f rng %s"
			% [sample.seed, sample.follow.target_damage,
				sample.candidate.target_damage, sample.unrelated_match])
	var mean := sum / float(N)
	var squares := 0.0
	for sample in samples:
		var delta := float(sample.difference) - mean
		squares += delta * delta
	var sd := sqrt(squares / float(N - 1))
	var half_width := 1.96 * sd / sqrt(float(N))
	var all_follow_zero := samples.all(func(sample):
		return is_equal_approx(float(sample.follow.target_damage), 0.0))
	var all_ticks_exact := samples.all(func(sample):
		return is_equal_approx(float(sample.candidate.target_damage), AUTHORED_TICK) \
			and is_equal_approx(float(sample.candidate.matched_damage), 0.0) \
			and is_equal_approx(float(sample.follow.matched_damage), AUTHORED_TICK))
	var all_unrelated_match := samples.all(func(sample):
		return bool(sample.unrelated_match))
	## Repetitions audit determinism only and never enter n or the statistics.
	var audit := []
	for index in [1, 2]:
		var first := _sample(index)
		var second := _sample(index)
		audit.append({"seed": "BAL%d" % index,
			"repeat_match": JSON.stringify(first) == JSON.stringify(second)})
	var audit_pass := audit.all(func(row): return bool(row.repeat_match))
	var passed := seed_states.size() == N and landings.size() == N \
		and all_follow_zero and all_ticks_exact and all_unrelated_match \
		and mean > 0.0 and mean > half_width and audit_pass
	var result := {
		"packet": "SG-206",
		"baseline": "f9aa3b2",
		"n_distinct_seeds": N,
		"observations_per_seed": 1,
		"distinct_seed_states": seed_states.size(),
		"distinct_scripted_landings": landings.size(),
		"primary_statistic": "paired candidate-minus-follow damage to left-behind target",
		"comparison_arms": ["feature-off live follow", "anchored candidate"],
		"feature_off_seam": "AURA field_anchor_set=false",
		"authored_tick": AUTHORED_TICK,
		"mean_paired_difference": mean,
		"paired_95_half_width": half_width,
		"follow_zero": all_follow_zero,
		"candidate_ticks_exact": all_ticks_exact,
		"unrelated_physical_and_rng_identical": all_unrelated_match,
		"repetition_audit_effective_n": 0,
		"repetition_audit": audit,
		"tuning_pass": "none",
		"passed": passed,
		"samples": samples,
	}
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		var file := FileAccess.open(str(args[0]), FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(result, "  "))
	print("SG206 %s n=%d mean=%.3f half-width=%.3f follow-zero=%s exact=%s unrelated=%s audit=%s"
		% ["PASS" if passed else "FAIL", N, mean, half_width,
			all_follow_zero, all_ticks_exact, all_unrelated_match, audit_pass])
	quit(0 if passed else 1)
