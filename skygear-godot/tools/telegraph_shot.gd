extends SceneTree
## One posed frame of enemy attack TELEGRAPHS, so the readability of a windup can
## be judged against a picture instead of a memory of a fight (board SG-3).
##
## The browser draws the reach of a melee swing as a filled oxblood WEDGE covering
## the swing arc, and a ranged shooter's firing line as a danger band down the
## lane — every attack readable before it is dangerous (design pillar 6). This
## poses four boarders frozen mid-windup, each facing a target, so the melee
## wedges and the gunner's aim band are all in one frame.
##
##   godot --path . --resolution 1600x900 --script tools/telegraph_shot.gd -- <outdir>
##
## NOT --headless: the whole output is a PNG and --headless makes PNGs empty.
func _initialize() -> void: call_deferred("_run")

## Each boarder is placed (not spawned into a lane) so the same picture comes back
## every run, frozen in `windup` at a chosen point in its own wind so the fill
## clock is part-way and the flicker is live. `st_frac` is how far through the
## windup it is: 0.55 leaves the tell visibly counting down.
const TARGETS := [
	{"kind": "SCRAPPER", "at": Vector2(-150.0, 470.0)},
	{"kind": "ARMORED", "at": Vector2(150.0, 470.0)},
	{"kind": "SWARM", "at": Vector2(-360.0, 560.0)},
	{"kind": "GUNNER", "at": Vector2(360.0, 300.0)},
]
const ST_FRAC := 0.55


func _run() -> void:
	var argv := OS.get_cmdline_user_args()
	var out_dir: String = str(argv[0]) if argv.size() > 0 else "../.shots/telegraph"
	DirAccess.make_dir_recursive_absolute(out_dir)
	var path: String = "%s/telegraphs.png" % out_dir
	await _shoot(path)
	print("  telegraphs %s" % path)
	print("telegraph shot ok")
	quit(0)


func _shoot(path: String) -> void:
	var world = load("res://scenes/main3d.tscn").instantiate()
	root.add_child(world)
	await process_frame
	var game: SkyGearGame = world.get_node("SkyGear")
	game.set_process(false)
	world.sway = false
	game.workshop = SkyGearWorkshop.fresh(true)
	game.heat = 0
	game.set_class("captain")
	game.set_seed_text("TELE")
	game.begin_run()
	game.choose_draft(0)
	game.start_wave(3)
	game.spawn_queue.clear()

	for t in TARGETS:
		game.spawn_enemy(str(t.kind), 1)
	var live := game.get_tree().get_nodes_in_group("enemies")
	for i in live.size():
		if i >= TARGETS.size():
			continue
		var e = live[i]
		e.global_position = TARGETS[i].at
		e.state = "move"

	## Settle: shadows land, the camera reaches the captain.
	for _i in 6:
		game._process(1.0 / 60.0)
		await process_frame
	game.effects.clear()

	## Freeze every boarder mid-windup, facing the captain, so the tell is drawn.
	for i in live.size():
		if i >= TARGETS.size():
			continue
		var e = live[i]
		var to_cap: Vector2 = game.player.global_position - e.global_position
		e.state = "windup"
		e.attack_direction = to_cap.normalized() if to_cap.length() > 0.001 else Vector2.DOWN
		e.state_time = float(e.config.windup) * ST_FRAC

	## Present a few frames so the renderer mirrors the windup into decals.
	for _i in 3:
		await process_frame

	## FROZEN (SG-108). Four boarders are frozen "mid-windup" by hand above, but
	## that only pins `state_time` — each still owns an AnimationPlayer that
	## keeps advancing on the ENGINE's clock, so the wedge and the aim band this
	## tool exists to photograph were drawn under limbs still mid-stride.
	await SkyGearStill.freeze(self, world, game)

	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png(path.replace("\\", "/"))
	world.queue_free()
	await process_frame
