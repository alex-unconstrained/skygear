extends SceneTree
## THE WHOLE BEAT OF A HEAVY'S SWING, FRAME BY FRAME (SG-156) — because the owner
## asked *"the telegraphed moves should be more clear - we need to work on that"*
## and the question that answers is not "is the wedge pretty" but **can you tell
## the WARNING from the HIT**.
##
## WHY `tools/telegraph_shot.gd` COULD NOT ANSWER IT. That tool poses ONE frame,
## at `ST_FRAC = 0.55` — the middle of the wind, the moment the telegraph looks
## its best. It also poses SCRAPPER, ARMORED, SWARM and GUNNER and **has no BOSS
## in it at all**, which is half of what the owner named. A single mid-wind frame
## can only ever say the wedge is drawn; it cannot say what the player sees at
## the moment it matters, because that moment is not in the picture.
##
## SO THIS SHOOTS THE BEAT: the same boarder, the same camera, five frames across
## one attack cycle.
##
##   wind-000   the frame the wedge appears — the warning's first instant
##   wind-050   mid-wind, which is the only frame the old tool ever took
##   wind-095   the last frame before contact, the wedge at its brightest
##   strike     THE FRAME THE DAMAGE LANDS
##   recover    mid-recovery, the second the boarder is punishable
##
## WHAT IT IS EXPECTED TO SHOW, AND THIS IS A PREDICTION MADE BEFORE LOOKING:
## frames 4 and 5 are BLANK PLANKING. `view3d.gd`'s telegraph pass runs inside
## `if enemy.state == "windup"` and nothing else in that pass draws for "recover",
## so the wedge is not merely dimmed at contact — it is DELETED on the frame the
## hit resolves, and nothing replaces it. The player's entire visual account of a
## swing is a shape that grows and then vanishes; the hit itself, and the 1.00 s
## of punishable recovery that follows it, have no mark on the deck at all.
##
## At the shipped camera (41.25° pitch, yaw 0) and nothing else, because the
## owner judges this by eye and a shot at a flattering angle is not evidence.
##
##   godot --path . --resolution 1600x900 --script tools/telegraph_beat.gd -- .shots/sg156
##
## The SG-numbered evidence directories live under `skygear-godot/.shots/`, which
## is gitignored — the board row names the path, the PNGs stay on the machine.
##
## NOT --headless: the whole output is a PNG and --headless makes PNGs empty.

## The two the owner named. One per sheet, alone on the deck, so nothing else on
## the planking can be mistaken for its telegraph.
const SUBJECTS := ["BOSS", "ARMORED"]

## `wind` is the fraction of the windup ELAPSED, so 0.95 is nearly-struck. The
## last two are states, not fractions — the beat leaves the windup there.
const BEATS := [
	{"tag": "1-wind-000", "wind": 0.00, "state": "windup"},
	{"tag": "2-wind-050", "wind": 0.50, "state": "windup"},
	{"tag": "3-wind-095", "wind": 0.95, "state": "windup"},
	{"tag": "4-strike", "wind": 0.00, "state": "recover"},
	{"tag": "5-recover", "wind": 0.50, "state": "recover"},
]


func _initialize() -> void: call_deferred("_run")


func _run() -> void:
	var argv := OS.get_cmdline_user_args()
	var out_dir: String = str(argv[0]) if argv.size() > 0 else ".shots/sg156"
	DirAccess.make_dir_recursive_absolute(out_dir)
	for kind in SUBJECTS:
		for beat in BEATS:
			var path: String = "%s/%s-%s.png" % [out_dir, kind.to_lower(), str(beat.tag)]
			await _shoot(path, kind, beat)
			print("  %s" % path)
	print("telegraph beat ok")
	quit(0)


func _shoot(path: String, kind: String, beat: Dictionary) -> void:
	var world = load("res://scenes/main3d.tscn").instantiate()
	root.add_child(world)
	await process_frame
	var game: SkyGearGame = world.get_node("SkyGear")
	game.set_process(false)
	world.sway = false
	## A tool that opens real runs writes rows into `user://runs.json`, which the
	## harness reads — SG-101's mistake, and it is cheaper to not make it twice.
	game.log_runs = false
	game.workshop = SkyGearWorkshop.fresh(true)
	game.heat = 0
	game.set_class("captain")
	game.set_seed_text("SG156")
	game.begin_run()
	game.choose_draft(0)
	## Wave 3 with no `await` before it, which is what keeps `_watch_cues` from
	## ever seeing wave 1 and craning the camera off the shipped solve (SG-33).
	game.start_wave(3)
	game.spawn_queue.clear()
	if game.view != null:
		game.view.cutscenes_enabled = false
		game.view.stop_cutscene()

	game.spawn_enemy(kind, 1)
	var subject: SkyGearEnemy = null
	for e in game.get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and str(e.kind) == kind:
			subject = e
	if subject == null:
		world.queue_free()
		await process_frame
		return

	## PLACED WHERE THE OWNER STOOD: swinging distance, dead ahead of the captain,
	## which is also the geometry `tools/melee_probe.gd` measured 60 of 60 swings
	## landing in. The picture and the number are of the same situation.
	## MID-DECK, AND THE CAPTAIN IS MOVED TO IT. She starts at y 720, which is far
	## enough aft that the camera — which chases her over several frames rather
	## than cutting — had not caught up by the shutter in the first draft of this
	## tool, and the first ten frames it produced contained neither figure. Both
	## are placed at the spot the camera actually frames. It does NOT chase her
	## here: `game.set_process(false)` is what these tools use to hold the sim
	## still, and the follow lives on that clock, so the camera stays parked over
	## deck centre however many frames are presented. Placing the pair at y 420 —
	## a sensible mid-deck number — put them on the bottom edge of the frame.
	var cap := Vector2(0.0, 60.0)
	game.player.global_position = cap
	game.player.velocity = Vector2.ZERO
	subject.global_position = cap + Vector2(0.0, -float(subject.config.attack_range) - 20.0)
	subject.state = "move"
	for _i in 40:
		game._process(1.0 / 60.0)
		game.player.global_position = cap
		await process_frame
	game.effects.clear()

	var to_cap: Vector2 = cap - subject.global_position
	subject.attack_direction = to_cap.normalized() if to_cap.length() > 0.001 else Vector2.DOWN
	subject.state = str(beat.state)
	## `state_time` COUNTS DOWN, so the elapsed fraction the tag names is
	## `1 - wind`. Getting this backwards would silently label every frame with
	## the mirror of the moment it shows.
	if str(beat.state) == "windup":
		subject.state_time = float(subject.config.windup) * (1.0 - float(beat.wind))
	else:
		subject.state_time = float(subject.config.recover) * (1.0 - float(beat.wind))

	for _i in 3:
		await process_frame
	## FROZEN (SG-108): pinning `state_time` by hand does not stop the
	## AnimationPlayer, which advances on the ENGINE's clock, so without this the
	## limbs are mid-stride under a telegraph that is supposed to be held still.
	await SkyGearStill.freeze(self, world, game)

	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png(path.replace("\\", "/"))
	world.queue_free()
	await process_frame
