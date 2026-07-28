class_name SkyGearHudLayout
extends RefCounted

## Where every HUD plate sits, as data rather than as arithmetic in `_draw`.
##
## The positions were constants, so moving one meant me editing a number,
## rebuilding, taking a screenshot, looking at it and doing it again. That is a
## turn per three pixels, and it is a loop I cannot close on my own because the
## answer is a matter of taste. Alex can settle a layout in ninety seconds by
## dragging it; the only thing missing was somewhere for the result to live.
##
## So: a layout is a small JSON document, the game reads it, and the in-game
## editor (F4) writes it. What he drags is what ships.
##
## Anchored rather than absolute. A plate records which screen corner it hangs
## off and how far in, so one layout is correct at 1280 and at 2560 — otherwise
## a hand-placed HUD is only right on the monitor it was placed on.

const USER_PATH := "user://hud_layout.json"
const SHIPPED_PATH := "res://assets/hud_layout.json"

## The layout the game falls back to, and what `reset` restores. Kept in code
## rather than only in the shipped file so a corrupt or absent file can never
## leave the player with no HUD at all.
const DEFAULT := {
	"captain": {"anchor": "bottom_left", "offset": [24, -156], "size": [350, 132]},
	"ship": {"anchor": "bottom_right", "offset": [-24, -210], "size": [350, 186]},
	"slot0": {"anchor": "bottom_centre", "offset": [-256, -136], "size": [120, 112]},
	"slot1": {"anchor": "bottom_centre", "offset": [-128, -136], "size": [120, 112]},
	"slot2": {"anchor": "bottom_centre", "offset": [0, -136], "size": [120, 112]},
	"slot3": {"anchor": "bottom_centre", "offset": [128, -136], "size": [120, 112]},
}

## Order matters for the editor: Tab walks this list, and it is the order a
## reader would name them in.
const ORDER := ["captain", "slot0", "slot1", "slot2", "slot3", "ship"]

const ANCHORS := ["top_left", "top_centre", "top_right",
	"bottom_left", "bottom_centre", "bottom_right"]

var plates: Dictionary = {}


func _init() -> void:
	plates = DEFAULT.duplicate(true)


## Load the player's layout if there is one, else the shipped one, else the
## built-in default. Every step is total: a layout file is a thing a human edits
## by hand, so it is a thing that will one day have a trailing comma in it.
static func load_layout() -> SkyGearHudLayout:
	var out := SkyGearHudLayout.new()
	for path in [USER_PATH, SHIPPED_PATH]:
		var parsed := _read(path)
		if not parsed.is_empty():
			out.plates = _sanitise(parsed)
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
	if parsed is Dictionary and (parsed as Dictionary).has("plates"):
		return (parsed as Dictionary).plates
	if parsed is Dictionary:
		return parsed
	return {}


## Anything missing or malformed falls back to the default for that plate, so a
## half-edited file loses one panel rather than the whole HUD.
static func _sanitise(raw: Dictionary) -> Dictionary:
	var out := DEFAULT.duplicate(true)
	for name in DEFAULT.keys():
		var entry: Variant = raw.get(name)
		if entry is not Dictionary:
			continue
		var anchor := str((entry as Dictionary).get("anchor", ""))
		var offset: Variant = (entry as Dictionary).get("offset")
		var size: Variant = (entry as Dictionary).get("size")
		if not anchor in ANCHORS or offset is not Array or size is not Array:
			continue
		if (offset as Array).size() != 2 or (size as Array).size() != 2:
			continue
		out[name] = {
			"anchor": anchor,
			"offset": [float(offset[0]), float(offset[1])],
			"size": [maxf(40.0, float(size[0])), maxf(28.0, float(size[1]))],
		}
	return out


func save() -> bool:
	var file := FileAccess.open(USER_PATH, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify({"version": 1, "plates": plates}, "  "))
	file.close()
	return true


func reset() -> void:
	plates = DEFAULT.duplicate(true)


## Where a plate lands on a screen of this size.
func rect(name: String, view: Vector2) -> Rect2:
	var entry: Dictionary = plates.get(name, DEFAULT.get(name, {}))
	if entry.is_empty():
		return Rect2()
	var size := Vector2(float(entry.size[0]), float(entry.size[1]))
	var offset := Vector2(float(entry.offset[0]), float(entry.offset[1]))
	var anchor := str(entry.anchor)
	var origin := Vector2.ZERO
	## The horizontal anchor also decides which of the plate's own edges the
	## offset is measured to, so a right-anchored plate keeps its right edge a
	## fixed distance from the right of the screen at any width.
	if anchor.ends_with("_left"):
		origin.x = offset.x
	elif anchor.ends_with("_centre"):
		origin.x = view.x * 0.5 + offset.x
	else:
		origin.x = view.x + offset.x - size.x
	origin.y = offset.y if anchor.begins_with("top") else view.y + offset.y
	return Rect2(origin, size)


func all_rects(view: Vector2) -> Dictionary:
	var out := {}
	for name in ORDER:
		out[name] = rect(name, view)
	return out


## Move a plate by a screen-space delta, keeping its anchor. Returns the new
## rect so the caller can show it.
func nudge(name: String, delta: Vector2) -> void:
	if not plates.has(name):
		return
	plates[name].offset[0] = float(plates[name].offset[0]) + delta.x
	plates[name].offset[1] = float(plates[name].offset[1]) + delta.y


func resize(name: String, delta: Vector2) -> void:
	if not plates.has(name):
		return
	plates[name].size[0] = maxf(40.0, float(plates[name].size[0]) + delta.x)
	plates[name].size[1] = maxf(28.0, float(plates[name].size[1]) + delta.y)


func set_anchor(name: String, anchor: String, view: Vector2) -> void:
	if not plates.has(name) or not anchor in ANCHORS:
		return
	## Re-anchoring keeps the plate where it is on screen and changes only what
	## it is measured from — otherwise every anchor change is also a jump, and
	## the editor becomes a puzzle.
	var was := rect(name, view)
	plates[name].anchor = anchor
	var size := was.size
	var offset := Vector2.ZERO
	if anchor.ends_with("_left"):
		offset.x = was.position.x
	elif anchor.ends_with("_centre"):
		offset.x = was.position.x - view.x * 0.5
	else:
		offset.x = was.end.x - view.x
	offset.y = was.position.y if anchor.begins_with("top") else was.position.y - view.y
	plates[name].offset = [offset.x, offset.y]
	plates[name].size = [size.x, size.y]


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
		if r.position.y < view.y * 0.5:
			out.append("%s is in the top half, where boarders arrive" % name)
	for i in ORDER.size():
		for j in range(i + 1, ORDER.size()):
			if (rects[ORDER[i]] as Rect2).intersects(rects[ORDER[j]]):
				out.append("%s overlaps %s" % [ORDER[i], ORDER[j]])
	return out
