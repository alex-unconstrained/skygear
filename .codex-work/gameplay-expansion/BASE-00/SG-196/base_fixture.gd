extends SceneTree

const BotScript := preload("res://tools/bot.gd")
const BalStat := preload("res://tools/bal_stat.gd")

var bot := BotScript.new()
var out_dir := ""


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var requested := int(args[0]) if args.size() > 0 else 120
	## Keep CharacterBody2D integration on balance.gd's declared 0.05 s clock.
	Engine.physics_ticks_per_second = 20
	await physics_frame
	out_dir = ProjectSettings.globalize_path(
		"res://../.codex-work/gameplay-expansion/BASE-00/SG-196")
	DirAccess.make_dir_recursive_absolute(out_dir)
	_write_json("queue-fixtures.json", await _queue_fixtures())
	print("BASE QUEUES captured: 6 seeds x 12 waves")

	## Match SG-195's process normalization. This result is discarded.
	print("BASE WARM-UP BAL-WARMUP (excluded)")
	await _one("BAL-WARMUP")

	var runs: Array = []
	for i in requested:
		var seed := "BAL%d" % (i + 1)
		var row := await _one(seed)
		runs.append(row)
		print("BASE %-6s wave %2d %s taken %.0f" % [seed, int(row.final_wave),
			"HELD" if bool(row.won) else "lost", float(row.taken)])

	var metrics := {
		"commit": "2c1ee5e6ed819f5351339daba840b881961db511",
		"instrument": "balance policy/integrator, 120 distinct BAL seeds, one excluded warm-up",
		"requested": requested,
		"distinct": requested,
		"repetitions": 1,
		"effective_n": requested,
		"runs": runs,
		"by_wave": _aggregate_waves(runs),
	}
	_write_json("metrics.json", metrics)
	if requested == 120:
		_write_attribution(runs, true, "damage-attribution-v1-ember.txt")
		_write_attribution(runs, false, "damage-attribution-v1-non-ember.txt")
	print("BASE METRICS captured: %d distinct seeds" % requested)
	quit(0)


func _queue_fixtures() -> Dictionary:
	var all := {"commit": "2c1ee5e6ed819f5351339daba840b881961db511",
		"heat": 0, "seeds": {}}
	for seed in ["STOW", "TEMPO", "WATCH1", "WATCH2", "WATCH3", "COLOSSUS"]:
		var game: SkyGearGame = (load("res://scenes/main.tscn") as PackedScene).instantiate()
		root.add_child(game)
		game.workshop = SkyGearWorkshop.fresh(true)
		game.refresh_berthed()
		game.heat = 0
		game.set_seed_text(seed)
		var waves := []
		for wave in range(1, 13):
			var rng_before := str(game.rng.state)
			var visual_before := str(game.visual_rng.state)
			var queue: Array[Dictionary] = game._build_spawn_queue(wave)
			var bytes := var_to_bytes(queue)
			waves.append({
				"wave": wave,
				"signature_sha256": _sha256(bytes),
				"byte_length": bytes.size(),
				"rng_before": rng_before,
				"rng_after": str(game.rng.state),
				"visual_rng_before": visual_before,
				"visual_rng_after": str(game.visual_rng.state),
				"queue": queue,
			})
		all.seeds[seed] = waves
		game.queue_free()
		await physics_frame
	return all


func _sha256(bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode()


func _write_json(name: String, value: Variant) -> void:
	var file := FileAccess.open(out_dir.path_join(name), FileAccess.WRITE)
	file.store_string(JSON.stringify(value, "\t"))
	file.close()


## Exact balance.gd simulation policy, with read-only per-wave observation added.
func _one(seed_text: String) -> Dictionary:
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
	game.begin_run()
	game.choose_draft(bot.draft_pick(game.draft_options))

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
			current_wave = game.wave
			wave_started = game.run_time
			wave_recorded = false

		bot.steer(game)
		game._process(0.05)
		for enemy in game.get_tree().get_nodes_in_group("enemies"):
			if is_instance_valid(enemy):
				enemy.set_physics_process(false)
				enemy._physics_process(0.05)
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
						break
		steps += 1
		if steps % 200 == 0:
			await physics_frame
		if steps > 40000:
			break

	if current_wave > 0 and not wave_recorded:
		waves.append(_wave_row(game, current_wave,
			game.run_time - wave_started, game.state_name == "VICTORY"))

	var per_rows: Array = []
	var has_ember := false
	for i in game.tel.per.size():
		var row: Dictionary = (game.tel.per[i] as Dictionary).duplicate(true)
		row["slot"] = i
		per_rows.append(row)
		if str(row.get("shape", "")) != "" and str(row.get("element", "")) == "EMBER":
			has_ember = true
	var out := {
		"seed": seed_text,
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
	}
	bot.release()
	game.queue_free()
	await physics_frame
	return out


func _wave_row(game: SkyGearGame, wave: int, duration: float,
		held: bool) -> Dictionary:
	return {
		"wave": wave,
		"duration": duration,
		"captain_damage_taken": float(game.tel.taken_by_wave.get(wave, 0.0)),
		"held": held,
	}


func _aggregate_waves(runs: Array) -> Array:
	var out: Array = []
	for wave in range(1, 13):
		var durations: Array[float] = []
		var taken: Array[float] = []
		var held := 0
		for run in runs:
			for raw_wave in run.waves:
				var row: Dictionary = raw_wave
				if int(row.wave) != wave:
					continue
				durations.append(float(row.duration))
				taken.append(float(row.captain_damage_taken))
				held += 1 if bool(row.held) else 0
				break
		var interval := BalStat.wilson(held, durations.size())
		out.append({
			"wave": wave,
			"reached_n": durations.size(),
			"held": held,
			"held_rate": float(held) / maxf(1.0, float(durations.size())),
			"held_wilson_95_low": interval.x,
			"held_wilson_95_high": interval.y,
			"duration_mean": _mean(durations),
			"duration_sd": _sd(durations),
			"captain_damage_taken_mean": _mean(taken),
			"captain_damage_taken_sd": _sd(taken),
		})
	return out


func _mean(values: Array[float]) -> float:
	var total := 0.0
	for value in values:
		total += value
	return total / maxf(1.0, float(values.size()))


func _sd(values: Array[float]) -> float:
	if values.size() < 2:
		return 0.0
	var mean := _mean(values)
	var total := 0.0
	for value in values:
		total += pow(value - mean, 2.0)
	return sqrt(total / float(values.size() - 1))


func _write_attribution(runs: Array, wants_ember: bool, name: String) -> void:
	var selected: Dictionary = {}
	for raw in runs:
		var run: Dictionary = raw
		if bool(run.has_ember) == wants_ember:
			selected = run
			break
	if selected.is_empty():
		push_error("BASE attribution fixture missing: %s" % name)
		return
	var lines := PackedStringArray([
		"damage attribution v1",
		"seed: %s" % str(selected.seed),
		"arm: %s" % ("representative Ember" if wants_ember else "representative non-Ember"),
		"",
		str(selected.report),
		"",
		"raw per-slot rows — slot / shape / element / damage / hits / kills / casts",
	])
	for raw_row in selected.per_slot:
		var row: Dictionary = raw_row
		lines.append("%d / %s / %s / %.3f / %d / %d / %d" % [
			int(row.slot), str(row.shape), str(row.element), float(row.damage),
			int(row.hits), int(row.kills), int(row.casts)])
	lines.append("basic: %s" % JSON.stringify(selected.basic))
	lines.append("allies: %s" % JSON.stringify(selected.allies))
	lines.append("deck: %s" % JSON.stringify(selected.deck))
	var file := FileAccess.open(out_dir.path_join(name), FileAccess.WRITE)
	file.store_string("\n".join(lines) + "\n")
	file.close()
