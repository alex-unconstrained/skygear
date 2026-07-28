class_name SkyGearGame
extends Node2D

enum State { TITLE, PLAY, DRAFT, PAUSE, GAMEOVER, VICTORY }

const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const PROP_SCENE := preload("res://scenes/prop.tscn")

const DECK_RECT := Rect2(-840, -1160, 1680, 2320)
const BOILER_POSITION := Vector2(0, 850)
const LANE_CENTERS := [-560.0, 0.0, 560.0]
const CARGO_RECTS := [
	Rect2(-340, -870, 120, 300),
	Rect2(-340, -370, 120, 270),
	Rect2(-340, 130, 120, 280),
	Rect2(-340, 620, 120, 250),
	Rect2(220, -870, 120, 300),
	Rect2(220, -370, 120, 270),
	Rect2(220, 130, 120, 280),
	Rect2(220, 620, 120, 250),
]

@onready var player: SkyGearPlayer = $Player
@onready var hud: SkyGearHUD = $HUD/Overlay
var audio: SkyGearAudio
## The captain, her crew and the thing in the last wave. Every line below sits
## on top of a mechanical cue that already fires, so the layer is flavour and
## never information — see `scripts/voice.gd` for why that rule exists.
var voice: SkyGearVoice
## Hit-stop and shake. The one thing in this project allowed to scale time, and
## it does it by handing the simulation a smaller delta rather than by touching
## `Engine.time_scale` — a global scale also slows the animation blends, the
## music and the voice, which is not a hit landing, it is the game skipping.
var impact: SkyGearImpact
## The 3D renderer, when it is the one drawing. Set by `SkyGearView3D` so the
## simulation can tell it a hit happened without knowing anything else about it.
var view: SkyGearView3D
var _said_first_board := false
var _said_boiler_low := false

var rng := RandomNumberGenerator.new()
## A SECOND stream, for anything that only affects the picture.
##
## The browser build keeps these apart deliberately and this is why: damage
## numbers were given a little random scatter so a stack of them is readable,
## the scatter was drawn from `rng`, and every crit roll, scrap roll and spawn
## jitter for the rest of the run shifted by however many boarders had been hit.
## A seed has to reproduce a run, so nothing cosmetic may touch it.
var visual_rng := RandomNumberGenerator.new()
var state := State.TITLE
var state_name := "TITLE"
var wave := 0
var wave_time := 0.0
var wave_clear_time := -1.0
var spawn_queue: Array[Dictionary] = []
var skills: Array[Dictionary] = []
var draft_options: Array[Dictionary] = []
var opening_draft := false
var boiler_hp := 500.0
var boiler_max_hp := 500.0
var boiler_position := BOILER_POSITION
var boiler_radius := 62.0
var end_reason := ""
var basic_cooldown := 0.0
var pressure := 0.0
var pressure_grace := 0.0
var vent_cooldown := 0.0
var damage_multiplier := 1.0
var projectiles: Array[Dictionary] = []
var effects: Array[Dictionary] = []
## Damage and healing, as numbers that leave the body they came from. The
## browser has had these since v2 and they are not decoration: a fight where
## every hit looks the same is a fight you cannot tune a build against, and the
## whole v11 upgrade system asks the player to notice which skill is carrying.
var floaters: Array[Dictionary] = []
var salvage: Array[Dictionary] = []
var fire_fields: Array[Dictionary] = []
var dash_hit_ids := {}

## v11.2 parity. `mods` is every global modifier a card can move; `tel` is what
## the player actually did, which the draft reads to decide which slot an
## upgrade should land on.
var mods: Dictionary = SkyGearCards.fresh_mods()
var tel: Dictionary = SkyGearTelemetry.fresh()
var rerolls := 0
var seed_text := ""
var src_slot := -1                  ## slot currently resolving, for attribution
var heal_budget := 0.0
var steal_budget := 0.0
var cards_taken: Array[String] = []
var run_time := 0.0
## Whether the last finished run reached the disk. Shown on the results screen,
## because a run log that silently is not being written is worse than none.
var run_logged := false
## Where the cursor is on the deck, as the 3D view sees it.
##
## The 2D scene is hidden, so `get_global_mouse_position()` on it answers a
## question about a space nobody is looking at. The renderer that owns the camera
## owns the answer; this is where it puts it. Unset in the plain 2D scene, which
## still uses the 2D mouse and is still what the harness drives.
var cursor_ground := Vector2.ZERO
var cursor_valid := false


func set_cursor_ground(at: Vector2) -> void:
	cursor_ground = at
	cursor_valid = true


## The point every skill aims at. One place, so a cast, the captain's facing and
## the renderer cannot disagree about where the player is pointing.
func aim_target() -> Vector2:
	if cursor_valid:
		return cursor_ground
	return player.get_global_mouse_position()
## The controls screen. `rebinding_index` is which row is listening for a key,
## or -1; `rebind_conflict` is the action that already owns the last key tried.
## The HUD layout editor (F4). State lives here rather than in the HUD because
## the HUD is a view and input belongs to the thing that owns input.
var layout_edit := false
var layout_pick := "captain"
## Which element INSIDE the selected plate is being edited, or "" for the plate
## itself. Panel-level placement was not enough: a glyph can sit off-centre in
## its own slot, and the only fix was another round trip through me.
var layout_item := ""
var layout_saved := false
var _layout_drag := ""
var _layout_resize := false
var _layout_from := Vector2.ZERO

var keys_open := false
var rebinding_index := -1
var rebind_conflict := ""

## The lane layer. Plain data, drawn by this node — see scripts/lanes.gd.
const BASE_Y := 730.0
const BOW_Y := -1000.0
var turrets: Array[Dictionary] = []
var crew: Array[Dictionary] = []
var hulk: Dictionary = {}
var crew_timer := 0.0

func _ready() -> void:
	rng.seed = 0x5A17C0DE
	player.game = self
	hud.game = self
	player.controls_enabled = false
	player.visible = false
	audio = SkyGearAudio.new()
	audio.name = "Audio"
	add_child(audio)
	impact = SkyGearImpact.new()
	impact.name = "Impact"
	add_child(impact)
	voice = SkyGearVoice.new()
	voice.name = "Voice"
	voice.audio = audio
	add_child(voice)
	player.dash_started.connect(_on_dash_started)
	SkyGearKeybinds.capture_defaults()
	SkyGearKeybinds.load_saved()
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	## The layout editor, first and greedy. It is a mode, and a mode that lets
	## the game underneath react to the same click is a mode that fights you.
	if layout_edit and _layout_input(event):
		get_viewport().set_input_as_handled()
		return
	## The rebind screen swallows everything while it is open, so that pressing
	## W to bind W does not also walk you into a boarder.
	if rebinding_index >= 0:
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode == KEY_ESCAPE:
				rebinding_index = -1
				rebind_conflict = ""
			else:
				_apply_rebind(event)
			get_viewport().set_input_as_handled()
		elif event is InputEventMouseButton and event.pressed:
			_apply_rebind(event)
			get_viewport().set_input_as_handled()
		return
	## The draft, with a mouse. It was keyboard-only — 1, 2, 3 — and a screen full
	## of cards that do not respond to being clicked reads as a screen that is
	## broken, not as a screen with a keyboard shortcut.
	if state == State.DRAFT and event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		var where: Vector2 = hud.get_local_mouse_position()
		var cards := SkyGearHUD.draft_cards(hud.size, mini(3, draft_options.size()))
		for i in cards.size():
			if cards[i].has_point(where):
				choose_draft(i)
				get_viewport().set_input_as_handled()
				return
		if SkyGearHUD.reroll_button(hud.size).has_point(where):
			reroll_draft()
			get_viewport().set_input_as_handled()
			return
	if event is not InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_F4:
		layout_edit = not layout_edit
		layout_saved = false
		hud.queue_redraw()
		get_viewport().set_input_as_handled()
		return
	## The controls screen. Fixed keys, deliberately: rebinding your way out of
	## the rebind screen leaves no way back in.
	if event.keycode == KEY_F2 and state in [State.TITLE, State.PAUSE]:
		keys_open = not keys_open
		queue_redraw()
		hud.queue_redraw()
		get_viewport().set_input_as_handled()
		return
	if keys_open:
		if event.keycode == KEY_ESCAPE:
			keys_open = false
		elif event.keycode == KEY_BACKSPACE:
			SkyGearKeybinds.reset()
			rebind_conflict = ""
		else:
			var slot := _digit_slot(event.keycode)
			if slot >= 0 and slot < SkyGearKeybinds.REBINDABLE.size():
				rebinding_index = slot
				rebind_conflict = ""
		hud.queue_redraw()
		get_viewport().set_input_as_handled()
		return
	if state == State.TITLE and event.keycode in [KEY_ENTER, KEY_KP_ENTER]:
		begin_run()
		get_viewport().set_input_as_handled()
		return
	if state in [State.GAMEOVER, State.VICTORY]:
		if event.keycode in [KEY_ENTER, KEY_KP_ENTER]:
			go_to_title()
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_C:
			# the report is the thing a tester pastes into a message; make
			# taking it one key rather than a screenshot of a screen
			copy_run_report()
			_fx({"kind": "banner", "text": "REPORT COPIED", "time": 0.0, "life": 1.6})
			get_viewport().set_input_as_handled()
			return
	if state == State.DRAFT:
		if event.keycode == KEY_R:
			reroll_draft()
			get_viewport().set_input_as_handled()
			return
		var choice := -1
		if event.keycode in [KEY_1, KEY_KP_1]:
			choice = 0
		elif event.keycode in [KEY_2, KEY_KP_2]:
			choice = 1
		elif event.keycode in [KEY_3, KEY_KP_3]:
			choice = 2
		if choice >= 0:
			choose_draft(choice)
			get_viewport().set_input_as_handled()
			return
	## Volume, from the keyboard, at any time — the browser build has a settings
	## panel and this build has downloads, so the minimum is that a player can
	## turn it down without leaving the game or opening the Windows mixer.
	if audio != null:
		if event.keycode == KEY_M:
			audio.toggle_mute()
			_fx({"kind": "banner", "text": "MUTED" if audio.muted else "UNMUTED",
				"time": 0.0, "life": 1.0})
			get_viewport().set_input_as_handled()
			return
		if event.keycode in [KEY_MINUS, KEY_KP_SUBTRACT, KEY_EQUAL, KEY_KP_ADD]:
			var step := -0.1 if event.keycode in [KEY_MINUS, KEY_KP_SUBTRACT] else 0.1
			audio.set_volume("master", float(audio.volumes.master) + step)
			_fx({"kind": "banner",
				"text": "VOLUME %d%%" % roundi(float(audio.volumes.master) * 100.0),
				"time": 0.0, "life": 1.0})
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed("pause"):
		if state == State.PLAY:
			_set_state(State.PAUSE)
		elif state == State.PAUSE:
			_set_state(State.PLAY)
		get_viewport().set_input_as_handled()

## The layout editor. Returns whether it consumed the event.
##
## Everything here writes to `SkyGearHUD.layout`, which is the same object the
## HUD draws from — so a drag is visible on the panel being dragged rather than
## on a wireframe of it. That is the whole point: the thing being positioned is
## the real panel with the real content at the real resolution.
func _layout_input(event: InputEvent) -> bool:
	var view: Vector2 = hud.size
	var where: Vector2 = hud.get_local_mouse_position()
	if SkyGearHUD.layout == null:
		SkyGearHUD.layout = SkyGearHudLayout.load_layout()
	var layout := SkyGearHUD.layout
	var plate_rect: Rect2 = SkyGearHUD.hud_plates(view).get(layout_pick, Rect2())

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var hit := SkyGearHUD.pick_at(view, where, layout_pick)
			if hit.is_empty():
				return true
			layout_pick = str(hit.plate)
			layout_item = str(hit.item)
			_layout_drag = layout_pick
			_layout_resize = bool(hit.resize)
			_layout_from = where
			layout_saved = false
		else:
			_layout_drag = ""
		hud.queue_redraw()
		return true

	if event is InputEventMouseMotion and _layout_drag != "":
		var delta: Vector2 = where - _layout_from
		_layout_from = where
		if _layout_resize:
			layout.resize(layout_pick, layout_item, delta)
		else:
			layout.nudge(layout_pick, layout_item, delta)
		layout_saved = false
		hud.queue_redraw()
		return true

	if event is not InputEventKey or not event.pressed:
		return event is InputEventMouseMotion
	var key := event as InputEventKey
	## Ctrl+S and Ctrl+R rather than S and R, because a layout you have spent two
	## minutes on should not be resettable by leaning on the keyboard.
	if key.ctrl_pressed and key.keycode == KEY_S:
		layout_saved = layout.save()
		hud.queue_redraw()
		return true
	if key.ctrl_pressed and key.keycode == KEY_R:
		layout.reset()
		layout_item = ""
		layout_saved = false
		hud.queue_redraw()
		return true
	## Tab walks plates; Enter drops into the elements inside one and Escape
	## comes back out. Two levels, one key each.
	if key.keycode == KEY_TAB:
		var step: int = -1 if key.shift_pressed else 1
		if layout_item == "":
			var order: Array = SkyGearHudLayout.ORDER
			var at: int = maxi(0, order.find(layout_pick))
			layout_pick = order[(at + step + order.size()) % order.size()]
		else:
			var items := layout.items_of(layout_pick)
			var at2: int = maxi(0, items.find(layout_item))
			layout_item = items[(at2 + step + items.size()) % items.size()]
		hud.queue_redraw()
		return true
	if key.keycode in [KEY_ENTER, KEY_KP_ENTER]:
		var items2 := layout.items_of(layout_pick)
		if layout_item == "" and not items2.is_empty():
			layout_item = items2[0]
		hud.queue_redraw()
		return true
	if key.keycode == KEY_ESCAPE:
		if layout_item != "":
			layout_item = ""
			hud.queue_redraw()
			return true
		layout_edit = false
		hud.queue_redraw()
		return true
	if key.keycode == KEY_A:
		var anchors: Array = SkyGearHudLayout.ANCHORS
		var entry: Dictionary = layout.plates.get(layout_pick, {}) if layout_item == "" \
			else layout._bag(layout_pick).get(layout_item, {})
		if not entry.is_empty():
			var current := str(entry.anchor)
			layout.set_anchor(layout_pick, layout_item,
				anchors[(maxi(0, anchors.find(current)) + 1) % anchors.size()],
				view, plate_rect)
			layout_saved = false
		hud.queue_redraw()
		return true
	## C centres the selected element in its plate, which is the single most
	## common thing anyone wants from a screen like this and is fiddly by hand.
	if key.keycode == KEY_C and layout_item != "":
		layout.set_anchor(layout_pick, layout_item, "centre", view, plate_rect)
		var entry2: Dictionary = layout._bag(layout_pick).get(layout_item, {})
		if not entry2.is_empty():
			entry2.offset = [0.0, float(entry2.offset[1])] if key.shift_pressed \
				else [0.0, 0.0]
		layout_saved = false
		hud.queue_redraw()
		return true
	var step_px: float = 10.0 if key.shift_pressed else 1.0
	var nudge := Vector2.ZERO
	match key.keycode:
		KEY_LEFT: nudge = Vector2(-step_px, 0)
		KEY_RIGHT: nudge = Vector2(step_px, 0)
		KEY_UP: nudge = Vector2(0, -step_px)
		KEY_DOWN: nudge = Vector2(0, step_px)
		_: return false
	if key.alt_pressed:
		layout.resize(layout_pick, layout_item, nudge)
	else:
		layout.nudge(layout_pick, layout_item, nudge)
	layout_saved = false
	hud.queue_redraw()
	return true


## 1-9 then 0, so ten rows are reachable without a cursor.
func _digit_slot(code: int) -> int:
	if code >= KEY_1 and code <= KEY_9:
		return code - KEY_1
	if code == KEY_0:
		return 9
	return -1


func _apply_rebind(event: InputEvent) -> void:
	var action: String = SkyGearKeybinds.REBINDABLE[rebinding_index][0]
	var clash := SkyGearKeybinds.rebind(action, event)
	rebind_conflict = clash
	if clash == "":
		rebinding_index = -1
	hud.queue_redraw()


func _process(delta: float) -> void:
	## Effects and the renderer keep running through a hit-stop — a frozen frame
	## with a frozen explosion on it reads as a crash, not as impact. Only the
	## simulation stops.
	_update_effects(delta)
	if state != State.PLAY:
		queue_redraw()
		return
	delta = impact.advance(delta)
	if delta <= 0.0:
		queue_redraw()
		return
	_update_cooldowns(delta)
	_update_wave(delta)
	_update_projectiles(delta)
	_update_passives(delta)
	_update_pressure(delta)
	_update_salvage(delta)
	_update_fire_fields(delta)
	run_time += delta
	_update_turrets(delta)
	_update_crew(delta)
	_update_hulk(delta)
	_process_skill_input()
	_process_basic_attack(delta)
	_process_dash_impacts()
	queue_redraw()

func is_playing() -> bool:
	return state == State.PLAY

func set_seed_text(text: String) -> void:
	## A seed a player can hand to someone else. Same idea as the browser's
	## ?seed=, and the reason card rolls draw from `rng` and never from
	## randf() at the call site.
	seed_text = text.strip_edges().to_upper()
	if seed_text == "":
		seed_text = _random_seed_text()
	rng.seed = hash(seed_text)


func _random_seed_text() -> String:
	const ALPHABET := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
	var out := ""
	var source := RandomNumberGenerator.new()
	source.randomize()
	for _i in 6:
		out += ALPHABET[source.randi_range(0, ALPHABET.length() - 1)]
	return out


func begin_run() -> void:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.queue_free()
	for prop in get_tree().get_nodes_in_group("props"):
		prop.queue_free()
	player.reset_for_run()
	player.visible = true
	wave = 0
	boiler_hp = boiler_max_hp
	skills.clear()
	projectiles.clear()
	effects.clear()
	salvage.clear()
	fire_fields.clear()
	spawn_queue.clear()
	damage_multiplier = 1.0
	pressure = 0.0
	pressure_grace = 0.0
	vent_cooldown = 0.0
	basic_cooldown = 0.0
	end_reason = ""
	opening_draft = true
	draft_options.clear()
	turrets = SkyGearLanes.make_turrets(LANE_CENTERS, BASE_Y)
	crew.clear()
	hulk = {}
	crew_timer = 2.5
	mods = SkyGearCards.fresh_mods()
	tel = SkyGearTelemetry.fresh()
	cards_taken.clear()
	rerolls = int(SkyGearData.DRAFT.rerolls)
	heal_budget = float(SkyGearData.CLOSE.heal_cap_per_sec)
	steal_budget = float(SkyGearData.CLOSE.lifesteal_cap_per_sec)
	run_time = 0.0
	src_slot = -1
	if seed_text == "":
		set_seed_text("")
	for skill in SkyGearData.STARTING_SKILLS:
		var instance := SkyGearData.make_skill(skill.shape, skill.element)
		draft_options.append({
			"kind": "skill",
			"title": SkyGearData.skill_name(instance).to_upper(),
			"text": "%s · %s" % [SkyGearData.SHAPES[instance.shape].kind, SkyGearData.ELEMENTS[instance.element].blurb],
			"color": SkyGearData.ELEMENTS[instance.element].color,
			"skill": instance,
		})
	_set_state(State.DRAFT)

## The run report. Same shape as the browser build's, because the point of it is
## that a tester pastes it into a message and the numbers mean the same thing on
## both sides — including which skill actually did the work, which is the
## question every balance conversation so far has had to guess at.
func run_report() -> String:
	var lines: Array[String] = []
	var won := state == State.VICTORY
	lines.append("SKYGEAR — Godot port")
	lines.append(("DECK HELD" if won else "BOARDED") + " — " + end_reason)
	lines.append("wave %d/%d · %s · seed %s" % [wave, SkyGearData.WAVES.size(),
		_format_time(run_time), seed_text])
	var build: Array[String] = ["Ember Cleave (auto)"]
	for skill in skills:
		build.append(SkyGearData.skill_name(skill))
	lines.append("build: " + "  /  ".join(build))
	if not cards_taken.is_empty():
		lines.append("draft: " + ", ".join(cards_taken))

	var total := float(tel.basic.damage) + float(tel.deck.damage) + float(tel.allies.damage)
	for row in tel.per:
		total += float(row.damage)
	if total > 0.0:
		lines.append("")
		lines.append("skills — damage · share · casts · kills")
		lines.append(_report_row("auto cleave", float(tel.basic.damage), total,
			int(tel.basic.casts), int(tel.basic.kills)))
		for i in tel.per.size():
			var row: Dictionary = tel.per[i]
			if str(row.shape) == "":
				continue
			lines.append(_report_row(
				SkyGearData.skill_name({"shape": row.shape, "element": row.element}),
				float(row.damage), total, int(row.casts), int(row.kills)))
		if float(tel.allies.damage) > 0.0:
			lines.append(_report_row("crew and cannons", float(tel.allies.damage), total, 0, 0))
		if float(tel.deck.damage) > 0.0:
			lines.append(_report_row("the deck", float(tel.deck.damage), total, 0, 0))
	var rt: Dictionary = tel.range_time
	var span: float = float(rt.close) + float(rt.mid) + float(rt.far) + float(rt.none)
	if span > 1.0:
		lines.append("range: %d%% close · %d%% mid · %d%% far · %d%% clear" % [
			roundi(float(rt.close) / span * 100.0), roundi(float(rt.mid) / span * 100.0),
			roundi(float(rt.far) / span * 100.0), roundi(float(rt.none) / span * 100.0)])
	lines.append("vents %d · healed %d · salvage %d · rerolls %d" % [
		int(tel.vents), roundi(float(tel.healed)), int(tel.salvage), int(tel.rerolls)])
	return "
".join(lines)


func _report_row(name: String, damage: float, total: float, casts: int, kills: int) -> String:
	return "  %-20s %7d  %d%%   %d casts  %d kills" % [
		name, roundi(damage), roundi(damage / maxf(1.0, total) * 100.0), casts, kills]


func _format_time(seconds: float) -> String:
	return "%d:%02d" % [int(seconds) / 60, int(seconds) % 60]


func copy_run_report() -> void:
	DisplayServer.clipboard_set(run_report())


func go_to_title() -> void:
	if audio != null:
		audio.stop_music()
	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.queue_free()
	for prop in get_tree().get_nodes_in_group("props"):
		prop.queue_free()
	player.visible = false
	projectiles.clear()
	effects.clear()
	_set_state(State.TITLE)

func _set_state(next_state: State) -> void:
	var was := state
	state = next_state
	state_name = State.keys()[state]
	player.controls_enabled = state == State.PLAY
	## A finished run goes on disk. One run is an anecdote; the reason v11 tracks
	## damage per skill and time at each range is so ten of them can be read as a
	## shape, and a report that dies when you press Enter cannot be.
	if was != next_state and (next_state == State.VICTORY or next_state == State.GAMEOVER):
		run_logged = SkyGearRunLog.record({
			"won": next_state == State.VICTORY,
			"wave": wave,
			"time": _format_time(run_time),
			"seed": seed_text,
			"build": _build_names(),
			"cards": cards_taken.duplicate(),
			"reason": end_reason,
			"vents": int(tel.vents),
			"healed": roundi(float(tel.healed)),
			"salvage": int(tel.salvage),
			"rerolls": int(tel.rerolls),
			"close_share": _close_share(),
			"report": run_report(),
		})
	hud.queue_redraw()


func _build_names() -> Array[String]:
	var out: Array[String] = ["Ember Cleave (auto)"]
	for skill in skills:
		out.append(SkyGearData.skill_name(skill))
	return out


## The fraction of the run spent inside close range, as a percentage. It is the
## one number that says whether the v11 loop landed, so it goes in the log on its
## own rather than only inside the report text.
func _close_share() -> int:
	var rt: Dictionary = tel.range_time
	var span: float = float(rt.close) + float(rt.mid) + float(rt.far) + float(rt.none)
	if span <= 0.0:
		return 0
	return roundi(float(rt.close) / span * 100.0)

func choose_draft(index: int) -> void:
	if state != State.DRAFT or index < 0 or index >= draft_options.size():
		return
	var option: Dictionary = draft_options[index]
	cards_taken.append(str(option.get("title", "?")))
	match option.kind:
		"card":
			if option.has("apply"):
				option.apply.call(self)
		"skill":
			if skills.size() < 4:
				skills.append(option.skill.duplicate(true))
				if voice != null:
					voice.say("slot", 1)
		"damage":
			damage_multiplier *= 1.15
		"health":
			player.max_hp += 12.0
			player.heal(12.0)
		"boiler":
			boiler_hp = minf(boiler_max_hp, boiler_hp + 60.0)
		"pressure":
			pressure = minf(99.0, pressure + 35.0)
		"dash":
			player.refund_dash(0.65)
	play_sfx("ui/card_pick.ogg", -4.0)
	draft_options.clear()
	if opening_draft:
		opening_draft = false
		start_wave(1)
	else:
		start_wave(wave + 1)

## A push wave grapples a fresh hulk to the hull. Without a fresh one per push
## the browser build spawned it once at run start and never reset it, so
## breaking it on wave 4 left it permanently dead — and wave 8 then satisfied
## its "ends when their hulk does" condition on the first frame.
## A boarding hulk grapples on and keeps sending them until it is broken.
func _begin_push(wave_number: int) -> void:
	if voice != null:
		voice.say("push", 2)
	var index := 0
	for i in wave_number:
		if bool(SkyGearData.WAVES[i].get("push", false)):
			index += 1
	hulk = SkyGearLanes.make_hulk(BOW_Y, 1.0 + maxi(0, index - 1) * 0.20)
	hulk.vulnerable = true
	play_sfx("lane/hulk_grapple.ogg", -4.0)


func start_wave(next_wave: int) -> void:
	wave = next_wave
	if audio != null:
		var is_boss := next_wave >= 1 and next_wave <= SkyGearData.WAVES.size() 			and bool(SkyGearData.WAVES[next_wave - 1].get("boss", false))
		audio.play_music(audio.track_for(next_wave, is_boss))
	if wave > SkyGearData.WAVES.size():
		if voice != null:
			voice.say("victory", 4)
		_set_state(State.VICTORY)
		return
	restow_props()
	if next_wave >= 1 and next_wave <= SkyGearData.WAVES.size():
		if bool(SkyGearData.WAVES[next_wave - 1].get("push", false)):
			_begin_push(next_wave)
	spawn_queue = _build_spawn_queue(wave)
	if voice != null and wave > 0:
		voice.say("wave_start", 1)
	wave_time = 0.0
	wave_clear_time = -1.0
	projectiles.clear()
	player.heal(4.0)
	_set_state(State.PLAY)
	play_sfx("world/wave_start.ogg", -5.0)
	_fx({"kind": "banner", "text": "WAVE %d" % wave, "time": 0.0, "life": 2.0})

func _build_spawn_queue(wave_number: int) -> Array[Dictionary]:
	var queue: Array[Dictionary] = []
	var definition: Dictionary = SkyGearData.WAVES[wave_number - 1]
	for batch in definition.batches:
		var lanes: Array = []
		var lane_spec: Variant = batch[3] if batch.size() > 3 else rng.randi_range(0, 2)
		if lane_spec is String and lane_spec == "all":
			lanes = [0, 1, 2]
		else:
			lanes = [int(lane_spec)]
		for lane_value in lanes:
			for i in int(batch[2]):
				queue.append({
					"time": float(batch[0]) + i * 0.22,
					"type": str(batch[1]),
					"lane": int(lane_value),
				})
	queue.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.time < b.time)
	return queue

func _update_wave(delta: float) -> void:
	if wave_clear_time >= 0.0:
		wave_clear_time -= delta
		if wave_clear_time <= 0.0:
			if wave >= SkyGearData.WAVES.size():
				if voice != null:
					voice.say("victory", 4)
				_set_state(State.VICTORY)
			else:
				open_draft()
		return
	wave_time += delta
	while not spawn_queue.is_empty() and float(spawn_queue[0].time) <= wave_time and enemy_count() < 64:
		var entry: Dictionary = spawn_queue.pop_front()
		spawn_enemy(entry.type, entry.lane)
	## A push wave is not over until its hulk is. Otherwise the wave that exists
	## to make you leave the objective can be won by standing on the objective.
	var push_pending := false
	if wave >= 1 and wave <= SkyGearData.WAVES.size():
		if bool(SkyGearData.WAVES[wave - 1].get("push", false)):
			push_pending = hulk.is_empty() or not bool(hulk.get("dead", false))
	if spawn_queue.is_empty() and enemy_count() == 0 and wave > 0 and not push_pending:
		wave_clear_time = 1.6
		play_sfx("world/wave_clear.ogg", -4.0)
		if voice != null:
			voice.say("wave_clear", 1)
		_fx({"kind": "banner", "text": "WAVE CLEAR", "time": 0.0, "life": 1.6})
	elif push_pending and spawn_queue.is_empty() and enemy_count() < 6 and wave > 0:
		# they keep coming while the hulk lives — that is what it is for
		for lane in LANE_CENTERS.size():
			spawn_queue.append({"time": wave_time + 1.0 + lane * 0.4,
				"type": "SCRAPPER" if lane != 1 else "SWARM", "lane": lane})

## Weighted by how much the player actually uses a slot, never absolute: the
## least-used slot keeps a real chance, because an upgrade is also how a
## neglected skill becomes worth pressing. Roughly 3:1 in favour of the skill
## carrying the run.
func pick_slot_by_use(candidates: Array) -> int:
	if candidates.is_empty():
		return -1
	if candidates.size() == 1:
		return int(candidates[0])
	var weights: Array[float] = []
	var total := 0.0
	for i in candidates:
		var w: float = 0.25 + SkyGearTelemetry.use(tel, int(i)) * 2.25
		weights.append(w)
		total += w
	var roll := rng.randf() * total
	for k in candidates.size():
		roll -= weights[k]
		if roll <= 0.0:
			return int(candidates[k])
	return int(candidates[candidates.size() - 1])


## Three upgrade cards, weighted, no duplicates, drawn from the seeded stream.
func roll_upgrade_cards(count: int) -> Array[Dictionary]:
	var available: Array = []
	for card in SkyGearCards.catalogue():
		if bool(card.can.call(self)):
			available.append(card)
	var out: Array[Dictionary] = []
	var used := {}
	for _i in count:
		var pool: Array = []
		for card in available:
			if not used.has(card.id):
				pool.append(card)
		if pool.is_empty():
			pool = available
		if pool.is_empty():
			break
		var total := 0.0
		var weights: Array[float] = []
		for card in pool:
			var w: float = maxf(0.01, float(card.weight.call(self)))
			weights.append(w)
			total += w
		var roll := rng.randf() * total
		var index := pool.size() - 1
		for k in pool.size():
			roll -= weights[k]
			if roll <= 0.0:
				index = k
				break
		var chosen: Dictionary = pool[index]
		used[chosen.id] = true
		var instance: Dictionary = chosen.make.call(self, Callable(self, "pick_slot_by_use"))
		instance["id"] = chosen.id
		instance["kind"] = "card"
		instance["rarity"] = chosen.rarity
		instance["scope"] = chosen.scope
		instance["color"] = SkyGearCards.SCOPE_COLOR[chosen.scope]
		instance["class_label"] = SkyGearCards.SCOPE_LABEL[chosen.scope]
		out.append(instance)
	return out


## Reroll. Two per RUN rather than per draft, so spending one is a decision
## about which hand was bad enough to be worth it. Refused once a card has been
## chosen, and it draws from the seeded stream so a replay that rerolls at the
## same moment sees the same second hand.
func reroll_draft() -> bool:
	if state != State.DRAFT or rerolls <= 0:
		return false
	rerolls -= 1
	tel.rerolls += 1
	var was_opening := opening_draft
	open_draft()
	opening_draft = was_opening
	return true


func open_draft() -> void:
	if voice != null:
		voice.say("draft")
	draft_options.clear()
	if skills.size() < 4:
		var shape_order: Array[String] = ["CHAIN", "RANGED_AOE", "CONE", "LINE_BURST", "RAY", "AURA", "PULSE", "SENTRY"]
		var element_order: Array[String] = ["EMBER", "FROST", "ARC", "STEAM"]
		var used_shapes: Array[String] = []
		for skill in skills:
			used_shapes.append(skill.shape)
		var cursor := rng.randi_range(0, shape_order.size() - 1)
		for i in 3:
			var shape: String = shape_order[(cursor + i) % shape_order.size()]
			var guard := 0
			while shape in used_shapes and guard < shape_order.size():
				cursor += 1
				shape = shape_order[(cursor + i) % shape_order.size()]
				guard += 1
			# One option deliberately matches the element you already run, so
			# committing to a colour across several shapes is a build rather
			# than a consolation prize.
			var element: String = element_order[rng.randi_range(0, element_order.size() - 1)]
			if i == 0 and not skills.is_empty():
				element = str(skills[rng.randi_range(0, skills.size() - 1)].element)
			var instance := SkyGearData.make_skill(shape, element)
			draft_options.append({
				"kind": "skill",
				"scope": SkyGearCards.SCOPE_NEW,
				"class_label": SkyGearCards.SCOPE_LABEL[SkyGearCards.SCOPE_NEW],
				"slot": skills.size(),
				"title": SkyGearData.skill_name(instance).to_upper(),
				"text": "%s · %s" % [SkyGearData.SHAPES[shape].kind, SkyGearData.ELEMENTS[element].blurb],
				"color": SkyGearData.ELEMENTS[element].color,
				"skill": instance,
			})
	else:
		draft_options = roll_upgrade_cards(3)
	for option in draft_options:
		if not option.has("scope"):
			option["scope"] = SkyGearCards.SCOPE_NEW
			option["class_label"] = SkyGearCards.SCOPE_LABEL[SkyGearCards.SCOPE_NEW]
		option["affects"] = SkyGearCards.affects(self, option)
	_set_state(State.DRAFT)
	play_sfx("ui/card_deal.ogg", -5.0)

func spawn_enemy(kind: String, lane: int) -> void:
	var enemy: SkyGearEnemy = ENEMY_SCENE.instantiate()
	add_child(enemy)
	enemy.global_position = Vector2(LANE_CENTERS[lane] + rng.randf_range(-58.0, 58.0), -1115.0)
	enemy.configure(self, kind, lane, wave)
	play_sfx("enemy/climb.ogg", -12.0)
	if voice != null:
		if kind == "BOSS":
			voice.say("boss_arrive", 3)
		elif not _said_first_board:
			_said_first_board = true
			voice.say("first_board", 2)

func enemy_count() -> int:
	var count := 0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy) and not enemy.dead:
			count += 1
	return count

func _process_basic_attack(delta: float) -> void:
	basic_cooldown = maxf(0.0, basic_cooldown - delta)
	if basic_cooldown > 0.0:
		return
	var target := nearest_enemy(player.global_position, 190.0)
	if target == null:
		return
	var direction := (target.global_position - player.global_position).normalized()
	_damage_cone(player.global_position, direction, 190.0, 2.443, 22.0 * damage_multiplier, "EMBER", 150.0, true)
	basic_cooldown = 0.45 * 0.8
	_fx({"kind": "arc", "position": player.global_position, "direction": direction.angle(), "radius": 190.0, "color": Color("#ff7a2f"), "time": 0.0, "life": 0.16})
	play_sfx("player/shape_cleave.ogg", -7.0)

func _process_skill_input() -> void:
	var actions := ["skill_1", "skill_2", "skill_3", "skill_4"]
	for i in mini(skills.size(), actions.size()):
		if Input.is_action_just_pressed(actions[i]):
			cast_skill(i)

## Base shape table x per-skill mods x global mods, in one place. Everything
## that fires reads this rather than the SHAPES table, so a card that says
## "+30% range" is felt by the cast, the preview and the harness alike.
func skill_stats(skill: Dictionary) -> Dictionary:
	var shape: Dictionary = SkyGearData.SHAPES[skill.shape]
	var m: Dictionary = skill.get("mods", {})
	var element: String = skill.element
	var elem_damage: float = float(mods.elem_damage.get(element, 1.0))
	var elem_cooldown: float = float(mods.elem_cooldown.get(element, 1.0))
	var out := {
		"kind": str(shape.kind),
		"damage": float(shape.damage) * float(m.get("damage", 1.0)) * elem_damage * damage_multiplier,
		"cooldown": float(shape.cooldown) * float(m.get("cooldown", 1.0)) * elem_cooldown * 0.8,
		"knock": float(shape.get("knock", 0.0)) * float(m.get("knock", 1.0)) * float(mods.knock_multiplier),
		"multi": int(m.get("multi", 1)),
		"range": float(shape.get("range", 0.0)) * float(m.get("range", 1.0)),
		"radius": float(shape.get("radius", 0.0)) * float(m.get("area", 1.0)),
		"width": float(shape.get("width", 0.0)) * float(m.get("area", 1.0)),
		"arc": float(shape.get("arc", 0.0)),
		"pierce": int(m.get("pierce", 0)),
		"jumps": int(shape.get("jumps", 0)) + int(m.get("jumps", 0)),
		"jump_range": float(shape.get("jump_range", 0.0)) * float(m.get("range", 1.0)),
		"tick_rate": float(shape.get("tick_rate", 1.0)),
	}
	# a wider cone is a shape change, not a scalar
	if out.kind == "cone":
		out.arc = (1.658 if bool(m.get("wide_cone", false)) else out.arc) * (1.0 + (float(m.get("area", 1.0)) - 1.0) * 0.55)
	elif out.kind == "arc":
		out.arc = out.arc * (1.0 + (float(m.get("area", 1.0)) - 1.0) * 0.55)
	return out


func cast_skill(index: int, aim_at = null) -> void:
	if index < 0 or index >= skills.size():
		return
	var skill: Dictionary = skills[index]
	var shape: Dictionary = SkyGearData.SHAPES[skill.shape]
	if bool(shape.get("passive", false)) or float(skill.cooldown_left) > 0.0:
		return
	var origin := player.global_position
	var target: Vector2 = aim_at if aim_at is Vector2 else aim_target()
	# An explicit aim has to steer the DIRECTION too, not only the landing point:
	# a Cleave aimed at a target it is facing away from hits nothing, which is
	# how six casts recorded six presses and zero damage.
	var direction: Vector2 = ((target - origin).normalized() if aim_at is Vector2
		else player.aim_direction)
	var st := skill_stats(skill)
	var previous_src := src_slot
	src_slot = index
	skill.casts = int(skill.get("casts", 0)) + 1
	SkyGearTelemetry.note_cast(tel, index, skill)
	# FIFTH GEAR: every fifth cast of a skill is free and doubled.
	var free_cast := false
	var damage := float(st.damage)
	if bool(mods.fifth_gear) and int(skill.casts) % 5 == 0:
		damage *= 2.0
		free_cast = true
	var shots: int = maxi(1, int(st.multi))
	if shots > 1:
		damage *= 0.7
	var land := origin
	for _shot in shots:
		land = _resolve_cast(st, skill, origin, direction, target, damage)
	# Every shape must be able to bite the hulk, or breaking one is the job of
	# whichever weapon happens to be shaped like a structure-killer.
	hulk_splash(land, damage * float(shots))
	# RESIDUE: a burning field wherever the shape landed.
	if float(mods.residue) > 0.0:
		_field({"position": land, "radius": 62.0 + 22.0 * float(mods.residue),
			"dps": 13.0 * float(mods.residue), "time": 2.0, "tick": 0.0})
	skill.cooldown_left = 0.0 if free_cast else float(st.cooldown)
	player.attack_time = 0.26
	play_sfx(_shape_sound(skill.shape), -5.0)
	src_slot = previous_src


func _resolve_cast(st: Dictionary, skill: Dictionary, origin: Vector2, direction: Vector2, target_in: Vector2, damage: float) -> Vector2:
	var target := target_in
	var shape: Dictionary = SkyGearData.SHAPES[skill.shape]
	var land := origin
	match str(st.kind):
		"arc":
			_damage_cone(origin, direction, float(st.range), float(st.arc), damage, skill.element, float(st.knock), true)
			_fx({"kind": "arc", "position": origin, "direction": direction.angle(), "radius": float(st.range), "color": SkyGearData.ELEMENTS[skill.element].color, "time": 0.0, "life": 0.2, "follow": true})
			land = origin + direction * float(st.range) * 0.62
		"line":
			var end := origin + direction * float(st.range)
			_damage_line(origin, end, float(st.width), damage, skill.element, float(st.knock), true)
			_fx({"kind": "line", "from": origin, "to": end, "color": SkyGearData.ELEMENTS[skill.element].color, "time": 0.0, "life": 0.18})
			land = origin + direction * float(st.range) * 0.5
		"cone":
			_damage_cone(origin, direction, float(st.range), float(st.arc), damage, skill.element, float(st.knock), true)
			_fx({"kind": "cone", "position": origin, "direction": direction.angle(), "radius": float(st.range), "arc": float(st.arc), "color": SkyGearData.ELEMENTS[skill.element].color, "time": 0.0, "life": 0.22, "follow": true})
			land = origin + direction * float(st.range) * 0.55
		"aoe":
			var offset := target - origin
			if offset.length() > float(st.range):
				target = origin + offset.normalized() * float(st.range)
			_damage_circle(target, float(st.radius), damage, skill.element, float(st.knock), true, true)
			_fx({"kind": "circle", "position": target, "radius": float(st.radius), "color": SkyGearData.ELEMENTS[skill.element].color, "time": 0.0, "life": 0.28})
			land = target
		"chain":
			land = _cast_chain(origin, target, st, skill.element, damage)
		"ray":
			var end := origin + direction * float(st.range)
			_damage_line(origin, end, float(st.width), damage * 4.0, skill.element, float(st.knock), true)
			_fx({"kind": "beam", "from": origin, "to": end, "color": SkyGearData.ELEMENTS[skill.element].color, "time": 0.0, "life": 0.32})
			land = origin + direction * float(st.range) * 0.5
	return land

func _cast_chain(origin: Vector2, target_position: Vector2, st: Dictionary, element: String, damage: float) -> Vector2:
	var current: SkyGearEnemy = nearest_enemy(target_position, float(st.range))
	if current == null:
		current = nearest_enemy(origin, float(st.range))
	if current == null:
		return origin
	var visited := {}
	var from := origin
	var jump_count := int(st.jumps) + (1 if element == "ARC" else 0)
	for jump in jump_count:
		if current == null:
			break
		visited[current.get_instance_id()] = true
		damage_enemy(current, damage * pow(0.85, jump), element, float(st.knock), from, true)
		_fx({"kind": "line", "from": from, "to": current.global_position, "color": SkyGearData.ELEMENTS[element].color, "time": 0.0, "life": 0.22})
		from = current.global_position
		current = nearest_enemy_excluding(from, float(st.jump_range), visited)
	return from

func _update_cooldowns(delta: float) -> void:
	vent_cooldown = maxf(0.0, vent_cooldown - delta)
	for skill in skills:
		skill.cooldown_left = maxf(0.0, float(skill.cooldown_left) - delta)

func _update_passives(delta: float) -> void:
	for skill in skills:
		var shape: Dictionary = SkyGearData.SHAPES[skill.shape]
		if not bool(shape.get("passive", false)):
			continue
		var timer := float(skill.get("passive_timer", 0.0)) - delta
		if timer > 0.0:
			skill.passive_timer = timer
			continue
		# A passive has no press, so its damage is all it can be judged on —
		# attribute it to its slot the same way a cast is.
		var previous_src := src_slot
		src_slot = skills.find(skill)
		var st := skill_stats(skill)
		match str(st.kind):
			"aura":
				_damage_circle(player.global_position, float(st.radius), float(st.damage), skill.element, 0.0, true, false)
				skill.passive_timer = 1.0 / maxf(0.2, float(st.tick_rate))
			"pulse":
				_damage_circle(player.global_position, float(st.radius), float(st.damage), skill.element, float(st.knock), true, false)
				_fx({"kind": "circle", "follow": true, "position": player.global_position, "radius": float(st.radius), "color": SkyGearData.ELEMENTS[skill.element].color, "time": 0.0, "life": 0.3})
				skill.passive_timer = float(st.cooldown)
			"sentry":
				var target := nearest_enemy(player.global_position, float(st.range))
				if target != null:
					damage_enemy(target, float(st.damage), skill.element, 60.0, player.global_position, true)
					_fx({"kind": "line", "from": player.global_position, "to": target.global_position, "color": SkyGearData.ELEMENTS[skill.element].color, "time": 0.0, "life": 0.12})
				skill.passive_timer = 0.7
		src_slot = previous_src

## The single funnel for damage dealt to a boarder. Crit, brittle, lifesteal,
## pressure and telemetry all happen here, once, because every other version of
## this project put them in four places and one of them was always wrong.
func damage_enemy(enemy: SkyGearEnemy, amount: float, element: String, knock: float, origin: Vector2, grants_pressure: bool) -> float:
	if not is_instance_valid(enemy) or enemy.dead:
		return 0.0
	var scaled := amount
	if enemy.slow_time > 0.0:
		scaled *= 1.0 + float(mods.slow_damage)
	var crit := rng.randf() < float(mods.crit_chance)
	if crit:
		scaled *= 2.0
	var hit_at := enemy.global_position
	var dealt := enemy.take_damage(scaled, origin, element, knock * float(mods.knock_multiplier))
	var killed := enemy.dead or enemy.hp <= 0.0
	if impact != null and dealt >= 1.0:
		impact.note_hit(dealt, killed)
		## And the picture of it. The renderer owns the particles; the simulation
		## only says a hit of this size, of this element, landed here.
		if view != null:
			view.impact_at(hit_at, element, dealt)
	if dealt >= 1.0:
		# a lane cannon fires no element, so this cannot assume the table has one
		var tint: Color = Color("#eee5d5")
		if SkyGearData.ELEMENTS.has(element):
			tint = SkyGearData.ELEMENTS[element].color
		add_floater("%d" % roundi(dealt), hit_at, Color("#ffe08a") if crit else tint, crit)
	SkyGearTelemetry.note_damage(tel, src_slot, dealt, killed)
	if crit and float(mods.crit_explode) > 0.0:
		_damage_circle(enemy.global_position, 70.0, 20.0, element, 60.0, false, false)
	if grants_pressure:
		register_damage(dealt, enemy.global_position)
	return dealt

func register_damage(amount: float, hit_position: Vector2) -> void:
	if amount <= 0.0:
		return
	# Close range is the condition on BOTH payouts: pressure and lifesteal. In
	# the browser build this was the fix for a run that healed faster than three
	# lanes of boarders could hurt it, from maximum range.
	if player.global_position.distance_to(hit_position) <= float(SkyGearData.CLOSE.range):
		pressure = minf(100.0, pressure + amount * float(SkyGearData.CLOSE.pressure_per_damage) * float(mods.pressure_rate))
		pressure_grace = float(SkyGearData.CLOSE.pressure_grace)
		player.set_pressure(pressure)
		if float(mods.lifesteal) > 0.0:
			heal_player(amount * float(mods.lifesteal), "steal")


## One ceiling on all healing, as a refilling budget. Vent, salvage, field
## dressing and cards all draw from it; lifesteal has a tighter one inside it.
## A cap on the SUM is the only version of this that does not need re-tuning
## every time a healing card is added.
func heal_player(amount: float, source: String) -> float:
	if amount <= 0.0 or player.hp <= 0.0:
		return 0.0
	var allowed := amount
	if source == "steal":
		allowed = minf(allowed, steal_budget)
		steal_budget -= allowed
	if source != "wave":
		allowed = minf(allowed, heal_budget)
		heal_budget -= allowed
	if allowed <= 0.0:
		return 0.0
	var healed := player.heal(allowed)
	tel.healed += healed
	# Healing has to be as legible as damage or the close-quarters loop is
	# invisible: the whole point of pressure, vent and salvage is that you can
	# see them paying you back for standing in range.
	if healed >= 1.0:
		add_floater("+%d" % roundi(healed), player.global_position, Color("#37f0c8"))
	return healed

func _damage_circle(center: Vector2, radius: float, damage: float, element: String, knock: float, grants_pressure: bool, hits_props: bool) -> void:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy) and not enemy.dead and enemy.global_position.distance_to(center) <= radius + enemy.radius:
			damage_enemy(enemy, damage, element, knock, center, grants_pressure)
	if hits_props:
		_damage_props_circle(center, radius, damage)

func _damage_cone(origin: Vector2, direction: Vector2, radius: float, arc: float, damage: float, element: String, knock: float, hits_props: bool) -> void:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or enemy.dead:
			continue
		var target_delta: Vector2 = enemy.global_position - origin
		if target_delta.length() <= radius + enemy.radius and absf(direction.angle_to(target_delta.normalized())) <= arc * 0.5:
			damage_enemy(enemy, damage, element, knock, origin, true)
	if hits_props:
		for prop in get_tree().get_nodes_in_group("props"):
			if is_instance_valid(prop) and prop.is_targetable():
				var prop_delta: Vector2 = prop.global_position - origin
				if prop_delta.length() <= radius + prop.radius and absf(direction.angle_to(prop_delta.normalized())) <= arc * 0.5:
					prop.damage(damage)

func _damage_line(start: Vector2, end: Vector2, width: float, damage: float, element: String, knock: float, hits_props: bool) -> void:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy) and not enemy.dead and _distance_to_segment(enemy.global_position, start, end) <= width + enemy.radius:
			damage_enemy(enemy, damage, element, knock, start, true)
	if hits_props:
		for prop in get_tree().get_nodes_in_group("props"):
			if is_instance_valid(prop) and prop.is_targetable() and _distance_to_segment(prop.global_position, start, end) <= width + prop.radius:
				prop.damage(damage)

func _damage_props_circle(center: Vector2, radius: float, damage: float) -> void:
	for prop in get_tree().get_nodes_in_group("props"):
		if is_instance_valid(prop) and prop.is_targetable() and prop.global_position.distance_to(center) <= radius + prop.radius:
			prop.damage(damage)

func nearest_enemy(origin: Vector2, max_distance: float) -> SkyGearEnemy:
	return nearest_enemy_excluding(origin, max_distance, {})

func nearest_enemy_excluding(origin: Vector2, max_distance: float, excluded: Dictionary) -> SkyGearEnemy:
	var nearest: SkyGearEnemy
	var best := max_distance
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or enemy.dead or excluded.has(enemy.get_instance_id()):
			continue
		var distance := origin.distance_to(enemy.global_position)
		if distance < best:
			best = distance
			nearest = enemy
	return nearest

func on_enemy_killed(enemy: SkyGearEnemy) -> void:
	var close_kill := enemy.global_position.distance_to(player.global_position) <= float(SkyGearData.CLOSE.range)
	if close_kill:
		pressure = minf(100.0, pressure + 9.0)
		pressure_grace = float(SkyGearData.CLOSE.pressure_grace)
		player.refund_dash(float(SkyGearData.CLOSE.dash_refund))
		if rng.randf() < float(SkyGearData.CLOSE.scrap_chance):
			_scrap({"position": enemy.global_position, "heal": float(SkyGearData.CLOSE.scrap_heal), "time": 12.0})
			tel.salvage += 1
	if float(mods.scrap_chance) > 0.0 and rng.randf() < float(mods.scrap_chance):
		_scrap({"position": enemy.global_position, "heal": 12.0, "time": 12.0})
		tel.salvage += 1
	if float(mods.kill_explode) > 0.0:
		_damage_circle(enemy.global_position, 80.0, float(mods.kill_explode), "EMBER", 70.0, false, false)
	if float(mods.kill_autofire) > 0.0 and rng.randf() < float(mods.kill_autofire) and skills.size() > 0:
		var previous: float = float(skills[0].cooldown_left)
		skills[0].cooldown_left = 0.0
		cast_skill(0, enemy.global_position)
		skills[0].cooldown_left = previous
	play_sfx("enemy/death_heavy_1.ogg" if enemy.kind in ["ARMORED", "BOSS"] else "enemy/death_light_1.ogg", -8.0)
	_fx({"kind": "burst", "position": enemy.global_position, "radius": enemy.radius * 2.5, "color": Color("#ff9a5a"), "time": 0.0, "life": 0.25})

func _update_pressure(delta: float) -> void:
	var close_range := float(SkyGearData.CLOSE.range)
	var nearby := 0
	var nearest := -1.0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or enemy.dead:
			continue
		var d: float = enemy.global_position.distance_to(player.global_position)
		if nearest < 0.0 or d < nearest:
			nearest = d
		if d <= close_range * 0.85:
			nearby += 1
	SkyGearTelemetry.note_range(tel, delta, nearest, close_range)
	# both budgets refill continuously
	heal_budget = minf(float(SkyGearData.CLOSE.heal_cap_per_sec), heal_budget + float(SkyGearData.CLOSE.heal_cap_per_sec) * delta)
	steal_budget = minf(float(SkyGearData.CLOSE.lifesteal_cap_per_sec), steal_budget + float(SkyGearData.CLOSE.lifesteal_cap_per_sec) * delta)
	if nearby >= 2:
		pressure = minf(100.0, pressure + float(SkyGearData.CLOSE.pressure_idle) * float(mods.pressure_rate) * delta * (1.0 + (nearby - 2) * 0.25))
		pressure_grace = float(SkyGearData.CLOSE.pressure_grace)
	else:
		pressure_grace = maxf(0.0, pressure_grace - delta)
		if pressure_grace <= 0.0:
			pressure = maxf(0.0, pressure - float(SkyGearData.CLOSE.pressure_decay) * delta)
	# FIELD DRESSING pays below 60% health only: a heal that cannot be banked at
	# full health is a comeback, one that runs all run is a difficulty setting.
	if float(mods.dressing) > 0.0 and pressure >= 50.0 and player.hp < player.max_hp * 0.60:
		heal_player(float(mods.dressing) * delta, "regen")
	if pressure >= 100.0 and vent_cooldown <= 0.0:
		vent_pressure()
	player.set_pressure(pressure)

func vent_pressure() -> void:
	pressure = 0.0
	pressure_grace = 0.0
	vent_cooldown = float(SkyGearData.CLOSE.vent_cooldown)
	var radius := float(SkyGearData.CLOSE.vent_radius) * float(mods.vent_radius)
	# `grants_pressure` is false on purpose: the vent refilling its own gauge
	# from its own blast makes venting self-sustaining in a crowd, which is the
	# healing failure this whole system was rebuilt to remove.
	_damage_circle(player.global_position, radius, float(SkyGearData.CLOSE.vent_damage) * float(mods.vent_damage), "STEAM", float(SkyGearData.CLOSE.vent_knock), false, false)
	heal_player(float(SkyGearData.CLOSE.vent_heal) + float(mods.vent_heal), "vent")
	tel.vents += 1
	_fx({"kind": "circle", "follow": true, "position": player.global_position, "radius": radius, "color": Color("#f2eaff"), "time": 0.0, "life": 0.5})
	if impact != null:
		impact.note_explosion(7.0)
	play_sfx("player/vent.ogg", -2.0)
	if voice != null:
		voice.say("vent")

func damage_player(amount: float, _source: String = "") -> void:
	if state != State.PLAY:
		return
	if player.take_damage(amount):
		play_sfx("player/hurt.ogg", -3.0)
		if impact != null:
			## Taking one shakes harder than landing one. The browser does the
			## same and it is the difference between a hit you notice and a
			## health bar you notice afterwards.
			impact.add_shake(4.5 + amount * 0.12)
		add_floater("-%d" % roundi(amount), player.global_position, Color("#ff4d37"), true)
		if voice != null and player.hp <= player.max_hp * 0.32 and player.hp > 0.0:
			voice.say("hurt_low", 2)
		_fx({"kind": "burst", "position": player.global_position, "radius": 65.0, "color": Color("#ff4d37"), "time": 0.0, "life": 0.18})
		if player.hp <= 0.0:
			end_reason = "The captain fell on wave %d." % wave
			if voice != null:
				voice.say("defeat", 4)
			_set_state(State.GAMEOVER)

func damage_boiler(amount: float) -> void:
	if voice != null and not _said_boiler_low and boiler_hp <= boiler_max_hp * 0.4:
		_said_boiler_low = true
		voice.say("boiler_low", 2)
	if state != State.PLAY:
		return
	boiler_hp = maxf(0.0, boiler_hp - amount)
	play_sfx("world/boiler_hurt.ogg", -6.0)
	_fx({"kind": "burst", "position": BOILER_POSITION, "radius": 90.0, "color": Color("#ff7a2f"), "time": 0.0, "life": 0.2})
	if boiler_hp <= 0.0:
		end_reason = "The Boiler was destroyed on wave %d." % wave
		if voice != null:
			voice.say("defeat", 4)
		_set_state(State.GAMEOVER)

func spawn_enemy_bolt(origin: Vector2, target: Vector2, damage: float, speed: float) -> void:
	var direction := (target - origin).normalized()
	_bolt({
		"position": origin,
		"velocity": direction * speed,
		"damage": damage,
		"life": 4.0,
		"trail": [origin],
	})

func _update_projectiles(delta: float) -> void:
	for i in range(projectiles.size() - 1, -1, -1):
		var bolt: Dictionary = projectiles[i]
		bolt.life = float(bolt.life) - delta
		bolt.position += bolt.velocity * delta
		var trail: Array = bolt.trail
		trail.push_front(bolt.position)
		if trail.size() > 9:
			trail.pop_back()
		var remove := float(bolt.life) <= 0.0 or not DECK_RECT.grow(80.0).has_point(bolt.position)
		if not remove and bolt.position.distance_to(player.global_position) <= 27.0:
			damage_player(float(bolt.damage), "bolt")
			remove = true
		if not remove and bolt.position.distance_to(BOILER_POSITION) <= boiler_radius:
			damage_boiler(float(bolt.damage))
			remove = true
		if not remove:
			for prop in get_tree().get_nodes_in_group("props"):
				if is_instance_valid(prop) and prop.is_targetable() and bolt.position.distance_to(prop.global_position) <= prop.radius + 8.0:
					prop.damage(float(bolt.damage))
					remove = true
					break
		if remove:
			projectiles.remove_at(i)

func restow_props() -> void:
	for prop in get_tree().get_nodes_in_group("props"):
		if is_instance_valid(prop):
			prop.dead = true
			prop.queue_free()
	for entry in SkyGearData.PROP_LAYOUT:
		var prop: SkyGearProp = PROP_SCENE.instantiate()
		add_child(prop)
		prop.global_position = entry.position
		prop.configure(self, entry.type)

func on_prop_destroyed(prop: SkyGearProp) -> void:
	if prop.prop_type == "crate":
		_scrap({"position": prop.global_position, "heal": 12.0, "time": 12.0})
		play_sfx("prop/crate_break_1.ogg", -5.0)
	elif prop.prop_type == "lantern":
		_field({"position": prop.global_position, "time": 6.0, "tick": 0.0})
		play_sfx("prop/lantern_break.ogg", -5.0)
	_fx({"kind": "burst", "position": prop.global_position, "radius": 70.0, "color": Color("#e8c376"), "time": 0.0, "life": 0.25})

func explode_keg(prop: SkyGearProp) -> void:
	if voice != null:
		voice.say("keg")
	if impact != null:
		impact.note_explosion(11.0)
	var center := prop.global_position
	_damage_circle(center, 175.0, 78.0, "STEAM", 380.0, false, false)
	if center.distance_to(player.global_position) <= 192.0:
		damage_player(26.0, "keg")
	_damage_props_circle(center, 175.0, 78.0)
	_fx({"kind": "burst", "position": center, "radius": 175.0, "color": Color("#ffe08a"), "time": 0.0, "life": 0.45})
	play_sfx("prop/keg_blow.ogg", -1.0)

func _update_salvage(delta: float) -> void:
	for i in range(salvage.size() - 1, -1, -1):
		var item: Dictionary = salvage[i]
		item.time = float(item.time) - delta
		if item.position.distance_to(player.global_position) <= 42.0:
			player.heal(float(item.heal))
			play_sfx("player/pickup.ogg", -5.0)
			salvage.remove_at(i)
		elif float(item.time) <= 0.0:
			salvage.remove_at(i)

func _update_fire_fields(delta: float) -> void:
	for i in range(fire_fields.size() - 1, -1, -1):
		var field: Dictionary = fire_fields[i]
		field.time = float(field.time) - delta
		field.tick = float(field.tick) - delta
		if float(field.tick) <= 0.0:
			field.tick = 0.25
			_damage_circle(field.position, 78.0, 7.5, "EMBER", 0.0, false, false)
			if field.position.distance_to(player.global_position) <= 78.0:
				damage_player(3.0, "fire")
		if float(field.time) <= 0.0:
			fire_fields.remove_at(i)

func _on_dash_started() -> void:
	dash_hit_ids.clear()
	play_sfx("player/dash.ogg", -4.0)
	if voice != null:
		voice.maybe("dash", 1.0 / 6.0)

func _process_dash_impacts() -> void:
	if player.dash_time_left <= 0.0:
		return
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or enemy.dead:
			continue
		var id := enemy.get_instance_id()
		if not dash_hit_ids.has(id) and enemy.global_position.distance_to(player.global_position) <= enemy.radius + 30.0:
			dash_hit_ids[id] = true
			damage_enemy(enemy, 30.0 * damage_multiplier, "STEAM", 260.0, player.global_position, true)
	for prop in get_tree().get_nodes_in_group("props"):
		if not is_instance_valid(prop) or not prop.is_targetable():
			continue
		var id := prop.get_instance_id()
		if not dash_hit_ids.has(id) and prop.global_position.distance_to(player.global_position) <= prop.radius + 28.0:
			dash_hit_ids[id] = true
			if prop.prop_type == "keg":
				prop.light_fuse()
			else:
				prop.damage(30.0)

## --- deck cannons ---------------------------------------------------------
## One per lane, gating it. Boarders have to break it to pass, which is what
## makes a lane a lane rather than a stripe on the floor.
func _update_turrets(delta: float) -> void:
	## The lane call. Checked here rather than in the HUD because the HUD is a
	## view and a view that fires audio is a view that fires audio twice the
	## moment anything else draws.
	if voice != null and state == State.PLAY:
		for enemy in get_tree().get_nodes_in_group("enemies"):
			if not is_instance_valid(enemy) or enemy.dead:
				continue
			var depth: float = (enemy.global_position.y - DECK_RECT.position.y) / DECK_RECT.size.y
			if depth > 0.80:
				voice.say("lane_critical", 2)
				break
	for t in turrets:
		t.flash = maxf(0.0, float(t.flash) - delta)
		t.fire_flash = maxf(0.0, float(t.fire_flash) - delta)
		if bool(t.dead):
			continue
		t.cooldown = maxf(0.0, float(t.cooldown) - delta)
		# the boarder nearest the Boiler in this lane, so a cannon covers the
		# thing behind it rather than the thing in front of it
		var best: SkyGearEnemy = null
		var best_y := -99999.0
		for enemy in get_tree().get_nodes_in_group("enemies"):
			if not is_instance_valid(enemy) or enemy.dead or enemy.state == "climb":
				continue
			if enemy.lane != int(t.lane):
				continue
			if enemy.global_position.distance_to(t.position) > SkyGearLanes.TURRET.range:
				continue
			if enemy.global_position.y > best_y:
				best_y = enemy.global_position.y
				best = enemy
		if best == null:
			continue
		t.angle = (best.global_position - Vector2(t.position)).angle()
		if float(t.cooldown) > 0.0:
			continue
		t.cooldown = SkyGearLanes.TURRET.cooldown
		t.fire_flash = 0.14
		var previous := src_slot
		src_slot = -3                     # allies: the ship's own guns
		damage_enemy(best, SkyGearLanes.TURRET.damage, "", 90.0, t.position, false)
		src_slot = previous
		play_sfx("lane/cannon_fire_1.ogg", -9.0)


func damage_turret(t: Dictionary, amount: float) -> void:
	if bool(t.dead):
		return
	t.hp = maxf(0.0, float(t.hp) - amount)
	t.flash = 0.16
	if float(t.hp) <= 0.0:
		t.dead = true
		play_sfx("lane/cannon_down_1.ogg", -4.0)
		if voice != null:
			voice.say("cannon_down", 1)
		_fx({"kind": "burst", "position": t.position, "radius": 120.0,
			"color": Color("#ff9a5a"), "time": 0.0, "life": 0.4})
	else:
		play_sfx("lane/cannon_hurt_1.ogg", -12.0)


## Everything it called in the first beat is vented with it, so the turn is a
## clear moment and not a moment spent fighting six swarmers.
func on_boss_turn(boss) -> void:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy) and enemy != boss and not enemy.dead:
			enemy.hp = 0.0
			enemy.kill()
	_fx({"kind": "circle", "position": boss.global_position, "radius": 420.0,
		"color": Color("#ffd36b"), "time": 0.0, "life": 0.9})
	_fx({"kind": "banner", "text": "IT TURNS", "time": 0.0, "life": 2.4})
	play_sfx("enemy/boss_roar.ogg", -1.0)
	if voice != null:
		voice.say("boss_turn", 3)


func nearest_crew(origin: Vector2, max_distance: float) -> Dictionary:
	var best: Dictionary = {}
	var best_distance := max_distance
	for c in crew:
		if bool(c.dead):
			continue
		var d: float = Vector2(c.position).distance_to(origin)
		if d < best_distance:
			best_distance = d
			best = c
	return best


func turret_in_lane(lane: int) -> Dictionary:
	for t in turrets:
		if int(t.lane) == lane and not bool(t.dead):
			return t
	return {}


## --- crew -----------------------------------------------------------------
## Your own boarders, pushing the other way. They are minions: they hold a lane
## while you are somewhere else, and on a push they are what breaks the hulk if
## you do not.
func _update_crew(delta: float) -> void:
	var pushing := not hulk.is_empty() and not bool(hulk.get("dead", true))
	crew_timer -= delta
	if crew_timer <= 0.0:
		crew_timer = SkyGearLanes.CREW.push_every if pushing else SkyGearLanes.CREW.every
		for lane in LANE_CENTERS.size():
			for _i in int(SkyGearLanes.CREW.per_wave):
				crew.append(SkyGearLanes.make_crew(lane, LANE_CENTERS, BASE_Y, rng))
		play_sfx("lane/crew_muster.ogg", -10.0)
		if voice != null:
			voice.say("crew_muster")

	for i in range(crew.size() - 1, -1, -1):
		var c: Dictionary = crew[i]
		c.flash = maxf(0.0, float(c.flash) - delta)
		if bool(c.dead):
			crew.remove_at(i)
			continue
		# nearest boarder in this crewman's lane, else march at the hulk
		var target: SkyGearEnemy = null
		var best := 1e9
		for enemy in get_tree().get_nodes_in_group("enemies"):
			if not is_instance_valid(enemy) or enemy.dead or enemy.state == "climb":
				continue
			if enemy.lane != int(c.lane):
				continue
			var d: float = enemy.global_position.distance_to(c.position)
			if d < best:
				best = d
				target = enemy
		var goal: Vector2 = Vector2(float(LANE_CENTERS[int(c.lane)]), BOW_Y + 260.0)
		var reach := float(SkyGearLanes.CREW.reach)
		if target != null:
			goal = target.global_position
		elif not hulk.is_empty() and not bool(hulk.dead) and bool(hulk.vulnerable):
			goal = hulk.position
			reach = float(hulk.radius) + 40.0
		var to_goal: Vector2 = goal - Vector2(c.position)
		var distance := to_goal.length()
		match str(c.state):
			"move":
				if distance <= reach:
					c.state = "windup"
					c.state_time = SkyGearLanes.CREW.windup
				else:
					c.position = Vector2(c.position) + to_goal.normalized() * float(SkyGearLanes.CREW.speed) * delta
			"windup":
				c.state_time = float(c.state_time) - delta
				if float(c.state_time) <= 0.0:
					c.state = "recover"
					c.state_time = SkyGearLanes.CREW.recover
					var previous := src_slot
					src_slot = -3
					if target != null and target.global_position.distance_to(c.position) <= reach + 20.0:
						damage_enemy(target, SkyGearLanes.CREW.damage, "", 60.0, c.position, false)
						play_sfx("lane/crew_attack_1.ogg", -14.0)
					elif not hulk.is_empty() and not bool(hulk.dead) and bool(hulk.vulnerable) \
							and Vector2(hulk.position).distance_to(c.position) <= reach + 30.0:
						damage_hulk(SkyGearLanes.CREW.siege)
					src_slot = previous
			"recover":
				c.state_time = float(c.state_time) - delta
				if float(c.state_time) <= 0.0:
					c.state = "move"


## Called from the lane update once a lane is genuinely breaking. The HUD
## already shouts it; this is the crew shouting it too.
func note_lane_critical() -> void:
	if voice != null:
		voice.say("lane_critical", 2)


func hurt_crew(c: Dictionary, amount: float) -> void:
	if bool(c.dead):
		return
	c.hp = float(c.hp) - amount
	c.flash = 0.14
	if float(c.hp) <= 0.0:
		c.dead = true
		play_sfx("lane/crew_down_1.ogg", -12.0)
		if voice != null:
			voice.say("crew_down")


## --- the boarding hulk ------------------------------------------------------
func _update_hulk(delta: float) -> void:
	if hulk.is_empty():
		return
	hulk.flash = maxf(0.0, float(hulk.get("flash", 0.0)) - delta)


func damage_hulk(amount: float) -> void:
	if hulk.is_empty() or bool(hulk.dead) or not bool(hulk.vulnerable):
		return
	hulk.hp = maxf(0.0, float(hulk.hp) - amount)
	hulk.flash = 0.12
	play_sfx("lane/hulk_hit.ogg", -14.0)
	if float(hulk.hp) <= 0.0:
		hulk.dead = true
		play_sfx("lane/hulk_break.ogg", -2.0)
		_fx({"kind": "burst", "position": hulk.position, "radius": 260.0,
			"color": Color("#ffd36b"), "time": 0.0, "life": 0.6})


## A shape that lands on or near the hulk hurts it, so every weapon can bite it
## rather than only the ones that happen to target structures.
func hulk_splash(at: Vector2, amount: float) -> void:
	if hulk.is_empty() or bool(hulk.dead) or not bool(hulk.vulnerable):
		return
	if Vector2(hulk.position).distance_to(at) < float(hulk.radius) + 150.0:
		damage_hulk(amount)


func correct_player_position(position: Vector2, radius: float) -> Vector2:
	var corrected := Vector2(
		clampf(position.x, DECK_RECT.position.x + radius, DECK_RECT.end.x - radius),
		clampf(position.y, DECK_RECT.position.y + radius, DECK_RECT.end.y - radius)
	)
	for cargo: Rect2 in CARGO_RECTS:
		var expanded: Rect2 = cargo.grow(radius)
		if expanded.has_point(corrected):
			var left_distance := absf(corrected.x - expanded.position.x)
			var right_distance := absf(expanded.end.x - corrected.x)
			var top_distance := absf(corrected.y - expanded.position.y)
			var bottom_distance := absf(expanded.end.y - corrected.y)
			var nearest_side := minf(minf(left_distance, right_distance), minf(top_distance, bottom_distance))
			if nearest_side == left_distance:
				corrected.x = expanded.position.x
			elif nearest_side == right_distance:
				corrected.x = expanded.end.x
			elif nearest_side == top_distance:
				corrected.y = expanded.position.y
			else:
				corrected.y = expanded.end.y
	return corrected

func correct_enemy_position(position: Vector2, lane: int, radius: float) -> Vector2:
	return Vector2(
		clampf(position.x, LANE_CENTERS[lane] - 190.0 + radius, LANE_CENTERS[lane] + 190.0 - radius),
		clampf(position.y, DECK_RECT.position.y + radius, DECK_RECT.end.y - radius)
	)

## One-shot cues, on the SFX bus, with a ceiling on how many can exist at once.
##
## The browser build leaked a Web Audio node per cue because nothing ever
## disconnected them, and a keg chain into forty boarders creates on the order of
## a hundred cues in one frame. Godot frees a finished player, but a hundred
## nodes a frame is still a hundred nodes a frame, so the cap is here from the
## start rather than after a playtest reports lag.
const MAX_VOICES := 24
var _voices := 0

func play_sfx(relative_path: String, volume_db: float = -6.0) -> void:
	if _voices >= MAX_VOICES:
		return
	var full_path := "res://assets/audio/sfx/" + relative_path
	if not ResourceLoader.exists(full_path):
		return
	var audio := AudioStreamPlayer.new()
	audio.stream = load(full_path)
	audio.volume_db = volume_db
	audio.bus = "UI" if relative_path.begins_with("ui/") else "SFX"
	add_child(audio)
	_voices += 1
	audio.finished.connect(func ():
		_voices -= 1
		audio.queue_free())
	audio.play()

func _shape_sound(shape: String) -> String:
	match shape:
		"CLOSEHIT": return "player/shape_cleave.ogg"
		"LINE_BURST": return "player/shape_lance.ogg"
		"CONE": return "player/shape_gale.ogg"
		"RANGED_AOE": return "player/shape_mortar.ogg"
		"CHAIN": return "player/shape_whip.ogg"
		"RAY": return "player/shape_beam_start.ogg"
		_: return "player/hit_1.ogg"

func _distance_to_segment(point: Vector2, start: Vector2, end: Vector2) -> float:
	var segment := end - start
	var length_squared := segment.length_squared()
	if length_squared <= 0.001:
		return point.distance_to(start)
	var t := clampf((point - start).dot(segment) / length_squared, 0.0, 1.0)
	return point.distance_to(start + segment * t)

## Everything the renderer pools needs a name that outlives its position in a
## list. The 3D view keyed its billboards and decals by ARRAY INDEX, and every
## one of these arrays is compacted with `remove_at` the moment an entry expires
## — so effect 3 became effect 4 mid-frame and the node drawing it kept its
## place while its contents changed underneath. On screen that is a ring turning
## into a beam, jumping across the deck and resizing halfway through its own
## fade, which is exactly what a passive build produces most of: a Field and a
## Sentry append and expire something several times a second.
var _fx_seq := 0


func _fx(d: Dictionary) -> void:
	_fx_seq += 1
	d["id"] = _fx_seq
	effects.append(d)


func _field(d: Dictionary) -> void:
	_fx_seq += 1
	d["id"] = _fx_seq
	fire_fields.append(d)


func _bolt(d: Dictionary) -> void:
	_fx_seq += 1
	d["id"] = _fx_seq
	projectiles.append(d)


func _scrap(d: Dictionary) -> void:
	_fx_seq += 1
	d["id"] = _fx_seq
	salvage.append(d)


func _update_effects(delta: float) -> void:
	for i in range(effects.size() - 1, -1, -1):
		effects[i].time = float(effects[i].time) + delta
		if float(effects[i].time) >= float(effects[i].life):
			effects.remove_at(i)
	## Anything anchored to the captain rides with her. The browser carries a
	## `follow` flag for the same reason: a cleave baked at the position you cast
	## it from slides out of your hands the moment you keep moving, which at
	## dash speed is most of its own lifetime.
	if player != null:
		for e in effects:
			if bool(e.get("follow", false)):
				e["position"] = player.global_position
	for i in range(floaters.size() - 1, -1, -1):
		var f: Dictionary = floaters[i]
		f.time = float(f.time) + delta
		f.position = Vector2(f.position) + Vector2(f.drift) * delta
		if float(f.time) >= float(f.life):
			floaters.remove_at(i)


## A number, leaving a body. Capped, because a swarm wave with a chain skill can
## produce sixty in a frame and sixty numbers is not more information than eight.
func add_floater(text: String, at: Vector2, colour: Color, big: bool = false) -> void:
	if floaters.size() >= 40:
		floaters.remove_at(0)
	floaters.append({
		"text": text, "position": at + Vector2(visual_rng.randf_range(-14.0, 14.0), -10.0),
		"drift": Vector2(visual_rng.randf_range(-26.0, 26.0), -78.0),
		"color": colour, "big": big, "time": 0.0, "life": 0.85 if not big else 1.1,
	})

## THE AIRSTREAM.
##
## Asked of the browser build in exactly these words: what am I supposed to be
## looking at to see that this ship is flying? The answer was "two cloud bands
## drifting", which is to say nothing. The strongest available cue that a
## vehicle is moving is not the scenery — it is stuff going past you.
##
## Ported here with the two things the browser version was missing when it was
## reviewed: it is constant rather than intermittent, and it SHEARS with the
## captain's lateral movement, which says "you are moving through air" rather
## than only "the ship is".
const AIRSTREAM_LANES := 54

func _draw_airstream() -> void:
	var t := float(Time.get_ticks_msec()) * 0.001
	var shear: float = clampf(player.velocity.x / 320.0, -1.0, 1.0) if player != null else 0.0
	for i in AIRSTREAM_LANES:
		var seed_value := float(i) * 0.6180339887
		var lane := fmod(seed_value, 1.0)
		var speed := 1.45 + fmod(seed_value * 7.3, 1.0) * 1.1
		var phase := fmod(t * speed * 0.42 + lane, 1.0)
		var y: float = DECK_RECT.position.y - 200.0 + phase * (DECK_RECT.size.y + 500.0)
		var x: float = DECK_RECT.position.x + lane * DECK_RECT.size.x + sin(seed_value * 31.7) * 90.0
		var length := 90.0 + fmod(seed_value * 13.0, 1.0) * 130.0
		var alpha := 0.06 + fmod(seed_value * 3.1, 1.0) * 0.07
		# the shear: streaks lean against the way the captain is moving
		var lean := -shear * 26.0
		draw_line(Vector2(x, y), Vector2(x + lean, y + length),
			Color(0.62, 0.72, 0.88, alpha), 1.6 + fmod(seed_value * 5.0, 1.0) * 2.0)


func _draw() -> void:
	draw_rect(Rect2(-5000, -5000, 10000, 10000), Color("#17152a"))
	draw_rect(DECK_RECT.grow(24.0), Color("#0d0b12"))
	draw_rect(DECK_RECT, Color("#3d2e30"))
	for y in range(int(DECK_RECT.position.y), int(DECK_RECT.end.y), 58):
		draw_line(Vector2(DECK_RECT.position.x, y), Vector2(DECK_RECT.end.x, y), Color(0.33, 0.25, 0.24, 0.62), 2.0)
	for x in range(int(DECK_RECT.position.x), int(DECK_RECT.end.x), 116):
		draw_line(Vector2(x, DECK_RECT.position.y), Vector2(x, DECK_RECT.end.y), Color(0.12, 0.09, 0.11, 0.28), 2.0)
	draw_rect(DECK_RECT, Color("#b0813f"), false, 8.0)
	_draw_airstream()
	for cargo in CARGO_RECTS:
		draw_rect(cargo, Color("#17131a"))
		draw_rect(cargo.grow(-8.0), Color("#54413c"))
		for y in range(int(cargo.position.y) + 18, int(cargo.end.y), 42):
			draw_line(Vector2(cargo.position.x + 8, y), Vector2(cargo.end.x - 8, y), Color("#b0813f"), 3.0)

	## --- the lane layer -----------------------------------------------------
	## Simulated since this milestone, and drawn here rather than as scene nodes
	## for the same reason it is simulated as plain data: three cannons, a dozen
	## crew and one hulk do not need a Node2D lifetime each.
	if not hulk.is_empty() and not bool(hulk.dead):
		var hull_flash: float = float(hulk.get("flash", 0.0))
		draw_circle(Vector2(hulk.position) + Vector2(0, 20), float(hulk.radius) * 0.9,
			Color(0.01, 0.01, 0.02, 0.5))
		draw_circle(hulk.position, float(hulk.radius),
			Color("#3a2a2e").lerp(Color.WHITE, hull_flash * 2.0))
		draw_circle(hulk.position, float(hulk.radius) * 0.62, Color("#241b25"))
		draw_arc(hulk.position, float(hulk.radius) + 14.0, -PI, -PI + TAU * float(hulk.hp) / float(hulk.max_hp),
			64, Color("#ff4d37"), 9.0)
		# grapples, so it reads as attached rather than parked
		for g in 5:
			var gx: float = float(hulk.position.x) - 150.0 + g * 75.0
			draw_line(Vector2(gx, float(hulk.position.y) + float(hulk.radius) * 0.6),
				Vector2(gx * 0.6, float(hulk.position.y) + float(hulk.radius) + 90.0),
				Color("#4a4a55"), 6.0)

	for t in turrets:
		var pos: Vector2 = t.position
		var dead_gun := bool(t.dead)
		draw_circle(pos + Vector2(0, 12), float(t.radius) * 1.15, Color(0.01, 0.01, 0.02, 0.5))
		var body := Color("#2a2027") if dead_gun else Color("#4a4a55")
		if float(t.flash) > 0.0:
			body = body.lerp(Color.WHITE, 0.6)
		draw_circle(pos, float(t.radius), body)
		if not dead_gun:
			draw_circle(pos, float(t.radius) * 0.55, Color("#b0813f"))
			var muzzle: Vector2 = pos + Vector2.RIGHT.rotated(float(t.angle)) * (float(t.radius) + 26.0)
			draw_line(pos, muzzle, Color("#e8c376"), 9.0)
			if float(t.fire_flash) > 0.0:
				draw_circle(muzzle, 14.0, Color("#ffd36b"))
			draw_arc(pos, float(t.radius) + 10.0, -PI * 0.5,
				-PI * 0.5 + TAU * float(t.hp) / float(t.max_hp), 32, Color("#37f0c8"), 4.0)
		else:
			draw_line(pos + Vector2(-22, -22), pos + Vector2(22, 22), Color("#ff4d37"), 5.0)
			draw_line(pos + Vector2(22, -22), pos + Vector2(-22, 22), Color("#ff4d37"), 5.0)

	for c in crew:
		if bool(c.dead):
			continue
		var cpos: Vector2 = c.position
		draw_circle(cpos + Vector2(0, 8), float(c.radius) * 1.1, Color(0.01, 0.01, 0.02, 0.45))
		var tint := Color("#8fa6c9")
		if float(c.flash) > 0.0:
			tint = tint.lerp(Color.WHITE, 0.7)
		draw_circle(cpos, float(c.radius), tint)
		draw_circle(cpos + Vector2(0, -float(c.radius) * 0.7), float(c.radius) * 0.55, Color("#e8e2d2"))
		if float(c.hp) < float(c.max_hp):
			var w := 26.0
			draw_rect(Rect2(cpos.x - w * 0.5, cpos.y - float(c.radius) - 12.0, w, 4.0), Color("#241b25"))
			draw_rect(Rect2(cpos.x - w * 0.5, cpos.y - float(c.radius) - 12.0,
				w * float(c.hp) / float(c.max_hp), 4.0), Color("#37f0c8"))

	draw_circle(BOILER_POSITION + Vector2(0, 14), 78.0, Color(0.01, 0.01, 0.02, 0.55))
	draw_circle(BOILER_POSITION, boiler_radius, Color("#5b3b25"))
	draw_circle(BOILER_POSITION, 46.0, Color("#b0813f"))
	draw_circle(BOILER_POSITION, 31.0, Color("#37f0c8") if boiler_hp > boiler_max_hp * 0.3 else Color("#ff4d37"))
	draw_arc(BOILER_POSITION, boiler_radius + 8.0, 0.0, TAU * boiler_hp / boiler_max_hp, 48, Color("#e8c376"), 5.0)

	for field in fire_fields:
		var flicker := 0.82 + 0.12 * sin(Time.get_ticks_msec() * 0.012 + field.position.x)
		draw_circle(field.position, 78.0, Color(0.82, 0.20, 0.05, 0.16))
		draw_arc(field.position, 64.0 * flicker, 0.0, TAU, 28, Color(1.0, 0.42, 0.08, 0.66), 6.0)
	for item in salvage:
		draw_circle(item.position, 18.0, Color("#6bbf72"))
		draw_arc(item.position, 25.0, 0.0, TAU, 18, Color("#e8c376"), 3.0)
	for bolt in projectiles:
		# where it is ON THE DECK, not where it is in the air. Reported against
		# the browser build: enemy fire was hard to track, and an unshadowed
		# sprite has no position you can step out of the way of.
		draw_circle(Vector2(bolt.position) + Vector2(0, 22), 9.0, Color(0.02, 0.015, 0.03, 0.45))
		var trail: Array = bolt.trail
		for i in range(trail.size() - 1):
			var alpha := 0.55 * (1.0 - float(i) / maxf(1.0, trail.size()))
			draw_line(trail[i], trail[i + 1], Color(1.0, 0.35, 0.12, alpha), maxf(2.0, 8.0 - i))
		_draw_flat_ellipse(bolt.position + Vector2(0, 13), 13.0, 5.0, Color(0.02, 0.01, 0.02, 0.55))
		draw_circle(bolt.position, 10.0, Color("#ff5a2f"))
		draw_circle(bolt.position, 4.0, Color("#ffe08a"))
	for effect in effects:
		_draw_effect(effect)

func _draw_effect(effect: Dictionary) -> void:
	var progress := float(effect.time) / float(effect.life)
	var alpha := 1.0 - progress
	var color: Color = effect.get("color", Color.WHITE)
	color.a *= alpha
	match str(effect.kind):
		"arc":
			draw_arc(effect.position, float(effect.radius) * (0.88 + progress * 0.12), float(effect.direction) - 1.22, float(effect.direction) + 1.22, 36, color, 12.0 * alpha + 2.0)
		"line":
			draw_line(effect.from, effect.to, color, 10.0 * alpha + 2.0)
		"beam":
			draw_line(effect.from, effect.to, color, 22.0 * alpha + 5.0)
			draw_line(effect.from, effect.to, Color(1, 1, 1, alpha), 5.0)
		"cone":
			var left := Vector2.from_angle(float(effect.direction) - float(effect.arc) * 0.5) * float(effect.radius)
			var right := Vector2.from_angle(float(effect.direction) + float(effect.arc) * 0.5) * float(effect.radius)
			draw_colored_polygon(PackedVector2Array([effect.position, effect.position + left, effect.position + right]), Color(color.r, color.g, color.b, alpha * 0.22))
			draw_line(effect.position, effect.position + left, color, 4.0)
			draw_line(effect.position, effect.position + right, color, 4.0)
		"circle":
			draw_arc(effect.position, float(effect.radius) * progress, 0.0, TAU, 48, color, 10.0 * alpha + 2.0)
		"burst":
			draw_circle(effect.position, float(effect.radius) * progress, Color(color.r, color.g, color.b, alpha * 0.28))
			draw_arc(effect.position, float(effect.radius) * progress, 0.0, TAU, 36, color, 8.0)

func _draw_flat_ellipse(center: Vector2, width: float, height: float, color: Color) -> void:
	var points := PackedVector2Array()
	for i in 24:
		var angle := TAU * float(i) / 24.0
		points.append(center + Vector2(cos(angle) * width, sin(angle) * height))
	draw_colored_polygon(points, color)

