class_name SkyGearUI
extends RefCounted

## Buttons that behave like buttons.
##
## Every clickable thing in this port is an ad-hoc `Rect2.has_point()` test
## written where it is drawn: the draft cards, the reroll, the rebind rows. None
## of them can be reached from the keyboard, none of them has a disabled state,
## none of them makes a sound, and none of them shows you what is selected. That
## is survivable for three cards and it is why the port has no settings screen,
## no pause menu you can quit from, and a results screen where Play Again is two
## screens away.
##
## The browser build solved this once in `_render_ui.js` and everything else
## there is built on it. This is the same idea in the same shape.
##
## IMMEDIATE MODE, with retained focus. A screen declares its widgets every
## frame in draw order; the widget call draws and returns whether it fired. What
## persists between frames is only the focus index, per screen, and the list of
## rectangles that input is tested against — because input arrives in a
## different callback from drawing, and testing against the list the player
## actually saw is the only way a click cannot land on a button that moved.
##
## The focus ring is hidden until a key is pressed, and hidden again the moment
## the mouse moves. Nothing is worse than a keyboard highlight following a
## player who is using a mouse.

const PANEL := Color(0.078, 0.070, 0.106, 0.95)
const BRASS := Color("#b0813f")
const BRASS_LIT := Color("#e8c376")
const BONE := Color("#eee5d5")
const TEAL := Color("#37f0c8")
const DIM := Color("#5f5863")
const INK := Color(0.03, 0.02, 0.045, 0.9)

## Emitted through a plain callback rather than a signal: this is a RefCounted
## helper owned by the HUD, and a signal would need a lifetime.
var on_sound: Callable = Callable()

var _focus: Dictionary = {}          ## screen -> focused index
var _screen := ""
var _index := 0
var _items: Array[Dictionary] = []   ## this frame
var _live: Array[Dictionary] = []    ## last frame, what input is tested against
var _canvas: CanvasItem
var _font: Font
var _mouse := Vector2.ZERO
var _keyboard := false               ## show the focus ring?
var _activate := false               ## a fire is pending, consumed by the next widget pass
var _hovered := -1


## Start a screen. Everything until the next `begin` belongs to it.
func begin(screen: String, canvas: CanvasItem, font: Font, mouse: Vector2) -> void:
	## The list input is tested against is LAST frame's, swapped in here — the
	## one the player was looking at when they clicked.
	_live = _items.duplicate()
	_items = []
	_screen = screen
	_index = 0
	_canvas = canvas
	_font = font
	if mouse.distance_to(_mouse) > 2.0:
		_keyboard = false
		_hovered = -1
	_mouse = mouse
	if not _focus.has(screen):
		_focus[screen] = 0


## Every rectangle declared this frame, for the audit. Two widgets on the same
## pixels is a bug the text audit cannot see — it measures a string against the
## frame it is IN, and two overlapping buttons each contain their own label
## perfectly well. Adding the Heat picker put three rows on top of each other on
## the title screen and every check passed.
func declared() -> Array[Dictionary]:
	return _items.duplicate()


func focused() -> int:
	return int(_focus.get(_screen, 0))


## A button. Returns true on the frame it is activated, by click or by key.
func button(rect: Rect2, label: String, opts: Dictionary = {}) -> bool:
	var index := _index
	_index += 1
	var disabled: bool = bool(opts.get("disabled", false))
	var primary: bool = bool(opts.get("primary", false))
	var hint: String = str(opts.get("hint", ""))
	_items.append({"rect": rect, "disabled": disabled})

	var hot: bool = not disabled and rect.has_point(_mouse)
	if hot and _hovered != index:
		_hovered = index
		_focus[_screen] = index
		_beep("hover")
	var shown: bool = (_keyboard and focused() == index) or hot

	var fill: Color = PANEL
	if disabled:
		fill = Color(0.06, 0.05, 0.08, 0.85)
	elif shown:
		fill = Color(TEAL.r, TEAL.g, TEAL.b, 0.16) if primary \
			else Color(BRASS.r, BRASS.g, BRASS.b, 0.20)
	elif primary:
		fill = Color(TEAL.r, TEAL.g, TEAL.b, 0.09)
	_canvas.draw_rect(rect, fill)
	var edge: Color = DIM if disabled else (TEAL if primary else BRASS)
	if shown:
		edge = TEAL if primary else BRASS_LIT
	_canvas.draw_rect(rect, edge, false, 2.0 if shown else 1.4)

	var tint: Color = DIM if disabled else (TEAL if primary else BONE)
	_canvas.draw_string(_font, rect.position + Vector2(1, rect.size.y * 0.5 + 7.0),
		label, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 18, INK)
	_canvas.draw_string(_font, rect.position + Vector2(0, rect.size.y * 0.5 + 6.0),
		label, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 18, tint)
	if hint != "":
		_canvas.draw_string(_font, Vector2(rect.end.x - 40.0, rect.position.y + 16.0),
			hint, HORIZONTAL_ALIGNMENT_RIGHT, 34, 11, DIM if disabled else BRASS)

	if disabled:
		return false
	if _activate and focused() == index:
		_activate = false
		_beep("click")
		return true
	return false


## A left-aligned row that behaves like a button — for lists of settings or
## bindings, where a centred label would read as a title.
func row(rect: Rect2, label: String, value: String, opts: Dictionary = {}) -> bool:
	var index := _index
	var fired := button(rect, "", opts)
	var shown: bool = (_keyboard and focused() == index) or rect.has_point(_mouse)
	var tint: Color = DIM if bool(opts.get("disabled", false)) else BONE
	## The hint owns the right edge when there is one, so the value steps left of
	## it rather than printing on top of it.
	var reserved: float = 14.0 + (34.0 if str(opts.get("hint", "")) != "" else 0.0)
	_canvas.draw_string(_font, rect.position + Vector2(14, rect.size.y * 0.5 + 6.0),
		label, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 28.0 - reserved, 16, tint)
	_canvas.draw_string(_font, rect.position + Vector2(-reserved, rect.size.y * 0.5 + 6.0),
		value, HORIZONTAL_ALIGNMENT_RIGHT, rect.size.x, 16,
		BRASS_LIT if shown else BRASS)
	return fired


## A 0..1 slider. Returns the new value, or the old one if nothing happened.
## Adjusted with left/right when focused, or by clicking along the track.
func slider(rect: Rect2, label: String, value: float, opts: Dictionary = {}) -> float:
	var index := _index
	_index += 1
	_items.append({"rect": rect, "disabled": false, "slider": true})
	var shown: bool = (_keyboard and focused() == index) or rect.has_point(_mouse)
	if rect.has_point(_mouse) and _hovered != index:
		_hovered = index
		_focus[_screen] = index
		_beep("hover")

	var track := Rect2(rect.position.x + 150.0, rect.get_center().y - 5.0,
		rect.size.x - 210.0, 10.0)
	_canvas.draw_string(_font, rect.position + Vector2(14, rect.size.y * 0.5 + 6.0),
		label, HORIZONTAL_ALIGNMENT_LEFT, 140, 16, BONE)
	_canvas.draw_rect(track, Color(0.04, 0.03, 0.06, 0.9))
	_canvas.draw_rect(Rect2(track.position, Vector2(track.size.x * clampf(value, 0.0, 1.0),
		track.size.y)), TEAL if shown else Color("#1c6f61"))
	_canvas.draw_rect(track, BRASS_LIT if shown else BRASS, false, 1.4)
	_canvas.draw_string(_font, Vector2(rect.end.x - 58.0, rect.size.y * 0.5 + rect.position.y + 6.0),
		"%d%%" % roundi(value * 100.0), HORIZONTAL_ALIGNMENT_RIGHT, 50, 16, BONE)

	var out := value
	if focused() == index and _nudge != 0:
		out = clampf(value + 0.05 * float(_nudge), 0.0, 1.0)
		_nudge = 0
		_beep("click")
	if _activate and focused() == index and track.grow(8.0).has_point(_mouse):
		out = clampf((_mouse.x - track.position.x) / maxf(1.0, track.size.x), 0.0, 1.0)
		_activate = false
		_beep("click")
	return out


## An A / B / C choice that cycles. Returns the new index.
func choice(rect: Rect2, label: String, options: Array, at: int) -> int:
	var index := _index
	var fired := row(rect, label, str(options[clampi(at, 0, options.size() - 1)]))
	var out := at
	if fired:
		out = (at + 1) % options.size()
	elif focused() == index and _nudge != 0:
		out = wrapi(at + _nudge, 0, options.size())
		_nudge = 0
		_beep("click")
	return out


var _nudge := 0


## Feed input in. Returns whether it was consumed, so the caller can stop.
##
## Focus only becomes visible once a key is used — a keyboard highlight chasing
## a player who is using a mouse is worse than no highlight at all.
func handle(event: InputEvent) -> bool:
	var count := _live.size()
	if count == 0:
		return false
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		for i in count:
			var item: Dictionary = _live[i]
			if bool(item.disabled) or not (item.rect as Rect2).has_point(_mouse):
				continue
			_focus[_screen] = i
			_activate = true
			return true
		return false
	if event is not InputEventKey or not event.pressed:
		return false
	var key := event as InputEventKey
	match key.keycode:
		KEY_UP, KEY_W:
			_step(-1)
			return true
		KEY_DOWN, KEY_S:
			_step(1)
			return true
		KEY_TAB:
			_step(-1 if key.shift_pressed else 1)
			return true
		KEY_LEFT, KEY_A:
			_keyboard = true
			_nudge = -1
			return true
		KEY_RIGHT, KEY_D:
			_keyboard = true
			_nudge = 1
			return true
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			_keyboard = true
			_activate = true
			_beep("click")
			return true
	return false


## Move focus, skipping anything disabled, and wrapping. Wrapping matters: a
## focus that stops at the bottom of a five-item menu is a focus a player thinks
## has broken.
func _step(by: int) -> void:
	_keyboard = true
	var count := _live.size()
	if count == 0:
		return
	var at := focused()
	for _i in count:
		at = wrapi(at + by, 0, count)
		if not bool((_live[at] as Dictionary).get("disabled", false)):
			break
	_focus[_screen] = at
	_beep("hover")


func _beep(kind: String) -> void:
	if on_sound.is_valid():
		on_sound.call(kind)
