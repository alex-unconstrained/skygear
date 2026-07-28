class_name SkyGearHUD
extends Control

var game: Node
var font: Font
## Set by the 3D view when it takes over the frame. Everything the browser
## draws ON the fight — health over a boarder's head, the number that leaves a
## body, the arrow saying one is behind you — is screen-space work that needs a
## world-to-screen, and in 3D that is the camera's job rather than a projection
## we write. Null in the plain 2D scene, where the entities draw their own.
var view: SkyGearView3D

func _ready() -> void:
	font = ThemeDB.fallback_font

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if game == null:
		return
	match game.state_name:
		"TITLE":
			_draw_title()
			if game.keys_open:
				_draw_keys()
		"DRAFT":
			_draw_world_overlay()
			_draw_game_hud()
			_draw_draft()
		"PAUSE":
			_draw_world_overlay()
			_draw_game_hud()
			if game.keys_open:
				_draw_keys()
			else:
				_draw_overlay("PAUSED", _pause_text())
		"GAMEOVER":
			## The run report, not a sentence. `_draw_results` has existed since
			## the report landed and nothing ever called it — the telemetry
			## layer, the per-slot attribution and the copy key were all feeding
			## a screen no player had ever seen.
			_draw_results("DECK LOST", Color("#ff4d37"))
		"VICTORY":
			_draw_results("DECK HELD", Color("#37f0c8"))
		_:
			_draw_world_overlay()
			_draw_game_hud()
	if game.layout_edit:
		_draw_layout_editor()

func _draw_title() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.025, 0.045, 0.72))
	_banner(size.x * 0.5, 104.0, 600.0)
	_center_text("SKYGEAR", 150.0, 64, Color("#e8c376"))
	_center_text("STORM-DUSK · GODOT PORT", 205.0, 24, Color("#37f0c8"))
	_center_text("Keep the Boiler alive through twelve boarding waves.", 286.0, 22, Color("#eee5d5"))
	_center_text("WASD move · mouse aim · LMB/RMB/Q/E skills · Space dash", 330.0, 18, Color("#b9afaa"))
	_center_text("Press Enter to choose your opening weapon", 430.0, 26, Color("#ffe08a"))
	## What the machine remembers. A title screen with a best-wave on it is the
	## cheapest possible reason to press Enter again.
	var history: Dictionary = SkyGearRunLog.summary()
	if int(history.runs) > 0:
		var line := "%d runs · best wave %d" % [int(history.runs), int(history.best_wave)]
		if int(history.wins) > 0:
			line += " · %d held" % int(history.wins)
			if str(history.best_time) != "":
				line += " (best %s)" % str(history.best_time)
		_center_text(line, 500.0, 17, Color("#b0813f"))
	_center_text("F2 rebind keys · F3 audio", 540.0, 15, Color("#6a6478"))
	_center_text("Milestone 1 · v11 combat vertical slice", 675.0, 15, Color("#8f8697"))

## The HUD, brought up to the browser build.
##
## The browser draws brass panels with riveted corners, the captain portrait, a
## pressure gauge with its own icon, skill slots showing each shape glyph and a
## cooldown sweep, and a lane readout. This was four grey rectangles and some
## text, which is the difference between a prototype and a game even when the
## simulation underneath is identical.
const PANEL_FILL := Color(0.078, 0.070, 0.106, 0.94)
const BRASS := Color("#b0813f")
const BRASS_LIT := Color("#e8c376")
const BONE := Color("#eee5d5")
const SLOT_ICONS := {
	"CLOSEHIT": "res://assets/art/ui/icon_skill_slash.png",
	"LINE_BURST": "res://assets/art/ui/icon_skill_hook.png",
	"CONE": "res://assets/art/ui/icon_skill_cone.png",
	"RANGED_AOE": "res://assets/art/ui/icon_skill_aoe.png",
	"CHAIN": "res://assets/art/ui/icon_skill_ult.png",
	"RAY": "res://assets/art/ui/icon_skill_turret.png",
	"AURA": "res://assets/art/ui/icon_skill_field.png",
	"PULSE": "res://assets/art/ui/icon_skill_pulse.png",
	"SENTRY": "res://assets/art/ui/icon_skill_sentry.png",
}
var _tex_cache := {}


func _tex(path: String) -> Texture2D:
	if not _tex_cache.has(path):
		_tex_cache[path] = load(path) if ResourceLoader.exists(path) else null
	return _tex_cache[path]


## Nine-slice, by hand.
##
## Godot's `draw_texture_rect_region` cannot nine-slice and `NinePatchRect` is a
## node rather than something you can call from `_draw`. So: corners at their
## authored size, edges stretched on one axis, middle on both. Nine calls.
##
## This is what lets one 512x256 painted plate be a 350-wide captain panel, a
## 348-wide ship panel and a 120-wide skill slot without the rivets smearing —
## which is the whole reason the HUD art is authored as housings rather than as
## one image per panel.
func _nine(texture: Texture2D, rect: Rect2, margin: float) -> void:
	var t := texture.get_size()
	var m: float = minf(margin, minf(t.x, t.y) * 0.45)
	var inner: float = maxf(1.0, m)
	## source columns/rows, then destination columns/rows
	var sx := [0.0, inner, t.x - inner, t.x]
	var sy := [0.0, inner, t.y - inner, t.y]
	## The destination corners never scale below their own size, or a narrow
	## panel eats its own frame.
	var dm: float = minf(inner, minf(rect.size.x, rect.size.y) * 0.45)
	var dx := [rect.position.x, rect.position.x + dm, rect.end.x - dm, rect.end.x]
	var dy := [rect.position.y, rect.position.y + dm, rect.end.y - dm, rect.end.y]
	for row in 3:
		for col in 3:
			var src := Rect2(sx[col], sy[row], sx[col + 1] - sx[col], sy[row + 1] - sy[row])
			var dst := Rect2(dx[col], dy[row], dx[col + 1] - dx[col], dy[row + 1] - dy[row])
			if src.size.x <= 0.0 or src.size.y <= 0.0 or dst.size.x <= 0.0 or dst.size.y <= 0.0:
				continue
			draw_texture_rect_region(texture, dst, src)


## A brass plate. The painted housing if it has been delivered, otherwise the
## code-drawn approximation of one — dark fill, hard ink edge, brass inlay,
## rivet in each corner. Both are the same shape, so the layout does not move
## when the art lands. docs/HUD-PLAN.md is the brief.
func _panel(rect: Rect2, slot: bool = false) -> void:
	var plate := _tex("res://assets/art/ui/plate_slot.png" if slot
		else "res://assets/art/ui/plate_wide.png")
	if plate != null:
		_nine(plate, rect, 48.0)
		return
	draw_rect(rect, PANEL_FILL)
	draw_rect(rect, Color("#0d0b12"), false, 5.0)
	draw_rect(rect.grow(-4.0), BRASS, false, 2.0)
	for corner in [rect.position + Vector2(9, 9), rect.position + Vector2(rect.size.x - 9, 9),
			rect.position + Vector2(9, rect.size.y - 9),
			rect.position + Vector2(rect.size.x - 9, rect.size.y - 9)]:
		draw_circle(corner, 2.6, BRASS)


## A big plate, for the screens that are one panel rather than five.
func _sheet(rect: Rect2) -> void:
	_panel(rect)


## The title banner.
##
## `frame_hud.png` is 1024x256 with its art in a 391x117 patch — it is a wide
## banner with a lot of empty sheet around it, not a border. Stretched over a
## panel it drew a small ornament floating in the middle of nothing, which is
## what happens when you use an asset for the thing its filename suggests
## instead of the thing its pixels are.
const BANNER_REGION := Rect2(316, 0, 391, 117)


func _banner(centre_x: float, y: float, width: float) -> void:
	var plate := _tex("res://assets/art/ui/frame_hud.png")
	if plate == null:
		return
	var height: float = width * BANNER_REGION.size.y / BANNER_REGION.size.x
	draw_texture_rect_region(plate,
		Rect2(centre_x - width * 0.5, y, width, height), BANNER_REGION,
		Color(1, 1, 1, 0.9))


## THE HUD LIVES ALONG THE BOTTOM.
##
## It used to sit in the top corners, and the top of the frame is where boarders
## come from — the objective plate and the lane readout were covering the two
## hundred pixels of deck a player most needs to watch. Everything is now in one
## band across the bottom, which is the half of the screen the captain is
## already looking at and the half nothing arrives from.
##
## Three clusters, all sharing a baseline: her on the left, her hand in the
## middle, the ship on the right.
const HUD_MARGIN := 24.0
const HUD_BASE := 24.0               ## gap from the bottom edge
const SLOT_W := 128.0


## Where each cluster sits, given the window.
##
## Read from `SkyGearHudLayout` rather than computed here, so the positions are
## something a person can drag (F4) rather than something I edit three pixels at
## a time through a rebuild-screenshot-look loop. One place still, because the
## layout matrix asserts against exactly these rectangles.
##
## The side plates still give way to the hand on a narrow window: a hand-placed
## layout is placed at one width, and a HUD that overlaps itself at 1152 is a
## bug rather than a hardware requirement.
static var layout: SkyGearHudLayout


static func hud_plates(view: Vector2) -> Dictionary:
	if layout == null:
		layout = SkyGearHudLayout.load_layout()
	var out := layout.all_rects(view)
	var slots := Rect2()
	for i in 4:
		slots = slots.merge(out["slot%d" % i]) if i > 0 else out["slot0"]
	for name in ["captain", "ship"]:
		var plate: Rect2 = out[name]
		if not plate.intersects(slots):
			continue
		var room: float = (slots.position.x - plate.position.x) if name == "captain" \
			else (plate.end.x - slots.end.x)
		plate.size.x = maxf(160.0, room - 12.0)
		if name == "ship":
			plate.position.x = plate.end.x - plate.size.x if false else slots.end.x + 12.0
		out[name] = plate
	return out


## How much of a plate is frame rather than interior.
##
## The code-drawn panel had a five pixel edge and the layout was written against
## it. The painted housings have a riveted brass border that is a fifth of their
## height, so the same layout put the health bar across the frame and the lane
## labels on the rivets. Everything inside a plate is positioned against
## `interior()`, never against the plate itself.
static func interior(rect: Rect2) -> Rect2:
	## Measured off the delivered plates rather than guessed: the riveted brass
	## border is close to a fifth of the shorter side, and 13% put the Boiler bar
	## across the top frame and the lane labels on the rivets.
	var inset: float = clampf(minf(rect.size.x, rect.size.y) * 0.19, 10.0, 30.0)
	return rect.grow(-inset)


## --- the layout editor -------------------------------------------------------
## Drawn over everything while F4 is on. The point is that the panels underneath
## are the REAL panels with the REAL content at the REAL resolution — a mockup
## of a HUD is a picture of a decision rather than the decision.
func _draw_layout_editor() -> void:
	var plates := SkyGearHUD.hud_plates(size)
	var chosen: String = game.layout_pick
	var chosen_item: String = game.layout_item
	for name in SkyGearHudLayout.ORDER:
		var rect: Rect2 = plates.get(name, Rect2())
		var hot: bool = name == chosen
		draw_rect(rect, Color(0.22, 0.94, 0.78, 0.08) if hot else Color(1, 1, 1, 0.03))
		draw_rect(rect, Color("#37f0c8") if hot else Color(1, 1, 1, 0.26), false,
			2.0 if hot and chosen_item == "" else 1.0)
		_label(name, rect.position + Vector2(6, -6), 200.0, HORIZONTAL_ALIGNMENT_LEFT, 12,
			Color("#37f0c8") if hot else Color(1, 1, 1, 0.45))
		if not hot:
			continue
		## Everything inside the selected plate, so the thing being aligned is
		## visible as a box rather than inferred from where a glyph landed.
		draw_rect(SkyGearHudLayout.interior(rect), Color(1, 1, 1, 0.18), false, 1.0)
		for item_name in layout.items_of(name):
			var box := layout.item(name, item_name, rect)
			var picked: bool = item_name == chosen_item
			draw_rect(box, Color(1.0, 0.88, 0.54, 0.14) if picked else Color(1, 1, 1, 0.04))
			draw_rect(box, Color("#ffe08a") if picked else Color(1, 1, 1, 0.3), false,
				2.0 if picked else 1.0)
			if picked:
				draw_rect(Rect2(box.end - Vector2(9, 9), Vector2(11, 11)), Color("#e8c376"))
				## Centre lines, which is what alignment actually is.
				draw_line(Vector2(box.get_center().x, rect.position.y),
					Vector2(box.get_center().x, rect.end.y), Color(1, 0.88, 0.54, 0.4), 1.0)
				draw_line(Vector2(rect.position.x, box.get_center().y),
					Vector2(rect.end.x, box.get_center().y), Color(1, 0.88, 0.54, 0.4), 1.0)
			else:
				_label(item_name, box.position + Vector2(2, -3), 160.0,
					HORIZONTAL_ALIGNMENT_LEFT, 10, Color(1, 1, 1, 0.5))

	var trouble := layout.problems(size)
	draw_rect(Rect2(0, 0, size.x, 66), Color(0.02, 0.015, 0.028, 0.9))
	var target: String = chosen if chosen_item == "" else "%s / %s" % [chosen, chosen_item]
	_value("HUD LAYOUT — editing %s" % target, Vector2(16, 22), size.x,
		HORIZONTAL_ALIGNMENT_LEFT, 15, BRASS_LIT)
	_label("drag to move · corner to resize · Tab next · Enter into a panel · Esc out"
		+ " · arrows nudge (Shift 10, Alt resize) · A anchor · C centre · Ctrl+S save"
		+ " · Ctrl+R reset · F4 done",
		Vector2(16, 42), size.x, HORIZONTAL_ALIGNMENT_LEFT, 12)
	var entry: Dictionary = layout.plates.get(chosen, {}) if chosen_item == "" 		else layout._bag(chosen).get(chosen_item, {})
	if not entry.is_empty():
		_label("%s  %d,%d  %dx%d" % [str(entry.anchor), int(entry.offset[0]),
			int(entry.offset[1]), int(entry.size[0]), int(entry.size[1])],
			Vector2(size.x - 16, 22), 300.0, HORIZONTAL_ALIGNMENT_RIGHT, 14, Color("#e8c376"))
	_label(("saved to " + SkyGearHudLayout.USER_PATH) if game.layout_saved
		else ("%d problem(s): %s" % [trouble.size(), ", ".join(trouble)]
			if not trouble.is_empty() else "layout is clean"),
		Vector2(size.x - 16, 42), 700.0, HORIZONTAL_ALIGNMENT_RIGHT, 12,
		Color("#37f0c8") if trouble.is_empty() else Color("#ff9a5a"))


## What is under a point: a plate, or an element inside the plate currently
## being edited. Shared with the input handler so what you grab is what you saw.
static func pick_at(view: Vector2, where: Vector2, current: String) -> Dictionary:
	var plates := hud_plates(view)
	## Items inside the selected plate win, because they are drawn on top of it
	## and are the smaller target.
	if plates.has(current):
		var plate: Rect2 = plates[current]
		for item_name in layout.items_of(current):
			var box := layout.item(current, item_name, plate)
			if not box.grow(3.0).has_point(where):
				continue
			var grip := Rect2(box.end - Vector2(9, 9), Vector2(11, 11))
			return {"plate": current, "item": item_name, "resize": grip.has_point(where)}
	for i in range(SkyGearHudLayout.ORDER.size() - 1, -1, -1):
		var name: String = SkyGearHudLayout.ORDER[i]
		var rect: Rect2 = plates.get(name, Rect2())
		if not rect.has_point(where):
			continue
		var grip2 := Rect2(rect.end - Vector2(16, 16), Vector2(16, 16))
		return {"plate": name, "item": "", "resize": grip2.has_point(where)}
	return {}


## A pressure dial. The face is painted with its danger arc and tick marks; the
## needle is drawn, because a needle baked into a bezel is a needle that is wrong
## for every value but one.
func _dial(rect: Rect2, ratio: float) -> void:
	var face := _tex("res://assets/art/ui/pressure_dial.png")
	var centre := rect.get_center()
	var radius: float = minf(rect.size.x, rect.size.y) * 0.5
	if face != null:
		draw_texture_rect_region(face, rect, Rect2(Vector2.ZERO, face.get_size()))
	else:
		draw_circle(centre, radius, Color("#0b0910"))
		draw_arc(centre, radius - 2.0, deg_to_rad(313.0), deg_to_rad(400.0), 24,
			Color("#8b2418"), 3.0)
		draw_arc(centre, radius, 0.0, TAU, 32, BRASS, 2.0)
	## 260 degrees of sweep starting at eight on a clock face, which is where a
	## dial with its danger arc across the last third puts zero.
	var angle: float = deg_to_rad(140.0 + 260.0 * clampf(ratio, 0.0, 1.0))
	var tip := centre + Vector2(cos(angle), sin(angle)) * (radius - 5.0)
	draw_line(centre, tip, Color("#f2eaff") if ratio >= 1.0 else Color("#e8542e"), 2.4)
	draw_circle(centre, 3.0, BRASS_LIT)


## The cooldown, as a clock sweep rather than a bottom-up wipe.
##
## Both say the same thing; the sweep says it in the shape everyone has already
## learned from every other game, and that is worth more than the shape being
## ours. Drawn as a fan of wedges so it needs neither a shader nor a rotated
## draw, both of which Godot makes awkward from inside `_draw`.
func _cooldown(rect: Rect2, remaining: float) -> void:
	var shade := Color(0.04, 0.03, 0.06, 0.74)
	var centre := rect.get_center()
	var radius: float = rect.size.length() * 0.5
	var steps: int = maxi(2, int(ceil(remaining * 24.0)))
	var points := PackedVector2Array([centre])
	for i in range(steps + 1):
		var a: float = -PI * 0.5 + TAU * remaining * float(i) / float(steps)
		points.append(centre + Vector2(cos(a), sin(a)) * radius)
	if points.size() >= 3:
		draw_colored_polygon(points, shade)


## Readability first.
##
## Reported after a playtest: "we've lost a lot of readability and clarity from
## the browser version." The browser draws every HUD label with an ink shadow
## under it and a bright value over it, and this build was putting small grey
## text straight onto brass — the one background it disappears against.
##
## `_label` and `_value` are the fix and they are used for every piece of text on
## the bar, so the contrast decision is made once.
const INK := Color(0.03, 0.02, 0.045, 0.9)


func _label(text: String, at: Vector2, width: float, align: int, pt: int = 12,
		tint: Color = Color("#cfc4b4")) -> void:
	draw_string(font, at + Vector2(1, 1), text, align, width, pt, INK)
	draw_string(font, at, text, align, width, pt, tint)


func _value(text: String, at: Vector2, width: float, align: int, pt: int = 15,
		tint: Color = Color("#fff6e4")) -> void:
	draw_string(font, at + Vector2(1.5, 1.5), text, align, width, pt, INK)
	draw_string(font, at, text, align, width, pt, tint)


func _draw_game_hud() -> void:
	var player: SkyGearPlayer = game.player
	var plates := hud_plates(size)
	var l := layout

	## --- the captain -------------------------------------------------------
	var panel: Rect2 = plates.captain
	_panel(panel)
	var portrait_at := l.item("captain", "portrait", panel)
	var portrait := _tex("res://assets/art/ui/portrait_corsair.png")
	if portrait != null:
		draw_texture_rect_region(portrait, portrait_at,
			Rect2(Vector2.ZERO, portrait.get_size()))
	var bezel := _tex("res://assets/art/ui/gauge_ring.png")
	if bezel != null:
		draw_texture_rect(bezel, portrait_at.grow(6.0), false, BRASS_LIT)
	else:
		draw_arc(portrait_at.get_center(), portrait_at.size.x * 0.5 + 2.0, 0.0, TAU, 40,
			BRASS, 2.4)

	var health := l.item("captain", "health", panel)
	_bar(health, player.hp / player.max_hp, Color("#e8542e"), Color("#8b2418"),
		"CAPTAIN", "%d / %d" % [player.hp, player.max_hp])

	var pressure_ratio: float = player.pressure / 100.0
	_dial(l.item("captain", "dial", panel), pressure_ratio)
	var vent_at := l.item("captain", "vent_icon", panel)
	var gauge_icon := _tex("res://assets/art/ui/icon_vent.png" if pressure_ratio >= 1.0
		else "res://assets/art/ui/icon_pressure.png")
	if gauge_icon != null:
		draw_texture_rect_region(gauge_icon, vent_at,
			Rect2(Vector2.ZERO, gauge_icon.get_size()),
			Color("#f2eaff") if pressure_ratio >= 1.0 else Color("#a79bb5"))
	var pressure_at := l.item("captain", "pressure_label", panel)
	_label("VENTING" if pressure_ratio >= 1.0 else "PRESSURE",
		pressure_at.position + Vector2(0, pressure_at.size.y), pressure_at.size.x,
		HORIZONTAL_ALIGNMENT_LEFT, 12,
		Color("#f2eaff") if pressure_ratio >= 1.0 else Color("#b4a8c4"))

	var dash_at := l.item("captain", "dash_label", panel)
	_label("DASH", dash_at.position + Vector2(0, dash_at.size.y), dash_at.size.x,
		HORIZONTAL_ALIGNMENT_LEFT, 12)
	var pips := l.item("captain", "dash_pips", panel)
	var pip_art := _tex("res://assets/art/ui/dash_pip.png")
	var pip_r: float = minf(pips.size.y, pips.size.x * 0.5) * 0.5
	for i in 2:
		var lit := i < player.dash_charges
		var at := Vector2(pips.position.x + pip_r + i * pip_r * 2.2, pips.get_center().y)
		if pip_art != null:
			draw_texture_rect_region(pip_art,
				Rect2(at - Vector2(pip_r, pip_r), Vector2(pip_r * 2, pip_r * 2)),
				Rect2(Vector2.ZERO, pip_art.get_size()),
				Color("#9ff5e2") if lit else Color(0.28, 0.26, 0.32))
		else:
			draw_circle(at, pip_r, Color("#37f0c8") if lit else Color("#201c28"))

	## --- the ship -----------------------------------------------------------
	var right: Rect2 = plates.ship
	_panel(right)
	_bar(l.item("ship", "boiler", right), game.boiler_hp / game.boiler_max_hp,
		Color("#37f0c8"), Color("#1c6f61"), "BOILER",
		"%d / %d" % [game.boiler_hp, game.boiler_max_hp])
	var wave_at := l.item("ship", "wave", right)
	_value("WAVE %d / 12" % game.wave,
		wave_at.position + Vector2(0, wave_at.size.y), wave_at.size.x,
		HORIZONTAL_ALIGNMENT_LEFT, 16, BRASS_LIT)
	var boarders_at := l.item("ship", "boarders", right)
	_value("BOARDERS %d" % game.enemy_count(),
		boarders_at.position + Vector2(0, boarders_at.size.y), boarders_at.size.x,
		HORIZONTAL_ALIGNMENT_RIGHT, 16)

	## Which lane is breaking, without having to look at it.
	var names := ["PORT", "CENTRE", "STARBOARD"]
	for lane in 3:
		var row := l.item("ship", "lane%d" % lane, right)
		_label(names[lane], row.position + Vector2(0, row.size.y - 3.0), 70.0,
			HORIZONTAL_ALIGNMENT_LEFT, 11)
		var track := Rect2(row.position.x + 74.0, row.get_center().y - 4.0,
			maxf(20.0, row.size.x - 96.0), 9.0)
		draw_rect(track, Color("#0b0910"))
		var gate: Dictionary = game.turret_in_lane(lane)
		if not gate.is_empty():
			draw_rect(Rect2(track.position,
				Vector2(track.size.x * float(gate.hp) / float(gate.max_hp), track.size.y)),
				Color("#37f0c8"))
		var deepest := -1.0
		var count := 0
		for enemy in game.get_tree().get_nodes_in_group("enemies"):
			if not is_instance_valid(enemy) or enemy.dead or enemy.lane != lane:
				continue
			count += 1
			var progress: float = clampf((enemy.global_position.y - SkyGearGame.DECK_RECT.position.y)
				/ SkyGearGame.DECK_RECT.size.y, 0.0, 1.0)
			deepest = maxf(deepest, progress)
		if deepest >= 0.0:
			var marker := track.position + Vector2(track.size.x * deepest, 0)
			draw_rect(Rect2(marker - Vector2(2, 3), Vector2(4, track.size.y + 6)),
				Color("#ff4d37") if deepest > 0.72 else Color("#ffb347"))
		draw_rect(track, Color("#0d0b12"), false, 1.4)
		_value(str(count), row.position + Vector2(row.size.x - 20.0, row.size.y - 3.0),
			20.0, HORIZONTAL_ALIGNMENT_RIGHT, 12)

	## --- the hand -----------------------------------------------------------
	var labels := ["LMB", "RMB", "Q", "E"]
	for i in 4:
		var slot := "slot%d" % i
		var rect: Rect2 = plates[slot]
		_panel(rect, true)
		var key_at := l.item(slot, "key", rect)
		_label(labels[i], key_at.position + Vector2(0, key_at.size.y), key_at.size.x,
			HORIZONTAL_ALIGNMENT_CENTER, 13, BRASS_LIT)
		var icon_at := l.item(slot, "icon", rect)
		var name_at := l.item(slot, "name", rect)
		## A dark recess under the glyph, always. The painted bezel has brass
		## detail in the middle of it, and an element icon drawn straight onto
		## that is an icon competing with a latch — the reported loss of clarity
		## against the browser, which puts every glyph on a flat dark disc.
		draw_circle(icon_at.get_center(), icon_at.size.x * 0.62, Color(0.05, 0.04, 0.07, 0.82))
		draw_arc(icon_at.get_center(), icon_at.size.x * 0.62, 0.0, TAU, 28,
			Color(0.02, 0.015, 0.03, 0.9), 2.0)
		if i >= game.skills.size():
			_label("LOCKED", name_at.position + Vector2(0, name_at.size.y), name_at.size.x,
				HORIZONTAL_ALIGNMENT_CENTER, 13, Color("#5f5863"))
			continue
		var skill: Dictionary = game.skills[i]
		var element: Color = SkyGearData.ELEMENTS[skill.element].color
		var icon := _tex(str(SLOT_ICONS.get(skill.shape, "")))
		if icon != null:
			draw_texture_rect_region(icon, icon_at, Rect2(Vector2.ZERO, icon.get_size()),
				element)
		var ready: bool = float(skill.cooldown_left) <= 0.0
		if not ready:
			var st: Dictionary = game.skill_stats(skill)
			var frac: float = clampf(float(skill.cooldown_left) / maxf(0.01, float(st.cooldown)),
				0.0, 1.0)
			_cooldown(icon_at.grow(4.0), frac)
		_label(SkyGearData.skill_name(skill),
			name_at.position + Vector2(0, name_at.size.y), name_at.size.x,
			HORIZONTAL_ALIGNMENT_CENTER, 12,
			element if ready else Color("#8b8296"))


func _bar(rect: Rect2, ratio: float, top: Color, bottom: Color, label: String, value: String) -> void:
	var filled := Rect2(rect.position, Vector2(rect.size.x * clampf(ratio, 0.0, 1.0), rect.size.y))
	var housing := _tex("res://assets/art/ui/bar_housing.png")
	var fill := _tex("res://assets/art/ui/bar_fill_cold.png" if top.g > top.r
		else "res://assets/art/ui/bar_fill_hot.png")
	## The housing is authored as a chunky trough, 512x158 — roughly three to one.
	## Nine-slicing that into a sixteen-pixel-tall bar squeezes 26 pixels of brass
	## corner into seven, and the gauge comes out solid brass with a thread of
	## colour in it. Below this height the painted housing is the wrong asset for
	## the slot and the code-drawn channel is the right one.
	if housing != null and rect.size.y >= 22.0:
		_nine(housing, rect, 20.0)
		## Inside the housing's own frame, which is about a fifth of its height.
		## Drawn at the rect the fill spills over the brass and the gauge reads
		## as a tube rather than as a channel with something in it.
		var bed := rect.grow(-maxf(3.0, rect.size.y * 0.24))
		## The channel, drawn dark before anything goes in it. Nine-slicing a
		## trough into a short bar leaves the interior mostly brass, so an empty
		## gauge reads as a full one — which on a health bar is the worst
		## possible failure.
		draw_rect(bed, Color("#0b0910"))
		filled = Rect2(bed.position, Vector2(bed.size.x * clampf(ratio, 0.0, 1.0), bed.size.y))
		if fill != null and filled.size.x > 1.0:
			## Clipped, not scaled: the band is authored even along its length so
			## it can be cut anywhere, and stretching it would smear the lit edge.
			var cut: float = filled.size.x / maxf(1.0, bed.size.x) * fill.get_width()
			draw_texture_rect_region(fill, filled,
				Rect2(0, 0, cut, fill.get_height()), Color(top.r, top.g, top.b, 0.98))
		elif filled.size.x > 1.0:
			draw_rect(filled, top)
	else:
		draw_rect(rect, Color("#0b0910"))
		draw_rect(filled, top)
		draw_rect(Rect2(filled.position + Vector2(0, filled.size.y * 0.55),
			Vector2(filled.size.x, filled.size.y * 0.45)), bottom)
		draw_rect(rect, Color("#0d0b12"), false, 2.4)
	# segment ticks, capped: a bar with sixty ticks is a bar
	var segments: int = clampi(int(rect.size.x / 26.0), 1, 12)
	for i in range(1, segments):
		var x: float = rect.position.x + rect.size.x * float(i) / float(segments)
		draw_line(Vector2(x, rect.position.y + 2), Vector2(x, rect.end.y - 2),
			Color(0.05, 0.04, 0.07, 0.5), 1.5)
	## Inside the bar rather than floating above it, so a gauge is one object
	## and the label cannot land on the plate's brass frame.
	_label(label, rect.position + Vector2(6, rect.size.y * 0.5 + 4.0), rect.size.x,
		HORIZONTAL_ALIGNMENT_LEFT, 11, BRASS_LIT)
	_value(value, rect.position + Vector2(-6, rect.size.y * 0.5 + 5.0), rect.size.x,
		HORIZONTAL_ALIGNMENT_RIGHT, 13)


## --- what is drawn over the fight -------------------------------------------
const ENEMY_NAMES := {
	"SCRAPPER": "SCRAPPER", "GUNNER": "DRONE", "ARMORED": "FURNACE KNIGHT",
	"SWARM": "GREMLIN", "BOSS": "THE COLOSSUS",
}
const LANE_NAMES := ["PORT", "CENTRE", "STARBOARD"]


## Where a point on the deck lands on screen, and whether it is on screen at
## all. `height` is above the planking in ground units.
func _to_screen(ground: Vector2, height: float) -> Dictionary:
	if view == null or view.camera == null:
		return {"ok": false, "at": Vector2.ZERO}
	var world := Vector3(ground.x, height, ground.y) * SkyGearView3D.WORLD_SCALE
	if view.camera.is_position_behind(world):
		return {"ok": false, "at": Vector2.ZERO}
	return {"ok": true, "at": view.camera.unproject_position(world)}


## A vignette. The browser darkens its own edges with a radial gradient over the
## whole canvas, and it is doing two jobs at once: it puts the eye on the middle
## of the deck where the fight is, and it stops the corners — which are always
## empty planking — from being the brightest thing in the frame.
var _vignette: ImageTexture


func _vignette_texture() -> ImageTexture:
	if _vignette != null:
		return _vignette
	var n := 96
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var u := (float(x) + 0.5) / float(n) * 2.0 - 1.0
			var v := (float(y) + 0.5) / float(n) * 2.0 - 1.0
			# elliptical, biased wider than tall so a 16:9 frame stays even
			var d: float = sqrt(u * u * 0.72 + v * v)
			img.set_pixel(x, y, Color(0, 0, 0, clampf(pow(maxf(0.0, d - 0.52) / 0.62, 1.7), 0.0, 1.0)))
	_vignette = ImageTexture.create_from_image(img)
	return _vignette


func _draw_world_overlay() -> void:
	if view == null:
		return
	draw_texture_rect(_vignette_texture(), Rect2(Vector2.ZERO, size), false,
		Color(1, 1, 1, 0.62))
	var frame := Rect2(Vector2.ZERO, size)
	var inset := frame.grow(-56.0)

	## Boarders: health when hurt, status when afflicted, a name when they are
	## something you have to treat differently.
	for enemy in game.get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or enemy.dead:
			continue
		var config: Dictionary = SkyGearData.ENEMIES.get(enemy.kind, {})
		var stand: float = 120.0 + float(config.get("radius", 22.0)) * 3.0
		var feet := _to_screen(enemy.global_position, 0.0)
		var head := _to_screen(enemy.global_position, stand + 26.0)
		var elite: bool = enemy.kind == "ARMORED" or enemy.kind == "BOSS"
		## Test the FEET, not the head. A tall boarder standing near the top of
		## the frame has its nameplate above the frame, and testing that put an
		## off-screen arrow over an enemy you were looking straight at.
		if not feet.ok or not frame.has_point(feet.at):
			if feet.ok:
				_edge_marker(feet.at, inset, Color("#ff4d37") if elite else Color("#ffb347"))
			continue
		if not head.ok:
			continue
		# the plate is pinned inside the frame when the head is not, but never on
		# top of the captain's own panel
		## Clamped to the top edge only. With the HUD along the bottom there is
		## nothing up there to collide with any more, which is the entire point
		## of having moved it.
		var at := Vector2(head.at.x, maxf(head.at.y, 20.0))
		var wide: float = 78.0 if enemy.kind == "BOSS" else (48.0 if elite else 34.0)
		if enemy.hp < enemy.max_hp or elite:
			var bar := Rect2(at - Vector2(wide * 0.5, 0.0), Vector2(wide, 5.0))
			draw_rect(bar.grow(1.5), Color(0.04, 0.03, 0.06, 0.85))
			draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(enemy.hp / enemy.max_hp,
				0.0, 1.0), bar.size.y)), Color("#e14f35") if not elite else Color("#ffb347"))
		if elite:
			# the plate is as wide as the NAME, not as wide as the health bar
			draw_string(font, at - Vector2(80.0, 6.0), str(ENEMY_NAMES.get(enemy.kind, enemy.kind)),
				HORIZONTAL_ALIGNMENT_CENTER, 160, 11, Color("#e8c376"))
		# status pips, left to right in the order they matter
		var pips: Array = []
		if enemy.burn_stacks > 0:
			pips.append(Color("#ff7a2f"))
		if enemy.slow_time > 0.0:
			pips.append(Color("#6fd8ff"))
		if enemy.stun_time > 0.0:
			pips.append(Color("#ffe08a"))
		for p in pips.size():
			draw_circle(at + Vector2(-wide * 0.5 + 4.0 + p * 9.0, 12.0), 3.2, pips[p])

	## The objective, when it is not in the frame. Losing sight of the Boiler is
	## normal — losing track of whether it is being hit is not.
	var boiler := _to_screen(game.boiler_position, 150.0)
	if boiler.ok and not frame.grow(-8.0).has_point(boiler.at):
		_edge_marker(boiler.at, inset, Color("#37f0c8"))
	elif not boiler.ok:
		_edge_marker(Vector2(size.x * 0.5, size.y * 2.0), inset, Color("#37f0c8"))

	## Which lane is about to break. The browser shouts this and it is the one
	## piece of text in the game that has ever changed what a tester did next.
	for lane in 3:
		var worst := 0.0
		for enemy in game.get_tree().get_nodes_in_group("enemies"):
			if not is_instance_valid(enemy) or enemy.dead or enemy.lane != lane:
				continue
			worst = maxf(worst, clampf((enemy.global_position.y
				- SkyGearGame.DECK_RECT.position.y) / SkyGearGame.DECK_RECT.size.y, 0.0, 1.0))
		if worst > 0.80:
			var x: float = size.x * (0.24 + lane * 0.26)
			draw_string(font, Vector2(x - 130.0, size.y * 0.22 + lane * 24.0),
				"%s LANE BREAKING" % LANE_NAMES[lane], HORIZONTAL_ALIGNMENT_CENTER, 260, 18,
				Color("#ff4d37"))

	## Salvage on the deck, marked. It heals you and it times out, and until now
	## the only sign of it was a small pile of scrap among a lot of small piles
	## of scrap.
	var scrap_icon := _tex("res://assets/art/ui/icon_salvage.png")
	if scrap_icon != null:
		for sc in game.salvage:
			var mark := _to_screen(Vector2(sc.position), 96.0)
			if not mark.ok or not frame.has_point(mark.at):
				continue
			var bob: float = sin(float(sc.time) * 4.0) * 3.0
			var fade: float = clampf(float(sc.time) / 3.0, 0.25, 1.0)
			draw_texture_rect(scrap_icon,
				Rect2(mark.at + Vector2(-11, -11 + bob), Vector2(22, 22)), false,
				Color(0.22, 0.94, 0.78, fade))

	## Numbers leaving bodies.
	for f in game.floaters:
		var t: float = float(f.time) / maxf(0.001, float(f.life))
		var spot := _to_screen(Vector2(f.position), 90.0)
		if not spot.ok:
			continue
		var colour: Color = f.color
		colour.a = clampf(1.0 - t * t, 0.0, 1.0)
		var pt: int = 22 if bool(f.big) else 16
		# an ink drop shadow, because a thin number over a lit deck is unreadable
		draw_string(font, spot.at + Vector2(-39.0, 2.0), str(f.text),
			HORIZONTAL_ALIGNMENT_CENTER, 80, pt, Color(0.03, 0.02, 0.04, colour.a * 0.85))
		draw_string(font, spot.at + Vector2(-40.0, 0.0), str(f.text),
			HORIZONTAL_ALIGNMENT_CENTER, 80, pt, colour)

	## Banners: wave numbers, IT TURNS, the run report having been copied.
	for e in game.effects:
		if str(e.kind) != "banner":
			continue
		var bt: float = float(e.time) / maxf(0.001, float(e.life))
		var fade: float = clampf(minf(bt * 6.0, (1.0 - bt) * 4.0), 0.0, 1.0)
		draw_string(font, Vector2(0.0, size.y * 0.26), str(e.text), HORIZONTAL_ALIGNMENT_CENTER,
			size.x, 42, Color(0.91, 0.77, 0.46, fade))


## A pointer pinned to the rim of the frame, aimed at something outside it.
func _edge_marker(toward: Vector2, inset: Rect2, colour: Color) -> void:
	var centre := inset.get_center()
	var dir := (toward - centre)
	if dir.length_squared() < 1.0:
		return
	dir = dir.normalized()
	# walk out from the centre until we leave the inset box
	var scale_x: float = INF if absf(dir.x) < 0.0001 else (inset.size.x * 0.5) / absf(dir.x)
	var scale_y: float = INF if absf(dir.y) < 0.0001 else (inset.size.y * 0.5) / absf(dir.y)
	var at := centre + dir * minf(scale_x, scale_y)
	var side := dir.orthogonal() * 9.0
	draw_colored_polygon(PackedVector2Array([at + dir * 13.0, at - dir * 8.0 + side,
		at - dir * 8.0 - side]), colour)
	draw_circle(at - dir * 4.0, 3.0, Color(0.04, 0.03, 0.06, 0.8))


## Where the draft cards are. Static and shared, so the thing that draws them
## and the thing that decides what was clicked cannot disagree — the same reason
## `hud_plates` exists.
const CARD_W := 280.0
const CARD_GAP := 28.0
const CARD_TOP := 200.0
const CARD_H := 340.0


static func draft_cards(view: Vector2, count: int) -> Array[Rect2]:
	var out: Array[Rect2] = []
	var span: float = CARD_W * float(count) + CARD_GAP * maxf(0.0, float(count) - 1.0)
	var start_x: float = (view.x - span) * 0.5
	for i in count:
		out.append(Rect2(start_x + i * (CARD_W + CARD_GAP), CARD_TOP, CARD_W, CARD_H))
	return out


## The reroll button, which was a line of text that said "(R)" and nothing a
## mouse could do anything with.
static func reroll_button(view: Vector2) -> Rect2:
	return Rect2(view.x * 0.5 - 120.0, CARD_TOP + CARD_H + 22.0, 240.0, 38.0)


func _draw_draft() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.015, 0.028, 0.78))
	_banner(size.x * 0.5, 88.0, 420.0)
	_center_text("CHOOSE ONE", 128.0, 34, Color("#e8c376"))
	_center_text("Every weapon is a shape crossed with an element.", 158.0, 18, Color("#b9afaa"))
	# reroll: two per RUN, so spending one is a decision about which hand
	var reroll := reroll_button(size)
	var can_reroll: bool = game.rerolls > 0
	var reroll_hot: bool = can_reroll and reroll.has_point(get_local_mouse_position())
	draw_rect(reroll, Color(0.69, 0.51, 0.25, 0.22 if reroll_hot else 0.10))
	draw_rect(reroll, BRASS_LIT if reroll_hot else BRASS, false, 2.0)
	_center_in_rect(("REROLL  x%d   (R)" % game.rerolls) if can_reroll else "NO REROLLS LEFT",
		Rect2(reroll.position + Vector2(0, 6), reroll.size), 18,
		BRASS_LIT if can_reroll else Color("#6a6478"))
	var card_width := CARD_W
	var cards := draft_cards(size, mini(3, game.draft_options.size()))
	for i in cards.size():
		var card: Dictionary = game.draft_options[i]
		var rect: Rect2 = cards[i]
		## The card under the pointer lifts and lights, because a card that does
		## not react to a cursor is a card a player does not know is clickable.
		var hovered: bool = rect.has_point(get_local_mouse_position())
		if hovered:
			rect = rect.grow(4.0)
		_panel(rect)
		_center_in_rect("%d  ·  CLICK OR PRESS %d" % [i + 1, i + 1],
			Rect2(rect.position + Vector2(0, 14), Vector2(rect.size.x, 30)), 13,
			Color("#ffe08a") if hovered else Color("#8b8296"))

		## The class band. Reported against the browser build in exactly these
		## words: it is not visually clear whether an upgrade enhances a skill
		## you have or hands you a new one. Both were a card with a title on it.
		var band := Rect2(rect.position + Vector2(18, 52), Vector2(card_width - 36, 26))
		var tint: Color = card.get("color", Color("#b0813f"))
		draw_rect(band, Color(tint.r, tint.g, tint.b, 0.16))
		draw_rect(band, tint, false, 2.0)
		_center_in_rect(str(card.get("class_label", "UPGRADE")),
			Rect2(band.position + Vector2(0, 3), band.size), 14, tint)

		_center_in_rect(str(card.title), Rect2(rect.position + Vector2(15, 96), Vector2(card_width - 30, 72)), 22, tint)
		_center_in_rect(str(card.text), Rect2(rect.position + Vector2(20, 150), Vector2(card_width - 40, 96)), 16, Color("#eee5d5"))

		## The shape, as its glyph. A card that hands you a weapon should show
		## you the weapon: nine shapes with nine icons already in `assets/`, and
		## "cone · burns targets" is a sentence rather than a picture.
		var glyph_shape := ""
		if str(card.get("kind", "")) == "skill":
			glyph_shape = str(card.skill.shape)
		elif card.has("shape"):
			glyph_shape = str(card.shape)
		if glyph_shape != "":
			var glyph := _tex(str(SLOT_ICONS.get(glyph_shape, "")))
			if glyph != null:
				var at := rect.position + Vector2(card_width * 0.5 - 34.0, 214.0)
				draw_texture_rect_region(glyph, Rect2(at, Vector2(68, 68)),
					Rect2(Vector2.ZERO, glyph.get_size()), tint)

		## And which of your skills it lands on, as glyphs, with the untouched
		## ones dim. A card that touches no skill says what it does touch —
		## four dark glyphs reads as "affects nothing".
		var hit: Array = card.get("affects", [])
		var row_y: float = rect.position.y + rect.size.y - 44.0
		## A weapon card does not "affect" the skills you already hold — it takes
		## a slot. Saying so beats four grey dots, which is what it was drawing.
		if str(card.get("kind", "")) == "skill":
			var slot_note := "ARMS SLOT %d" % (int(card.get("slot", game.skills.size())) + 1)
			if game.skills.size() >= 4:
				slot_note = "REPLACES A SLOT"
			_center_in_rect(slot_note, Rect2(Vector2(rect.position.x, row_y),
				Vector2(card_width, 24)), 13, tint)
		elif game.skills.is_empty() or hit.is_empty():
			var label := "AFFECTS THE CAPTAIN"
			match str(card.get("scope", "captain")):
				"ship": label = "AFFECTS THE BOILER"
				"deck": label = "AFFECTS THE DECK"
				"meta": label = "AFFECTS FUTURE DRAFTS"
				"new": label = "ARMS AN EMPTY SLOT"
			_center_in_rect(label, Rect2(Vector2(rect.position.x, row_y), Vector2(card_width, 24)), 13, tint)
		else:
			var count: int = game.skills.size()
			var step := 34.0
			var x0: float = rect.position.x + card_width * 0.5 - (count - 1) * step * 0.5
			for k in count:
				var lit: bool = hit.has(k)
				var centre := Vector2(x0 + k * step, row_y + 6.0)
				var skill_color: Color = SkyGearData.ELEMENTS[game.skills[k].element].color
				if lit:
					draw_circle(centre, 14.0, Color(tint.r, tint.g, tint.b, 0.18))
					draw_arc(centre, 14.0, 0.0, TAU, 20, tint, 2.0)
				draw_circle(centre, 7.0, skill_color if lit else Color(0.42, 0.40, 0.46))

## The controls screen.
##
## WASD is a QWERTY fact, not a universal one, and a player who cannot reach
## `dash` cannot dash. Ten rows, numbered so they are reachable without a cursor,
## and the menu keys are deliberately not on the list — rebinding your way out of
## the rebind screen leaves no way back in.
func _draw_keys() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.015, 0.028, 0.92))
	var sheet := Rect2(size.x * 0.5 - 300.0, 70.0, 600.0, 480.0)
	_sheet(sheet)
	_banner(size.x * 0.5, 84.0, 420.0)
	_center_text("CONTROLS", 124.0, 38, BRASS_LIT)
	_center_text("press a number to rebind that row", 154.0, 15, Color("#8b8296"))
	var y := sheet.position.y + 112.0
	for i in SkyGearKeybinds.REBINDABLE.size():
		var action: String = SkyGearKeybinds.REBINDABLE[i][0]
		var name: String = SkyGearKeybinds.REBINDABLE[i][1]
		var listening: bool = game.rebinding_index == i
		var row := Rect2(sheet.position.x + 30.0, y - 15.0, sheet.size.x - 60.0, 30.0)
		if listening:
			draw_rect(row, Color(0.69, 0.51, 0.25, 0.20))
			draw_rect(row, BRASS, false, 1.6)
		draw_string(font, Vector2(row.position.x + 10.0, y + 6.0),
			"%d" % ((i + 1) % 10), HORIZONTAL_ALIGNMENT_LEFT, 24, 15, Color("#6a6478"))
		draw_string(font, Vector2(row.position.x + 40.0, y + 6.0), name,
			HORIZONTAL_ALIGNMENT_LEFT, 240, 17, BONE)
		draw_string(font, Vector2(row.position.x, y + 6.0),
			"press a key…" if listening else SkyGearKeybinds.label(action),
			HORIZONTAL_ALIGNMENT_RIGHT, row.size.x - 12.0, 17,
			BRASS_LIT if listening else Color("#b9afaa"))
		y += 34.0
	if game.rebind_conflict != "":
		_center_text("that key already runs %s" % game.rebind_conflict.replace("_", " "),
			y + 14.0, 15, Color("#ff9a5a"))
	_center_text("Backspace resets · Esc closes · F2 toggles", sheet.end.y - 22.0, 15,
		Color("#37f0c8"))


func _draw_overlay(title: String, subtitle: String) -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.015, 0.028, 0.86))
	_center_text(title, 260.0, 52, Color("#e8c376"))
	var lines := subtitle.split("\n")
	for i in lines.size():
		_center_text(lines[i], 330.0 + i * 34.0, 22, Color("#eee5d5"))

## The results screen IS the run report. One block of text a player can read and
## copy, rather than a screen that says "twelve waves repelled" and a report
## somewhere else that says something different.
func _pause_text() -> String:
	var lines := "Esc / P to return to the deck"
	if game.audio != null:
		lines += "

volume  %d%%   (- and = to change, M to mute)" % roundi(float(game.audio.volumes.master) * 100.0)
		if game.audio.muted:
			lines += "
MUTED"
	lines += "

WASD move · mouse aim · LMB/RMB/Q/E skills · Space dash"
	lines += "
1/2/3 pick a card · R reroll · C copy the run report"
	return lines


func _draw_results(title: String, tint: Color) -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.015, 0.028, 0.90))
	var report: String = game.run_report()
	var body := report.split("
")
	var tall := 0.0
	for line in body:
		tall += 20.0 if str(line).begins_with("  ") else 23.0
	## Sized to the report rather than to the window. A fixed plate left three
	## hundred pixels of empty brass under a twelve-line run, which reads as a
	## screen that failed to load something.
	_sheet(Rect2(size.x * 0.5 - 400.0, 52.0, 800.0, minf(size.y - 104.0, tall + 232.0)))
	_banner(size.x * 0.5, 62.0, 520.0)
	_center_text(title, 110.0, 52, tint)
	if game.end_reason != "":
		_center_text(game.end_reason, 146.0, 18, Color("#b9afaa"))
	var lines := body
	var y := 188.0
	for i in lines.size():
		var line: String = lines[i]
		var small := line.begins_with("  ")
		draw_string(font, Vector2(size.x * 0.5 - 340.0, y), line,
			HORIZONTAL_ALIGNMENT_LEFT, 680, 15 if small else 17,
			Color("#b9afaa") if small else Color("#eee5d5"))
		y += 20.0 if small else 23.0
	y += 18.0
	_center_text("C to copy the report · Enter to return to title", y, 18, Color("#37f0c8"))
	var log_note := "saved to the run log" if game.run_logged 		else "COULD NOT WRITE THE RUN LOG — copy it before you leave"
	_center_text(log_note, y + 24.0, 14,
		Color("#6a6478") if game.run_logged else Color("#ff9a5a"))


func _center_text(text: String, y: float, font_size: int, color: Color) -> void:
	draw_string(font, Vector2(0, y), text, HORIZONTAL_ALIGNMENT_CENTER, size.x, font_size, color)

func _center_in_rect(text: String, rect: Rect2, font_size: int, color: Color) -> void:
	draw_string(font, rect.position + Vector2(0, font_size), text, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, font_size, color)

