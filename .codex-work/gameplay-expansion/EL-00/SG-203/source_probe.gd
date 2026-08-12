extends SceneTree

## Diagnostic companion for SG-203's red forced-Frost BAL2 gate.  This keeps the
## exact production simulation and records only where the first burn becomes
## visible; it changes no simulation state.
const BotScript := preload("res://tools/bot.gd")
const OUT_REL := "res://../.codex-work/gameplay-expansion/EL-00/SG-203"

var bot := BotScript.new()
var seen: Dictionary = {}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	Engine.physics_ticks_per_second = 20
	await physics_frame
	## Same excluded process warm-up as BASE-00, then the arm under diagnosis.
	await _one("BAL-WARMUP", "", false)
	seen.clear()
	var row := await _one("BAL2", "FROST", true)
	var out := {"seed": "BAL2", "auto": "FROST",
		"burn_acquisitions": seen.size(), "acquisitions": seen.values(),
		"run": row}
	var path := ProjectSettings.globalize_path(OUT_REL + "/source-probe.json")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(out, "\t") + "\n")
	file.close()
	print("SG203 SOURCE PROBE burn acquisitions=%d" % seen.size())
	quit(0)


func _one(seed_text: String, forced_auto: String, record: bool) -> Dictionary:
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
	var steps := 0
	while game.state_name == "PLAY" or game.state_name == "DRAFT":
		if game.state_name == "DRAFT":
			game.choose_draft(bot.draft_pick(game.draft_options))
		bot.steer(game)
		game._process(0.05)
		if record:
			_scan(game, "after game._process")
		for enemy in game.get_tree().get_nodes_in_group("enemies"):
			if is_instance_valid(enemy):
				enemy.set_physics_process(false)
				enemy._physics_process(0.05)
				if record:
					_scan(game, "after enemy._physics_process")
		for prop in game.get_tree().get_nodes_in_group("props"):
			if is_instance_valid(prop):
				prop.set_process(false)
				prop._process(0.05)
				if record:
					_scan(game, "after prop._process")
		if is_instance_valid(game.player):
			game.player._physics_process(0.05)
		if record:
			_scan(game, "after player._physics_process")
		if steps % 4 == 0:
			var target: SkyGearEnemy = game.nearest_enemy(
				game.player.global_position, 900.0)
			if target != null:
				for slot in game.skills.size():
					if float(game.skills[slot].cooldown_left) <= 0.0:
						game.cast_skill(slot, target.global_position)
						if record:
							_scan(game, "after cast slot %d" % slot)
						break
		steps += 1
		if steps % 200 == 0:
			await physics_frame
		if steps > 40000:
			break
	var elements: Array[String] = [game.auto_element_id()]
	for skill in game.skills:
		var element := str((skill as Dictionary).get("element", ""))
		if element != "":
			elements.append(element)
	var out := {"wave": game.wave, "won": game.state_name == "VICTORY",
		"run_time": game.run_time, "elements": elements,
		"kill_explode": float(game.mods.kill_explode),
		"report": game.run_report()}
	bot.release()
	game.queue_free()
	await physics_frame
	return out


func _scan(game: SkyGearGame, stage: String) -> void:
	for raw in game.get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(raw) or int(raw.get("burn_stacks")) <= 0:
			continue
		var serial := int(raw.get("spawn_serial"))
		var key := str(serial) if serial > 0 else str(raw.get_instance_id())
		if seen.has(key):
			continue
		var fields: Array = []
		for field in game.fire_fields:
			fields.append({"id": int(field.get("id", 0)),
				"position": [float(field.position.x), float(field.position.y)],
				"time": float(field.time), "tick": float(field.tick)})
		seen[key] = {"spawn_serial": serial, "kind": str(raw.get("kind")),
			"position": [float(raw.global_position.x), float(raw.global_position.y)],
			"stacks": int(raw.get("burn_stacks")), "stage": stage,
			"run_time": game.run_time, "wave": game.wave,
			"fire_fields": fields, "kill_explode": float(game.mods.kill_explode)}
