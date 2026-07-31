extends SceneTree
## Does the sword look HELD?
##
## Attaching a weapon to a hand is a dozen small nudges — a degree of roll, two
## centimetres along the palm — and each nudge through an edit / export / launch
## / find-a-boarder loop is five minutes. This renders the captain holding
## whatever `assets/models/weapons.json` says, across the poses where a bad fit
## shows, into one contact sheet. Nudge a number in the JSON, run it again.
##
##   godot --path . --script tools/weapon_fit.gd
##   godot --path . --script tools/weapon_fit.gd -- --weapon sword_gearblade
##
## Writes `.shots/weapon-fit.png`. NOT headless — it has to rasterise.
##
## The poses are chosen for what each one catches:
##   idle    the resting grip, where the hand is closed and nothing is moving
##   swing   the frame a bad fit is loudest, mid-arc with the wrist rolled over
##   run     whether it clips her leg on the pass
##   dash    the extreme, where the arm is furthest from the body
func _initialize() -> void: call_deferred("_run")

const POSES := [
	{"clip": "idle", "at": 0.5, "yaw": 0.55},
	{"clip": "swing", "at": 0.42, "yaw": 0.9},
	{"clip": "swing", "at": 0.62, "yaw": -0.5},
	{"clip": "run", "at": 0.3, "yaw": 1.4},
	{"clip": "walk", "at": 0.5, "yaw": 2.6},
	{"clip": "dash", "at": 0.5, "yaw": 0.2},
]
const CELL := Vector2i(360, 520)
const COLUMNS := 3


func _run() -> void:
	var which := ""
	var sweep := ""
	var argv := OS.get_cmdline_user_args()
	for i in argv.size():
		if argv[i] == "--weapon" and i + 1 < argv.size():
			which = argv[i + 1]
		if argv[i] == "--sweep" and i + 1 < argv.size():
			sweep = argv[i + 1]

	var fit := SkyGearRig3D.weapon_fit("captain")
	if fit.is_empty():
		print("no fit for 'captain' in assets/models/weapons.json")
		quit(1)
		return
	if which != "":
		var table = JSON.parse_string(
			FileAccess.get_file_as_string(SkyGearRig3D.WEAPON_TABLE))
		var weapons: Dictionary = (table as Dictionary).get("weapons", {})
		if not weapons.has(which):
			print("unknown weapon '%s'" % which)
			quit(1)
			return
		fit["path"] = str((weapons[which] as Dictionary).get("path", ""))

	print("")
	print("WEAPON FIT  ·  %s" % str(fit.path).get_file())
	print("  bone     %s" % str(fit.bone))
	print("  offset   %s" % str(fit.offset))
	print("  rotation %s" % str(fit.rotation))
	print("  length   %.2f m" % float(fit.length))

	## One viewport per cell, composited at the end. Rendering six poses into one
	## scene and moving a camera between them is the same picture six times with
	## a stale frame in it — sub-viewports each settle on their own.
	var sheet := Image.create(CELL.x * COLUMNS,
		CELL.y * 2, false,
		Image.FORMAT_RGBA8)
	sheet.fill(Color(0.06, 0.05, 0.08))

	## SWEEP MODE. Which way a hand bone points is a property of whoever rigged it,
	## and guessing it one build at a time is the slow loop this tool exists to
	## kill. `--sweep x` holds the pose still and turns the weapon instead, so the
	## right number is something you read off a sheet rather than converge on.
	var cells: Array = POSES
	if sweep != "":
		cells = []
		for step in 6:
			var turn := -180.0 + float(step) * 60.0
			cells.append({"clip": "idle", "at": 0.5, "yaw": 0.55,
				"sweep": sweep, "turn": turn})
		print("  sweeping %s from -180 to 120 in 60 degree steps" % sweep)

	var missing := 0
	for i in cells.size():
		var pose: Dictionary = cells[i]
		var vp := SubViewport.new()
		vp.size = CELL
		vp.transparent_bg = false
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(vp)

		var world := Node3D.new()
		vp.add_child(world)
		var env := WorldEnvironment.new()
		var e := Environment.new()
		e.background_mode = Environment.BG_COLOR
		e.background_color = Color(0.06, 0.05, 0.08)
		e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		e.ambient_light_color = Color(0.55, 0.58, 0.72)
		e.ambient_light_energy = 0.6
		e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
		env.environment = e
		world.add_child(env)
		var key := DirectionalLight3D.new()
		key.rotation = Vector3(deg_to_rad(-48.0), deg_to_rad(38.0), 0.0)
		key.light_energy = 2.1
		world.add_child(key)

		var rig := SkyGearRig3D.new()
		world.add_child(rig)
		if not rig.setup("res://assets/models/captain/captain.tscn", 1.8, 1):
			print("captain rig failed to load")
			quit(1)
			return
		var turn := _v3(fit.rotation)
		if pose.has("sweep"):
			match str(pose.sweep):
				"x": turn.x = float(pose.turn)
				"y": turn.y = float(pose.turn)
				"z": turn.z = float(pose.turn)
		if not rig.hold(str(fit.path), str(fit.bone),
				_v3(fit.offset), turn, float(fit.length), 1):
			missing += 1
		rig.rotation.y = float(pose.yaw)

		## Park the clip at a fixed point rather than letting it play: the whole
		## value of a contact sheet is that two runs are comparable.
		var clip := str(pose.clip)
		if rig.has_clip(clip):
			rig.anim.play(clip)
			rig.anim.seek(rig.anim.get_animation(clip).length * float(pose.at), true)
			rig.anim.pause()
		else:
			clip += " (missing)"

		var cam := Camera3D.new()
		cam.fov = 34.0
		vp.add_child(cam)
		cam.position = Vector3(0.0, 1.05, 3.4)
		cam.look_at(Vector3(0.0, 0.95, 0.0))
		cam.current = true

		## Three frames: one to build, one to pose the skeleton, one to draw it.
		await process_frame
		await process_frame
		await process_frame
		var shot := vp.get_texture().get_image()
		shot.convert(Image.FORMAT_RGBA8)
		var cell := Vector2i((i % COLUMNS) * CELL.x, (i / COLUMNS) * CELL.y)
		sheet.blit_rect(shot, Rect2i(Vector2i.ZERO, CELL), cell)
		if pose.has("sweep"):
			print("  cell %d  %s = %.0f deg" % [i, str(pose.sweep), float(pose.turn)])
		else:
			print("  cell %d  %s @ %.0f%%" % [i, clip, float(pose.at) * 100.0])
		vp.queue_free()

	sheet.save_png("res://../.shots/weapon-fit.png")
	print("")
	if missing > 0:
		print("THE WEAPON DID NOT ATTACH in %d of %d cells — check the bone name"
			% [missing, cells.size()])
	print("wrote .shots/weapon-fit.png")
	quit(1 if missing > 0 else 0)


func _v3(a) -> Vector3:
	if a is Array and (a as Array).size() >= 3:
		return Vector3(float(a[0]), float(a[1]), float(a[2]))
	return Vector3.ZERO
