extends SceneTree
## Three posed frames for the morning playtest's readability batch (board
## SG-59/60/61), so each fix is judged against a picture instead of a memory:
##
##   vent.png — the Boilerwright beside a deck vent: the standing plume, the
##              lit grate, and HIS teal stand-here ring at VENT_STAND;
##   aim.png  — a Frost Mortar armed with the cursor thrown PAST its range:
##              the teal range ring, the marker clamped at the reach with its
##              glow gone, and the faint echo under the cursor;
##   hulk.png — a half-broken boarding hulk at the bow wearing its own
##              unprojected health bar and nameplate.
##
##   godot --path . --resolution 1600x900 --script tools/readability_shot.gd -- <outdir>
##
## NOT --headless: the whole output is a PNG and --headless has no GPU (SG-29).
func _initialize() -> void: call_deferred("_run")


func _run() -> void:
	if not SkyGearRendererCheck.can_capture():
		printerr(SkyGearRendererCheck.capture_refusal())
		quit(2)
		return
	var argv := OS.get_cmdline_user_args()
	var out_dir: String = str(argv[0]) if argv.size() > 0 else "../.shots/readability"
	DirAccess.make_dir_recursive_absolute(out_dir)
	await _vent_shot("%s/vent.png" % out_dir)
	await _aim_shot("%s/aim.png" % out_dir)
	await _hulk_shot("%s/hulk.png" % out_dir)
	print("readability shots ok")
	quit(0)


func _pose(class_id: String, seed_text: String) -> Array:
	var world = load("res://scenes/main3d.tscn").instantiate()
	root.add_child(world)
	await process_frame
	var game: SkyGearGame = world.get_node("SkyGear")
	world.sway = false
	game.workshop = SkyGearWorkshop.fresh(true)
	game.refresh_berthed()
	game.heat = 0
	game.set_class(class_id)
	game.set_seed_text(seed_text)
	game.begin_run()
	game.choose_draft(0)
	game.start_wave(2)
	## The SG-36 idiom: park a spawn at t=99999 so the wave can never read as
	## finished — without it the settle below clears the wave and the DRAFT
	## opens over the frame (bitten by exactly this on the first run).
	game.spawn_queue.clear()
	game.spawn_queue.append({"time": 99999.0, "kind": "SCRAPPER", "lane": 1})
	return [world, game]


func _settle(game: SkyGearGame, frames: int) -> void:
	for _i in frames:
		game._process(1.0 / 60.0)
		await process_frame
	## The WAVE banners are `_fx` entries; posed frames do not need a title
	## card floating over the thing being photographed.
	game.effects.clear()
	await process_frame
	await process_frame


func _save(world, path: String) -> void:
	var img := root.get_texture().get_image()
	img.save_png(path.replace("\\", "/"))
	print("  %s" % path)
	world.queue_free()
	await process_frame


func _vent_shot(path: String) -> void:
	var posed: Array = await _pose("boilerwright", "READVENT")
	var world = posed[0]
	var game: SkyGearGame = posed[1]
	## Beside the centre vent, not on it: the ring, the grate and the plume all
	## in frame with the man they are for.
	game.player.global_position = Vector2(150, 120)
	## Long enough for the metered plume to stand a full column.
	await _settle(game, 80)
	await _save(world, path)


func _aim_shot(path: String) -> void:
	var posed: Array = await _pose("captain", "READAIM")
	var world = posed[0]
	var game: SkyGearGame = posed[1]
	game.player.global_position = Vector2(0, 300)
	game.skills.append(SkyGearData.make_skill("RANGED_AOE", "FROST"))
	var slot: int = game.skills.size() - 1
	var reach: float = float(game.skill_stats(game.skills[slot]).range)
	## The cursor thrown PAST the range, so the frame shows the clamp read:
	## marker at the reach, dimmed, echo under the cursor.
	world.pose_aim(slot, game.player.global_position + Vector2(60.0, -reach * 1.45))
	await _settle(game, 12)
	await _save(world, path)


func _hulk_shot(path: String) -> void:
	var posed: Array = await _pose("captain", "READHULK")
	var world = posed[0]
	var game: SkyGearGame = posed[1]
	## Up-deck, so the bow — and the wall grappled to it — is in the frame.
	game.player.global_position = Vector2(0, -350)
	game.hulk = SkyGearLanes.make_hulk(game.BOW_Y, 1.0)
	game.hulk.vulnerable = true
	game.hulk.hp = float(game.hulk.max_hp) * 0.55
	await _settle(game, 14)
	await _save(world, path)
