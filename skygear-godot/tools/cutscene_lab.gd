extends SceneTree
## Author a cutscene against the REAL renderer, and save something the game plays.
##
##   godot --path . --resolution 1600x900 --script tools/cutscene_lab.gd
##   ... -- --open colossus_arrival        open one
##   ... -- --play colossus_arrival --at 0.4 --frame out.png
##                                          render that instant, no interface
##   ... -- --open colossus_arrival --shot ui.png
##                                          photograph the tool itself
##
## THE REAL RENDERER, not a preview. This instantiates `scenes/main3d.tscn` —
## the same deck, the same models, the same lighting, the same lens the fight
## runs through — the way `tools/model_lab.gd`'s FX mode does, and for the same
## reason: a shot approved against an approximation is a shot nobody has seen.
##
## MOUSE FIRST, and this is not a preference. The machine this is authored on has
## no PageUp, no PageDown and no numpad; a tool that needs one is a tool that
## does not exist. Every single thing below is a click, a drag or a scroll, and
## the keys are shortcuts layered on top.
##
##   DRAG            orbit the camera around the point it is looking at
##   RIGHT-DRAG      slide both the camera and its target across the deck
##   WHEEL           in and out along the view axis
##   THE DIAL RACK   every one of those numbers, one labelled axis at a time
##   THE TIMELINE    click a keyframe, drag it in time, scrub between them
##
## AUTO-KEY. Move the camera anywhere on the timeline and a keyframe appears at
## that instant, seeded from the pose you were already looking at. That is the
## whole authoring loop: scrub to a moment, move the camera, move on. The toggle
## turns it off for when you want to look around without recording.
##
## WHAT IT WRITES. `assets/cutscenes/<id>.json`, and an index beside it. The
## format, the reader and the four trigger points are all in
## `scripts/cutscene.gd`; the runtime that drives the camera is
## `scripts/cutscene_player.gd`. All three existed before this tool did, because
## a saved format with no reader is the failure this project has committed five
## times and the one it can least afford to commit again.
func _initialize() -> void: call_deferred("_run")

const LIST_W := 194.0
const ROW_H := 19.0
## One frame at the rate the game runs, so the instant you stop on is an instant
## the player will actually be shown.
const FRAME := 1.0 / 60.0
## Two keyframes closer together than this are the same keyframe as far as
## clicking, dragging and auto-key are concerned. A twentieth of a second is
## about the smallest gap a hand can aim at on a 900-pixel-wide track.
const SNAP := 0.02

## How far one click of a dial moves. Positions are in GROUND UNITS against a
## deck 1680 by 2320 of them, so 40 is about a fortieth of the deck's width —
## small enough to place a shot, large enough that crossing the deck is a dozen
## clicks rather than forty. Shift quarters every one of them.
const STEP_POS := 40.0
const STEP_FOV := 1.0
const STEP_ROLL := 1.0
const STEP_TIME := 0.1
const FINE := 0.25

## Metres of orbit per pixel of drag, and radians of it. Slow enough to land a
## framing, fast enough to get across the deck without letting go.
const DRAG_ORBIT := 0.006
const DRAG_PAN := 2.6            ## ground units per pixel
const WHEEL_DOLLY := 1.12

const SPEEDS := [[0.1, "0.1x"], [0.25, "0.25x"], [0.5, "0.5x"], [1.0, "1x"], [2.0, "2x"]]

## What the CUE button cycles through. "" is a cutscene that nothing plays,
## which is a legitimate thing to be while it is being written — and the reason
## it is first in the list rather than absent from it.
const CUE_CHOICES := ["", "boss_arrival", "wave_start", "victory", "defeat"]


## Input, and the late tick. `process_priority` is the load-bearing part: the
## renderer writes the gameplay camera in its own `_process`, so anything that
## wants to be the camera has to run AFTER it. A `SceneTree._process` override
## runs BEFORE the nodes and was silently overwritten every frame — the first
## version of this tool showed the gameplay camera no matter what the dials said.
class Hands extends Node:
	var lab
	func _ready() -> void:
		set_process_unhandled_input(true)
		process_priority = 100
	func _unhandled_input(event: InputEvent) -> void:
		if lab != null:
			lab.hand(event)
	func _process(delta: float) -> void:
		if lab != null:
			lab.after_frame(delta)


## The keyframe track. A row of diamonds under the scrub bar: click one to
## select it, drag it to move it in time, click the empty track to scrub there.
## Drawn rather than built out of buttons because a keyframe has to be DRAGGABLE
## along its own axis, and a Button cannot be.
class KeyTrack extends Control:
	var lab
	func _draw() -> void:
		if lab != null:
			lab.draw_track(self)
	func _gui_input(event: InputEvent) -> void:
		if lab != null:
			lab.track_input(self, event)


var _w := 1600.0
var _h := 900.0

var _world: Node3D
var _view: SkyGearView3D
var _game: SkyGearGame
var _cam: Camera3D

## EVERY control lives on this layer. The game owns a `Camera2D` for the hidden
## 2D simulation, and a `Camera2D` transforms the whole default canvas layer —
## `model_lab.gd` learned this the expensive way when the effects loop dragged
## its entire interface eight hundred pixels down the screen.
var _ui: CanvasLayer

var _ids: Array[String] = []
var _scene: Dictionary = {}
var _id := ""
var _dirty := false
var _note := ""

var _time := 0.0
var _playing := false
var _loop := true
var _speed := 1.0
var _selected := 0
var _autokey := true
var _sway := false
var _scrubbing := false
var _dragging := 0
var _shift := false

var _label: Label
var _list: VBoxContainer
var _keylist: VBoxContainer
var _rows: VBoxContainer
var _row_value: Dictionary = {}
var _btn: Dictionary = {}
var _timeline: PanelContainer
var _scrub: HSlider
var _scrub_label: Label
var _track: KeyTrack
var _name_edit: LineEdit
var _hands: Hands

var _bar_layer: CanvasLayer
var _bar_top: ColorRect
var _bar_bottom: ColorRect

var _shot_to := ""
var _frame_to := ""


func _run() -> void:
	var seen := root.get_visible_rect().size
	if seen.x > 200.0 and seen.y > 200.0:
		_w = seen.x
		_h = seen.y

	var want_open := ""
	var want_at := -1.0
	var want_stage := ""
	var argv := OS.get_cmdline_user_args()
	for i in argv.size():
		if (argv[i] == "--open" or argv[i] == "--play") and i + 1 < argv.size():
			want_open = str(argv[i + 1])
		if argv[i] == "--at" and i + 1 < argv.size():
			want_at = clampf(float(argv[i + 1]), 0.0, 1.0)
		if argv[i] == "--shot" and i + 1 < argv.size():
			_shot_to = str(argv[i + 1])
		## The picture on its own, with the interface taken down. This is what a
		## before-and-after of a shot needs — a screenshot with a dial rack across
		## it is a screenshot of the dial rack.
		if argv[i] == "--frame" and i + 1 < argv.size():
			_frame_to = str(argv[i + 1])
		## The same buttons the STAGE panel carries, reachable from a script — so
		## "the Colossus at 40% of its arrival shot" is a picture a before-and-after
		## can be made of, twice, months apart. A framing that can only be reproduced
		## by clicking is a framing nobody re-checks.
		if argv[i] == "--stage" and i + 1 < argv.size():
			want_stage = str(argv[i + 1])

	if not _enter_world():
		return

	## THE BARS GET THEIR OWN LAYER, under the interface and over the deck. A shot
	## framed without them is a shot framed against a picture 12% taller than the
	## one the player will see — the captain's head goes behind the top bar and
	## nobody finds out until it ships. They stay up for `--frame` too, because
	## that render is meant to BE the player's picture.
	_bar_layer = CanvasLayer.new()
	_bar_layer.layer = 15
	root.add_child(_bar_layer)
	for top in [true, false]:
		var bar := ColorRect.new()
		bar.color = Color(0.0, 0.0, 0.0, 1.0)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.set_anchors_preset(Control.PRESET_TOP_WIDE if top else Control.PRESET_BOTTOM_WIDE)
		_bar_layer.add_child(bar)
		if top:
			_bar_top = bar
		else:
			_bar_bottom = bar

	_ui = CanvasLayer.new()
	_ui.layer = 20
	root.add_child(_ui)
	_build_ui()

	_hands = Hands.new()
	root.add_child(_hands)
	_hands.lab = self

	_ids = SkyGearCutscene.list_ids()
	_refresh_list()
	if want_open != "" and _ids.has(want_open):
		_open(want_open)
	elif not _ids.is_empty():
		_open(_ids[0])
	else:
		_new()
	if want_stage != "":
		_stage(want_stage)
	if want_at >= 0.0:
		_time = want_at * maxf(0.0001, SkyGearCutscene.length(_scene))
	_show()

	if _shot_to != "" or _frame_to != "":
		## Six frames, the same warm-up `model_lab.gd` waits out: the deck's
		## shaders are compiled on first draw and a shot taken on frame one is a
		## photograph of a scene still arriving.
		for _i in 8:
			await process_frame
		if _frame_to != "":
			_ui.visible = false
			await process_frame
			await process_frame
			root.get_texture().get_image().save_png(_frame_to)
			print("frame %s @ %.2fs -> %s" % [_id, _time, _frame_to])
			_ui.visible = true
		if _shot_to != "":
			await process_frame
			await process_frame
			root.get_texture().get_image().save_png(_shot_to)
			print("shot %s -> %s" % [_id, _shot_to])
		quit(0)


## The real deck. Everything about this block is `model_lab.gd`'s FX mode, for
## the same reason it gives: nothing here re-implements the renderer, so what is
## framed in this tool is what the game will show.
func _enter_world() -> bool:
	var packed := load("res://scenes/main3d.tscn") as PackedScene
	if packed == null:
		print("scenes/main3d.tscn is missing — there is nothing to point a camera at")
		quit(1)
		return false
	_world = packed.instantiate() as Node3D
	root.add_child(_world)
	_view = _world as SkyGearView3D
	_game = _world.get_node_or_null("SkyGear") as SkyGearGame
	if _view == null or _game == null:
		print("main3d.tscn is not the shape this expects")
		quit(1)
		return false
	## The title screen would sit over the frame and the menu would eat the
	## clicks. Neither is what we came to look at.
	if _game.hud != null:
		_game.hud.visible = false
		_game.hud.set_process_unhandled_input(false)
	_game.set_process_input(false)
	_game.set_process_unhandled_input(false)
	## And the SHIPPED cutscenes stay out of the way. Staging wave 12 to frame the
	## Colossus would otherwise fire the very cutscene being authored, on top of
	## itself, hiding the interface and locking the controls.
	_view.cutscenes_enabled = false
	_view.sway = _sway
	return true


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
	## LEFT: which cutscene, and the deck to frame it against.
	var frame := _panel(Vector2(10, 10), Vector2(LIST_W, 236))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	frame.add_child(box)
	_heading(box, "CUTSCENES")
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(LIST_W - 24.0, 128)
	box.add_child(scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 1)
	scroll.add_child(_list)
	## The id, editable. This is both "name the new one" and "rename this one":
	## SAVE writes to whatever is in the box, so there is one control instead of
	## two that have to be explained apart.
	_name_edit = LineEdit.new()
	_name_edit.custom_minimum_size = Vector2(LIST_W - 24.0, 24)
	_name_edit.add_theme_font_size_override("font_size", 12)
	_name_edit.text_changed.connect(func(_t: String) -> void: _show())
	box.add_child(_name_edit)
	var file_row := HBoxContainer.new()
	file_row.add_theme_constant_override("separation", 3)
	box.add_child(file_row)
	for pair in [["NEW", "new"], ["SAVE", "save"], ["DELETE", "delete"]]:
		var b := _chip(str(pair[0]), (LIST_W - 30.0) / 3.0, 24, 11)
		b.pressed.connect(_press.bind(str(pair[1])))
		file_row.add_child(b)
		_btn[str(pair[1])] = b

	_build_stage()
	_build_keys()
	_build_scene_panel()

	_label = Label.new()
	_label.position = Vector2(LIST_W + 22.0, 10.0)
	_label.add_theme_font_size_override("font_size", 14)
	_label.add_theme_color_override("font_color", Color("#e6ddd0"))
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_label.add_theme_constant_override("outline_size", 5)
	_ui.add_child(_label)

	_rows = VBoxContainer.new()
	_rows.position = Vector2(LIST_W + 22.0, 132.0)
	_rows.add_theme_constant_override("separation", 2)
	_ui.add_child(_rows)
	_build_rows()

	_build_timeline()


## Something to point the camera AT. An empty deck is a fine place to learn the
## controls and a useless place to judge a boss arrival, and the reason the shot
## that ships was framable at all is that this panel can put the Colossus on the
## planking without playing eleven waves first.
func _build_stage() -> void:
	var frame := _panel(Vector2(10, 254), Vector2(LIST_W, 0))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	frame.add_child(box)
	_heading(box, "STAGE — what is on the deck")
	for pair in [["START A RUN", "run"], ["WAVE 12", "wave12"],
			["PUT THE COLOSSUS ON", "boss"], ["THREE BOARDERS", "boarders"],
			["CLEAR THE DECK", "clear"]]:
		var b := _chip(str(pair[0]), LIST_W - 24.0, 21, 11)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(_press.bind(str(pair[1])))
		box.add_child(b)
	_heading(box, "LOOK")
	for pair in [["SHIP SWAY", "sway"], ["AUTO-KEY", "autokey"]]:
		var b := _chip(str(pair[0]), LIST_W - 24.0, 21, 11)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(_press.bind(str(pair[1])))
		box.add_child(b)
		_btn[str(pair[1])] = b
	var frame_btn := _chip("SNAPSHOT THIS FRAME", LIST_W - 24.0, 21, 11)
	frame_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	frame_btn.pressed.connect(_press.bind("snapshot"))
	box.add_child(frame_btn)


## RIGHT: the keyframes themselves, and the verbs that act on them.
func _build_keys() -> void:
	var frame := _panel(Vector2(_w - LIST_W - 10.0, 10.0), Vector2(LIST_W, 236))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	frame.add_child(box)
	_heading(box, "KEYFRAMES")
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(LIST_W - 24.0, 150)
	box.add_child(scroll)
	_keylist = VBoxContainer.new()
	_keylist.add_theme_constant_override("separation", 1)
	scroll.add_child(_keylist)
	var verbs := HBoxContainer.new()
	verbs.add_theme_constant_override("separation", 3)
	box.add_child(verbs)
	for pair in [["ADD", "addkey"], ["SET", "setkey"], ["DROP", "dropkey"],
			["PIN", "pinkey"]]:
		var b := _chip(str(pair[0]), (LIST_W - 33.0) / 4.0, 24, 11)
		## PIN is the one that needs explaining, and a tooltip is where an
		## explanation belongs when the button has to stay four letters wide.
		if str(pair[1]) == "pinkey":
			b.tooltip_text = "pin this keyframe to the LIVE gameplay camera, wherever the captain happens to be — the way a shot ends without a cut"
		b.pressed.connect(_press.bind(str(pair[1])))
		verbs.add_child(b)


## And everything about the SCENE rather than about one keyframe.
func _build_scene_panel() -> void:
	var frame := _panel(Vector2(_w - LIST_W - 10.0, 254.0), Vector2(LIST_W, 0))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	frame.add_child(box)
	_heading(box, "WHEN IT PLAYS")
	var cue := _chip("CUE  —", LIST_W - 24.0, 22, 11)
	cue.alignment = HORIZONTAL_ALIGNMENT_LEFT
	cue.pressed.connect(_press.bind("cue"))
	box.add_child(cue)
	_btn["cue"] = cue
	var wave := HBoxContainer.new()
	wave.add_theme_constant_override("separation", 3)
	box.add_child(wave)
	for way in [-1.0, 1.0]:
		var b := _chip("-" if way < 0.0 else "+", 24, 20, 11)
		b.pressed.connect(_dial.bind("wave", way))
		wave.add_child(b)
	var wave_label := Label.new()
	wave_label.text = "WAVE"
	wave_label.custom_minimum_size = Vector2(56, 20)
	wave_label.add_theme_font_size_override("font_size", 11)
	wave_label.add_theme_color_override("font_color", Color("#b9afaa"))
	wave.add_child(wave_label)
	var wave_value := Label.new()
	wave_value.add_theme_font_size_override("font_size", 11)
	wave_value.add_theme_color_override("font_color", Color("#e8c376"))
	_row_value["wave"] = wave_value
	wave.add_child(wave_value)
	_heading(box, "HOW IT PRESENTS")
	for pair in [["hold", "LOCK THE CAPTAIN"], ["hide_hud", "HIDE THE HUD"],
			["sway", "KEEP THE SHIP'S SWAY"]]:
		var b := _chip(str(pair[1]), LIST_W - 24.0, 21, 11)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(_press.bind("flip:" + str(pair[0])))
		box.add_child(b)
		_btn[str(pair[0])] = b
	var bars := HBoxContainer.new()
	bars.add_theme_constant_override("separation", 3)
	box.add_child(bars)
	for way in [-1.0, 1.0]:
		var b := _chip("-" if way < 0.0 else "+", 24, 20, 11)
		b.pressed.connect(_dial.bind("letterbox", way))
		bars.add_child(b)
	var bar_label := Label.new()
	bar_label.text = "BARS"
	bar_label.custom_minimum_size = Vector2(56, 20)
	bar_label.add_theme_font_size_override("font_size", 11)
	bar_label.add_theme_color_override("font_color", Color("#b9afaa"))
	bars.add_child(bar_label)
	var bar_value := Label.new()
	bar_value.add_theme_font_size_override("font_size", 11)
	bar_value.add_theme_color_override("font_color", Color("#e8c376"))
	_row_value["letterbox"] = bar_value
	bars.add_child(bar_value)


## THE DIAL RACK. Every number on the selected keyframe, one labelled axis at a
## time, with the live value beside it.
##
## Named in WORDS, not X/Y/Z. `model_lab.gd` carries the same rack and the same
## comment for the same reported reason: nobody looking at a deck knows which
## way its Z points, and "ALONG  bow / stern" is a thing you can act on without
## first working out the handedness of the world.
func _build_rows() -> void:
	for old in _rows.get_children():
		_rows.remove_child(old)
		old.queue_free()
	_row_value.erase("ex")
	var specs := [
		["ex", "CAMERA  across   port / starboard"],
		["ey", "CAMERA  height   up off the planking"],
		["ez", "CAMERA  along    toward the bow / the stern"],
		["lx", "AIMED   across   port / starboard"],
		["ly", "AIMED   height   up off the planking"],
		["lz", "AIMED   along    toward the bow / the stern"],
		["fov", "LENS             wider / longer"],
		["roll", "ROLL             tilt the horizon"],
		["t", "AT               when this key happens"],
	]
	for spec in specs:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		for way in [-1.0, 1.0]:
			var b := _chip("-" if way < 0.0 else "+", 30, 22, 13)
			b.pressed.connect(_dial.bind(str(spec[0]), way))
			row.add_child(b)
		var name_label := Label.new()
		name_label.text = str(spec[1])
		name_label.custom_minimum_size = Vector2(300, 22)
		name_label.add_theme_font_size_override("font_size", 13)
		name_label.add_theme_color_override("font_color", Color("#b9afaa"))
		row.add_child(name_label)
		var value := Label.new()
		value.custom_minimum_size = Vector2(96, 22)
		value.add_theme_font_size_override("font_size", 13)
		value.add_theme_color_override("font_color", Color("#e8c376"))
		_row_value[str(spec[0])] = value
		row.add_child(value)
		_rows.add_child(row)
	## The ease is a name rather than a number, so it cycles rather than nudges.
	var ease_row := HBoxContainer.new()
	ease_row.add_theme_constant_override("separation", 4)
	var ease_btn := _chip("EASE", 64, 22, 12)
	ease_btn.pressed.connect(_press.bind("ease"))
	ease_row.add_child(ease_btn)
	var ease_name := Label.new()
	ease_name.custom_minimum_size = Vector2(272, 22)
	ease_name.add_theme_font_size_override("font_size", 13)
	ease_name.add_theme_color_override("font_color", Color("#b9afaa"))
	_row_value["easewhat"] = ease_name
	ease_row.add_child(ease_name)
	var ease_value := Label.new()
	ease_value.custom_minimum_size = Vector2(96, 22)
	ease_value.add_theme_font_size_override("font_size", 13)
	ease_value.add_theme_color_override("font_color", Color("#e8c376"))
	_row_value["ease"] = ease_value
	ease_row.add_child(ease_value)
	_rows.add_child(ease_row)


## THE TIMELINE, along the bottom, where a timeline lives in every tool anyone
## has already used.
func _build_timeline() -> void:
	_timeline = _panel(Vector2(LIST_W + 22.0, _h - 176.0),
		Vector2(_w - LIST_W * 2.0 - 44.0, 166.0))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	_timeline.add_child(box)
	_heading(box, "TIMELINE — click a diamond to select it, drag it to move it in time")

	_track = KeyTrack.new()
	_track.lab = self
	_track.custom_minimum_size = Vector2(_w - LIST_W * 2.0 - 68.0, 34)
	box.add_child(_track)

	var scrub_row := HBoxContainer.new()
	scrub_row.add_theme_constant_override("separation", 8)
	box.add_child(scrub_row)
	_scrub = HSlider.new()
	_scrub.min_value = 0.0
	_scrub.max_value = 1.0
	_scrub.step = 0.0005
	_scrub.custom_minimum_size = Vector2(_w - LIST_W * 2.0 - 320.0, 22)
	_scrub.value_changed.connect(_on_scrub)
	scrub_row.add_child(_scrub)
	_scrub_label = Label.new()
	_scrub_label.add_theme_font_size_override("font_size", 12)
	_scrub_label.add_theme_color_override("font_color", Color("#e8c376"))
	scrub_row.add_child(_scrub_label)

	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 4)
	box.add_child(bar)
	for pair in [["|< START", "rewind"], ["< STEP", "back"], ["PLAY", "play"],
			["STEP >", "forward"], ["LOOP", "loop"]]:
		var b := _chip(str(pair[0]), 84, 26, 12)
		b.pressed.connect(_press.bind(str(pair[1])))
		bar.add_child(b)
		_btn[str(pair[1])] = b
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(14, 0)
	bar.add_child(gap)
	var speed_label := Label.new()
	speed_label.text = "SPEED"
	speed_label.add_theme_font_size_override("font_size", 12)
	speed_label.add_theme_color_override("font_color", Color("#b9afaa"))
	bar.add_child(speed_label)
	for preset in SPEEDS:
		var b := _chip(str(preset[1]), 46, 26, 12)
		b.pressed.connect(_set_speed.bind(float(preset[0])))
		bar.add_child(b)
		_btn["s" + str(preset[1])] = b


# ------------------------------------------------------------------- drawing --

func draw_track(track: Control) -> void:
	var size := track.size
	var total := maxf(0.0001, SkyGearCutscene.length(_scene))
	## The bed. Wider than the diamonds so the whole strip reads as one axis
	## rather than as a row of unrelated markers.
	track.draw_rect(Rect2(0.0, size.y * 0.5 - 3.0, size.x, 6.0),
		Color(0.16, 0.14, 0.20, 0.95))
	## A tick every second, because "how long is this shot" is the question you
	## ask constantly and a bar with no scale cannot answer it.
	var second := 0
	while float(second) <= total:
		var x: float = float(second) / total * size.x
		track.draw_line(Vector2(x, size.y * 0.5 - 9.0), Vector2(x, size.y * 0.5 + 9.0),
			Color(0.38, 0.35, 0.42, 0.7), 1.0)
		second += 1
	## The playhead.
	var head: float = clampf(_time / total, 0.0, 1.0) * size.x
	track.draw_line(Vector2(head, 2.0), Vector2(head, size.y - 2.0),
		Color("#37f0c8"), 2.0)
	var keys: Array = _scene.get("keys", [])
	for i in keys.size():
		var key: Dictionary = keys[i]
		var x: float = clampf(float(key.t) / total, 0.0, 1.0) * size.x
		var y: float = size.y * 0.5
		var r: float = 9.0 if i == _selected else 7.0
		var tint: Color = Color("#f0c060") if i == _selected else Color("#9a8f86")
		track.draw_colored_polygon(PackedVector2Array([
			Vector2(x, y - r), Vector2(x + r, y), Vector2(x, y + r), Vector2(x - r, y)]),
			tint)


func track_input(track: Control, event: InputEvent) -> void:
	var size := track.size
	var total := maxf(0.0001, SkyGearCutscene.length(_scene))
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if not mb.pressed:
			_dragging = 0
			return
		var at: float = clampf(mb.position.x / maxf(1.0, size.x), 0.0, 1.0) * total
		var near := _key_near(at, total * 12.0 / maxf(1.0, size.x))
		if near >= 0:
			_selected = near
			## Dragging state 3 means "a diamond is under the finger". Held on the
			## lab rather than on the track so releasing anywhere ends it.
			_dragging = 3
		else:
			_dragging = 0
		_time = at
		_playing = false
		_show()
		return
	if event is InputEventMouseMotion and _dragging == 3:
		var mm := event as InputEventMouseMotion
		var at: float = clampf(mm.position.x / maxf(1.0, size.x), 0.0, 1.0) * total
		_move_key(_selected, at)
		_time = float((_scene.keys[_selected] as Dictionary).t)
		_show()


## The keyframe within `slack` seconds of `at`, or -1. Nearest wins, so two keys
## almost on top of each other still resolve to the one clicked closest to.
func _key_near(at: float, slack: float) -> int:
	var best := -1
	var best_gap := slack
	var keys: Array = _scene.get("keys", [])
	for i in keys.size():
		var gap: float = absf(float((keys[i] as Dictionary).t) - at)
		if gap <= best_gap:
			best_gap = gap
			best = i
	return best


# ------------------------------------------------------------------- editing --

func _keys() -> Array:
	return _scene.get("keys", []) as Array


## The scene with its pinned keys filled in from where the gameplay camera is
## right now. `_scene` stays unbound and is what SAVE writes, so a pin survives
## the round trip and is resolved fresh every time the game plays the shot.
func _bound() -> Dictionary:
	if _view == null:
		return _scene
	return SkyGearCutscene.bind(_scene, _view._focus)


## Editing a pinned key un-pins it, because the two cannot both be true: a key
## whose numbers come from the gameplay camera cannot also carry numbers you
## dragged. Silent would be wrong, so `_show` says PINNED next to the key and it
## stops saying it the moment you move it.
func _unpin(key: Dictionary) -> void:
	if str(key.get("from", "")) == "gameplay":
		var shot := SkyGearCutscene.sample(_bound(), float(key.t))
		key["eye"] = [shot.eye.x, shot.eye.y, shot.eye.z]
		key["look"] = [shot.look.x, shot.look.y, shot.look.z]
		key["fov"] = float(shot.fov)
		key["from"] = ""
		_note = "key %d un-pinned — it carries its own numbers now." % (_selected + 1)


func _key() -> Dictionary:
	var keys := _keys()
	if keys.is_empty():
		return {}
	_selected = clampi(_selected, 0, keys.size() - 1)
	return keys[_selected]


## Move a key in time and put the list back in order, keeping the same key
## selected. Re-sorting is what makes dragging a key PAST another one work
## rather than corrupt the scene, and it is why the selection is tracked by
## identity here instead of by index.
func _move_key(index: int, to: float) -> void:
	var keys := _keys()
	if index < 0 or index >= keys.size():
		return
	var key: Dictionary = keys[index]
	key["t"] = maxf(0.0, to)
	keys.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.t) < float(b.t))
	_selected = keys.find(key)
	_dirty = true
	_refresh_keys()


## The pose the camera is in right now, as a keyframe dictionary. Sampled from
## the scene rather than read back off the Camera3D, so the numbers that go into
## a key are in GROUND UNITS and are the same numbers that came out — a
## round-trip through metres and a look-at matrix loses the aim point entirely.
func _pose_now() -> Dictionary:
	var shot := SkyGearCutscene.sample(_bound(), _time)
	return {"t": _time,
		"eye": [shot.eye.x, shot.eye.y, shot.eye.z],
		"look": [shot.look.x, shot.look.y, shot.look.z],
		"fov": float(shot.fov), "roll": float(shot.roll), "ease": "inout", "from": ""}


## Insert a key at the current time, or return the one already there. This is
## AUTO-KEY: the first move of the camera at a fresh instant records one.
func _key_here() -> Dictionary:
	var keys := _keys()
	var near := _key_near(_time, SNAP)
	if near >= 0:
		_selected = near
		return keys[near]
	var key := _pose_now()
	## Inherit the ease of the key we are landing between, so inserting a middle
	## key into a linear drift does not silently put a settle in the middle of it.
	var before := _key_near(_time - 1e6, 1e9)
	if before >= 0:
		key["ease"] = str((keys[before] as Dictionary).get("ease", "inout"))
	keys.append(key)
	keys.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.t) < float(b.t))
	_selected = keys.find(key)
	_dirty = true
	_refresh_keys()
	return key


## The key a drag or a dial should write into. Without auto-key, dials still
## edit the SELECTED key and the scrub jumps to it — a dial that changes nothing
## visible is worse than a dial that moves the playhead.
func _edit_target() -> Dictionary:
	if _autokey:
		return _key_here()
	var key := _key()
	if key.is_empty():
		return {}
	_time = float(key.t)
	return key


func _dial(which: String, way: float) -> void:
	var amount: float = way * (FINE if _shift else 1.0)
	if which == "wave":
		_scene["wave"] = clampi(int(_scene.get("wave", 0)) + int(signf(way)), 0, 12)
		_dirty = true
		_show()
		return
	if which == "letterbox":
		_scene["letterbox"] = clampf(float(_scene.get("letterbox", 0.12))
			+ 0.01 * amount, 0.0, 0.3)
		_dirty = true
		_show()
		return
	if which == "t":
		var key := _key()
		if not key.is_empty():
			_move_key(_selected, maxf(0.0, float(key.t) + STEP_TIME * amount))
			_time = float((_keys()[_selected] as Dictionary).t)
		_show()
		return
	var target := _edit_target()
	if target.is_empty():
		return
	_unpin(target)
	var eye := SkyGearCutscene.to_vector(target.eye)
	var look := SkyGearCutscene.to_vector(target.look)
	match which:
		"ex": eye.x += STEP_POS * amount
		"ey": eye.y += STEP_POS * amount
		"ez": eye.z += STEP_POS * amount
		"lx": look.x += STEP_POS * amount
		"ly": look.y += STEP_POS * amount
		"lz": look.z += STEP_POS * amount
		"fov": target["fov"] = clampf(float(target.fov) + STEP_FOV * amount, 8.0, 100.0)
		"roll": target["roll"] = clampf(float(target.roll) + STEP_ROLL * amount, -90.0, 90.0)
	target["eye"] = [eye.x, eye.y, eye.z]
	target["look"] = [look.x, look.y, look.z]
	_dirty = true
	_show()


func _press(what: String) -> void:
	if what.begins_with("flip:"):
		var field := what.substr(5)
		_scene[field] = not bool(_scene.get(field, true))
		_dirty = true
		_show()
		return
	match what:
		"new": _new()
		"save": _save()
		"delete": _delete()
		"addkey":
			_key_here()
		"setkey":
			## Overwrite the selected key with wherever the camera is now. The
			## other half of ADD: ADD records a new instant, SET re-frames one that
			## already exists without moving it in time.
			var key := _key()
			if not key.is_empty():
				var pose := _pose_now()
				key["eye"] = pose.eye
				key["look"] = pose.look
				key["fov"] = pose.fov
				key["roll"] = pose.roll
				_dirty = true
		"pinkey":
			var key := _key()
			if not key.is_empty():
				key["from"] = "" if str(key.get("from", "")) == "gameplay" else "gameplay"
				_dirty = true
				_note = ("key %d follows the gameplay camera now — the shot hands back without a cut."
					% (_selected + 1)) if str(key.from) == "gameplay" \
					else "key %d carries its own numbers again." % (_selected + 1)
		"dropkey":
			var keys := _keys()
			## Never below two. A cutscene with one key has no duration and nothing
			## to scrub, and deleting your way into one is an easy accident with a
			## confusing result.
			if keys.size() > 2:
				keys.remove_at(clampi(_selected, 0, keys.size() - 1))
				_selected = clampi(_selected, 0, keys.size() - 1)
				_dirty = true
				_refresh_keys()
			else:
				_note = "a cutscene needs two keyframes to be a movement at all."
		"ease":
			var key := _key()
			if not key.is_empty():
				var at := SkyGearCutscene.EASES.find(str(key.get("ease", "inout")))
				key["ease"] = SkyGearCutscene.EASES[(at + 1) % SkyGearCutscene.EASES.size()]
				_dirty = true
		"cue":
			var at := CUE_CHOICES.find(str(_scene.get("cue", "")))
			_scene["cue"] = CUE_CHOICES[(at + 1) % CUE_CHOICES.size()]
			_dirty = true
		"play": _playing = not _playing
		"rewind":
			_time = 0.0
			_playing = false
		"back": _step(-1)
		"forward": _step(1)
		"loop": _loop = not _loop
		"sway":
			_sway = not _sway
			if _view != null:
				_view.sway = _sway
		"autokey": _autokey = not _autokey
		"snapshot": _snapshot()
		"run": _stage("run")
		"wave12": _stage("wave12")
		"boss": _stage("boss")
		"boarders": _stage("boarders")
		"clear": _stage("clear")
	_show()


func _step(direction: int) -> void:
	_playing = false
	_time = clampf(_time + FRAME * float(direction), 0.0,
		SkyGearCutscene.length(_scene))


func _set_speed(rate: float) -> void:
	_speed = clampf(rate, 0.02, 4.0)
	_show()


func _on_scrub(value: float) -> void:
	if _scrubbing:
		return
	## Scrubbing pauses. Dragging a bar on something that is still running is how
	## you end up certain you saw a frame you did not — `model_lab.gd`'s note,
	## and it was right there too.
	_playing = false
	_time = value * SkyGearCutscene.length(_scene)
	_show()


# -------------------------------------------------------------------- staging --

func _stage(what: String) -> void:
	if _game == null:
		return
	match what:
		"run":
			_game.begin_run()
			if not _game.draft_options.is_empty():
				_game.choose_draft(0)
			_note = "wave 1, one weapon. The captain is where the camera follows her."
		"wave12":
			if _game.state == SkyGearGame.State.TITLE:
				_game.begin_run()
				if not _game.draft_options.is_empty():
					_game.choose_draft(0)
			_game.start_wave(12)
			_note = "wave 12 — the Colossus spawns at the bow on its own."
		"boss":
			_game.spawn_enemy("BOSS", 1)
			_note = "the Colossus is at the bow, around x 0, z -1115."
		"boarders":
			for lane in 3:
				_game.spawn_enemy("SCRAPPER", lane)
		"clear":
			for enemy in _game.get_tree().get_nodes_in_group("enemies"):
				if is_instance_valid(enemy):
					enemy.queue_free()
			_note = "deck cleared."


## A PNG of exactly what is on screen, without the interface. The one habit that
## has caught things in this project is looking at the picture, and a snapshot
## you have to leave the tool to take is a snapshot nobody takes.
func _snapshot() -> void:
	var out := "res://.shots/cutscene/%s-%.2f.png" % [_id if _id != "" else "untitled", _time]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.shots/cutscene"))
	_ui.visible = false
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(out))
	_ui.visible = true
	_note = "written to %s" % out
	print("snapshot -> %s" % out)
	_show()


# --------------------------------------------------------------------- files --

func _refresh_list() -> void:
	for old in _list.get_children():
		_list.remove_child(old)
		old.queue_free()
	for id in _ids:
		var row := _chip(id, LIST_W - 34.0, ROW_H, 11)
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.flat = true
		row.pressed.connect(_open.bind(id))
		_list.add_child(row)


func _refresh_keys() -> void:
	for old in _keylist.get_children():
		_keylist.remove_child(old)
		old.queue_free()
	var keys := _keys()
	for i in keys.size():
		var key: Dictionary = keys[i]
		var eye := SkyGearCutscene.to_vector(key.eye)
		var row := _chip("%d   %.2fs   %s%s" % [i + 1, float(key.t), str(key.ease),
			"  PIN" if str(key.get("from", "")) == "gameplay" else ""],
			LIST_W - 34.0, ROW_H, 11)
		row.tooltip_text = "eye %.0f %.0f %.0f" % [eye.x, eye.y, eye.z]
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.flat = true
		row.pressed.connect(_pick_key.bind(i))
		_keylist.add_child(row)
	if _track != null:
		_track.queue_redraw()


func _pick_key(which: int) -> void:
	_selected = which
	var key := _key()
	if not key.is_empty():
		## Selecting a key GOES to it. A selection that leaves the camera
		## somewhere else means the next drag edits a frame you are not looking at,
		## which is the single most confusing thing a timeline can do.
		_time = float(key.t)
		_playing = false
	_show()


func _open(id: String) -> void:
	var scene := SkyGearCutscene.load_scene(id)
	if scene.is_empty():
		_note = "could not read %s" % SkyGearCutscene.path_for(id)
		_show()
		return
	_scene = scene
	_id = id
	_name_edit.text = id
	_selected = 0
	_time = 0.0
	_playing = false
	_dirty = false
	_note = ""
	_refresh_keys()
	_show()


func _new() -> void:
	var id := "shot_1"
	var n := 1
	while _ids.has(id):
		n += 1
		id = "shot_%d" % n
	_scene = SkyGearCutscene.blank(id)
	_id = id
	_name_edit.text = id
	_selected = 0
	_time = 0.0
	_playing = false
	_dirty = true
	_note = "a new shot, framed on the gameplay camera. Move it and keys appear."
	_refresh_keys()
	_show()


func _save() -> void:
	var id := _name_edit.text.strip_edges().to_lower().replace(" ", "_")
	if id == "":
		_note = "give it a name first — the box above NEW."
		return
	_scene["id"] = id
	_scene["name"] = id.replace("_", " ").to_upper()
	if not SkyGearCutscene.save_scene(id, _scene):
		_note = "could not write %s" % SkyGearCutscene.path_for(id)
		return
	_id = id
	_dirty = false
	_ids = SkyGearCutscene.list_ids()
	_refresh_list()
	var cue := str(_scene.get("cue", ""))
	_note = "written to %s — %s" % [SkyGearCutscene.path_for(id),
		("the game plays it at `%s`" % cue) if cue != ""
			else "NOTHING PLAYS IT YET: set a CUE on the right"]
	print(_note)


func _delete() -> void:
	if _id == "" or not SkyGearCutscene.delete_scene(_id):
		_note = "nothing on disk to delete."
		_show()
		return
	_ids = SkyGearCutscene.list_ids()
	_refresh_list()
	_note = "deleted %s" % _id
	if _ids.is_empty():
		_new()
	else:
		_open(_ids[0])


# -------------------------------------------------------------------- display --

## The camera, written AFTER the renderer wrote its own. See the note on `Hands`.
func after_frame(delta: float) -> void:
	if _playing:
		var total := SkyGearCutscene.length(_scene)
		_time += delta * _speed
		if _time >= total:
			if _loop:
				_time = fmod(_time, maxf(0.0001, total))
			else:
				_time = total
				_playing = false
		_show()
	if _cam == null and _view != null:
		_cam = _view.camera
	if _cam == null or _scene.is_empty():
		return
	var shot := SkyGearCutscene.sample(_bound(), _time)
	var roll := 0.0
	var yaw := 0.0
	## The same two numbers the runtime adds, from the same place, so a shot
	## framed with the sway on is framed against the sway the game will apply.
	if _sway and bool(_scene.get("sway", true)):
		roll = SkyGearView3D.SWAY_ROLL * _view._roll
		yaw = SkyGearView3D.SWAY_YAW * _view._yaw
	SkyGearCutscene.aim(_cam, shot, roll, yaw)


func _show() -> void:
	var total := SkyGearCutscene.length(_scene)
	var shot := SkyGearCutscene.sample(_bound(), _time)
	var key := _key()
	## The letterbox, exactly where the runtime will put it. Anchored rather than
	## sized, so it is right at whatever resolution the tool happened to open at.
	var bars := clampf(float(_scene.get("letterbox", 0.12)), 0.0, 0.3)
	if _bar_top != null:
		_bar_top.anchor_bottom = bars
		_bar_bottom.anchor_top = 1.0 - bars
	var lines: Array[String] = []
	lines.append("%s%s        %d keyframes        %.2f s long"
		% [_id.to_upper() if _id != "" else "UNTITLED", "  ·  UNSAVED" if _dirty else "",
			_keys().size(), total])
	## THE LIVE READOUT. A shot you cannot read the numbers off is a shot you
	## cannot reproduce, reason about or describe to anybody — and every other
	## spatial number in this project is quoted in ground units, so these are too.
	lines.append("camera %.0f, %.0f, %.0f     aimed at %.0f, %.0f, %.0f     lens %.1f deg     roll %+.1f"
		% [shot.eye.x, shot.eye.y, shot.eye.z, shot.look.x, shot.look.y, shot.look.z,
			shot.fov, shot.roll])
	lines.append("ground units, the deck is 1680 across and 2320 bow to stern - drag to orbit, right-drag to slide, wheel to push in")
	var cue := str(_scene.get("cue", ""))
	lines.append("plays at:  %s" % (SkyGearCutscene.CUES[cue] if SkyGearCutscene.CUES.has(cue)
		else "nothing yet — pick a CUE on the right, or this file is never read"))
	if _note != "":
		lines.append(_note)
	_label.text = "\n".join(lines)

	if not key.is_empty():
		var eye := SkyGearCutscene.to_vector(key.eye)
		var look := SkyGearCutscene.to_vector(key.look)
		for pair in [["ex", "%+.0f" % eye.x], ["ey", "%+.0f" % eye.y], ["ez", "%+.0f" % eye.z],
				["lx", "%+.0f" % look.x], ["ly", "%+.0f" % look.y], ["lz", "%+.0f" % look.z],
				["fov", "%.1f" % float(key.fov)], ["roll", "%+.1f" % float(key.roll)],
				["t", "%.2f s" % float(key.t)], ["ease", str(key.ease)]]:
			var value: Label = _row_value.get(str(pair[0]))
			if value != null:
				value.text = str(pair[1])
		var what: Label = _row_value.get("easewhat")
		if what != null:
			what.text = "KEY %d of %d%s      how it LEAVES this key" % [_selected + 1,
				_keys().size(),
				"  ·  PINNED to the gameplay camera" if str(key.get("from", "")) == "gameplay"
					else ""]
	for pair in [["wave", str(int(_scene.get("wave", 0))) if int(_scene.get("wave", 0)) > 0 else "any"],
			["letterbox", "%.0f%%" % (float(_scene.get("letterbox", 0.12)) * 100.0)]]:
		var value: Label = _row_value.get(str(pair[0]))
		if value != null:
			value.text = str(pair[1])

	_scrubbing = true
	_scrub.set_value_no_signal(clampf(_time / maxf(0.0001, total), 0.0, 1.0))
	_scrubbing = false
	_scrub_label.text = "%.2f / %.2f s      frame %d of %d      %.2fx" % [
		_time, total, int(round(_time / FRAME)), int(round(total / FRAME)), _speed]

	_refresh_toggles()
	if _track != null:
		_track.queue_redraw()


func _refresh_toggles() -> void:
	for pair in [["sway", _sway], ["autokey", _autokey], ["loop", _loop],
			["hold", bool(_scene.get("hold", true))],
			["hide_hud", bool(_scene.get("hide_hud", true))]]:
		var b: Button = _btn.get(str(pair[0]))
		if b != null:
			b.add_theme_color_override("font_color",
				Color("#37f0c8") if bool(pair[1]) else Color("#b9afaa"))
	var sway_btn: Button = _btn.get("sway")
	if sway_btn != null:
		## Two toggles named SWAY would be a trap: this one is what the TOOL is
		## showing you right now, and the one on the right is what the game will
		## do. Both exist because a shot framed under a moving camera is a shot
		## you cannot line up, and a shot never seen moving is a shot that surprises
		## you in the build.
		sway_btn.text = "SHIP SWAY (preview)"
	var cue_btn: Button = _btn.get("cue")
	if cue_btn != null:
		var cue := str(_scene.get("cue", ""))
		cue_btn.text = "CUE  %s" % (cue if cue != "" else "— none —")
		cue_btn.add_theme_color_override("font_color",
			Color("#37f0c8") if cue != "" else Color("#c88b7a"))
	var play_btn: Button = _btn.get("play")
	if play_btn != null:
		play_btn.text = "PAUSE" if _playing else "PLAY"
	for preset in SPEEDS:
		var b: Button = _btn.get("s" + str(preset[1]))
		if b != null:
			b.add_theme_color_override("font_color",
				Color("#37f0c8") if is_equal_approx(_speed, float(preset[0]))
					else Color("#b9afaa"))
	for i in _keylist.get_child_count():
		var row := _keylist.get_child(i) as Button
		row.add_theme_color_override("font_color",
			Color("#37f0c8") if i == _selected else Color("#b9afaa"))
	for i in _list.get_child_count():
		var row := _list.get_child(i) as Button
		row.add_theme_color_override("font_color",
			Color("#37f0c8") if i < _ids.size() and _ids[i] == _id else Color("#b9afaa"))


# --------------------------------------------------------------------- input --

func hand(event: InputEvent) -> void:
	if event is InputEventKey:
		_shift = (event as InputEventKey).shift_pressed
		_key_press(event as InputEventKey)
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		_shift = mb.shift_pressed
		## Never over the panels or the timeline, or dragging a slider orbits the
		## camera underneath it.
		if mb.position.x < LIST_W + 16.0 or mb.position.x > _w - LIST_W - 16.0:
			return
		if _timeline != null and mb.position.y > _timeline.position.y - 6.0:
			return
		if mb.position.y < 132.0:
			return
		match mb.button_index:
			MOUSE_BUTTON_LEFT: _dragging = 1 if mb.pressed else 0
			MOUSE_BUTTON_RIGHT: _dragging = 2 if mb.pressed else 0
			MOUSE_BUTTON_WHEEL_UP: _wheel(-1.0)
			MOUSE_BUTTON_WHEEL_DOWN: _wheel(1.0)
		return
	if event is InputEventMouseMotion and (_dragging == 1 or _dragging == 2):
		_drag((event as InputEventMouseMotion).relative)


## In and out along the view axis, which is what a wheel means everywhere else.
## The AIM point does not move, so pushing in tightens on whatever the shot is
## about rather than sliding off it.
func _wheel(notches: float) -> void:
	var key := _edit_target()
	if key.is_empty():
		return
	_unpin(key)
	var eye := SkyGearCutscene.to_vector(key.eye)
	var look := SkyGearCutscene.to_vector(key.look)
	var axis := eye - look
	var reach: float = maxf(30.0, axis.length())
	axis = axis.normalized() if axis.length() > 0.001 else Vector3(0.0, 0.6, 0.8).normalized()
	reach = clampf(reach * (WHEEL_DOLLY if notches > 0.0 else 1.0 / WHEEL_DOLLY), 40.0, 9000.0)
	eye = look + axis * reach
	key["eye"] = [eye.x, eye.y, eye.z]
	_dirty = true
	_show()


func _drag(by: Vector2) -> void:
	var key := _edit_target()
	if key.is_empty():
		return
	_unpin(key)
	var eye := SkyGearCutscene.to_vector(key.eye)
	var look := SkyGearCutscene.to_vector(key.look)
	if _dragging == 2:
		## SLIDE. Both ends together, across the deck, in the directions the
		## screen is showing — so dragging right moves the shot right whatever way
		## the camera happens to be facing.
		var forward := (look - eye)
		forward.y = 0.0
		if forward.length() < 0.001:
			forward = Vector3(0.0, 0.0, -1.0)
		forward = forward.normalized()
		var side := Vector3(-forward.z, 0.0, forward.x)
		var move: Vector3 = side * (-by.x * DRAG_PAN) + forward * (-by.y * DRAG_PAN)
		if _shift:
			## Shift lifts instead, because "up" is the one direction a flat drag
			## cannot mean and the one a shot most often needs.
			move = Vector3(0.0, -by.y * DRAG_PAN, 0.0)
		eye += move
		look += move
	else:
		## ORBIT around the aim point. Spherical, so the distance the shot was
		## framed at survives being turned around.
		var offset := eye - look
		var reach: float = maxf(30.0, offset.length())
		var yaw := atan2(offset.x, offset.z)
		var pitch := asin(clampf(offset.y / reach, -1.0, 1.0))
		yaw -= by.x * DRAG_ORBIT
		## Never quite straight up or down: a look-at through the pole flips the
		## horizon over, and a camera that rolls 180 degrees when you drag one
		## pixel too far is a camera nobody can aim.
		pitch = clampf(pitch + by.y * DRAG_ORBIT, deg_to_rad(-80.0), deg_to_rad(85.0))
		offset = Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * reach
		eye = look + offset
	key["eye"] = [eye.x, eye.y, eye.z]
	key["look"] = [look.x, look.y, look.z]
	_dirty = true
	_show()


## Keys, every one of them optional. SPACE play/pause, `,` `.` one frame either
## way, `[` `]` previous / next keyframe, ENTER save, ESC quit.
func _key_press(event: InputEventKey) -> void:
	if not event.pressed or event.echo:
		return
	## The name box has the keyboard while it is being typed in, and a tool that
	## quits when you type an `e` into a filename is a tool that loses work.
	if _name_edit != null and _name_edit.has_focus():
		return
	match event.keycode:
		KEY_ESCAPE:
			quit(0)
		KEY_SPACE:
			_press("play")
		KEY_COMMA:
			_press("back")
		KEY_PERIOD:
			_press("forward")
		KEY_BRACKETLEFT:
			_pick_key(wrapi(_selected - 1, 0, maxi(1, _keys().size())))
		KEY_BRACKETRIGHT:
			_pick_key(wrapi(_selected + 1, 0, maxi(1, _keys().size())))
		KEY_ENTER, KEY_KP_ENTER:
			_press("save")
