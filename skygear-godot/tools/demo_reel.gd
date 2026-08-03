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
##
## ===========================================================================
## VERSION 2, AND WHAT THE OWNER SAID ABOUT VERSION 1
## ===========================================================================
##
## *"The demo is cool but the character never runs around? I'd like to show how
## enemies jump down onto the deck and show more areas of the game - possible?"*
##
## Three answers, and the first is the one that changes the file.
##
## 1. THE CAPTAIN IS PLAYED, NOT POSED. `tools/bot.gd` — the object the balance
##    rig and the harness both drive — steers her now. Board SG-156 calls it a
##    KITER: it holds the 210-unit pressure band, circle-strafes inside it,
##    closes when the band opens, backs off when it shuts, walks out of a fire
##    pool it is standing in, steers off the deck walls and takes the defensive
##    dash. That is the motion v1 was missing, and NOTHING here fakes it with a
##    camera move: the camera does what it always does, which is follow her.
##
##    THE PRICE IS THAT THE CLOCKS HAD TO BE JOINED UP, and it is the SG-118
##    lesson arriving in a second file. `game.set_process(false)` does not reach
##    the captain — she is her own node and movement lives in
##    `_physics_process`, which the engine was still calling on every awaited
##    frame with whatever delta the machine produced. So this tool now does what
##    `tools/balance.gd` does: the captain, the boarders and the props are
##    disabled and hand-stepped at DT, and `Engine.physics_ticks_per_second` is
##    pinned to 60 so `move_and_slide()`'s internal
##    `get_physics_process_delta_time()` is exactly the DT they are handed.
##    Without that pin she integrates velocity on one clock and commits ground
##    on another, and travels at a fraction of her own speed.
##
##    AND IT IS MEASURED RATHER THAN ASSERTED. Every gameplay shot writes
##    `track.csv` beside its frames — her ground position on every captured
##    frame — and this tool prints the path length and the bounding span it
##    implies. A shot that does not move her is visible in the log before
##    anybody has to watch the video.
##
## 2. THE BOARDERS ARRIVE ON CAMERA. v1 had six gremlins already standing on the
##    planking, because `_place` set `state = "move"` — which is precisely the
##    line that skips the arrival. `02_board` does not call it: boarders come in
##    through `spawn_enemy` alone and cross on the simulation's own arc, lifted
##    off the deck through the 0.8 s `state == "climb"` window with the gold
##    landing ring closing onto the spot they will land on (SG-133 / SG-135 /
##    SG-141, and `tools/arrival_shot.gd -- drop` is the still of it). The shot
##    is staged AT THE BOW, where the boarding hulk is parked and where the
##    crossing actually comes from, and the wave is settled past
##    `ARRIVAL_APPROACH` first so the hull is on its hold rather than still
##    coming forward. Three staggered groups, so the frame holds several arcs at
##    once — one boarder falling is a jump, five is a boarding party.
##
## 3. MORE OF THE GAME, which on one deck means variety of PLACE and MOMENT.
##    The bow and the hulk and the sky (02), the cargo runs and the deck cannons
##    (04), the mast, the braziers, a powder keg and the fire it leaves (05),
##    and the three screens a viewer would otherwise never know exist — the
##    title with its Heat ladder, the berths, and a weapon draft (06). Fore, mid
##    and aft come free from (1), because the camera tracks her.
##
## AND THE SKIP HINT IS SUPPRESSED, for the reel only. `CLICK TO SKIP` is real
## UI and belongs in the game; in a clip it reads as a screen recording rather
## than a trailer. It is hidden by reaching into the live cutscene player's
## label from HERE — `scripts/` is not touched, and the hint is still on screen
## for every player who ever sees a cutscene.

func _initialize() -> void: call_deferred("_run")

const DT := 1.0 / 60.0
const FPS := 30.0
const EVERY := 2  ## sim ticks per captured frame — 60 / 30, a whole number.

const BotScript := preload("res://tools/bot.gd")
const Screens := preload("res://tools/screens.gd")

## The bar every shot sails with. Four seated weapons, identical across the
## reel, chosen to span the VFX vocabulary the cuts actually show: a swung arc,
## a lobbed shell, a chain that jumps, and a planted sentry.
const BAR := [["CLOSEHIT", "EMBER"], ["RANGED_AOE", "FROST"],
	["CHAIN", "ARC"], ["SENTRY", "STEAM"]]

## The reel, in cut order — and the directory names ARE the cut order, because
## `tools/demo_encode.py` splices `sorted(shots_dir.iterdir())`. Renumber both
## or neither. `ticks` is the CAPTURED length (frames = ticks/EVERY); `settle`
## is the un-captured run-up that gets the deck into the state the shot opens on
## — boarders closed, banners expired, camera arrived, arriving hull on its hold.
const SHOTS := [
	{"id": "01_open", "kind": "cutscene", "cutscene": "run_open", "wave": 1,
		"settle": 90, "ticks": 150,
		## 150 ticks, not 180. `run_open` is 2.52 s of keyframes and clip.gd
		## adds a 0.75 s tail to FILM THE HAND-BACK, which is a claim worth
		## proving and not worth watching: at 180 the shot ends on half a second
		## of ordinary HUD with the letterbox already retracted. 150 lands on
		## the last keyframe and cuts straight into the boarding.
		"what": "the run-opening reveal — the deck, the sky, the braziers, the crew, the captain"},
	## THE ASK, BY NAME. See note 2 in the header: nothing is placed, everything
	## crosses. The captain starts up at the bow so the hulk, the sky over the
	## prow and the crossing are all in the same frame, and the bot walks her
	## into the party as it lands.
	## SHE STANDS ON THE CENTRELINE, and that is a composition decision with a
	## measurement behind it: boarders come down `LANE_CENTERS`, which are
	## -560 / 0 / +560, and the camera sits on her x. Take this shot from 370
	## units to port and the starboard lane's whole arrival happens off the right
	## edge behind an off-screen arrow — a third of the thing the shot is about.
	##
	## AND WAVE 4 IS DELIBERATE, not a spare number. It is the GRAPPLE RUN — the
	## wave a boarding hulk locks onto the bow and unloads from it, which is
	## precisely the picture the owner asked for, and the hulk is the dark
	## furnace-mouthed hull the crossings come off. The settle is 260 ticks
	## because `EVENT_BANNER_TIME` is 4.0 s (240) and a trailer must not open on
	## a dissolving tooltip.
	{"id": "02_board", "kind": "board", "settle": 260, "ticks": 270,
		"at": Vector2(0.50, 0.13), "zoom": 1.08,
		"what": "boarders cross from the hulk and drop onto the bow — gremlins, scrappers, a knight"},
	{"id": "03_swarm", "kind": "swarm", "settle": 110, "ticks": 190,
		"at": Vector2(0.50, 0.40),
		"what": "six swarm gremlins on the crew line, and the captain working through them"},
	{"id": "04_guns", "kind": "guns", "settle": 90, "ticks": 200,
		"at": Vector2(0.62, 0.52),
		"what": "abilities and the deck cannons — mortar, chain, sentry, cannon fire"},
	## MID-DECK AND THE THINGS ON IT: the mast, a brazier, the cargo runs, a
	## powder keg going up and the fire it leaves behind — which the bot then
	## walks OUT of, because that is rule 2 of its policy and it is nice to see.
	{"id": "05_deck", "kind": "deck", "settle": 120, "ticks": 190,
		"at": Vector2(0.44, 0.56),
		"what": "amidships — the mast, the braziers, a powder keg, and the fire it leaves"},
	## THE SCREENS. Three plates in one directory, cut in sequence: a viewer who
	## only ever sees the deck has no idea there is a run structure around it.
	{"id": "06_screens", "kind": "screens", "ticks": 186,
		"what": "the title and its Heat ladder, the berths between runs, a weapon draft"},
	{"id": "07_arrival", "kind": "cutscene", "cutscene": "colossus_arrival",
		"wave": 12, "settle": 90, "ticks": 210,
		"what": "the Colossus arrival cutscene, wave 12"},
	## 260 ticks, measured off the frames rather than guessed. `kill()` lands on
	## tick 150 (frame 75) but the Colossus does not break THERE — the death
	## runs 1.6 s of coming apart first, so the thirteen parts are only on the
	## planking around frame 118 and the wreckage has sunk by frame 132. At the
	## 300 ticks this shot was first cut to, the reel ended on eighteen frames
	## of empty deck. 260 goes out on frame 129, with the last part settling.
	{"id": "08_boss", "kind": "boss", "settle": 250, "ticks": 260,
		"what": "the Colossus fight — the slam, the half-health turn, and thirteen parts coming apart"},
	## THE CLOSER. `victory` runs 5.4 s and a trailer does not have 5.4 s to
	## spend on its last shot; 168 ticks holds the caption up through the middle
	## of the scene and hands the encoder's half-second fade something to eat.
	{"id": "09_victory", "kind": "cutscene", "cutscene": "victory", "wave": 12,
		"settle": 60, "ticks": 168,
		"what": "the victory shot — the deck held"},
]

## The three plates of `06_screens`, and how long each is held. A menu is read,
## not watched: under about 45 frames a viewer registers a flash of brass and
## nothing else. `screen` is matched against `scripts/screen_poser.gd`'s own
## list, so these are the exact screens the text audit measures.
const PLATES := [
	{"screen": "title + heat", "ticks": 62},
	{"screen": "the berths", "ticks": 58},
	{"screen": "draft (upgrades)", "ticks": 66},
]

var _fails := 0
var _bot := BotScript.new()
## Per shot: how far she actually walked. Printed at the end so the whole reel's
## movement can be read in one place — the v1 complaint, as a table.
var _tracks: Array = []


func _run() -> void:
	## `--resolution` is silently ignored for tool scripts on this machine
	## (board SG-46), so the frame size is forced here — the deck_probe/clip.gd
	## hunk verbatim. Without it the reel captures at desktop size.
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1600, 900))
	root.size = Vector2i(1600, 900)
	## THE PIN THAT MAKES THE CAPTAIN TRAVEL AT HER OWN SPEED (SG-118). She is
	## hand-stepped at DT below, and `move_and_slide()` does not take a delta —
	## it reads `get_physics_process_delta_time()`. Leave this at whatever the
	## project ships and she integrates velocity on one clock and commits ground
	## on another.
	Engine.physics_ticks_per_second = 60
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
		if str(shot.kind) == "screens":
			await _shoot_screens(shot)
		else:
			await _shoot(shot)
	_bot.release()
	if not _tracks.is_empty():
		print("")
		print("WHERE SHE WENT — ground units, from `track.csv` beside each shot")
		print("  %-12s %8s %8s %8s %8s" % ["shot", "walked", "net", "span x", "span y"])
		for row in _tracks:
			print("  %-12s %8.0f %8.0f %8.0f %8.0f" % [str(row.id),
				float(row.walked), float(row.net), float(row.span_x),
				float(row.span_y)])
	print("")
	print("demo reel %s" % ("ok" if _fails == 0 else "FAILED (%d)" % _fails))
	quit(_fails)


static func _total() -> float:
	var t := 0.0
	for shot in SHOTS:
		t += float(shot.ticks) / 60.0
	return t


## Where on the deck, as a fraction of `DECK_RECT`, using `tools/sky_shot.gd`'s
## own convention so a spot named here means the same thing as a spot named
## there. y = 0 is the BOW (the boarding hulk's end); y = 1 is the Boiler.
static func _spot(at: Vector2) -> Vector2:
	var deck: Rect2 = SkyGearGame.DECK_RECT
	return Vector2(deck.position.x + deck.size.x * at.x,
		deck.position.y + deck.size.y * at.y)


func _clear_frames(dir: String) -> void:
	## A stale sequence under a fresh one is a shot that plays two takes spliced.
	if DirAccess.dir_exists_absolute(dir):
		for old in DirAccess.get_files_at(dir):
			if str(old).begins_with("frame_") and str(old).ends_with(".png"):
				DirAccess.remove_absolute("%s/%s" % [dir, str(old)])
	DirAccess.make_dir_recursive_absolute(dir)


func _shoot(shot: Dictionary) -> void:
	var id := str(shot.id)
	var ticks := int(shot.ticks)
	var frames := ticks / EVERY
	var dir := "%s/%s" % [ProjectSettings.globalize_path("res://.shots/demo"), id]
	_clear_frames(dir)
	print("shot %s — %d frames, %.2fs" % [id, frames, float(ticks) / 60.0])

	var world = load("res://scenes/main3d.tscn").instantiate()
	root.add_child(world)
	await process_frame
	var game: SkyGearGame = world.get_node("SkyGear")
	## Both clocks are ours; the engine would otherwise step them again at
	## whatever the wall clock happened to be.
	game.set_process(false)
	game.set_physics_process(false)
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
	## AND THE CAPTAIN, which the two lines above never reach (SG-118). She is
	## her own node; disabled here and hand-stepped in `_tick`, or the engine
	## walks her on a clock this tool does not control.
	game.player.set_physics_process(false)
	game.player.set_process(false)
	## The full bar, seated identically in every shot — the whole reason this
	## tool is not three more clip.gd scenarios.
	game.skills.clear()
	for pair in BAR:
		game.skills.append(SkyGearData.make_skill(str(pair[0]), str(pair[1])))

	if shot.has("zoom"):
		world.set("_zoom", float(shot.zoom))
		world.set("_zoom_target", float(shot.zoom))
	if shot.has("at"):
		game.player.global_position = _spot(shot.at)
		game.player.velocity = Vector2.ZERO
		## Snap the camera to her rather than letting it ease across the deck
		## through the settle — the first captured frame should open on the shot,
		## not on the tail of a pan.
		world.set("_focus", game.player.global_position)
		world.set("_focus_set", true)

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
		"board":
			## NOTHING IS PLACED HERE — that is the whole shot. `spawn_enemy`
			## puts a boarder at the bow rail in `state == "climb"`, and the
			## renderer lifts it off the planking and flies it in from the hulk
			## over `SkyGearEnemy.ARRIVAL_TIME`. `_place` would end that window
			## on its second line, which is exactly how v1 lost the arrival.
			##
			## The settle is long on purpose: `ARRIVAL_APPROACH` is 2.6 s and the
			## hull is only ON the bow hold at the end of it. Open earlier and
			## the transport is still sliding forward behind the crossing.
			game.start_wave(4)
			_hold_wave_open(game)
			game.crew_timer = 0.0
			game._update_crew(0.05)
			await _settle(game, world, int(shot.settle))
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
					Vector2(float(spread[n]), -120.0 + float(n % 3) * 40.0))
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
		"deck":
			## Amidships, around the mast at (0,-180), the brazier at (160,330)
			## and the keg at (100,50) — `SkyGearData.PROP_LAYOUT`'s own
			## furniture, none of it moved. Two knights and two scrappers give
			## the bot something to kite around it.
			game.start_wave(6)
			_hold_wave_open(game)
			for stand in [
					{"kind": "ARMORED", "lane": 1, "at": Vector2(-40.0, -190.0)},
					{"kind": "SCRAPPER", "lane": 0, "at": Vector2(-380.0, 40.0)},
					{"kind": "SCRAPPER", "lane": 2, "at": Vector2(330.0, -60.0)},
					{"kind": "SWARM", "lane": 1, "at": Vector2(150.0, 180.0)}]:
				_place(game, str(stand.kind), int(stand.lane), stand.at)
			await _settle(game, world, int(shot.settle))
		"boss":
			## WAVE 12, where he actually arrives — clip.gd stages him on wave 1
			## because the wave number is not what it is measuring, and here it
			## is on camera. One Colossus, spawned through the real
			## `spawn_enemy`, so it is the simulation's own arrival, AI and all.
			game.start_wave(12)
			_hold_wave_open(game)
			_place(game, "BOSS", 1, Vector2(-10.0, 215.0))
			await _settle(game, world, int(shot.settle))

	game.effects.clear()

	## THE SHUTTER. `frames` groups of `EVERY` ticks, one PNG per group, so the
	## file count on disk is this arithmetic or the loop is broken.
	var track: Array[Vector2] = []
	var tick := 0
	for frame in frames:
		for _step in EVERY:
			tick += 1
			_beat(game, kind, tick)
			await _tick(game, world)
		track.append(game.player.global_position)
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
	_record_track(id, dir, track, kind == "cutscene")


## ONE TICK OF THE WHOLE DECK, and every clock in it is this one.
##
## The order matters and is `tools/balance.gd`'s: STEER first, so the input she
## acts on this tick matches the deck she is about to be stepped through; then
## the simulation; then the three node kinds that own a `_physics_process` or a
## `_process` the game node's own does not reach — the boarders, the props and
## the captain. Anything left on the engine's clock runs at whatever the wall
## clock produced and the shot is a different length every time it is filmed.
func _tick(game: SkyGearGame, world) -> void:
	_bot.steer(game)
	game._process(DT)
	for foe in game.get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(foe):
			foe.set_physics_process(false)
			foe._physics_process(DT)
	## A lit keg's 0.45 s fuse lives in `prop.gd:_process` and a keg is 26
	## damage; on the engine's clock it goes off wherever the awaited frames
	## happened to fall.
	for prop in game.get_tree().get_nodes_in_group("props"):
		if is_instance_valid(prop):
			prop.set_process(false)
			prop._process(DT)
	if is_instance_valid(game.player):
		game.player._physics_process(DT)
	## THE COACH IS OFF, and it has to be switched off HERE rather than before
	## the loop. `scripts/coach.gd` fires from wave 2 onward and `game._process`
	## re-derives `coach_line` every tick, so there is no flag to set once — the
	## line has to be cleared between the sim step and the render step, which is
	## the only window in which it exists and has not yet been drawn. Without
	## this the boss shot carries "HOLD E / 4 to arm the Sentry..." across the
	## Colossus coming apart: correct teaching, ruinous trailer. Nothing in
	## `scripts/` is touched — the coach still runs, it just has no sentence on
	## screen while the reel is filming.
	game.coach_line = ""
	world._process(DT)
	## AND `CLICK TO SKIP` IS OFF, for the same reason and by the same route: it
	## is real UI, it is right in the game, and on a clip it reads as a screen
	## recording. Done every tick rather than once because the label is built by
	## `_build_bars` when a scene starts, so there is no earlier moment at which
	## it exists. `visible` rather than `modulate`, because `_fade_bars` writes
	## the alpha on every frame and would put it straight back.
	_hush_skip_hint(world)
	await process_frame


func _hush_skip_hint(world) -> void:
	var player = world.get("_cutscene")
	if player == null:
		return
	var hint = player.get("_skip_hint")
	if hint != null and is_instance_valid(hint):
		hint.visible = false


## HOW FAR SHE ACTUALLY WENT. Written beside the frames as well as printed: a
## number in a terminal is gone when the terminal is, and the claim this reel
## has to make is exactly the one v1 could not.
func _record_track(id: String, dir: String, track: Array[Vector2],
		exempt: bool) -> void:
	if track.is_empty():
		return
	var walked := 0.0
	var lo := track[0]
	var hi := track[0]
	for i in track.size():
		if i > 0:
			walked += track[i].distance_to(track[i - 1])
		lo = Vector2(minf(lo.x, track[i].x), minf(lo.y, track[i].y))
		hi = Vector2(maxf(hi.x, track[i].x), maxf(hi.y, track[i].y))
	var net := track[0].distance_to(track[track.size() - 1])
	var lines := PackedStringArray(["frame,x,y"])
	for i in track.size():
		lines.append("%d,%.1f,%.1f" % [i, track[i].x, track[i].y])
	var file := FileAccess.open("%s/track.csv" % dir.replace("\\", "/"),
		FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines) + "\n")
		file.close()
	_tracks.append({"id": id, "walked": walked, "net": net,
		"span_x": hi.x - lo.x, "span_y": hi.y - lo.y})
	print("  walked %.0f units, net %.0f, span %.0f x %.0f%s"
		% [walked, net, hi.x - lo.x, hi.y - lo.y,
			"  (cutscene — her controls are locked)" if exempt else ""])


## THE SCREENS, in one directory so they cut as one beat. A separate function
## rather than another `kind` because `scripts/screen_poser.gd` builds its own
## world state from the title up for every plate, which is the opposite of what
## every other shot here wants.
##
## The poser is the audit's and the F4 editor's, so what is filmed is what the
## text audit measures at 1600x900 — not a second set of poses that could drift
## from it. It leaves `game.set_process(false)` behind it deliberately (a posed
## screen must be the same state twice), and the RENDERER is still stepped here
## so the braziers and the sway carry on behind the sheet: a menu over a dead
## deck is the one thing that would make these three plates read as mock-ups.
func _shoot_screens(shot: Dictionary) -> void:
	var id := str(shot.id)
	var dir := "%s/%s" % [ProjectSettings.globalize_path("res://.shots/demo"), id]
	_clear_frames(dir)
	var planned := 0
	for plate in PLATES:
		planned += int(plate.ticks) / EVERY
	print("shot %s — %d frames, %.2fs (%d plates)"
		% [id, planned, float(shot.ticks) / 60.0, PLATES.size()])

	var world = load("res://scenes/main3d.tscn").instantiate()
	root.add_child(world)
	await process_frame
	var game: SkyGearGame = world.get_node("SkyGear")
	var hud = game.hud
	world.set_process(false)
	world.cutscenes_enabled = false
	world.stop_cutscene()
	world.sway = true
	game.log_runs = false

	var frame := 0
	for plate in PLATES:
		var screen := Screens.find(str(plate.screen))
		if screen.is_empty():
			print(" FAIL no screen called '%s'" % str(plate.screen))
			_fails += 1
			continue
		## THE CANVAS, NOT THE WINDOW. `pose()` writes `hud.size` from this, and
		## the project ships `canvas_items` stretch on a 1920x1080 base — so
		## handing it `root.size` (1600x900) lays the whole interface out inside
		## the left-hand 83% of a canvas that is then scaled to fill the window,
		## and every plate comes back with a seam down it at x = 1333. The
		## visible rect is the canvas the HUD actually draws into.
		await Screens.pose(self, game, hud, screen,
			Vector2(root.get_visible_rect().size))
		## Two settled frames before the shutter, screen_shot.gd's reason
		## verbatim: the pose touches the simulation and the HUD redraws on
		## `_process`, so the first frame after a pose can carry the previous
		## screen's plate.
		for _i in 2:
			hud.queue_redraw()
			await process_frame
		for _f in int(plate.ticks) / EVERY:
			for _step in EVERY:
				world._process(DT)
				await process_frame
			hud.queue_redraw()
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(
				"%s/frame_%04d.png" % [dir.replace("\\", "/"), frame])
			frame += 1
		print("  %-18s %3d frames" % [str(plate.screen), int(plate.ticks) / EVERY])

	world.queue_free()
	await process_frame
	var on_disk := 0
	for file in DirAccess.get_files_at(dir):
		if str(file).begins_with("frame_") and str(file).ends_with(".png"):
			on_disk += 1
	if on_disk != planned:
		print(" FAIL %d frames on disk, planned %d" % [on_disk, planned])
		_fails += 1
	else:
		print("  ok %d frames -> %s" % [on_disk, dir])


## What happens on which captured tick. Every beat below is fired through the
## simulation's own door — `spawn_enemy`, `cast_skill`, `kill()`, an hp
## assignment the player's damage could equally have made — so what films is
## what a run does.
func _beat(game: SkyGearGame, kind: String, tick: int) -> void:
	match kind:
		"board":
			## FIVE GROUPS ACROSS THE WHOLE SHOT, not one volley at the head.
			## `ARRIVAL_TIME` is 0.8 s — 48 ticks — so a single wave of arrivals
			## is over eight tenths of a second after it starts and the other
			## three and a half seconds are an ordinary deck fight. Spaced like
			## this there is a figure in the air, or a ring closing on the
			## planking, for most of the cut, and the groups overlap: the first
			## is still falling when the second launches.
			##
			## The kinds are the three that actually cross. The Colossus never
			## does — he arrives by cutscene — so he is not here.
			if tick == 6:
				game.spawn_enemy("SWARM", 0)
				game.spawn_enemy("SWARM", 1)
				game.spawn_enemy("SCRAPPER", 2)
			elif tick == 30:
				game.spawn_enemy("SCRAPPER", 0)
				game.spawn_enemy("SWARM", 2)
			elif tick == 54:
				game.spawn_enemy("ARMORED", 1)
				game.spawn_enemy("SWARM", 0)
			elif tick == 104:
				game.spawn_enemy("SWARM", 2)
				game.spawn_enemy("SCRAPPER", 1)
			elif tick == 156:
				game.spawn_enemy("SWARM", 0)
				game.spawn_enemy("ARMORED", 2)
			elif tick == 200:
				_cast_at_nearest(game, 0)
			elif tick == 240:
				_cast_at_nearest(game, 2)
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
		"deck":
			## THE KEG, blown the way a player blows one: a shell into it. It is
			## `PROP_LAYOUT`'s keg at (100, 50), it takes the shot through the
			## real prop damage path, and what it leaves behind is a real fire
			## pool at the radius SG-163 made it draw at — which the bot then
			## walks out of on its own.
			if tick == 24:
				game.cast_skill(1, Vector2(100.0, 50.0))
			elif tick == 90:
				_cast_at_nearest(game, 0)
			elif tick == 140:
				_cast_at_nearest(game, 2)
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
##
## NOTE THE THIRD LINE. `state = "move"` ENDS the arrival window, which is right
## for a shot that opens on a deck already fought over and wrong for one about
## the crossing. `02_board` does not call this at all.
func _place(game: SkyGearGame, kind: String, lane: int, at: Vector2) -> void:
	game.spawn_enemy(kind, lane)
	var live := game.get_tree().get_nodes_in_group("enemies")
	var placed = live[live.size() - 1]
	placed.global_position = at
	placed.lane = lane
	placed.state = "move"


## The un-captured run-up, on the same clock and through the same door as the
## shutter — including the bot, so the captain is already moving on frame one
## rather than accelerating out of a standstill into the cut.
func _settle(game: SkyGearGame, world, ticks: int) -> void:
	for _i in ticks:
		await _tick(game, world)


## An empty wave AUTO-CLEARS and the draft photobombs the shot (the SG-36
## story): one spawn parked in the far future holds the wave open without
## putting an uninvited boarder in frame.
func _hold_wave_open(game: SkyGearGame) -> void:
	game.spawn_queue.clear()
	game.spawn_queue.append({"time": 99999.0, "kind": "SCRAPPER", "lane": 1})
