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
	return cfg.save(PATH) == OK


## Total, like everything else that touches the disk here. A profile that cannot
## be read is a profile with default keys, not a crash on boot.
static func load_saved() -> void:
	capture_defaults()
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
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
