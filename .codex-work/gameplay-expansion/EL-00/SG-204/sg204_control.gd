extends SceneTree

var out_dir := ""


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	out_dir = ProjectSettings.globalize_path(
		"res://../.codex-work/gameplay-expansion/EL-00/SG-204")
	DirAccess.make_dir_recursive_absolute(out_dir)
	var user_before := _user_fingerprints()
	var first := await _arm(false)
	var second := await _arm(false)
	var negative := await _arm(true)
	var user_after := _user_fingerprints()

	var first_bytes := JSON.stringify(first.report_record, "\t").to_utf8_buffer()
	var second_bytes := JSON.stringify(second.report_record, "\t").to_utf8_buffer()
	var checks := {
		"control_has_no_environmental_sources":
			int(first.props) == 0 and int(first.fire_fields) == 0,
		"control_has_only_non_ember_player_sources":
			str(first.auto_element) == "FROST"
			and (first.equipped_elements as Array) == ["FROST"],
		"control_never_acquires_burn": int(first.burn_stacks) == 0,
		"control_has_no_burn_reaction_row":
			(first.burn_reaction_rows as Array).is_empty(),
		"control_damage_uses_basic_and_slot_buckets":
			is_equal_approx(float(first.basic.damage), 0.5)
			and is_equal_approx(float(first.per_slot[0].damage), 0.4),
		"control_rng_is_unchanged":
			str(first.rng_before) == str(first.rng_after)
			and str(first.visual_rng_before) == str(first.visual_rng_after),
		"control_repeat_is_byte_identical": first_bytes == second_bytes,
		"control_repeat_fingerprint_matches":
			str(first.fingerprint) == str(second.fingerprint),
		"negative_uses_one_real_production_fire_field":
			int(negative.negative_fire_fields) == 1,
		"negative_makes_the_exact_no_burn_assertion_fail":
			int(negative.burn_stacks) > 0,
		"evidence_driver_writes_no_user_file": user_before == user_after,
	}
	var passed := true
	for key in checks:
		if not bool(checks[key]):
			passed = false
			push_error("SG-204 failed: %s" % str(key))

	_write_text("damage-attribution-v1-true-non-ember.txt",
		str(first.report_text))
	_write_json("control-a.json", first)
	_write_json("control-b.json", second)
	_write_json("negative-fire-field.json", negative)
	_write_json("result.json", {
		"packet": "SG-204",
		"accepted_beam_commit": "508523c",
		"coordinator_baseline": "349489799803cd4ad289c690579a79bb43e6565e",
		"reused_sg203_production_arm_sha256":
			"65F183243A8912D1D8005464EF9B2627E19BB4E6BF5D2D90A6C937A9794C3C7A",
		"checks": checks,
		"control_fingerprint": str(first.fingerprint),
		"repeat_fingerprint": str(second.fingerprint),
		"control_report_sha256": _sha256(first_bytes),
		"user_before": user_before,
		"user_after": user_after,
		"result": "PASS" if passed else "FAIL",
	})
	print("SG204 %s: control burn=%d negative burn=%d repeat=%s" % [
		"PASS" if passed else "FAIL", int(first.burn_stacks),
		int(negative.burn_stacks), str(first.fingerprint) == str(second.fingerprint)])
	quit(0 if passed else 1)


func _arm(add_fire_field: bool) -> Dictionary:
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
	## This is an attribution fixture, not a rendering fixture. The ordinary
	## damage funnel otherwise asks the view for impact particles, whose seeded
	## visual stream is expected to move. Nulling the optional reader proves the
	## evidence path itself moves neither stream without changing damage.
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
	## Sub-one amounts still traverse the ordinary damage/element/attribution
	## funnel but deliberately do not open its seeded cosmetic floater branch.
	game.damage_enemy(enemy, 0.5, "FROST", 0.0,
		enemy.global_position, false, false)
	game.src_slot = 0
	game.damage_enemy(enemy, 0.4, "FROST", 0.0,
		enemy.global_position, false, false)
	game.src_slot = -1
	var rng_after := str(game.rng.state)
	var visual_rng_after := str(game.visual_rng.state)
	var props_before := game.props().size()
	var fields_before := game.fire_fields.size()
	var negative_fields := 0
	if add_fire_field:
		game._field({"position": enemy.global_position, "time": 0.5, "tick": 0.0})
		negative_fields = game.fire_fields.size()
		game._update_fire_fields(0.05)

	var reaction_rows := _reaction_rows(game.tel)
	var per_rows: Array = []
	for i in game.tel.per.size():
		var row: Dictionary = (game.tel.per[i] as Dictionary).duplicate(true)
		row["slot"] = i
		per_rows.append(row)
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
	var fingerprint := _sha256(JSON.stringify(report_record, "\t").to_utf8_buffer())
	var report_text := "\n".join(PackedStringArray([
		"damage attribution v1",
		"accepted Beam implementation: 508523c",
		"fixture: focused production funnel; no props or fire fields",
		"seed: %s" % game.seed_text,
		"arm: true non-Ember",
		"auto element: %s" % game.auto_element_id(),
		"equipped elements: [FROST]",
		"burn acquisitions observed: %d" % int(enemy.burn_stacks),
		"BURN reaction rows: %d" % reaction_rows.size(),
		"basic: %s" % JSON.stringify(game.tel.basic),
		"per slot: %s" % JSON.stringify(per_rows),
		"fingerprint: %s" % fingerprint,
	])) + "\n"
	var out := {
		"report_record": report_record,
		"report_text": report_text,
		"fingerprint": fingerprint,
		"auto_element": game.auto_element_id(),
		"equipped_elements": ["FROST"],
		"props": props_before,
		"fire_fields": fields_before,
		"negative_fire_fields": negative_fields,
		"burn_stacks": int(enemy.burn_stacks),
		"burn_reaction_rows": reaction_rows,
		"basic": (game.tel.basic as Dictionary).duplicate(true),
		"per_slot": per_rows,
		"rng_before": rng_before,
		"rng_after": rng_after,
		"visual_rng_before": visual_rng_before,
		"visual_rng_after": visual_rng_after,
	}
	game.queue_free()
	await physics_frame
	return out


func _reaction_rows(tel: Dictionary) -> Array:
	if not tel.has("reactions"):
		return []
	var raw: Variant = tel.reactions
	if raw is Array:
		return (raw as Array).duplicate(true)
	if raw is Dictionary:
		var out: Array = []
		for key in (raw as Dictionary):
			if str(key).to_upper() == "BURN":
				out.append((raw as Dictionary)[key])
		return out
	return []


func _user_fingerprints() -> Dictionary:
	var out := {}
	for name in ["runs.json", "keys.cfg", "workshop.json", "settings.cfg"]:
		var path := ProjectSettings.globalize_path("user://" + name)
		if FileAccess.file_exists(path):
			out[name] = _sha256(FileAccess.get_file_as_bytes(path))
		else:
			out[name] = "ABSENT"
	return out


func _sha256(bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode()


func _write_json(name: String, value: Variant) -> void:
	var file := FileAccess.open(out_dir.path_join(name), FileAccess.WRITE)
	file.store_string(JSON.stringify(value, "\t") + "\n")
	file.close()


func _write_text(name: String, value: String) -> void:
	var file := FileAccess.open(out_dir.path_join(name), FileAccess.WRITE)
	file.store_string(value)
	file.close()
