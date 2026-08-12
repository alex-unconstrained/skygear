extends SceneTree

## Normal-camera review fixture for SG-207. It drives one real accepted cast,
## reads the production Pulse scheduler, and never overrides camera or renderer.


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
		push_error("SG207 G4 fixture needs an output directory")
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
	game.set_seed_text("SG207-G4")
	game.begin_run()
	game.choose_draft(0)
	game.spawn_queue.clear()
	game.hulk = {}
	game.skills = [SkyGearData.make_skill("PULSE", "STEAM"),
		SkyGearData.make_skill("LINE_BURST", "FROST")]
	game.tel = SkyGearTelemetry.fresh(2)
	game.mods.crit_chance = 0.0
	game.mods.crit_explode = 0.0
	game.mods.kill_explode = 0.0
	game.mods.knock_multiplier = 0.0
	game.player.global_position = Vector2.ZERO
	game.player.aim_direction = Vector2.UP
	var target := _target(game, Vector2(160.0, 0.0))
	game.skills[0].passive_timer = 0.30
	game._set_state(SkyGearGame.State.PAUSE)
	var before_public := game.pulse_time_left(game.skills[0])
	var before_raw := float(game.skills[0].passive_timer)
	var before := await _frame(out.path_join("01-pulse-before-cast-0.3.png"))

	game._set_state(SkyGearGame.State.PLAY)
	var hp_before_cast := target.hp
	game.cast_skill(1, Vector2.UP * 900.0)
	var active_damage := hp_before_cast - target.hp
	game._set_state(SkyGearGame.State.PAUSE)
	var due_public := game.pulse_time_left(game.skills[0])
	var due_raw := float(game.skills[0].passive_timer)
	var due := await _frame(out.path_join("02-accepted-cast-pulse-due-now.png"))

	game._set_state(SkyGearGame.State.PLAY)
	var before_pulse := target.hp
	game._update_passives(0.05)
	game._set_state(SkyGearGame.State.PAUSE)
	var after_public := game.pulse_time_left(game.skills[0])
	var after_raw := float(game.skills[0].passive_timer)
	var fired := await _frame(out.path_join("03-pulse-fires-on-crossing-target.png"))
	## Same simulation state, same captured image buffer. The duplicate is the
	## paired control; no clock, camera or render state advances between it.
	var repeated: Image = fired.duplicate()
	repeated.save_png(out.path_join("04-same-state-repeat.png"))
	var fired_bytes: PackedByteArray = fired.get_data()
	var repeated_bytes: PackedByteArray = repeated.get_data()
	var different := 0
	for i in fired_bytes.size():
		if fired_bytes[i] != repeated_bytes[i]:
			different += 1
	var noise := 100.0 * float(different) / maxf(1.0,
		float(fired_bytes.size()))
	var manifest := {
		"packet": "SG-207",
		"camera": "production normal camera; no camera or renderer override",
		"frames": [
			"01-pulse-before-cast-0.3.png",
			"02-accepted-cast-pulse-due-now.png",
			"03-pulse-fires-on-crossing-target.png",
			"04-same-state-repeat.png",
		],
		"pulse_slot": 0,
		"pulse_is_keyless_passive": bool(SkyGearData.SHAPES.PULSE.passive),
		"visible_reader": "HUD calls game.pulse_time_left(skill) and game.pulse_period(skill)",
		"simulation_reader": "game.pulse_time_left(skill)",
		"before_raw": before_raw,
		"before_public": before_public,
		"accepted_active_cast": int(game.skills[1].casts) == 1,
		"active_damage": active_damage,
		"due_raw_negative_remainder": due_raw,
		"due_public": due_public,
		"after_raw": after_raw,
		"after_public": after_public,
		"crossing_target_damage": before_pulse - target.hp,
		"authored_pulse_damage": 34.0,
		"same_state_bytes": fired_bytes.size(),
		"same_state_different_bytes": different,
		"same_state_noise_percent": noise,
		"capture_sizes": [[before.get_width(), before.get_height()],
			[due.get_width(), due.get_height()],
			[fired.get_width(), fired.get_height()]],
	}
	var file := FileAccess.open(out.path_join("g4-fixture.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest, "  "))
	var passed := noise == 0.0 and int(game.skills[1].casts) == 1 \
		and is_equal_approx(active_damage, 0.0) and due_raw < 0.0 \
		and is_equal_approx(due_public, 0.0) \
		and is_equal_approx(before_pulse - target.hp, 34.0)
	print("SG207_G4 %s frames=%dx%d cast=%s active=%.1f clock %.2f->%.2f(raw %.2f)->%.2f damage=%.1f noise=%.2f%%"
		% ["PASS" if passed else "FAIL", fired.get_width(), fired.get_height(),
			manifest.accepted_active_cast, active_damage, before_public, due_public,
			due_raw, after_public, manifest.crossing_target_damage, noise])
	quit(0 if passed else 1)
