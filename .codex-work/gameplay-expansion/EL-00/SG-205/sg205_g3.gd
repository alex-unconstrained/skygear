extends "res://../.codex-work/gameplay-expansion/EL-00/SG-203/sg203_fixture.gd"

## INVALID DIAGNOSTIC, RETAINED ONLY WITH g3-first-fail.log. This whole-run
## construction crosses targeted upgrade drafts, whose weights consume the
## attribution EL-00 intentionally changes. Do not quote it as a gameplay A/B.
## The authoritative pre-consumer instrument is sg205_g3_predraft.gd.

const OUTPUT_REL := "res://../.codex-work/gameplay-expansion/EL-00/SG-205"
const BASELINE_REL := "res://../.codex-work/gameplay-expansion/EL-00/SG-203/feature-off-120.json"
const CONTROL_REL := "res://../.codex-work/gameplay-expansion/EL-00/SG-204/control-a.json"
const SG205_DRIVER_REL := OUTPUT_REL + "/sg205_g3.gd"


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var requested := int(args[0]) if args.size() > 0 else 120
	if requested != 120:
		push_error("SG-205 G3 requires exactly 120 distinct BAL seeds")
		quit(2)
		return
	Engine.physics_ticks_per_second = 20
	await physics_frame
	out_dir = ProjectSettings.globalize_path(OUTPUT_REL)
	DirAccess.make_dir_recursive_absolute(out_dir)
	var baseline: Dictionary = _read_json(BASELINE_REL)
	var baseline_by_seed := {}
	for raw in baseline.get("runs", []):
		var row: Dictionary = raw
		baseline_by_seed[str(row.seed)] = row
	var user_before := _user_fingerprints()

	print("SG205 WARM-UP BAL-WARMUP (excluded)")
	await _one("BAL-WARMUP", "")
	var runs: Array = []
	var physical_mismatches: Array = []
	var attribution_mismatches: Array = []
	var seed_names: Array[String] = []
	for i in requested:
		var seed := "BAL%d" % (i + 1)
		var current: Dictionary = await _one(seed, "")
		var before: Dictionary = baseline_by_seed.get(seed, {})
		var current_physical := _physical(current)
		var baseline_physical := _physical(before)
		current["physical_fingerprint"] = _fingerprint(current_physical)
		current["baseline_physical_fingerprint"] = _fingerprint(baseline_physical)
		var physical_match := current_physical == baseline_physical
		current["physical_match"] = physical_match
		if not physical_match:
			physical_mismatches.append({
				"seed": seed, "before": baseline_physical,
				"after": current_physical,
			})
		var increase := _player_damage(current) - _player_damage(before)
		var burn := _burn_damage(current)
		current["primary_attribution_increase"] = increase
		current["burn_reaction_damage"] = burn
		var attribution_match := absf(increase - burn) <= 0.001
		current["attribution_match"] = attribution_match
		if not attribution_match:
			attribution_mismatches.append({
				"seed": seed, "increase": increase, "burn": burn,
			})
		runs.append(current)
		seed_names.append(seed)
		print("SG205 %-6s physical %s attribution %.2f / BURN %.2f" % [
			seed, "match" if physical_match else "DIFF", increase, burn])

	var repeats: Array = []
	for seed in ["BAL1", "BAL2"]:
		var again: Dictionary = await _one(seed, "")
		var original: Dictionary = runs[int(seed.trim_prefix("BAL")) - 1]
		repeats.append({
			"seed": seed,
			"original_fingerprint": str(original.fingerprint),
			"repeat_fingerprint": str(again.fingerprint),
			"match": str(original.fingerprint) == str(again.fingerprint),
		})

	var control := await _focused_control()
	var baseline_control: Dictionary = _read_json(CONTROL_REL)
	var control_bytes := JSON.stringify(control.report_record, "	").to_utf8_buffer()
	var baseline_control_bytes := JSON.stringify(
		baseline_control.report_record, "	").to_utf8_buffer()
	var user_after := _user_fingerprints()
	var expected: Array[String] = []
	for i in requested:
		expected.append("BAL%d" % (i + 1))
	var checks := {
		"requested_120_distinct": seed_names == expected
			and seed_names.size() == 120,
		"effective_n_is_distinct_seed_count": runs.size() == 120,
		"repetitions_do_not_inflate_n": runs.size() == 120
			and repeats.size() == 2,
		"repeat_fingerprints_match": _all_repeat_matches(repeats),
		"all_physical_fingerprints_match_feature_off":
			physical_mismatches.is_empty(),
		"every_primary_increase_equals_burn_reaction_damage":
			attribution_mismatches.is_empty(),
		"true_non_ember_control_is_byte_identical":
			control_bytes == baseline_control_bytes,
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

	_write_json("feature-on-120.json", {
		"schema": "sg205-feature-on-v2",
		"baseline_sha256": _sha256(FileAccess.get_file_as_bytes(
			ProjectSettings.globalize_path(BASELINE_REL))),
		"requested": 120,
		"distinct": seed_names.size(),
		"repetitions": 1,
		"effective_n": runs.size(),
		"seeds": seed_names,
		"runs": runs,
		"repeat_audit": repeats,
	})
	_write_v2(runs[0], "representative Ember production run",
		"damage-attribution-v2-ember.txt")
	_write_control_v2(control)
	_write_json("g3-result.json", {
		"packet": "SG-205",
		"result": "PASS" if passed else "FAIL",
		"driver_sha256": _sha256(FileAccess.get_file_as_bytes(
			ProjectSettings.globalize_path(SG205_DRIVER_REL))),
		"baseline_sha256": _sha256(FileAccess.get_file_as_bytes(
			ProjectSettings.globalize_path(BASELINE_REL))),
		"sample": {"requested": 120, "distinct": seed_names.size(),
			"repetitions": 1, "effective_n": runs.size()},
		"checks": checks,
		"physical_mismatches": physical_mismatches,
		"attribution_mismatches": attribution_mismatches,
		"repeat_audit": repeats,
		"control_fingerprint": _sha256(control_bytes),
		"baseline_control_fingerprint": _sha256(baseline_control_bytes),
		"user_before": user_before,
		"user_after": user_after,
	})
	print("SG205 %s n=%d physical-diffs=%d attribution-diffs=%d" % [
		"PASS" if passed else "FAIL", runs.size(),
		physical_mismatches.size(), attribution_mismatches.size()])
	quit(0 if passed else 1)


func _physical(run: Dictionary) -> Dictionary:
	return {
		"seed": str(run.get("seed", "")),
		"final_wave": int(run.get("final_wave", 0)),
		"won": bool(run.get("won", false)),
		"run_time": float(run.get("run_time", 0.0)),
		"taken": float(run.get("taken", 0.0)),
		"waves": (run.get("waves", []) as Array).duplicate(true),
	}


func _player_damage(run: Dictionary) -> float:
	var total := float((run.get("basic", {}) as Dictionary).get("damage", 0.0))
	for raw in run.get("per_slot", []):
		total += float((raw as Dictionary).get("damage", 0.0))
	return total


func _burn_damage(run: Dictionary) -> float:
	var total := 0.0
	for raw in run.get("reaction_rows", []):
		var row: Dictionary = raw
		if str(row.get("reaction", "")).to_upper() == "BURN":
			total += float(row.get("damage", 0.0))
	return total


func _focused_control() -> Dictionary:
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


func _user_fingerprints() -> Dictionary:
	var values := {}
	for name in ["runs.json", "keys.cfg", "workshop.json", "settings.cfg"]:
		var path := ProjectSettings.globalize_path("user://" + name)
		values[name] = _sha256(FileAccess.get_file_as_bytes(path)) \
			if FileAccess.file_exists(path) else "ABSENT"
	return values


func _read_json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


func _write_v2(run: Dictionary, arm: String, name: String) -> void:
	var lines := PackedStringArray([
		"damage attribution v2",
		"seed: %s" % str(run.seed),
		"arm: %s" % arm,
		"physical fingerprint: %s" % str(run.physical_fingerprint),
		"feature-off physical fingerprint: %s" % str(
			run.baseline_physical_fingerprint),
		"primary attribution increase: %.3f" % float(
			run.primary_attribution_increase),
		"BURN reaction damage: %.3f" % float(run.burn_reaction_damage),
		"",
		str(run.report),
		"",
		"raw per-slot rows: %s" % JSON.stringify(run.per_slot),
		"basic: %s" % JSON.stringify(run.basic),
		"reaction rows: %s" % JSON.stringify(run.reaction_rows),
	])
	var file := FileAccess.open(out_dir.path_join(name), FileAccess.WRITE)
	file.store_string("\n".join(lines) + "\n")
	file.close()


func _write_control_v2(control: Dictionary) -> void:
	var file := FileAccess.open(out_dir.path_join(
		"damage-attribution-v2-true-non-ember.txt"), FileAccess.WRITE)
	file.store_string("damage attribution v2\n"
		+ "focused true-non-Ember control remains byte-identical to SG-204\n"
		+ "record: %s\n" % JSON.stringify(control.report_record))
	file.close()
