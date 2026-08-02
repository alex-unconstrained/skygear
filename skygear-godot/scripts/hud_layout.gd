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
	"captain": {
		"anchor": "bottom_left", "offset": [24, -24], "size": [350, 132],
		"items": {
			"portrait": {"anchor": "centre_left", "offset": [0, 0], "size": [60, 60]},
			"health": {"anchor": "top_left", "offset": [74, 8], "size": [212, 26]},
			"dial": {"anchor": "bottom_left", "offset": [74, -4], "size": [40, 40]},
			"vent_icon": {"anchor": "bottom_left", "offset": [120, -34], "size": [15, 15]},
			"pressure_label": {"anchor": "bottom_left", "offset": [140, -26], "size": [96, 14]},
			"dash_label": {"anchor": "bottom_left", "offset": [140, -8], "size": [40, 14]},
			"dash_pips": {"anchor": "bottom_left", "offset": [184, -14], "size": [48, 20]},
		},
	},
	## THE OBJECTIVE, TOP CENTRE. It is the thing you lose by and it was in a
	## corner competing with three lane tracks. Top centre is where the browser
	## puts it and where an eye goes first — and it is a slim centred plate, so
	## it costs almost none of the deck the boarders arrive across, which is why
	## the rest of the HUD is still along the bottom.
	"objective": {
		"anchor": "top_centre", "offset": [0, 12], "size": [420, 76],
		"items": {
			"boiler": {"anchor": "top_centre", "offset": [0, 8], "size": [340, 26]},
			"wave": {"anchor": "bottom_left", "offset": [0, 0], "size": [150, 20]},
			"boarders": {"anchor": "bottom_right", "offset": [0, 0], "size": [160, 20]},
		},
	},
	"ship": {
		"anchor": "bottom_right", "offset": [-24, -24], "size": [350, 118],
		"items": {
			"lane0": {"anchor": "top_left", "offset": [0, 6], "size": [268, 16]},
			"lane1": {"anchor": "top_left", "offset": [0, 26], "size": [268, 16]},
			"lane2": {"anchor": "top_left", "offset": [0, 46], "size": [268, 16]},
		},
	},
	## Centre-relative, because that is what a centre anchor means: the offset is
	## to the plate's own centre, so four slots at -192/-64/+64/+192 are
	## symmetric about the middle of the screen by construction.
	"slot0": {"anchor": "bottom_centre", "offset": [-192, -24], "size": [120, 112]},
	"slot1": {"anchor": "bottom_centre", "offset": [-64, -24], "size": [120, 112]},
	"slot2": {"anchor": "bottom_centre", "offset": [64, -24], "size": [120, 112]},
	"slot3": {"anchor": "bottom_centre", "offset": [192, -24], "size": [120, 112]},
}

## Every skill slot shares one set of item positions — four slots that disagree
## about where their glyph sits is four bugs, not four decisions. Stored once
## under `slot0` and applied to all four.
const SLOT_ITEMS := {
	"key": {"anchor": "top_centre", "offset": [0, -1], "size": [66, 14]},
	"icon": {"anchor": "centre", "offset": [0, 2], "size": [32, 32]},
	"name": {"anchor": "bottom_centre", "offset": [0, 1], "size": [74, 13]},
}

const ORDER := ["objective", "captain", "slot0", "slot1", "slot2", "slot3", "ship"]

## The one plate allowed above the halfway line, because it is the objective and
## it is deliberately slim. Everything else stays in the bottom band, which is
## the whole reason the HUD was moved there.
const TOP_ALLOWED := ["objective"]

var plates: Dictionary = {}
var slot_items: Dictionary = {}
## THE THIRD LEVEL (SG-42): per-screen, per-element offsets for everything that
## is NOT the gameplay HUD — the title rows, the draft cards' contents, the
## pause buttons, a workshop heading. `screen -> {element key -> [dx, dy]}`.
##
## An offset here is RELATIVE TO THE ELEMENT'S COMPUTED HOME — the position the
## drawing code was about to use — never an absolute position. That is what
## keeps a saved offset meaningful when the code-side layout changes: move the
## home and the offset follows it, the same invariant the plate anchors carry.
## The element keys are made by `element_slug` from what the element says, so a
## readout whose NUMBER changes keeps its key.
var screens: Dictionary = {}


func _init() -> void:
	plates = DEFAULT.duplicate(true)
	slot_items = SLOT_ITEMS.duplicate(true)
	screens = {}


static func load_layout() -> SkyGearHudLayout:
	var out := SkyGearHudLayout.new()
	for path in [USER_PATH, SHIPPED_PATH]:
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
		"size": [maxf(8.0, float(size[0])), maxf(8.0, float(size[1]))],
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
		plate.size[0] = maxf(40.0, float(plate.size[0]))
		plate.size[1] = maxf(28.0, float(plate.size[1]))
		if (DEFAULT[name] as Dictionary).has("items"):
			var items: Variant = (source as Dictionary).get("items") if source is Dictionary else null
			plate["items"] = _sanitise_items(items, DEFAULT[name].items)
		out[name] = plate
	return out


## One malformed offset loses that one entry, never the screen — the same
## per-key fallback rule the plates carry. Anything that is not a two-number
## array is dropped, and a dropped entry means "the element's computed home",
## which is always a drawable answer.
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
			var off: Variant = (entries as Dictionary)[key]
			if off is not Array or (off as Array).size() != 2:
				continue
			if not ((off[0] is float or off[0] is int) and (off[1] is float or off[1] is int)):
				continue
			kept[str(key)] = [float(off[0]), float(off[1])]
		if not kept.is_empty():
			out[str(screen)] = kept
	return out


func save() -> bool:
	var file := FileAccess.open(USER_PATH, FileAccess.WRITE)
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
## where the code puts it", the state every element starts in.
func screen_offset(screen: String, key: String) -> Vector2:
	var entries: Variant = screens.get(screen)
	if entries is not Dictionary:
		return Vector2.ZERO
	var off: Variant = (entries as Dictionary).get(key)
	if off is not Array or (off as Array).size() != 2:
		return Vector2.ZERO
	return Vector2(float(off[0]), float(off[1]))


## Zero offsets are ERASED rather than stored: an entry that says "exactly where
## the code already puts it" is data with no reader waiting to happen, and the
## shipped-keys-resolve check should never have to argue about dead weight.
func set_screen_offset(screen: String, key: String, off: Vector2) -> void:
	if off.is_zero_approx():
		if screens.has(screen):
			(screens[screen] as Dictionary).erase(key)
			if (screens[screen] as Dictionary).is_empty():
				screens.erase(screen)
		return
	if not screens.has(screen):
		screens[screen] = {}
	screens[screen][key] = [off.x, off.y]


func nudge_screen(screen: String, key: String, delta: Vector2) -> void:
	set_screen_offset(screen, key, screen_offset(screen, key) + delta)


## Ctrl+R for one screen: this screen's offsets only. The other twenty screens
## keep the work that was done on them.
func clear_screen(screen: String) -> void:
	screens.erase(screen)


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
	entry.offset[0] = float(entry.offset[0]) + delta.x
	entry.offset[1] = float(entry.offset[1]) + delta.y


func resize(plate_name: String, item_name: String, delta: Vector2) -> void:
	var entry: Dictionary = _bag(plate_name).get(item_name, {}) if item_name != "" \
		else plates.get(plate_name, {})
	if entry.is_empty():
		return
	var floor_x: float = 40.0 if item_name == "" else 8.0
	var floor_y: float = 28.0 if item_name == "" else 8.0
	entry.size[0] = maxf(floor_x, float(entry.size[0]) + delta.x)
	entry.size[1] = maxf(floor_y, float(entry.size[1]) + delta.y)


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
