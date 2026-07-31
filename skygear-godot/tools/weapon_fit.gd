extends SceneTree
## Put the sword in her hand, live, with the arrow keys.
##
## The old version rendered a contact sheet and exited: change a number in
## `weapons.json`, run it, look, repeat. Twenty seconds a nudge, and a grip is a
## dozen nudges, so it was used three times and then the sword stayed slightly
## wrong. Which is what happened, and what got reported.
##
## Same six poses, but live. A grip is a physical thing you find by moving it,
## not a number you reason about from a still.
##
##   godot --path . --script tools/weapon_fit.gd
##   godot --path . --script tools/weapon_fit.gd -- --weapon sword_gearblade
##
##   arrows        move across and up
##   PgUp / PgDn   move along the blade
##   A / D  yaw       W / S  pitch       Q / E  roll
##   [ / ]         shorter / longer
##   TAB  next pose      SPACE  play or pause      R  reset      ENTER  save
##
## Saving writes `assets/models/weapons.json`, which is the file the GAME reads:
## what you set here is what ships.
func _initialize() -> void: call_deferred("_run")

const POSES := [
	{"clip": "idle", "at": 0.5, "yaw": 0.55, "name": "idle - the resting grip"},
	{"clip": "swing", "at": 0.42, "yaw": 0.9, "name": "swing - mid-arc, wrist over"},
	{"clip": "swing", "at": 0.62, "yaw": -0.5, "name": "swing - follow-through"},
	{"clip": "run", "at": 0.3, "yaw": 1.4, "name": "run - does it clip her leg"},
	{"clip": "walk", "at": 0.5, "yaw": 2.6, "name": "walk - from behind"},
	{"clip": "dash", "at": 0.5, "yaw": 0.2, "name": "dash - arm at full stretch"},
]

const NUDGE := 0.01        ## metres a tap moves it
const TURN := 2.0          ## degrees a tap turns it
const GROW := 0.02         ## metres a tap lengthens it


## A SceneTree cannot receive key input; only a Node in the tree can. This is
## that Node and nothing else, and it hands every key straight back.
class Keys extends Node:
	var owner_tool
	func _ready() -> void:
		set_process_unhandled_key_input(true)
	func _unhandled_key_input(event: InputEvent) -> void:
		if owner_tool != null:
			owner_tool.key(event)


var _fit: Dictionary = {}
var _saved: Dictionary = {}
var _rig: SkyGearRig3D
var _label: Label
var _pose := 0
var _playing := false
var _path := ""


func _run() -> void:
	var which := ""
	var argv := OS.get_cmdline_user_args()
	for i in argv.size():
		if argv[i] == "--weapon" and i + 1 < argv.size():
			which = argv[i + 1]

	_fit = SkyGearRig3D.weapon_fit("captain")
	if _fit.is_empty():
		print("no fit for 'captain' in assets/models/weapons.json")
		quit(1)
		return
	if which != "":
		var table = JSON.parse_string(
			FileAccess.get_file_as_string(SkyGearRig3D.WEAPON_TABLE))
		var weapons: Dictionary = (table as Dictionary).get("weapons", {})
		if not weapons.has(which):
			print("unknown weapon: " + which)
			quit(1)
			return
		_fit["path"] = str((weapons[which] as Dictionary).get("path", ""))
	_path = str(_fit.path)
	_saved = _fit.duplicate(true)

	var world := Node3D.new()
	root.add_child(world)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.07, 0.06, 0.09)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.55, 0.58, 0.72)
	e.ambient_light_energy = 0.7
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	world.add_child(env)
	var key_light := DirectionalLight3D.new()
	key_light.rotation = Vector3(deg_to_rad(-48.0), deg_to_rad(38.0), 0.0)
	key_light.light_energy = 2.2
	world.add_child(key_light)
	## A fill from the other side, or the far half of the blade is a silhouette
	## and you cannot judge the thing you came here to judge.
	var fill := DirectionalLight3D.new()
	fill.rotation = Vector3(deg_to_rad(-20.0), deg_to_rad(-140.0), 0.0)
	fill.light_energy = 0.7
	fill.light_color = Color("#8fa6c9")
	world.add_child(fill)

	_rig = SkyGearRig3D.new()
	world.add_child(_rig)
	if not _rig.setup("res://assets/models/captain/captain.tscn", 1.8, 1):
		print("captain rig failed to load")
		quit(1)
		return

	var cam := Camera3D.new()
	world.add_child(cam)
	cam.fov = 30.0
	cam.position = Vector3(0.0, 1.15, 2.9)
	cam.look_at(Vector3(0.0, 1.02, 0.0))
	cam.current = true

	_label = Label.new()
	_label.position = Vector2(16, 12)
	_label.add_theme_font_size_override("font_size", 15)
	_label.add_theme_color_override("font_color", Color("#e6ddd0"))
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_label.add_theme_constant_override("outline_size", 5)
	root.add_child(_label)

	var keys := Keys.new()
	keys.owner_tool = self
	root.add_child(keys)

	_apply()
	_show()


func _apply() -> void:
	_rig.hold(_path, str(_fit.bone), _v3(_fit.offset), _v3(_fit.rotation),
		float(_fit.length), 1)
	var pose: Dictionary = POSES[_pose]
	var clip := str(pose.clip)
	_rig.rotation.y = float(pose.yaw)
	if _rig.has_clip(clip):
		_rig.anim.play(clip)
		if _playing:
			_rig.anim.speed_scale = 1.0
		else:
			_rig.anim.seek(_rig.anim.get_animation(clip).length * float(pose.at), true)
			_rig.anim.pause()


func _show() -> void:
	var o := _v3(_fit.offset)
	var r := _v3(_fit.rotation)
	var dirty: bool = str(_fit) != str(_saved)
	var lines: Array[String] = []
	lines.append("%s     %s" % [_path.get_file(), "UNSAVED" if dirty else "saved"])
	lines.append(str(POSES[_pose].name))
	lines.append("")
	lines.append("offset    %+.3f  %+.3f  %+.3f" % [o.x, o.y, o.z])
	lines.append("rotation  %+.0f  %+.0f  %+.0f" % [r.x, r.y, r.z])
	lines.append("length    %.2f m        %s"
		% [float(_fit.length), "playing" if _playing else "paused"])
	lines.append("")
	lines.append("arrows move - PgUp/PgDn along the blade")
	lines.append("A/D yaw - W/S pitch - Q/E roll - [ ] length")
	lines.append("TAB pose - SPACE play - R reset - ENTER save")
	_label.text = "\n".join(lines)


func _v3(a) -> Vector3:
	if a is Array and (a as Array).size() >= 3:
		return Vector3(float(a[0]), float(a[1]), float(a[2]))
	return Vector3.ZERO


func _set_v(field: String, v: Vector3) -> void:
	_fit[field] = [v.x, v.y, v.z]


func key(event: InputEvent) -> void:
	if event is not InputEventKey or not event.pressed or event.echo:
		return
	var k := (event as InputEventKey).keycode
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
		KEY_TAB: _pose = (_pose + 1) % POSES.size()
		KEY_SPACE: _playing = not _playing
		KEY_R: _fit = _saved.duplicate(true)
		KEY_ENTER, KEY_KP_ENTER: _save()
		KEY_ESCAPE:
			quit(0)
			return
		_:
			return
	_set_v("offset", o)
	_set_v("rotation", r)
	_apply()
	_show()


## Writes the file the GAME reads. Only the captain entry is touched: the weapon
## table around it is left exactly as it was, because a tool that rewrites more
## than it was asked to is a tool nobody runs twice.
func _save() -> void:
	var table = JSON.parse_string(
		FileAccess.get_file_as_string(SkyGearRig3D.WEAPON_TABLE))
	if table is not Dictionary:
		print("could not read the weapon table")
		return
	var captain: Dictionary = (table as Dictionary).get("captain", {})
	captain["bone"] = str(_fit.bone)
	captain["length"] = float(_fit.length)
	captain["offset"] = _fit.offset
	captain["rotation"] = _fit.rotation
	(table as Dictionary)["captain"] = captain
	var f := FileAccess.open(SkyGearRig3D.WEAPON_TABLE, FileAccess.WRITE)
	if f == null:
		print("could not write the weapon table")
		return
	f.store_string(JSON.stringify(table, "  "))
	f.close()
	_saved = _fit.duplicate(true)
	print("saved  offset %s  rotation %s  length %.2f"
		% [str(_fit.offset), str(_fit.rotation), float(_fit.length)])
	_show()
