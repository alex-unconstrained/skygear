extends SceneTree

## SG-203 is an evidence-only correction to BASE-00.  It runs on the accepted
## AB-01 code and deliberately changes no production file or tuning value.
const BotScript := preload("res://tools/bot.gd")

const EVIDENCE_REL := "res://../.codex-work/gameplay-expansion/EL-00/SG-203"
const DRIVER_REL := EVIDENCE_REL + "/sg203_fixture.gd"
const ACCEPTED_BEAM_COMMIT := "508523c"
const COORDINATOR_BASELINE := "52ffb7922ef180edd7e36e2c92f8b500d5ac5513"

var bot := BotScript.new()
var out_dir := ""


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var requested := int(args[0]) if args.size() > 0 else 120
	if requested != 120:
		push_error("SG-203 acceptance requires exactly 120 distinct BAL seeds")
		quit(2)
		return
	Engine.physics_ticks_per_second = 20
	await physics_frame
	out_dir = ProjectSettings.globalize_path(EVIDENCE_REL)
	DirAccess.make_dir_recursive_absolute(out_dir)

	## The production instrument deliberately excludes one process warm-up.
	print("SG203 WARM-UP BAL-WARMUP (excluded)")
	await _one("BAL-WARMUP", "")

	var runs: Array = []
	for i in requested:
		var seed := "BAL%d" % (i + 1)
		var row := await _one(seed, "")
		runs.append(row)
		print("SG203 %-6s wave %2d %s taken %.0f" % [seed,
			int(row.final_wave), "HELD" if bool(row.won) else "lost",
			float(row.taken)])

	## These repetitions audit determinism.  They never enter runs/effective_n.
	var repeated: Array = []
	for seed in ["BAL1", "BAL2"]:
		var again := await _one(seed, "")
		var original: Dictionary = runs[int(seed.trim_prefix("BAL")) - 1]
		repeated.append({
			"seed": seed,
			"original_fingerprint": str(original.fingerprint),
			"repeat_fingerprint": str(again.fingerprint),
			"match": str(original.fingerprint) == str(again.fingerprint),
		})

	## This is the corrected control.  The choice is made through the existing
	## production seam before begin_run(), exactly as a player pre-run choice is.
	var true_non_ember := await _one("BAL2", "FROST")
	var ember: Dictionary = runs[0]

	var seed_names: Array[String] = []
	var fingerprints: Dictionary = {}
	for raw in runs:
		var row: Dictionary = raw
		seed_names.append(str(row.seed))
		fingerprints[str(row.seed)] = str(row.fingerprint)
	var expected: Array[String] = []
	for i in requested:
		expected.append("BAL%d" % (i + 1))

	var checks := {
		"requested_120_distinct": requested == 120 and seed_names == expected
			and fingerprints.size() == 120,
		"effective_n_is_distinct_seed_count": runs.size() == 120,
		"repetitions_do_not_inflate_n": runs.size() == 120 and repeated.size() == 2,
		"repeat_fingerprints_match": _all_repeat_matches(repeated),
		"ember_representative_is_ember": bool(ember.has_ember),
		"true_non_ember_auto_is_frost": str(true_non_ember.auto_element) == "FROST",
		"true_non_ember_has_no_ember_element": not bool(true_non_ember.has_ember),
		"true_non_ember_all_elements_are_non_ember":
			(true_non_ember.element_violations as Array).is_empty(),
		"true_non_ember_never_acquired_burn": int(true_non_ember.burn_acquisitions) == 0,
		"true_non_ember_has_no_burn_reaction_row":
			(true_non_ember.burn_reaction_rows as Array).is_empty(),
	}
	var passed := true
	for key in checks:
		if not bool(checks[key]):
			passed = false
			push_error("SG-203 failed: %s" % str(key))

	_write_json("feature-off-120.json", {
		"schema": "sg203-feature-off-v1",
		"accepted_beam_commit": ACCEPTED_BEAM_COMMIT,
		"coordinator_baseline": COORDINATOR_BASELINE,
		"instrument": "BASE-00 production bot/policy/integrator; one excluded warm-up",
		"requested": 120,
		"distinct": fingerprints.size(),
		"repetitions": 1,
		"effective_n": runs.size(),
		"seeds": seed_names,
		"fingerprints": fingerprints,
		"runs": runs,
		"repeat_audit": repeated,
	})
	_write_attribution(ember, "representative Ember; accepted Beam code",
		"damage-attribution-v1-ember-beam-stable.txt")
	_write_attribution(true_non_ember,
		"true non-Ember; auto forced FROST before begin_run",
		"damage-attribution-v1-true-non-ember.txt")
	_write_json("result.json", {
		"packet": "SG-203",
		"result": "PASS" if passed else "FAIL",
		"accepted_beam_commit": ACCEPTED_BEAM_COMMIT,
		"coordinator_baseline": COORDINATOR_BASELINE,
		"driver_sha256": _sha256(FileAccess.get_file_as_bytes(
			ProjectSettings.globalize_path(DRIVER_REL))),
		"checks": checks,
		"ember_seed": str(ember.seed),
		"ember_fingerprint": str(ember.fingerprint),
		"true_non_ember_seed": str(true_non_ember.seed),
		"true_non_ember_fingerprint": str(true_non_ember.fingerprint),
		"true_non_ember_auto": str(true_non_ember.auto_element),
		"true_non_ember_elements": true_non_ember.equipped_elements,
		"true_non_ember_burn_acquisitions": int(true_non_ember.burn_acquisitions),
		"true_non_ember_burn_reaction_rows": true_non_ember.burn_reaction_rows,
		"sample": {"requested": 120, "distinct": fingerprints.size(),
			"repetitions": 1, "effective_n": runs.size()},
		"repeat_audit": repeated,
	})
	print("SG203 %s: n=%d distinct=%d true-non-Ember burn=%d" % [
		"PASS" if passed else "FAIL", runs.size(), fingerprints.size(),
		int(true_non_ember.burn_acquisitions)])
	quit(0 if passed else 1)


## Exact BASE-00 / balance.gd simulation policy, plus read-only assertions.
func _one(seed_text: String, forced_auto: String) -> Dictionary:
	var game: SkyGearGame = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	game.workshop = SkyGearWorkshop.fresh(true)
	game.workshop.unlocked = true
	game.workshop.best_heat = SkyGearWorkshop.HEAT.size() - 1
	game.heat = 0
	game.set_process(false)
	game.set_physics_process(false)
	game.player.set_physics_process(false)
	game.player.set_process(false)
	game.log_runs = false
	if game.impact != null:
		game.impact.enabled = false
	await physics_frame
	game.set_seed_text(seed_text)
	if forced_auto != "":
		game.auto_element = forced_auto
	game.begin_run()
	game.choose_draft(bot.draft_pick(game.draft_options))

	var element_violations: Array = []
	var burn_seen: Dictionary = {}
	_scan_elements(game, element_violations)
	_scan_burn(game, burn_seen)
	var current_wave := game.wave
	var wave_started := game.run_time
	var wave_recorded := false
	var waves: Array = []
	var steps := 0
	while game.state_name == "PLAY" or game.state_name == "DRAFT":
		if game.state_name == "DRAFT":
			if current_wave > 0 and not wave_recorded:
				waves.append(_wave_row(game, current_wave,
					game.run_time - wave_started, true))
				wave_recorded = true
			game.choose_draft(bot.draft_pick(game.draft_options))
			_scan_elements(game, element_violations)
			current_wave = game.wave
			wave_started = game.run_time
			wave_recorded = false

		bot.steer(game)
		game._process(0.05)
		_scan_burn(game, burn_seen)
		for enemy in game.get_tree().get_nodes_in_group("enemies"):
			if is_instance_valid(enemy):
				enemy.set_physics_process(false)
				enemy._physics_process(0.05)
				_scan_one_burn(enemy, burn_seen)
		for prop in game.get_tree().get_nodes_in_group("props"):
			if is_instance_valid(prop):
				prop.set_process(false)
				prop._process(0.05)
		if is_instance_valid(game.player):
			game.player._physics_process(0.05)
		if steps % 4 == 0:
			var target: SkyGearEnemy = game.nearest_enemy(
				game.player.global_position, 900.0)
			if target != null:
				for slot in game.skills.size():
					if float(game.skills[slot].cooldown_left) <= 0.0:
						game.cast_skill(slot, target.global_position)
						_scan_burn(game, burn_seen)
						break
		steps += 1
		if steps % 200 == 0:
			await physics_frame
		if steps > 40000:
			break

	if current_wave > 0 and not wave_recorded:
		waves.append(_wave_row(game, current_wave,
			game.run_time - wave_started, game.state_name == "VICTORY"))

	_scan_elements(game, element_violations)
	_scan_burn(game, burn_seen)
	var per_rows: Array = []
	var equipped_elements: Array[String] = [game.auto_element_id()]
	var has_ember := game.auto_element_id() == "EMBER"
	for i in game.tel.per.size():
		var row: Dictionary = (game.tel.per[i] as Dictionary).duplicate(true)
		row["slot"] = i
		per_rows.append(row)
		var element := str(row.get("element", ""))
		if element != "":
			equipped_elements.append(element)
		if str(row.get("shape", "")) != "" and element == "EMBER":
			has_ember = true
	var reaction_rows := _reaction_rows(game.tel)
	var burn_reaction_rows: Array = []
	for raw in reaction_rows:
		var reaction: Dictionary = raw
		if str(reaction.get("reaction", reaction.get("id", reaction.get(
				"name", "")))).to_upper() == "BURN":
			burn_reaction_rows.append(reaction)
	var out := {
		"seed": seed_text,
		"forced_auto": forced_auto,
		"auto_element": game.auto_element_id(),
		"equipped_elements": equipped_elements,
		"element_violations": element_violations,
		"burn_acquisitions": burn_seen.size(),
		"burn_targets": burn_seen.values(),
		"burn_reaction_rows": burn_reaction_rows,
		"final_wave": game.wave,
		"won": game.state_name == "VICTORY",
		"run_time": game.run_time,
		"taken": float(game.tel.taken),
		"waves": waves,
		"has_ember": has_ember,
		"report": game.run_report(),
		"per_slot": per_rows,
		"basic": (game.tel.basic as Dictionary).duplicate(true),
		"allies": (game.tel.allies as Dictionary).duplicate(true),
		"deck": (game.tel.deck as Dictionary).duplicate(true),
		"reaction_rows": reaction_rows,
	}
	out["fingerprint"] = _fingerprint(out)
	bot.release()
	game.queue_free()
	await physics_frame
	return out


func _scan_elements(game: SkyGearGame, violations: Array) -> void:
	if game.auto_element_id() == "EMBER":
		_append_unique(violations, "auto:EMBER")
	for i in game.skills.size():
		var element := str((game.skills[i] as Dictionary).get("element", ""))
		if element == "EMBER":
			_append_unique(violations, "slot%d:EMBER" % i)


func _scan_burn(game: SkyGearGame, seen: Dictionary) -> void:
	for enemy in game.get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy):
			_scan_one_burn(enemy, seen)


func _scan_one_burn(enemy: Node, seen: Dictionary) -> void:
	if int(enemy.get("burn_stacks")) <= 0:
		return
	var serial := int(enemy.get("spawn_serial"))
	var key := str(serial) if serial > 0 else str(enemy.get_instance_id())
	if not seen.has(key):
		seen[key] = {"spawn_serial": serial, "kind": str(enemy.get("kind")),
			"max_stacks_seen": int(enemy.get("burn_stacks"))}
	else:
		seen[key].max_stacks_seen = maxi(int(seen[key].max_stacks_seen),
			int(enemy.get("burn_stacks")))


func _reaction_rows(tel: Dictionary) -> Array:
	if not tel.has("reactions"):
		return []
	var raw: Variant = tel.reactions
	if raw is Array:
		return (raw as Array).duplicate(true)
	if raw is Dictionary:
		var out: Array = []
		for key in (raw as Dictionary):
			var row: Variant = (raw as Dictionary)[key]
			if row is Dictionary:
				var copy: Dictionary = (row as Dictionary).duplicate(true)
				copy["reaction"] = str(key)
				out.append(copy)
		return out
	return []


func _wave_row(game: SkyGearGame, wave: int, duration: float,
		held: bool) -> Dictionary:
	return {"wave": wave, "duration": duration,
		"captain_damage_taken": float(game.tel.taken_by_wave.get(wave, 0.0)),
		"held": held}


func _fingerprint(run: Dictionary) -> String:
	var stable: Dictionary = run.duplicate(true)
	stable.erase("fingerprint")
	return _sha256(var_to_bytes(stable))


func _sha256(bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode()


func _all_repeat_matches(rows: Array) -> bool:
	for row in rows:
		if not bool(row.match):
			return false
	return true


func _append_unique(values: Array, value: Variant) -> void:
	if not value in values:
		values.append(value)


func _write_json(name: String, value: Variant) -> void:
	var file := FileAccess.open(out_dir.path_join(name), FileAccess.WRITE)
	file.store_string(JSON.stringify(value, "\t") + "\n")
	file.close()


func _write_attribution(run: Dictionary, arm: String, name: String) -> void:
	var lines := PackedStringArray([
		"damage attribution v1",
		"accepted Beam implementation: %s" % ACCEPTED_BEAM_COMMIT,
		"seed: %s" % str(run.seed),
		"arm: %s" % arm,
		"auto element: %s" % str(run.auto_element),
		"equipped elements: %s" % JSON.stringify(run.equipped_elements),
		"burn acquisitions observed: %d" % int(run.burn_acquisitions),
		"BURN reaction rows: %d" % (run.burn_reaction_rows as Array).size(),
		"fingerprint: %s" % str(run.fingerprint),
		"",
		str(run.report),
		"",
		"raw per-slot rows — slot / shape / element / damage / hits / kills / casts",
	])
	for raw_row in run.per_slot:
		var row: Dictionary = raw_row
		lines.append("%d / %s / %s / %.3f / %d / %d / %d" % [
			int(row.slot), str(row.shape), str(row.element), float(row.damage),
			int(row.hits), int(row.kills), int(row.casts)])
	lines.append("basic: %s" % JSON.stringify(run.basic))
	lines.append("allies: %s" % JSON.stringify(run.allies))
	lines.append("deck: %s" % JSON.stringify(run.deck))
	lines.append("reaction rows: %s" % JSON.stringify(run.reaction_rows))
	var file := FileAccess.open(out_dir.path_join(name), FileAccess.WRITE)
	file.store_string("\n".join(lines) + "\n")
	file.close()
