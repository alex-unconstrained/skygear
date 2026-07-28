extends SceneTree
## Six frames across a second of a run, so an animation cycle can be verified as
## a cycle rather than as one lucky still.
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var world = load("res://scenes/main3d.tscn").instantiate()
	root.add_child(world)
	await process_frame
	var game: SkyGearGame = world.get_node("SkyGear")
	game.set_seed_text("ANIM")
	game.begin_run()
	game.choose_draft(0)
	game.start_wave(3)
	game.player.global_position = Vector2(0, 500)
	for i in 6:
		game.spawn_enemy(["SCRAPPER", "SCRAPPER", "SWARM"][i % 3], i % 3)
	for e in game.get_tree().get_nodes_in_group("enemies"):
		e.state = "move"
		e.global_position = game.player.global_position + Vector2(randf_range(-380, 380), randf_range(-560, -180))
	for shot in 6:
		for i in 5:
			game._process(0.04)
			game.player.velocity = Vector2(120, -40)
			for e in game.get_tree().get_nodes_in_group("enemies"):
				if is_instance_valid(e): e._physics_process(0.04)
			await process_frame
		root.get_texture().get_image().save_png("res://../.shots/anim-%d.png" % shot)
	print("frames saved")
	quit(0)
