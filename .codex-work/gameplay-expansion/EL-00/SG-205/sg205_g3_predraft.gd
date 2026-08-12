extends "res://../.codex-work/gameplay-expansion/EL-00/SG-203/sg203_fixture.gd"

## EL-00's causal G3 ends before the next targeted draft can consume the
## attribution being measured. The off arm below is the exact old burn tick,
## kept in evidence only; the on arm drives production _update_statuses().
const SG205_OUT := "res://../.codex-work/gameplay-expansion/EL-00/SG-205"
const SG203_BASELINE := "res://../.codex-work/gameplay-expansion/EL-00/SG-203/feature-off-120.json"
const SG204_CONTROL := "res://../.codex-work/gameplay-expansion/EL-00/SG-204/control-a.json"
const THIS_DRIVER := SG205_OUT + "/sg205_g3_predraft.gd"
const PARENT_ENEMY_BLOB := "8372ab10b302e5e13e571eeb2bb6d21c01756d00"


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var requested := int(args[0]) if args.size() > 0 else 120
	if requested != 120:
		push_error("SG-205 G3 requires exactly 120 distinct BAL seeds")
		quit(2)
		return
	await physics_frame
	out_dir = ProjectSettings.globalize_path(SG205_OUT)
	DirAccess.make_dir_recursive_absolute(out_dir)
	var baseline: Dictionary = _read_json(SG203_BASELINE)
	var expected: Array[String] = []
	for i in requested:
		expected.append("BAL%d" % (i + 1))
	var user_before := _user_hashes()

	## One excluded process warm-up, exactly as the corrected balance instrument.
	await _pair("BAL-WARMUP", 0)
	var rows: Array = []
	var physical_mismatches: Array = []
	var attribution_mismatches: Array = []
	for i in requested:
		var seed := expected[i]
		var pair: Dictionary = await _pair(seed, i)
		rows.append(pair)
		if not bool(pair.physical_match):
			physical_mismatches.append({
				"seed": seed, "off": pair.off.physical, "on": pair.on.physical,
			})
		if not bool(pair.attribution_match):
			attribution_mismatches.append({
				"seed": seed,
				"primary_increase": pair.primary_increase,
				"burn_damage": pair.burn_damage,
			})
		print("SG205 %-6s physical %s attribution %.2f / BURN %.2f" % [
			seed, "match" if bool(pair.physical_match) else "DIFF",
			float(pair.primary_increase), float(pair.burn_damage)])

	var repeats: Array = []
	for item in [{"seed": "BAL1", "index": 0}, {"seed": "BAL2", "index": 1}]:
		var again: Dictionary = await _pair(str(item.seed), int(item.index))
		var original: Dictionary = rows[int(item.index)]
		repeats.append({
			"seed": str(item.seed),
			"original_fingerprint": str(original.fingerprint),
			"repeat_fingerprint": str(again.fingerprint),
			"match": str(original.fingerprint) == str(again.fingerprint),
		})

	var control := await _focused_non_ember()
	var baseline_control: Dictionary = _read_json(SG204_CONTROL)
	var control_bytes := JSON.stringify(control.report_record, "	").to_utf8_buffer()
	var baseline_control_bytes := JSON.stringify(
		baseline_control.report_record, "	").to_utf8_buffer()
	var user_after := _user_hashes()
	var baseline_seeds: Array = baseline.get("seeds", [])
	var checks := {
		"requested_120_distinct": expected.size() == 120
			and baseline_seeds == expected,
		"effective_n_is_distinct_seed_count": rows.size() == 120,
		"repetitions_do_not_inflate_n": rows.size() == 120
			and repeats.size() == 2,
		"repeat_fingerprints_match": _all_repeat_matches(repeats),
		"all_preconsumer_physical_fingerprints_match":
			physical_mismatches.is_empty(),
		"every_primary_increase_equals_burn_reaction_damage":
			attribution_mismatches.is_empty(),
		"all_five_source_slots_are_exercised": _source_slots(rows)
			== [0, 1, 2, 3, 4],
		"one_two_and_three_stacks_are_exercised": _stack_counts(rows)
			== [1, 2, 3],
		"near_and_far_physical_arms_are_exercised": _range_arms(rows)
			== ["far", "near"],
		"true_non_ember_control_is_byte_identical":
			_sha256(control_bytes) == str(baseline_control.fingerprint),
		"true_non_ember_has_no_burn":
			int(control.burn_stacks) == 0
			and (control.reaction_rows as Array).is_empty(),
		"true_non_ember_rng_is_unchanged":
			str(control.rng_before) == str(control.rng_after)
			and str(control.visual_rng_before) == str(control.visual_rng_after),
		"evidence_driver_writes_no_user_file": user_before == user_after,
	}
	var passed := true
	for key in checks:
		if not bool(checks[key]):
			passed = false
			push_error("SG-205 G3 failed: %s" % str(key))

	_write_json("g3-preconsumer-120.json", {
		"schema": "sg205-preconsumer-paired-v2",
		"feature_off": "exact pre-EL burn tick in evidence only",
		"accepted_parent": "e870b6a",
		"parent_enemy_blob": PARENT_ENEMY_BLOB,
		"legacy_schedule": "burn_tick += 0.25",
		"legacy_formula": "5.0 * burn_stacks * 0.25",
		"feature_on": "production enemy._update_statuses",
		"consumer_boundary": "ends before any targeted upgrade draft",
		"sg203_baseline_sha256": _file_hash(SG203_BASELINE),
		"requested": 120,
		"distinct": expected.size(),
		"repetitions": 1,
		"effective_n": rows.size(),
		"seeds": expected,
		"rows": rows,
		"repeat_audit": repeats,
	})
	_write_json("g3-result.json", {
		"packet": "SG-205",
		"result": "PASS" if passed else "FAIL",
		"driver_sha256": _file_hash(THIS_DRIVER),
		"accepted_parent": "e870b6a",
		"parent_enemy_blob": PARENT_ENEMY_BLOB,
		"sg203_baseline_sha256": _file_hash(SG203_BASELINE),
		"sample": {"requested": 120, "distinct": expected.size(),
			"repetitions": 1, "effective_n": rows.size()},
		"checks": checks,
		"physical_mismatches": physical_mismatches,
		"attribution_mismatches": attribution_mismatches,
		"repeat_audit": repeats,
		"control_fingerprint": _sha256(control_bytes),
		"baseline_control_fingerprint": str(baseline_control.fingerprint),
		"user_before": user_before,
		"user_after": user_after,
	})
	_write_v2(rows[0], "damage-attribution-v2-ember.txt")
	_write_non_ember(control)
	print("SG205 %s n=%d physical-diffs=%d attribution-diffs=%d" % [
		"PASS" if passed else "FAIL", rows.size(),
		physical_mismatches.size(), attribution_mismatches.size()])
	quit(0 if passed else 1)


func _pair(seed: String, index: int) -> Dictionary:
	var feature_off: Dictionary = await _arm(seed, index, false)
	var feature_on: Dictionary = await _arm(seed, index, true)
	var primary_increase := float(feature_on.primary_damage) \
		- float(feature_off.primary_damage)
	var burn_damage := float(feature_on.burn_damage)
	var row := {
		"seed": seed,
		"source_slot": int(feature_on.source_slot),
		"stacks": int(feature_on.stacks),
		"range_arm": str(feature_on.range_arm),
		"off": feature_off,
		"on": feature_on,
		"physical_match": feature_off.physical == feature_on.physical,
		"primary_increase": primary_increase,
		"burn_damage": burn_damage,
		"attribution_match": absf(primary_increase - burn_damage) <= 0.000001,
	}
	row["fingerprint"] = _fingerprint(row)
	return row


func _arm(seed: String, index: int, feature_on: bool) -> Dictionary:
	var game: SkyGearGame = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	game.workshop = SkyGearWorkshop.fresh(true)
	game.refresh_berthed()
	game.log_runs = false
	game.set_process(false)
	game.set_physics_process(false)
	game.player.set_process(false)
	game.player.set_physics_process(false)
	if game.impact != null:
		game.impact.enabled = false
	game.view = null
	game.set_seed_text(seed)
	game.begin_run()
	game.skills.clear()
	game.skills.append(SkyGearData.make_skill("RAY", "EMBER"))
	game.tel = SkyGearTelemetry.fresh(5)
	var source_slot := index % 5
	var stacks := index % 3 + 1
	var range_arm := "near" if index % 2 == 0 else "far"
	var target_position := Vector2(0.0, -100.0 if range_arm == "near" else -500.0)
	game.player.global_position = Vector2.ZERO
	game.player.hp = game.player.max_hp - 20.0
	game.pressure = 0.0
	game.player.set_pressure(0.0)
	game.mods.crit_chance = 0.0
	game.mods.crit_explode = 0.0
	game.mods.kill_explode = 0.0
	game.mods.lifesteal = 0.2
	game.spawn_enemy("SCRAPPER", 1)
	var live := game.get_tree().get_nodes_in_group("enemies")
	var enemy: SkyGearEnemy = live[live.size() - 1]
	enemy.state = "move"
	enemy.state_time = 0.0
	enemy.global_position = target_position
	enemy.hp = 1000.0
	enemy.max_hp = 1000.0
	game.src_slot = source_slot
	for _stack in stacks:
		game.damage_enemy(enemy, 0.5, "EMBER", 0.0,
			game.player.global_position, true, false)
	var rng_before := str(game.rng.state)
	var visual_rng_before := str(game.visual_rng.state)
	if feature_on:
		enemy._update_statuses(0.25)
	else:
		## Exact pre-EL tick. This is the declared feature-off seam and remains
		## outside production: carry 0.25, subtract HP, register physical payout.
		enemy.slow_time = maxf(0.0, enemy.slow_time - 0.25)
		enemy.stun_time = maxf(0.0, enemy.stun_time - 0.25)
		enemy.burn_time -= 0.25
		enemy.burn_tick -= 0.25
		if enemy.burn_tick <= 0.0:
			enemy.burn_tick += 0.25
			if enemy.can_be_hit():
				var amount := 5.0 * enemy.burn_stacks * 0.25
				var dealt := minf(enemy.hp, amount)
				enemy.hp -= amount
				game.register_damage(dealt, enemy.global_position)
	var physical := {
		"enemy_hp": enemy.hp,
		"burn_time": enemy.burn_time,
		"burn_tick": enemy.burn_tick,
		"burn_stacks": enemy.burn_stacks,
		"player_hp": game.player.hp,
		"pressure": game.pressure,
		"rng_state": str(game.rng.state),
		"visual_rng_state": str(game.visual_rng.state),
		"run_time": game.run_time,
	}
	var primary_damage := float(game.tel.basic.damage)
	for raw in game.tel.per:
		primary_damage += float((raw as Dictionary).damage)
	var burn_damage := 0.0
	var burn_triggers := 0
	if game.tel.reactions.has("BURN"):
		burn_damage = float(game.tel.reactions.BURN.damage)
		burn_triggers = int(game.tel.reactions.BURN.triggers)
	var out := {
		"arm": "on" if feature_on else "off",
		"source_slot": source_slot,
		"stacks": stacks,
		"range_arm": range_arm,
		"physical": physical,
		"primary_damage": primary_damage,
		"burn_damage": burn_damage,
		"burn_triggers": burn_triggers,
		"source_row": (game.tel.per[source_slot] as Dictionary).duplicate(true),
		"rng_unchanged": str(game.rng.state) == rng_before,
		"visual_rng_unchanged": str(game.visual_rng.state) == visual_rng_before,
	}
	game.queue_free()
	await physics_frame
	return out


func _focused_non_ember() -> Dictionary:
	var game: SkyGearGame = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	game.workshop = SkyGearWorkshop.fresh(true)
	game.refresh_berthed()
	game.log_runs = false
	game.set_process(false)
	game.set_physics_process(false)
	game.player.set_process(false)
	game.player.set_physics_process(false)
	if game.impact != null:
		game.impact.enabled = false
	game.view = null
	game.auto_element = "FROST"
	game.set_seed_text("SG204-TRUE-NON-EMBER")
	game.begin_run()
	game.skills.clear()
	game.skills.append(SkyGearData.make_skill("RANGED_AOE", "FROST"))
	game.tel = SkyGearTelemetry.fresh(game.skill_capacity())
	SkyGearTelemetry.note_cast(game.tel, 0, game.skills[0])
	game.spawn_enemy("SCRAPPER", 1)
	var live := game.get_tree().get_nodes_in_group("enemies")
	var enemy: SkyGearEnemy = live[live.size() - 1]
	enemy.state = "move"
	enemy.state_time = 0.0
	enemy.global_position = Vector2(0.0, -100.0)
	var rng_before := str(game.rng.state)
	var visual_rng_before := str(game.visual_rng.state)
	game.src_slot = -1
	game.damage_enemy(enemy, 0.5, "FROST", 0.0,
		enemy.global_position, false, false)
	game.src_slot = 0
	game.damage_enemy(enemy, 0.4, "FROST", 0.0,
		enemy.global_position, false, false)
	game.src_slot = -1
	var rng_after := str(game.rng.state)
	var visual_rng_after := str(game.visual_rng.state)
	var per_rows: Array = []
	for i in game.tel.per.size():
		var row: Dictionary = (game.tel.per[i] as Dictionary).duplicate(true)
		row["slot"] = i
		per_rows.append(row)
	var reaction_rows := _reaction_rows(game.tel)
	var report_record := {
		"schema": "damage-attribution-v1-focused-control",
		"seed": game.seed_text,
		"arm": "true non-Ember, no environmental Ember sources",
		"auto_element": game.auto_element_id(),
		"equipped_elements": ["FROST"],
		"basic": (game.tel.basic as Dictionary).duplicate(true),
		"per_slot": per_rows,
		"allies": (game.tel.allies as Dictionary).duplicate(true),
		"deck": (game.tel.deck as Dictionary).duplicate(true),
		"reaction_rows": reaction_rows,
		"enemy_hp": enemy.hp,
		"burn_stacks": enemy.burn_stacks,
	}
	var out := {
		"report_record": report_record,
		"burn_stacks": int(enemy.burn_stacks),
		"reaction_rows": reaction_rows,
		"rng_before": rng_before,
		"rng_after": rng_after,
		"visual_rng_before": visual_rng_before,
		"visual_rng_after": visual_rng_after,
	}
	game.queue_free()
	await physics_frame
	return out


func _source_slots(rows: Array) -> Array:
	var out: Array = []
	for row in rows:
		if not int(row.source_slot) in out:
			out.append(int(row.source_slot))
	out.sort()
	return out


func _stack_counts(rows: Array) -> Array:
	var out: Array = []
	for row in rows:
		if not int(row.stacks) in out:
			out.append(int(row.stacks))
	out.sort()
	return out


func _range_arms(rows: Array) -> Array:
	var out: Array = []
	for row in rows:
		if not str(row.range_arm) in out:
			out.append(str(row.range_arm))
	out.sort()
	return out


func _read_json(path: String) -> Dictionary:
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return value if value is Dictionary else {}


func _file_hash(path: String) -> String:
	return _sha256(FileAccess.get_file_as_bytes(
		ProjectSettings.globalize_path(path)))


func _user_hashes() -> Dictionary:
	var out := {}
	for name in ["runs.json", "keys.cfg", "workshop.json", "settings.cfg"]:
		var path := ProjectSettings.globalize_path("user://" + name)
		out[name] = _sha256(FileAccess.get_file_as_bytes(path)) \
			if FileAccess.file_exists(path) else "ABSENT"
	return out


func _write_v2(row: Dictionary, name: String) -> void:
	var file := FileAccess.open(out_dir.path_join(name), FileAccess.WRITE)
	file.store_string("damage attribution v2\n"
		+ "seed: %s\n" % str(row.seed)
		+ "feature-off primary: %.3f\n" % float(row.off.primary_damage)
		+ "feature-on primary: %.3f\n" % float(row.on.primary_damage)
		+ "BURN reaction damage: %.3f\n" % float(row.burn_damage)
		+ "physical match: %s\n" % str(row.physical_match)
		+ "source row: %s\n" % JSON.stringify(row.on.source_row))
	file.close()


func _write_non_ember(control: Dictionary) -> void:
	var file := FileAccess.open(out_dir.path_join(
		"damage-attribution-v2-true-non-ember.txt"), FileAccess.WRITE)
	file.store_string("damage attribution v2\n"
		+ "focused true-non-Ember control remains byte-identical to SG-204\n"
		+ "record: %s\n" % JSON.stringify(control.report_record))
	file.close()
