extends SceneTree
## Look at every model in the project, and put things on the ones with bones.
##
## `weapon_fit` was a WEAPON fitter: the captain, one sword, six fixed poses. The
## ask was broader and I built the narrow thing — "a way to view, edit, tweak and
## map 3D models we are using in-game". Two consequences followed. Every prop the
## generator produced went straight into the game unlooked-at, because there was
## nowhere to look at it. And the sword grip stayed wrong, because the fitter was
## rebuilt and then never used.
##
##   godot --path . --resolution 1600x900 --script tools/model_lab.gd
##   ... -- --model boiler        open on one
##
## TWO MODES, on TAB.
##
##   VIEW    orbit and inspect anything. Triangles, height in ground units,
##           material count, bones. Turntable on SPACE.
##   MOUNT   hang the current model off a bone of the captain and adjust it live.
##           Only offered when the model is small enough to be held.
##
##   PgUp / PgDn   previous / next model          TAB   swap mode
##   A / D         orbit          W / S   pitch          [ / ]  dolly
##   SPACE         turntable      G       ground grid + a 1m rule
##   ENTER         save the mount (MOUNT mode)     R      revert it
##   ESC           quit
##
## In MOUNT the arrow keys move it, PgUp/PgDn walk the blade axis, Q/E roll, and
## B cycles the bone. Saving writes `assets/models/weapons.json`, the file the
## game reads.
func _initialize() -> void: call_deferred("_run")

const RIG := "res://assets/models/captain/captain.tscn"
const NUDGE := 0.01
const TURN := 2.0
const GROW := 0.02
## Above this it is scenery, not something a person holds, so MOUNT is pointless.
const HOLDABLE_M := 2.6


class Keys extends Node:
	var lab
	func _ready() -> void:
		set_process_unhandled_key_input(true)
	func _unhandled_key_input(event: InputEvent) -> void:
		if lab != null:
			lab.key(event)


var _models: Array[String] = []
var _at := 0
var _mount := false
var _spin := false
var _grid := true
var _yaw := 0.6
var _pitch := -0.22
var _dolly := 3.2
var _world: Node3D
var _cam: Camera3D
var _label: Label
var _shown: Node3D
var _rig: SkyGearRig3D
var _bones: Array[String] = []
var _bone_at := 0
var _fit := {}
var _saved := {}
var _stats := ""


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
		if argv[i] == "--model" and i + 1 < argv.size():
			var want := str(argv[i + 1])
			if _models.has(want):
				_at = _models.find(want)

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
	## Two lamps and a rim, the same shape the deck uses, so a model judged here
	## is judged under something close to the light it will actually stand in.
	var key := DirectionalLight3D.new()
	key.rotation = Vector3(deg_to_rad(-48.0), deg_to_rad(38.0), 0.0)
	key.light_energy = 2.2
	_world.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation = Vector3(deg_to_rad(-20.0), deg_to_rad(-140.0), 0.0)
	fill.light_energy = 0.7
	fill.light_color = Color("#8fa6c9")
	_world.add_child(fill)

	_cam = Camera3D.new()
	_cam.fov = 32.0
	_world.add_child(_cam)
	_cam.current = true

	_label = Label.new()
	_label.position = Vector2(16, 12)
	_label.add_theme_font_size_override("font_size", 14)
	_label.add_theme_color_override("font_color", Color("#e6ddd0"))
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_label.add_theme_constant_override("outline_size", 5)
	root.add_child(_label)

	var keys := Keys.new()
	keys.lab = self
	root.add_child(keys)

	_load()
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
	_bone_at = 0

	var key := _models[_at]
	var path := _path_for(key)
	var packed := load(path) as PackedScene
	if packed == null:
		_stats = "failed to load " + path
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

	var tall_m: float = box.size.y
	var tall_ground: float = tall_m / SkyGearView3D.WORLD_SCALE
	_stats = "%d tris - %d surfaces - %d bones - %.0f ground units tall (%.2f m)" % [
		tris, mats, bone_count, tall_ground, tall_m]
	if tris > 20000:
		_stats += "\nHEAVY: over 20k triangles. Remesh before this ships."

	if _mount and _can_mount(tall_m):
		_build_mount()
	else:
		_mount = false
		_shown = packed.instantiate() as Node3D
		var holder := Node3D.new()
		holder.add_child(_shown)
		_world.add_child(holder)
		_shown = holder
		## Framed on its own bounding box, so a keg and a Colossus are both
		## legible without touching the dolly.
		_dolly = maxf(1.4, maxf(box.size.x, maxf(box.size.y, box.size.z)) * 2.1)
		holder.position = -box.get_center() + Vector3(0.0, box.size.y * 0.5, 0.0)


func _can_mount(tall_m: float) -> bool:
	return tall_m <= HOLDABLE_M and ResourceLoader.exists(RIG)


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
	_dolly = 3.0
	_apply_mount()


func _apply_mount() -> void:
	if _rig == null:
		return
	_fit["bone"] = _bones[_bone_at] if not _bones.is_empty() else str(_fit.bone)
	_rig.hold(_path_for(_models[_at]), str(_fit.bone), _v3(_fit.offset),
		_v3(_fit.rotation), float(_fit.length), 1)
	if _rig.has_clip("idle"):
		_rig.anim.play("idle")
		if not _spin:
			_rig.anim.seek(_rig.anim.get_animation("idle").length * 0.5, true)
			_rig.anim.pause()


func _tick() -> void:
	## The camera orbits a fixed point rather than the model, so switching models
	## does not throw the view away.
	var focus := Vector3(0.0, 0.9 if _mount else _dolly * 0.22, 0.0)
	_cam.position = focus + Vector3(
		sin(_yaw) * cos(_pitch), -sin(_pitch), cos(_yaw) * cos(_pitch)) * _dolly
	_cam.look_at(focus)
	_show()


func _show() -> void:
	var lines: Array[String] = []
	lines.append("%s        [%d of %d]        %s" % [_models[_at].to_upper(),
		_at + 1, _models.size(), "MOUNT" if _mount else "VIEW"])
	lines.append(_stats)
	lines.append("")
	if _mount:
		var o := _v3(_fit.offset)
		var r := _v3(_fit.rotation)
		lines.append("bone      %s" % str(_fit.bone))
		lines.append("offset    %+.3f  %+.3f  %+.3f" % [o.x, o.y, o.z])
		lines.append("rotation  %+.0f  %+.0f  %+.0f" % [r.x, r.y, r.z])
		lines.append("length    %.2f m        %s"
			% [float(_fit.length), "UNSAVED" if str(_fit) != str(_saved) else "saved"])
		lines.append("")
		lines.append("arrows move - PgUp/PgDn along it - Q/E roll - [ ] length")
		lines.append("B bone - TAB back to view - ENTER save - R revert")
	else:
		lines.append("PgUp/PgDn model - TAB mount it - A/D orbit - W/S pitch")
		lines.append("[ ] dolly - SPACE turntable - G grid - ESC quit")
	_label.text = "\n".join(lines)


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


func key(event: InputEvent) -> void:
	if event is not InputEventKey or not event.pressed or event.echo:
		return
	var k := (event as InputEventKey).keycode
	if k == KEY_ESCAPE:
		quit(0)
		return
	if k == KEY_TAB:
		_mount = not _mount
		_load()
		_tick()
		return

	if _mount:
		var o := _v3(_fit.offset)
		var r := _v3(_fit.rotation)
		match k:
			KEY_LEFT: o.x -= NUDGE
			KEY_RIGHT: o.x += NUDGE
			KEY_UP: o.y += NUDGE
			KEY_DOWN: o.y -= NUDGE
			KEY_PAGEUP: o.z += NUDGE
			KEY_PAGEDOWN: o.z -= NUDGE
			KEY_A: r.y -= TURN
			KEY_D: r.y += TURN
			KEY_W: r.x -= TURN
			KEY_S: r.x += TURN
			KEY_Q: r.z -= TURN
			KEY_E: r.z += TURN
			KEY_BRACKETLEFT: _fit.length = maxf(0.15, float(_fit.length) - GROW)
			KEY_BRACKETRIGHT: _fit.length = float(_fit.length) + GROW
			KEY_B:
				if not _bones.is_empty():
					_bone_at = (_bone_at + 1) % _bones.size()
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
		KEY_PAGEUP:
			_at = wrapi(_at - 1, 0, _models.size())
			_load()
		KEY_PAGEDOWN:
			_at = wrapi(_at + 1, 0, _models.size())
			_load()
		KEY_A: _yaw -= 0.12
		KEY_D: _yaw += 0.12
		KEY_W: _pitch = clampf(_pitch - 0.07, -1.3, 1.3)
		KEY_S: _pitch = clampf(_pitch + 0.07, -1.3, 1.3)
		KEY_BRACKETLEFT: _dolly = maxf(0.6, _dolly * 0.88)
		KEY_BRACKETRIGHT: _dolly = minf(80.0, _dolly * 1.14)
		KEY_SPACE: _spin = not _spin
		KEY_G: _grid = not _grid
		_:
			return
	_tick()


## Only the captain entry, and only the fields the mount owns. A tool that
## rewrites more than it was asked to is a tool nobody runs twice.
func _save() -> void:
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
	## And make sure the weapon it now names is one the table knows about.
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
