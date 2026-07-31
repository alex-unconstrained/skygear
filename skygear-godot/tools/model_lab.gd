extends SceneTree
## Look at every model in the project, and put things on the ones with bones.
##
## MOUSE FIRST. The first version was keyboard-only and leaned on PgUp/PgDn,
## which a laptop does not have — a tool nobody can drive is the same as no tool,
## and this one already failed once by being too narrow to use. Everything can be
## done by clicking and dragging; the keys are shortcuts, not the interface.
##
##   godot --path . --resolution 1600x900 --script tools/model_lab.gd
##   ... -- --model boiler        open on one
##
## VIEW
##   click a name on the left        load it
##   left-drag                       orbit
##   wheel                           closer / further
##   MOUNT button, or TAB            hang it off the captain
##
## MOUNT
##   left-drag                       slide it across and up
##   right-drag                      turn it
##   shift + left-drag               run it along its own length
##   wheel                           longer / shorter
##   click a bone on the right       move it to that bone
##   SAVE writes assets/models/weapons.json, the file the GAME reads
##
## Keys that still work: A/D orbit, W/S pitch, Q/E roll, [ ] size, SPACE
## turntable, R revert, ENTER save, ESC quit.
func _initialize() -> void: call_deferred("_run")

const RIG := "res://assets/models/captain/captain.tscn"
const NUDGE := 0.01
const TURN := 2.0
const GROW := 0.02
## Above this it is scenery, not something a person holds, so MOUNT is pointless.
const HOLDABLE_M := 2.6
## Metres per pixel of drag, and degrees per pixel. Slow enough to place a grip.
const DRAG_MOVE := 0.0016
const DRAG_TURN := 0.35
const ROW_H := 19.0
const LIST_W := 168.0


class Hands extends Node:
	var lab
	func _ready() -> void:
		set_process_unhandled_input(true)
	func _unhandled_input(event: InputEvent) -> void:
		if lab != null:
			lab.hand(event)


var _models: Array[String] = []
var _at := 0
var _mount := false
var _spin := false
var _yaw := 0.6
var _pitch := -0.22
var _dolly := 3.2
var _world: Node3D
var _cam: Camera3D
var _label: Label
var _list: VBoxContainer
var _bonelist: VBoxContainer
var _shown: Node3D
var _rig: SkyGearRig3D
var _bones: Array[String] = []
var _bone_at := 0
var _fit := {}
var _saved := {}
var _stats := ""
var _dragging := 0
var _shift := false
var _shot_to := ""
var _axes: VBoxContainer
var _axis_value: Dictionary = {}


func _run() -> void:
	for dir in DirAccess.get_directories_at("res://assets/models"):
		var glb := "res://assets/models/%s/%s.glb" % [dir, dir]
		var scene := "res://assets/models/%s/%s.tscn" % [dir, dir]
		if ResourceLoader.exists(scene) or ResourceLoader.exists(glb):
			_models.append(str(dir))
	_models.sort()
	if _models.is_empty():
		print("no models under assets/models")
		quit(1)
		return

	var argv := OS.get_cmdline_user_args()
	for i in argv.size():
		if argv[i] == "--model" and i + 1 < argv.size() and _models.has(str(argv[i + 1])):
			_at = _models.find(str(argv[i + 1]))
		if argv[i] == "--mount":
			_mount = true
		if argv[i] == "--shot" and i + 1 < argv.size():
			_shot_to = str(argv[i + 1])

	_world = Node3D.new()
	root.add_child(_world)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.07, 0.06, 0.09)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.55, 0.58, 0.72)
	e.ambient_light_energy = 0.7
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	_world.add_child(env)
	## Two lamps and a rim, the shape the deck uses, so a model judged here is
	## judged under something close to the light it will actually stand in.
	var key_light := DirectionalLight3D.new()
	key_light.rotation = Vector3(deg_to_rad(-48.0), deg_to_rad(38.0), 0.0)
	key_light.light_energy = 2.2
	_world.add_child(key_light)
	var fill := DirectionalLight3D.new()
	fill.rotation = Vector3(deg_to_rad(-20.0), deg_to_rad(-140.0), 0.0)
	fill.light_energy = 0.7
	fill.light_color = Color("#8fa6c9")
	_world.add_child(fill)

	_cam = Camera3D.new()
	_cam.fov = 32.0
	_world.add_child(_cam)
	_cam.current = true

	_build_ui()
	root.add_child(Hands.new())
	(root.get_child(root.get_child_count() - 1) as Hands).lab = self
	_load()
	_tick()
	## `--shot` renders one frame and leaves. Added so this tool could be VERIFIED
	## rather than compile-checked — the last one shipped green and unusable — and
	## kept because a reference render of any model is worth having on its own.
	if _shot_to != "":
		await process_frame
		await process_frame
		await process_frame
		root.get_texture().get_image().save_png(_shot_to)
		print("shot %s -> %s" % [_models[_at], _shot_to])
		quit(0)


func _build_ui() -> void:
	## A clickable list, because "press PgUp seventeen times to reach the vent" is
	## not a way to browse anything.
	var frame := PanelContainer.new()
	frame.position = Vector2(10, 10)
	frame.custom_minimum_size = Vector2(LIST_W, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.04, 0.07, 0.88)
	style.border_color = Color("#b0813f")
	style.set_border_width_all(1)
	style.set_content_margin_all(6)
	frame.add_theme_stylebox_override("panel", style)
	root.add_child(frame)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 1)
	frame.add_child(_list)
	for i in _models.size():
		var row := Button.new()
		row.text = _models[i]
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.custom_minimum_size = Vector2(LIST_W - 12.0, ROW_H)
		row.add_theme_font_size_override("font_size", 12)
		row.flat = true
		row.pressed.connect(_pick.bind(i))
		_list.add_child(row)

	## And the bones, for the same reason — cycling with a key through 33 of them
	## to find the left hand is not selection, it is a lottery.
	var bone_frame := PanelContainer.new()
	bone_frame.position = Vector2(1600.0 - LIST_W - 10.0, 10.0)
	bone_frame.custom_minimum_size = Vector2(LIST_W, 0)
	bone_frame.add_theme_stylebox_override("panel", style)
	root.add_child(bone_frame)
	_bonelist = VBoxContainer.new()
	_bonelist.add_theme_constant_override("separation", 1)
	bone_frame.add_child(_bonelist)

	_label = Label.new()
	_label.position = Vector2(LIST_W + 26.0, 12.0)
	_label.add_theme_font_size_override("font_size", 14)
	_label.add_theme_color_override("font_color", Color("#e6ddd0"))
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_label.add_theme_constant_override("outline_size", 5)
	root.add_child(_label)

	## PER-AXIS BUTTONS. Reported: "I had a really hard time trying to mount the
	## weapon." Dragging is ambiguous — a drag moves two axes at once and you
	## cannot tell which one moved, so a grip that is nearly right becomes a
	## guessing game. Six labelled rows of minus/plus, each showing its live
	## number.
	##
	## Named in WORDS, not X/Y/Z: nobody looking at a sword knows which way its
	## Z points, and that was precisely the difficulty.
	var axes := VBoxContainer.new()
	axes.position = Vector2(LIST_W + 26.0, 232.0)
	axes.add_theme_constant_override("separation", 3)
	root.add_child(axes)
	_axes = axes
	for spec in [["mx", "ACROSS    left / right"], ["my", "UP        raise / lower"],
			["mz", "ALONG     toward hilt / tip"],
			["rx", "PITCH     tip up / tip down"], ["ry", "YAW       swing L / R"],
			["rz", "ROLL      edge over"], ["len", "LENGTH    shorter / longer"]]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		for way in [-1.0, 1.0]:
			var b := Button.new()
			b.text = "-" if way < 0.0 else "+"
			b.custom_minimum_size = Vector2(30, 24)
			b.pressed.connect(_axis.bind(str(spec[0]), way))
			row.add_child(b)
		var name_label := Label.new()
		name_label.text = str(spec[1])
		name_label.custom_minimum_size = Vector2(250, 24)
		name_label.add_theme_font_size_override("font_size", 13)
		name_label.add_theme_color_override("font_color", Color("#b9afaa"))
		row.add_child(name_label)
		var value := Label.new()
		value.add_theme_font_size_override("font_size", 13)
		value.add_theme_color_override("font_color", Color("#e8c376"))
		_axis_value[str(spec[0])] = value
		row.add_child(value)
		axes.add_child(row)

	var buttons := HBoxContainer.new()
	buttons.position = Vector2(LIST_W + 26.0, 1600.0 * 0.0 + 470.0)
	root.add_child(buttons)
	for pair in [["MOUNT", "mount"], ["SAVE", "save"], ["REVERT", "revert"],
			["SPIN", "spin"]]:
		var b := Button.new()
		b.text = str(pair[0])
		b.custom_minimum_size = Vector2(96, 30)
		b.pressed.connect(_press.bind(str(pair[1])))
		buttons.add_child(b)


## One nudge on one axis. Every button and every key lands here, so exactly one
## place knows what a step is.
func _axis(which: String, way: float) -> void:
	if not _mount:
		return
	var o := _v3(_fit.offset)
	var r := _v3(_fit.rotation)
	match which:
		"mx": o.x += NUDGE * way
		"my": o.y += NUDGE * way
		"mz": o.z += NUDGE * way
		"rx": r.x += TURN * way
		"ry": r.y += TURN * way
		"rz": r.z += TURN * way
		"len": _fit.length = maxf(0.15, float(_fit.length) + GROW * way)
	_set_v("offset", o)
	_set_v("rotation", r)
	_apply_mount()
	_show()


func _press(what: String) -> void:
	match what:
		"mount":
			_mount = not _mount
			_load()
		"save": _save()
		"revert":
			_fit = _saved.duplicate(true)
			_apply_mount()
		"spin": _spin = not _spin
	_tick()


func _pick(which: int) -> void:
	_at = which
	_load()
	_tick()


func _pick_bone(which: int) -> void:
	_bone_at = which
	_apply_mount()
	_tick()


func _path_for(key: String) -> String:
	var scene := "res://assets/models/%s/%s.tscn" % [key, key]
	return scene if ResourceLoader.exists(scene) 		else "res://assets/models/%s/%s.glb" % [key, key]


func _load() -> void:
	if _shown != null:
		_shown.queue_free()
		_shown = null
	if _rig != null:
		_rig.queue_free()
		_rig = null
	_bones.clear()
	for old in _bonelist.get_children():
		old.queue_free()

	var key := _models[_at]
	var packed := load(_path_for(key)) as PackedScene
	if packed == null:
		_stats = "failed to load " + _path_for(key)
		return

	## MEASURED IN GROUND UNITS, not metres. A model is only right or wrong
	## relative to the deck, and the deck is 1680 x 2320 of them — a height in
	## metres is a number nobody here can act on.
	var probe := packed.instantiate()
	_world.add_child(probe)
	var tris := 0
	var mats := 0
	var box := AABB()
	var first := true
	for child in probe.find_children("*", "MeshInstance3D", true, false):
		var mi := child as MeshInstance3D
		if mi.mesh == null:
			continue
		mats += mi.mesh.get_surface_count()
		for surface in mi.mesh.get_surface_count():
			var arrays := mi.mesh.surface_get_arrays(surface)
			if arrays.size() > Mesh.ARRAY_INDEX and arrays[Mesh.ARRAY_INDEX] != null:
				tris += (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
			elif arrays.size() > Mesh.ARRAY_VERTEX:
				tris += (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
		var world_box: AABB = mi.global_transform * mi.get_aabb()
		box = world_box if first else box.merge(world_box)
		first = false
	var skeleton: Skeleton3D = null
	for child in probe.find_children("*", "Skeleton3D", true, false):
		skeleton = child as Skeleton3D
	var bone_count := skeleton.get_bone_count() if skeleton != null else 0
	probe.queue_free()

	_stats = "%d tris - %d surfaces - %d bones - %.0f ground units tall (%.2f m)" % [
		tris, mats, bone_count, box.size.y / SkyGearView3D.WORLD_SCALE, box.size.y]
	if tris > 20000:
		_stats += "\nHEAVY: over 20k triangles for something this size."

	for i in _models.size():
		var row := _list.get_child(i) as Button
		row.add_theme_color_override("font_color",
			Color("#37f0c8") if i == _at else Color("#b9afaa"))

	if _mount and box.size.y <= HOLDABLE_M and ResourceLoader.exists(RIG):
		_build_mount()
	else:
		_mount = false
		var holder := Node3D.new()
		holder.add_child(packed.instantiate())
		_world.add_child(holder)
		_shown = holder
		## Framed on its own bounding box, so a keg and a Colossus are both
		## legible without touching the wheel.
		_dolly = maxf(1.4, maxf(box.size.x, maxf(box.size.y, box.size.z)) * 2.1)
		holder.position = -box.get_center() + Vector3(0.0, box.size.y * 0.5, 0.0)


func _build_mount() -> void:
	_rig = SkyGearRig3D.new()
	_world.add_child(_rig)
	if not _rig.setup(RIG, 1.8, 1):
		_mount = false
		return
	for child in _rig.model.find_children("*", "Skeleton3D", true, false):
		var sk := child as Skeleton3D
		for i in sk.get_bone_count():
			_bones.append(sk.get_bone_name(i))
	if _fit.is_empty():
		_fit = SkyGearRig3D.weapon_fit("captain")
		if _fit.is_empty():
			_fit = {"bone": "mixamorig_RightHand", "length": 0.95,
				"offset": [0.0, 0.0, 0.0], "rotation": [-120.0, 0.0, 0.0]}
		_saved = _fit.duplicate(true)
	_bone_at = maxi(0, _bones.find(str(_fit.bone)))
	## Only the bones anything is ever mounted to. Thirty-three rows of spine is
	## a list nobody scrolls.
	for i in _bones.size():
		var name := _bones[i]
		if not ("Hand" in name or "Arm" in name or "Shoulder" in name
				or "Spine" in name or "Head" in name):
			continue
		var row := Button.new()
		row.text = name.replace("mixamorig_", "")
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.custom_minimum_size = Vector2(LIST_W - 12.0, ROW_H)
		row.add_theme_font_size_override("font_size", 12)
		row.flat = true
		row.pressed.connect(_pick_bone.bind(i))
		_bonelist.add_child(row)
	_dolly = 3.0
	_apply_mount()


func _apply_mount() -> void:
	if _rig == null:
		return
	if not _bones.is_empty():
		_fit["bone"] = _bones[_bone_at]
	_rig.hold(_path_for(_models[_at]), str(_fit.bone), _v3(_fit.offset),
		_v3(_fit.rotation), float(_fit.length), 1)
	if _rig.has_clip("idle"):
		_rig.anim.play("idle")
		if not _spin:
			_rig.anim.seek(_rig.anim.get_animation("idle").length * 0.5, true)
			_rig.anim.pause()


func _tick() -> void:
	var focus := Vector3(0.0, 0.9 if _mount else _dolly * 0.22, 0.0)
	_cam.position = focus + Vector3(
		sin(_yaw) * cos(_pitch), -sin(_pitch), cos(_yaw) * cos(_pitch)) * _dolly
	_cam.look_at(focus)
	_show()


func _show() -> void:
	var lines: Array[String] = []
	lines.append("%s        %s" % [_models[_at].to_upper(),
		"MOUNT" if _mount else "VIEW"])
	lines.append(_stats)
	lines.append("")
	if _mount:
		var o := _v3(_fit.offset)
		var r := _v3(_fit.rotation)
		lines.append("bone      %s" % str(_fit.bone).replace("mixamorig_", ""))
		lines.append("offset    %+.3f  %+.3f  %+.3f" % [o.x, o.y, o.z])
		lines.append("rotation  %+.0f  %+.0f  %+.0f" % [r.x, r.y, r.z])
		lines.append("length    %.2f m      %s"
			% [float(_fit.length), "UNSAVED" if str(_fit) != str(_saved) else "saved"])
		lines.append("")
		lines.append("drag or use the rows below - click a bone on the right")
	else:
		lines.append("click a model - drag to orbit - wheel to zoom")
		lines.append("MOUNT hangs it off the captain")
	_label.text = "\n".join(lines)
	if _axes != null:
		_axes.visible = _mount
	if _mount and not _axis_value.is_empty():
		var shown_o := _v3(_fit.offset)
		var shown_r := _v3(_fit.rotation)
		for pair in [["mx", "%+.3f" % shown_o.x], ["my", "%+.3f" % shown_o.y],
				["mz", "%+.3f" % shown_o.z], ["rx", "%+.0f" % shown_r.x],
				["ry", "%+.0f" % shown_r.y], ["rz", "%+.0f" % shown_r.z],
				["len", "%.2f m" % float(_fit.length)]]:
			(_axis_value[str(pair[0])] as Label).text = str(pair[1])


func _v3(a) -> Vector3:
	if a is Array and (a as Array).size() >= 3:
		return Vector3(float(a[0]), float(a[1]), float(a[2]))
	return Vector3.ZERO


func _set_v(field: String, v: Vector3) -> void:
	_fit[field] = [v.x, v.y, v.z]


func _process(delta: float) -> bool:
	if _spin:
		_yaw += delta * 0.6
		_tick()
	return false


func hand(event: InputEvent) -> void:
	if event is InputEventKey:
		_shift = (event as InputEventKey).shift_pressed
		_key(event as InputEventKey)
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		_shift = mb.shift_pressed
		## Never over the lists, or dragging to pick a model orbits the camera.
		if mb.position.x < LIST_W + 20.0 or mb.position.x > 1600.0 - LIST_W - 20.0:
			return
		match mb.button_index:
			MOUSE_BUTTON_LEFT: _dragging = 1 if mb.pressed else 0
			MOUSE_BUTTON_RIGHT: _dragging = 2 if mb.pressed else 0
			MOUSE_BUTTON_WHEEL_UP: _wheel(-1.0)
			MOUSE_BUTTON_WHEEL_DOWN: _wheel(1.0)
		return
	if event is InputEventMouseMotion and _dragging > 0:
		_drag((event as InputEventMouseMotion).relative)


func _wheel(notches: float) -> void:
	if _mount:
		_fit.length = maxf(0.15, float(_fit.length) - notches * GROW)
		_apply_mount()
	else:
		_dolly = clampf(_dolly * (1.12 if notches > 0.0 else 0.89), 0.6, 80.0)
	_tick()


func _drag(by: Vector2) -> void:
	if not _mount:
		_yaw -= by.x * 0.006
		_pitch = clampf(_pitch + by.y * 0.005, -1.3, 1.3)
		_tick()
		return
	var o := _v3(_fit.offset)
	var r := _v3(_fit.rotation)
	if _dragging == 2:
		r.y += by.x * DRAG_TURN
		r.x += by.y * DRAG_TURN
	elif _shift:
		## Along its own length, which is the axis you cannot see from the front
		## and the one a grip usually needs.
		o.z += by.y * DRAG_MOVE
	else:
		o.x += by.x * DRAG_MOVE
		o.y -= by.y * DRAG_MOVE
	_set_v("offset", o)
	_set_v("rotation", r)
	_apply_mount()
	_show()


func _key(event: InputEventKey) -> void:
	if not event.pressed or event.echo:
		return
	var k := event.keycode
	if k == KEY_ESCAPE:
		quit(0)
		return
	if k == KEY_TAB:
		_press("mount")
		return
	if _mount:
		var o := _v3(_fit.offset)
		var r := _v3(_fit.rotation)
		match k:
			KEY_LEFT: o.x -= NUDGE
			KEY_RIGHT: o.x += NUDGE
			KEY_UP: o.y += NUDGE
			KEY_DOWN: o.y -= NUDGE
			KEY_A: r.y -= TURN
			KEY_D: r.y += TURN
			KEY_W: r.x -= TURN
			KEY_S: r.x += TURN
			KEY_Q: r.z -= TURN
			KEY_E: r.z += TURN
			KEY_BRACKETLEFT: _fit.length = maxf(0.15, float(_fit.length) - GROW)
			KEY_BRACKETRIGHT: _fit.length = float(_fit.length) + GROW
			KEY_SPACE: _spin = not _spin
			KEY_R: _fit = _saved.duplicate(true)
			KEY_ENTER, KEY_KP_ENTER:
				_save()
				return
			_:
				return
		_set_v("offset", o)
		_set_v("rotation", r)
		_apply_mount()
		_show()
		return
	match k:
		## Z and X rather than PgUp/PgDn: a laptop has no page keys, which is how
		## the first version of this ended up undriveable.
		KEY_Z, KEY_COMMA:
			_at = wrapi(_at - 1, 0, _models.size())
			_load()
		KEY_X, KEY_PERIOD:
			_at = wrapi(_at + 1, 0, _models.size())
			_load()
		KEY_A: _yaw -= 0.12
		KEY_D: _yaw += 0.12
		KEY_W: _pitch = clampf(_pitch - 0.07, -1.3, 1.3)
		KEY_S: _pitch = clampf(_pitch + 0.07, -1.3, 1.3)
		KEY_BRACKETLEFT: _dolly = maxf(0.6, _dolly * 0.88)
		KEY_BRACKETRIGHT: _dolly = minf(80.0, _dolly * 1.14)
		KEY_SPACE: _spin = not _spin
		_:
			return
	_tick()


## Only the captain entry, and only the fields the mount owns. A tool that
## rewrites more than it was asked to is a tool nobody runs twice.
func _save() -> void:
	if not _mount:
		return
	var table = JSON.parse_string(
		FileAccess.get_file_as_string(SkyGearRig3D.WEAPON_TABLE))
	if table is not Dictionary:
		print("could not read the weapon table")
		return
	var captain: Dictionary = (table as Dictionary).get("captain", {})
	captain["weapon"] = _models[_at]
	captain["bone"] = str(_fit.bone)
	captain["length"] = float(_fit.length)
	captain["offset"] = _fit.offset
	captain["rotation"] = _fit.rotation
	(table as Dictionary)["captain"] = captain
	var weapons: Dictionary = (table as Dictionary).get("weapons", {})
	if not weapons.has(_models[_at]):
		weapons[_models[_at]] = {"path": _path_for(_models[_at])}
		(table as Dictionary)["weapons"] = weapons
	var f := FileAccess.open(SkyGearRig3D.WEAPON_TABLE, FileAccess.WRITE)
	if f == null:
		print("could not write the weapon table")
		return
	f.store_string(JSON.stringify(table, "  "))
	f.close()
	_saved = _fit.duplicate(true)
	print("saved %s on %s  offset %s  rotation %s  length %.2f"
		% [_models[_at], str(_fit.bone), str(_fit.offset), str(_fit.rotation),
			float(_fit.length)])
	_show()
