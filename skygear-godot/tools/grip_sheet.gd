extends SceneTree
## IS THE WEAPON ACTUALLY IN THE HAND — AT REST AND THROUGH THE SWING (SG-170).
##
## Alex hand-modelled a boarding pike, a furnace axe and a scrap wrench; they
## were ingested, committed, registered in `assets/models/weapons.json` and
## never appeared on the deck, because the only `hold()` call in the renderer
## was the hero's. `view3d.mount_weapon` is the fix; this is the instrument that
## says whether the FIT is right, which is a different question and a visual one.
##
##   godot --path . --resolution 1600x900 --script tools/grip_sheet.gd -- .shots/sg170
##   ... -- .shots/sg170 --who CREW                     one subject, fast loop
##   ... -- .shots/sg170 --who CREW --variants "-96,-96,0,0.38,0.05,0;-90,0,0"
##
## Then `python tools/grip_montage.py <dir>` stitches the frames into one sheet,
## because a grip is judged by comparing poses and not by staring at one.
##
## NOT --headless: the whole output is PNGs and --headless makes them empty
## (board SG-29).
##
## WHY IT SHOOTS THROUGH THE REAL GAME rather than posing a rig in a lab, which
## would be half the code. `tools/weapon_fit.gd` already is that lab, and the
## thing a lab cannot tell you is the thing this row is about: whether the GAME
## mounts anything at all. A lab that loads the table itself and calls `hold()`
## itself would have photographed a beautifully fitted pike every day for the
## whole life of the port while the deck stayed empty-handed. So the world here
## is `scenes/main3d.tscn`, the figures come through `spawn_enemy` and
## `game.crew`, the mount comes through `view3d.mount_weapon`, and the only
## thing this file knows how to do is point a camera.
##
## WHY EVERY SUBJECT IS SHOT MID-SWING AND NOT JUST AT IDLE. A grip is a rigid
## offset from a hand bone; a hand bone travels furthest, fastest and through the
## widest wrist rotation at the middle of an attack. A haft that sits sweetly in
## a resting fist routinely swings THROUGH the forearm or leaves the hand
## entirely, and neither is visible in an idle frame. The phases below straddle
## contact deliberately.
func _initialize() -> void: call_deferred("_run")


## The three figures SG-170 armed, and the one control. SCRAPPER carries no row
## in the weapon table and must come back with EMPTY HANDS and no error — an
## absent fit is a refusal, not a crash, and the only way to know the refusal is
## clean is to photograph it beside the three that are not refused.
## `spot` is per subject because the camera distance scales with the FIGURE:
## a gremlin is a third the knight's height, so his camera stands a third as far
## back and a deck cannon eight metres away fills half his frame. There is no one
## place on this deck that is clear for a 0.83 m goblin and for a 1.44 m sailor
## carrying two metres of pike. `--spot x,y` overrides.
const SUBJECTS := [
	{"kind": "ARMORED", "spot": Vector2(0.0, 430.0)},
	{"kind": "SWARM", "spot": Vector2(0.0, 80.0)},
	{"kind": "CREW", "spot": Vector2(0.0, 430.0)},
	{"kind": "SCRAPPER", "spot": Vector2(0.0, 80.0)},
]

## Fractions of the CLIP, not of the skill window: `seek` addresses the clip.
## `idle` and `run` are where a boarder spends most of its life; the three
## `swing` phases straddle contact.
const PHASES := [
	{"tag": "1-idle", "clip": "idle", "at": 0.50},
	{"tag": "2-swing-020", "clip": "swing", "at": 0.20},
	{"tag": "3-swing-050", "clip": "swing", "at": 0.50},
	{"tag": "4-swing-080", "clip": "swing", "at": 0.80},
	{"tag": "5-run", "clip": "run", "at": 0.35},
]

## Where the camera stands, in degrees around the figure. 35 is the three-quarter
## front the reference paintings are drawn at; 92 is dead side-on, which is the
## only angle a two-handed levelled pike can be judged from — pointed at the
## camera it is a disc.
## `a` looks from the port bow quarter rather than the starboard one because the
## BOILER stands between the starboard quarter and mid-deck, and it ate the
## subject in every `a` frame of the first pass.
## THREE, AND THE THIRD IS NOT A LUXURY: a weapon is mounted on the RIGHT hand,
## so a camera parked off the left shoulder has the whole body between it and the
## thing being judged. The furnace knight's axe was invisible in every frame of
## two whole sweeps for that reason and read as "not mounted" until a camera was
## put on the other side of him.
const ANGLES := [
	{"tag": "a", "yaw": -40.0},
	{"tag": "b", "yaw": 92.0},
	{"tag": "c", "yaw": 250.0},
]

## Where the captain is parked. Off the frame's shoulder: she is the one figure
## here whose grip is already fitted and a cutlass crossing the shot is a
## distraction from the three that are not.
const CAPTAIN_PARK := Vector2(900.0, 700.0)
## Where the subject stands. Mid-deck and clear: at the first spot tried a
## crewman's two-metre pike ran behind the port cargo run and its POINT — the
## end of it you are trying to judge — was occluded in every frame taken of it.
const SPOT := Vector2(0.0, 430.0)


## `--spot x,y` overrides it, because "clear deck" depends on how CLOSE the
## camera has to stand: it scales with the figure, so a gremlin — a third the
## knight's height — gets a camera three times nearer and a deck cannon eight
## metres away fills half his frame.
var _spot := SPOT
var _spot_set := false


var _out := ".shots/sg170"
var _variants: Array = []
var _solve_grip := false
var _shots := true


## SLIDE THE WEAPON ALONG ITS OWN SHAFT UNTIL ITS GRIP POINT IS IN THE FIST, and
## print the `offset` that does it. `--grip`.
##
## THE PROBLEM THIS REMOVES. `hold()` puts the weapon's own ORIGIN at `offset`,
## and for every model in this manifest that origin is the middle of the mesh —
## so a two-metre pike mounted at offset zero has a metre of itself sticking out
## behind the man holding it. The fix is a slide ALONG the shaft, which is a
## one-dimensional quantity expressed in the table as a three-dimensional vector
## in BONE axes, and it changes every time you touch the rotation. Searching for
## it by eye is a three-axis hunt for a one-axis answer, re-run after every
## rotation nudge, which is how a grip ends up "slightly wrong" and stays there.
##
## AND IT GIVES `grip_at` A READER AT LAST. Every weapon in the `weapons` block
## carries `grip_at` — where along the shaft the hand belongs, 0 at the butt —
## authored from Alex's own modelling spec (`handoff-3d/weapons/PROMPTS.md`) and
## read by NOTHING in this repository until now: STATUS's first failure mode,
## sitting in the same file as the assets this row is about. It is read HERE, in
## the fitting tool, and deliberately NOT in the renderer: making the game apply
## it would silently move the captain's cutlass, whose `offset` is Alex's own
## hand-fit and is not this row's to touch. Filed as SG-171.
##
## The arithmetic. `blade_tip` is stamped by `hold()` in MOUNT space and is the
## far end of the weapon measured from the hand, so with offset zero it is half
## the weapon: the whole shaft is `2 * blade_tip` and the grip point sits at
## `(g - 0.5)` of it. Bringing that point to the hand is the negation. The
## conversions out are the two `hold()` applies on the way in — `per_unit` from
## bone units to metres, `to_world` from metres to the table's 1.8 m frame — so
## what is printed is a number you can paste into `weapons.json` unchanged.
func _grip_offset(rig: SkyGearRig3D, grip_at: float, to_world: float) -> Array:
	if rig.held == null or not rig.held.has_meta("blade_tip"):
		return [0.0, 0.0, 0.0]
	var tip: Vector3 = rig.held.get_meta("blade_tip")
	var pts := rig.blade_points()
	if pts.size() != 2 or tip.length() < 1e-6:
		return [0.0, 0.0, 0.0]
	var per_unit: float = pts[0].distance_to(pts[1]) / tip.length()
	var off: Vector3 = tip * (0.5 - grip_at) * 2.0 * per_unit / maxf(0.0001, to_world)
	return [snappedf(off.x, 0.001), snappedf(off.y, 0.001), snappedf(off.z, 0.001)]


## What the weapons block says about this figure's weapon. The per-character row
## names a weapon; the weapon names its own grip.
static func grip_of(who: String) -> float:
	var table = JSON.parse_string(
		FileAccess.get_file_as_string(SkyGearRig3D.WEAPON_TABLE))
	if table is not Dictionary or not (table as Dictionary).has(who):
		return 0.5
	var key := str(((table as Dictionary)[who] as Dictionary).get("weapon", ""))
	var weapons: Dictionary = (table as Dictionary).get("weapons", {})
	return float((weapons.get(key, {}) as Dictionary).get("grip_at", 0.5))


func _run() -> void:
	var argv := OS.get_cmdline_user_args()
	if argv.size() > 0 and not str(argv[0]).begins_with("--"):
		_out = str(argv[0])
	var only := ""
	for i in argv.size():
		if argv[i] == "--who" and i + 1 < argv.size():
			only = str(argv[i + 1]).to_upper()
		elif argv[i] == "--variants" and i + 1 < argv.size():
			_variants = _parse_variants(str(argv[i + 1]))
		elif argv[i] == "--grip":
			_solve_grip = true
		elif argv[i] == "--spot" and i + 1 < argv.size():
			var xy := str(argv[i + 1]).split(",", false)
			if xy.size() >= 2:
				_spot = Vector2(float(xy[0]), float(xy[1]))
				_spot_set = true
		elif argv[i] == "--numbers":
			## Skip the exposures. A coarse rotation search is forty variants
			## times fifteen poses, and six hundred PNGs of a hunt you are going
			## to throw away is four minutes of disk for nothing — the numbers
			## alone narrow it to three candidates and THOSE get photographed.
			## Looking is still what decides; this only stops you looking at
			## thirty-seven frames you already know are wrong.
			_shots = false
	DirAccess.make_dir_recursive_absolute(_out)
	if _variants.is_empty():
		## The shipped table, which is the only thing worth photographing once
		## the fitting is finished.
		_variants = [{}]
	for row in SUBJECTS:
		var kind: String = str(row.kind)
		if only != "" and kind != only:
			continue
		if not _spot_set:
			_spot = row.spot
		await _subject(kind)
	print("grip sheet ok -> ", _out)
	quit(0)


## `rx,ry,rz[,ox,oy,oz[,len]]` per variant, semicolons between. Everything
## omitted is left at whatever the shipped row says, so a rotation sweep does
## not silently reset an offset you already like.
func _parse_variants(text: String) -> Array:
	var out: Array = []
	for chunk in text.split(";", false):
		var n := PackedFloat64Array()
		for f in str(chunk).split(",", false):
			n.append(float(str(f).strip_edges()))
		var v: Dictionary = {}
		if n.size() >= 3:
			v["rotation"] = [n[0], n[1], n[2]]
		if n.size() >= 6:
			v["offset"] = [n[3], n[4], n[5]]
		if n.size() >= 7:
			v["length"] = n[6]
		out.append(v)
	return out


## ONE WORLD PER SUBJECT, every variant and pose shot inside it. The first draft
## rebuilt `main3d.tscn` for each of forty frames and a fitting pass took eleven
## minutes, which is long enough that you stop iterating and start reasoning —
## and reasoning is the thing this row's brief says does not find a grip.
##
## Safe to reuse here for the reason a photographing tool usually cannot: the
## scene is FROZEN before the first exposure and nothing but the mount and the
## `seek` moves between frames, so there is no blend, no effect and no clock to
## carry over. `telegraph_beat.gd` rebuilds because it re-poses the SIMULATION.
func _subject(kind: String) -> void:
	var world = load("res://scenes/main3d.tscn").instantiate()
	root.add_child(world)
	await process_frame
	var game: SkyGearGame = world.get_node("SkyGear")
	game.set_process(false)
	world.sway = false
	## A tool that opens a real run writes rows into `user://runs.json`, which
	## the harness reads. SG-101's mistake, and cheaper not to make twice.
	game.log_runs = false
	game.workshop = SkyGearWorkshop.fresh(true)
	game.heat = 0
	game.set_class("captain")
	game.set_seed_text("SG170")
	game.begin_run()
	game.choose_draft(0)
	game.start_wave(3)
	game.spawn_queue.clear()
	if game.view != null:
		game.view.cutscenes_enabled = false
		game.view.stop_cutscene()
	game.player.global_position = CAPTAIN_PARK
	game.player.velocity = Vector2.ZERO

	var subject: SkyGearEnemy = null
	var crewman: Dictionary = {}
	if kind == "CREW":
		game.crew.clear()
		crewman = SkyGearLanes.make_crew(1, SkyGearGame.LANE_CENTERS,
			SkyGearGame.BASE_Y, null)
		crewman["position"] = _spot
		game.crew.append(crewman)
	else:
		game.spawn_enemy(kind, 1)
		for e in game.get_tree().get_nodes_in_group("enemies"):
			if is_instance_valid(e) and str(e.kind) == kind:
				subject = e
		if subject == null:
			print("  %s -- did not spawn" % kind)
			world.queue_free()
			await process_frame
			return
		subject.global_position = _spot
		subject.state = "move"

	## Let the renderer build the rig and settle. The mount happens on the FIRST
	## frame a rig is created, so anything after this is holding a weapon or the
	## row this tool exists for is not done.
	for _i in 30:
		game._process(1.0 / 60.0)
		if subject != null:
			subject.global_position = _spot
			subject.attack_direction = Vector2(0.0, 1.0)
			subject.velocity = Vector2.ZERO
		else:
			crewman["position"] = _spot
			crewman["attack_direction"] = Vector2(0.0, 1.0)
			crewman["velocity"] = Vector2.ZERO
		game.player.global_position = CAPTAIN_PARK
		await process_frame
	game.effects.clear()

	var rig := _rig_of(game, kind, subject, crewman)
	if rig == null:
		print("  %s -- NO RIG" % kind)
		world.queue_free()
		await process_frame
		return
	## THE ANSWER TO THE ROW'S ACTUAL QUESTION, printed before any picture: did
	## the GAME put something in this hand, off the shipped table, with no help
	## from this tool.
	print("%s  rig %.2f m  shipped table: %s"
		% [kind, rig.fit_height, "HOLDING" if rig.held != null else "EMPTY-HANDED"])

	await SkyGearStill.freeze(self, world, game)
	## THE HUD OFF. Four brass panels over the bottom third of the frame is
	## exactly where a levelled pike and a low-swung wrench live.
	for layer in world.find_children("*", "CanvasLayer", true, false):
		(layer as CanvasLayer).visible = false
	var cam := Camera3D.new()
	world.add_child(cam)
	cam.fov = 34.0
	cam.current = true

	var ground_height: float = rig.fit_height / SkyGearView3D.WORLD_SCALE
	var to_world: float = rig.fit_height / 1.8
	for vi in _variants.size():
		var variant: Dictionary = _variants[vi]
		if not variant.is_empty():
			SkyGearView3D.mount_weapon(rig, kind.to_lower(), ground_height, variant)
			## A `BoneAttachment3D` learns its transform on the skeleton's next
			## pass, and `hold()` measures the bone's scale off it — so a mount
			## built and photographed inside one frame is scaled off an identity
			## basis. Two frames, then mount AGAIN off the settled attachment,
			## and the reach printed below matches the shipped path exactly.
			## Without the second call a swept variant reads ~3x its true length
			## and every number you would author from it is wrong.
			await process_frame
			await process_frame
			SkyGearView3D.mount_weapon(rig, kind.to_lower(), ground_height, variant)
			await process_frame
			if _solve_grip:
				## Solved against THIS variant's rotation, because the slide is
				## along the shaft and the rotation is what decides where the
				## shaft lies. Solving once for the whole sweep would hand every
				## rotation the answer for the first one.
				variant = variant.duplicate()
				variant["offset"] = [0.0, 0.0, 0.0]
				SkyGearView3D.mount_weapon(rig, kind.to_lower(), ground_height,
					variant)
				await process_frame
				var g := grip_of(kind.to_lower())
				variant["offset"] = _grip_offset(rig, g, to_world)
				SkyGearView3D.mount_weapon(rig, kind.to_lower(), ground_height,
					variant)
				await process_frame
				print("  grip_at %.2f -> offset %s" % [g, str(variant.offset)])
		print("%s v%d  %s" % [kind.to_lower(), vi, str(variant)])
		for phase in PHASES:
			for angle in ANGLES:
				var tag := "" if _variants.size() == 1 else "v%d-" % vi
				var path: String = "%s/%s%s-%s-%s.png" % [_out, tag,
					kind.to_lower(), str(phase.tag), str(angle.tag)]
				_expose(rig, cam, phase, float(angle.yaw))
				await process_frame
				if _shots:
					await RenderingServer.frame_post_draw
					root.get_texture().get_image().save_png(
						path.replace("\\", "/"))
				## Reported once per POSE, not once per variant: where a weapon
				## points is a property of the pose it is in, and a single
				## number printed after the last exposure describes only the run
				## cycle. Reporting the idle triple as if it held through the
				## swing is exactly the "judged off one frame" this row forbids.
				if angle == ANGLES[0]:
					_report(rig, "    %s" % str(phase.tag))
	world.queue_free()
	await process_frame


## Pose the clip and point the camera. Everything here is written AFTER the
## freeze: `seek` still writes a pose through a player whose `speed_scale` is
## zero, which is the whole reason the order is freeze-then-pose (SG-108).
func _expose(rig: SkyGearRig3D, cam: Camera3D, phase: Dictionary,
		yaw: float) -> void:
	var clip := str(phase.clip)
	if not rig.has_clip(clip):
		clip = rig.playing()
	if clip != "" and rig.anim != null and rig.anim.has_animation(clip):
		rig.anim.play(clip)
		rig.anim.seek(rig.anim.get_animation(clip).length * float(phase.at), true)
	var at: Vector3 = rig.global_position
	var tall: float = rig.fit_height
	## FRAMED ON THE PAIR, not on the figure: a crewman is 1.44 m and his pike is
	## two metres, so a camera placed off the body alone crops the point of the
	## weapon out of every picture taken of it.
	var pts := rig.blade_points()
	var reach: float = pts[0].distance_to(pts[1]) if pts.size() == 2 else 0.0
	var frame: float = maxf(tall, reach * 1.5)
	var a := deg_to_rad(yaw)
	var back: float = maxf(1.4, frame * 1.75)
	## Orbit the camera rather than turning the rig: turning the rig would move
	## it relative to the deck lamps and change what the picture is lit by
	## between two angles of what is meant to be one comparison.
	cam.position = at + Vector3(sin(a) * back, tall * 0.80, cos(a) * back)
	cam.look_at(at + Vector3(0.0, tall * 0.50, 0.0))


## THE NUMBERS BESIDE THE PICTURES, and they are what turns a rotation search
## from squinting into arithmetic.
##
## `blade_points` returns the hand and the point of the weapon furthest from it,
## both in WORLD metres. Reported here in the FIGURE'S OWN FRAME — the rig faces
## local +Z (`place` builds its basis that way) — so the three components read
## as `fwd` (out in front of him), `side` (across his body, + to his left) and
## `up`. That is the frame the design intent is written in: a levelled pike
## wants a big +fwd and a small |up|; an axe raised overhead wants a big +up;
## a wrench swung low wants a negative one. A picture tells you it is wrong; the
## triple tells you which way to turn it.
func _report(rig: SkyGearRig3D, label: String) -> void:
	var pts := rig.blade_points()
	if pts.size() != 2:
		print("  %-46s held=NO" % label)
		return
	var basis := rig.global_transform.basis.orthonormalized()
	var rel: Vector3 = pts[1] - pts[0]
	var local := Vector3(rel.dot(basis.x), rel.dot(basis.y), rel.dot(basis.z))
	## Where the hand itself is, as a fraction of the figure's height, because
	## "the axe is over his head" is a claim about the TIP and not about the arm.
	var tip_up: float = (pts[1].y - rig.global_position.y) / maxf(0.01, rig.fit_height)
	print("  %-46s reach %.2f m (%.0f%%)  fwd %+.2f  side %+.2f  up %+.2f  tip@%.2f body"
		% [label, rel.length(), 100.0 * rel.length() / maxf(0.01, rig.fit_height),
			local.z, local.x, local.y, tip_up])


## The rig the renderer built for this figure, found the way the renderer keys
## it — enemies by instance id, a crewman by the `rig_key` the renderer stamps
## into his own dictionary (SG-88).
func _rig_of(game: SkyGearGame, kind: String, subject: SkyGearEnemy,
		crewman: Dictionary) -> SkyGearRig3D:
	if game.view == null:
		return null
	var key := ""
	if kind == "CREW":
		key = str(crewman.get("rig_key", ""))
	else:
		for k in game.view._rigs.keys():
			var r = game.view._rigs[k]
			if is_instance_valid(r) and str(r.get_meta("model_key", "")) \
					== kind.to_lower():
				key = str(k)
	if key == "" or not game.view._rigs.has(key):
		return null
	return game.view._rigs[key] as SkyGearRig3D
