class_name SkyGearKeybinds
extends RefCounted

## Rebindable controls, saved between sessions.
##
## WASD is not a universal fact. It is a QWERTY fact, and the browser build has
## carried a rebind screen since v6 for the plain reason that a player who cannot
## reach `dash` cannot dash. The port shipped with the map baked into
## `project.godot`, which is the same as not having one.
##
## Scope is deliberately narrow. Only the eight actions a hand rests on are
## rebindable — movement, four skills, dash and pause. Menu keys (Enter, 1/2/3,
## C, R, F2, F3) stay fixed, because a player who rebinds their way out of the
## rebind screen has no way back in.
##
## Physical keycodes throughout, so an AZERTY keyboard gets ZQSD without anyone
## having to rebind anything, and a rebind is stored as the physical key too.

const PATH := "user://keys.cfg"
const REBINDABLE := [
	["move_up", "MOVE UP"],
	["move_down", "MOVE DOWN"],
	["move_left", "MOVE LEFT"],
	["move_right", "MOVE RIGHT"],
	["skill_1", "SKILL 1"],
	["skill_2", "SKILL 2"],
	["skill_3", "SKILL 3"],
	["skill_4", "SKILL 4"],
	["dash", "DASH"],
	## Deckwork. Held, not pressed — see `scripts/deckwork.gd`.
	["deckwork", "REPAIR / WORK"],
	["pause", "PAUSE"],
]

## THE KEY THAT SELECTS EACH ROW, AND THE ONLY COPY OF THAT MAPPING (DR-09b).
##
## This list had ELEVEN rows and the sheet numbered them `(i + 1) % 10`, so row
## 10 (PAUSE) was labelled `"1"` — the same digit as MOVE UP — and the reader,
## `game.gd::_digit_slot`, mapped only KEY_1..9 and KEY_0. The result was not a
## cosmetic clash: **PAUSE could not be rebound at all**, on a sheet whose own
## subtitle says "press a number to rebind that row", and the rows are not
## clickable so there was no other way in.
##
## One table, two readers — the drawn label and the keycode both come from here,
## so a twelfth row cannot re-open the gap by being added in one place only. Past
## the ten digits the selectors keep going along the number row, which is where
## a hand already is: `-` for row 11, `=` for a row 12 if one is ever added.
const SLOTS := [
	[KEY_1, "1"], [KEY_2, "2"], [KEY_3, "3"], [KEY_4, "4"], [KEY_5, "5"],
	[KEY_6, "6"], [KEY_7, "7"], [KEY_8, "8"], [KEY_9, "9"], [KEY_0, "0"],
	[KEY_MINUS, "-"], [KEY_EQUAL, "="],
]


## The character printed beside row `i` — and the one the player must press.
static func slot_label(i: int) -> String:
	return str(SLOTS[i][1]) if i >= 0 and i < SLOTS.size() else "?"


## The row a keycode selects, or -1. Numpad twins included: a player rebinding
## on a full-size board should not have to find the top row.
static func slot_for(code: int) -> int:
	for i in SLOTS.size():
		if code == int(SLOTS[i][0]):
			return i
	if code == KEY_KP_SUBTRACT:
		return 10
	if code == KEY_KP_ADD:
		return 11
	return -1

## THE FILE EVERY READER AND WRITER HERE ACTUALLY GOES THROUGH. `PATH` is where
## a PLAYER's rebinds live; `store` is the pointer, so a TEST RUN can be sent
## somewhere else. The third application of `SkyGearHudLayout.store` (SG-83) and
## `SkyGearAudio.store` (SG-181), and the reason is board SG-182.
##
## `_persistence()` rebinds `dash` to F, calls `save()`, reloads, then `reset()`s
## and saves again — all against the real file. So every
## `SkyGear Tools.bat harness` flattened the owner's bindings back to project
## defaults, and a run that died between the two saves left his dash bound to F.
## The reason it was invisible is the same reason a wiped file looks stable: an
## earlier harness run had already flattened it, so the before/after hashes
## agreed while the damage had already been done.
static var store := PATH

## What the project ships with, captured the first time this runs so `reset()`
## has something true to go back to rather than a second hard-coded copy that
## can drift out of step with `project.godot`.
static var _defaults: Dictionary = {}


static func capture_defaults() -> void:
	if not _defaults.is_empty():
		return
	for row in REBINDABLE:
		var action: String = row[0]
		if InputMap.has_action(action):
			_defaults[action] = InputMap.action_get_events(action).duplicate()


## The label a player reads for an action, built from whatever is bound to it.
## Mouse buttons are named rather than numbered, because "Button 1" is not a
## thing anybody has on their desk.
static func label(action: String) -> String:
	if not InputMap.has_action(action):
		return "—"
	var parts: Array[String] = []
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			var code: Key = event.physical_keycode if event.physical_keycode != KEY_NONE \
				else event.keycode
			## Physical -> what is printed on the key, so an AZERTY player is told
			## "Z" rather than "W". The headless server cannot answer that, and
			## asking it anyway logged an error per row per frame in the harness.
			if DisplayServer.get_name() != "headless":
				code = DisplayServer.keyboard_get_keycode_from_physical(code)
			parts.append(OS.get_keycode_string(code))
		elif event is InputEventMouseButton:
			match event.button_index:
				MOUSE_BUTTON_LEFT: parts.append("LMB")
				MOUSE_BUTTON_RIGHT: parts.append("RMB")
				MOUSE_BUTTON_MIDDLE: parts.append("MMB")
				_: parts.append("MOUSE %d" % event.button_index)
	if parts.is_empty():
		return "UNBOUND"
	return " / ".join(parts)


## ONE event's label, for the places a string has to fit — the four skill-well
## tabs, the title's control line. `label()` joins everything an action answers
## to ("LMB / 1"), which is right on the CONTROLS sheet and eight pixels too wide
## on a well tab.
##
## Mouse first, deliberately: `skill_1` is LMB *and* 1, and the hand that plays
## this game is on the mouse. A player who rebinds the key still sees the button
## they are actually using.
static func short_label(action: String) -> String:
	var whole := label(action)
	if whole == "UNBOUND" or whole == "—":
		return whole
	var parts := whole.split(" / ")
	for p in parts:
		if p in ["LMB", "RMB", "MMB"]:
			return p
	return str(parts[0])


## The one line on the title screen that tells a player what their hands do, and
## for the whole life of the port it was the string `"WASD move · mouse aim ·
## LMB/RMB/Q/E skills · Space dash"` — four claims, none of them read from the
## bindings, on a game that has shipped a rebind sheet since SG-33 and resolves
## PHYSICAL keycodes so an AZERTY board silently gets ZQSD (DR-09a).
##
## `jet` is the class fact, not a binding fact: the Boilerwright's Space is a
## Bleed Jet and calling it a dash is the reason that move goes undiscovered.
static func controls_line(jet: bool) -> String:
	var move := ""
	var spaced := false
	for action in ["move_up", "move_left", "move_down", "move_right"]:
		var k := short_label(action)
		if k.length() != 1:
			spaced = true
		move += k + " "
	move = move.strip_edges()
	## WASD reads as a word; anything with a multi-character key in it reads as
	## a list and needs its spaces. Arrow keys are the case that proves it.
	if not spaced:
		move = move.replace(" ", "")

	var skills: Array[String] = []
	for i in 4:
		skills.append(short_label("skill_%d" % (i + 1)))

	var last := "%s bleeds a jet" % short_label("dash") if jet \
		else "%s dash" % short_label("dash")
	return "%s move · mouse aim · %s skills · %s" % [
		move, "/".join(skills), last]


## Bind an action to one event, replacing everything on it.
##
## Refuses a key already spoken for by a different rebindable action, rather
## than silently creating a double-bind that reads as "dash is broken". The
## caller gets the conflicting action back so it can say which one.
static func rebind(action: String, event: InputEvent) -> String:
	if not InputMap.has_action(action):
		return "?"
	for row in REBINDABLE:
		var other: String = row[0]
		if other == action:
			continue
		for bound in InputMap.action_get_events(other):
			if bound.is_match(event, false):
				return other
	InputMap.action_erase_events(action)
	InputMap.action_add_event(action, event)
	save()
	return ""


static func reset() -> void:
	capture_defaults()
	for action in _defaults.keys():
		InputMap.action_erase_events(action)
		for event in _defaults[action]:
			InputMap.action_add_event(action, event)
	save()


static func save() -> bool:
	var cfg := ConfigFile.new()
	for row in REBINDABLE:
		var action: String = row[0]
		if not InputMap.has_action(action):
			continue
		var codes: Array = []
		for event in InputMap.action_get_events(action):
			if event is InputEventKey:
				codes.append({"kind": "key", "code": int(event.physical_keycode)})
			elif event is InputEventMouseButton:
				codes.append({"kind": "mouse", "code": int(event.button_index)})
		cfg.set_value("keys", action, codes)
	return cfg.save(store) == OK


## Total, like everything else that touches the disk here. A profile that cannot
## be read is a profile with default keys, not a crash on boot.
static func load_saved() -> void:
	capture_defaults()
	var cfg := ConfigFile.new()
	if cfg.load(store) != OK:
		return
	for row in REBINDABLE:
		var action: String = row[0]
		if not InputMap.has_action(action) or not cfg.has_section_key("keys", action):
			continue
		var codes: Variant = cfg.get_value("keys", action, [])
		if codes is not Array or (codes as Array).is_empty():
			continue
		InputMap.action_erase_events(action)
		for entry in codes:
			if entry is not Dictionary:
				continue
			if str(entry.get("kind", "")) == "key":
				var k := InputEventKey.new()
				k.physical_keycode = int(entry.get("code", 0)) as Key
				InputMap.action_add_event(action, k)
			elif str(entry.get("kind", "")) == "mouse":
				var m := InputEventMouseButton.new()
				m.button_index = int(entry.get("code", 1)) as MouseButton
				InputMap.action_add_event(action, m)
