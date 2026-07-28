extends SceneTree
## The screens, shot one after another. A HUD panel that reads well in isolation
## can still put text through a rivet at 1366 wide, and the only way to know is
## to look at all four.
func _initialize() -> void: call_deferred("_run")

func _shoot(name: String) -> void:
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png("res://../.shots/godot-%s.png" % name)
	print("shot ", name)

func _run() -> void:
	var world = load("res://scenes/main3d.tscn").instantiate()
	root.add_child(world)
	await process_frame
	var game: SkyGearGame = world.get_node("SkyGear")
	game.set_seed_text("SCREENS")

	await _shoot("title")

	game.keys_open = true
	game.rebinding_index = 4
	await _shoot("keys")
	game.keys_open = false
	game.rebinding_index = -1

	game.begin_run()
	await _shoot("draft-open")
	game.choose_draft(0)
	game.skills.append(SkyGearData.make_skill("CHAIN", "ARC"))
	game.start_wave(4)
	game.player.global_position = Vector2(40, 640)
	for i in 8:
		game.spawn_enemy(["SCRAPPER", "SWARM", "GUNNER", "ARMORED"][i % 4], i % 3)
	for e in game.get_tree().get_nodes_in_group("enemies"):
		e.state = "move"
		e.global_position = game.player.global_position + Vector2(randf_range(-500, 500), randf_range(-800, -160))
	for i in 30:
		game._process(0.05)
		for e in game.get_tree().get_nodes_in_group("enemies"):
			if is_instance_valid(e): e._physics_process(0.05)
		await process_frame

	# the mid-run draft, over a live fight
	game.open_draft()
	game._set_state(SkyGearGame.State.DRAFT)
	await _shoot("draft")
	game.choose_draft(1)

	# and the report
	game.run_time = 293.0
	game.wave = 7
	game.damage_player(99999.0)
	await _shoot("report")
	print("done")
	quit(0)
