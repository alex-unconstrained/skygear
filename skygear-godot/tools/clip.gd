extends SceneTree
## STILL: NOT APPLICABLE — this tool photographs MOTION on purpose (SG-108).
## Every other readback in `tools/` freezes the scene through `SkyGearStill`
## because `set_process(false)` does not stop an `AnimationPlayer`. Here the
## walk cycle IS the evidence: a still cannot witness a walk, a dash crack or a
## cutscene's hand-back, which is the whole reason this tool exists. What it
## does instead is hand-drive both clocks at a fixed `DT` so the sequence is
## reproducible frame for frame, which is the guarantee a film needs.
## Motion evidence (board SG-47, POST-PARITY-PLAN item 1): pose a scenario the
## way `scripts/screen_poser.gd` and `tools/vfx_shot.gd` pose theirs, run N
## seconds of REAL sim+render, save the frames to `.shots/clips/`, and stitch
## them into an animated file you can watch.
##
## Every other piece of visual evidence on the board is a still, and every
## figure-thread claim ahead of us — the walk, the swing, the kneel — is a claim
## about MOTION. "The walk reads well" without this tool is the
## assert-from-memory failure mode STATUS names.
##
##   godot --path . --resolution 1600x900 --script tools/clip.gd -- <scenario> \
##       [--seconds N] [--fps N] [--out name]
##   godot --path . --resolution 1600x900 --script tools/clip.gd -- list
##   godot --path . --resolution 1600x900 --script tools/clip.gd            (the smoke)
##
## NOT `--headless` — the readback hangs without a swapchain on this machine
## (board SG-29), same as every screenshot tool here. Bare invocation runs the
## SMOKE — one short dash clip, produced end to end and counted — which is what
## `hub -- all` runs, so the pipeline is checked before anyone needs it.
##
## THE CLOCK IS TICKS, NOT WALL TIME. The sim and the renderer are both stepped
## by hand at 1/60 s (`set_process(false)`, then `_process(DT)` per presented
## frame — the vfx_shot lesson, extended to the renderer so a cutscene's
## `advance()` runs on the same clock), and a frame is captured every
## `plan.every` ticks. So the frame count on disk follows from `ClipMath.plan`
## arithmetic the harness pins headless, and a 6-second cutscene is 6 seconds
## of clip on a 60 Hz monitor and on a 144 Hz one alike.
##
## CUTSCENES ARE SUPPRESSED for every scenario (the SG-33 rule — a posed ending
## must not have its camera stolen mid-frame), and a cutscene SCENARIO then
## plays its scene explicitly through the real `SkyGearCutscenePlayer`
## (`view.play_cutscene`, which does not consult the auto-cue gate): real bars,
## real caption, real camera hand-back, filmed — which is board SG-32 closed,
## since a cutscene is a posed clip. The sway is left ALIVE unless a scenario
## asks for stillness (`still`): a motion clip of a dead-still ship is evidence
## about the wrong game.

func _initialize() -> void: call_deferred("_run")

const DT := 1.0 / 60.0
## Un-captured settle before the shutter opens: banners expire, shadows land,
## the camera reaches the captain. Fight scenarios extend it (mid-swarm means
## the swarm has had time to board).
const SETTLE_TICKS := 90

var _fails := 0


func _run() -> void:
	## `--resolution` is silently ignored for tool scripts on this machine (board
	## SG-46 — the window opens at desktop size and the root viewport tracks it),
	## so the frame size is forced here, the `tools/deck_probe.gd` hunk verbatim.
	## Without it every clip captures at 2560x1440 and weighs 2.5x what it says.
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1600, 900))
	root.size = Vector2i(1600, 900)
	await process_frame

	var argv := OS.get_cmdline_user_args()
	var name := ""
	var seconds := -1.0
	var fps: float = ClipMath.DEFAULT_FPS
	var out_name := ""
	var i := 0
	while i < argv.size():
		var arg := str(argv[i])
		if arg == "--seconds" and i + 1 < argv.size():
			seconds = float(argv[i + 1])
			i += 2
		elif arg == "--fps" and i + 1 < argv.size():
			fps = float(argv[i + 1])
			i += 2
		elif arg == "--out" and i + 1 < argv.size():
			out_name = str(argv[i + 1])
			i += 2
		else:
			if name == "":
				name = arg
			i += 1

	if name == "list":
		_list()
		quit(0)
		return

	## Bare invocation is the smoke — `hub -- all` cannot pass arguments, and a
	## launcher entry that opens a window and then asks for typing is an entry
	## nobody automates.
	if name == "" or name == "smoke":
		var smoke: Dictionary = ClipMath.SMOKE
		await _clip(str(smoke.scenario), float(smoke.seconds), float(smoke.fps),
			str(smoke.out), true)
		print("")
		print("clip smoke %s" % ("ok" if _fails == 0 else "FAILED (%d)" % _fails))
		quit(_fails)
		return

	var spec := ClipMath.find(name)
	if spec.is_empty():
		print("no scenario called '%s'. `-- list` names them." % name)
		quit(1)
		return
	await _clip(name, seconds, fps, out_name, false)
	quit(_fails)


func _list() -> void:
	print("")
	print("CLIP SCENARIOS    godot --path . --resolution 1600x900 --script tools/clip.gd -- <id>")
	print("")
	for id in ClipMath.ids():
		var spec := ClipMath.find(str(id))
		print("  %-22s %.1fs   %s" % [str(id), float(spec.seconds), str(spec.what)])
	print("")
	print("  defaults: --fps %d, --out <scenario id>; frames + the stitched file land in .shots/clips/"
		% int(ClipMath.DEFAULT_FPS))
	print("")


## One clip, end to end: pose, run, capture, stitch, verify. `checked` adds the
## smoke's assertions on top (file exists, nonzero, frame count matches the
## plan) — the same facts every run prints, but with a verdict attached.
func _clip(name: String, seconds: float, fps: float, out_name: String,
		checked: bool) -> void:
	var spec := ClipMath.find(name)
	if seconds <= 0.0:
		seconds = float(spec.seconds)
	var plan := ClipMath.plan(seconds, fps)
	if out_name == "":
		out_name = name
	var base := ProjectSettings.globalize_path("res://.shots/clips")
	var frames_dir := "%s/%s" % [base, out_name]
	## A stale sequence under a fresh one is a clip that plays two runs spliced;
	## clear the old frames first.
	if DirAccess.dir_exists_absolute(frames_dir):
		for old in DirAccess.get_files_at(frames_dir):
			if str(old).begins_with("frame_") and str(old).ends_with(".png"):
				DirAccess.remove_absolute("%s/%s" % [frames_dir, str(old)])
	DirAccess.make_dir_recursive_absolute(frames_dir)
	var out_file := "%s/%s.gif" % [base, out_name]

	print("clip %s — %d frames, every %d ticks (%.2fs at %d ms/frame)" % [name,
		int(plan.frames), int(plan.every), float(plan.seconds), int(plan.delay_ms)])

	var world = load("res://scenes/main3d.tscn").instantiate()
	root.add_child(world)
	await process_frame
	var game: SkyGearGame = world.get_node("SkyGear")
	## Both clocks are OURS. The engine would also call these every frame, at
	## whatever the wall clock happened to be — the double-stepping that made
	## vfx_shot's first run photograph an empty deck.
	game.set_process(false)
	world.set_process(false)
	## A posed ending is a picture, not a run (the SG-49 lesson): nothing this
	## tool stages may append to the player's own run log.
	game.log_runs = false
	## The SG-33 rule: no auto-fired cutscene may steal a posed frame. Cutscene
	## scenarios play theirs EXPLICITLY below, through the same player.
	world.cutscenes_enabled = false
	world.stop_cutscene()
	## The sway stays alive for motion — forced off only when a scenario asks
	## for stillness, which is the deterministic-rest rule from the cloak work.
	world.sway = not bool(spec.get("still", false))
	game.workshop = SkyGearWorkshop.fresh(true)
	## The FIGHT clip sails with every berth filled (SG-56): the standing
	## motion evidence that six berthed fittings — barricade crates at the
	## bow, the fourth cannon, both extra vents, the grating and the wreck —
	## leave the camera unobstructed and the fight legible. Set BEFORE
	## `begin_run`, which is the one moment the ship reads its berths.
	if str(spec.kind) == "fight":
		game.workshop.unlocked = true
		for fit_id in SkyGearFittings.FITTINGS.keys():
			(game.workshop.fittings as Dictionary)[fit_id] = true
			SkyGearFittings.berth(game.workshop, str(fit_id))
	game.heat = 0
	var kind := str(spec.kind)
	## The boilerwright scenario is ABOUT the second class; everything else
	## films the captain, the default the other scenarios were framed for.
	game.set_class("boilerwright" if kind == "boilerwright" else "captain")
	game.set_seed_text("CLIP")
	game.begin_run()
	game.choose_draft(0)

	match kind:
		"fight":
			## The real wave 3 spawn queue, left to run. Four seated skills so
			## the HUD reads like a fight rather than a fresh boot.
			game.skills.clear()
			for pair in [["CLOSEHIT", "EMBER"], ["RANGED_AOE", "FROST"],
					["CHAIN", "ARC"], ["SENTRY", "STEAM"]]:
				game.skills.append(SkyGearData.make_skill(str(pair[0]), str(pair[1])))
			game.start_wave(3)
			## Mid-swarm means the swarm has boarded: five un-captured seconds of
			## real spawning before the shutter opens.
			await _settle(game, world, 300)
		"dash":
			game.start_wave(1)
			_hold_wave_open(game)
			await _settle(game, world, SETTLE_TICKS)
			## She faces up-deck, back to the camera — where the cloak is.
			game.set_cursor_ground(game.player.global_position + Vector2(0.0, -420.0))
		"projectiles":
			## The SG-40 bolt heads: a mortar's shell, a lance, and the deck
			## guns, all in the air in one clip. Placed targets (the vfx_shot
			## TARGETS, lanes spread so every cannon has a reason to fire).
			game.skills.clear()
			game.skills.append(SkyGearData.make_skill("RANGED_AOE", "FROST"))
			game.skills.append(SkyGearData.make_skill("LINE_BURST", "ARC"))
			game.start_wave(3)
			_hold_wave_open(game)
			for target in [
					{"kind": "SCRAPPER", "at": Vector2(-90.0, 330.0), "lane": 1},
					{"kind": "SCRAPPER", "at": Vector2(190.0, 190.0), "lane": 1},
					{"kind": "SWARM", "at": Vector2(-300.0, 430.0), "lane": 0},
					{"kind": "GUNNER", "at": Vector2(360.0, 300.0), "lane": 2}]:
				game.spawn_enemy(str(target.kind), int(target.lane))
				var live := game.get_tree().get_nodes_in_group("enemies")
				var placed = live[live.size() - 1]
				placed.global_position = target.at
				placed.lane = int(target.lane)
				placed.state = "move"
			await _settle(game, world, SETTLE_TICKS)
			## The guns reload every 1.9 s; zeroed here they fire in the clip's
			## first second and again near its end.
			for turret in game.turrets:
				turret.cooldown = 0.0
		"scrapper":
			## The pilot's lens (SG-55): a rank of scrappers, placed close
			## enough that six seconds shows the whole read — the march down
			## the deck AND the closing swing. Spawned through the real
			## `spawn_enemy` (so each is the simulation's own boarder, lane,
			## AI and all) and then placed up-deck of the captain, in frame at
			## the locked camera, walking toward her.
			game.start_wave(1)
			_hold_wave_open(game)
			for stand in [
					{"lane": 0, "at": Vector2(-300.0, 240.0)},
					{"lane": 1, "at": Vector2(-40.0, 110.0)},
					{"lane": 2, "at": Vector2(260.0, 200.0)}]:
				game.spawn_enemy("SCRAPPER", int(stand.lane))
				var rank := game.get_tree().get_nodes_in_group("enemies")
				var walker = rank[rank.size() - 1]
				walker.global_position = stand.at
				walker.lane = int(stand.lane)
				walker.state = "move"
			await _settle(game, world, SETTLE_TICKS)
		"knight":
			## The furnace knight's witness (SG-85): the WALK (he is the one
			## boarder slow enough to have one), the closing cut, and the first
			## DEATH this game has ever shown. Three of them, spawned through
			## the real `spawn_enemy` — the simulation's own boarders, lane, AI
			## and all — then placed up-deck of the captain and left to close.
			## Two are killed on the strip below through `kill()`, the sim's own
			## one-way door, so the death that films is the one a player causes.
			game.skills.clear()
			game.skills.append(SkyGearData.make_skill("CLOSEHIT", "EMBER"))
			game.start_wave(1)
			_hold_wave_open(game)
			for stand in [
					{"lane": 0, "at": Vector2(-280.0, 210.0)},
					{"lane": 1, "at": Vector2(-10.0, 60.0)},
					{"lane": 2, "at": Vector2(250.0, 170.0)}]:
				game.spawn_enemy("ARMORED", int(stand.lane))
				var wall := game.get_tree().get_nodes_in_group("enemies")
				var knight = wall[wall.size() - 1]
				knight.global_position = stand.at
				knight.lane = int(stand.lane)
				knight.state = "move"
			await _settle(game, world, SETTLE_TICKS)
			game.set_cursor_ground(game.player.global_position + Vector2(0.0, -420.0))
		"boss":
			## THE SEGMENTED COLOSSUS (SG-90), and the four beats it has, in the
			## order the fight plays them: the walk down the deck at ninety-five,
			## a two-fisted slam when it closes, the half-health TURN — and the
			## death, which is the shot this scenario exists for. One boss,
			## spawned through the real `spawn_enemy`, so it is the simulation's
			## own wave-12 arrival, lane, AI and all.
			##
			## Nothing here reaches into the renderer. The turn is triggered by
			## taking its health to half, which is the condition a player's damage
			## meets; the death is `kill()`, the sim's own one-way door. What
			## films is what a run does.
			game.skills.clear()
			game.skills.append(SkyGearData.make_skill("CLOSEHIT", "EMBER"))
			game.start_wave(1)
			_hold_wave_open(game)
			game.spawn_enemy("BOSS", 1)
			var arrivals := game.get_tree().get_nodes_in_group("enemies")
			var colossus = arrivals[arrivals.size() - 1]
			colossus.global_position = Vector2(-10.0, 215.0)
			colossus.lane = 1
			colossus.state = "move"
			await _settle(game, world, SETTLE_TICKS)
			game.set_cursor_ground(game.player.global_position + Vector2(0.0, -420.0))
		"crew":
			## YOUR OWN SAILORS (SG-88). The crew are not spawned by anything a
			## tool can call directly — they MUSTER, on `crew_timer`, two per
			## lane per bell — so this rings the bell instead of building them:
			## `crew_timer = 0` and one `_update_crew` tick is the simulation's
			## own muster, twice, which is six sailors in three lanes. Then a
			## rank of scrappers walks into them and the crew do what the crew
			## do, which is stab whatever is nearest in their lane.
			game.skills.clear()
			game.skills.append(SkyGearData.make_skill("CLOSEHIT", "EMBER"))
			game.start_wave(1)
			_hold_wave_open(game)
			for _bell in 2:
				game.crew_timer = 0.0
				game._update_crew(0.05)
			for stand in [
					{"lane": 0, "at": Vector2(-280.0, 60.0)},
					{"lane": 1, "at": Vector2(-10.0, 20.0)},
					{"lane": 2, "at": Vector2(250.0, 60.0)}]:
				game.spawn_enemy("SCRAPPER", int(stand.lane))
				var rank := game.get_tree().get_nodes_in_group("enemies")
				var walker = rank[rank.size() - 1]
				walker.global_position = stand.at
				walker.lane = int(stand.lane)
				walker.state = "move"
			await _settle(game, world, SETTLE_TICKS)
		"swarm":
			## THE GOBLIN, SIX AT ONCE (SG-89) — which is the number the late
			## waves actually send and the only number worth filming, because
			## the whole question about this figure is what a scuttling crowd
			## of them looks like. Crew mustered for them to swing AT, so the
			## clip carries the attack variants rather than six run cycles.
			game.skills.clear()
			game.skills.append(SkyGearData.make_skill("CLOSEHIT", "EMBER"))
			game.start_wave(1)
			_hold_wave_open(game)
			game.crew_timer = 0.0
			game._update_crew(0.05)
			var spread := [-330.0, -210.0, -40.0, 60.0, 230.0, 340.0]
			for n in spread.size():
				var lane: int = n % 3
				game.spawn_enemy("SWARM", lane)
				var mob := game.get_tree().get_nodes_in_group("enemies")
				var goblin = mob[mob.size() - 1]
				goblin.global_position = Vector2(float(spread[n]), 150.0 + float(n % 3) * 40.0)
				goblin.lane = lane
				goblin.state = "move"
			await _settle(game, world, SETTLE_TICKS)
		"drone":
			## THE GUNNER FLIES (SG-87). Four of them, because a flock is the
			## thing the per-drone phase exists for — a shared clock would make
			## them one object drawn four times, and a still cannot show that.
			## They are RANGED (340 units), so they are stood back and left to
			## hover and shoot rather than walked into anything; what the strip
			## has to carry is the rotor spin, the bob, and four drones not
			## bobbing in unison.
			game.skills.clear()
			game.skills.append(SkyGearData.make_skill("RANGED_AOE", "FROST"))
			game.start_wave(1)
			_hold_wave_open(game)
			for stand in [
					{"lane": 0, "at": Vector2(-300.0, -60.0)},
					{"lane": 1, "at": Vector2(-70.0, -140.0)},
					{"lane": 1, "at": Vector2(90.0, -20.0)},
					{"lane": 2, "at": Vector2(300.0, -110.0)}]:
				game.spawn_enemy("GUNNER", int(stand.lane))
				var flight := game.get_tree().get_nodes_in_group("enemies")
				var drone = flight[flight.size() - 1]
				drone.global_position = stand.at
				drone.lane = int(stand.lane)
				drone.state = "move"
			await _settle(game, world, SETTLE_TICKS)
		"boilerwright":
			## His class row's witness (SG-74): the walk, the slash and the
			## plant on one strip of film. A seated Cleave so the casts swing
			## the wrench (the variant rotation picks a different cut each
			## time), a full bank so Tap Main can afford itself, and an open
			## wave so nothing photobombs the kneel.
			game.skills.clear()
			game.skills.append(SkyGearData.make_skill("CLOSEHIT", "EMBER"))
			game.skills.append(SkyGearData.make_skill("RANGED_AOE", "FROST"))
			game.start_wave(1)
			_hold_wave_open(game)
			await _settle(game, world, SETTLE_TICKS)
			game.pressure = 100.0
			game.player.set_pressure(game.pressure)
			## Faced up-deck like the dash scenario — where the boarders come
			## from, so the cuts read as fighting rather than shadow-boxing.
			game.set_cursor_ground(game.player.global_position + Vector2(0.0, -420.0))
		"cutscene":
			## Stage the moment the scene is authored for: its own wave for a
			## narrowed wave_start, wave 12's real spawn queue for the Colossus
			## (the BOSS arrives through the real spawn path), the end states for
			## the ending shots.
			var cue := str(spec.get("cue", ""))
			var wave := 3
			if cue == "wave_start" and int(spec.get("wave", 0)) > 0:
				wave = int(spec.wave)
			elif cue == "run_open":
				wave = 1
			elif cue == "boss_arrival":
				wave = 12
			game.skills.clear()
			for pair in [["CLOSEHIT", "EMBER"], ["RANGED_AOE", "FROST"],
					["CHAIN", "ARC"], ["SENTRY", "STEAM"]]:
				game.skills.append(SkyGearData.make_skill(str(pair[0]), str(pair[1])))
			game.start_wave(wave)
			await _settle(game, world, SETTLE_TICKS)
			if cue == "victory":
				game.end_reason = "twelve waves repelled"
				game._set_state(SkyGearGame.State.VICTORY)
			elif cue == "defeat":
				game.end_reason = "the Boiler went cold"
				game._set_state(SkyGearGame.State.GAMEOVER)
			await _settle(game, world, 6)
			if not bool(world.play_cutscene(str(spec.cutscene))):
				print(" FAIL the cutscene '%s' refused to play" % str(spec.cutscene))
				_fails += 1
				world.queue_free()
				return

	game.effects.clear()

	## THE SHUTTER. `plan.frames` groups of `plan.every` ticks, one PNG per
	## group — so the file count on disk is the plan's arithmetic or the loop is
	## broken, never something in between.
	var dash_at := int(plan.ticks) / 2
	var tick := 0
	for frame in int(plan.frames):
		for _step in int(plan.every):
			tick += 1
			match kind:
				"dash":
					if tick == 1:
						Input.action_press("move_up")
					elif tick == dash_at:
						Input.action_press("dash")
					elif tick == dash_at + 7:
						Input.action_release("dash")
				"projectiles":
					if tick == 1:
						game.cast_skill(0, game.player.global_position + Vector2(60.0, -520.0))
					elif tick == 45:
						game.cast_skill(1, game.player.global_position + Vector2(-120.0, -480.0))
					elif tick == 110:
						game.cast_skill(0, game.player.global_position + Vector2(-200.0, -400.0))
				"fight":
					if tick == 30 or tick == 170:
						var foes := game.get_tree().get_nodes_in_group("enemies")
						if not foes.is_empty():
							game.cast_skill(1, foes[0].global_position)
				"knight":
					## Two and a half seconds of the march — which is the whole
					## point of him, a wall arriving rather than a rusher — then
					## the deaths, ninety ticks apart so the first body is still
					## sinking when the second goes down.
					if tick == 150 or tick == 240:
						var wall := game.get_tree().get_nodes_in_group("enemies")
						for foe in wall:
							if is_instance_valid(foe) and not foe.dead \
									and str(foe.kind) == "ARMORED":
								foe.kill()
								break
				"boss":
					## SHE HOLDS HER GROUND, and that is a framing decision as
					## much as a tactical one. Two other stagings were filmed and
					## both were worse: walking up-deck to meet it ran her to the
					## bow and left the machine behind the camera, and giving
					## ground pinned the camera against its own deck clamp and
					## pushed the Colossus further up the frame rather than down
					## it. A 330-unit figure standing at melee reach of the
					## subject the camera rides IS going to loom — that is what
					## the archetype is for — so the clip films it looming.
					## Four seconds of the walk and whatever swing it closes
					## into, then the half-health TURN — fired by taking its hp
					## to half, the same condition a player's damage meets, so
					## the beat that plays is the sim's own. Its 1.6 s hold ends
					## near tick 340; the kill goes in at 420 with four seconds
					## of strip left, which is 1.6 s of coming apart, 0.4 s of
					## the wreckage sinking, and time to look at it.
					if tick == 240 or tick == 420:
						var siege := game.get_tree().get_nodes_in_group("enemies")
						for foe in siege:
							if not is_instance_valid(foe) or foe.dead \
									or str(foe.kind) != "BOSS":
								continue
							if tick == 240:
								foe.hp = minf(foe.hp, foe.max_hp * 0.5)
							else:
								foe.kill()
							break
				"crew":
					## Three seconds of the crew working up the lane and closing
					## on the scrappers, then the first ALLY death this game has
					## shown — and a second a hundred ticks later, so the strip
					## carries a body still sinking while the next one goes down.
					## Killed by taking a crewman's hp to nothing and letting
					## `_update_crew` find him, which is the simulation's own
					## door; the renderer is never touched.
					if tick == 180 or tick == 280:
						for c in game.crew:
							if not bool(c.dead):
								c.hp = 0.0
								c.dead = true
								break
				"swarm":
					## The mob closes on its own — at 230 units a second there is
					## nothing to stage. Two die a second and a half apart, which
					## at half the captain's height is the read the SG-85 seam
					## was built for and has never been asked to carry in
					## numbers.
					if tick == 210 or tick == 300:
						var mob := game.get_tree().get_nodes_in_group("enemies")
						for foe in mob:
							if is_instance_valid(foe) and not foe.dead \
									and str(foe.kind) == "SWARM":
								foe.kill()
								break
				"drone":
					## Nothing is staged. The drones hover, bob and shoot on the
					## simulation's own clock — the point of the strip is that
					## its motion is not a clip and does not need a cue. One cast
					## at the flock near the end, so the film also answers "does
					## a hovering target read as hittable".
					if tick == 270:
						var flight := game.get_tree().get_nodes_in_group("enemies")
						for foe in flight:
							if is_instance_valid(foe) and not foe.dead \
									and str(foe.kind) == "GUNNER":
								game.cast_skill(0, foe.global_position)
								break
				"boilerwright":
					## Two seconds of march, two cuts sixty-five ticks apart
					## (the variant rotation shows two DIFFERENT slashes), then
					## the tap: kneel, press, back up before the strip runs out.
					if tick == 1:
						Input.action_press("move_up")
					elif tick == 115:
						Input.action_release("move_up")
					elif tick == 140 or tick == 205:
						game.cast_skill(0,
							game.player.global_position + Vector2(30.0, -150.0))
					elif tick == 265:
						game.pressure = maxf(game.pressure, 60.0)
						game.tap_main()
			game._process(DT)
			world._process(DT)
			await process_frame
		var img := root.get_texture().get_image()
		img.save_png("%s/frame_%04d.png" % [frames_dir.replace("\\", "/"), frame])
	## Never leave an action held: `Input` is global and a stuck key outlives the
	## scenario that pressed it.
	if kind == "dash" or kind == "boilerwright" or kind == "boss":
		Input.action_release("move_up")
		Input.action_release("move_down")
		Input.action_release("dash")

	world.queue_free()
	await process_frame

	## Count what actually landed before stitching, so a failed save is named
	## here rather than surfacing as a shorter GIF nobody measures.
	var on_disk := 0
	for file in DirAccess.get_files_at(frames_dir):
		if str(file).begins_with("frame_") and str(file).ends_with(".png"):
			on_disk += 1
	if on_disk != int(plan.frames):
		print(" FAIL %d frames on disk, plan said %d" % [on_disk, int(plan.frames)])
		_fails += 1

	## Stitch. The Python half re-opens its own output and refuses to succeed
	## unless the animation's frame count matches what it was given.
	var stitch := ProjectSettings.globalize_path("res://tools/clip_stitch.py")
	var out_lines: Array = []
	var code := OS.execute("python", [stitch, frames_dir, out_file,
		"--delay-ms", str(int(plan.delay_ms)), "--scale", "0.5"], out_lines, true)
	for line in out_lines:
		print("  %s" % str(line).strip_edges(false, true))
	if code != 0:
		print(" FAIL clip_stitch exited %d" % code)
		_fails += 1

	var size := 0
	if FileAccess.file_exists(out_file):
		var handle := FileAccess.open(out_file, FileAccess.READ)
		size = int(handle.get_length())
		handle.close()
	print("  %-12s %s  (%d frames, %.2fs, %d bytes)" % [name, out_file,
		on_disk, float(plan.seconds), size])

	if checked:
		_verdict("the stitched file exists and is not empty", size > 0, str(size))
		_verdict("the frame count on disk matches the plan",
			on_disk == int(plan.frames), "%d vs %d" % [on_disk, int(plan.frames)])
		_verdict("the stitcher verified its own output", code == 0, "exit %d" % code)


## Advance both clocks without capturing — the pose settling, off camera.
func _settle(game: SkyGearGame, world, ticks: int) -> void:
	for _i in ticks:
		game._process(DT)
		world._process(DT)
		await process_frame


## An empty wave AUTO-CLEARS and the draft photobombs the clip (the SG-36
## story): one spawn parked in the far future holds the wave open without
## putting an uninvited boarder in frame.
func _hold_wave_open(game: SkyGearGame) -> void:
	game.spawn_queue.clear()
	game.spawn_queue.append({"time": 99999.0, "kind": "SCRAPPER", "lane": 1})


func _verdict(what: String, ok: bool, detail: String) -> void:
	print("  %s %s   %s" % ["ok " if ok else "FAIL", what, detail])
	if not ok:
		_fails += 1
