extends SceneTree
## Look at every model in the project, RUN it, hang things off it, and write the
## result back into the game.
##
## MOUSE FIRST. The first version was keyboard-only and leaned on PgUp/PgDn,
## which a laptop does not have — a tool nobody can drive is the same as no tool,
## and this one already failed once by being too narrow to use. Every single
## thing below can be done by clicking, dragging or scrolling; the keys are
## shortcuts on top, never the only way in.
##
##   godot --path . --resolution 1600x900 --script tools/model_lab.gd
##   ... -- --model boiler                    open on one
##   ... -- --mount                           open holding it
##   ... -- --fx                              open on the effects loop
##   ... -- --clip swing2 --at 0.62           pose an animation frame
##   ... -- --shot out.png                    render that frame and exit
##
## THREE MODES, three buttons, top middle.
##
## VIEW    click a name on the left. Drag to orbit, wheel to dolly. Triangles,
##         surfaces, bones and height IN GROUND UNITS in the header.
## MOUNT   hangs the model off the captain's skeleton. Drag it, nudge it one
##         labelled axis at a time, click a different bone — then SAVE, which
##         writes `assets/models/weapons.json`, the file the GAME reads.
## FX      spawns the real renderer with the real deck and fires one effect on a
##         loop so it can be judged on its own instead of mid-wave.
##
## THE TIMELINE runs along the bottom in all three modes. Click a clip, PLAY,
## drag the bar to scrub, STEP a frame at a time. This is the point of the whole
## tool: a grip judged at a static pose is a grip judged at the one frame that
## was never the problem. Mount the sword, play `swing2`, and watch whether it
## stays in her hand THROUGH the swing.
##
## THE LOOK panel, bottom left, is everything that changes how you see it rather
## than what it is: wireframe, clay, flat lighting, a grid in ground units, the
## skeleton drawn over the mesh, the light swung around, the backdrop cycled.
## Judging a remesh needs the wireframe; judging a silhouette needs the clay;
## finding out where `RightHand` actually IS needs the bone axes.
##
## Keys, all of them optional: SPACE play/pause, `,` `.` step one frame,
## Z / X previous / next model, T turntable, TAB next mode, R revert, ENTER
## save, ESC quit. In MOUNT the arrows slide the weapon and A/D/W/S/Q/E turn it.
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
## One frame at the rate the game runs. Stepping by a real frame rather than by
## a round fraction means the frame you stop on is a frame the player will see.
const FRAME := 1.0 / 60.0
## FRAMING. `FIT` is how many model-heights back the camera sits; `RIGHT` slides
## it sideways so the subject clears the dial stack, and `LIFT` raises it so the
## feet clear the timeline. All three are fractions of the dolly, so a keg and a
## Colossus land in the same place on screen.
const FIT := 2.45
const RIGHT := 0.11
const LIFT := 0.07

const VIEW := 0
const MOUNT := 1
const FX := 2
const MODE_NAME := ["VIEW", "MOUNT", "FX"]

## Backdrops to judge against. A model that reads on near-black and vanishes on
## grey has a value problem, and you only find that by flipping between them.
const BACKDROPS := [
	{"name": "night", "color": Color(0.07, 0.06, 0.09)},
	{"name": "deck", "color": Color(0.16, 0.13, 0.19)},
	{"name": "grey", "color": Color(0.38, 0.38, 0.40)},
	{"name": "white", "color": Color(0.86, 0.86, 0.88)},
	{"name": "black", "color": Color(0.0, 0.0, 0.0)},
]

## The effect kinds `view3d.gd::_sync_effects` knows how to draw, in the order a
## person would want to flip through them. Same strings the simulation emits, so
## what you see here is what the fight draws — not a second implementation of it.
const FX_KINDS := ["arc", "cone", "circle", "burst", "line", "beam"]
const FX_ELEMENTS := ["EMBER", "FROST", "ARC", "STEAM"]

## Playback rates worth one click. A tenth speed is what you use to find the
## frame the blade leaves her hand; the label is spelled out because GDScript's
## format operator has no `%g` and a rate printed as "0.100000x" reads as noise.
const SPEEDS := [[0.1, "0.1x"], [0.25, "0.25x"], [0.5, "0.5x"], [1.0, "1x"],
	[2.0, "2x"]]


class Hands extends Node:
	var lab
	func _ready() -> void:
		set_process_unhandled_input(true)
	func _unhandled_input(event: InputEvent) -> void:
		if lab != null:
			lab.hand(event)


var _models: Array[String] = []
var _at := 0
var _mode := VIEW
var _spin := false
var _yaw := 0.6
var _pitch := -0.22
var _dolly := 3.2
var _world: Node3D
var _cam: Camera3D
var _env: Environment
var _key_light: DirectionalLight3D
var _fill_light: DirectionalLight3D
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
var _note := ""
var _dragging := 0
var _shift := false
var _alt := false
var _shot_to := ""
var _rows: VBoxContainer
var _row_value: Dictionary = {}
var _row_widget: Dictionary = {}

## The weapon's rotation as a live BASIS, not three Euler fields. The whole point
## of SG-39's part 1: a nudge composes an axis rotation onto this basis about the
## weapon's OWN local axis, so the three rows stay visibly distinct even at pitch
## -90 where the stored Euler yaw and roll collapse onto the same axis. `_fit`
## keeps an Euler `rotation` array in sync with it (extracted through `LabMath`)
## so the FILE format is unchanged and every existing weapons.json fit loads to
## the same pose. See tools/lab_math.gd.
var _rot_basis: Basis = Basis.IDENTITY

## The one typed-input widget, reused across every numeric row — MOUNT's seven,
## the four LIGHT rows and the nine FX dials. Repositioned over whichever value
## was clicked rather than seven boxes hand-rolled into the layout.
var _editor: LineEdit
var _editing_key := ""

## Which local axis to light up on the blade (0 = X/pitch, 1 = Y/yaw, 2 = Z/roll)
## and until when. Set while a rotation row is hovered, and flashed briefly after
## a rotation nudge, so you can SEE which line the row will spin about right now.
var _hover_axis := -1
var _flash_axis := -1
var _flash_until := 0.0
var _clock := 0.0

## Single-level undo (Ctrl+Z), enough to take back the last nudge or typed entry.
var _undo_state: Dictionary = {}
var _has_undo := false

## Everything in the LOOK panel that is on or off.
var _on := {"wire": false, "clay": false, "flat": false, "grid": true,
	"skel": false, "axis": true, "sway": false}
var _toggle_btn: Dictionary = {}
var _bg_at := 0
var _light_yaw := 38.0
var _light_pitch := -48.0
var _key_energy := 2.2
var _ambient := 0.7
var _focus_y := 0.7
var _grid: MeshInstance3D
var _look_frame: PanelContainer
var _bone_frame: PanelContainer
var _overlay: MeshInstance3D
var _clay_mat: StandardMaterial3D

## Animation. `_anim` is whichever AnimationPlayer belongs to what is on screen —
## the mounted rig's, or a static model that happens to carry one.
var _anim: AnimationPlayer
var _clips: Array[String] = []
var _clip_name := ""
var _playing := false
var _loop := true
var _speed := 1.0
var _clip_chips: HFlowContainer
var _scrub: HSlider
var _scrub_label: Label
var _timeline: PanelContainer
var _transport: Dictionary = {}
var _scrubbing := false

## The effects loop. `_fx_world` is a REAL `main3d.tscn` — the real renderer, the
## real deck, the real camera — because the alternative is a second copy of the
## effect code in here, and two functions disagreeing about one number is how
## three visual bugs got made.
var _fx_world: Node3D
var _fx_view: SkyGearView3D
var _fx_game: SkyGearGame
var _fx_env: Environment
var _fx_kind := 0
var _fx_element := 0
var _fx_clock := 0.0
var _fx_list: VBoxContainer
var _fx_dial := {"radius": 190.0, "life": 0.22, "arc": 1.7, "damage": 40.0,
	"period": 1.1, "slowmo": 1.0, "glow": 1.0, "spark": 26.0, "plife": 1.0}

var _w := 1600.0
var _h := 900.0
## EVERY control goes in here, not straight on the root. FX mode brings the real
## game scene in with it, and the game owns a `Camera2D` for the hidden 2D
## simulation — a `Camera2D` transforms the whole default canvas layer, so the
## first version of the effects loop dragged the entire tool interface eight
## hundred pixels down the screen and shrank it. A layer of its own is immune.
var _ui: CanvasLayer


func _run() -> void:
	## Before anything is loaded. Godot builds the wireframe index buffers at mesh
	## upload time, so asking for them after the models are in memory gets you a
	## toggle that does nothing.
	RenderingServer.set_debug_generate_wireframes(true)

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

	var want_clip := ""
	var want_at := -1.0
	var argv := OS.get_cmdline_user_args()
	for i in argv.size():
		if argv[i] == "--model" and i + 1 < argv.size() and _models.has(str(argv[i + 1])):
			_at = _models.find(str(argv[i + 1]))
		if argv[i] == "--mount":
			_mode = MOUNT
		if argv[i] == "--fx":
			_mode = FX
		if argv[i] == "--clip" and i + 1 < argv.size():
			want_clip = str(argv[i + 1])
		if argv[i] == "--at" and i + 1 < argv.size():
			want_at = clampf(float(argv[i + 1]), 0.0, 1.0)
		if argv[i] == "--shot" and i + 1 < argv.size():
			_shot_to = str(argv[i + 1])
		## `--look wire,clay,skel` so a reference render can be made of the same
		## model under the same switches twice, months apart. A toggle that can
		## only be reached by clicking cannot appear in a before-and-after.
		if argv[i] == "--look" and i + 1 < argv.size():
			for name in str(argv[i + 1]).split(","):
				if _on.has(name):
					_on[name] = true
		if argv[i] == "--bg" and i + 1 < argv.size():
			for b in BACKDROPS.size():
				if str(BACKDROPS[b].name) == str(argv[i + 1]):
					_bg_at = b

	var seen := root.get_visible_rect().size
	if seen.x > 200.0 and seen.y > 200.0:
		_w = seen.x
		_h = seen.y

	_world = Node3D.new()
	root.add_child(_world)
	var env := WorldEnvironment.new()
	_env = Environment.new()
	_env.background_mode = Environment.BG_COLOR
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.ambient_light_color = Color(0.55, 0.58, 0.72)
	_env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = _env
	_world.add_child(env)
	## Two lamps and a rim, the shape the deck uses, so a model judged here is
	## judged under something close to the light it will actually stand in. Both
	## are swung from the LOOK panel, because a form you cannot relight is a form
	## you are judging at one angle and shipping at another.
	_key_light = DirectionalLight3D.new()
	_world.add_child(_key_light)
	_fill_light = DirectionalLight3D.new()
	_fill_light.rotation = Vector3(deg_to_rad(-20.0), deg_to_rad(-140.0), 0.0)
	_fill_light.light_energy = 0.7
	_fill_light.light_color = Color("#8fa6c9")
	_world.add_child(_fill_light)

	_cam = Camera3D.new()
	_cam.fov = 32.0
	_world.add_child(_cam)
	_cam.current = true

	_ui = CanvasLayer.new()
	_ui.layer = 20
	root.add_child(_ui)

	_build_grid()
	_build_overlay()
	_build_ui()
	var hands := Hands.new()
	root.add_child(hands)
	hands.lab = self

	_apply_look()
	if _mode == FX:
		_enter_fx()
	else:
		_load()
	_build_rows()
	## `--clip` and `--at` exist so a grip can be checked at ONE named frame from a
	## script — "the captain at 62% of swing2, holding the cutlass" is a thing you
	## want a picture of before and after a change, not a thing you want to find by
	## hand twice.
	if want_clip != "" and _clips.has(want_clip):
		_clip_name = want_clip
		_apply_clip(false)
		if want_at >= 0.0:
			_set_playing(false)
			_seek_fraction(want_at)
		else:
			_set_playing(true)
	_tick()

	## `--shot` renders one frame and leaves. Added so this tool could be VERIFIED
	## rather than compile-checked — the last one shipped green and unusable — and
	## kept because a reference render of any model, at any frame of any clip, is
	## worth having on its own.
	if _shot_to != "":
		for _i in 6:
			await process_frame
		## An effect lives a fifth of a second. Six frames of a scene still loading
		## is long enough for one fired on frame zero to be over, so the shot fires
		## its own and photographs it two frames in — near the peak, which is the
		## frame anyone judging it would have paused on.
		if _mode == FX:
			_fx_fire()
			await process_frame
			await process_frame
		root.get_texture().get_image().save_png(_shot_to)
		print("shot %s (%s) -> %s" % [_models[_at], MODE_NAME[_mode], _shot_to])
		quit(0)


# ---------------------------------------------------------------- interface --

func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.04, 0.07, 0.90)
	style.border_color = Color("#b0813f")
	style.set_border_width_all(1)
	style.set_content_margin_all(6)
	return style


func _panel(at: Vector2, size: Vector2) -> PanelContainer:
	var frame := PanelContainer.new()
	frame.position = at
	frame.custom_minimum_size = size
	frame.size = size
	frame.add_theme_stylebox_override("panel", _panel_style())
	_ui.add_child(frame)
	return frame


func _heading(parent: Node, text: String) -> Label:
	var head := Label.new()
	head.text = text
	head.add_theme_font_size_override("font_size", 11)
	head.add_theme_color_override("font_color", Color("#8b7f76"))
	parent.add_child(head)
	return head


func _chip(text: String, width: float, height: float, font: int = 12) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(width, height)
	b.add_theme_font_size_override("font_size", font)
	return b


func _build_ui() -> void:
	## A clickable list, because "press PgUp seventeen times to reach the vent" is
	## not a way to browse anything. Scrolled rather than grown, so adding models
	## never pushes the LOOK panel off the bottom of the screen.
	var frame := _panel(Vector2(10, 10), Vector2(LIST_W, 262))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	frame.add_child(scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 1)
	scroll.add_child(_list)
	for i in _models.size():
		var row := _chip(_models[i], LIST_W - 24.0, ROW_H)
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.flat = true
		row.pressed.connect(_pick.bind(i))
		_list.add_child(row)

	_build_look()

	## And the bones, for the same reason — cycling with a key through 33 of them
	## to find the left hand is not selection, it is a lottery.
	_bone_frame = _panel(Vector2(_w - LIST_W - 10.0, 10.0), Vector2(LIST_W, 262))
	var bone_frame := _bone_frame
	var bone_scroll := ScrollContainer.new()
	bone_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	bone_frame.add_child(bone_scroll)
	_bonelist = VBoxContainer.new()
	_bonelist.add_theme_constant_override("separation", 1)
	bone_scroll.add_child(_bonelist)

	_build_fx_panel()

	_label = Label.new()
	_label.position = Vector2(LIST_W + 26.0, 10.0)
	_label.add_theme_font_size_override("font_size", 14)
	_label.add_theme_color_override("font_color", Color("#e6ddd0"))
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_label.add_theme_constant_override("outline_size", 5)
	_ui.add_child(_label)

	## The three modes and the three verbs, one row, always in the same place.
	var buttons := HBoxContainer.new()
	buttons.position = Vector2(LIST_W + 26.0, 116.0)
	buttons.add_theme_constant_override("separation", 4)
	_ui.add_child(buttons)
	for pair in [["VIEW", "view"], ["MOUNT", "mount"], ["FX", "fx"]]:
		var b := _chip(str(pair[0]), 74, 28)
		b.pressed.connect(_press.bind(str(pair[1])))
		buttons.add_child(b)
		_toggle_btn[str(pair[1])] = b
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(18, 0)
	buttons.add_child(gap)
	for pair in [["SAVE", "save"], ["REVERT", "revert"], ["TURNTABLE", "spin"]]:
		var b := _chip(str(pair[0]), 92, 28)
		b.pressed.connect(_press.bind(str(pair[1])))
		buttons.add_child(b)
		_toggle_btn[str(pair[1])] = b

	## THE DIAL STACK. Reported: "I had a really hard time trying to mount the
	## weapon." Dragging is ambiguous — a drag moves two axes at once and you
	## cannot tell which one moved, so a grip that is nearly right becomes a
	## guessing game. Labelled rows of minus/plus, each showing its live number.
	##
	## Named in WORDS, not X/Y/Z: nobody looking at a sword knows which way its
	## Z points, and that was precisely the difficulty. The same rack carries the
	## effect dials in FX mode, so there is one place to look for a number.
	_rows = VBoxContainer.new()
	_rows.position = Vector2(LIST_W + 26.0, 156.0)
	_rows.add_theme_constant_override("separation", 2)
	_ui.add_child(_rows)

	_build_timeline()

	## The one typed-input box, added last so it draws above every row it lands on.
	## Hidden until a value is clicked; ENTER applies, ESC or a click away cancels,
	## a malformed entry is refused and the old value kept (see `_commit_edit`).
	_editor = LineEdit.new()
	_editor.visible = false
	_editor.select_all_on_focus = true
	_editor.add_theme_font_size_override("font_size", 13)
	_editor.text_submitted.connect(_editor_submit)
	_editor.focus_exited.connect(_editor_focus_lost)
	_editor.gui_input.connect(_editor_gui)
	_ui.add_child(_editor)


## A row's live value, as a small flat button. Clicking it opens the typed-input
## box; the wheel over it nudges the row. One helper feeds every numeric row so
## there is exactly one typed-input path, not seven.
func _make_value(key: String, width: float, font: int) -> Button:
	var b := Button.new()
	b.flat = true
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(width, 22.0 if font >= 13 else 20.0)
	b.add_theme_font_size_override("font_size", font)
	b.add_theme_color_override("font_color", Color("#e8c376"))
	b.pressed.connect(_begin_edit.bind(key))
	b.gui_input.connect(_row_scroll.bind(key))
	_row_value[key] = b
	return b


## Rebuilt when the mode changes rather than hidden, because a stale row showing
## a number from the other mode is worse than no row.
func _build_rows() -> void:
	for old in _rows.get_children():
		_rows.remove_child(old)
		old.queue_free()
	_row_value.clear()
	var specs: Array = []
	if _mode == MOUNT:
		specs = [["mx", "ACROSS   left / right"], ["my", "UP       raise / lower"],
			["mz", "ALONG    toward hilt / tip"],
			["rx", "PITCH    tip up / tip down"], ["ry", "YAW      swing L / R"],
			["rz", "ROLL     edge over"], ["len", "LENGTH   shorter / longer"]]
	elif _mode == FX:
		specs = [["fxr", "RADIUS   how far it reaches"],
			["fxa", "ARC      how wide the fan"],
			["fxl", "LIFE     seconds on screen"],
			["fxd", "DAMAGE   drives sparks + flash"],
			["fxp", "EVERY    seconds between casts"],
			["fxs", "SLOW-MO  time scale"],
			["fxg", "GLOW     bloom strength"],
			["fxq", "SPARK    particle size"],
			["fxt", "SPARK    particle lifetime"]]
	## Which local axis (if any) each MOUNT rotation row spins about, so hovering
	## the row can light the matching coloured line on the blade.
	var rot_axis := {"rx": 0, "ry": 1, "rz": 2}
	for spec in specs:
		var key := str(spec[0])
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		for way in [-1.0, 1.0]:
			var b := _chip("-" if way < 0.0 else "+", 30, 22, 13)
			b.pressed.connect(_dial.bind(key, way))
			row.add_child(b)
		var name_label := Label.new()
		name_label.text = str(spec[1])
		name_label.custom_minimum_size = Vector2(232, 22)
		name_label.add_theme_font_size_override("font_size", 13)
		name_label.add_theme_color_override("font_color", Color("#b9afaa"))
		## Hovering a rotation row lights its axis on the blade (priority 3a).
		if rot_axis.has(key):
			var axis: int = rot_axis[key]
			name_label.mouse_entered.connect(func() -> void: _hover_axis = axis)
			name_label.mouse_exited.connect(func() -> void:
				if _hover_axis == axis:
					_hover_axis = -1)
		row.add_child(name_label)
		row.add_child(_make_value(key, 78, 13))
		_row_widget[key] = row
		_rows.add_child(row)


## Everything that changes how you SEE it rather than what it is. Left column,
## under the models, so the two lists you scan are on the same side.
func _build_look() -> void:
	var frame := _panel(Vector2(10, 282), Vector2(LIST_W, 0))
	_look_frame = frame
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	frame.add_child(box)
	_heading(box, "LOOK")
	for pair in [["wire", "WIREFRAME"], ["clay", "CLAY"], ["flat", "FLAT LIGHT"],
			["grid", "GRID + RULER"], ["skel", "SKELETON"], ["axis", "BONE AXES"]]:
		var b := _chip(str(pair[1]), LIST_W - 24.0, 22, 11)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(_flip.bind(str(pair[0])))
		box.add_child(b)
		_toggle_btn[str(pair[0])] = b
	var bg := _chip("BACKDROP  night", LIST_W - 24.0, 22, 11)
	bg.alignment = HORIZONTAL_ALIGNMENT_LEFT
	bg.pressed.connect(_press.bind("backdrop"))
	box.add_child(bg)
	_toggle_btn["backdrop"] = bg
	_heading(box, "LIGHT")
	for pair in [["lyaw", "SWING"], ["lpitch", "HEIGHT"], ["lkey", "KEY"],
			["lamb", "AMBIENT"]]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 3)
		for way in [-1.0, 1.0]:
			var b := _chip("-" if way < 0.0 else "+", 24, 20, 11)
			b.pressed.connect(_dial.bind(str(pair[0]), way))
			row.add_child(b)
		var name_label := Label.new()
		name_label.text = str(pair[1])
		name_label.custom_minimum_size = Vector2(56, 20)
		name_label.add_theme_font_size_override("font_size", 11)
		name_label.add_theme_color_override("font_color", Color("#b9afaa"))
		row.add_child(name_label)
		row.add_child(_make_value(str(pair[0]), 44, 11))
		box.add_child(row)


## The effect picker. Clicking any of these enters FX mode, because a list you
## have to arm something else before using is a list people bounce off.
func _build_fx_panel() -> void:
	var frame := _panel(Vector2(_w - LIST_W - 10.0, 282.0), Vector2(LIST_W, 0))
	_fx_list = VBoxContainer.new()
	_fx_list.add_theme_constant_override("separation", 2)
	frame.add_child(_fx_list)
	_heading(_fx_list, "EFFECT — the real one")
	for i in FX_KINDS.size():
		var b := _chip(FX_KINDS[i], LIST_W - 24.0, 21, 11)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(_pick_fx_kind.bind(i))
		_fx_list.add_child(b)
		_toggle_btn["fxk%d" % i] = b
	_heading(_fx_list, "ELEMENT")
	for i in FX_ELEMENTS.size():
		var b := _chip(FX_ELEMENTS[i], LIST_W - 24.0, 21, 11)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(_pick_fx_element.bind(i))
		_fx_list.add_child(b)
		_toggle_btn["fxe%d" % i] = b
	var sway := _chip("SHIP SWAY", LIST_W - 24.0, 21, 11)
	sway.alignment = HORIZONTAL_ALIGNMENT_LEFT
	sway.pressed.connect(_flip.bind("sway"))
	_fx_list.add_child(sway)
	_toggle_btn["sway"] = sway
	var once := _chip("FIRE ONCE NOW", LIST_W - 24.0, 21, 11)
	once.pressed.connect(_press.bind("fire"))
	_fx_list.add_child(once)


## THE TIMELINE. The single biggest thing this tool was missing: a weapon that
## sits perfectly in a rest pose can leave her hand entirely two thirds of the
## way through a swing, and a still frame cannot show that. Bottom of the screen
## because that is where a timeline lives in every tool anyone has already used.
func _build_timeline() -> void:
	_timeline = _panel(Vector2(LIST_W + 26.0, _h - 152.0),
		Vector2(_w - LIST_W * 2.0 - 56.0, 142.0))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	_timeline.add_child(box)
	_heading(box, "ANIMATION")

	_clip_chips = HFlowContainer.new()
	_clip_chips.add_theme_constant_override("h_separation", 3)
	_clip_chips.add_theme_constant_override("v_separation", 3)
	box.add_child(_clip_chips)

	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 4)
	box.add_child(bar)
	for pair in [["|< START", "rewind"], ["< STEP", "back"], ["PLAY", "play"],
			["STEP >", "forward"], ["LOOP", "loop"]]:
		var b := _chip(str(pair[0]), 84, 26, 12)
		b.pressed.connect(_press.bind(str(pair[1])))
		bar.add_child(b)
		_transport[str(pair[1])] = b
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(16, 0)
	bar.add_child(sp)
	var speed_label := Label.new()
	speed_label.text = "SPEED"
	speed_label.add_theme_font_size_override("font_size", 12)
	speed_label.add_theme_color_override("font_color", Color("#b9afaa"))
	bar.add_child(speed_label)
	## Presets as well as minus/plus, because "a quarter speed" is a thing you
	## want in one click when you are hunting the frame the blade slips.
	for preset in SPEEDS:
		var b := _chip(str(preset[1]), 46, 26, 12)
		b.pressed.connect(_set_speed.bind(float(preset[0])))
		bar.add_child(b)
		_transport["s" + str(preset[1])] = b

	var scrub_row := HBoxContainer.new()
	scrub_row.add_theme_constant_override("separation", 8)
	box.add_child(scrub_row)
	_scrub = HSlider.new()
	_scrub.min_value = 0.0
	_scrub.max_value = 1.0
	_scrub.step = 0.0005
	_scrub.custom_minimum_size = Vector2(_w - LIST_W * 2.0 - 300.0, 22)
	_scrub.value_changed.connect(_on_scrub)
	scrub_row.add_child(_scrub)
	_scrub_label = Label.new()
	_scrub_label.add_theme_font_size_override("font_size", 12)
	_scrub_label.add_theme_color_override("font_color", Color("#e8c376"))
	scrub_row.add_child(_scrub_label)


# ------------------------------------------------------------------ scenery --

## A grid in GROUND UNITS, not metres. The deck is 1680 x 2320 of them and every
## judgement about whether a prop is the right size is made against that number,
## so the ruler has to speak it. Squares are 25 ground units, the bright lines
## every 100, and the post is 176 — the captain, for scale.
func _build_grid() -> void:
	var mesh := ImmediateMesh.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.surface_begin(Mesh.PRIMITIVE_LINES, mat)
	var half := 8
	for i in range(-half, half + 1):
		var at := float(i) * 0.25
		var strong: bool = (i % 4) == 0
		var tint := Color(0.55, 0.52, 0.60, 0.75) if strong else Color(0.32, 0.30, 0.36, 0.42)
		if i == 0:
			tint = Color(0.80, 0.62, 0.32, 0.9)
		for pair in [[Vector3(at, 0, -2.0), Vector3(at, 0, 2.0)],
				[Vector3(-2.0, 0, at), Vector3(2.0, 0, at)]]:
			mesh.surface_set_color(tint)
			mesh.surface_add_vertex(pair[0])
			mesh.surface_set_color(tint)
			mesh.surface_add_vertex(pair[1])
	## The height post: 1.76 m, ticked every 0.25, standing off to one side so it
	## never sits inside the model it is measuring.
	for i in 8:
		var y := float(i) * 0.25
		var tick := Color(0.9, 0.75, 0.4, 0.8) if i % 4 == 0 else Color(0.6, 0.5, 0.3, 0.5)
		mesh.surface_set_color(tick)
		mesh.surface_add_vertex(Vector3(-1.5, y, 0.0))
		mesh.surface_set_color(tick)
		mesh.surface_add_vertex(Vector3(-1.5 + (0.14 if i % 4 == 0 else 0.07), y, 0.0))
	mesh.surface_set_color(Color(0.9, 0.75, 0.4, 0.8))
	mesh.surface_add_vertex(Vector3(-1.5, 0.0, 0.0))
	mesh.surface_set_color(Color(0.9, 0.75, 0.4, 0.8))
	mesh.surface_add_vertex(Vector3(-1.5, 1.76, 0.0))
	mesh.surface_end()
	_grid = MeshInstance3D.new()
	_grid.mesh = mesh
	_grid.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_world.add_child(_grid)


## The skeleton, and the axes of the bone you have selected, drawn OVER the mesh.
## This is the answer to the question the mount was actually failing on — not
## "what is the offset" but "where is `mixamorig_RightHand`, and which way does
## its Z point". You cannot nudge a sword onto a bone you cannot see.
func _build_overlay() -> void:
	_overlay = MeshInstance3D.new()
	_overlay.mesh = ImmediateMesh.new()
	_overlay.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_world.add_child(_overlay)


func _skeleton() -> Skeleton3D:
	var source: Node = _rig.model if _rig != null and _rig.model != null else _shown
	if source == null:
		return null
	for child in source.find_children("*", "Skeleton3D", true, false):
		return child as Skeleton3D
	return null


func _draw_overlay() -> void:
	var mesh := _overlay.mesh as ImmediateMesh
	mesh.clear_surfaces()
	## Light the weapon's own axes whenever a rotation row is hovered or just
	## nudged, even with BONE AXES off — that is the point of the hint.
	var want_weapon: bool = _mode == MOUNT and _active_axis() >= 0 \
		and _rig != null and _rig.held != null
	if _mode == FX or (not bool(_on.skel) and not bool(_on.axis) and not want_weapon):
		return
	var sk := _skeleton()
	if sk == null:
		return
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	## Through the mesh on purpose. A hand bone is inside a glove; a skeleton you
	## can only see from behind is a skeleton you cannot use.
	mat.no_depth_test = true
	mesh.surface_begin(Mesh.PRIMITIVE_LINES, mat)
	var base := sk.global_transform
	if bool(_on.skel):
		for i in sk.get_bone_count():
			var parent := sk.get_bone_parent(i)
			if parent < 0:
				continue
			var a: Vector3 = (base * sk.get_bone_global_pose(parent)).origin
			var b: Vector3 = (base * sk.get_bone_global_pose(i)).origin
			mesh.surface_set_color(Color(0.45, 0.85, 1.0, 0.55))
			mesh.surface_add_vertex(a)
			mesh.surface_set_color(Color(0.45, 0.85, 1.0, 0.55))
			mesh.surface_add_vertex(b)
	if bool(_on.axis) and _bone_at >= 0 and _bone_at < _bones.size():
		var index := sk.find_bone(_bones[_bone_at])
		if index >= 0:
			var at: Transform3D = base * sk.get_bone_global_pose(index)
			## Fixed length in WORLD metres. The skeleton carries a scale of about
			## a hundred, so an axis drawn in bone units is either invisible or the
			## length of the room.
			var span := 0.12
			for axis in [[0, Color(1.0, 0.30, 0.30)], [1, Color(0.35, 1.0, 0.40)],
					[2, Color(0.40, 0.60, 1.0)]]:
				var dir: Vector3 = at.basis[int(axis[0])].normalized() * span
				mesh.surface_set_color(axis[1])
				mesh.surface_add_vertex(at.origin)
				mesh.surface_set_color(axis[1])
				mesh.surface_add_vertex(at.origin + dir)
	## The WEAPON's live local axes at the grip: X red / pitch, Y green / yaw,
	## Z blue / roll — the same colours as the row hints, the active one bright.
	## This is what makes it visible that each rotation row spins about a
	## different line, which is exactly what the gimbal collapse hid.
	if want_weapon and _rig.held.get_child_count() > 0:
		var holder := _rig.held.get_child(0) as Node3D
		if holder != null:
			var active := _active_axis()
			var wb := holder.global_transform.basis.orthonormalized()
			var origin := holder.global_position
			var span := 0.18
			var cols := [Color(1.0, 0.30, 0.30), Color(0.35, 1.0, 0.40),
				Color(0.40, 0.60, 1.0)]
			for a in 3:
				var bright: bool = a == active
				var col: Color = cols[a]
				col.a = 1.0 if bright else 0.16
				var dir: Vector3 = wb[a].normalized() * span * (1.0 if bright else 0.55)
				mesh.surface_set_color(col)
				mesh.surface_add_vertex(origin - dir * 0.28)
				mesh.surface_set_color(col)
				mesh.surface_add_vertex(origin + dir)
	mesh.surface_end()


# ------------------------------------------------------------------- dialing --

## One nudge on one dial. Every button and every key lands here, so exactly one
## place knows what a step is.
func _dial(which: String, way: float) -> void:
	_snapshot()
	## Shift coarsens a step ten-fold and Alt fines it to a tenth — shown in the
	## header so it is not a secret gesture (priority 3b).
	var s := _step_mult()
	way *= s
	match which:
		"lyaw":
			_light_yaw = wrapf(_light_yaw + 15.0 * way, -180.0, 180.0)
		"lpitch":
			_light_pitch = clampf(_light_pitch + 10.0 * way, -89.0, 0.0)
		"lkey":
			_key_energy = clampf(_key_energy + 0.25 * way, 0.0, 8.0)
		"lamb":
			_ambient = clampf(_ambient + 0.1 * way, 0.0, 3.0)
		"fxr":
			_fx_dial.radius = clampf(float(_fx_dial.radius) + 20.0 * way, 20.0, 900.0)
		"fxa":
			_fx_dial.arc = clampf(float(_fx_dial.arc) + 0.1 * way, 0.15, TAU)
		"fxl":
			_fx_dial.life = clampf(float(_fx_dial.life) + 0.02 * way, 0.04, 3.0)
		"fxd":
			_fx_dial.damage = clampf(float(_fx_dial.damage) + 10.0 * way, 1.0, 300.0)
		"fxp":
			_fx_dial.period = clampf(float(_fx_dial.period) + 0.1 * way, 0.15, 6.0)
		"fxs":
			_fx_dial.slowmo = clampf(float(_fx_dial.slowmo) + 0.1 * way, 0.05, 2.0)
			Engine.time_scale = float(_fx_dial.slowmo)
		"fxg":
			_fx_dial.glow = clampf(float(_fx_dial.glow) + 0.15 * way, 0.0, 4.0)
			_apply_fx_dials()
		"fxq":
			_fx_dial.spark = clampf(float(_fx_dial.spark) + 4.0 * way, 4.0, 160.0)
			_apply_fx_dials()
		"fxt":
			_fx_dial.plife = clampf(float(_fx_dial.plife) + 0.1 * way, 0.1, 4.0)
			_apply_fx_dials()
		_:
			## `way` already carries the step multiplier.
			_dial_mount(which, way)
			return
	if which.begins_with("l"):
		_apply_look()
	_show()


## Nudge a MOUNT row. `way` arrives already scaled by the step multiplier. The
## three rotation rows compose a rotation about the weapon's OWN live local axis
## (via `LabMath.rotate_local`) rather than incrementing an Euler field — the
## whole fix for the yaw/roll collapse. Offset and length stay linear.
func _dial_mount(which: String, way: float) -> void:
	if _mode != MOUNT or _fit.is_empty():
		return
	var o := _v3(_fit.offset)
	match which:
		"mx": o.x += NUDGE * way; _set_v("offset", o)
		"my": o.y += NUDGE * way; _set_v("offset", o)
		"mz": o.z += NUDGE * way; _set_v("offset", o)
		"rx": _rotate_weapon(0, TURN * way)
		"ry": _rotate_weapon(1, TURN * way)
		"rz": _rotate_weapon(2, TURN * way)
		"len": _fit.length = maxf(0.15, float(_fit.length) + GROW * way)
	_apply_mount()
	_show()


## Compose a rotation about the weapon's live local axis onto `_rot_basis`, keep
## the Euler `rotation` array in sync for the file and the readout, and flash the
## axis on the blade so it is clear which line just turned.
func _rotate_weapon(axis: int, degrees: float) -> void:
	_rot_basis = LabMath.rotate_local(_rot_basis, axis, degrees)
	_fit["rotation"] = _euler_array(_rot_basis)
	_flash_axis = axis
	_flash_until = _clock + 0.9


func _euler_array(b: Basis) -> Array:
	var e := LabMath.fit_euler_deg(b)
	return [e.x, e.y, e.z]


func _step_mult() -> float:
	if _shift:
		return 10.0
	if _alt:
		return 0.1
	return 1.0


## The step size shown in the header, so the coarse/fine modifiers are visible
## rather than a gesture you have to already know (priority 3b).
func _step_hint() -> String:
	if _shift:
		return "STEP x10 (Shift held)"
	if _alt:
		return "STEP x0.1 (Alt held)"
	return "STEP x1 - Shift x10, Alt x0.1"


## Which axis to light on the blade right now: a freshly nudged one flashes for
## a moment, otherwise whichever rotation row the mouse is over. -1 draws nothing.
func _active_axis() -> int:
	if _clock < _flash_until and _flash_axis >= 0:
		return _flash_axis
	return _hover_axis


# ------------------------------------------------------------- typed input --

## Wheel over a row's value nudges it, the way every DCC tool does (priority 3d).
func _row_scroll(event: InputEvent, key: String) -> void:
	if event is not InputEventMouseButton:
		return
	var mb := event as InputEventMouseButton
	if not mb.pressed:
		return
	if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
		_shift = mb.shift_pressed
		_alt = mb.alt_pressed
		_dial(key, 1.0)
	elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		_shift = mb.shift_pressed
		_alt = mb.alt_pressed
		_dial(key, -1.0)


## Open the typed-input box over a value. It appears where the number was, seeded
## with the current number and everything selected, so a type-over replaces it.
func _begin_edit(key: String) -> void:
	if not _row_value.has(key):
		return
	_finish_edit()
	_editing_key = key
	var btn := _row_value[key] as Control
	var rect := btn.get_global_rect()
	_editor.position = rect.position - Vector2(2.0, 1.0)
	_editor.size = Vector2(maxf(74.0, rect.size.x + 8.0), maxf(20.0, rect.size.y + 2.0))
	_editor.text = _raw_value(key)
	_editor.visible = true
	_editor.grab_focus()
	_editor.select_all()


## The plain number a row currently holds, with no unit suffix — what you edit.
func _raw_value(key: String) -> String:
	var o := _v3(_fit.offset) if _mode == MOUNT and not _fit.is_empty() else Vector3.ZERO
	var r := _v3(_fit.rotation) if _mode == MOUNT and not _fit.is_empty() else Vector3.ZERO
	match key:
		"mx": return "%.3f" % o.x
		"my": return "%.3f" % o.y
		"mz": return "%.3f" % o.z
		"rx": return "%.1f" % r.x
		"ry": return "%.1f" % r.y
		"rz": return "%.1f" % r.z
		"len": return "%.2f" % float(_fit.length)
		"lyaw": return "%.0f" % _light_yaw
		"lpitch": return "%.0f" % _light_pitch
		"lkey": return "%.2f" % _key_energy
		"lamb": return "%.2f" % _ambient
		"fxr": return "%.0f" % float(_fx_dial.radius)
		"fxa": return "%.2f" % float(_fx_dial.arc)
		"fxl": return "%.2f" % float(_fx_dial.life)
		"fxd": return "%.0f" % float(_fx_dial.damage)
		"fxp": return "%.1f" % float(_fx_dial.period)
		"fxs": return "%.2f" % float(_fx_dial.slowmo)
		"fxg": return "%.2f" % float(_fx_dial.glow)
		"fxq": return "%.0f" % float(_fx_dial.spark)
		"fxt": return "%.1f" % float(_fx_dial.plife)
	return ""


func _editor_submit(text: String) -> void:
	_commit_edit(text)


func _editor_focus_lost() -> void:
	## Clicking away cancels — the entry only takes on ENTER.
	if _editing_key != "":
		_finish_edit()


func _editor_gui(event: InputEvent) -> void:
	if event is InputEventKey and (event as InputEventKey).pressed \
			and (event as InputEventKey).keycode == KEY_ESCAPE:
		_finish_edit()
		_editor.accept_event()


## ENTER landed. A well-formed number is applied (and is an undo point); a
## malformed one is refused and the old value kept — a bad entry never moves
## anything.
func _commit_edit(text: String) -> void:
	var key := _editing_key
	var parsed := LabMath.parse_number(text)
	if bool(parsed.ok) and key != "":
		_snapshot()
		_apply_typed(key, float(parsed.value))
	_finish_edit()


## Hide the box and drop focus. Idempotent — clearing `_editing_key` first stops
## the focus_exited it triggers from re-entering.
func _finish_edit() -> void:
	if _editing_key == "":
		return
	_editing_key = ""
	if _editor != null:
		_editor.visible = false
		if _editor.has_focus():
			_editor.release_focus()
	_show()


## Set a row to an ABSOLUTE typed value, clamped to the same range its nudge uses.
## Rotation sets an Euler component and rebuilds the basis from the three — an
## absolute type-in is exactly where naming yaw/pitch/roll separately is wanted.
func _apply_typed(key: String, val: float) -> void:
	match key:
		"mx", "my", "mz", "len", "rx", "ry", "rz":
			if _mode != MOUNT or _fit.is_empty():
				return
			var o := _v3(_fit.offset)
			var e := _v3(_fit.rotation)
			match key:
				"mx": o.x = val; _set_v("offset", o)
				"my": o.y = val; _set_v("offset", o)
				"mz": o.z = val; _set_v("offset", o)
				"len": _fit.length = maxf(0.15, val)
				"rx": e.x = val
				"ry": e.y = val
				"rz": e.z = val
			if key.begins_with("r"):
				_rot_basis = LabMath.fit_basis(e)
				_fit["rotation"] = _euler_array(_rot_basis)
				_flash_axis = {"rx": 0, "ry": 1, "rz": 2}[key]
				_flash_until = _clock + 0.9
			_apply_mount()
		"lyaw": _light_yaw = wrapf(val, -180.0, 180.0); _apply_look()
		"lpitch": _light_pitch = clampf(val, -89.0, 0.0); _apply_look()
		"lkey": _key_energy = clampf(val, 0.0, 8.0); _apply_look()
		"lamb": _ambient = clampf(val, 0.0, 3.0); _apply_look()
		"fxr": _fx_dial.radius = clampf(val, 20.0, 900.0)
		"fxa": _fx_dial.arc = clampf(val, 0.15, TAU)
		"fxl": _fx_dial.life = clampf(val, 0.04, 3.0)
		"fxd": _fx_dial.damage = clampf(val, 1.0, 300.0)
		"fxp": _fx_dial.period = clampf(val, 0.15, 6.0)
		"fxs":
			_fx_dial.slowmo = clampf(val, 0.05, 2.0)
			Engine.time_scale = float(_fx_dial.slowmo)
		"fxg": _fx_dial.glow = clampf(val, 0.0, 4.0); _apply_fx_dials()
		"fxq": _fx_dial.spark = clampf(val, 4.0, 160.0); _apply_fx_dials()
		"fxt": _fx_dial.plife = clampf(val, 0.1, 4.0); _apply_fx_dials()
	_show()


# -------------------------------------------------------------------- undo --

## One level of undo. Snapshotted before every nudge, drag and typed entry;
## restored by Ctrl+Z. Single level is enough to take back the last mistake.
func _snapshot() -> void:
	_undo_state = {
		"mode": _mode, "fit": _fit.duplicate(true), "rot": _rot_basis,
		"fx": _fx_dial.duplicate(true), "lyaw": _light_yaw, "lpitch": _light_pitch,
		"lkey": _key_energy, "lamb": _ambient,
	}
	_has_undo = true


func _undo() -> void:
	if not _has_undo:
		_note = "nothing to undo."
		_show()
		return
	_has_undo = false
	var u := _undo_state
	_light_yaw = float(u.lyaw)
	_light_pitch = float(u.lpitch)
	_key_energy = float(u.lkey)
	_ambient = float(u.lamb)
	if int(u.mode) == _mode and _mode == MOUNT:
		_fit = (u.fit as Dictionary).duplicate(true)
		_rot_basis = u.rot
		_apply_mount()
	elif int(u.mode) == _mode and _mode == FX:
		_fx_dial = (u.fx as Dictionary).duplicate(true)
		Engine.time_scale = float(_fx_dial.slowmo)
		_apply_fx_dials()
	_apply_look()
	_note = "undid the last change."
	_tick()


func _flip(key: String) -> void:
	_on[key] = not bool(_on.get(key, false))
	_apply_look()
	_show()


func _press(what: String) -> void:
	match what:
		"view": _set_mode(VIEW)
		"mount": _set_mode(MOUNT)
		"fx": _set_mode(FX)
		"save": _save()
		"revert":
			if _mode == MOUNT:
				_fit = _saved.duplicate(true)
				_rot_basis = LabMath.fit_basis(_v3(_fit.rotation))
				_apply_mount()
		"spin": _spin = not _spin
		"backdrop":
			_bg_at = (_bg_at + 1) % BACKDROPS.size()
			_apply_look()
		"play": _set_playing(not _playing)
		"rewind":
			_seek_fraction(0.0)
			_set_playing(false)
		"back": _step(-1)
		"forward": _step(1)
		"loop":
			_loop = not _loop
			_apply_loop()
		"fire": _fx_fire()
	_tick()


func _set_mode(next: int) -> void:
	if next == _mode:
		return
	if _mode == FX:
		_leave_fx()
	_mode = next
	if _mode == FX:
		_enter_fx()
	else:
		_load()
	_build_rows()


func _pick(which: int) -> void:
	_at = which
	if _mode == FX:
		_leave_fx()
		_mode = VIEW
		_build_rows()
	_load()
	_tick()


func _pick_bone(which: int) -> void:
	_bone_at = which
	if _mode == MOUNT:
		_apply_mount()
	_tick()


func _pick_fx_kind(which: int) -> void:
	_fx_kind = which
	if _mode != FX:
		_set_mode(FX)
	_fx_fire()
	_tick()


func _pick_fx_element(which: int) -> void:
	_fx_element = which
	if _mode != FX:
		_set_mode(FX)
	_fx_fire()
	_tick()


func _path_for(key: String) -> String:
	var scene := "res://assets/models/%s/%s.tscn" % [key, key]
	return scene if ResourceLoader.exists(scene) \
		else "res://assets/models/%s/%s.glb" % [key, key]


# ------------------------------------------------------------------ loading --

func _load() -> void:
	if _shown != null:
		_shown.queue_free()
		_shown = null
	if _rig != null:
		_rig.queue_free()
		_rig = null
	_anim = null
	_bones.clear()
	for old in _bonelist.get_children():
		_bonelist.remove_child(old)
		old.queue_free()
	_note = ""

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

	## AT THE SIZE THE DECK WILL RENDER IT, not at the size its file happens to
	## be. An ingested FBX carries a unit scale and measures two centimetres; a
	## Meshy GLB is whatever the generator felt like. Both are rescaled on the way
	## onto the deck, so a lab that frames the raw file is framing a size nobody
	## will ever see — the captain came up as a speck beside a one-metre grid.
	## The ingest writes the real height onto the root as `model_height`, and it is
	## the authority — a SKINNED mesh's own AABB is the bind pose in mesh space and
	## can be nothing like what the skeleton actually draws. `SkyGearRig3D.setup`
	## prefers the meta for exactly this reason; framing that did not was showing
	## the captain floating half out of frame.
	var meta_h := float(probe.get_meta("model_height", 0.0))
	var measured: float = meta_h if meta_h > 0.0 else box.size.y
	var deck := _deck_units(key)
	var stand: float = measured
	if deck > 0.0 and measured > 0.0001:
		stand = deck * SkyGearView3D.WORLD_SCALE
	_stats = "%d tris  -  %d surfaces  -  %d bones  -  %.0f ground units tall (%.2f m)%s" % [
		tris, mats, bone_count, stand / SkyGearView3D.WORLD_SCALE, stand,
		"" if deck > 0.0 else "  (measured from the file - no deck size is registered for this model yet)"]
	if tris > 20000:
		_stats += "     HEAVY: over 20k triangles."

	for i in _models.size():
		var row := _list.get_child(i) as Button
		row.add_theme_color_override("font_color",
			Color("#37f0c8") if i == _at else Color("#b9afaa"))

	if _mode == MOUNT:
		if box.size.y > HOLDABLE_M:
			_note = "%.1f m is scenery, not something a person holds — MOUNT is off." % box.size.y
			_mode = VIEW
		elif not ResourceLoader.exists(RIG):
			_note = "no captain rig on disk, so there is nothing to mount onto."
			_mode = VIEW
	if _mode == MOUNT:
		_build_mount()
	elif skeleton != null:
		## A SKINNED MODEL IS SET UP THE WAY THE GAME SETS IT UP. Its own AABB is
		## the bind pose in mesh space and nothing like what the skeleton draws, so
		## measuring it and centring on the result put the captain in the air above
		## her own grid. `SkyGearRig3D.setup` reads the ingest's `model_height` and
		## trusts the Mixamo convention that the origin sits between the feet —
		## which is what the deck does, so what stands here is what stands there.
		_rig = SkyGearRig3D.new()
		_world.add_child(_rig)
		if not _rig.setup(_path_for(key), stand, 1):
			_rig.queue_free()
			_rig = null
		else:
			_focus_y = stand * 0.52
			_dolly = maxf(0.3, stand * FIT)
			_cam.near = clampf(_dolly * 0.004, 0.001, 0.05)
	if _mode != MOUNT and _rig == null:
		var holder := Node3D.new()
		holder.add_child(packed.instantiate())
		_world.add_child(holder)
		_shown = holder
		holder.scale = Vector3.ONE * (stand / maxf(0.0001, measured))
		## Measured again, after scaling and in the tree, then sat on the grid.
		var live := _live_box(holder)
		holder.position -= Vector3(live.get_center().x, live.position.y,
			live.get_center().z)
		live = _live_box(holder)
		_focus_y = live.size.y * 0.52
		## Framed on what is actually there, so a keg and a Colossus are both
		## legible without touching the wheel. No absolute floor on the dolly: one
		## used to hold the camera 1.4 m from a model 2 cm tall.
		_dolly = maxf(0.06, maxf(live.size.x, maxf(live.size.y, live.size.z)) * FIT)
		_cam.near = clampf(_dolly * 0.004, 0.001, 0.05)

	_collect_bones()
	_collect_clips()
	_apply_look()
	_build_rows()


## What the GAME will make this thing, in GROUND UNITS. Read from the renderer's
## own tables rather than restated, because two functions disagreeing about one
## number is how three of this project's visual bugs were made. Zero means no
## table knows, and the header says so rather than guessing quietly.
## What is on screen, in world metres, right now. Two passes are cheap and one
## assumption is not.
func _live_box(under: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for child in under.find_children("*", "MeshInstance3D", true, false):
		var mi := child as MeshInstance3D
		if mi.mesh == null:
			continue
		var world_box: AABB = mi.global_transform * mi.get_aabb()
		box = world_box if first else box.merge(world_box)
		first = false
	return box


func _deck_units(key: String) -> float:
	if key == "captain":
		return SkyGearView3D.CAPTAIN_HEIGHT
	var kind := key.to_upper()
	if SkyGearData.ENEMIES.has(kind):
		## The same expression `_sync_all` uses for a boarder's height. If that one
		## moves, this one is wrong and the lab will quietly lie about every enemy.
		return 120.0 + float(SkyGearData.ENEMIES[kind].get("radius", 22.0)) * 3.0
	for prop_type in SkyGearView3D.PROP_MODEL:
		if str(SkyGearView3D.PROP_MODEL[prop_type]) == key:
			return float(SkyGearView3D.PROP_HEIGHT.get(prop_type, 0.0))
	## Generated, on disk, deliberately not wired to the deck — but the size they
	## were made FOR is still the size the next attempt has to be judged at.
	if key == "brazier":
		return float(SkyGearView3D.PROP_HEIGHT.get("brazier", 0.0))
	if key == "crate_small":
		return float(SkyGearView3D.PROP_HEIGHT.get("crate", 0.0))
	return 0.0


func _build_mount() -> void:
	_rig = SkyGearRig3D.new()
	_world.add_child(_rig)
	## 1.8 m, which is the frame `weapons.json` is authored in — the renderer
	## rescales offset and length by her real deck height on the way in. Change
	## this and every saved number silently means something else.
	if not _rig.setup(RIG, 1.8, 1):
		_mode = VIEW
		return
	if _fit.is_empty():
		_fit = SkyGearRig3D.weapon_fit("captain")
		if _fit.is_empty():
			_fit = {"bone": "mixamorig_RightHand", "length": 0.95,
				"offset": [0.0, 0.0, 0.0], "rotation": [-120.0, 0.0, 0.0]}
		_saved = _fit.duplicate(true)
	## The live rotation basis is seeded from the fit's stored Euler through the
	## same conversion the file uses, so an existing weapons.json fit mounts to the
	## exact pose it saved at — the fit-compatibility guarantee (SG-39 part 1).
	_rot_basis = LabMath.fit_basis(_v3(_fit.rotation))
	## Far enough back that her whole silhouette is in frame. A grip judged on a
	## crop of one hand is a grip you cannot see leaving the hand.
	_dolly = 1.8 * FIT
	_focus_y = 0.9
	_collect_bones()
	_bone_at = maxi(0, _bones.find(str(_fit.bone)))
	_apply_mount()


## The bone list, from whatever skeleton is on screen — the mounted rig's or a
## skinned model being viewed on its own. Filtered to the bones anything is ever
## hung off: thirty-three rows of spine is a list nobody scrolls.
func _collect_bones() -> void:
	_bones.clear()
	for old in _bonelist.get_children():
		_bonelist.remove_child(old)
		old.queue_free()
	var sk := _skeleton()
	if sk == null:
		_heading(_bonelist, "BONES")
		var none := Label.new()
		none.text = "no skeleton on
this model"
		none.add_theme_font_size_override("font_size", 11)
		none.add_theme_color_override("font_color", Color("#6f655e"))
		_bonelist.add_child(none)
		return
	for i in sk.get_bone_count():
		_bones.append(sk.get_bone_name(i))
	if _bone_at >= _bones.size():
		_bone_at = 0
	for i in _bones.size():
		var bone_name := _bones[i]
		if not ("Hand" in bone_name or "Arm" in bone_name or "Shoulder" in bone_name
				or "Spine" in bone_name or "Head" in bone_name):
			continue
		var row := _chip(bone_name.replace("mixamorig_", ""), LIST_W - 24.0, ROW_H)
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.flat = true
		row.pressed.connect(_pick_bone.bind(i))
		_bonelist.add_child(row)


func _apply_mount() -> void:
	if _rig == null:
		return
	if not _bones.is_empty():
		_fit["bone"] = _bones[_bone_at]
	_rig.hold(_path_for(_models[_at]), str(_fit.bone), _v3(_fit.offset),
		_v3(_fit.rotation), float(_fit.length), 1)
	_apply_look()
	## And keep playing whatever was playing. Re-seating the weapon used to snap
	## the rig back to a paused idle, which meant every nudge threw away the frame
	## of the swing you were nudging it AT — the exact frame that matters.
	_apply_clip(true)


# ---------------------------------------------------------------- animation --

func _collect_clips() -> void:
	_clips.clear()
	_anim = null
	var source: Node = _rig.model if _rig != null and _rig.model != null else _shown
	if source != null:
		_anim = source.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _anim != null:
		for name in _anim.get_animation_list():
			_clips.append(str(name))
		_clips.sort()
	for old in _clip_chips.get_children():
		_clip_chips.remove_child(old)
		old.queue_free()
	for i in _clips.size():
		var b := _chip(_clips[i], 0, 22, 12)
		b.pressed.connect(_pick_clip.bind(i))
		_clip_chips.add_child(b)
	if _clips.is_empty():
		_clip_name = ""
		_playing = false
		return
	if not _clips.has(_clip_name):
		_clip_name = "idle" if _clips.has("idle") else _clips[0]
	_apply_clip(false)


func _pick_clip(which: int) -> void:
	if which < 0 or which >= _clips.size():
		return
	_clip_name = _clips[which]
	_apply_clip(false)
	_set_playing(true)
	_tick()


## Put the player on the wanted clip at the wanted time. `keep_time` is what lets
## a mount nudge happen mid-swing without losing the frame.
func _apply_clip(keep_time: bool) -> void:
	if _anim == null or _clip_name == "" or not _anim.has_animation(_clip_name):
		return
	var was := _anim.current_animation_position if keep_time else 0.0
	_apply_loop()
	_anim.play(_clip_name)
	_anim.speed_scale = _speed
	_anim.seek(clampf(was, 0.0, _length()), true)
	if not _playing:
		_anim.pause()
	_refresh_scrub()


## LOOP is written onto the clip itself rather than faked with a restart, because
## Godot blends a looping clip across the wrap and a hand-rolled `seek(0)` pops.
## In-memory only — nothing here ever saves an animation resource.
func _apply_loop() -> void:
	if _anim == null or _clip_name == "" or not _anim.has_animation(_clip_name):
		return
	var clip := _anim.get_animation(_clip_name)
	clip.loop_mode = Animation.LOOP_LINEAR if _loop else Animation.LOOP_NONE


func _length() -> float:
	if _anim == null or _clip_name == "" or not _anim.has_animation(_clip_name):
		return 0.0
	return maxf(0.0001, _anim.get_animation(_clip_name).length)


func _set_playing(on: bool) -> void:
	_playing = on
	if _anim == null or _clip_name == "":
		_playing = false
		return
	if _playing:
		if not _anim.is_playing():
			_anim.play(_clip_name)
		_anim.speed_scale = _speed
	else:
		_anim.pause()


func _set_speed(rate: float) -> void:
	_speed = clampf(rate, 0.02, 4.0)
	if _anim != null:
		_anim.speed_scale = _speed
	_tick()


## One frame at a time, and PAUSED, because stepping is what you do when you have
## found the moment and want to look at it.
func _step(direction: int) -> void:
	if _anim == null or _clip_name == "":
		return
	_set_playing(false)
	var at: float = clampf(_anim.current_animation_position + FRAME * float(direction),
		0.0, _length())
	_anim.seek(at, true)
	_refresh_scrub()


func _seek_fraction(fraction: float) -> void:
	if _anim == null or _clip_name == "":
		return
	if not _anim.is_playing():
		_anim.play(_clip_name)
		_anim.pause()
	_anim.seek(clampf(fraction, 0.0, 1.0) * _length(), true)
	_refresh_scrub()


func _on_scrub(value: float) -> void:
	if _scrubbing or _anim == null or _clip_name == "":
		return
	## Scrubbing pauses. Dragging a bar on something that is still running is how
	## you end up certain you saw a frame you did not.
	_set_playing(false)
	_anim.seek(value * _length(), true)
	_refresh_scrub()


func _refresh_scrub() -> void:
	if _scrub == null:
		return
	var length := _length()
	var at: float = _anim.current_animation_position if _anim != null else 0.0
	_scrubbing = true
	_scrub.set_value_no_signal(clampf(at / maxf(0.0001, length), 0.0, 1.0))
	_scrubbing = false
	if _clip_name == "":
		_scrub_label.text = "no clips on this model"
	else:
		_scrub_label.text = "%.2f / %.2f s      frame %d of %d      %.2fx" % [
			at, length, int(round(at / FRAME)), int(round(length / FRAME)), _speed]


# ----------------------------------------------------------------------- fx --

## FX mode is the REAL renderer. `main3d.tscn` is the view plus the simulation
## scene, and the simulation sits in its menu state doing nothing except ageing
## and expiring effects — which is exactly the loop we want and none of the wave
## pressure we do not. Nothing here re-implements an effect; it fires the same
## `_fx` dictionary the skill code fires and lets `view3d.gd` draw it.
func _enter_fx() -> void:
	if _fx_world != null:
		return
	var packed := load("res://scenes/main3d.tscn") as PackedScene
	if packed == null:
		_note = "scenes/main3d.tscn is missing, so FX has nothing to run."
		_mode = VIEW
		_load()
		return
	_world.visible = false
	_cam.current = false
	_fx_world = packed.instantiate() as Node3D
	root.add_child(_fx_world)
	_fx_view = _fx_world as SkyGearView3D
	_fx_game = _fx_world.get_node_or_null("SkyGear") as SkyGearGame
	if _fx_view == null or _fx_game == null:
		_note = "main3d.tscn is not the shape this expects."
		_leave_fx()
		_mode = VIEW
		_load()
		return
	## The title screen would sit on top of everything, and the menu would eat the
	## keys. Neither is what we came to look at.
	if _fx_game.hud != null:
		_fx_game.hud.visible = false
		_fx_game.hud.set_process_unhandled_input(false)
	_fx_game.set_process_input(false)
	_fx_game.set_process_unhandled_input(false)
	_fx_view.sway = bool(_on.sway)
	for child in _fx_view.find_children("*", "WorldEnvironment", true, false):
		_fx_env = (child as WorldEnvironment).environment
	_apply_fx_dials()
	_fx_clock = 999.0
	_clips.clear()
	_clip_name = ""
	_collect_clips()


func _leave_fx() -> void:
	Engine.time_scale = 1.0
	if _fx_world != null:
		_fx_world.queue_free()
		_fx_world = null
	_fx_view = null
	_fx_game = null
	_fx_env = null
	_world.visible = true
	_cam.current = true


## Everything a dial can reach on a running renderer. Deliberately live rather
## than saved: these map onto constants in `view3d.gd`, and a JSON file nobody
## reads is the failure this project has made five times. SAVE in FX mode puts
## the numbers on the clipboard with the constant they belong to instead.
func _apply_fx_dials() -> void:
	if _fx_env != null:
		_fx_env.glow_strength = float(_fx_dial.glow)
	if _fx_view == null:
		return
	for family in _fx_view._sparks.keys():
		var node: GPUParticles3D = _fx_view._sparks[family]
		node.lifetime = float(_fx_dial.plife)
		var mesh := node.draw_pass_1 as QuadMesh
		if mesh != null:
			var scale: float = 1.0 if family != "steam" else 46.0 / 26.0
			mesh.size = Vector2.ONE * float(_fx_dial.spark) * scale \
				* SkyGearView3D.WORLD_SCALE


func _fx_fire() -> void:
	if _fx_view == null or _fx_game == null or _fx_game.player == null:
		return
	var at: Vector2 = _fx_game.player.global_position
	## Up the deck, which is the direction the camera is looking down. A cone
	## fired sideways is a cone you are judging in profile.
	var angle := -PI * 0.5
	var direction := Vector2(cos(angle), sin(angle))
	var element: String = FX_ELEMENTS[_fx_element]
	var tint: Color = SkyGearData.ELEMENTS[element].color
	var kind: String = FX_KINDS[_fx_kind]
	var radius: float = float(_fx_dial.radius)
	var life: float = float(_fx_dial.life)
	var d := {"kind": kind, "color": tint, "time": 0.0, "life": life}
	if kind == "line" or kind == "beam":
		d["from"] = at
		d["to"] = at + direction * radius
	else:
		d["position"] = at
		d["direction"] = angle
		d["radius"] = radius
		d["arc"] = float(_fx_dial.arc)
	_fx_game._fx(d)
	## And the particles and the light, which are the other half of a hit and
	## come from a different function entirely.
	_fx_view.impact_at(at + direction * radius * 0.6, element, float(_fx_dial.damage))
	_fx_clock = 0.0


# ------------------------------------------------------------------ display --

func _apply_look() -> void:
	root.debug_draw = Viewport.DEBUG_DRAW_WIREFRAME if bool(_on.wire) \
		else Viewport.DEBUG_DRAW_DISABLED
	if _grid != null:
		_grid.visible = bool(_on.grid) and _mode != FX
	if _env != null:
		_env.background_color = BACKDROPS[_bg_at].color
		## FLAT kills the lamps and turns the ambient up, which is the only honest
		## way to look at an albedo texture: under a key light you are judging the
		## lighting as much as the paint.
		_env.ambient_light_energy = 1.7 if bool(_on.flat) else _ambient
	if _key_light != null:
		_key_light.rotation = Vector3(deg_to_rad(_light_pitch), deg_to_rad(_light_yaw), 0.0)
		_key_light.light_energy = 0.0 if bool(_on.flat) else _key_energy
	if _fill_light != null:
		_fill_light.light_energy = 0.0 if bool(_on.flat) else 0.7
	if _fx_view != null:
		_fx_view.sway = bool(_on.sway)

	if _clay_mat == null:
		_clay_mat = StandardMaterial3D.new()
		_clay_mat.albedo_color = Color(0.76, 0.74, 0.71)
		_clay_mat.roughness = 0.62
		_clay_mat.metallic = 0.0
	for mesh in _all_meshes():
		mesh.material_override = _clay_mat if bool(_on.clay) else null
	_refresh_toggles()


func _all_meshes() -> Array:
	var out: Array = []
	for source in [_shown, _rig]:
		if source == null:
			continue
		for child in (source as Node).find_children("*", "MeshInstance3D", true, false):
			out.append(child)
	return out


func _refresh_toggles() -> void:
	for key in ["wire", "clay", "flat", "grid", "skel", "axis", "sway"]:
		var b: Button = _toggle_btn.get(key)
		if b != null:
			b.add_theme_color_override("font_color",
				Color("#37f0c8") if bool(_on.get(key, false)) else Color("#b9afaa"))
	var bg: Button = _toggle_btn.get("backdrop")
	if bg != null:
		bg.text = "BACKDROP  %s" % str(BACKDROPS[_bg_at].name)
	for i in 3:
		var b: Button = _toggle_btn.get(["view", "mount", "fx"][i])
		if b != null:
			b.add_theme_color_override("font_color",
				Color("#37f0c8") if _mode == i else Color("#b9afaa"))
	var spin_btn: Button = _toggle_btn.get("spin")
	if spin_btn != null:
		spin_btn.add_theme_color_override("font_color",
			Color("#37f0c8") if _spin else Color("#b9afaa"))
	for i in FX_KINDS.size():
		var b: Button = _toggle_btn.get("fxk%d" % i)
		if b != null:
			b.add_theme_color_override("font_color",
				Color("#37f0c8") if _fx_kind == i and _mode == FX else Color("#b9afaa"))
	for i in FX_ELEMENTS.size():
		var b: Button = _toggle_btn.get("fxe%d" % i)
		if b != null:
			b.add_theme_color_override("font_color",
				SkyGearData.ELEMENTS[FX_ELEMENTS[i]].color if _fx_element == i
					else Color("#b9afaa"))
	if _transport.has("play"):
		(_transport.play as Button).text = "PAUSE" if _playing else "PLAY"
	if _transport.has("loop"):
		(_transport.loop as Button).add_theme_color_override("font_color",
			Color("#37f0c8") if _loop else Color("#b9afaa"))
	for preset in SPEEDS:
		var b: Button = _transport.get("s" + str(preset[1]))
		if b != null:
			b.add_theme_color_override("font_color",
				Color("#37f0c8") if is_equal_approx(_speed, float(preset[0]))
					else Color("#b9afaa"))
	for i in _clip_chips.get_child_count():
		var b := _clip_chips.get_child(i) as Button
		b.add_theme_color_override("font_color",
			Color("#37f0c8") if i < _clips.size() and _clips[i] == _clip_name
				else Color("#b9afaa"))


func _tick() -> void:
	## Looking slightly BELOW the middle of the model lifts it in frame, which is
	## what keeps the boots off the timeline. 0.573 is the vertical extent of a
	## 32-degree field at one unit of distance.
	var focus := Vector3(0.0, _focus_y - _dolly * 0.573 * LIFT, 0.0)
	_cam.position = focus + Vector3(
		sin(_yaw) * cos(_pitch), -sin(_pitch), cos(_yaw) * cos(_pitch)) * _dolly
	_cam.look_at(focus)
	## Slid left afterwards, orientation untouched, which pushes the subject to
	## the right of frame and out from under the dial stack. Doing it here rather
	## than by moving the panels means the framing is the same in every mode.
	_cam.position -= _cam.global_transform.basis.x * (_dolly * RIGHT)
	_show()


func _show() -> void:
	var lines: Array[String] = []
	if _mode == FX:
		lines.append("EFFECTS LOOP        %s / %s        every %.1fs"
			% [FX_KINDS[_fx_kind].to_upper(), FX_ELEMENTS[_fx_element],
				float(_fx_dial.period)])
		lines.append("the real renderer on the real deck - pick an effect on the right - click a dial to type it.   %s"
			% _step_hint())
		lines.append("SAVE puts these numbers on the clipboard with the constant they belong to")
	else:
		lines.append("%s        %s" % [_models[_at].to_upper(), MODE_NAME[_mode]])
		lines.append(_stats)
		if _mode == MOUNT and not _fit.is_empty():
			var o := _v3(_fit.offset)
			var r := _v3(_fit.rotation)
			lines.append("bone %s   offset %+.3f %+.3f %+.3f   rot %+.0f %+.0f %+.0f   %.2f m   %s"
				% [str(_fit.bone).replace("mixamorig_", ""), o.x, o.y, o.z, r.x, r.y, r.z,
					float(_fit.length),
					"UNSAVED" if str(_fit) != str(_saved) else "saved to weapons.json"])
			lines.append("Click a value to type it - wheel a row to nudge - each PITCH/YAW/ROLL spins the blade's OWN axis.   %s"
				% _step_hint())
		else:
			lines.append("Drag to orbit, wheel to dolly - click a value to type it - grid squares are 25 ground units, the post 176.   %s"
				% _step_hint())
	if _note != "":
		lines.append(_note)
	_label.text = "\n".join(lines)

	for pair in [["lyaw", "%+.0f" % _light_yaw], ["lpitch", "%+.0f" % _light_pitch],
			["lkey", "%.2f" % _key_energy], ["lamb", "%.2f" % _ambient]]:
		var value: Label = _row_value.get(str(pair[0]))
		if value != null:
			value.text = str(pair[1])
	if _mode == MOUNT and not _fit.is_empty():
		var o := _v3(_fit.offset)
		var r := _v3(_fit.rotation)
		for pair in [["mx", "%+.3f" % o.x], ["my", "%+.3f" % o.y], ["mz", "%+.3f" % o.z],
				["rx", "%+.0f" % r.x], ["ry", "%+.0f" % r.y], ["rz", "%+.0f" % r.z],
				["len", "%.2f m" % float(_fit.length)]]:
			var value: Button = _row_value.get(str(pair[0]))
			if value != null:
				value.text = str(pair[1])
	if _mode == FX:
		for pair in [["fxr", "%.0f" % float(_fx_dial.radius)],
				["fxa", "%.2f rad" % float(_fx_dial.arc)],
				["fxl", "%.2f s" % float(_fx_dial.life)],
				["fxd", "%.0f" % float(_fx_dial.damage)],
				["fxp", "%.1f s" % float(_fx_dial.period)],
				["fxs", "%.2fx" % float(_fx_dial.slowmo)],
				["fxg", "%.2f" % float(_fx_dial.glow)],
				["fxq", "%.0f" % float(_fx_dial.spark)],
				["fxt", "%.1f s" % float(_fx_dial.plife)]]:
			var value: Button = _row_value.get(str(pair[0]))
			if value != null:
				value.text = str(pair[1])
	_timeline.visible = _mode != FX
	## In FX mode none of these reach anything — the deck brings its own lights,
	## its own sky and no skeleton. A dial that does nothing is worse than no dial.
	if _look_frame != null:
		_look_frame.visible = _mode != FX
	if _bone_frame != null:
		_bone_frame.visible = _mode != FX
	_refresh_scrub()
	_refresh_toggles()


func _v3(a) -> Vector3:
	if a is Array and (a as Array).size() >= 3:
		return Vector3(float(a[0]), float(a[1]), float(a[2]))
	return Vector3.ZERO


func _set_v(field: String, v: Vector3) -> void:
	_fit[field] = [v.x, v.y, v.z]


func _process(delta: float) -> bool:
	_clock += delta
	if _spin and _mode != FX:
		_yaw += delta * 0.6
		_tick()
	if _mode == FX:
		_fx_clock += delta
		if _fx_clock >= float(_fx_dial.period):
			_fx_fire()
		return false
	_draw_overlay()
	if _playing and _anim != null:
		## A one-shot clip stops itself at the end. Looping is set on the clip, so
		## this only catches the non-looping case and the rounding at the wrap.
		if not _anim.is_playing():
			if _loop:
				_anim.play(_clip_name)
				_anim.seek(0.0, true)
			else:
				_playing = false
				_refresh_toggles()
		_refresh_scrub()
	return false


# -------------------------------------------------------------------- input --

func hand(event: InputEvent) -> void:
	if event is InputEventKey:
		_shift = (event as InputEventKey).shift_pressed
		_alt = (event as InputEventKey).alt_pressed
		## While a value is being typed the LineEdit owns the keyboard — the global
		## shortcuts (and ESC-quits) must stay out of its way.
		if _editing_key != "":
			return
		_key(event as InputEventKey)
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		_shift = mb.shift_pressed
		_alt = mb.alt_pressed
		## Never over the lists or the timeline, or dragging to pick a model
		## orbits the camera underneath it.
		if mb.position.x < LIST_W + 20.0 or mb.position.x > _w - LIST_W - 20.0:
			return
		if _timeline != null and _timeline.visible \
				and mb.position.y > _timeline.position.y - 6.0:
			return
		match mb.button_index:
			MOUSE_BUTTON_LEFT:
				if mb.pressed and _mode == MOUNT:
					_snapshot()
				_dragging = 1 if mb.pressed else 0
			MOUSE_BUTTON_RIGHT:
				if mb.pressed and _mode == MOUNT:
					_snapshot()
				_dragging = 2 if mb.pressed else 0
			MOUSE_BUTTON_WHEEL_UP: _wheel(-1.0)
			MOUSE_BUTTON_WHEEL_DOWN: _wheel(1.0)
		return
	if event is InputEventMouseMotion and _dragging > 0:
		_drag((event as InputEventMouseMotion).relative)


func _wheel(notches: float) -> void:
	if _mode == FX:
		return
	if _mode == MOUNT:
		_fit.length = maxf(0.15, float(_fit.length) - notches * GROW)
		_apply_mount()
	else:
		_dolly = clampf(_dolly * (1.12 if notches > 0.0 else 0.89), 0.6, 80.0)
	_tick()


func _drag(by: Vector2) -> void:
	if _mode != MOUNT:
		if _mode == FX:
			return
		_yaw -= by.x * 0.006
		_pitch = clampf(_pitch + by.y * 0.005, -1.3, 1.3)
		_tick()
		return
	var o := _v3(_fit.offset)
	if _dragging == 2:
		## Right-drag turns the blade about its OWN live axes — yaw about local Y,
		## pitch about local X — so a drag never collapses the way Euler edits did.
		_rotate_weapon(1, by.x * DRAG_TURN)
		_rotate_weapon(0, by.y * DRAG_TURN)
	elif _shift:
		## Along its own length, which is the axis you cannot see from the front
		## and the one a grip usually needs.
		o.z += by.y * DRAG_MOVE
		_set_v("offset", o)
	else:
		o.x += by.x * DRAG_MOVE
		o.y -= by.y * DRAG_MOVE
		_set_v("offset", o)
	_apply_mount()
	_show()


func _key(event: InputEventKey) -> void:
	if not event.pressed or event.echo:
		return
	var k := event.keycode
	## Ctrl+Z takes back the last nudge, drag or typed entry, in any mode.
	if event.ctrl_pressed and k == KEY_Z:
		_undo()
		return
	match k:
		KEY_ESCAPE:
			_leave_fx()
			quit(0)
			return
		KEY_TAB:
			_set_mode((_mode + 1) % 3)
			_tick()
			return
		KEY_SPACE:
			_press("play")
			return
		KEY_COMMA:
			_step(-1)
			return
		KEY_PERIOD:
			_step(1)
			return
		KEY_T:
			_press("spin")
			return
	if _mode == MOUNT:
		## Every mount nudge routes through `_dial`, so keys, buttons and the wheel
		## share one path: it snapshots for undo, applies the step multiplier, and
		## rotates about the blade's live local axis. A/D yaw, W/S pitch, Q/E roll.
		match k:
			KEY_LEFT: _dial("mx", -1.0)
			KEY_RIGHT: _dial("mx", 1.0)
			KEY_UP: _dial("my", 1.0)
			KEY_DOWN: _dial("my", -1.0)
			KEY_A: _dial("ry", -1.0)
			KEY_D: _dial("ry", 1.0)
			KEY_W: _dial("rx", -1.0)
			KEY_S: _dial("rx", 1.0)
			KEY_Q: _dial("rz", -1.0)
			KEY_E: _dial("rz", 1.0)
			KEY_BRACKETLEFT: _dial("len", -1.0)
			KEY_BRACKETRIGHT: _dial("len", 1.0)
			KEY_R:
				_snapshot()
				_fit = _saved.duplicate(true)
				_rot_basis = LabMath.fit_basis(_v3(_fit.rotation))
				_apply_mount()
				_show()
			KEY_ENTER, KEY_KP_ENTER:
				_save()
			KEY_Z:
				_at = wrapi(_at - 1, 0, _models.size())
				_load()
				_tick()
			KEY_X:
				_at = wrapi(_at + 1, 0, _models.size())
				_load()
				_tick()
		return
	match k:
		## Z and X rather than PgUp/PgDn: a laptop has no page keys, which is how
		## the first version of this ended up undriveable.
		KEY_Z:
			_at = wrapi(_at - 1, 0, _models.size())
			_load()
		KEY_X:
			_at = wrapi(_at + 1, 0, _models.size())
			_load()
		KEY_A: _yaw -= 0.12
		KEY_D: _yaw += 0.12
		KEY_W: _pitch = clampf(_pitch - 0.07, -1.3, 1.3)
		KEY_S: _pitch = clampf(_pitch + 0.07, -1.3, 1.3)
		KEY_BRACKETLEFT: _dolly = maxf(0.6, _dolly * 0.88)
		KEY_BRACKETRIGHT: _dolly = minf(80.0, _dolly * 1.14)
		KEY_ENTER, KEY_KP_ENTER: _save()
		_:
			return
	_tick()


# --------------------------------------------------------------------- save --

func _save() -> void:
	if _mode == FX:
		_save_fx()
		return
	if _mode != MOUNT:
		_note = "nothing to save in VIEW — MOUNT is what writes a number."
		_show()
		return
	## Only the captain entry, and only the fields the mount owns. A tool that
	## rewrites more than it was asked to is a tool nobody runs twice.
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
	_note = "written to assets/models/weapons.json — the game reads it on the next launch."
	print("saved %s on %s  offset %s  rotation %s  length %.2f"
		% [_models[_at], str(_fit.bone), str(_fit.offset), str(_fit.rotation),
			float(_fit.length)])
	_show()


## The effect dials have no data file, deliberately. Every one of them is a
## CONSTANT in the renderer, and inventing a JSON for them would be the fifth
## time this project has shipped a table nothing reads. So SAVE hands back the
## numbers and the exact place they go, on the clipboard and on stdout.
func _save_fx() -> void:
	var lines := [
		"# dialled in tools/model_lab.gd, FX mode, %s / %s"
			% [FX_KINDS[_fx_kind], FX_ELEMENTS[_fx_element]],
		"# scripts/view3d.gd  _build_impacts()",
		"    node.lifetime = %.2f                 # was 1.0" % float(_fx_dial.plife),
		"    mesh.size = Vector2(%.0f, %.0f) * WORLD_SCALE   # was 26 / 46"
			% [float(_fx_dial.spark), float(_fx_dial.spark) * 46.0 / 26.0],
		"# scripts/game.gd  the _fx({...}) call for this shape",
		'    {"kind": "%s", "radius": %.0f, "arc": %.2f, "life": %.2f}'
			% [FX_KINDS[_fx_kind], float(_fx_dial.radius), float(_fx_dial.arc),
				float(_fx_dial.life)],
		"# environment glow_strength = %.2f" % float(_fx_dial.glow),
	]
	var text := "\n".join(lines)
	DisplayServer.clipboard_set(text)
	print("\n" + text + "\n\ncopied to the clipboard")
	_note = "copied to the clipboard — paste it where the comment says."
	_show()
