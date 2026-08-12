extends SceneTree

const SAMPLE_TIMES := [0.0, 0.12, 0.24, 0.36]
const TRACE_SALT := 0x0B3A601


func _initialize() -> void:
	call_deferred("_run")


func _v(v: Vector2) -> Array:
	return [snappedf(v.x, 0.000001), snappedf(v.y, 0.000001)]


func _has_property(object: Object, wanted: String) -> bool:
	for row in object.get_property_list():
		if str(row.name) == wanted:
			return true
	return false


func _fingerprint(row: Dictionary) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(JSON.stringify(row, "", false).to_utf8_buffer())
	return context.finish().hex_encode()


func _trace(seed_text: String, arm: String) -> Dictionary:
	var trace_rng := RandomNumberGenerator.new()
	trace_rng.seed = hash(seed_text) ^ TRACE_SALT
	var angle := trace_rng.randf_range(-0.35, 0.35)
	var direction := Vector2(sin(angle), -cos(angle))
	var tangent := Vector2(-direction.y, direction.x)
	var distance := trace_rng.randf_range(250.0, 360.0)
	var speed := trace_rng.randf_range(360.0, 520.0)
	if trace_rng.randi_range(0, 1) == 0:
		speed *= -1.0
	var origin := Vector2(0.0, 400.0)
	var initial := origin + direction * distance
	var velocity := tangent * speed
	var positions: Array = []
	for elapsed in SAMPLE_TIMES:
		positions.append(initial if arm == "control"
			else initial + velocity * float(elapsed))

	var scene := load("res://scenes/main.tscn") as PackedScene
	var game: SkyGearGame = scene.instantiate()
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.player.set_process(false)
	game.player.set_physics_process(false)
	if game.impact != null:
		game.impact.enabled = false
	game.set_seed_text(seed_text)
	game.state = SkyGearGame.State.PLAY
	game.state_name = "PLAY"
	game.wave = 1
	game.spawn_queue.clear()
	game.skills.clear()
	game.skills.append(SkyGearData.make_skill("RAY", "EMBER"))
	game.mods.crit_chance = 0.0
	game.mods.crit_explode = 0.0
	game.mods.kill_explode = 0.0
	game.mods.residue = 0.0
	game.mods.fifth_gear = false
	game.player.global_position = origin
	game.player.velocity = Vector2.ZERO
	game.spawn_enemy("ARMORED", 1)
	var target: SkyGearEnemy = game.enemies()[0] as SkyGearEnemy
	target.set_process(false)
	target.set_physics_process(false)
	target.state = "move"
	target.state_time = 0.0
	target.max_hp = 1000.0
	target.hp = 1000.0
	target.global_position = positions[0]

	var stats: Dictionary = game.skill_stats(game.skills[0])
	var forced: Variant = positions[0] if arm == "explicit" else null
	game.set_cursor_ground(positions[0])
	game.player._update_aim()
	var rng_before := str(game.rng.state)
	if arm == "explicit":
		game.cast_skill(0, forced)
	else:
		game.cast_skill(0)
	var rng_after_press := str(game.rng.state)
	var beam_line: Dictionary = game.active_channel_line()
	var beam_to: Vector2 = beam_line.get("to", Vector2.ZERO)

	var samples: Array = []
	for i in SAMPLE_TIMES.size():
		if i > 0:
			target.global_position = positions[i]
			if arm in ["live", "control"]:
				game.set_cursor_ground(positions[i])
				game.player._update_aim()
			game._process(float(SAMPLE_TIMES[i]) - float(SAMPLE_TIMES[i - 1]))
		var aim_point: Vector2 = positions[0] if arm == "explicit" else positions[i]
		var ray_direction := (aim_point - game.player.global_position).normalized()
		var ray_end: Vector2 = game.player.global_position + ray_direction * float(stats.range)
		var line_distance: float = game._distance_to_segment(
			target.global_position, game.player.global_position, ray_end)
		var active := false
		if _has_property(game, "active_channel"):
			active = not (game.get("active_channel") as Dictionary).is_empty()
		samples.append({
			"elapsed": SAMPLE_TIMES[i],
			"target": _v(target.global_position),
			"aim": _v(aim_point),
			"ray_end": _v(ray_end),
			"line_distance": snappedf(line_distance, 0.000001),
			"geometry_hit": line_distance <= float(stats.width) + target.radius,
			"hp": snappedf(target.hp, 0.000001),
			"slot_damage": snappedf(float(game.tel.per[0].damage), 0.000001),
			"slot_hits": int(game.tel.per[0].hits),
			"active_channel": active,
		})

	var row := {
		"schema": "beam-moving-target-trace-v1",
		"seed": seed_text,
		"arm": arm,
		"call": "cast_skill(0, explicit Vector2)" if arm == "explicit" else "cast_skill(0)",
		"origin": _v(origin),
		"initial_target": _v(initial),
		"target_velocity": _v(velocity),
		"sample_times": SAMPLE_TIMES,
		"shape": "RAY",
		"element": "EMBER",
		"range": stats.range,
		"width": stats.width,
		"damage_per_table": stats.damage,
		"beam_endpoint_on_press": _v(beam_to),
		"hp_delta": snappedf(1000.0 - target.hp, 0.000001),
		"casts": int(game.tel.per[0].casts),
		"hits": int(game.tel.per[0].hits),
		"slot_damage": snappedf(float(game.tel.per[0].damage), 0.000001),
		"burn_stacks": target.burn_stacks,
		"selected_element_applications": 1 if target.burn_stacks > 0 else 0,
		"status_reaction_damage": 0.0,
		"crit_explosion_damage": 0.0,
		"rng_before_press": rng_before,
		"rng_after_press": rng_after_press,
		"active_channel_property_present": _has_property(game, "active_channel"),
		"samples": samples,
	}
	game.free()
	return row


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var requested := int(args[0]) if args.size() > 0 else 120
	var repetitions := int(args[1]) if args.size() > 1 else 2
	var output := (args[2] if args.size() > 2
		else "res://../.codex-work/gameplay-expansion/AB-01/pre-baseline")
	var output_abs := ProjectSettings.globalize_path(output)
	DirAccess.make_dir_recursive_absolute(output_abs)
	var traces := FileAccess.open(output_abs.path_join("traces.jsonl"), FileAccess.WRITE)
	var first: Dictionary = {}
	var divergence: Array = []
	var hp_by_arm := {"live": [], "explicit": [], "control": []}
	var paired_deltas: Array[float] = []
	for repetition in repetitions:
		for number in range(1, requested + 1):
			var seed_text := "BEAM%d" % number
			var first_rep_damage := {}
			for arm in ["live", "explicit", "control"]:
				var row := _trace(seed_text, arm)
				var fingerprint := _fingerprint(row)
				var key := "%s/%s" % [seed_text, arm]
				if repetition == 0:
					first[key] = fingerprint
					row["fingerprint_sha256"] = fingerprint
					traces.store_line(JSON.stringify(row, "", false))
					(hp_by_arm[arm] as Array).append(float(row.hp_delta))
					first_rep_damage[arm] = float(row.hp_delta)
				elif str(first.get(key, "")) != fingerprint:
					divergence.append({"seed": seed_text, "arm": arm,
						"repetition": repetition + 1, "expected": first.get(key, ""),
						"actual": fingerprint})
			if repetition == 0:
				paired_deltas.append(float(first_rep_damage.live)
					- float(first_rep_damage.explicit))
	traces.close()
	var means := {}
	for arm in hp_by_arm:
		var sum := 0.0
		for amount in hp_by_arm[arm]:
			sum += float(amount)
		means[arm] = sum / maxf(1.0, float((hp_by_arm[arm] as Array).size()))
	var paired_mean := 0.0
	for amount in paired_deltas:
		paired_mean += amount
	paired_mean /= maxf(1.0, float(paired_deltas.size()))
	var paired_ss := 0.0
	for amount in paired_deltas:
		paired_ss += pow(float(amount) - paired_mean, 2.0)
	var paired_sd := sqrt(paired_ss / maxf(1.0, float(paired_deltas.size() - 1)))
	var paired_half_width := 1.96 * paired_sd / sqrt(maxf(1.0,
		float(paired_deltas.size())))
	var live_full := true
	for amount in hp_by_arm.live:
		live_full = live_full and is_equal_approx(float(amount), 28.0)
	var control_full := true
	for amount in hp_by_arm.control:
		control_full = control_full and is_equal_approx(float(amount), 28.0)
	var resolution_pass := paired_mean > 0.0 and paired_mean > paired_half_width
	var summary := {
		"schema": "beam-moving-target-summary-v1",
		"requested_distinct_seeds": requested,
		"seed_first": "BEAM1",
		"seed_last": "BEAM%d" % requested,
		"arms": ["live", "explicit"],
		"control": "full_stay",
		"canonical_trace_rows": requested * 3,
		"repetitions": repetitions,
		"effective_n_per_arm": requested,
		"repetitions_increase_effective_n": false,
		"determinism_pass": divergence.is_empty(),
		"divergence": divergence,
		"mean_hp_delta": means,
		"paired_live_minus_explicit_mean": paired_mean,
		"paired_95_half_width": paired_half_width,
		"resolution_pass": resolution_pass,
		"live_full_28_pass": live_full,
		"full_stay_28_pass": control_full,
		"selected_element_applications_per_accepted_body_channel": 1,
		"status_reaction_damage": 0.0,
		"crit_explosion_damage": 0.0,
		"source_contract": {
			"live": "set_cursor_ground(target); player._update_aim(); cast_skill(0)",
			"explicit": "cast_skill(0, initial_target Vector2)",
			"target_motion": "manual positions at elapsed 0.00, 0.12, 0.24, 0.36",
			"control": "production live aim; target remains inside line for all four ticks",
			"simulation_step": "game._process(delta); enemy physics disabled",
		},
	}
	var summary_file := FileAccess.open(output_abs.path_join("summary.json"), FileAccess.WRITE)
	summary_file.store_string(JSON.stringify(summary, "  ", false) + "\n")
	summary_file.close()
	print(JSON.stringify(summary, "", false))
	quit(0 if divergence.is_empty() and resolution_pass and live_full and control_full
		else 2)
