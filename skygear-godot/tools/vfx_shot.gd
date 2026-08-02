extends SceneTree
## One posed frame per player skill, so a VFX judgement can be made against a
## picture instead of against a memory of a fight.
##
## Every VFX call in this port so far has been judged mid-combat, with boarders,
## telegraphs, floaters and three other skills on screen at once — which is the
## exact condition under which "the beam is a flat streak on the deck" went
## unnoticed for eleven builds. `docs/OUTSTANDING.md` asks for VFX playback in
## the lab and that is the right home for it eventually; this is the headless
## half, and it is the half that can be run before and after a change and diffed.
##
## Each scene freezes ONE skill at a chosen point in its own life — a Lance is a
## fifth of a second long, so photographing it needs the shot to be taken on the
## right tick rather than whenever the screenshot key was pressed.
##
##   godot --path . --resolution 1600x900 --script tools/vfx_shot.gd -- <outdir>
##   godot --path . --resolution 1600x900 --script tools/vfx_shot.gd -- <outdir> beam chain
##
## NOT `--headless`. There is no framebuffer to read back without a GPU, and a
## tool whose whole output is a PNG cannot run on the flag that makes PNGs empty.
func _initialize() -> void: call_deferred("_run")

## `shape`/`element` is the weapon, `tick` is which frame of its life to
## photograph. The ticks are chosen per shape rather than shared: an arc lives
## 0.20s and a Mortar's circle 0.28, so a single number would catch one of them
## at its peak and the other after it had gone.
const SCENES := [
	{"id": "arc", "shape": "CLOSEHIT", "element": "EMBER", "tick": 4,
		"what": "Ember Cleave - the captain's auto-attack, the most-seen effect in the game"},
	## SG-18: the same swing on the OTHER class — and since SG-38 landed his
	## pipe wrench, this photographs the trail tracing the WRENCH through his
	## retargeted swing, not the empty knuckle mount it started on.
	{"id": "trail-bw", "shape": "CLOSEHIT", "element": "STEAM", "tick": 4,
		"class": "boilerwright",
		"what": "SG-18/SG-38 - the Boilerwright's blade trail off his wrench"},
	{"id": "cone", "shape": "CONE", "element": "STEAM", "tick": 5,
		"what": "Steam Gale - the Boilerwright's auto-attack"},
	{"id": "line", "shape": "LINE_BURST", "element": "ARC", "tick": 3,
		"what": "Arc Lance - hitscan, and the shot has to be visible in the air"},
	{"id": "aoe", "shape": "RANGED_AOE", "element": "FROST", "tick": 6,
		"what": "Frost Mortar - a shell in flight, then the burst"},
	{"id": "chain", "shape": "CHAIN", "element": "ARC", "tick": 5,
		"what": "Arc Whip - jumps between boarders, through the air"},
	{"id": "ray", "shape": "RAY", "element": "EMBER", "tick": 6,
		"what": "Ember Beam - a held beam with a body"},
	{"id": "pulse", "shape": "PULSE", "element": "FROST", "tick": 7,
		"what": "Frost Pulse - a passive that fires itself"},
	{"id": "aura", "shape": "AURA", "element": "STEAM", "tick": 30,
		"what": "Steam Field - a standing volume you can see the edge of"},
	## Not a skill. The deck's own guns: their shots, and their health. Ten ticks
	## rather than three or four, because a cannon ball has to be part-way down
	## the lane before there is anything to look at.
	{"id": "cannon", "shape": "LINE_BURST", "element": "ARC", "tick": 10,
		"hurt": true, "what": "the deck cannons - shots in flight and health bars"},
	## The same frame with the wheel all the way out, because the ask was
	## specifically that the bars stay readable there. They are drawn in screen
	## space at a fixed pixel size, so this is a claim that has to be looked at
	## rather than reasoned about: the WORLD gets smaller and the bar does not.
	{"id": "cannon-zoomed", "shape": "LINE_BURST", "element": "ARC", "tick": 10,
		"hurt": true, "zoom": 99.0,
		"what": "the same guns at full mousewheel zoom-out"},
]

## Boarders to shoot at. Placed rather than spawned into lanes, so the same
## picture comes back every run and a Whip always has three things to jump
## between.
##
## The y values are not free. The captain starts at y = 720 and the camera solve
## puts the top of the frame at about y = -300, so anything spawned at the bow
## where boarders actually arrive is a metre above the lens. These sit in the
## middle third of the frame, spread wide enough that a chain has to travel.
##
## `lane` is not cosmetic. A deck cannon only fires at a boarder whose LANE index
## matches its own, so four boarders all filed under lane 1 leave the port and
## starboard guns idle and the cannon scene shows three guns doing nothing.
const TARGETS := [
	{"kind": "SCRAPPER", "at": Vector2(-90.0, 330.0), "lane": 1},
	{"kind": "SCRAPPER", "at": Vector2(190.0, 190.0), "lane": 1},
	{"kind": "SWARM", "at": Vector2(-300.0, 430.0), "lane": 0},
	{"kind": "GUNNER", "at": Vector2(360.0, 300.0), "lane": 2},
]


func _run() -> void:
	var argv := OS.get_cmdline_user_args()
	var out_dir: String = str(argv[0]) if argv.size() > 0 else "../.shots/vfx"
	var wanted: Array = []
	for i in range(1, argv.size()):
		wanted.append(str(argv[i]))
	DirAccess.make_dir_recursive_absolute(out_dir)

	for scene in SCENES:
		if not wanted.is_empty() and not wanted.has(str(scene.id)):
			continue
		var path: String = "%s/%s.png" % [out_dir, str(scene.id)]
		await _shoot(scene, path)
		print("  %-8s %s" % [str(scene.id), path])
	print("vfx shots ok")
	quit(0)


func _shoot(scene: Dictionary, path: String) -> void:
	var world = load("res://scenes/main3d.tscn").instantiate()
	root.add_child(world)
	await process_frame
	var game: SkyGearGame = world.get_node("SkyGear")
	## The simulation is DRIVEN, not left running. The game node is in the tree, so
	## the engine calls `_process` on it every frame as well — and a tool that also
	## steps it by hand advances it twice per frame, at whatever the wall clock
	## happened to be. A Lance lives 0.18 s; a fifth of a second of accidental
	## extra simulation is the whole effect, which is exactly why the first run of
	## this tool photographed an empty deck and I nearly believed it.
	game.set_process(false)
	## The sway is off for the same reason the harness turns it off: a camera that
	## is never still cannot be the thing two screenshots are diffed against.
	world.sway = false
	game.workshop = SkyGearWorkshop.fresh(true)
	game.heat = 0
	## Per-scene class, defaulting to the captain — the SG-18 trail has to be
	## photographed on BOTH rigs, and the class picks the model and the fit.
	game.set_class(str(scene.get("class", "captain")))
	game.set_seed_text("VFX")
	game.begin_run()
	game.choose_draft(0)
	## ONE weapon, always in slot 0. A deck of four skills means four effects in
	## the frame and no way to say which one the picture is of.
	game.skills.clear()
	game.skills.append(SkyGearData.make_skill(str(scene.shape), str(scene.element)))
	game.start_wave(3)
	game.spawn_queue.clear()

	for t in TARGETS:
		game.spawn_enemy(str(t.kind), 1)
	var live := game.get_tree().get_nodes_in_group("enemies")
	for i in live.size():
		if i < TARGETS.size():
			live[i].global_position = TARGETS[i].at
			live[i].lane = int(TARGETS[i].lane)
			## Off the rail and onto the deck. A boarder spawns in "climb" and the
			## deck cannons skip anything still climbing — which is right in the
			## game and wrong in a posed scene, where nobody ever walks out of it.
			live[i].state = "move"

	if bool(scene.get("hurt", false)):
		## A gun at every stage of failing, so one frame shows the whole range the
		## bar has to be readable across.
		for i in game.turrets.size():
			game.turrets[i].hp = [float(game.turrets[i].max_hp) * 0.62, 0.0,
				float(game.turrets[i].max_hp) * 0.18][i % 3]
			if game.turrets[i].hp <= 0.0:
				game.turrets[i].dead = true

	world.zoom_by(float(scene.get("zoom", 0.0)))

	## Settle first: one frame with nothing cast, so the boarders have their
	## shadows and the camera has reached the captain before the skill fires.
	for _i in 6:
		game._process(1.0 / 60.0)
		await process_frame
	## And drop the wave banner, which `start_wave` posts and which otherwise
	## sits across the middle of every shot for two seconds.
	game.effects.clear()
	## A passive has no press. `cast_skill` does nothing for a Field or a Pulse —
	## they fire off `_update_passives` on their own clock — so zeroing the timer
	## is the only way to say "now" to one, and without it the pulse scene
	## photographed an empty deck four seconds before the thing went off.
	game.skills[0].passive_timer = 0.0
	## The deck cannons reload every 1.9 s and a scene runs for a fraction of
	## that, so left alone they never fire and the shot they were changed to make
	## visible is not in the picture of them.
	for t in game.turrets:
		t.cooldown = 0.0

	var aim: Vector2 = game.player.global_position + Vector2(0.0, -420.0)
	game.set_cursor_ground(aim)
	game.cast_skill(0, aim)
	for _i in maxi(1, int(scene.tick)):
		game._process(1.0 / 60.0)
		await process_frame
	## Two more presented frames so the renderer has mirrored the final tick and
	## any particle injected on it has actually been simulated.
	await process_frame
	await process_frame

	var img := root.get_texture().get_image()
	img.save_png(path.replace("\\", "/"))
	world.queue_free()
	await process_frame
