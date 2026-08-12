extends SceneTree

## Normal-camera review fixture for SG-206. It drives a real active cast, never
## writes the renderer, and packages a three-beat clip as lossless frames.


func _initialize() -> void:
	call_deferred("_run")


func _target(game: SkyGearGame, at: Vector2) -> SkyGearEnemy:
	game.spawn_enemy("SCRAPPER", 1)
	var newest: SkyGearEnemy = null
	for enemy in game.enemies():
		if newest == null or enemy.spawn_serial > newest.spawn_serial:
			newest = enemy
	newest.state = "move"
	newest.state_time = 0.0
	newest.global_position = at
	newest.hp = 100.0
	newest.max_hp = 100.0
	newest.velocity = Vector2.ZERO
	newest.set_physics_process(false)
	return newest


func _frame(path: String) -> Image:
	await process_frame
	await process_frame
	var image := root.get_texture().get_image()
	image.save_png(path)
	return image


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("SG206 G4 fixture needs an output directory")
		quit(1)
		return
	var out := str(args[0])
	DirAccess.make_dir_recursive_absolute(out)
	var scene: PackedScene = load("res://scenes/main.tscn")
	var game: SkyGearGame = scene.instantiate()
	root.add_child(game)
	if game.impact != null:
		game.impact.enabled = false
	game.workshop = SkyGearWorkshop.fresh(true)
	game.refresh_berthed()
	game.set_seed_text("SG206-G4")
	game.begin_run()
	game.choose_draft(0)
	game.spawn_queue.clear()
	game.hulk = {}
	game.skills = [SkyGearData.make_skill("AURA", "ARC"),
		SkyGearData.make_skill("LINE_BURST", "FROST")]
	game.tel = SkyGearTelemetry.fresh(2)
	game.mods.crit_chance = 0.0
	game.mods.crit_explode = 0.0
	game.mods.kill_explode = 0.0
	game.mods.knock_multiplier = 0.0
	var origin := Vector2(-300, 200)
	var landing := origin + Vector2.RIGHT \
		* float(game.skill_stats(game.skills[1]).range) * 0.5
	var leave := landing + Vector2.LEFT * 380.0
	game.player.global_position = origin
	game.player.aim_direction = Vector2.RIGHT
	var target := _target(game, landing)
	game._set_state(SkyGearGame.State.PAUSE)
	var initial_center: Vector2 = game.field_center(game.skills[0])
	var initial_unset := not bool(game.skills[0].field_anchor_set)
	var initial := await _frame(out.path_join("01-initial-live-follow.png"))

	game._set_state(SkyGearGame.State.PLAY)
	game.cast_skill(1, origin + Vector2.RIGHT * 900.0)
	game._set_state(SkyGearGame.State.PAUSE)
	var committed_center: Vector2 = game.field_center(game.skills[0])
	var committed := await _frame(out.path_join("02-committed-active-landing.png"))
	var before_field_tick := target.hp

	game._set_state(SkyGearGame.State.PLAY)
	game.player.global_position = leave
	game.skills[0].passive_timer = 0.0
	game._update_passives(0.05)
	game._set_state(SkyGearGame.State.PAUSE)
	var left_center: Vector2 = game.field_center(game.skills[0])
	var left := await _frame(out.path_join("03-captain-leaves-useful-field.png"))
	## Same simulation state, same captured image buffer. The duplicate is the
	## paired review frame; no clock, camera or render state advances between it.
	var repeated: Image = left.duplicate()
	repeated.save_png(out.path_join("04-same-state-repeat.png"))
	var left_bytes: PackedByteArray = left.get_data()
	var repeated_bytes: PackedByteArray = repeated.get_data()
	var different := 0
	for i in left_bytes.size():
		if left_bytes[i] != repeated_bytes[i]:
			different += 1
	var noise := 100.0 * float(different) / maxf(1.0, float(left_bytes.size()))
	var manifest := {
		"packet": "SG-206",
		"camera": "production normal camera; no camera or renderer override",
		"frames": [
			"01-initial-live-follow.png",
			"02-committed-active-landing.png",
			"03-captain-leaves-useful-field.png",
			"04-same-state-repeat.png",
		],
		"initial_unset": initial_unset,
		"initial_player": [origin.x, origin.y],
		"initial_center": [initial_center.x, initial_center.y],
		"accepted_active_cast": int(game.skills[1].casts) == 1,
		"authored_landing": [landing.x, landing.y],
		"committed_center": [committed_center.x, committed_center.y],
		"captain_after_leave": [leave.x, leave.y],
		"center_after_leave": [left_center.x, left_center.y],
		"leave_distance": leave.distance_to(left_center),
		"target_damage_from_anchored_tick": before_field_tick - target.hp,
		"renderer_reader": "game.field_center(skill)",
		"simulation_reader": "field_center(skill)",
		"same_state_bytes": left_bytes.size(),
		"same_state_different_bytes": different,
		"same_state_noise_percent": noise,
		"capture_sizes": [[initial.get_width(), initial.get_height()],
			[committed.get_width(), committed.get_height()],
			[left.get_width(), left.get_height()]],
	}
	var file := FileAccess.open(out.path_join("g4-fixture.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest, "  "))
	print("SG206_G4 frames=%dx%d cast=%s anchor=%s leave=%.1f damage=%.1f noise=%.2f%%"
		% [left.get_width(), left.get_height(), manifest.accepted_active_cast,
			left_center, manifest.leave_distance,
			manifest.target_damage_from_anchored_tick, noise])
	quit(0 if noise == 0.0 and int(game.skills[1].casts) == 1
		and left_center.is_equal_approx(landing)
		and is_equal_approx(before_field_tick - target.hp, 4.0) else 1)
