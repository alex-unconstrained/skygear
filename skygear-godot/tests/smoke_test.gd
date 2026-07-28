extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures.append(message)
		push_error("FAIL: " + message)

func _run() -> void:
	var scene: PackedScene = load("res://scenes/main.tscn")
	var game: SkyGearGame = scene.instantiate()
	root.add_child(game)
	await process_frame

	_check(game.state_name == "TITLE", "project boots to title")
	game.begin_run()
	_check(game.state_name == "DRAFT", "run opens with weapon draft")
	_check(game.draft_options.size() == 3, "opening draft has three choices")
	game.choose_draft(0)
	await process_frame
	_check(game.state_name == "PLAY", "draft choice starts play")
	_check(game.wave == 1, "wave one starts")
	_check(game.skills.size() == 1, "opening skill is equipped")
	_check(game.get_tree().get_nodes_in_group("props").size() == SkyGearData.PROP_LAYOUT.size(), "reactive props are restowed")

	game.spawn_enemy("SCRAPPER", 1)
	await process_frame
	var enemy: SkyGearEnemy = game.nearest_enemy(Vector2(0, -1115), 200.0)
	_check(enemy != null, "enemy scene spawns")
	if enemy != null:
		var hp_before := enemy.hp
		game.damage_enemy(enemy, 10.0, "FROST", 0.0, game.player.global_position, true)
		_check(enemy.hp < hp_before, "enemy takes skill damage")
		_check(enemy.slow_time > 0.0, "element effect is applied")

	var player_hp_before := game.player.hp
	game.player.hp = 50.0
	game.pressure = 100.0
	game.vent_pressure()
	_check(game.player.hp > 50.0, "pressure vent heals captain")
	_check(game.pressure == 0.0, "pressure vent resets gauge")
	game.player.hp = player_hp_before

	game.damage_boiler(game.boiler_max_hp)
	_check(game.state_name == "GAMEOVER", "Boiler destruction ends run")

	game.free()
	if failures.is_empty():
		print("SMOKE TEST PASSED")
		quit(0)
	else:
		print("SMOKE TEST FAILED: ", failures)
		quit(1)

