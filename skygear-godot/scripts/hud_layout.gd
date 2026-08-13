class_name SkyGearHudLayout
extends RefCounted

## Where every HUD plate sits, and where everything inside it sits, as data.
##
## The positions were constants, so moving one meant me editing a number,
## rebuilding, taking a screenshot, looking at it and doing it again. That is a
## turn per three pixels, and it is a loop I cannot close on my own because the
## answer is a matter of taste.
##
## The first version moved the six PLATES. That was not enough: the icons and
## bars inside them were still positioned by arithmetic, so a glyph could sit
## off-centre in its own slot and the only fix was another round trip. Now every
## drawn element is an entry here, and the editor drills into a plate to reach
## them.
##
## An offset is measured to the box's MATCHING edge: a `bottom_right` box keeps
## its bottom-right corner a fixed distance from the screen's bottom-right, and a
## `centre` box measures centre to centre. One rule for all nine anchors, so
## nothing has to be remembered per case.
##
## Everything is ANCHORED, never absolute. A plate hangs off a screen corner; an
## item hangs off a corner of its plate's interior. One hand-placed layout is
## then correct at 1280 and at 2560 — otherwise it is only right on the monitor
## it was placed on.

const USER_PATH := "user://hud_layout.json"
const SHIPPED_PATH := "res://assets/hud_layout.json"

## THE FILE THE EDITOR ACTUALLY READS AND WRITES. `USER_PATH` is where a
## player's alignment pass lives; `store` is the pointer every reader and writer
## goes through, so a TEST RUN can be sent somewhere else.
##
## It is a var for exactly one reason, and it is a bug the owner reported
## (SG-83): `tests/parity_test.gd` deleted `USER_PATH` six times a run and saved
## its own fixtures over it, so every `SkyGear Tools.bat harness` on this
## machine silently destroyed whatever the owner had just aligned by hand and
## saved with Ctrl+S. The save worked perfectly; the next harness run wiped it.
## The precedent is written a few lines up the same file — "a harness that
## depends on a save file is not a harness" — and SG-49, where posed endings
## wrote fake rows into the player's own run log. A tool must never reach into
## `user://` and destroy real player data, so the harness now points this at a
## scratch file and the real one is asserted untouched.
static var store := USER_PATH

## A full three by three. Used for plates against the screen and for items
## against their plate, because the resolution is identical either way.
const ANCHORS := [
	"top_left", "top_centre", "top_right",
	"centre_left", "centre", "centre_right",
	"bottom_left", "bottom_centre", "bottom_right",
]

## How much of a plate is painted frame rather than usable interior. Items are
## anchored against the interior, so a plate that is resized keeps its contents
## inside the brass rather than across it.
const FRAME_FRACTION := 0.19
const FRAME_MIN := 10.0
const FRAME_MAX := 30.0

## The layout the game falls back to, and what Ctrl+R restores. In code as well
## as in the shipped file, so a corrupt or absent file can never leave a player
## with no HUD at all.
const DEFAULT := {
	## THE CAPTAIN'S STATION (docs/HUD-DESIGN.md §4). Two bays: the porthole on
	## the left, and the three readouts stacked to the right of it, each in a bay
	## it keeps whether or not it has anything to say.
	##
	## EVERY BOX IS ANCHORED top_left AND SIZED TO FIT THE NARROWEST PLATE THE
	## GAME DRAWS. That is deliberate, and it is what stopped the redesign moving
	## under itself: `hud_plates` hands the side plates whatever the hand leaves,
	## so at 1280 the captain is 352 wide rather than 380 — and `item()` clamps a
	## box that no longer fits by moving it LEFT, which would have slid the health
	## bar over the portrait on exactly the width the audit runs at. Laid out
	## against the 1280 interior (278 x 94) and given the spare 28 px at 1920 as
	## right margin, nothing ever moves. Anchoring the lower rows to `bottom_left`
	## instead — which is what they used to do — would have made a plate that
	## resizes shuffle three rows past each other.
	##
	## AND 146 IS THE HEIGHT CEILING, MEASURED, NOT CHOSEN. It was drafted at 168,
	## which is the height the design wants; the text audit found the health bar's
	## own name printed through the opening bid's bottom row at 1280x720
	## ("CAPTAIN" through "EMBER SENTRY"). The bid matrix runs to a FIXED
	## y = CARD_TOP + CARD_H + 6 = 600 at every window height, and its last row's
	## label box therefore ends at about 586 whatever the row count — so at 720
	## the plate's own head is what has to give way. The first captain string
	## sits at (720 - 24 - h) + min(54, 0.22h) + 8, which clears 586 for
	## h <= 151; 146 takes it with three pixels to spare rather than one.
	## AND 400 WIDE, WHERE IT WAS 380 (board SG-276). Nothing inside this plate
	## moved: `interior()` stopped handing out 22 px of painted brass on each side
	## as if it were usable, so the plate grew by exactly what it had been
	## borrowing. Laid out against the old interior, `health` (88 + 194 = 282) and
	## `vent_icon` (262 + 14 = 276) both ended past the corrected 272, and the
	## renderer's clamp would have answered by sliding the health bar left across
	## the portrait — on the one plate whose whole job is being read at a glance.
	##
	## AND 400 IS A CEILING, NOT A PREFERENCE. `problems()` is asked at 1366, where
	## the hand's leftmost well starts at 431 and this plate's left edge is pinned
	## at 24 — so anything past 407 overlaps the wells, and 440 duly did. 400 keeps
	## seven pixels of daylight there and still gives a 292 interior, which clears
	## the health bar's 282 by ten.
	"captain": {
		"anchor": "bottom_left", "offset": [24, -24], "size": [400, 146],
		"items": {
			## The porthole. It is the interior's full height less the chip line
			## reserved under it, which is why it is not square-to-the-plate.
			"portrait": {"anchor": "top_left", "offset": [0, 3], "size": [76, 76]},
			## The heavy gauge. Twice the height of the light one below it, and
			## that ratio is the hierarchy — see §3.3.
			"health": {"anchor": "top_left", "offset": [88, 0], "size": [194, 30]},
			## The instrument, bolted to the left end of the light gauge as its
			## cap. 26 rather than 40: it says roughly, the gauge says exactly.
			"dial": {"anchor": "top_left", "offset": [88, 40], "size": [22, 22]},
			## `pressure_label` is now the light GAUGE, not a label — the name it
			## carries is drawn inside it. The key is kept because a hand-placed
			## layout in `user://` refers to it.
			"pressure_label": {"anchor": "top_left", "offset": [120, 43], "size": [140, 16]},
			"vent_icon": {"anchor": "top_left", "offset": [262, 44], "size": [14, 14]},
			"dash_label": {"anchor": "top_left", "offset": [88, 67], "size": [46, 14]},
			## Six pixels after the word, not forty-four. They used to sit past the
			## end of PRESSURE on the row above and read as belonging to it.
			"dash_pips": {"anchor": "top_left", "offset": [140, 67], "size": [80, 14]},
		},
	},
	## THE OBJECTIVE, TOP CENTRE. It is the thing you lose by and it was in a
	## corner competing with three lane tracks. Top centre is where the browser
	## puts it and where an eye goes first — and it is a slim centred plate, so
	## it costs almost none of the deck the boarders arrive across, which is why
	## the rest of the HUD is still along the bottom.
	## 96 TALL, NOT 76, AND THE TWO READOUTS LIFTED OFF THE RAIL.
	##
	## `bottom_left` with a zero offset anchors to the plate's bottom EDGE, which
	## on a `_panel` is the painted brass rail — so WAVE and BOARDERS were both
	## printed across the casting, and with only 76 px of plate they were also
	## crowding the gauge above them. This is the most-looked-at object in the
	## game: it is the thing you lose by, and it was a four-way collision.
	##
	## 20 px more plate and a 16 px lift puts the gauge, the two readouts and the
	## rail in three bands that do not touch.
	## 118 TALL, AND THE ARITHMETIC IS THE POINT.
	##
	## `item()` places against `interior(plate_rect)` and CLAMPS to it, so the
	## plate's height minus twice its rail is the entire budget. At 76 that
	## budget was about 44 px and it was being asked to hold a 26 px gauge AND
	## two 20 px readouts — 66 px of content in 44 px of room, so the clamp piled
	## WAVE and BOARDERS straight on top of the BOILER gauge. The most-looked-at
	## object in the game, the thing you lose by, was a four-way collision.
	##
	## 118 leaves roughly 66 px of interior: 26 of gauge, 8 of air, 20 of
	## readout, and slack at both ends. Nothing here is a lift off an edge —
	## lifting was the first attempt and it made the pile-up worse, because a
	## negative offset in a too-small interior moves an item INTO its neighbour.
	## The plate grew instead.
	## 470 WIDE, WHERE IT WAS 420, AND THE SAME REASON AS THE CAPTAIN (SG-276).
	## The corrected interior of a 420 plate is 312, which the 340-wide BOILER
	## gauge does not fit inside — and WAVE (150) and BOARDERS (160) together are
	## 310 of it, so the two readouts the owner reported as "not clear and not well
	## aligned" would have been touching. At 470 the interior is 362: the gauge has
	## 22 px of margin and the readouts have 52 px of daylight between them.
	"objective": {
		"anchor": "top_centre", "offset": [0, 12], "size": [470, 118],
		"items": {
			"boiler": {"anchor": "top_centre", "offset": [0, 4], "size": [340, 26]},
			"wave": {"anchor": "bottom_left", "offset": [0, -2], "size": [150, 20]},
			"boarders": {"anchor": "bottom_right", "offset": [0, -2], "size": [160, 20]},
		},
	},
	## THE LANE READOUT, RE-AUTHORED (SG-276). Two separate faults, one report —
	## the owner's *"the enemy tracker in the three lanes is not aligned properly
	## at all"*:
	##
	##   * WIDTH. 350 corrects to a 242 interior against 268-wide rows, so PORT,
	##     CENTRE and STARBOARD hung off the left of their own panel and the
	##     boarder counts off the right. 400 gives 292, and the rows are 280. The
	##     ceiling is the captain's, mirrored: at 1366 the rightmost well ends at
	##     935 and this plate's right edge is pinned 24 from the frame.
	##   * HEIGHT, and this one was never the arithmetic's fault. The shipped file
	##     carried a hand-dragged 186-tall plate with its rows at y = 48/66/84,
	##     which left 48 px of dead brass ABOVE the three tracks and 4 px below —
	##     the rows sat low in a panel half again as tall as they needed. 150 tall
	##     gives an 84 px interior for 60 px of rows, and 12/34/56 centres them in
	##     it. `assets/hud_layout.json` is regenerated from this table, so the two
	##     stop disagreeing.
	"ship": {
		"anchor": "bottom_right", "offset": [-24, -24], "size": [400, 150],
		"items": {
			"lane0": {"anchor": "top_left", "offset": [0, 12], "size": [280, 16]},
			"lane1": {"anchor": "top_left", "offset": [0, 34], "size": [280, 16]},
			"lane2": {"anchor": "top_left", "offset": [0, 56], "size": [280, 16]},
		},
	},
	## Centre-relative, because that is what a centre anchor means: the offset is
	## to the plate's own centre, so four slots at -192/-64/+64/+192 are
	## symmetric about the middle of the screen by construction.
	"slot0": {"anchor": "bottom_centre", "offset": [-192, -24], "size": [120, 112]},
	"slot1": {"anchor": "bottom_centre", "offset": [-64, -24], "size": [120, 112]},
	"slot2": {"anchor": "bottom_centre", "offset": [64, -24], "size": [120, 112]},
	"slot3": {"anchor": "bottom_centre", "offset": [192, -24], "size": [120, 112]},
	## THE SECOND HAND's well (SG-26). Raised above the hand rather than fifth in
	## the row: extending the band rightward runs the shipped layout into the
	## ship plate at 1366, and the fifth hand is the one with no key — off the
	## row is what it IS. Drawn only when the Article grants a fifth slot; placed
	## always, so the layout matrix and `problems()` check it like any plate.
	"slot4": {"anchor": "bottom_centre", "offset": [128, -140], "size": [120, 112]},
}

## Every skill slot shares one set of item positions — four slots that disagree
## about where their glyph sits is four bugs, not four decisions. Stored once
## under `slot0` and applied to all four.
const SLOT_ITEMS := {
	"key": {"anchor": "top_centre", "offset": [0, -1], "size": [66, 14]},
	"icon": {"anchor": "centre", "offset": [0, 2], "size": [32, 32]},
	## 66, MATCHING `key` (SG-276). A slot is 120 wide, so its corrected interior is
	## 67.2 and a 74-wide nameplate was authored 7 px outside its own well — which
	## `problems()` would now say out loud and the renderer was silently clamping.
	## The two boxes on this plate that hold words are the same width now, which is
	## what they should always have been.
	"name": {"anchor": "bottom_centre", "offset": [0, 1], "size": [66, 13]},
}

const ORDER := ["objective", "captain", "slot0", "slot1", "slot2", "slot3",
	"slot4", "ship"]

## The one plate allowed above the halfway line, because it is the objective and
## it is deliberately slim. Everything else stays in the bottom band, which is
## the whole reason the HUD was moved there.
const TOP_ALLOWED := ["objective"]

var plates: Dictionary = {}
var slot_items: Dictionary = {}
## THE THIRD LEVEL (SG-42): per-screen, per-element offsets for everything that
## is NOT the gameplay HUD — the title rows, the draft cards' contents, the
## pause buttons, a workshop heading. `screen -> {element key -> entry}`.
##
## AN ENTRY IS ONE OF TWO SHAPES — SG-80 grew the second:
##
##     [dx, dy]                        an offset alone — SG-42's original
##     {"o": [dx, dy], "s": [dw, dh]}  offset AND size delta, either half
##                                     dropped when it is zero
##
## An offset-only edit still writes the array, so a file that predates sizes and
## a file that never uses one are the same file, byte for byte. The shape is
## chosen that way on purpose: the size delta is the rarer edit, and a schema
## change that rewrites every existing entry to say "and no size" is a migration
## nobody asked for.
##
## BOTH HALVES ARE RELATIVE TO THE ELEMENT'S COMPUTED HOME — the position and
## the size the drawing code was about to use — never absolute. That is what
## keeps a saved entry meaningful when the code-side layout changes: move the
## home and the offset follows it; widen the home and the size delta rides the
## new width. The same invariant the plate anchors carry. The element keys are
## made by `element_slug` from what the element says, so a readout whose NUMBER
## changes keeps its key.
var screens: Dictionary = {}


func _init() -> void:
	plates = DEFAULT.duplicate(true)
	slot_items = SLOT_ITEMS.duplicate(true)
	screens = {}


static func load_layout() -> SkyGearHudLayout:
	var out := SkyGearHudLayout.new()
	for path in [store, SHIPPED_PATH]:
		var raw := _read(path)
		if raw.is_empty():
			continue
		out.plates = _sanitise(raw.get("plates", {}))
		out.slot_items = _sanitise_items(raw.get("slot_items", {}), SLOT_ITEMS)
		out.screens = _sanitise_screens(raw.get("screens", {}))
		return out
	return out


static func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed if parsed is Dictionary else {}


## One entry, checked. Anything missing or malformed falls back, so a
## half-edited file loses one element rather than the whole HUD.
static func _entry(raw: Variant, fallback: Dictionary) -> Dictionary:
	if raw is not Dictionary:
		return fallback.duplicate(true)
	var anchor := str((raw as Dictionary).get("anchor", ""))
	var offset: Variant = (raw as Dictionary).get("offset")
	var size: Variant = (raw as Dictionary).get("size")
	if not anchor in ANCHORS or offset is not Array or size is not Array:
		return fallback.duplicate(true)
	if (offset as Array).size() != 2 or (size as Array).size() != 2:
		return fallback.duplicate(true)
	return {
		"anchor": anchor,
		"offset": [float(offset[0]), float(offset[1])],
		"size": [maxf(ELEMENT_MIN, float(size[0])), maxf(ELEMENT_MIN, float(size[1]))],
	}


static func _sanitise_items(raw: Variant, fallback: Dictionary) -> Dictionary:
	var out := {}
	for name in fallback.keys():
		out[name] = _entry((raw as Dictionary).get(name) if raw is Dictionary else null,
			fallback[name])
	return out


static func _sanitise(raw: Variant) -> Dictionary:
	var out := {}
	for name in DEFAULT.keys():
		var source: Variant = (raw as Dictionary).get(name) if raw is Dictionary else null
		var plate := _entry(source, DEFAULT[name])
		plate.size[0] = maxf(PLATE_MIN.x, float(plate.size[0]))
		plate.size[1] = maxf(PLATE_MIN.y, float(plate.size[1]))
		if (DEFAULT[name] as Dictionary).has("items"):
			var items: Variant = (source as Dictionary).get("items") if source is Dictionary else null
			plate["items"] = _sanitise_items(items, DEFAULT[name].items)
		out[name] = plate
	return out


## One malformed entry loses that one entry, never the screen — the same
## per-key fallback rule the plates carry. And FINER than per-key on the dict
## shape: a malformed size half costs the size and keeps the offset beside it,
## because the two are separate decisions about one element. A dropped half
## means "the element's computed home", which is always a drawable answer.
static func _sanitise_screens(raw: Variant) -> Dictionary:
	var out := {}
	if raw is not Dictionary:
		return out
	for screen in (raw as Dictionary).keys():
		var entries: Variant = (raw as Dictionary)[screen]
		if entries is not Dictionary:
			continue
		var kept := {}
		for key in (entries as Dictionary).keys():
			var entry: Variant = (entries as Dictionary)[key]
			var o: Variant = null
			var s: Variant = null
			if entry is Array:
				o = _pair(entry)
				if o == null:
					continue
			elif entry is Dictionary:
				o = _pair((entry as Dictionary).get("o"))
				s = _pair((entry as Dictionary).get("s"))
			else:
				continue
			var value: Variant = _screen_value(o, s)
			if value != null:
				kept[str(key)] = value
		if not kept.is_empty():
			out[str(screen)] = kept
	return out


## A two-number array, or null — the atom both halves of a screen entry are
## made of.
static func _pair(raw: Variant) -> Variant:
	if raw is not Array or (raw as Array).size() != 2:
		return null
	if not ((raw[0] is float or raw[0] is int) and (raw[1] is float or raw[1] is int)):
		return null
	return [float(raw[0]), float(raw[1])]


## The stored shape for one offset/size pair, normalised: zero halves are
## ERASED (data with no reader), a size-less entry keeps SG-42's array shape so
## an offset-only pass round-trips exactly as it always did, and an entry with
## nothing left to say stores nothing at all — the caller erases the key.
static func _screen_value(o: Variant, s: Variant) -> Variant:
	var off := Vector2(float(o[0]), float(o[1])) if o != null else Vector2.ZERO
	var sz := Vector2(float(s[0]), float(s[1])) if s != null else Vector2.ZERO
	if off.is_zero_approx() and sz.is_zero_approx():
		return null
	if sz.is_zero_approx():
		return [off.x, off.y]
	if off.is_zero_approx():
		return {"s": [sz.x, sz.y]}
	return {"o": [off.x, off.y], "s": [sz.x, sz.y]}


## Writes, and SAYS whether it wrote. A `false` here used to reach an editor
## header that shrugged and printed "layout is clean"; the caller now shows the
## failure in the alarm colour, because a save that quietly does nothing is the
## same shape of bug as a run log that quietly is not written.
func save() -> bool:
	var file := FileAccess.open(store, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(
		{"version": 3, "plates": plates, "slot_items": slot_items,
			"screens": screens}, "  "))
	file.close()
	return true


func reset() -> void:
	plates = DEFAULT.duplicate(true)
	slot_items = SLOT_ITEMS.duplicate(true)
	screens = {}


## --- the screen-element level (SG-42) -----------------------------------------

## The saved offset for one element on one screen, or ZERO — which is "draw it
## where the code puts it", the state every element starts in. Reads BOTH
## stored shapes: SG-42's array and SG-80's dict.
func screen_offset(screen: String, key: String) -> Vector2:
	var entry: Variant = _screen_entry(screen, key)
	var o: Variant = _pair(entry) if entry is Array \
		else (_pair((entry as Dictionary).get("o")) if entry is Dictionary else null)
	return Vector2(float(o[0]), float(o[1])) if o != null else Vector2.ZERO


## The saved SIZE DELTA for one element (SG-80), or ZERO — "as big as the code
## draws it". An array-shaped entry has no size half BY DEFINITION, which is
## exactly what keeps every file written before this feature loading unchanged.
func screen_size(screen: String, key: String) -> Vector2:
	var entry: Variant = _screen_entry(screen, key)
	if entry is not Dictionary:
		return Vector2.ZERO
	var s: Variant = _pair((entry as Dictionary).get("s"))
	return Vector2(float(s[0]), float(s[1])) if s != null else Vector2.ZERO


func _screen_entry(screen: String, key: String) -> Variant:
	var entries: Variant = screens.get(screen)
	if entries is not Dictionary:
		return null
	return (entries as Dictionary).get(key)


## Zero halves are ERASED rather than stored: an entry that says "exactly where,
## and exactly as big as, the code already draws it" is data with no reader
## waiting to happen, and the shipped-keys-resolve check should never have to
## argue about dead weight. Setting either half preserves the other.
func set_screen_offset(screen: String, key: String, off: Vector2) -> void:
	_store_screen(screen, key, off, screen_size(screen, key))


func set_screen_size(screen: String, key: String, sz: Vector2) -> void:
	_store_screen(screen, key, screen_offset(screen, key), sz)


func _store_screen(screen: String, key: String, off: Vector2, sz: Vector2) -> void:
	var value: Variant = _screen_value(
		[off.x, off.y] if not off.is_zero_approx() else null,
		[sz.x, sz.y] if not sz.is_zero_approx() else null)
	if value == null:
		if screens.has(screen):
			(screens[screen] as Dictionary).erase(key)
			if (screens[screen] as Dictionary).is_empty():
				screens.erase(screen)
		return
	if not screens.has(screen):
		screens[screen] = {}
	screens[screen][key] = value


func nudge_screen(screen: String, key: String, delta: Vector2) -> void:
	set_screen_offset(screen, key, screen_offset(screen, key) + _drag_delta(delta))


## The size sibling of `nudge_screen` (SG-80), routed through the SAME
## `_drag_delta` session — so Shift during a drag-resize locks the resize to
## its dominant DIMENSION exactly as SG-58 locks a move to its dominant axis.
## One session, one arithmetic, one gesture to learn.
func resize_screen(screen: String, key: String, delta: Vector2) -> void:
	set_screen_size(screen, key, screen_size(screen, key) + _drag_delta(delta))


## Ctrl+R for one screen: this screen's offsets AND sizes — one erase, because
## an entry is one element's whole edit. The other twenty screens keep the work
## that was done on them.
func clear_screen(screen: String) -> void:
	screens.erase(screen)


## --- the Shift drag-lock (SG-58) ------------------------------------------------

## Hold Shift while DRAGGING in the F4 editor and the drag locks to its DOMINANT
## axis — the one with the larger cumulative travel since the drag began, the
## standard DCC gesture — with the minor axis held at zero. Release Shift and
## the element catches back up to the raw mouse path; press it again and the
## dominant axis is RE-EVALUATED from the whole drag so far — decided per
## press, never flip-flopped per frame. Arrow-nudges keep their Shift = ×10
## meaning untouched: the lock consults `drag_motion`, which is true only while
## the input event being processed is editor drag MOTION, and a key event never
## is.
##
## The session is all arithmetic on purpose (the LabMath pattern): the input
## plumbing is windowed, but the decision the owner asked for is testable
## headless — `editor · shift while dragging locks the dominant axis` and its
## siblings in the harness.
class DragLock extends RefCounted:
	const AXIS_NONE := -1
	const AXIS_X := 0
	const AXIS_Y := 1

	var cum := Vector2.ZERO      ## raw mouse travel since the drag began
	var applied := Vector2.ZERO  ## the travel the nudges actually applied
	var shift := false
	var axis := AXIS_NONE        ## the locked axis, while Shift is down

	## The dominant axis of a travel pair. A tie goes to X, and no travel at
	## all decides nothing — the first real movement decides instead.
	static func pick_axis(travel: Vector2) -> int:
		if travel.is_zero_approx():
			return AXIS_NONE
		return AXIS_X if absf(travel.x) >= absf(travel.y) else AXIS_Y

	## A travel pair with its minor axis zeroed. AXIS_NONE passes it through.
	static func locked(travel: Vector2, which: int) -> Vector2:
		if which == AXIS_X:
			return Vector2(travel.x, 0.0)
		if which == AXIS_Y:
			return Vector2(0.0, travel.y)
		return travel

	func begin(shift_now: bool = false) -> void:
		cum = Vector2.ZERO
		applied = Vector2.ZERO
		shift = shift_now
		axis = AXIS_NONE

	## Edge-triggered, so hearing the same state twice changes nothing (two
	## HUDs can observe one event while a pose is up). A press RE-EVALUATES the
	## axis from the whole drag so far; a release drops the lock.
	func set_shift(down: bool) -> void:
		if down == shift:
			return
		shift = down
		axis = pick_axis(cum) if down else AXIS_NONE

	## One raw mouse delta in, the delta to APPLY out. Locked, the applied path
	## is the raw path with the minor axis zeroed — so pressing Shift mid-drag
	## snaps the element onto the axis, and releasing it catches back up to the
	## mouse, both through the same subtraction.
	func move(delta: Vector2) -> Vector2:
		cum += delta
		if shift and axis == AXIS_NONE:
			axis = pick_axis(cum)
		var target := locked(cum, axis) if shift else cum
		var out := target - applied
		applied = target
		return out


## The one live session. `SkyGearHUD._input` OBSERVES the editor's input —
## never consumes it — and keeps these current before the game's own handler
## turns the same event into a nudge (`_input` on every node precedes any
## `_unhandled_input` seeing the event — the engine's order, not luck).
static var drag := DragLock.new()
## True exactly while the input event being processed is a mouse-drag motion in
## the editor — the flag that keeps arrow-key nudges (Shift = ×10) out of the
## lock's reach.
static var drag_motion := false


## Route a delta through the live session — drag motion only; every other
## caller gets its delta back untouched.
static func _drag_delta(delta: Vector2) -> Vector2:
	if not drag_motion:
		return delta
	return drag.move(delta)


## --- undo (single-level, the SG-39 convention) ---------------------------------

## Everything the editor can change, as one deep copy. The editor takes one
## before every destructive step; Ctrl+Z swaps it back in, and the swap keeps
## what it replaced so a second Ctrl+Z returns.
func snapshot() -> Dictionary:
	return {"plates": plates.duplicate(true), "slot_items": slot_items.duplicate(true),
		"screens": screens.duplicate(true)}


func restore(snap: Dictionary) -> void:
	if snap.is_empty():
		return
	plates = (snap.get("plates", {}) as Dictionary).duplicate(true)
	slot_items = (snap.get("slot_items", {}) as Dictionary).duplicate(true)
	screens = (snap.get("screens", {}) as Dictionary).duplicate(true)


## --- typed entry ---------------------------------------------------------------

## Parse a typed "dx, dy" pair. Accepts two numbers separated by a comma or
## whitespace ("12,-3", " +4 0.5 "); refuses empty, one number, three, or any
## stray character. On refusal the caller keeps the old value — a malformed
## entry never moves anything. The pair-shaped sibling of LabMath.parse_number,
## here rather than in tools/ because the HUD cannot depend on a tools/ file.
static func parse_offset(text: String) -> Dictionary:
	var parts := text.strip_edges().replace(",", " ").split(" ", false)
	if parts.size() != 2:
		return {"ok": false, "x": 0.0, "y": 0.0}
	for part in parts:
		if not str(part).is_valid_float():
			return {"ok": false, "x": 0.0, "y": 0.0}
	return {"ok": true, "x": str(parts[0]).to_float(), "y": str(parts[1]).to_float()}


## --- the floors a resize cannot argue with (SG-80) -----------------------------

## THE NARROWEST A TEXT BOX MAY BE MADE. One glyph at `SkyGearInk.MIN_PT` — the
## ink floor, read from the file that owns it rather than copied as a number,
## because "two functions disagreeing about one number" is this project's named
## failure mode. Below this a box cannot hold a readable character at all, so a
## drag past it is REFUSED.
##
## Note what this floor deliberately is NOT: the width of the string inside the
## box. Narrowing a box until its text no longer fits is a legal edit that the
## LIVE VERDICT reports — the same OVERFLOW detector `tools/text_audit.gd`
## runs — because "you have made this too narrow for its words" is information
## the person resizing wants, not an action to silently prevent. A floor set at
## the content width would make that verdict unreachable, which is the
## detector-silenced-to-make-a-screen-pass failure by another route.
const TEXT_MIN := SkyGearInk.MIN_PT

## And for a widget or a mark, the item floor the plates already carry — the
## same 8 px `_entry` sanitises to and `resize` refuses to go under, named once
## so the three cannot drift.
const ELEMENT_MIN := 8.0

## The floor a PLATE cannot be edited below, likewise named rather than
## repeated: below this the six clusters cannot share a baseline.
const PLATE_MIN := Vector2(40.0, 28.0)


## A base size grown by a delta, never below the floor. The whole arithmetic of
## a resize, in one place so the draw funnels, the drag and the typed box
## cannot drift apart.
static func grown(base: Vector2, delta: Vector2, floor_size: Vector2) -> Vector2:
	if delta == Vector2.ZERO:
		return base
	return Vector2(maxf(base.x + delta.x, floor_size.x),
		maxf(base.y + delta.y, floor_size.y))


## The floor for a box the code drew at `base`. Never larger than the base
## itself: a floor may refuse a shrink, but it must never quietly ENLARGE
## something the code chose to draw smaller than the minimum.
static func size_floor(base: Vector2, minimum: Vector2) -> Vector2:
	return Vector2(minf(base.x, minimum.x), minf(base.y, minimum.y))


## An element's saved-under key, from what it SAYS. Letters only, lowercased,
## everything else a single underscore — digits deliberately excluded, so
## "WAVE 7 / 12" and "WAVE 9 / 12" are the same element and a readout does not
## shed its saved offset every time its number ticks. The editor shows this key
## beside the selected element, because it is the name the offset saves under.
static func element_slug(text: String, fallback: String = "text") -> String:
	var out := ""
	for ch in text.to_lower():
		var code: int = ch.unicode_at(0)
		if code >= 97 and code <= 122:
			out += ch
		elif not out.ends_with("_") and out != "":
			out += "_"
	out = out.trim_suffix("_")
	if out.length() > 28:
		out = out.substr(0, 28).trim_suffix("_")
	return out if out != "" else fallback


## Resolve one anchored box inside another. The whole geometry of the HUD is
## this function; plates pass the screen and items pass their plate's interior.
static func place(entry: Dictionary, within: Rect2) -> Rect2:
	var size := Vector2(float(entry.size[0]), float(entry.size[1]))
	var offset := Vector2(float(entry.offset[0]), float(entry.offset[1]))
	var anchor := str(entry.anchor)
	var origin := Vector2.ZERO
	if anchor.ends_with("_left"):
		origin.x = within.position.x + offset.x
	elif anchor.ends_with("_centre") or anchor == "centre":
		origin.x = within.get_center().x + offset.x - size.x * 0.5
	else:
		origin.x = within.end.x + offset.x - size.x
	if anchor.begins_with("top"):
		origin.y = within.position.y + offset.y
	elif anchor.begins_with("centre"):
		origin.y = within.get_center().y + offset.y - size.y * 0.5
	else:
		origin.y = within.end.y + offset.y - size.y
	return Rect2(origin, size)


func rect(name: String, view: Vector2) -> Rect2:
	var entry: Dictionary = plates.get(name, DEFAULT.get(name, {}))
	if entry.is_empty():
		return Rect2()
	return place(entry, Rect2(Vector2.ZERO, view))


## The usable inside of a plate, once its painted brass frame is taken off.
## THE SAME interior the renderer uses. This had its own formula — 19% of the
## short side, clamped to 10..30 — while `SkyGearHUD` drew a nine-slice rail and
## measured against that. Two answers to "where does the brass end" is how items
## get placed three pixels outside the plate they belong to, which is exactly
## what `tools/text_audit.gd` reported for the lane labels and the wave line.
##
## The constants stay because the editor overlay quotes them, but nothing
## positions against them any more.
static func interior(plate: Rect2) -> Rect2:
	return SkyGearHUD.interior(plate)


## Where an item inside a plate lands. `plate_rect` is passed in rather than
## recomputed, because the HUD applies a narrow-window squeeze to the side plates
## and an item has to follow the plate it is actually drawn in.
func item(plate_name: String, item_name: String, plate_rect: Rect2) -> Rect2:
	var source: Dictionary = slot_items if plate_name.begins_with("slot") \
		else (plates.get(plate_name, {}).get("items", {}) as Dictionary)
	var entry: Dictionary = source.get(item_name, {})
	if entry.is_empty():
		return Rect2()
	## CLAMPED to the plate. An offset that pushes an item past the brass is a
	## label drawn on the frame — the audit found PORT, CENTRE and STARBOARD
	## eleven pixels left of their own plate, and WAVE 7 / 12 three pixels left of
	## its own. A layout file is hand-edited, so it will always be possible to
	## nudge something off the edge; the renderer refusing is cheaper than
	## everyone remembering not to.
	return _clamped(place(entry, interior(plate_rect)), interior(plate_rect))


## Where an item was AUTHORED to go, before the plate refuses it. The editor
## needs this — a warning that your offset pushes a glyph off its slot is only
## possible if something still knows you asked for that. `item` clamps for the
## renderer; this tells the truth for the human.
func authored(plate_name: String, item_name: String, plate_rect: Rect2) -> Rect2:
	var source: Dictionary = slot_items if plate_name.begins_with("slot") 		else (plates.get(plate_name, {}).get("items", {}) as Dictionary)
	var entry: Dictionary = source.get(item_name, {})
	if entry.is_empty():
		return Rect2()
	return place(entry, interior(plate_rect))


static func _clamped(box_in: Rect2, room: Rect2) -> Rect2:
	var box := box_in
	box.size.x = minf(box.size.x, room.size.x)
	box.size.y = minf(box.size.y, room.size.y)
	box.position.x = clampf(box.position.x, room.position.x, room.end.x - box.size.x)
	box.position.y = clampf(box.position.y, room.position.y, room.end.y - box.size.y)
	return box





## The item names a plate owns, in a stable order for the editor to walk.
func items_of(plate_name: String) -> Array[String]:
	var out: Array[String] = []
	var source: Dictionary = SLOT_ITEMS if plate_name.begins_with("slot") \
		else (DEFAULT.get(plate_name, {}).get("items", {}) as Dictionary)
	for key in source.keys():
		out.append(str(key))
	return out


func _bag(plate_name: String) -> Dictionary:
	if plate_name.begins_with("slot"):
		return slot_items
	return plates.get(plate_name, {}).get("items", {})


func nudge(plate_name: String, item_name: String, delta: Vector2) -> void:
	var entry: Dictionary = _bag(plate_name).get(item_name, {}) if item_name != "" \
		else plates.get(plate_name, {})
	if entry.is_empty():
		return
	var apply := _drag_delta(delta)
	entry.offset[0] = float(entry.offset[0]) + apply.x
	entry.offset[1] = float(entry.offset[1]) + apply.y


func resize(plate_name: String, item_name: String, delta: Vector2) -> void:
	var entry: Dictionary = _bag(plate_name).get(item_name, {}) if item_name != "" \
		else plates.get(plate_name, {})
	if entry.is_empty():
		return
	var least := PLATE_MIN if item_name == "" else Vector2(ELEMENT_MIN, ELEMENT_MIN)
	entry.size[0] = maxf(least.x, float(entry.size[0]) + delta.x)
	entry.size[1] = maxf(least.y, float(entry.size[1]) + delta.y)


## Re-anchoring keeps the box where it is on screen and changes only what it is
## measured from — otherwise every anchor change is also a jump, and the editor
## becomes a puzzle.
func set_anchor(plate_name: String, item_name: String, anchor: String,
		view: Vector2, plate_rect: Rect2) -> void:
	if not anchor in ANCHORS:
		return
	var within: Rect2 = Rect2(Vector2.ZERO, view) if item_name == "" else interior(plate_rect)
	var entry: Dictionary = _bag(plate_name).get(item_name, {}) if item_name != "" \
		else plates.get(plate_name, {})
	if entry.is_empty():
		return
	var was := place(entry, within)
	entry.anchor = anchor
	var offset := Vector2.ZERO
	if anchor.ends_with("_left"):
		offset.x = was.position.x - within.position.x
	elif anchor.ends_with("_centre") or anchor == "centre":
		offset.x = was.get_center().x - within.get_center().x
	else:
		offset.x = was.end.x - within.end.x
	if anchor.begins_with("top"):
		offset.y = was.position.y - within.position.y
	elif anchor.begins_with("centre"):
		offset.y = was.get_center().y - within.get_center().y
	else:
		offset.y = was.end.y - within.end.y
	entry.offset = [offset.x, offset.y]


func all_rects(view: Vector2) -> Dictionary:
	var out := {}
	for name in ORDER:
		out[name] = rect(name, view)
	return out


## Does this layout hold together? Used by the harness and by the editor's own
## readout, so a hand-placed layout is checked rather than trusted.
func problems(view: Vector2) -> Array[String]:
	var out: Array[String] = []
	var frame := Rect2(Vector2.ZERO, view)
	var rects := all_rects(view)
	for name in ORDER:
		var r: Rect2 = rects[name]
		if not frame.encloses(r):
			out.append("%s is off screen" % name)
		if r.position.y < view.y * 0.5 and not name in TOP_ALLOWED:
			out.append("%s is in the top half, where boarders arrive" % name)
		## And the one that is allowed up there has to stay slim, or it becomes
		## the thing the HUD was moved out of the way of.
		if name in TOP_ALLOWED and r.size.y > view.y * 0.16:
			out.append("%s is too tall for the top of the screen" % name)
		## An item outside its own plate is the failure this whole second level
		## exists to make visible: a glyph sitting off the edge of its slot.
		var inside := interior(r)
		for item_name in items_of(name):
			if not inside.grow(2.0).encloses(authored(name, item_name, r)):
				out.append("%s/%s is outside its plate" % [name, item_name])
	for i in ORDER.size():
		for j in range(i + 1, ORDER.size()):
			if (rects[ORDER[i]] as Rect2).intersects(rects[ORDER[j]]):
				out.append("%s overlaps %s" % [ORDER[i], ORDER[j]])
	return out
