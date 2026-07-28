extends SceneTree
## A representative fight, framed the way the browser's reference shot is framed:
## the captain mid-deck with the Boiler behind her, boarders coming down all
## three lanes, and everything in flight at once. Not a diorama — the point of
## the shot is to be comparable to `.shots/fight-1366x768-art.png`.
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var world = load("res://scenes/main3d.tscn").instantiate()
	root.add_child(world)
	await process_frame
	var game: SkyGearGame = world.get_node("SkyGear")
	game.set_seed_text("SHOT3D")
	game.begin_run()
	game.choose_draft(0)
	game.skills.append(SkyGearData.make_skill("CHAIN", "ARC"))
	game.skills.append(SkyGearData.make_skill("CLOSEHIT", "EMBER"))
	game.skills.append(SkyGearData.make_skill("AURA", "STEAM"))
	game.start_wave(5)
	game.player.global_position = Vector2(40, 690)
	game.player.hp = 76.0
	game.pressure = 62.0
	game.player.set_pressure(62.0)
	for i in 12:
		game.spawn_enemy(["SCRAPPER", "SWARM", "GUNNER", "ARMORED"][i % 4], i % 3)
	for e in game.get_tree().get_nodes_in_group("enemies"):
		e.state = "move"
		e.global_position = game.player.global_position + Vector2(randf_range(-520, 520), randf_range(-820, -120))
		e.hp = e.max_hp * randf_range(0.35, 1.0)
	for i in 60:
		game._process(0.05)
		for e in game.get_tree().get_nodes_in_group("enemies"):
			if is_instance_valid(e): e._physics_process(0.05)
		await process_frame
	# fire everything, so the shot has a fight in it rather than a diorama
	for slot in game.skills.size():
		game.skills[slot].cooldown_left = 0.0
		game.cast_skill(slot, game.player.global_position + Vector2(60, -260))
	# a bolt or two in the air on their way to her, and numbers already leaving
	game.spawn_enemy_bolt(game.player.global_position + Vector2(-330, -300),
		game.player.global_position, 10.0, 352.0)
	game.spawn_enemy_bolt(game.player.global_position + Vector2(280, -420),
		game.player.global_position, 10.0, 352.0)
	for i in 6:
		game._process(0.02)
		await process_frame
	root.get_texture().get_image().save_png("res://../.shots/godot-3d.png")
	print("shot saved")
	quit(0)
