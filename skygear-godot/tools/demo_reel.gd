extends SceneTree
## STILL: NOT APPLICABLE — this tool photographs MOTION, for the same reason
## `tools/clip.gd` does (SG-108): a trailer is motion or it is a contact sheet.
##
## THE DEMO REEL. Not evidence — a thing to send to a friend. `tools/clip.gd` is
## the motion-evidence tool and stays that; this is its showreel sibling, and it
## exists as its own file rather than as three more `ClipMath.SCENARIOS` rows
## because the two tools want opposite things from a frame:
##
##   * clip.gd films a CLAIM. Its boss scenario clears the skill bar down to the
##     one skill the claim needs, which is correct for evidence and puts three
##     `draft a weapon / EMPTY` plates across the bottom of every frame. On a
##     shareable video that reads as an unfinished game.
##   * this films the GAME. Every shot seats the SAME four weapons — Ember
##     Cleave, Frost Mortar, Arc Whip, Steam Sentry — so the bar is full and,
##     more to the point, is the same bar in every cut. A HUD that changes
##     between shots tells a viewer they are watching six unrelated clips.
##
## Two more things it does that the evidence tool has no reason to: it stages
## the boss fight on WAVE 12 (where the Colossus actually arrives, so the wave
## counter is not lying to camera), and it captures shot lengths chosen to CUT
## rather than scenario lengths chosen to prove — the arrival is trimmed before
## the camera hand-back, because a trailer wants the next shot there.
##
##   godot --path . --resolution 1600x900 --script tools/demo_reel.gd -- list
##   godot --path . --resolution 1600x900 --script tools/demo_reel.gd -- all
##   godot --path . --resolution 1600x900 --script tools/demo_reel.gd -- <shot>
##
## NOT `--headless` — there is no framebuffer to read back without a GPU and the
## PNGs come out empty (board SG-29), the same trap every capture tool here has.
##
## Frames land in `.shots/demo/<shot>/frame_%04d.png` at 1600x900, 30 fps, one
## directory per shot. Nothing is stitched here: the deliverable is an mp4 and
## `tools/demo_encode.py` does that half, which keeps the encoder's flags in a
## file a person can read instead of in a shell history.
##
## THE CLOCK IS TICKS. Both the sim and the renderer are stepped by hand at
## 1/60 s — `set_process(false)`, then `_process(DT)` per presented frame, the
## clip.gd idiom — so a shot is the same length on a 60 Hz monitor and a 144 Hz
## one, and the beats below land on the frame they say they do.

func _initialize() -> void: call_deferred("_run")

const DT := 1.0 / 60.0
const FPS := 30.0
const EVERY := 2  ## sim ticks per captured frame — 60 / 30, a whole number.

## The bar every shot sails with. Four seated weapons, identical across the
## reel, chosen to span the VFX vocabulary the cuts actually show: a swung arc,
## a lobbed shell, a chain that jumps, and a planted sentry.
const BAR := [["CLOSEHIT", "EMBER"], ["RANGED_AOE", "FROST"],
	["CHAIN", "ARC"], ["SENTRY", "STEAM"]]

## The reel, in cut order. `ticks` is the CAPTURED length (frames = ticks/EVERY);
## `settle` is the un-captured run-up that gets the deck into the state the shot
## opens on — boarders closed, banners expired, camera arrived.
const SHOTS := [
	{"id": "01_open", "kind": "cutscene", "cutscene": "run_open", "wave": 1,
		"settle": 90, "ticks": 150,
		## 150 ticks, not 180. `run_open` is 2.52 s of keyframes and clip.gd
		## adds a 0.75 s tail to FILM THE HAND-BACK, which is a claim worth
		## proving and not worth watching: at 180 the shot ends on half a second
		## of ordinary HUD with the letterbox already retracted. 150 lands on
		## the last keyframe and cuts straight into the swarm.
		"what": "the run-opening reveal — the deck, the sky, the braziers, the crew, the captain"},
	{"id": "02_swarm", "kind": "swarm", "settle": 110, "ticks": 180,
		"what": "six swarm gremlins board and hit the crew line"},
	{"id": "03_guns", "kind": "guns", "settle": 90, "ticks": 210,
		"what": "abilities and the deck cannons — mortar, chain, sentry, cannon fire"},
	{"id": "04_knight", "kind": "knight", "settle": 165, "ticks": 150,
		"what": "furnace knights walk the deck and come down"},
	{"id": "05_arrival", "kind": "cutscene", "cutscene": "colossus_arrival",
		"wave": 12, "settle": 90, "ticks": 240,
		"what": "the Colossus arrival cutscene, wave 12"},
	## 260 ticks, measured off the frames rather than guessed. `kill()` lands on
	## tick 150 (frame 75) but the Colossus does not break THERE — the death
	## runs 1.6 s of coming apart first, so the thirteen parts are only on the
	## planking around frame 118 and the wreckage has sunk by frame 132. At the
	## 300 ticks this shot was first cut to, the reel ended on eighteen frames
	## of empty deck. 260 goes out on frame 129, with the last part settling.
	{"id": "06_boss", "kind": "boss", "settle": 250, "ticks": 260,
		"what": "the Colossus fight — the slam, the half-health turn, and thirteen parts coming apart"},
]

var _fails := 0


func _run() -> void:
	## `--resolution` is silently ignored for tool scripts on this machine
	## (board SG-46), so the frame size is forced here — the deck_probe/clip.gd
	## hunk verbatim. Without it the reel captures at desktop size.
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1600, 900))
	root.size = Vector2i(1600, 900)
	await process_frame

	var argv := OS.get_cmdline_user_args()
	var want := str(argv[0]) if argv.size() > 0 else "all"
	if want == "list":
		print("")
		print("DEMO REEL SHOTS   godot --path . --resolution 1600x900 --script tools/demo_reel.gd -- <id|all>")
		print("")
		for shot in SHOTS:
			print("  %-12s %4.1fs  %s" % [str(shot.id),
				float(shot.ticks) / 60.0, str(shot.what)])
		print("")
		print("  total %.1fs at %d fps; frames land in .shots/demo/<id>/" % [_total(), int(FPS)])
		print("")
		quit(0)
		return

	var todo: Array = []
	for shot in SHOTS:
		if want == "all" or str(shot.id) == want:
			todo.append(shot)
	if todo.is_empty():
		print("no shot called '%s'. `-- list` names them." % want)
		quit(1)
		return

	for shot in todo:
		await _shoot(shot)
	print("")
	print("demo reel %s" % ("ok" if _fails == 0 else "FAILED (%d)" % _fails))
	quit(_fails)


static func _total() -> float:
	var t := 0.0
	for shot in SHOTS:
		t += float(shot.ticks) / 60.0
	return t


func _shoot(shot: Dictionary) -> void:
	var id := str(shot.id)
	var ticks := int(shot.ticks)
	var frames := ticks / EVERY
	var dir := "%s/%s" % [ProjectSettings.globalize_path("res://.shots/demo"), id]
	## A stale sequence under a fresh one is a shot that plays two takes spliced.
	if DirAccess.dir_exists_absolute(dir):
		for old in DirAccess.get_files_at(dir):
			if str(old).begins_with("frame_") and str(old).ends_with(".png"):
				DirAccess.remove_absolute("%s/%s" % [dir, str(old)])
	DirAccess.make_dir_recursive_absolute(dir)
	print("shot %s — %d frames, %.2fs" % [id, frames, float(ticks) / 60.0])

	var world = load("res://scenes/main3d.tscn").instantiate()
	root.add_child(world)
	await process_frame
	var game: SkyGearGame = world.get_node("SkyGear")
	## Both clocks are ours; the engine would otherwise step them again at
	## whatever the wall clock happened to be.
	game.set_process(false)
	world.set_process(false)
	## A posed shot is not a run (the SG-49 lesson): nothing here may append to
	## the player's own run log.
	game.log_runs = false
	## The SG-33 rule: no auto-fired cutscene may steal a posed frame. The
	## cutscene shots play theirs EXPLICITLY, through the same player.
	world.cutscenes_enabled = false
	world.stop_cutscene()
	world.sway = true
	game.workshop = SkyGearWorkshop.fresh(true)
	game.heat = 0
	game.set_class("captain")
	game.set_seed_text("REEL")
	game.begin_run()
	game.choose_draft(0)
	## The full bar, seated identically in every shot — the whole reason this
	## tool is not three more clip.gd scenarios.
	game.skills.clear()
	for pair in BAR:
		game.skills.append(SkyGearData.make_skill(str(pair[0]), str(pair[1])))

	var kind := str(shot.kind)
	match kind:
		"cutscene":
			game.start_wave(int(shot.wave))
			await _settle(game, world, int(shot.settle))
			if not bool(world.play_cutscene(str(shot.cutscene))):
				print(" FAIL the cutscene '%s' refused to play" % str(shot.cutscene))
				_fails += 1
				world.queue_free()
				await process_frame
				return
		"swarm":
			## Six at once, which is the number the late waves actually send,
			## with the crew mustered for them to swing AT — a lane of run
			## cycles with nothing to hit is a shot about the wrong thing.
			game.start_wave(2)
			_hold_wave_open(game)
			game.crew_timer = 0.0
			game._update_crew(0.05)
			var spread := [-330.0, -210.0, -40.0, 60.0, 230.0, 340.0]
			for n in spread.size():
				var lane: int = n % 3
				_place(game, "SWARM", lane,
					Vector2(float(spread[n]), 150.0 + float(n % 3) * 40.0))
			await _settle(game, world, int(shot.settle))
		"guns":
			## The vfx_shot TARGETS, lanes spread so every deck cannon has a
			## boarder in its own lane and a reason to fire — four foes all
			## filed under lane 1 leaves port and starboard idle.
			game.start_wave(3)
			_hold_wave_open(game)
			for target in [
					{"kind": "SCRAPPER", "at": Vector2(-90.0, 330.0), "lane": 1},
					{"kind": "SCRAPPER", "at": Vector2(190.0, 190.0), "lane": 1},
					{"kind": "SWARM", "at": Vector2(-300.0, 430.0), "lane": 0},
					{"kind": "GUNNER", "at": Vector2(360.0, 300.0), "lane": 2},
					{"kind": "GUNNER", "at": Vector2(-260.0, 120.0), "lane": 0}]:
				_place(game, str(target.kind), int(target.lane), target.at)
			await _settle(game, world, int(shot.settle))
			## The guns reload every 1.9 s; zeroed here they fire inside the
			## shot rather than a second after it ends.
			for turret in game.turrets:
				turret.cooldown = 0.0
		"knight":
			## Three walls, spawned through the real `spawn_enemy` and placed
			## up-deck. The settle is long because the knight is the one
			## boarder slow enough to have a walk worth arriving on.
			game.start_wave(5)
			_hold_wave_open(game)
			for stand in [
					{"lane": 0, "at": Vector2(-280.0, 210.0)},
					{"lane": 1, "at": Vector2(-10.0, 60.0)},
					{"lane": 2, "at": Vector2(250.0, 170.0)}]:
				_place(game, "ARMORED", int(stand.lane), stand.at)
			await _settle(game, world, int(shot.settle))
			game.set_cursor_ground(game.player.global_position + Vector2(0.0, -420.0))
		"boss":
			## WAVE 12, where he actually arrives — clip.gd stages him on wave 1
			## because the wave number is not what it is measuring, and here it
			## is on camera. One Colossus, spawned through the real
			## `spawn_enemy`, so it is the simulation's own arrival, AI and all.
			game.start_wave(12)
			_hold_wave_open(game)
			_place(game, "BOSS", 1, Vector2(-10.0, 215.0))
			await _settle(game, world, int(shot.settle))
			game.set_cursor_ground(game.player.global_position + Vector2(0.0, -420.0))

	game.effects.clear()

	## THE SHUTTER. `frames` groups of `EVERY` ticks, one PNG per group, so the
	## file count on disk is this arithmetic or the loop is broken.
	var tick := 0
	for frame in frames:
		for _step in EVERY:
			tick += 1
			_beat(game, kind, tick)
			game._process(DT)
			## THE COACH IS OFF, and it has to be switched off HERE rather than
			## before the loop. `scripts/coach.gd` fires from wave 2 onward and
			## `game._process` re-derives `coach_line` every tick, so there is
			## no flag to set once — the line has to be cleared between the sim
			## step and the render step, which is the only window in which it
			## exists and has not yet been drawn. Without this the boss shot
			## carries "HOLD E / 4 to arm the Sentry..." across the Colossus
			## coming apart: correct teaching, ruinous trailer. Nothing in
			## `scripts/` is touched — the coach still runs, it just has no
			## sentence on screen while the reel is filming.
			game.coach_line = ""
			world._process(DT)
			await process_frame
		var img := root.get_texture().get_image()
		img.save_png("%s/frame_%04d.png" % [dir.replace("\\", "/"), frame])

	world.queue_free()
	await process_frame

	var on_disk := 0
	for file in DirAccess.get_files_at(dir):
		if str(file).begins_with("frame_") and str(file).ends_with(".png"):
			on_disk += 1
	if on_disk != frames:
		print(" FAIL %d frames on disk, planned %d" % [on_disk, frames])
		_fails += 1
	else:
		print("  ok %d frames -> %s" % [on_disk, dir])


## What happens on which captured tick. Every beat below is fired through the
## simulation's own door — `cast_skill`, `kill()`, an hp assignment the player's
## damage could equally have made — so what films is what a run does.
func _beat(game: SkyGearGame, kind: String, tick: int) -> void:
	match kind:
		"swarm":
			if tick == 20:
				_cast_at_nearest(game, 0)
			elif tick == 70:
				_cast_at_nearest(game, 2)   ## Arc Whip, jumping the mob
			elif tick == 130:
				_cast_at_nearest(game, 1)
			if tick == 100 or tick == 150:
				_kill_one(game, "SWARM")
		"guns":
			if tick == 10:
				game.cast_skill(1, game.player.global_position + Vector2(60.0, -420.0))
			elif tick == 70:
				_cast_at_nearest(game, 2)
			elif tick == 120:
				game.cast_skill(3, game.player.global_position + Vector2(-60.0, -200.0))
			elif tick == 170:
				game.cast_skill(1, game.player.global_position + Vector2(-200.0, -380.0))
		"knight":
			if tick == 20:
				_cast_at_nearest(game, 0)
			elif tick == 60:
				_cast_at_nearest(game, 2)
			if tick == 45 or tick == 110:
				_kill_one(game, "ARMORED")
		"boss":
			## The three beats, in the order the fight plays them. The TURN is
			## fired by taking its health to half — the condition a player's
			## damage meets — and the death is `kill()`, the sim's own one-way
			## door. Its 1.6 s banner hold clears before the kill lands, and the
			## kill leaves 2.5 s of strip: 1.6 s of coming apart and time to
			## look at the wreckage on the planking.
			if tick == 15 or tick == 105:
				_cast_at_nearest(game, 0)
			elif tick == 60:
				_cast_at_nearest(game, 1)
			if tick == 30:
				for foe in game.get_tree().get_nodes_in_group("enemies"):
					if is_instance_valid(foe) and not foe.dead and str(foe.kind) == "BOSS":
						foe.hp = minf(foe.hp, foe.max_hp * 0.5)
						break
			elif tick == 150:
				_kill_one(game, "BOSS")


func _cast_at_nearest(game: SkyGearGame, slot: int) -> void:
	var best = null
	var best_d := INF
	for foe in game.get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(foe) or foe.dead:
			continue
		var d: float = foe.global_position.distance_to(game.player.global_position)
		if d < best_d:
			best_d = d
			best = foe
	if best != null:
		game.cast_skill(slot, best.global_position)


func _kill_one(game: SkyGearGame, kind: String) -> void:
	for foe in game.get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(foe) and not foe.dead and str(foe.kind) == kind:
			foe.kill()
			return


## Spawn through the real path, then place — so the figure in frame is the
## simulation's own boarder, lane, AI and all, standing where the lens wants it.
func _place(game: SkyGearGame, kind: String, lane: int, at: Vector2) -> void:
	game.spawn_enemy(kind, lane)
	var live := game.get_tree().get_nodes_in_group("enemies")
	var placed = live[live.size() - 1]
	placed.global_position = at
	placed.lane = lane
	placed.state = "move"


func _settle(game: SkyGearGame, world, ticks: int) -> void:
	for _i in ticks:
		game._process(DT)
		world._process(DT)
		await process_frame


## An empty wave AUTO-CLEARS and the draft photobombs the shot (the SG-36
## story): one spawn parked in the far future holds the wave open without
## putting an uninvited boarder in frame.
func _hold_wave_open(game: SkyGearGame) -> void:
	game.spawn_queue.clear()
	game.spawn_queue.append({"time": 99999.0, "kind": "SCRAPPER", "lane": 1})
