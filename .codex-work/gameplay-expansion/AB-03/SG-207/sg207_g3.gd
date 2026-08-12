extends SceneTree

## SG-207 / AB-03 preregistered G3.
##
## One observation from each distinct PULSE1..PULSE120 seed. Both arms perform
## the same accepted, deliberately missing Lance cast with Pulse 0.30 seconds
## from due. The feature-off seam restores the 0.35 seconds that pre-AB-03 did
## not subtract. The crossing group then leaves before that arm's natural Pulse.
## A matched group enters for the later discharge, pairing total damage and RNG
## opportunity exactly while the crossing group remains the measured outcome.

const N := 120
const STEP := 0.05
const WAIT_FOR_FEATURE_OFF := 0.25
const AUTHORED_DAMAGE := 34.0
const GROUP_SIZE := 3


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
	game.skills = [SkyGearData.make_skill("PULSE", "STEAM"),
		SkyGearData.make_skill("LINE_BURST", "STEAM")]
	game.tel = SkyGearTelemetry.fresh(2)
	game.mods.crit_chance = 0.0
	game.mods.crit_explode = 0.0
	game.mods.kill_explode = 0.0
	game.mods.knock_multiplier = 0.0
	game.player.global_position = Vector2.ZERO
	game.player.aim_direction = Vector2.UP
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
	newest.velocity = Vector2.ZERO
	newest.set_physics_process(false)
	return newest


func _group_damage(group: Array[SkyGearEnemy]) -> float:
	var amount := 0.0
	for enemy in group:
		amount += 100.0 - enemy.hp
	return amount


func _observe(game: SkyGearGame, crossing: Array[SkyGearEnemy],
		matched: Array[SkyGearEnemy], control: SkyGearEnemy, feature_on: bool,
		gameplay_state: int, visual_state: int) -> Dictionary:
	var crossing_at := Vector2(160.0, 0.0)
	var far_at := Vector2(650.0, 0.0)
	for index in crossing.size():
		crossing[index].hp = 100.0
		crossing[index].dead = false
		crossing[index].global_position = crossing_at + Vector2(0.0,
			(float(index) - 1.0) * 24.0)
	for index in matched.size():
		matched[index].hp = 100.0
		matched[index].dead = false
		matched[index].global_position = far_at + Vector2(0.0,
			(float(index) - 1.0) * 24.0)
	control.hp = 100.0
	control.dead = false
	control.global_position = Vector2(-650.0, 0.0)
	game.pressure = 0.0
	game.player.set_pressure(0.0)
	game.tel = SkyGearTelemetry.fresh(2)
	game.floaters.clear()
	game.effects.clear()
	game.rng.state = gameplay_state
	game.visual_rng.state = visual_state
	game.skills[0].passive_timer = 0.30
	game.skills[1].cooldown_left = 0.0
	game.skills[1].casts = 0
	var all_hp_before := _group_damage(crossing) + _group_damage(matched)
	game.cast_skill(1, Vector2.UP * 900.0)
	var active_damage := _group_damage(crossing) + _group_damage(matched) \
		- all_hp_before
	if not feature_on:
		## Evidence-only emulation of d123e88: the accepted cast had no Pulse
		## advance. Every other production cast side effect remains intact.
		game.skills[0].passive_timer = float(game.skills[0].passive_timer) + 0.35
	game._update_passives(STEP)
	var crossing_damage := _group_damage(crossing)
	## The crossing closes before the unadvanced scheduler becomes due. Its
	## matched group supplies the same three authored hits to the other arm.
	for index in crossing.size():
		crossing[index].global_position = far_at + Vector2(0.0,
			(float(index) - 1.0) * 24.0)
	for index in matched.size():
		matched[index].global_position = crossing_at + Vector2(0.0,
			(float(index) - 1.0) * 24.0)
	game._update_passives(WAIT_FOR_FEATURE_OFF)
	return {
		"crossing_damage": crossing_damage,
		"matched_damage": _group_damage(matched),
		"combined_damage": _group_damage(crossing) + _group_damage(matched),
		"active_damage": active_damage,
		"control_hp": control.hp,
		"player_hp": game.player.hp,
		"pressure": game.pressure,
		"gameplay_rng": game.rng.state,
		"visual_rng": game.visual_rng.state,
		"floaters": game.floaters.size(),
		"effects": game.effects.size(),
		"pulse_attribution": float(game.tel.per[0].damage),
		"pulse_hits": int(game.tel.per[0].hits),
		"pulse_timer": float(game.skills[0].passive_timer),
		"accepted_casts": int(game.skills[1].casts),
	}


func _physical_fingerprint(row: Dictionary) -> String:
	return JSON.stringify({
		"combined_damage": row.combined_damage,
		"control_hp": row.control_hp,
		"player_hp": row.player_hp,
		"pressure": row.pressure,
		"gameplay_rng": row.gameplay_rng,
		"visual_rng": row.visual_rng,
		"floaters": row.floaters,
		"effects": row.effects,
		"pulse_attribution": row.pulse_attribution,
		"pulse_hits": row.pulse_hits,
		"accepted_casts": row.accepted_casts,
	})


func _sample(index: int) -> Dictionary:
	var seed_text := "PULSE%d" % index
	var game := _new_game(seed_text)
	var crossing: Array[SkyGearEnemy] = []
	var matched: Array[SkyGearEnemy] = []
	for _i in GROUP_SIZE:
		crossing.append(_target(game, Vector2.ZERO))
	for _i in GROUP_SIZE:
		matched.append(_target(game, Vector2.ZERO))
	var control := _target(game, Vector2.ZERO)
	var gameplay_state: int = game.rng.state
	var visual_state: int = game.visual_rng.state
	var feature_off := _observe(game, crossing, matched, control, false,
		gameplay_state, visual_state)
	var candidate := _observe(game, crossing, matched, control, true,
		gameplay_state, visual_state)
	var out := {
		"seed": seed_text,
		"seed_state": gameplay_state,
		"feature_off": feature_off,
		"candidate": candidate,
		"difference": float(candidate.crossing_damage)
			- float(feature_off.crossing_damage),
		"physical_and_rng_match": _physical_fingerprint(feature_off)
			== _physical_fingerprint(candidate),
	}
	game.free()
	return out


func _run() -> void:
	var samples: Array[Dictionary] = []
	var seed_states := {}
	var sum := 0.0
	for index in range(1, N + 1):
		var sample := _sample(index)
		samples.append(sample)
		seed_states[int(sample.seed_state)] = true
		sum += float(sample.difference)
		print("SG207 %s off %.1f candidate %.1f active %.1f rng %s"
			% [sample.seed, sample.feature_off.crossing_damage,
				sample.candidate.crossing_damage,
				sample.candidate.active_damage, sample.physical_and_rng_match])
	var mean := sum / float(N)
	var squares := 0.0
	for sample in samples:
		var delta := float(sample.difference) - mean
		squares += delta * delta
	var sd := sqrt(squares / float(N - 1))
	var half_width := 1.96 * sd / sqrt(float(N))
	var expected_group_damage := AUTHORED_DAMAGE * float(GROUP_SIZE)
	var all_feature_off_zero := samples.all(func(sample):
		return is_equal_approx(float(sample.feature_off.crossing_damage), 0.0))
	var all_candidate_exact := samples.all(func(sample):
		return is_equal_approx(float(sample.candidate.crossing_damage),
			expected_group_damage))
	var all_active_zero := samples.all(func(sample):
		return is_equal_approx(float(sample.feature_off.active_damage), 0.0) \
			and is_equal_approx(float(sample.candidate.active_damage), 0.0))
	var all_physical_match := samples.all(func(sample):
		return bool(sample.physical_and_rng_match))
	## Repetitions audit determinism only and never enter n or the statistics.
	var audit := []
	for index in [1, 2]:
		var first := _sample(index)
		var second := _sample(index)
		audit.append({"seed": "PULSE%d" % index,
			"repeat_match": JSON.stringify(first) == JSON.stringify(second)})
	var audit_pass := audit.all(func(row): return bool(row.repeat_match))
	var passed := seed_states.size() == N and all_feature_off_zero \
		and all_candidate_exact and all_active_zero and all_physical_match \
		and mean > 0.0 and mean > half_width and audit_pass
	var result := {
		"packet": "SG-207",
		"baseline": "d123e88",
		"n_distinct_seeds": N,
		"seed_names": "PULSE1..PULSE120",
		"observations_per_seed": 1,
		"distinct_seed_states": seed_states.size(),
		"primary_statistic": "paired Pulse-attributed damage gain to crossing group",
		"comparison_arms": ["feature-off accepted SG-206 behavior",
			"feature-on AB-03 cast advance"],
		"feature_off_seam": "evidence restores 0.35 after the identical accepted cast",
		"authored_damage_per_hit": AUTHORED_DAMAGE,
		"crossing_group_size": GROUP_SIZE,
		"mean_paired_difference": mean,
		"paired_95_half_width": half_width,
		"feature_off_crossing_zero": all_feature_off_zero,
		"candidate_hits_exact": all_candidate_exact,
		"active_damage_zero": all_active_zero,
		"physical_and_rng_identical": all_physical_match,
		"matched_opportunity_note": "feature-off later Pulse hits matched group after crossing group leaves",
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
	print("SG207 %s n=%d mean=%.3f half-width=%.3f off-zero=%s exact=%s active-zero=%s physical-rng=%s audit=%s"
		% ["PASS" if passed else "FAIL", N, mean, half_width,
			all_feature_off_zero, all_candidate_exact, all_active_zero,
			all_physical_match, audit_pass])
	quit(0 if passed else 1)
