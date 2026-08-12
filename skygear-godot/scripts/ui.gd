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

## Emitted through a plain callback rather than a signal: this is a RefCounted
## helper owned by the HUD, and a signal would need a lifetime.
var on_sound: Callable = Callable()

## WHERE A WIDGET'S WORDS GO TO BE DRAWN.
##
## This layer used to call `draw_string` itself, which made it a second answer to
## a question the HUD had already answered once: how big is the smallest text we
## allow, how is a glyph separated from the plate behind it, and where does the
## legibility audit find out what was drawn. Two answers to one question is the
## bug that has bitten this project three times.
##
## So the HUD hands over its funnel and every button label, row value, slider
## readout and key hint goes through it — which is also the only reason the audit
## can see them at all. Falls back to a plain draw if nobody set it, because a
## widget that vanishes when a callback is missing is worse than an unmeasured
## one.
var scribe: Callable = Callable()

## WHICH PLATE IS OPEN RIGHT NOW.
##
## Asked rather than told, because a screen opens and closes several plates
## while it draws and a value handed over at `begin` would be the wrong one by
## the third panel.
##
## Two levels, and they are different bugs. A label belongs to its WIDGET — a
## button whose text runs off its own edge is a clipped button. A widget belongs
## to the PLATE — four pause buttons hanging off the left edge of their sheet is
## a layout laid out from the wrong x, which is exactly what they were, and the
## first version of this measured the labels against nothing at all and reported
## sixteen screens clean while it was happening.
var plate: Callable = Callable()

## THE SCREEN EDITOR'S HOOK (SG-42). `(name, rect) -> Rect2`, called once per
## widget with the widget's label before anything is drawn or declared, so a
## saved per-screen offset moves the widget AND its hit test AND its label in
## one step — the label is positioned from the rect, and `_declare` records the
## rect input is tested against. Unset (the normal game with no offsets saved),
## it costs one `is_valid()` per widget and changes nothing.
var adjust: Callable = Callable()

## THE MENU VOCABULARY'S HOOK (SG-93 / S2). `(rect, state) -> void`, called in
## place of this file's own fill-and-outline so a widget is drawn in the same
## hardware the title screen is bolted together from. `state` carries
## `disabled`, `primary` and `lit`; everything else — the palette, the bevel,
## the rivets, the engraved channel — belongs to `hud.gd` and stays there.
##
## Deliberately NOT the full `_menu_plate`: that function also owns the label,
## the key hint and the F4 adjustment, all three of which this file already
## does. Chrome only, so there is exactly one implementation of each job.
var chrome: Callable = Callable()


func _adjusted(name: String, rect: Rect2) -> Rect2:
	if adjust.is_valid():
		return adjust.call(name, rect)
	return rect


## THE WIDGET HALF OF THE TEXT AUDIT'S MATH, shared. `tools/text_audit.gd`
## consumes this and so does the F4 editor's verdict line — one function, so the
## editor cannot disagree with the audit about what "colliding" means (two
## answers to one question is the failure mode that has bitten this project
## three times). `items` is what `declared()` returns. Two kinds come back:
##   COLLIDE  two widgets share pixels (`grow(-1)` so a shared border is not a hit)
##   WIDGET   a framed widget sits outside the plate it was declared on
static func collisions(items: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for a in items.size():
		for b in range(a + 1, items.size()):
			var ra: Rect2 = items[a].rect
			var rb: Rect2 = items[b].rect
			if not ra.grow(-1.0).intersects(rb.grow(-1.0)):
				continue
			out.append({"kind": "COLLIDE", "text": "two widgets share pixels",
				"box": ra, "frame": rb, "measured": 0.0, "given": 0.0})
		var item: Dictionary = items[a]
		if not bool(item.get("framed", false)):
			continue
		var box: Rect2 = item.rect
		var plate_rect: Rect2 = item.frame
		if plate_rect.encloses(box.grow(-0.5)):
			continue
		out.append({"kind": "WIDGET",
			"text": "widget %d of %d sits on the frame" % [a, items.size()],
			"box": box, "frame": plate_rect, "measured": 0.0, "given": 0.0})
	return out


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


## Every widget rectangle, tagged with the plate that was open when it was
## declared. Kept here rather than recomputed by the audit, because "the plate
## that was open at the time" is a fact about the frame that drew it and cannot
## be reconstructed afterwards from a list of rectangles.
func _declare(rect: Rect2, extra: Dictionary = {}) -> void:
	var item := {"rect": rect, "disabled": false, "framed": false,
		"frame": Rect2()}
	item.merge(extra, true)
	if plate.is_valid():
		var open: Dictionary = plate.call()
		item["framed"] = bool(open.open)
		item["frame"] = open.rect as Rect2
	_items.append(item)


## The label belongs to the widget, so that is the frame it is measured against.
func _text(owner: Rect2, at: Vector2, s: String, align: int, width: float,
		pt: int, tint: Color) -> void:
	if scribe.is_valid():
		scribe.call(owner, s, at, width, align, pt, tint)
	else:
		SkyGearInk.write(_canvas, _font, at, s, align, width, pt, tint)


## IS THE WIDGET AT THIS INDEX LIT — under the mouse, or holding the keyboard
## focus? Only `bare` widgets need to ask; every other widget draws its own
## highlight and never has to know.
##
## Indexed the same way the Workshop already indexes: the caller takes
## `declared().size()` before the call, which is the index the widget is about to
## occupy, and asks with it afterwards. That is the one pairing in this layer
## that cannot drift, because both numbers come from the same list.
func lit(index: int) -> bool:
	if index < 0 or index >= _items.size():
		return false
	var item: Dictionary = _items[index]
	if bool(item.get("disabled", false)):
		return false
	if _keyboard and focused() == index:
		return true
	return (item.rect as Rect2).has_point(_mouse)


## A button. Returns true on the frame it is activated, by click or by key.
##
## `bare` draws NOTHING and does everything else — declares the rectangle, takes
## the hover, moves the focus, plays the sounds, fires on click and on Enter. It
## exists for the Workshop, where a "button" is a brass fitting with a rim
## colour, a row of rank rivets and a pipe running into it, and painting a plain
## panel underneath all of that would only be something to cover up. The
## alternative — an ad-hoc `Rect2.has_point()` test written where it is drawn —
## is precisely the thing this file was written to end, and it is why this is a
## flag here rather than a hand-rolled hit test over there. `declared()` still
## sees every one of them, so the audit's COLLIDE and WIDGET passes are unchanged.
func button(rect: Rect2, label: String, opts: Dictionary = {}) -> bool:
	## Adjusted before declaration unless a wrapper (row/choice) already did it
	## with a better name than an empty delegate label.
	if not bool(opts.get("adjusted", false)):
		rect = _adjusted(str(opts.get("key", label)), rect)
	var index := _index
	_index += 1
	var disabled: bool = bool(opts.get("disabled", false))
	var primary: bool = bool(opts.get("primary", false))
	var bare: bool = bool(opts.get("bare", false))
	var hint: String = str(opts.get("hint", ""))
	_declare(rect, {"disabled": disabled})

	var hot: bool = not disabled and rect.has_point(_mouse)
	if hot and _hovered != index:
		_hovered = index
		_focus[_screen] = index
		_beep("hover")
	var shown: bool = (_keyboard and focused() == index) or hot
	if bare:
		if disabled:
			return false
		if _activate and focused() == index:
			_activate = false
			_beep("click")
			return true
		return false

	## SG-93 / S2 · THE MENU VOCABULARY REACHES EVERY WIDGET, IN ONE PLACE.
	##
	## What was here was a filled rectangle and a 1.4px outline — the "hairline
	## rectangle" the UI/UX audit named, and the reason SETTINGS, HOW TO PLAY,
	## CONTROLS and PAUSE looked like they came from a different game than the
	## title. SG-91 built the answer (`_menu_plate`: shadow, body, bevel, brass
	## surround, rivets, engraved channel) and MENU-DESIGN §5 costs spreading it
	## as "a call swap per row".
	##
	## IT IS ONE SWAP, NOT PER ROW, AND THAT IS THE POINT. The chrome is a
	## callback the HUD supplies — the same shape as `scribe`, `plate` and
	## `adjust` — so the vocabulary keeps living in `hud.gd` beside `_bevel`,
	## `_rivet` and the palette, and EVERY widget in the game picks it up at
	## once: the four sheets, the results buttons, the Workshop, the Berths.
	## Geometry is untouched, so no measured layout moves and the containment
	## audit has nothing new to say.
	##
	## An unset `chrome` keeps the old rectangle exactly, which is what the
	## harness's own bare `SkyGearUI` fixtures draw with.
	if chrome.is_valid():
		chrome.call(rect, {"disabled": disabled, "primary": primary,
			"lit": shown})
	else:
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
	_text(rect, rect.position + Vector2(0, rect.size.y * 0.5 + 6.0), label,
		HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 18, tint)
	if hint != "":
		## 44, because "Alt+F4" at the smallest size the game is allowed to draw
		## is 37 and this box was 34. It used to fit at 11pt, which is the size at
		## which nobody read it.
		##
		## And BRASS_LIT rather than BRASS: the audit measured the key hints at
		## 1.02 against the housing they are painted on, which is brass text on
		## brass and the lowest contrast anywhere in the game. A hint is meant to
		## be quiet, not absent.
		_text(rect, Vector2(rect.end.x - 48.0, rect.position.y + 17.0), hint,
			HORIZONTAL_ALIGNMENT_RIGHT, 44, 12, DIM if disabled else BRASS_LIT)

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
	## The row adjusts under ITS label — the delegate button's label is empty,
	## and an element key made from "" is a key made from draw order alone.
	rect = _adjusted(label, rect)
	opts = opts.duplicate()
	opts["adjusted"] = true
	var index := _index
	var fired := button(rect, "", opts)
	var shown: bool = (_keyboard and focused() == index) or rect.has_point(_mouse)
	var tint: Color = DIM if bool(opts.get("disabled", false)) else BONE
	## The hint owns the right edge when there is one, so the value steps left of
	## it rather than printing on top of it.
	var reserved: float = 14.0 + (48.0 if str(opts.get("hint", "")) != "" else 0.0)
	_text(rect, rect.position + Vector2(14, rect.size.y * 0.5 + 6.0), label,
		HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 28.0 - reserved, 16, tint)
	_text(rect, rect.position + Vector2(-reserved, rect.size.y * 0.5 + 6.0), value,
		HORIZONTAL_ALIGNMENT_RIGHT, rect.size.x, 16, BRASS_LIT if shown else BRASS)
	return fired


## A 0..1 slider. Returns the new value, or the old one if nothing happened.
## Adjusted with left/right when focused, or by clicking along the track.
func slider(rect: Rect2, label: String, value: float, opts: Dictionary = {}) -> float:
	rect = _adjusted(label, rect)
	var index := _index
	_index += 1
	_declare(rect, {"slider": true})
	var shown: bool = (_keyboard and focused() == index) or rect.has_point(_mouse)
	if rect.has_point(_mouse) and _hovered != index:
		_hovered = index
		_focus[_screen] = index
		_beep("hover")

	var track := Rect2(rect.position.x + 150.0, rect.get_center().y - 5.0,
		rect.size.x - 210.0, 10.0)
	_text(rect, rect.position + Vector2(14, rect.size.y * 0.5 + 6.0), label,
		HORIZONTAL_ALIGNMENT_LEFT, 140, 16, BONE)
	_canvas.draw_rect(track, Color(0.04, 0.03, 0.06, 0.9))
	_canvas.draw_rect(Rect2(track.position, Vector2(track.size.x * clampf(value, 0.0, 1.0),
		track.size.y)), TEAL if shown else Color("#1c6f61"))
	_canvas.draw_rect(track, BRASS_LIT if shown else BRASS, false, 1.4)
	_text(rect, Vector2(rect.end.x - 58.0, rect.size.y * 0.5 + rect.position.y + 6.0),
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
