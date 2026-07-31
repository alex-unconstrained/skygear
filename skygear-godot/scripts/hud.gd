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
## Buttons that behave like buttons. Every clickable thing here used to be an
## ad-hoc rect test written where it was drawn — no keyboard, no focus, no
## disabled state, no sound. That is why there was no settings screen and no way
## to quit from a pause.
var ui := SkyGearUI.new()

func _ready() -> void:
	font = ThemeDB.fallback_font
	ui.on_sound = func(kind: String) -> void:
		if game != null:
			game.play_sfx("ui/card_hover.ogg" if kind == "hover" else "ui/card_deal.ogg",
				-16.0 if kind == "hover" else -8.0)

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if game == null:
		return
	_in_frame = false
	_banner_claim = false
	if game.how_open:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.025, 0.045, 0.72))
		_draw_how()
		return
	if game.settings_open:
		match game.state_name:
			"TITLE":
				draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.025, 0.045, 0.72))
			_:
				_draw_world_overlay()
		_draw_settings()
		if game.layout_edit:
			_draw_layout_editor()
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
				_draw_pause()
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
			_draw_event(game.event_banner_left)
			_draw_coach()
	if game.layout_edit:
		_draw_layout_editor()
	if game.show_profiler:
		_draw_profiler()

func _draw_title() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.025, 0.045, 0.72))
	_banner(size.x * 0.5, 104.0, 600.0)
	_center_text("SKYGEAR", 150.0, 64, Color("#e8c376"))
	_center_text("STORM-DUSK · GODOT PORT", 205.0, 24, Color("#37f0c8"))
	_center_text("Keep the Boiler alive through twelve boarding waves.", 286.0, 22, Color("#eee5d5"))
	_center_text("WASD move · mouse aim · LMB/RMB/Q/E skills · Space dash", 330.0, 18, Color("#b9afaa"))
	## The title had one instruction — press Enter — and four more things you
	## could do that it never mentioned. All of them are buttons now.
	ui.begin("title", self, font, get_local_mouse_position())
	var tw := 300.0
	var tx: float = size.x * 0.5 - tw * 0.5
	var ty := 380.0
	if ui.button(Rect2(tx, ty, tw, 44.0), "BEGIN RUN",
			{"primary": true, "hint": "Enter"}):
		game.begin_run()
	if ui.button(Rect2(tx, ty + 52.0, tw, 38.0), "HOW TO PLAY", {"hint": "F1"}):
		game.how_open = true
	if ui.button(Rect2(tx, ty + 96.0, tw, 38.0), "SETTINGS", {"hint": "F5"}):
		game.settings_open = true
	if ui.button(Rect2(tx, ty + 140.0, tw, 38.0), "CONTROLS", {"hint": "F2"}):
		game.keys_open = true
	if ui.button(Rect2(tx, ty + 184.0, tw, 38.0), "QUIT", {"hint": "Alt+F4"}):
		game.quit_game()
	ty += 260.0
	## What the machine remembers. A title screen with a best-wave on it is the
	## cheapest possible reason to press Enter again.
	var history: Dictionary = SkyGearRunLog.summary()
	if int(history.runs) > 0:
		var line := "%d runs · best wave %d" % [int(history.runs), int(history.best_wave)]
		if int(history.wins) > 0:
			line += " · %d held" % int(history.wins)
			if str(history.best_time) != "":
				line += " (best %s)" % str(history.best_time)
		_center_text(line, ty, 17, Color("#b0813f"))
	_center_text("Milestone 1 · v11 combat vertical slice", ty + 46.0, 15,
		Color("#8f8697"))

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
## How thick the brass actually is, in destination pixels. Extracted because
## `interior()` used to answer this question with a DIFFERENT formula — it
## believed the rail was at most thirty pixels while this drew up to forty-eight,
## so every panel laid its content out against a frame narrower than the one on
## screen and the difference was drawn over the art. One function, one answer.
static func rail(rect: Rect2, margin: float = PLATE_MARGIN) -> float:
	return minf(maxf(1.0, margin), minf(rect.size.x, rect.size.y) * 0.45)


const PLATE_MARGIN := 48.0


func _nine(texture: Texture2D, rect: Rect2, margin: float) -> void:
	var t := texture.get_size()
	var m: float = minf(margin, minf(t.x, t.y) * 0.45)
	var inner: float = maxf(1.0, m)
	## source columns/rows, then destination columns/rows
	var sx := [0.0, inner, t.x - inner, t.x]
	var sy := [0.0, inner, t.y - inner, t.y]
	## The destination corners never scale below their own size, or a narrow
	## panel eats its own frame.
	var dm: float = rail(rect, inner)
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
	_open_frame(rect)
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


## Where the last banner was, so a title drawn on it is measured against the
## banner rather than against whatever plate happens to be open.
var _banner_rect := Rect2()


func _banner(centre_x: float, y: float, width: float) -> void:
	var plate := _tex("res://assets/art/ui/frame_hud.png")
	if plate == null:
		return
	var height: float = width * BANNER_REGION.size.y / BANNER_REGION.size.x
	_banner_rect = Rect2(centre_x - width * 0.5, y, width, height)
	draw_texture_rect_region(plate, _banner_rect, BANNER_REGION, Color(1, 1, 1, 0.9))
	## A title drawn after this belongs to the banner, not to whatever plate is
	## underneath it. The banner art is an ornament with its lettering area in the
	## middle two thirds, so that is the frame.
	## ...and claims the NEXT string only, then hands the frame back. A banner
	## holds one title; anything after it is page content and belongs to the plate
	## below. Claiming until the next panel put the whole run report inside the
	## banner and reported six lines as escaping it.
	_banner_frame = Rect2(_banner_rect.position.x + width * 0.14,
		_banner_rect.position.y - height * 0.45, width * 0.72, height * 1.85)
	_banner_claim = true


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
## The usable area inside a plate: everything the brass is not.
##
## This used to guess — `clamp(min_side * 0.19, 10, 30)` — while `_nine` drew a
## rail of `min(48, min_side * 0.45)`. On a 280-wide draft card that is 30 against
## 48, so text laid out at the "interior" edge started eighteen pixels inside the
## frame and ran off the other side. Reported as "the text begins outside of the
## frame and continues over onto the right".
##
## Now it asks the renderer. A little breathing room past the rail, because text
## touching brass is legible but looks like a mistake.
const RAIL_BREATH := 6.0

## A frame may never eat more than this much of the plate it frames. The rail is
## a fixed 48 in the nine-slice, which is honest on a 330-wide draft card and
## absurd on a 90-tall HUD strip — there `rail + breath` is 46 of 90, and the
## audit duly reported an interior four pixels tall. On a short plate the corner
## art is squeezed rather than cropped, so the painted brass is proportionally
## thinner than the slice carrying it, and this cap is the cheap approximation of
## that. Measured against the delivered plates, which is where the old 0.19 came
## from.
const RAIL_MAX_FRACTION := 0.22

static func interior(rect: Rect2) -> Rect2:
	var short: float = minf(rect.size.x, rect.size.y)
	var inset: float = minf(rail(rect) + RAIL_BREATH, short * RAIL_MAX_FRACTION)
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


## The frame cost, top-left, in a monospaced-ish block.
##
## Deliberately plain and deliberately ugly: it is a diagnostic, and a
## diagnostic that looks like part of the game is one people forget is on.
func _draw_profiler() -> void:
	if game.profiler == null:
		return
	var text: String = game.profiler.report(view, game)
	var lines: PackedStringArray = text.split("
")
	var box := Rect2(10, 10, 560, 10.0 + lines.size() * 17.0)
	draw_rect(box, Color(0.02, 0.015, 0.028, 0.86))
	draw_rect(box, Color("#37f0c8"), false, 1.0)
	for i in lines.size():
		draw_string(font, Vector2(18, 26 + i * 17), lines[i],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13,
			Color("#37f0c8") if i == 0 else Color("#cfc4b4"))


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


## --- every string the HUD draws goes through here ----------------------------
##
## Not for style. `tools/text_audit.gd` attaches an `audit` array and this is
## where a string gets measured against the width it was handed and against the
## panel it is inside — which is the only way to catch "the text begins outside
## the frame" as a class rather than one card at a time.
##
## The frame stack is pushed by `_panel`, so a string knows which plate it is on
## without every call site having to say.
var audit = null                     ## Array when auditing, null in a real game

## The plate a string belongs to. ONE, not a stack: this is immediate mode and
## the panels here are siblings — three draft cards drawn in a loop, five HUD
## plates in a row — so "the frame is whichever plate was drawn last" is exactly
## right, and a push/pop stack would need a scope the drawing code does not have.
## Cleared at the top of `_draw`, so a screen cannot inherit the previous one's.
var _frame := Rect2()
var _in_frame := false
var _banner_frame := Rect2()
var _banner_claim := false


func _open_frame(rect: Rect2) -> void:
	_frame = interior(rect)
	_in_frame = true


func _say(text: String, at: Vector2, width: float, align: int, pt: int,
		tint: Color) -> void:
	draw_string(font, at, text, align, width, pt, tint)
	if audit == null or text.strip_edges() == "":
		return
	var measured: float = font.get_string_size(text, align, -1, pt).x
	## The box the string will actually occupy, given its alignment. A
	## right-aligned string at x with width w ends at x + w and starts wherever
	## it is long enough to start, which is not the same rectangle at all.
	var left := at.x
	if align == HORIZONTAL_ALIGNMENT_CENTER:
		left = at.x + (width - measured) * 0.5
	elif align == HORIZONTAL_ALIGNMENT_RIGHT:
		left = at.x + width - measured
	var box := Rect2(left, at.y - pt, minf(measured, width), float(pt) * 1.3)
	if measured > width + 0.5:
		audit.append({"kind": "OVERFLOW", "text": text, "box": box,
			"measured": measured, "given": width,
			"frame": _frame if _in_frame else Rect2()})
		return
	var frame: Rect2 = _frame
	if _banner_claim:
		frame = _banner_frame
		_banner_claim = false
	elif not _in_frame:
		return
	## Vertical slop, because a baseline sitting a pixel proud of the interior is
	## not what anybody means by "outside the frame".
	if box.position.x < frame.position.x - 0.5 or box.end.x > frame.end.x + 0.5 			or box.position.y < frame.position.y - 4.0 or box.end.y > frame.end.y + 4.0:
		audit.append({"kind": "OUTSIDE", "text": text, "box": box,
			"measured": measured, "given": width, "frame": frame})


## Wrapped text. Audited the same way — this is where the card bodies go, and a
## card body is the thing that was reported.
func _says(text: String, at: Vector2, width: float, align: int, pt: int,
		lines: int, tint: Color) -> void:
	draw_multiline_string(font, at, text, align, width, pt, lines, tint)
	if audit == null or text.strip_edges() == "":
		return
	## Longest line after wrapping, which is what decides whether the block fits.
	## Measuring the whole string would report a paragraph as one enormous line.
	var widest := 0.0
	var count := 1
	var run := ""
	for word in text.split(" "):
		var trial: String = word if run == "" else run + " " + word
		if font.get_string_size(trial, align, -1, pt).x > width and run != "":
			widest = maxf(widest, font.get_string_size(run, align, -1, pt).x)
			run = word
			count += 1
		else:
			run = trial
	widest = maxf(widest, font.get_string_size(run, align, -1, pt).x)

	if count > lines:
		audit.append({"kind": "OVERFLOW", "text": text,
			"box": Rect2(at, Vector2(width, float(pt) * 1.3 * count)),
			"measured": float(count), "given": float(lines),
			"frame": _frame if _in_frame else Rect2()})
		return
	if not _in_frame:
		return
	var left := at.x
	if align == HORIZONTAL_ALIGNMENT_CENTER:
		left = at.x + (width - widest) * 0.5
	elif align == HORIZONTAL_ALIGNMENT_RIGHT:
		left = at.x + width - widest
	var box := Rect2(left, at.y - pt, widest, float(pt) * 1.3 * count)
	if box.position.x < _frame.position.x - 0.5 or box.end.x > _frame.end.x + 0.5 			or box.position.y < _frame.position.y - 4.0 or box.end.y > _frame.end.y + 4.0:
		audit.append({"kind": "OUTSIDE", "text": text, "box": box,
			"measured": widest, "given": width, "frame": _frame})


## The largest size at which this string fits. A slot label reading "Ember
## Cleav" is a slot label that has failed at its only job, and every one of these
## boxes is a fixed size set by the plate art — so the text yields, not the box.
func _fits(text: String, width: float, pt: int, floor_pt: int = 9) -> int:
	var size_pt := pt
	while size_pt > floor_pt and font.get_string_size(text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, size_pt).x > width:
		size_pt -= 1
	return size_pt


func _label(text: String, at: Vector2, width: float, align: int, pt: int = 12,
		tint: Color = Color("#cfc4b4")) -> void:
	draw_string(font, at + Vector2(1, 1), text, align, width, pt, INK)
	_say(text, at, width, align, pt, tint)


func _value(text: String, at: Vector2, width: float, align: int, pt: int = 15,
		tint: Color = Color("#fff6e4")) -> void:
	draw_string(font, at + Vector2(1.5, 1.5), text, align, width, pt, INK)
	_say(text, at, width, align, pt, tint)


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

	## THE AUTO-ATTACK, as a ring around her portrait.
	##
	## She swings every 0.36s at anything inside 190 units and nothing has ever
	## said so. It is a fifth of a run's damage on most builds, it is the reason
	## standing next to a boarder is not passive, and a player who does not know
	## it exists reads "close range" as a risk with no upside — which is the same
	## misreading the coach and HOW TO PLAY were both written to fix.
	##
	## On the portrait rather than in the slot row, because it is not a slot: it
	## costs no key and cannot be drafted away. A sweep that fills, and a soft
	## flare on the frame it lands.
	var auto_period: float = 0.45 * 0.8
	var auto_left: float = clampf(float(game.basic_cooldown), 0.0, auto_period)
	var swung: float = 1.0 - auto_left / auto_period
	var reach: float = portrait_at.size.x * 0.5 + 7.0
	draw_arc(portrait_at.get_center(), reach, -PI * 0.5, -PI * 0.5 + TAU * swung,
		36, Color("#ff9a4a"), 2.6)
	if swung >= 0.999:
		## Ready, and there is something in reach for it to hit. A full ring over
		## an empty deck would read as a cooldown that never fires.
		var prey = game.nearest_enemy(game.player.global_position, 190.0)
		if prey != null:
			draw_arc(portrait_at.get_center(), reach, 0.0, TAU, 36,
				Color(1.0, 0.72, 0.36, 0.55), 4.4)

	var health := l.item("captain", "health", panel)
	_bar(health, player.hp / player.max_hp, Color("#e8542e"), Color("#8b2418"),
		"CAPTAIN", "%d / %d" % [player.hp, player.max_hp])
	## And what is true of HER right now, in the same chips the boarders use, so
	## there is one vocabulary rather than two. Only states that change what she
	## should do: untouchable mid-dash, and a gauge that is ready to vent.
	var mine: Array = []
	if player.invulnerability_left > 0.0:
		mine.append({"kind": "invuln", "remaining": player.invulnerability_left / 0.4})
	if player.pressure >= 100.0:
		mine.append({"kind": "vent", "remaining": 1.0})
	_status_chips(Vector2(health.get_center().x, health.end.y + 5.0), mine)

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
	var owned: int = maxi(1, player.max_dash_charges)
	var pip_r: float = minf(pips.size.y, pips.size.x / float(owned)) * 0.5
	for i in owned:
		var lit := i < player.dash_charges
		var at := Vector2(pips.position.x + pip_r + i * pip_r * 2.2, pips.get_center().y)
		if pip_art != null:
			draw_texture_rect_region(pip_art,
				Rect2(at - Vector2(pip_r, pip_r), Vector2(pip_r * 2, pip_r * 2)),
				Rect2(Vector2.ZERO, pip_art.get_size()),
				Color("#9ff5e2") if lit else Color(0.28, 0.26, 0.32))
		else:
			draw_circle(at, pip_r, Color("#37f0c8") if lit else Color("#201c28"))
		## The one currently recharging fills, so "nearly" is visible. Waiting on
		## a dash with no idea how long is the most common reason to walk into
		## something.
		if not lit and i == player.dash_charges and player.dash_recharge_left > 0.0:
			var done: float = 1.0 - clampf(player.dash_recharge_left
				/ maxf(0.01, SkyGearPlayer.DASH_RECHARGE), 0.0, 1.0)
			draw_arc(at, pip_r - 1.0, -PI * 0.5, -PI * 0.5 + TAU * done, 20,
				Color("#37f0c8"), 2.4)

	## --- the objective, top centre ------------------------------------------
	## The thing you lose by, where an eye goes first, rather than in a corner
	## competing with three lane tracks for attention.
	var top: Rect2 = plates.objective
	_panel(top)
	var ratio: float = game.boiler_hp / maxf(1.0, game.boiler_max_hp)
	_bar(l.item("objective", "boiler", top), ratio,
		Color("#37f0c8") if ratio > 0.34 else Color("#ff6a3a"),
		Color("#1c6f61") if ratio > 0.34 else Color("#8b2418"), "BOILER",
		"%d / %d" % [game.boiler_hp, game.boiler_max_hp])
	var wave_at := l.item("objective", "wave", top)
	var wave_text := "WAVE %d / 12" % game.wave
	_value(wave_text, wave_at.position + Vector2(0, wave_at.size.y - 4.0), wave_at.size.x,
		HORIZONTAL_ALIGNMENT_LEFT, _fits(wave_text, wave_at.size.x, 16, 11), BRASS_LIT)
	var boarders_at := l.item("objective", "boarders", top)
	var boarders_text := "BOARDERS %d" % game.enemy_count()
	_value(boarders_text, boarders_at.position + Vector2(0, boarders_at.size.y - 4.0),
		boarders_at.size.x, HORIZONTAL_ALIGNMENT_RIGHT,
		_fits(boarders_text, boarders_at.size.x, 16, 11))

	## --- the lanes ----------------------------------------------------------
	var right: Rect2 = plates.ship
	_panel(right)

	## Which lane is breaking, without having to look at it.
	var names := ["PORT", "CENTRE", "STARBOARD"]
	var l_ship := l
	for lane in 3:
		var row := l.item("ship", "lane%d" % lane, right)
		var name_w: float = minf(70.0, row.size.x * 0.34)
		_label(names[lane], row.position + Vector2(0, row.size.y - 3.0), name_w,
			HORIZONTAL_ALIGNMENT_LEFT, _fits(names[lane], name_w, 11, 8))
		var track := Rect2(row.position.x + name_w + 4.0, row.get_center().y - 4.0,
			maxf(20.0, row.size.x - name_w - 26.0), 9.0)
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
			## "EMPTY", not "LOCKED". Nothing gates these by wave — a slot fills
			## when you draft a weapon into it — and calling it locked tells a
			## player to wait for something that is never going to arrive.
			_label("EMPTY", name_at.position + Vector2(0, name_at.size.y - 3.0),
				name_at.size.x, HORIZONTAL_ALIGNMENT_CENTER, 13, Color("#6f6878"))
			## Shrunk to the slot rather than clipped to "draft a wea", and given
			## the whole slot to sit in rather than the icon plus a guess.
			var hint_w: float = maxf(icon_at.size.x + 24.0, name_at.size.x)
			_label("draft a weapon",
				Vector2(name_at.get_center().x - hint_w * 0.5,
					icon_at.get_center().y + 4.0), hint_w,
				HORIZONTAL_ALIGNMENT_CENTER,
				_fits("draft a weapon", hint_w, 10, 7), Color("#5f5863"))
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
			## The number, not just the wedge. "Can I press this in time" is a
			## question an angle cannot answer.
			_value("%.1f" % float(skill.cooldown_left),
				Vector2(icon_at.position.x, icon_at.get_center().y + 6.0),
				icon_at.size.x, HORIZONTAL_ALIGNMENT_CENTER, 15, Color("#fff6e4"))
		var slot_name: String = SkyGearData.skill_name(skill)
		_label(slot_name, name_at.position + Vector2(0, name_at.size.y - 3.0),
			name_at.size.x, HORIZONTAL_ALIGNMENT_CENTER,
			_fits(slot_name, name_at.size.x, 12, 9),
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


## --- health, and what is wrong with you -------------------------------------
##
## The bars were five pixels tall and thirty-four wide with three-pixel dots
## under them for burning, slowed and stunned. At the distance this camera sits
## that is not a readout, it is a rumour — and the statuses matter: a slowed
## boarder is one you can walk away from, a stunned one is a free hit, and a
## burning one is going to die whether you keep hitting it or not.
##
## Bigger, but not by much: the fix for legibility is contrast and structure
## rather than size. A dark bed so the bar reads against a lit deck, an ink edge
## so it reads against anything, a lighter top edge so it has a shape, and
## segment ticks so a half-full bar is countable rather than estimated.
const ENEMY_BAR_H := 7.0
const ENEMY_BAR_W := {"BOSS": 120.0, "ARMORED": 68.0, "SCRAPPER": 52.0,
	"GUNNER": 50.0, "SWARM": 40.0}

## Each status is a chip: the colour, a letter, and a bar underneath that drains
## with the time left. Colour alone fails for a colour-blind player and a dot
## alone cannot show how long is left, which is the only actionable part.
const STATUS_LOOK := {
	"burn": {"tint": Color("#ff7a2f"), "mark": "B"},
	"slow": {"tint": Color("#6fd8ff"), "mark": "S"},
	"stun": {"tint": Color("#ffe08a"), "mark": "!"},
	"vent": {"tint": Color("#c9b6e8"), "mark": "V"},
	"invuln": {"tint": Color("#37f0c8"), "mark": "I"},
}
const CHIP_W := 15.0
const CHIP_H := 13.0


## One health bar, drawn the same way everywhere so the captain's and a
## boarder's are read with the same eye.
func _health_bar(rect: Rect2, ratio: float, tint: Color) -> void:
	draw_rect(rect.grow(2.0), Color(0.03, 0.02, 0.045, 0.92))
	draw_rect(rect, Color(0.10, 0.07, 0.11, 0.95))
	var fill := Rect2(rect.position,
		Vector2(rect.size.x * clampf(ratio, 0.0, 1.0), rect.size.y))
	if fill.size.x > 0.5:
		draw_rect(fill, tint)
		## A lit top edge. Two pixels, and it is the difference between a
		## coloured rectangle and something with a surface.
		draw_rect(Rect2(fill.position, Vector2(fill.size.x, 2.0)),
			tint.lightened(0.42))
	## Segment ticks, so a bar is countable rather than estimated. Capped, or a
	## boss bar becomes a comb.
	var segments: int = clampi(int(rect.size.x / 17.0), 1, 8)
	for i in range(1, segments):
		var x: float = rect.position.x + rect.size.x * float(i) / float(segments)
		draw_line(Vector2(x, rect.position.y), Vector2(x, rect.end.y),
			Color(0.03, 0.02, 0.045, 0.55), 1.0)
	draw_rect(rect, Color(0.03, 0.02, 0.045, 0.9), false, 1.0)


## A row of status chips, centred under a bar. `remaining` drives the drain, so
## a chip about to expire looks like one.
func _status_chips(centre: Vector2, chips: Array) -> void:
	if chips.is_empty():
		return
	var total: float = chips.size() * CHIP_W + (chips.size() - 1) * 3.0
	var x: float = centre.x - total * 0.5
	for chip in chips:
		var look: Dictionary = STATUS_LOOK.get(str(chip.kind), STATUS_LOOK.burn)
		var box := Rect2(x, centre.y, CHIP_W, CHIP_H)
		draw_rect(box.grow(1.0), Color(0.03, 0.02, 0.045, 0.9))
		draw_rect(box, Color(look.tint.r, look.tint.g, look.tint.b, 0.30))
		draw_rect(box, look.tint, false, 1.0)
		draw_string(font, Vector2(box.position.x, box.end.y - 3.0), str(look.mark),
			HORIZONTAL_ALIGNMENT_CENTER, CHIP_W, 11, look.tint.lightened(0.4))
		## Stacks, where a status has them — three burns is not one burn.
		if int(chip.get("stacks", 0)) > 1:
			draw_string(font, Vector2(box.end.x - 7.0, box.position.y + 6.0),
				str(int(chip.stacks)), HORIZONTAL_ALIGNMENT_LEFT, 10, 9,
				Color("#fff6e4"))
		var left: float = clampf(float(chip.get("remaining", 1.0)), 0.0, 1.0)
		draw_rect(Rect2(box.position.x, box.end.y + 1.0, CHIP_W * left, 2.0), look.tint)
		x += CHIP_W + 3.0


func _status_row(enemy, at: Vector2, _wide: float) -> void:
	var chips: Array = []
	if enemy.burn_stacks > 0:
		chips.append({"kind": "burn", "remaining": enemy.burn_time / 3.0,
			"stacks": enemy.burn_stacks})
	if enemy.slow_time > 0.0:
		chips.append({"kind": "slow", "remaining": enemy.slow_time / 2.0})
	if enemy.stun_time > 0.0:
		chips.append({"kind": "stun", "remaining": enemy.stun_time / 0.45})
	_status_chips(at, chips)


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


## The event card. Not a banner that flashes and goes — an event that changes
## how a wave should be played has to be readable for long enough to read.
## The coach's one line. Deliberately quiet: no plate, no icon, no sound — a
## line of text under the objective, where the eye already goes for the wave
## number. A hint that announces itself is a hint that interrupts, and this
## fires while a player is being shot at.
func _draw_coach() -> void:
	var line: String = str(game.coach_line)
	if line == "":
		return
	## Drawn after the HUD plates, and it belongs to none of them — without this
	## the audit measures it against whichever plate was opened last.
	_in_frame = false
	var band := Rect2(size.x * 0.5 - 380.0, size.y * 0.115, 760.0, 26.0)
	## A dark strip behind it, because this is drawn over the deck and the deck is
	## a lit wooden floor at the top of frame where the boarders are.
	draw_rect(band, Color(0.03, 0.02, 0.045, 0.62))
	draw_rect(Rect2(band.position, Vector2(3.0, band.size.y)), Color("#37f0c8"))
	_label(line, Vector2(band.position.x + 12.0, band.position.y + 18.0),
		band.size.x - 24.0, HORIZONTAL_ALIGNMENT_LEFT,
		_fits(line, band.size.x - 24.0, 15, 11), Color("#bfe9df"))


func _draw_event(seconds_left: float) -> void:
	var data: Dictionary = game.event_data()
	if data.is_empty() or seconds_left <= 0.0:
		return
	## Fades in fast and out slow, so it does not steal the moment the wave
	## starts and does not vanish while you are still reading it.
	var age: float = game.EVENT_BANNER_TIME - seconds_left
	var alpha: float = clampf(minf(age / 0.25, seconds_left / 0.9), 0.0, 1.0)
	var tint := Color(str(data.get("tint", "#ff9a4a")))
	var card := Rect2(size.x * 0.5 - 330.0, size.y * 0.20, 660.0, 96.0)
	draw_rect(card, Color(0.03, 0.02, 0.045, 0.80 * alpha))
	draw_rect(card, Color(tint.r, tint.g, tint.b, 0.85 * alpha), false, 2.0)
	## A bar of the event colour down the leading edge, so the kind of event is
	## legible before the words are.
	draw_rect(Rect2(card.position, Vector2(5.0, card.size.y)),
		Color(tint.r, tint.g, tint.b, alpha))
	var room := card.grow(-18.0)
	_label("WAVE %d · EVENT" % game.wave, Vector2(room.position.x, room.position.y + 12.0),
		room.size.x, HORIZONTAL_ALIGNMENT_LEFT, 12,
		Color(tint.r, tint.g, tint.b, 0.85 * alpha))
	_say(str(data.name), Vector2(room.position.x, room.position.y + 40.0),
		room.size.x, HORIZONTAL_ALIGNMENT_LEFT,
		_fits(str(data.name), room.size.x, 30, 18), Color(tint.r, tint.g, tint.b, alpha))
	_says(str(data.blurb), Vector2(room.position.x, room.position.y + 62.0),
		room.size.x, HORIZONTAL_ALIGNMENT_LEFT, 15, 2,
		Color(0.93, 0.90, 0.84, alpha))


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
		var wide: float = ENEMY_BAR_W.get(enemy.kind, 52.0)
		if enemy.hp < enemy.max_hp or elite:
			_health_bar(Rect2(at - Vector2(wide * 0.5, 0.0), Vector2(wide, ENEMY_BAR_H)),
				enemy.hp / maxf(1.0, enemy.max_hp),
				Color("#ffb347") if elite else Color("#e14f35"))
		if elite:
			# the plate is as wide as the NAME, not as wide as the health bar
			draw_string(font, at - Vector2(80.0, 8.0), str(ENEMY_NAMES.get(enemy.kind, enemy.kind)),
				HORIZONTAL_ALIGNMENT_CENTER, 160, 11, Color("#e8c376"))
		_status_row(enemy, at + Vector2(0.0, ENEMY_BAR_H + 11.0), wide)

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
## 280 wide with a 48px brass rail on each side left 172 usable, and the card
## body, the title and every preview row were laid out at fixed offsets from the
## OUTER edge — so they started on the brass and ran off the far side. That is
## the reported bug: "the text begins outside of the frame and continues over
## onto the right". `tools/text_audit.gd` found 34 strings doing it.
##
## Wider, because the content is the content: 330 leaves 222 inside the rail,
## which fits the longest card sentence in the catalogue at two lines. Everything
## below now measures from `interior(rect)` rather than from the card edge, so
## this number can move again without breaking the layout.
const CARD_W := 330.0
const CARD_GAP := 26.0
const CARD_TOP := 190.0
const CARD_H := 372.0


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
	## The game HUD is drawn under this, and it leaves its last plate open. A
	## full-screen instruction is not on that plate, and the audit rightly said so.
	_in_frame = false
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.015, 0.028, 0.78))
	_banner(size.x * 0.5, 88.0, 420.0)
	_center_text("CHOOSE ONE", 128.0, 34, Color("#e8c376"))
	_center_text("Click a card, or press its number.", 158.0, 18, Color("#b9afaa"))
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
		## EVERYTHING below is measured from here. The card is brass around a
		## hole; the hole is what you may write in.
		var face := interior(rect)

		## The class band. Reported against the browser build in exactly these
		## words: it is not visually clear whether an upgrade enhances a skill
		## you have or hands you a new one. Both were a card with a title on it.
		var band := Rect2(face.position, Vector2(face.size.x, 26))
		var tint: Color = card.get("color", Color("#b0813f"))
		draw_rect(band, Color(tint.r, tint.g, tint.b, 0.16))
		draw_rect(band, tint, false, 2.0)
		_center_in_rect("%d  ·  %s" % [i + 1, str(card.get("class_label", "UPGRADE"))],
			Rect2(band.position + Vector2(0, 3), band.size), 14, tint)

		## The title, shrunk to fit rather than clipped. "SLOW COMBUSTION" at 22pt
		## is 216 wide against 222 of card; one longer name and it is over the
		## edge, and a title that silently loses its last word is worse than a
		## title one point smaller.
		var title := str(card.title)
		var title_pt := 22
		while title_pt > 14 and font.get_string_size(title, HORIZONTAL_ALIGNMENT_CENTER,
				-1, title_pt).x > face.size.x:
			title_pt -= 1
		_say(title, Vector2(face.position.x, band.end.y + 34.0), face.size.x,
			HORIZONTAL_ALIGNMENT_CENTER, title_pt, tint)
		_says(str(card.text), Vector2(face.position.x, band.end.y + 74.0),
			face.size.x, HORIZONTAL_ALIGNMENT_CENTER, 16, 3, Color("#eee5d5"))

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
			if glyph != null and SkyGearCards.preview(game, card).is_empty():
				var at := Vector2(face.get_center().x - 34.0, band.end.y + 96.0)
				draw_texture_rect_region(glyph, Rect2(at, Vector2(68, 68)),
					Rect2(Vector2.ZERO, glyph.get_size()), tint)

		## BEFORE -> AFTER. The card said "hits harder" and left you to guess by
		## how much, against a current value it also did not show.
		var rows: Array = SkyGearCards.preview(game, card)
		if not rows.is_empty():
			var ry: float = band.end.y + 132.0
			var rx: float = face.position.x
			var rw: float = face.size.x
			## A rule above them, so the numbers read as a consequence of the
			## sentence rather than as more of it.
			draw_line(Vector2(rx, ry - 12.0), Vector2(rx + rw, ry - 12.0),
				Color(tint.r, tint.g, tint.b, 0.35), 1.0)
			for r in rows.slice(0, SkyGearCards.PREVIEW_ROWS):
				var good: bool = bool(r.better)
				_label(str(r.label), Vector2(rx, ry), rw * 0.5,
					HORIZONTAL_ALIGNMENT_LEFT, _fits(str(r.label), rw * 0.5, 12, 8))
				## Old value struck through in grey, new value lit. An arrow with
				## two live-looking numbers reads as a range, not a change.
				var old_at := Vector2(rx + rw * 0.52, ry)
				_say(str(r.before), old_at, rw * 0.2, HORIZONTAL_ALIGNMENT_LEFT, 12, Color("#6a6478"))
				_say("->", Vector2(rx + rw * 0.72, ry), 20,
					HORIZONTAL_ALIGNMENT_LEFT, 12, Color("#6a6478"))
				_say(str(r.after), Vector2(rx + rw * 0.80, ry), rw * 0.22,
					HORIZONTAL_ALIGNMENT_LEFT, 12,
					Color("#7be8a8") if good else Color("#ff9a5a"))
				ry += 16.0
			if rows.size() > SkyGearCards.PREVIEW_ROWS:
				_label("+%d more" % (rows.size() - SkyGearCards.PREVIEW_ROWS),
					Vector2(rx, ry), rw, HORIZONTAL_ALIGNMENT_LEFT, 11)

		## And which of your skills it lands on, as glyphs, with the untouched
		## ones dim. A card that touches no skill says what it does touch —
		## four dark glyphs reads as "affects nothing".
		var hit: Array = card.get("affects", [])
		var row_y: float = face.end.y - 22.0
		## A weapon card does not "affect" the skills you already hold — it takes
		## a slot. Saying so beats four grey dots, which is what it was drawing.
		if str(card.get("kind", "")) == "skill":
			var slot_note := "ARMS SLOT %d" % (int(card.get("slot", game.skills.size())) + 1)
			if game.skills.size() >= 4:
				slot_note = "REPLACES A SLOT"
			_say(slot_note, Vector2(face.position.x, row_y + 13.0), face.size.x,
				HORIZONTAL_ALIGNMENT_CENTER, 13, tint)
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
	var row_count: int = SkyGearKeybinds.REBINDABLE.size()
	var sheet := Rect2(size.x * 0.5 - 300.0, 70.0, 600.0,
		136.0 + row_count * 34.0 + 76.0)
	_sheet(sheet)
	_banner(size.x * 0.5, 84.0, 420.0)
	_center_text("CONTROLS", 124.0, 38, BRASS_LIT)
	_center_text("press a number to rebind that row", 154.0, 15, Color("#8b8296"))
	## Against the plate's own interior. Thirty pixels in from a 600-wide sheet is
	## inside the brass, so the row number and the key name were both drawn on the
	## frame — the audit reported "1", "2", "W" and "S" every run.
	var page := interior(sheet)
	var y := page.position.y + 68.0
	for i in SkyGearKeybinds.REBINDABLE.size():
		var action: String = SkyGearKeybinds.REBINDABLE[i][0]
		var name: String = SkyGearKeybinds.REBINDABLE[i][1]
		var listening: bool = game.rebinding_index == i
		var row := Rect2(page.position.x, y - 15.0, page.size.x, 30.0)
		if listening:
			draw_rect(row, Color(0.69, 0.51, 0.25, 0.20))
			draw_rect(row, BRASS, false, 1.6)
		_say("%d" % ((i + 1) % 10), Vector2(row.position.x + 10.0, y + 6.0), 24,
			HORIZONTAL_ALIGNMENT_LEFT, 15, Color("#6a6478"))
		_say(name, Vector2(row.position.x + 40.0, y + 6.0), 240,
			HORIZONTAL_ALIGNMENT_LEFT, 17, BONE)
		_say("press a key…" if listening else SkyGearKeybinds.label(action),
			Vector2(row.position.x, y + 6.0), row.size.x - 12.0,
			HORIZONTAL_ALIGNMENT_RIGHT, 17,
			BRASS_LIT if listening else Color("#b9afaa"))
		y += 34.0
	if game.rebind_conflict != "":
		_center_text("that key already runs %s" % game.rebind_conflict.replace("_", " "),
			y + 14.0, 15, Color("#ff9a5a"))
	_center_text("Backspace resets · Esc closes · F2 toggles",
		interior(sheet).end.y - 4.0, 15,
		Color("#37f0c8"))


## The pause menu, as a menu.
##
## It was a static block of text, so from a paused run there was no way to
## restart or quit to the title short of alt-F4. Five buttons, reachable by
## mouse or keyboard, with the loadout underneath — the only place in the game a
## player can read what their build actually does without being shot at.
func _draw_pause() -> void:
	_in_frame = false
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.015, 0.028, 0.88))
	## Sized to what is in it. The buttons are a fixed stack and the build list
	## is one row per skill, so the height is arithmetic rather than a guess —
	## and a frame with three hundred empty pixels under the last button reads as
	## a screen that failed to load.
	var rows: int = maxi(game.skills.size(), 1)
	var body := 272.0 + (66.0 if game.audio != null else 0.0)
	var tall: float = maxf(body, 26.0 + rows * 40.0) + 118.0
	var top: float = maxf(70.0, (size.y - tall) * 0.5)
	var sheet := Rect2(size.x * 0.5 - 330.0, top, 660.0, tall)
	_panel(sheet)
	## The banner rides the panel rather than a screen constant, or it lands on
	## the first button the moment the panel moves.
	_banner(size.x * 0.5, sheet.position.y - 10.0, 420.0)
	_center_text("PAUSED", sheet.position.y + 48.0, 40, BRASS_LIT)

	ui.begin("pause", self, font, get_local_mouse_position())
	var bw := 300.0
	var bx := sheet.position.x + 26.0
	var by := sheet.position.y + 82.0
	if ui.button(Rect2(bx, by, bw, 40.0), "RESUME", {"primary": true, "hint": "Esc"}):
		game.toggle_pause()
	if ui.button(Rect2(bx, by + 46.0, bw, 40.0), "HOW TO PLAY", {"hint": "F1"}):
		game.how_open = true
	if ui.button(Rect2(bx, by + 92.0, bw, 40.0), "RESTART RUN"):
		game.restart_run()
	if ui.button(Rect2(bx, by + 138.0, bw, 40.0), "QUIT TO TITLE"):
		game.go_to_title()
	if game.audio != null:
		game.audio.set_volume("master", ui.slider(
			Rect2(bx, by + 194.0, bw, 30.0), "VOLUME", float(game.audio.volumes.master)))
		if ui.button(Rect2(bx, by + 230.0, bw, 34.0),
				"UNMUTE" if game.audio.muted else "MUTE", {"hint": "M"}):
			game.audio.toggle_mute()

	## The loadout. Reading what your own build does should not require being
	## shot at while you do it.
	## The build column, bounded by the plate rather than by a guess. The cooldown
	## figures were right-aligned to a fixed 260 from a left edge that did not know
	## where the brass was, so every one of them printed on the frame.
	var room := interior(sheet)
	var lx := bx + bw + 26.0
	var lw: float = maxf(120.0, room.end.x - lx)
	_label("YOUR BUILD", Vector2(lx, by + 4.0), lw, HORIZONTAL_ALIGNMENT_LEFT, 12)
	var ly := by + 26.0
	for i in game.skills.size():
		var skill: Dictionary = game.skills[i]
		var tint: Color = SkyGearData.ELEMENTS[skill.element].color
		var st: Dictionary = game.skill_stats(skill)
		var icon := _tex(str(SLOT_ICONS.get(skill.shape, "")))
		if icon != null:
			draw_texture_rect_region(icon, Rect2(lx, ly, 26, 26),
				Rect2(Vector2.ZERO, icon.get_size()), tint)
		_value(SkyGearData.skill_name(skill), Vector2(lx + 34.0, ly + 13.0),
			lw - 74.0, HORIZONTAL_ALIGNMENT_LEFT, 15, tint)
		_label("%s · %s" % [str(SkyGearData.SHAPES[skill.shape].kind),
			str(SkyGearData.ELEMENTS[skill.element].blurb)],
			Vector2(lx + 34.0, ly + 27.0), lw - 74.0, HORIZONTAL_ALIGNMENT_LEFT, 11)
		_label("%.2fs" % float(st.cooldown), Vector2(lx, ly + 27.0), lw,
			HORIZONTAL_ALIGNMENT_RIGHT, 11, BRASS)
		ly += 40.0
	_label("WASD move · mouse aim · Space dash · F4 layout · F3 stats",
		Vector2(room.position.x, room.end.y - 4.0), room.size.x,
		HORIZONTAL_ALIGNMENT_CENTER, 12)


## Settings. There were none — volume was two keys nobody knew about, and every
## other option was a function key mentioned once on the title screen. Four
## channels rather than one, because the report that started this was "SFX with
## character audio weren't really easy to hear against the other sounds", and a
## single master slider cannot answer that.
## HOW TO PLAY. The title screen said "keep the Boiler alive through twelve
## boarding waves" and listed the keys, which tells you the controls and none of
## the game — and this game has exactly one idea that is not obvious from the
## controls: the gauge fills from fighting CLOSE, so the safe thing to do is the
## losing thing to do. A player who does not know that kites, runs out of heals
## and concludes the game is unfair.
##
## Numbers, not adjectives. "Fills faster when you fight close" is a sentence a
## player can nod at and not act on; "inside 210 units" is a distance they can
## learn. Read from the same tables the simulation reads, so this page cannot
## drift away from the game.
func _draw_how() -> void:
	_in_frame = false
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.015, 0.028, 0.93))
	var close: Dictionary = SkyGearData.CLOSE
	var lines: Array = [
		["THE ONE THING", ""],
		["", "Your gauge fills from damage you land within %d units and from being crowded — and empties when you are not. It is not a reward for surviving, it is a reward for being in reach." % int(close.range)],
		["", "At full it VENTS by itself: %d damage in a %d radius and %d health back. Kiting is the losing line; the ship heals you for standing in it." % [int(close.vent_damage), int(close.vent_radius), int(close.vent_heal)]],
		["WHAT YOU LOSE BY", ""],
		["", "The Boiler, not you. It sits at the stern and boarders walk to it. You have %d health and it has %d; dying costs you the run, but so does letting three lanes through while you are alive and well." % [int(SkyGearPlayer.MAX_HP), 500]],
		["THE DECK FIGHTS", ""],
		["", "Three lanes, each with a cannon and crew. They hold, they do not kill — treat them as time, not as damage. Kegs and lanterns explode when hit and count as yours."],
		["YOUR HAND", ""],
		["", "Four slots. Every weapon is a SHAPE crossed with an ELEMENT, so a Cone of Frost and a Cone of Ember are the same swing and different fights. Cards upgrade a slot, an element, you, the ship or the deck — the band across the top of a card says which."],
		["EVERY FOURTH WAVE", ""],
		["", "Waves 4, 8 and 12 are named events, announced before they start. They change what the wave asks of you, and two of the three pay you for engaging."],
	]

	## Sized to the copy. The width is fixed, so the interior width is known
	## before the plate exists — 860 less a 54px rail each side — and the height
	## follows from how many lines that width produces. A plate with a third of
	## itself empty reads as a screen that failed to load something.
	const PAGE_W := 860.0
	var text_w: float = PAGE_W - 2.0 * (rail(Rect2(0, 0, PAGE_W, 600.0)) + RAIL_BREATH)
	var wanted := 0.0
	for row in lines:
		if str(row[0]) != "":
			wanted += 30.0
		else:
			wanted += _wrapped_lines(str(row[1]), text_w, 16) * 21.0 + 8.0
	var page_h: float = minf(size.y - 112.0, wanted + 108.0 + 52.0 + 74.0)
	## Slightly above centre. Dead centre puts a page of text lower than the eye
	## expects to find it.
	var page := Rect2(size.x * 0.5 - PAGE_W * 0.5,
		maxf(56.0, (size.y - page_h) * 0.42), PAGE_W, page_h)
	_sheet(page)
	_banner(size.x * 0.5, page.position.y - 10.0, 460.0)
	_center_text("HOW TO PLAY", page.position.y + 48.0, 36, BRASS_LIT)
	var room := interior(page)
	var top: float = room.position.y + 74.0
	var space: float = room.end.y - top - 52.0   ## less the BACK button

	## MEASURE, then draw. At 720p the page is 570 tall and this copy wants more,
	## so the last section used to be written across the bottom rail — which is
	## precisely the bug `tools/text_audit.gd` exists to catch, and it caught this
	## one. The text yields rather than the page overflowing.
	var pt := 16
	var line_h := 21.0
	while pt > 11:
		var total := 0.0
		for row in lines:
			if str(row[0]) != "":
				total += 30.0
				continue
			total += _wrapped_lines(str(row[1]), room.size.x, pt) * line_h + 8.0
		if total <= space:
			break
		pt -= 1
		line_h = float(pt) + 5.0

	var y: float = top
	for row in lines:
		var heading := str(row[0])
		var body := str(row[1])
		if heading != "":
			y += 10.0
			_label(heading, Vector2(room.position.x, y), room.size.x,
				HORIZONTAL_ALIGNMENT_LEFT, maxi(11, pt - 3), Color("#37f0c8"))
			y += 20.0
			continue
		var wrapped: int = _wrapped_lines(body, room.size.x, pt)
		_says(body, Vector2(room.position.x, y), room.size.x,
			HORIZONTAL_ALIGNMENT_LEFT, pt, 5, Color("#e6ddd0"))
		y += wrapped * line_h + 8.0

	ui.begin("how", self, font, get_local_mouse_position())
	if ui.button(Rect2(size.x * 0.5 - 110.0, room.end.y - 40.0, 220.0, 38.0),
			"BACK", {"primary": true, "hint": "Esc"}):
		game.how_open = false


## How many lines this string takes at this width. Same wrap the renderer does,
## because a page that guesses its own height overlaps itself.
func _wrapped_lines(text: String, width: float, pt: int) -> int:
	var count := 1
	var run := ""
	for word in text.split(" "):
		var trial: String = word if run == "" else run + " " + word
		if font.get_string_size(trial, HORIZONTAL_ALIGNMENT_LEFT, -1, pt).x > width \
				and run != "":
			run = word
			count += 1
		else:
			run = trial
	return count


func _draw_settings() -> void:
	_in_frame = false
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.015, 0.028, 0.90))
	var rows := 8
	var tall: float = 118.0 + rows * 40.0 + 58.0
	var top: float = maxf(60.0, (size.y - tall) * 0.5)
	var sheet := Rect2(size.x * 0.5 - 330.0, top, 660.0, tall)
	_panel(sheet)
	_banner(size.x * 0.5, sheet.position.y - 10.0, 420.0)
	_center_text("SETTINGS", sheet.position.y + 48.0, 38, BRASS_LIT)

	ui.begin("settings", self, font, get_local_mouse_position())
	var w := 580.0
	var x := sheet.position.x + 40.0
	var y := sheet.position.y + 86.0
	if game.audio != null:
		for pair in [["master", "MASTER"], ["sfx", "EFFECTS"], ["music", "MUSIC"],
				["voice", "VOICE"], ["ui", "INTERFACE"]]:
			game.audio.set_volume(str(pair[0]),
				ui.slider(Rect2(x, y, w, 32.0), str(pair[1]),
					float(game.audio.volumes[str(pair[0])])))
			y += 40.0
		if ui.button(Rect2(x, y, w, 34.0),
				"UNMUTE EVERYTHING" if game.audio.muted else "MUTE EVERYTHING",
				{"hint": "M"}):
			game.audio.toggle_mute()
		y += 40.0

	var full: bool = DisplayServer.window_get_mode() in [
		DisplayServer.WINDOW_MODE_FULLSCREEN,
		DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]
	if ui.row(Rect2(x, y, w, 34.0), "FULLSCREEN", "ON" if full else "OFF",
			{"hint": "F11"}):
		game.toggle_fullscreen()
	y += 40.0
	if ui.button(Rect2(x, y, w, 34.0), "REBIND CONTROLS", {"hint": "F2"}):
		game.settings_open = false
		game.keys_open = true
	y += 46.0
	if ui.button(Rect2(x + w * 0.5 - 110.0, y, 220.0, 38.0), "BACK",
			{"primary": true, "hint": "Esc"}):
		game.settings_open = false

	## Settings are written on the way out, not on every drag of a slider — a save
	## per mouse-move frame is a hundred file writes to move the volume.
	var foot := interior(sheet)
	_label("changes are saved when you leave this screen",
		Vector2(foot.position.x, foot.end.y - 4.0), foot.size.x,
		HORIZONTAL_ALIGNMENT_CENTER, 12)


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
	_in_frame = false
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
	const RESULTS_CHROME := 360.0   ## banner, title, reason, buttons, the log note
	_sheet(Rect2(size.x * 0.5 - 400.0, 52.0, 800.0,
		minf(size.y - 104.0, tall + RESULTS_CHROME)))
	_banner(size.x * 0.5, 62.0, 520.0)
	_center_text(title, 110.0, 52, tint)
	if game.end_reason != "":
		_center_text(game.end_reason, 146.0, 18, Color("#b9afaa"))
	var lines := body
	## Against the plate's own interior. 680 inside an 800-wide sheet leaves 60 a
	## side, and the rail is 48 plus breathing room — so the longest build line
	## needed 712 and got clipped at 680.
	var page := interior(Rect2(size.x * 0.5 - 400.0, 52.0, 800.0, 400.0))
	var body_x: float = page.position.x
	var body_w: float = page.size.x
	var y := 212.0
	for i in lines.size():
		var line: String = lines[i]
		var small := line.begins_with("  ")
		## Per line, because one long build string should not shrink the whole
		## report — and a clipped build line is the one line a tester pastes.
		_say(line, Vector2(body_x, y), body_w, HORIZONTAL_ALIGNMENT_LEFT,
			_fits(line, body_w, 15 if small else 17, 11),
			Color("#b9afaa") if small else Color("#eee5d5"))
		y += 20.0 if small else 23.0
	y += 16.0

	## BUTTONS, not a line of text naming keys. This screen said "C to copy the
	## report, Enter to return to title" and that was the whole interface: the one
	## thing a player wants at the end of a run — go again — was two screens away
	## behind a key nobody reads.
	##
	## PLAY AGAIN keeps the seed. A run you just lost on the third wave is a run
	## you want to try again, not a different twelve waves, and the same seed is
	## the only version of "again" you can learn anything from.
	ui.begin("results", self, font, get_local_mouse_position())
	var bw := 226.0
	var gap := 12.0
	var bx: float = size.x * 0.5 - (bw * 2.0 + gap) * 0.5
	if ui.button(Rect2(bx, y, bw, 42.0), "PLAY AGAIN",
			{"primary": true, "hint": "Enter"}):
		game.restart_run()
	if ui.button(Rect2(bx + bw + gap, y, bw, 42.0), "NEW SEED"):
		game.new_seed_run()
	y += 50.0
	if ui.button(Rect2(bx, y, bw, 36.0), "COPY REPORT", {"hint": "C"}):
		game.copy_report()
	if ui.button(Rect2(bx + bw + gap, y, bw, 36.0), "QUIT TO TITLE", {"hint": "Esc"}):
		game.go_to_title()
	y += 46.0

	## Whether the copy landed. A button that does something invisible is a button
	## a player presses four times.
	if game.copied_at > 0.0 and game.run_time - game.copied_at < 2.0:
		_center_text("copied to the clipboard", y, 14, Color("#37f0c8"))
	var log_note := "saved to the run log" if game.run_logged 		else "COULD NOT WRITE THE RUN LOG — copy it before you leave"
	_center_text(log_note, y + 18.0, 14,
		Color("#6a6478") if game.run_logged else Color("#ff9a5a"))


func _center_text(text: String, y: float, font_size: int, color: Color) -> void:
	_say(text, Vector2(0, y), size.x, HORIZONTAL_ALIGNMENT_CENTER, font_size, color)

func _center_in_rect(text: String, rect: Rect2, font_size: int, color: Color) -> void:
	_say(text, rect.position + Vector2(0, font_size), rect.size.x,
		HORIZONTAL_ALIGNMENT_CENTER, font_size, color)

