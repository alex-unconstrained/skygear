extends SceneTree

const BotScript := preload("res://tools/bot.gd")
var bot := BotScript.new()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	Engine.physics_ticks_per_second = 20
	SkyGearWorkshop.store = "user://workshop.muster-g3.json"
	SkyGearRunLog.store = "user://runs.muster-g3.json"
	SkyGearAudio.store = "user://settings.muster-g3.cfg"
	await physics_frame
	var args := OS.get_cmdline_user_args()
	var count := int(args[0]) if not args.is_empty() else 120
	print("MUSTER G3 · primary absolute lateral Captain ground during wave 6")
	print("arms forced ASSAULT vs PINCER · Heat 0 · BAL1..BAL%d · reps 1" % count)
	print("pass >=10% mean movement and paired 95% half-width")

	var arms := {}
	for grammar in ["ASSAULT", "PINCER"]:
		OS.set_environment("SKYGEAR_MUSTER_FORCE", grammar)
		OS.set_environment("SKYGEAR_MUSTER_FLAT", "")
		print("warm-up %s · BAL-WARMUP excluded" % grammar)
		await _one("BAL-WARMUP")
		var rows: Array[Dictionary] = []
		for index in count:
			var seed_text := "BAL%d" % (index + 1)
			var row := await _one(seed_text)
			row.seed = seed_text
			rows.append(row)
			if (index + 1) % 20 == 0 or index + 1 == count:
				print("%s %d/%d" % [grammar, index + 1, count])
		arms[grammar] = rows
	OS.set_environment("SKYGEAR_MUSTER_FORCE", "")

	var assault: Array = arms.ASSAULT
	var pincer: Array = arms.PINCER
	var assault_mean := _mean(assault)
	var pincer_mean := _mean(pincer)
	var diffs: Array[float] = []
	var assault_reached := 0
	var pincer_reached := 0
	for index in count:
		diffs.append(float(pincer[index].travel) - float(assault[index].travel))
		assault_reached += 1 if bool(assault[index].reached) else 0
		pincer_reached += 1 if bool(pincer[index].reached) else 0
	var diff_mean := 0.0
	for value in diffs:
		diff_mean += value
	diff_mean /= diffs.size()
	var diff_sd := 0.0
	for value in diffs:
		diff_sd += pow(value - diff_mean, 2.0)
	diff_sd = sqrt(diff_sd / (diffs.size() - 1.0))
	var half_width := 1.96 * diff_sd / sqrt(float(diffs.size()))
	var effect_pct := absf(diff_mean) / maxf(0.001, absf(assault_mean)) * 100.0
	var resolution_pct := half_width / maxf(0.001, absf(assault_mean)) * 100.0
	var passed := effect_pct >= 10.0 and absf(diff_mean) > half_width
	var out := {
		"n": count,
		"seeds": "BAL1..BAL%d" % count,
		"repetitions": 1,
		"assault_mean": assault_mean,
		"pincer_mean": pincer_mean,
		"paired_difference": diff_mean,
		"paired_sd": diff_sd,
		"paired_95_half_width": half_width,
		"effect_percent": effect_pct,
		"printed_resolution_percent": resolution_pct,
		"assault_reached_wave6": assault_reached,
		"pincer_reached_wave6": pincer_reached,
		"pass": passed,
		"assault": assault,
		"pincer": pincer,
	}
	print("ASSAULT mean %.3f · PINCER mean %.3f" % [assault_mean, pincer_mean])
	print("paired delta %.3f · 95%% half-width %.3f" % [diff_mean, half_width])
	print("effect %.2f%% · printed resolution %.2f%% · verdict %s" % [
		effect_pct, resolution_pct, "PASS" if passed else "FAIL"])
	print("wave-6 reached ASSAULT %d/%d · PINCER %d/%d" % [
		assault_reached, count, pincer_reached, count])
	print("MUSTER_G3 " + JSON.stringify(out))
	quit(0 if passed else 2)


func _mean(rows: Array) -> float:
	var total := 0.0
	for row in rows:
		total += float(row.travel)
	return total / maxf(1.0, rows.size())


func _one(seed_text: String) -> Dictionary:
	var game: SkyGearGame = (
		load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	game.workshop = SkyGearWorkshop.fresh(true)
	game.workshop.unlocked = true
	game.workshop.best_heat = SkyGearWorkshop.HEAT.size() - 1
	game.heat = 0
	game.set_process(false)
	game.set_physics_process(false)
	game.player.set_physics_process(false)
	game.player.set_process(false)
	if game.impact != null:
		game.impact.enabled = false
	await physics_frame
	game.set_seed_text(seed_text)
	game.begin_run()
	game.choose_draft(bot.draft_pick(game.draft_options))
	var travel := 0.0
	var reached := false
	var steps := 0
	while game.state_name == "PLAY" or game.state_name == "DRAFT":
		if game.state_name == "DRAFT":
			if game.wave >= 6:
				break
			game.choose_draft(bot.draft_pick(game.draft_options))
			continue
		if game.wave == 6:
			reached = true
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
		var before_x := game.player.global_position.x
		if is_instance_valid(game.player):
			game.player._physics_process(0.05)
			travel += absf(game.player.global_position.x - before_x)
		else:
			break
		if steps % 4 == 0:
			_cast(game)
		else:
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
				_cast(game)
		steps += 1
		if steps % 200 == 0:
			await physics_frame
		if steps > 24000:
			break
	bot.release()
	var out := {"travel": travel, "reached": reached, "last_wave": game.wave}
	game.queue_free()
	await physics_frame
	return out


func _cast(game: SkyGearGame) -> void:
	var target: SkyGearEnemy = game.nearest_enemy(
		game.player.global_position, 900.0)
	if target == null:
		return
	for slot in game.skills.size():
		if float(game.skills[slot].cooldown_left) <= 0.0:
			game.cast_skill(slot, target.global_position)
			return
