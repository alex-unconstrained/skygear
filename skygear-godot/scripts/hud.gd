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
	## The widget layer writes through the HUD's funnel rather than calling
	## `draw_string` itself: one point-size floor, one outline, one recorder the
	## legibility audit can attach to. Before this the button labels and the key
	## hints were the only text in the game the audit could not see.
	ui.scribe = _say_in
	ui.plate = open_frame
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
	if game.workshop_open:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.025, 0.045, 0.72))
		_draw_workshop()
		return
	if game.compare_open:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.025, 0.045, 0.72))
		_draw_compare()
		return
	if game.how_open:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.025, 0.045, 0.72))
		_draw_how()
		return
	if game.settings_open:
		match game.state_name:
			"TITLE":
				draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.025, 0.045, 0.72))
			_:
				_draw_world_overlay(true)
		_draw_settings()
		if game.layout_edit:
			_draw_layout_editor()
		return
	match game.state_name:
		"TITLE":
			## INSTEAD OF the title, not over it — which is what the Workshop, the
			## how-to and the settings sheet all already do, and the controls sheet
			## was the one that did not. Its scrim is 0.92, so the title ghosted
			## through at eight percent and the audit read SKYGEAR, DIFFICULTY and
			## BEGIN RUN as printed through the rows.
			##
			## The part that is worse than the ghosting: `_draw_title` DECLARES its
			## buttons as it draws them, so BEGIN RUN was still a live target sitting
			## underneath the sheet.
			if game.keys_open:
				_draw_keys()
			else:
				_draw_title()
		"DRAFT":
			_draw_world_overlay(true)
			_draw_game_hud()
			_draw_draft()
		"PAUSE":
			_draw_world_overlay(true)
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
	## The last clause is the class's, not a constant. "Space dash" is a lie for
	## the man with no dash, and it is the one line on this screen that tells a
	## player what their hands do.
	_center_text("WASD move · mouse aim · LMB/RMB/Q/E skills · %s"
		% ("Space bleeds a jet · F, V" if not (game.class_data().get("jet", {}) as Dictionary).is_empty()
			else "Space dash"),
		330.0, 18, Color("#b9afaa"))
	## ONE CURSOR DOWN THE PAGE, not six offsets from a shared anchor.
	##
	## Every row here was placed at `ty` plus or minus a magic number, and adding
	## the Heat picker put DIFFICULTY on top of CAPTAIN on top of THE WORKSHOP —
	## three overlapping widgets that the text audit passed, because every string
	## was inside its OWN frame. A cursor cannot produce that class of bug.
	ui.begin("title", self, font, get_local_mouse_position())
	var tw := 300.0
	var tx: float = size.x * 0.5 - tw * 0.5
	var wide: float = tw + 180.0
	var wx: float = size.x * 0.5 - wide * 0.5
	var y := 372.0

	## DIFFICULTY, only once there is more than one rung to choose between.
	if SkyGearWorkshop.heat_available(game.workshop) > 0:
		var rungs: Array = []
		for i in SkyGearWorkshop.heat_available(game.workshop) + 1:
			rungs.append("HEAT %d · %s" % [i, str(SkyGearWorkshop.HEAT[i].name)])
		game.heat = ui.choice(Rect2(wx, y, wide, 32.0), "DIFFICULTY", rungs,
			clampi(game.heat, 0, rungs.size() - 1))
		y += 34.0
		_says(str(SkyGearWorkshop.HEAT[clampi(game.heat, 0, rungs.size() - 1)].blurb),
			Vector2(wx, y + 12.0), wide, HORIZONTAL_ALIGNMENT_CENTER, 13, 2,
			Color("#ff9a4a") if game.heat > 0 else Color("#8f8697"))
		y += 30.0

	## WHO IS ABOARD. A cycling row rather than a screen of its own: two classes,
	## one sentence of difference, and a separate screen for a binary choice is a
	## click a player pays every single run.
	var ids: Array = SkyGearData.CLASSES.keys()
	var at: int = maxi(0, ids.find(game.class_id))
	var picked: int = ui.choice(Rect2(wx, y, wide, 32.0), "WHO IS ABOARD",
		ids.map(func(k): return str(SkyGearData.CLASSES[k].name)), at)
	if picked != at:
		game.set_class(str(ids[picked]))
	y += 34.0
	_says(str(game.class_data().get("blurb", "")), Vector2(wx, y + 12.0), wide,
		HORIZONTAL_ALIGNMENT_CENTER, 13, 2, Color("#b9afaa"))
	y += 32.0
	## ...AND A WAY TO SEE WHAT THE OTHER ONE IS.
	##
	## A cycling row plus one sentence is enough to pick a class you already know
	## and useless for choosing between two you do not. Reported after a playtest:
	## "Boilerwright feels slower — and I'm not sure I understand what the class
	## actually does?" He is slower, deliberately, and nothing on this screen ever
	## said what the 55 units of speed bought.
	if ui.button(Rect2(wx, y, wide, 30.0), "COMPARE THE TWO", {"hint": "F7"}):
		game.compare_open = true
	y += 38.0

	if bool(game.workshop.unlocked):
		if ui.button(Rect2(tx, y, tw, 34.0),
				"THE WORKSHOP  ·  %d" % int(game.workshop.scrip), {"hint": "F6"}):
			game.workshop_open = true
		y += 40.0

	if ui.button(Rect2(tx, y, tw, 44.0), "BEGIN RUN",
			{"primary": true, "hint": "Enter"}):
		game.begin_run()
	y += 52.0
	if ui.button(Rect2(tx, y, tw, 38.0), "HOW TO PLAY", {"hint": "F1"}):
		game.how_open = true
	y += 44.0
	if ui.button(Rect2(tx, y, tw, 38.0), "SETTINGS", {"hint": "F5"}):
		game.settings_open = true
	y += 44.0
	if ui.button(Rect2(tx, y, tw, 38.0), "CONTROLS", {"hint": "F2"}):
		game.keys_open = true
	y += 44.0
	if ui.button(Rect2(tx, y, tw, 38.0), "QUIT", {"hint": "Alt+F4"}):
		game.quit_game()
	y += 56.0

	## What the machine remembers. A title screen with a best-wave on it is the
	## cheapest possible reason to press Enter again.
	var history: Dictionary = SkyGearRunLog.summary()
	if int(history.runs) > 0:
		var line := "%d runs · best wave %d" % [int(history.runs), int(history.best_wave)]
		if int(history.wins) > 0:
			line += " · %d held" % int(history.wins)
			if str(history.best_time) != "":
				line += " (best %s)" % str(history.best_time)
		_center_text(line, y, 17, Color("#b0813f"))
		y += 30.0
	_center_text("Milestone 1 · v11 combat vertical slice", y + 16.0, 15,
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
## the browser version", and again after the containment audit went green: "text
## on skills and cards and HUD elements is hard to read". The first fix was an
## ink shadow under `_label` and `_value`, which covered the two functions that
## remembered to call it and one side of each stroke.
##
## The decision now lives in `scripts/ink.gd` and every glyph in the game passes
## through it — including the widget layer's, which used to draw its own. Point
## size floor, outline width, outline colour, contrast floor: one file, and
## `tools/text_audit.gd` reads the same file to decide what fails.


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

## --- and how big it was, and what was behind it ------------------------------
##
## Containment is not legibility. Every string in this game already sits inside
## its frame — the audit proves it at four resolutions — and the report was still
## "text on skills and cards and HUD elements is hard to read". Fitting a label
## into a box by shrinking it to 7pt is a containment PASS and a legibility
## failure, and `_fits` does exactly that, silently.
##
## So the same funnel records the other two numbers: the point size the glyph was
## actually drawn at after every clamp and shrink, and the tint, so the audit can
## sample the rendered frame under the box and work out the contrast against the
## pixels that are really there rather than against the panel colour somebody
## assumed. `hide_text` renders the frame with every glyph suppressed and nothing
## else changed, which is how you get the background under a word without the
## word in the way.
var ink = null                       ## Array when the legibility pass is attached
var hide_text := false               ## draw the frame, but not a single glyph


func _note(text: String, box: Rect2, pt: int, tint: Color) -> void:
	if ink == null or text.strip_edges() == "":
		return
	## The halo goes in the record rather than being assumed by the reader. The
	## contrast that matters for an outlined glyph is against the halo, not
	## against the plate two pixels further out, and a reader that assumed every
	## string was outlined would report the day somebody turns one off as clean.
	ink.append({"text": text, "box": box, "pt": pt, "tint": tint,
		"outline": SkyGearInk.OUTLINE, "halo": SkyGearInk.INK})

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


## A DARK FIELD STAMPED INTO A PLATE, and the frame for whatever is written on
## it. Two problems, one object.
##
## The legibility one: the audit measured the weapon name in a skill slot at
## 1.19 against the housing it is painted on — orange-on-brass, which is not a
## contrast, it is a camouflage. An outline rescues the letterform and leaves the
## word sitting in the middle of rivets and scratches that the eye keeps reading
## as strokes.
##
## The containment one: a 128-wide slot with a 46px brass surround leaves 71px
## for a weapon name, and "Ember Cleave" at a size you can read is 80. The old
## answer was `_fits`, which shrank it to 10pt and then 7pt and called that a
## pass. The right answer is that the name does not get smaller — it gets a
## nameplate, and the nameplate is what it is measured against, because the
## nameplate is genuinely the frame it is inside of.
##
## Which is also what the housing art is for. The browser build stamps every slot
## label into a recessed strip and this is that strip.
func _stamp(area: Rect2, strength: float = 0.62) -> Rect2:
	SkyGearInk.recess(self, area, strength)
	_frame = area
	_in_frame = true
	return area


func _say(text: String, at: Vector2, width: float, align: int, pt: int,
		tint: Color) -> void:
	## THE FLOOR IS APPLIED AT THE FUNNEL, not at the forty call sites that pick a
	## size. A call site asking for 10 is corrected rather than obeyed, `_fits`
	## cannot shrink past it, and the audit is then measuring the size that was
	## really drawn rather than the size somebody intended.
	var size_pt: int = maxi(pt, SkyGearInk.MIN_PT)
	if not hide_text:
		SkyGearInk.write(self, font, at, text, align, width, size_pt, tint)
	if (audit == null and ink == null) or text.strip_edges() == "":
		return
	var measured: float = font.get_string_size(text, align, -1, size_pt).x
	## The box the string will actually occupy, given its alignment. A
	## right-aligned string at x with width w ends at x + w and starts wherever
	## it is long enough to start, which is not the same rectangle at all.
	var box := SkyGearInk.box(font, text, at, width, align, size_pt)
	_note(text, box, size_pt, tint)
	if audit == null:
		return
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


## Text that belongs to no plate: the letter on a status chip, a boarder's
## nameplate, a number leaving a body, a wave banner across the middle of the
## deck. Measured for size and contrast like everything else — those are the
## strings drawn over a LIT WOODEN FLOOR, which is the worst background in the
## game — but there is no frame for them to be inside of, and checking them
## against whichever plate happened to be open last reported the chips under the
## captain's health bar as escaping her panel.
func _say_free(text: String, at: Vector2, width: float, align: int, pt: int,
		tint: Color) -> void:
	var was := _in_frame
	_in_frame = false
	_say(text, at, width, align, pt, tint)
	_in_frame = was


## The plate that is open at this instant, for the widget layer to stamp onto
## every rectangle it declares. Asked rather than pushed: a screen opens and
## closes several plates while it draws.
func open_frame() -> Dictionary:
	return {"rect": _frame, "open": _in_frame}


## A WIDGET'S LABEL BELONGS TO THE WIDGET.
##
## Not to the plate: a button positions its own text and a centred label in a
## 300-wide button is inside that button wherever the button is. What must be
## inside the plate is the BUTTON, and the audit checks that separately against
## the rectangles `SkyGearUI.declared()` hands it.
##
## The first version of this routed widget text through `_say_free`, which
## exempts a string from the frame check entirely. That silenced the detector at
## exactly the moment it started working: the audit reported sixteen screens
## clean while four pause buttons were hanging off the left edge of their sheet
## and the build column's cooldowns were printing on the brass. A detector turned
## off to make a screen pass is worse than no detector, and this project has
## shipped one of those before.
func _say_in(owner: Rect2, text: String, at: Vector2, width: float, align: int,
		pt: int, tint: Color) -> void:
	var was_frame := _frame
	var was_in := _in_frame
	_frame = owner
	_in_frame = true
	_say(text, at, width, align, pt, tint)
	_frame = was_frame
	_in_frame = was_in


## Wrapped text. Audited the same way — this is where the card bodies go, and a
## card body is the thing that was reported.
func _says(text: String, at: Vector2, width: float, align: int, requested: int,
		lines: int, tint: Color) -> void:
	var pt: int = maxi(requested, SkyGearInk.MIN_PT)
	if not hide_text:
		SkyGearInk.write_lines(self, font, at, text, align, width, pt, lines, tint)
	if (audit == null and ink == null) or text.strip_edges() == "":
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
	var span := at.x
	if align == HORIZONTAL_ALIGNMENT_CENTER:
		span = at.x + (width - widest) * 0.5
	elif align == HORIZONTAL_ALIGNMENT_RIGHT:
		span = at.x + width - widest
	_note(text, Rect2(span, at.y - pt, widest, float(pt) * 1.3 * float(count)),
		pt, tint)
	if audit == null:
		return

	if count > lines:
		audit.append({"kind": "OVERFLOW", "text": text,
			"box": Rect2(at, Vector2(width, float(pt) * 1.3 * count)),
			"measured": float(count), "given": float(lines),
			"frame": _frame if _in_frame else Rect2()})
		return
	if not _in_frame:
		return
	var box := Rect2(span, at.y - pt, widest, float(pt) * 1.3 * count)
	if box.position.x < _frame.position.x - 0.5 or box.end.x > _frame.end.x + 0.5 			or box.position.y < _frame.position.y - 4.0 or box.end.y > _frame.end.y + 4.0:
		audit.append({"kind": "OUTSIDE", "text": text, "box": box,
			"measured": widest, "given": width, "frame": _frame})


## The largest size at which this string fits. A slot label reading "Ember
## Cleav" is a slot label that has failed at its only job, and every one of these
## boxes is a fixed size set by the plate art — so the text yields, not the box.
##
## BUT NOT PAST THE FLOOR. This is the function that produced the reported bug:
## it will happily hand back 7pt, the call sites passed floors of 7, 8, 9 and 11,
## and "draft a weapon" in an empty skill slot was being drawn at seven points on
## painted brass. Containment is not the only thing that can fail. The floor is
## `SkyGearInk.MIN_PT` and a caller cannot argue it down — a caller who wants
## smaller text wants a shorter string or a wider box.
func _fits(text: String, width: float, pt: int, floor_pt: int = SkyGearInk.MIN_PT) -> int:
	var size_pt: int = maxi(pt, SkyGearInk.MIN_PT)
	var stop: int = maxi(floor_pt, SkyGearInk.MIN_PT)
	while size_pt > stop and font.get_string_size(text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, size_pt).x > width:
		size_pt -= 1
	return size_pt


## A caption, and a number. The two were the whole readability layer once: each
## drew a one-pixel offset shadow under itself and then the glyph. On a flat
## panel that works. On the painted brass housings it is worth nothing — the
## shadow covers the lower right of each stem and leaves the other three sides of
## every stroke on lit metal — and the audit measured the slot names at 1.2:1
## with the shadow doing precisely as much for them as without it. The separation
## now happens once, in `SkyGearInk.write`, for every string in the game rather
## than for the two that remembered to ask. These stay because they are the
## caption/value VOCABULARY: same size, same tint, everywhere.
func _label(text: String, at: Vector2, width: float, align: int, pt: int = 12,
		tint: Color = Color("#cfc4b4")) -> void:
	_say(text, at, width, align, pt, tint)


func _value(text: String, at: Vector2, width: float, align: int, pt: int = 15,
		tint: Color = Color("#fff6e4")) -> void:
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
		## Whose health this is. It said CAPTAIN for both, which is wrong the
		## moment there are two of them — and the short name rather than the full
		## one, because the bar is 212 wide and "THE BOILERWRIGHT" is not.
		str(game.class_data().get("name", "CAPTAIN")).replace("THE ", ""),
		"%d / %d" % [player.hp, player.max_hp])
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
	var dial_at := l.item("captain", "dial", panel)
	_dial(dial_at, pressure_ratio)
	## OVERPRESSURE, AS A RING ROUND THE DIAL.
	##
	## The Boilerwright's bank is a flat damage multiplier the whole time it is
	## above zero and it has never appeared anywhere on screen — which is most of
	## what "I'm not sure I understand what the class actually does" is about. A
	## multiplier the player cannot see is not a mechanic, it is a comment.
	##
	## The same shape as the auto-attack ring round her portrait, deliberately: one
	## vocabulary for "this is live right now and it is doing something for you".
	## And it goes OUT, visibly, which is the half that teaches — the moment the
	## bank empties the ring drops and a red one flares in its place for as long as
	## `overpressure_lost` runs.
	var boost: float = float(game.class_data().get("overpressure", 0.0))
	if boost > 0.0:
		var ring: float = dial_at.size.x * 0.5 + 4.0
		if game.overpressure_multiplier() > 1.0:
			draw_arc(dial_at.get_center(), ring, 0.0, TAU, 40, Color("#ff9a4a"), 2.6)
		elif game.overpressure_lost > 0.0:
			draw_arc(dial_at.get_center(), ring, 0.0, TAU, 40,
				Color(1.0, 0.30, 0.22, clampf(game.overpressure_lost / 1.6, 0.0, 1.0)),
				3.0)
	var vent_at := l.item("captain", "vent_icon", panel)
	var gauge_icon := _tex("res://assets/art/ui/icon_vent.png" if pressure_ratio >= 1.0
		else "res://assets/art/ui/icon_pressure.png")
	if gauge_icon != null:
		draw_texture_rect_region(gauge_icon, vent_at,
			Rect2(Vector2.ZERO, gauge_icon.get_size()),
			Color("#f2eaff") if pressure_ratio >= 1.0 else Color("#a79bb5"))
	var pressure_at := l.item("captain", "pressure_label", panel)
	## The gauge is named by the class. His does not vent, so a label that says
	## VENTING at the top is a promise the game does not keep.
	var gauge_name: String = str(game.class_data().get("gauge", "PRESSURE"))
	var venting: bool = pressure_ratio >= 1.0 			and bool(game.class_data().get("gauge_auto_vents", true))
	## THE STRIP RIGHT OF THE DIAL, measured to the plate's own interior rather
	## than to the item box. The two rows here are the only place either class's
	## gauge is explained, and they were laid out against `pressure_label`'s 96 and
	## a hard-coded 92 — which put "V BLOWDOWN" eight pixels past the brass. No
	## screen in the audit posed the Boilerwright, so nothing ever said so.
	var strip_x: float = pressure_at.position.x
	var strip_w: float = maxf(60.0, interior(panel).end.x - strip_x)
	_label("VENTING" if venting else gauge_name,
		pressure_at.position + Vector2(0, pressure_at.size.y), 60.0,
		HORIZONTAL_ALIGNMENT_LEFT, 12,
		Color("#f2eaff") if pressure_ratio >= 1.0 else Color("#b4a8c4"))
	## WHAT THE GAUGE IS BUYING, next to the gauge, in the units it is bought in.
	## "HEAD 41" says how full a bar is; "x1.45 DAMAGE" says why anyone should
	## care, and x1.00 in red says what was just lost.
	if boost > 0.0:
		var mult: float = game.overpressure_multiplier()
		var lit: Color = Color("#ff9a4a")
		if mult <= 1.0:
			lit = Color("#ff4d37") if game.overpressure_lost > 0.0 else Color("#8f8697")
		_label("x%.2f DAMAGE" % mult,
			pressure_at.position + Vector2(0, pressure_at.size.y), strip_w,
			HORIZONTAL_ALIGNMENT_RIGHT, 12, lit)
	## THE DASH ROW IS THE CLASS ROW. She has two recharging dashes and he has
	## none, so for him that strip is dead space — and it is exactly where his
	## three bindings want to be. One row, two meanings, no new layout.
	##
	## All three, including the one on the dash key: he has no dash, so Space is a
	## Bleed Jet that costs 12 Head, and a move living on a key labelled DASH for a
	## class with no dash is a move nobody finds. Tinted by whether the bank can
	## currently pay for it, which turns the row into the answer to "what can I do
	## right now" rather than a list of letters.
	var dash_at := l.item("captain", "dash_label", panel)
	if player.max_dash_charges <= 0:
		var jet_cost: float = float((game.class_data().get("jet", {}) as Dictionary)
			.get("cost", 0.0))
		var row := Vector2(dash_at.position.x, dash_at.position.y + dash_at.size.y)
		var keys := [
			{"text": "F MAIN", "lit": Color("#9be8d2"),
				"ready": game.tap_cooldown <= 0.0
					and game.pressure >= float(SkyGearData.TAP.cost)},
			{"text": "V BLOW", "lit": Color("#ffb347"),
				"ready": game.pressure >= float(SkyGearData.BLOWDOWN.min_head)},
			## Steam's own hue lifted, because #c9b6e8 unlit and #5f5863 dimmed are
			## two greys at this size and the row's whole job is which of the three
			## you can currently afford.
			{"text": "SPC JET", "lit": Color("#ddcdff"),
				"ready": jet_cost > 0.0 and game.pressure >= jet_cost},
		]
		var cell: float = strip_w / float(keys.size())
		for i in keys.size():
			_label(str(keys[i].text), row + Vector2(float(i) * cell, 0.0), cell - 4.0,
				HORIZONTAL_ALIGNMENT_LEFT, 12,
				keys[i].lit if bool(keys[i].ready) else Color("#5f5863"))
	else:
		_dash_pips(dash_at, panel, player, l)
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
		## STARBOARD is 71 wide at the smallest size the game is allowed to draw,
		## and this box was 70. It used to fit because `_fits` was permitted to
		## take the lane names down to 8pt on a lit brass rail.
		var name_w: float = minf(80.0, row.size.x * 0.38)
		_label(names[lane], row.position + Vector2(0, row.size.y - 3.0), name_w,
			HORIZONTAL_ALIGNMENT_LEFT, _fits(names[lane], name_w, 12))
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
		## WATCH BILL turns "how many are here" into "how many are coming", which
		## is the difference between reacting to a lane and choosing one.
		var readout := str(count)
		if game.talent("show_queue") > 0.0:
			readout = "%d+%d" % [count, game.queued_in_lane(lane)]
		_value(readout, row.position + Vector2(row.size.x - 20.0, row.size.y - 3.0),
			20.0 + (18.0 if game.talent("show_queue") > 0.0 else 0.0),
			HORIZONTAL_ALIGNMENT_RIGHT, _fits(readout, 38.0, 12, 9))

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
		## THE NAMEPLATE. Every slot gets one whether it is armed or not, because a
		## row of four slots where only the filled ones have a strip reads as a
		## row of four different objects. Spans the plate rather than its interior:
		## the strip IS the frame for the name, and 71px of interior cannot hold
		## "Ember Cleave" at a size anyone can read.
		var tag := Rect2(rect.position.x + 5.0, name_at.position.y - 3.0,
			rect.size.x - 10.0, name_at.size.y + 4.0)
		if i >= game.skills.size():
			_stamp(tag)
			## "EMPTY", not "LOCKED". Nothing gates these by wave — a slot fills
			## when you draft a weapon into it — and calling it locked tells a
			## player to wait for something that is never going to arrive.
			_label("EMPTY", Vector2(tag.position.x, name_at.position.y + name_at.size.y - 3.0),
				tag.size.x, HORIZONTAL_ALIGNMENT_CENTER, 13, Color("#8b8296"))
			## And the instruction across the empty well, on a strip of its own.
			## It was 7pt grey on brass — the single least legible string the pass
			## found, and it is the one string in the HUD whose entire job is to be
			## read by somebody who does not yet know what the slot is for.
			var well := _stamp(Rect2(rect.position.x + 5.0,
				icon_at.get_center().y - 9.0, rect.size.x - 10.0, 17.0), 0.5)
			_label("draft a weapon", Vector2(well.position.x, well.end.y - 4.0),
				well.size.x, HORIZONTAL_ALIGNMENT_CENTER,
				_fits("draft a weapon", well.size.x, 12), Color("#9a92a6"))
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
		_stamp(tag)
		_label(slot_name, Vector2(tag.position.x, name_at.position.y + name_at.size.y - 3.0),
			tag.size.x, HORIZONTAL_ALIGNMENT_CENTER,
			_fits(slot_name, tag.size.x, 13),
			element if ready else Color("#8b8296"))


## The dash charges. Extracted when the Boilerwright arrived: he has none, and
## that strip of plate becomes his two bindings instead — one row, two meanings,
## no new layout. Inlining the branch would have meant an early `return` in the
## middle of `_draw_game_hud`, which silently drops the objective and the lanes.
func _dash_pips(dash_at: Rect2, panel: Rect2, player: SkyGearPlayer,
		l: SkyGearHudLayout) -> void:
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
## And the deck cannons. Wider than a SCRAPPER's and narrower than the boss's,
## because a gun is a piece of the ship rather than a body: it should read as the
## most important thing in its lane without competing with the Colossus.
const TURRET_BAR_W := 82.0

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
		_say_free(str(look.mark), Vector2(box.position.x, box.end.y - 3.0),
			CHIP_W, HORIZONTAL_ALIGNMENT_CENTER, 11, look.tint.lightened(0.4))
		## Stacks, where a status has them — three burns is not one burn.
		if int(chip.get("stacks", 0)) > 1:
			_say_free(str(int(chip.stacks)), Vector2(box.end.x - 7.0, box.position.y + 6.0),
				10, HORIZONTAL_ALIGNMENT_LEFT, 9, Color("#fff6e4"))
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


## `under_menu` is true wherever this is the BACKDROP to a sheet rather than the
## live game. The world still draws — a frozen deck behind the pause menu is the
## right picture — but the two things made of TEXT stop, because a floating
## damage number and a wave banner laid across a menu are just two pieces of
## writing on the same pixels. The audit found the wave banner printed through
## the draft, the pause sheet and the settings sheet.
func _draw_world_overlay(under_menu: bool = false) -> void:
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
		## TALLY. Numbers on the bar, for a player who has bought the right to
		## stop estimating. Deliberately small and dim: this is a talent for
		## someone who wants it, not a change to how the game reads by default.
		if game.talent("show_numbers") > 0.0 and enemy.hp < enemy.max_hp:
			_label("%d" % roundi(enemy.hp), at + Vector2(wide * 0.5 + 4.0, 6.0),
				48.0, HORIZONTAL_ALIGNMENT_LEFT, 10, Color("#cfc4b4"))
		if elite:
			# the plate is as wide as the NAME, not as wide as the health bar
			_say_free(str(ENEMY_NAMES.get(enemy.kind, enemy.kind)),
				at - Vector2(80.0, 8.0), 160, HORIZONTAL_ALIGNMENT_CENTER, 11,
				Color("#e8c376"))
		_status_row(enemy, at + Vector2(0.0, ENEMY_BAR_H + 11.0), wide)

	## THE DECK CANNONS. Reported as "cannons should fire visible projectiles, and
	## have clear health bars".
	##
	## They already HAD a health readout — the lane panel in the bottom right
	## draws a teal track per lane — and the corner is the wrong place for it,
	## which is what the report is really about. A gauge over there tells you that
	## a cannon is dying; it does not tell you WHICH of the three guns in front of
	## you it is, and that answer has to arrive in the same glance as the boarders
	## breaking it. So the same number is now also over the gun, in exactly the
	## language a boarder's health is in: `_health_bar`, the same bed, the same
	## height, the same segment ticks, unprojected from the world so it sits over
	## the object and stays legible when the wheel pulls the camera back.
	##
	## Hidden at full health and shown while hurt or down, which is the boarders'
	## rule too. Three permanent bars over three permanent objects is furniture the
	## eye learns to skip; a bar that appears only when something is wrong is a bar
	## that means something when it appears.
	for turret in game.turrets:
		var down: bool = bool(turret.dead)
		var life: float = clampf(float(turret.hp) / maxf(1.0, float(turret.max_hp)),
			0.0, 1.0)
		if not down and life >= 0.999:
			continue
		## 160 ground units: the gun stands 130 and its barrel is the highest part
		## of it, so a bar at the model's own height would be drawn through the
		## muzzle rather than over it.
		var gun := _to_screen(Vector2(turret.position), 160.0)
		if not gun.ok or not frame.has_point(gun.at):
			continue
		var mid := Vector2(gun.at.x, maxf(gun.at.y, 20.0))
		var bar := Rect2(mid - Vector2(TURRET_BAR_W * 0.5, 0.0),
			Vector2(TURRET_BAR_W, ENEMY_BAR_H))
		if not down:
			## The Boiler's own thresholds, because both are things of yours that
			## the boarders are trying to break and a player should not have to
			## learn two colour scales.
			_health_bar(bar, life,
				Color("#37f0c8") if life > 0.34 else Color("#ffb347"))
			continue
		## A dead gun gets an EMPTY BED rather than no bar at all. "There is a bar
		## here and it is empty" is a different statement from "there is nothing
		## here", and the difference is whether the player ever learns the thing
		## can come back.
		_health_bar(bar, 0.0, Color("#ff4d37"))
		## And it fills the other way while you are repairing it, so the progress
		## is on the object being worked on rather than only under the prompt.
		## `is_same`, not `==`: Dictionary equality compares CONTENTS in Godot 4,
		## and three cannons at full health are three equal dictionaries.
		var job: Dictionary = game.deckwork
		if not job.is_empty() and is_same(job.get("target"), turret) 				and game.deckwork_progress > 0.0:
			draw_rect(Rect2(bar.position, Vector2(
				bar.size.x * clampf(game.deckwork_progress, 0.0, 1.0), bar.size.y)),
				Color("#ffb347"))
		_say_free("DOWN", mid - Vector2(50.0, 8.0), 100,
			HORIZONTAL_ALIGNMENT_CENTER, 11, Color("#ff8b6a"))

	## AND THE PROMPT, once you are close enough to do something about it.
	##
	## The system has worked since the day it landed and no player has ever run
	## it, because nothing on screen said it existed. A verb with no prompt is a
	## verb nobody performs — the hint from the coach says the ability EXISTS,
	## and this says you are standing where it works.
	##
	## Drawn over the gun rather than at the player: the thing being worked on is
	## the thing the eye is already on, and a prompt pinned to the captain would
	## drift away from the cannon the moment she moved off it.
	## NOT UNDER A MENU. The health bars above can stay — they are scenery, and a
	## frozen deck behind the pause sheet should still look like the deck. This
	## cannot: it names a key, and in the draft that key is REROLL. A prompt
	## reading "HOLD R - REPAIR THE CANNON" over a screen where R throws your
	## hand away is worse than no prompt at all.
	var work: Dictionary = game.deckwork if not under_menu else {}
	if not work.is_empty():
		var spec: Dictionary = work.spec
		var goal: Dictionary = work.target
		var pin := _to_screen(Vector2(goal.position), 150.0)
		if pin.ok:
			var stopped: bool = bool(work.get("contested", false))
			## Says WHY when it refuses. A prompt that simply vanishes while
			## boarders stand on the gun teaches the player that the repair is
			## unreliable rather than that it is contested.
			var line: String = ("— " + str(spec.blocked).to_upper() + " —") if stopped 				else "HOLD %s · %s" % [SkyGearKeybinds.label(str(spec.get(
					"action", "deckwork"))), str(spec.verb)]
			var tint: Color = Color("#ff8b6a") if stopped else Color("#ffdca8")
			var plate := Rect2(pin.at.x - 128.0, pin.at.y - 34.0, 256.0, 22.0)
			_stamp(plate, 0.62)
			_say_free(line, Vector2(plate.position.x, plate.position.y + 15.0),
				plate.size.x, HORIZONTAL_ALIGNMENT_CENTER, 13, tint)
			## The ring under the words, so the commitment reads as a commitment.
			if not stopped and game.deckwork_progress > 0.0:
				var run := Rect2(plate.position.x + 28.0, plate.end.y + 2.0,
					plate.size.x - 56.0, 3.0)
				draw_rect(run, Color(0.05, 0.04, 0.07, 0.7))
				draw_rect(Rect2(run.position, Vector2(run.size.x * clampf(
					game.deckwork_progress, 0.0, 1.0), run.size.y)),
					Color("#ffb347"))

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
			_say_free("%s LANE BREAKING" % LANE_NAMES[lane],
				Vector2(x - 130.0, size.y * 0.22 + lane * 24.0), 260,
				HORIZONTAL_ALIGNMENT_CENTER, 18, Color("#ff4d37"))

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
	if under_menu:
		return
	for f in game.floaters:
		var t: float = float(f.time) / maxf(0.001, float(f.life))
		var spot := _to_screen(Vector2(f.position), 90.0)
		if not spot.ok:
			continue
		var colour: Color = f.color
		colour.a = clampf(1.0 - t * t, 0.0, 1.0)
		var pt: int = 22 if bool(f.big) else 16
		## SIZED TO THE STRING, not to a constant 80. Every floater was a number
		## until the Boilerwright's Overpressure started announcing itself in words,
		## and "OVERPRESSURE LOST" at 22pt is 164 wide in an 80-wide box — clipped
		## in the middle of the frame, which the audit reported the moment there was
		## a screen posing him. Centred on the body either way.
		var wide: float = maxf(80.0,
			font.get_string_size(str(f.text), HORIZONTAL_ALIGNMENT_CENTER, -1,
				maxi(pt, SkyGearInk.MIN_PT)).x + 6.0)
		_say_free(str(f.text), spot.at + Vector2(-wide * 0.5, 0.0), wide,
			HORIZONTAL_ALIGNMENT_CENTER, pt, colour)

	## Banners: wave numbers, IT TURNS, the run report having been copied.
	##
	## STACKED, because more than one is alive more often than it looks.
	## Starting a wave posts one with a two second life and clearing it posts
	## another with 1.6, so any wave finished inside two seconds of beginning
	## printed the two through each other at the same centred y — which is what
	## a screenshot of the new sky caught, unreadable, dead centre. Every check
	## passed: the collision pass compares WIDGET rectangles, and a banner is a
	## free-drawn string that was never in its input set.
	##
	## Older ones pushed DOWN, so the line that just arrived is always in the
	## place the eye already went.
	var stack := 0
	for e in game.effects:
		if str(e.kind) != "banner":
			continue
		var bt: float = float(e.time) / maxf(0.001, float(e.life))
		var fade: float = clampf(minf(bt * 6.0, (1.0 - bt) * 4.0), 0.0, 1.0)
		_say_free(str(e.text), Vector2(0.0, size.y * 0.26 + stack * 48.0), size.x,
			HORIZONTAL_ALIGNMENT_CENTER, 42, Color(0.91, 0.77, 0.46, fade))
		stack += 1


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
## 330 left 222 inside the rail. A preview row has to hold four things at the
## smallest size the game is allowed to draw: "dash cooldown bonus" is 127 and
## "30.00x" is 38, twice, with an arrow between them. That is 217 of content
## against 222 of card, and it only ever fitted because `_fits` was allowed down
## to 8pt. 368 leaves 244 after PLATE_BREATH, and three of them plus the gaps is
## 1156 — inside the 1280 floor the audit checks.
const CARD_W := 368.0
const CARD_GAP := 26.0
const CARD_TOP := 190.0
## 372 once, and taller now to pay for two things the face did not have room
## for: the tag row that says the element, the rarity and the role, and
## CARD_FOOT below.
const CARD_H := 404.0

## AND THE PAINTED CARD IS NOT THE SHAPE `interior()` THINKS IT IS.
##
## `interior()` asks the nine-slice how thick the rail is and gets 54. The
## painted plate has an inner bevel BELOW the slice margin, so the real dark
## field starts a few pixels further in on every side — and further still at the
## bottom, where the middle row of the slice stretches 160 source rows to 276
## destination rows on a card this tall and drags the bevel with it.
##
## Nothing in the containment audit could see this: it trusts `interior()`, and
## `interior()` is what is optimistic. The contrast pass found it — "AFFECTS THE
## CAPTAIN" measured 1.26 against `a0814c`, which is brass, on a row the layout
## believed was well inside the dark — and a player found the rest of it: the
## class band overlapping the top rail and COMMON clipped by the right one.
##
## Both numbers are measured off the rendered plate rather than off the slice
## margin, and both live here rather than at the nine call sites that lay
## something out on a card.
## The foot is a FRACTION, not a constant, because the bevel is authored in the
## plate's middle band and the slice stretches that band vertically — 160 source
## rows into 276 on a card and into 348 on the pause sheet, dragging the bevel
## further from the bottom edge the taller the plate is. Clamped at both ends so
## a HUD strip does not lose a third of itself to it.
const PLATE_BREATH := 8.0
const PLATE_FOOT := 0.035


## The writing area of a plate: the hole in the brass, honestly, as opposed to
## `interior()`, which is the hole the nine-slice believes it cut.
static func writing_area(rect: Rect2) -> Rect2:
	var face := interior(rect).grow(-PLATE_BREATH)
	face.size.y -= clampf(rect.size.y * PLATE_FOOT, 6.0, 22.0)
	return face


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
	## MANIFEST. What is coming, while you still have a choice about it.
	if game.talent("show_manifest") > 0.0:
		var coming: String = game.next_wave_manifest()
		if coming != "":
			_label(coming, Vector2(0.0, 180.0), size.x, HORIZONTAL_ALIGNMENT_CENTER,
				_fits(coming, size.x, 14, 10), Color("#8fa6c9"))
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
		## RARITY, AS METAL. Hue is spoken for by the element, so the tier of a
		## card is a heavier and brighter ring with rivets at the corners: iron,
		## brass, steel. It reads at a distance and it costs one draw call, where
		## a painted back per rarity x element x role is twenty-four textures.
		var look: Dictionary = SkyGearCards.rarity_look(card)
		if float(look.ring) > 0.0:
			## Inside the brass rather than on the card's silhouette, or the ring
			## reads as a box drawn around the card instead of as its frame.
			draw_rect(rect.grow(-11.0), look.metal, false, float(look.ring))
			for corner in [rect.position + Vector2(19, 19),
				Vector2(rect.end.x - 19, rect.position.y + 19),
				Vector2(rect.position.x + 19, rect.end.y - 19),
				rect.end - Vector2(19, 19)]:
				if int(look.rivets) > 0:
					## A stud, which needs a dark rim. A plain bright disc on brass
					## is a dot somebody stuck on rather than a rivet driven in.
					draw_circle(corner, 4.0, Color(0.05, 0.04, 0.07, 0.85))
					draw_circle(corner, 2.8, look.metal)
		## EVERYTHING below is measured from here. The card is brass around a
		## hole, the hole is what you may write in, and `card_face` is the only
		## thing that knows where the painted hole actually is.
		var face := writing_area(rect)
		
		## THE HUE IS THE ELEMENT'S. Always, in both drafts. It used to be the
		## SCOPE colour on a drafted card and the ELEMENT colour on an opening
		## weapon, so the one channel a player reads before any words meant two
		## different things depending on which draft they were looking at.
		var tint: Color = SkyGearCards.hue_of(card)
		## The class band. Reported against the browser build in exactly these
		## words: it is not visually clear whether an upgrade enhances a skill
		## you have or hands you a new one. Both were a card with a title on it.
		var band := Rect2(face.position, Vector2(face.size.x, 26))
		draw_rect(band, Color(tint.r, tint.g, tint.b, 0.16))
		draw_rect(band, tint, false, 2.0)
		_center_in_rect("%d  ·  %s" % [i + 1, str(card.get("class_label", "UPGRADE"))],
			Rect2(band.position + Vector2(0, 3), band.size), 14, tint)
		
		## THE TAG ROW: element, rarity, role, in words as well as in colour.
		## The player's test was whether all three can be told apart at a glance,
		## and a glance at hue alone fails for one man in twelve — so the swatch
		## has its element written beside it, the ring has its tier written under
		## it, and the role is a word because the role is binary.
		var tag_y: float = band.end.y + 16.0
		var swatch := Rect2(face.position.x, tag_y - 9.0, 10.0, 10.0)
		draw_rect(swatch, tint)
		draw_rect(swatch, Color(0.03, 0.02, 0.045, 0.9), false, 1.0)
		_label(SkyGearCards.element_label(card),
			Vector2(face.position.x + 16.0, tag_y), face.size.x * 0.52,
			HORIZONTAL_ALIGNMENT_LEFT, 12, tint)
		var role := SkyGearCards.role_of(card)
		if role != "":
			## A badge, not a shade. You could draft a Field and not find out it
			## has no key until the fight started.
			var badge := Rect2(face.get_center().x - 34.0, tag_y - 12.0, 68.0, 16.0)
			draw_rect(badge, Color(0.05, 0.04, 0.075, 0.7))
			draw_rect(badge, Color(tint.r, tint.g, tint.b, 0.75), false, 1.2)
			_label(role, Vector2(badge.position.x, tag_y), badge.size.x,
				HORIZONTAL_ALIGNMENT_CENTER, 12, Color("#e6ddd0"))
		_label(str(look.name), Vector2(face.position.x, tag_y), face.size.x,
			HORIZONTAL_ALIGNMENT_RIGHT, 12, look.metal)

		## The title, shrunk to fit rather than clipped. "SLOW COMBUSTION" at 22pt
		## is 216 wide against 222 of card; one longer name and it is over the
		## edge, and a title that silently loses its last word is worse than a
		## title one point smaller.
		var title := str(card.title)
		var title_pt := 22
		while title_pt > 14 and font.get_string_size(title, HORIZONTAL_ALIGNMENT_CENTER,
				-1, title_pt).x > face.size.x:
			title_pt -= 1
		_say(title, Vector2(face.position.x, band.end.y + 52.0), face.size.x,
			HORIZONTAL_ALIGNMENT_CENTER, title_pt, tint)
		_says(str(card.text), Vector2(face.position.x, band.end.y + 90.0),
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
				## 96, not 68. A weapon card has no before/after rows, so the glyph
				## is the only thing in the middle two hundred pixels of it, and at
				## 68 it read as a bullet point in an empty card. It is also the
				## fastest read on the face: the shape of the swing.
				var at := Vector2(face.get_center().x - 48.0, band.end.y + 100.0)
				draw_circle(at + Vector2(48, 48), 56.0, Color(0.04, 0.03, 0.06, 0.35))
				draw_texture_rect_region(glyph, Rect2(at, Vector2(96, 96)),
					Rect2(Vector2.ZERO, glyph.get_size()), tint)

		## BEFORE -> AFTER. The card said "hits harder" and left you to guess by
		## how much, against a current value it also did not show.
		var rows: Array = SkyGearCards.preview(game, card)
		if not rows.is_empty():
			var ry: float = band.end.y + 150.0
			var rx: float = face.position.x
			var rw: float = face.size.x
			## A rule above them, so the numbers read as a consequence of the
			## sentence rather than as more of it.
			draw_line(Vector2(rx, ry - 12.0), Vector2(rx + rw, ry - 12.0),
				Color(tint.r, tint.g, tint.b, 0.35), 1.0)
			## The label owns more of the row than it did. Half of 222 is 111 and
			## the longest label in the catalogue is 127 at the floor size; the
			## numbers on the right need far less than they were reserving.
			for r in rows.slice(0, SkyGearCards.PREVIEW_ROWS):
				var good: bool = bool(r.better)
				_label(str(r.label), Vector2(rx, ry), rw * 0.54,
					HORIZONTAL_ALIGNMENT_LEFT, _fits(str(r.label), rw * 0.54, 12))
				## Old value struck through in grey, new value lit. An arrow with
				## two live-looking numbers reads as a range, not a change.
				##
				## "30.00x" is 38 wide at the floor size and the BEFORE column was
				## 37 — a one-pixel clip that only showed up once `_fits` stopped
				## being allowed to shrink the row out of trouble.
				_say(str(r.before), Vector2(rx + rw * 0.55, ry), rw * 0.17,
					HORIZONTAL_ALIGNMENT_RIGHT, 12, Color("#6a6478"))
				_say("->", Vector2(rx + rw * 0.73, ry), 20,
					HORIZONTAL_ALIGNMENT_LEFT, 12, Color("#8f8697"))
				_say(str(r.after), Vector2(rx + rw * 0.81, ry), rw * 0.19,
					HORIZONTAL_ALIGNMENT_LEFT, 12,
					Color("#7be8a8") if good else Color("#ff9a5a"))
				ry += 17.0
			if rows.size() > SkyGearCards.PREVIEW_ROWS:
				_label("+%d more" % (rows.size() - SkyGearCards.PREVIEW_ROWS),
					Vector2(rx, ry), rw, HORIZONTAL_ALIGNMENT_LEFT, 11)

		## And which of your skills it lands on, as glyphs, with the untouched
		## ones dim. A card that touches no skill says what it does touch —
		## four dark glyphs reads as "affects nothing".
		var hit: Array = card.get("affects", [])
		var row_y: float = face.end.y - 24.0
		## A weapon card does not "affect" the skills you already hold — it takes
		## a slot. Saying so beats four grey dots, which is what it was drawing.
		if str(card.get("kind", "")) == "skill":
			var slot_note := "ARMS SLOT %d" % (int(card.get("slot", game.skills.size())) + 1)
			if game.skills.size() >= 4:
				slot_note = "REPLACES A SLOT"
			_stamp(Rect2(face.position.x, row_y, face.size.x, 20.0), 0.45)
			_say(slot_note, Vector2(face.position.x, row_y + 15.0), face.size.x,
				HORIZONTAL_ALIGNMENT_CENTER, 13, tint)
		elif game.skills.is_empty() or hit.is_empty():
			var label := "AFFECTS THE CAPTAIN"
			match str(card.get("scope", "captain")):
				"ship": label = "AFFECTS THE BOILER"
				"deck": label = "AFFECTS THE DECK"
				"meta": label = "AFFECTS FUTURE DRAFTS"
				"new": label = "ARMS AN EMPTY SLOT"
			## On a field of its own. This is the string the contrast pass caught at
			## 1.26 against brass, and moving it up is only half the answer — the
			## bottom of a card is where the painted bevel starts whatever the
			## layout believes.
			var foot := _stamp(Rect2(face.position.x, row_y, face.size.x, 20.0), 0.45)
			_center_in_rect(label, Rect2(foot.position + Vector2(0, 2), foot.size),
				13, tint)
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
		## THE DASH KEY IS NOT A DASH FOR EVERYONE. The Boilerwright has none —
		## Space is a Bleed Jet that costs 12 Head and lays scalding steam behind
		## him — and this page telling him it is a DASH is the reason the move goes
		## undiscovered. The BINDING is still `dash`, because the two classes share
		## one key and a second action would be a second thing to rebind.
		if action == "dash" and not (game.class_data().get("jet", {}) as Dictionary).is_empty():
			name = "BLEED JET"
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
		writing_area(sheet).end.y, 15,
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
	## Plus the banner's overhang. The buttons used to start 82 below the top of
	## the sheet and the banner ornament reaches 115 past it, so RESUME was drawn
	## through the bottom of the PAUSED plaque.
	var tall: float = maxf(body, 26.0 + rows * 40.0) + 154.0
	var top: float = maxf(70.0, (size.y - tall) * 0.5)
	var sheet := Rect2(size.x * 0.5 - 330.0, top, 660.0, tall)
	_panel(sheet)
	## The banner rides the panel rather than a screen constant, or it lands on
	## the first button the moment the panel moves.
	_banner(size.x * 0.5, sheet.position.y - 10.0, 420.0)
	_center_text("PAUSED", sheet.position.y + 48.0, 40, BRASS_LIT)

	ui.begin("pause", self, font, get_local_mouse_position())
	## FROM THE INTERIOR, not from the sheet.
	##
	## `interior()` carries a long note about three functions disagreeing over
	## where the brass ends, and this was the place that never got the message:
	## 26 in from a 660-wide sheet is 28 pixels inside a 54-pixel rail, so all
	## four buttons and the whole build column were laid out on the frame. Every
	## label was perfectly centred in its own button and the audit could not see
	## it, because it had no way to ask whether the BUTTON was in the right place
	## — it does now, and this was the first thing it found.
	var room := interior(sheet)
	var bw := 300.0
	var bx: float = room.position.x
	var by: float = room.position.y + 62.0
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
		## BRASS_LIT, not BRASS. The contrast pass measured these at 1.32
		## against the plate — b0813f text on a b0813f rivet, which is the
		## same number twice.
		_label("%.2fs" % float(st.cooldown), Vector2(lx, ly + 27.0), lw,
			HORIZONTAL_ALIGNMENT_RIGHT, 12, BRASS_LIT)
		ly += 40.0
	## Against the writing area rather than the interior: the interior's
	## bottom edge is on the painted bevel, and the contrast pass measured
	## this line at 1.59 against bright brass sitting exactly there.
	_label("WASD move · mouse aim · %s · F7 classes · F4 layout · F3 stats"
		% ("Space bleeds a jet" if not (game.class_data().get("jet", {}) as Dictionary).is_empty()
			else "Space dash"),
		Vector2(room.position.x, writing_area(sheet).end.y), room.size.x,
		HORIZONTAL_ALIGNMENT_CENTER, 12)


## Settings. There were none — volume was two keys nobody knew about, and every
## other option was a function key mentioned once on the title screen. Four
## channels rather than one, because the report that started this was "SFX with
## character audio weren't really easy to hear against the other sounds", and a
## single master slider cannot answer that.
## --- the two of them, side by side ------------------------------------------
##
## THE TABLE HAD NO READER. `CLASSES[*].compare` has carried eight parallel rows
## — the question, the gauge, and it, what it buys, the vent, your keys, stand,
## you lose by — since the Boilerwright landed, and nothing has ever drawn one of
## them. The picker showed a single sentence, which is enough to confirm a class
## you already know and no use at all for choosing between two you do not. That
## is failure mode one in `STATUS.md`, and this is the fifth instance.
##
## What it cost the game, in the player's own words after a playtest:
## "Boilerwright feels slower — and I'm not sure I understand what the class
## actually does?" He IS slower — 205 against 260, and that is the design — but
## nothing anywhere told him what the 55 units bought, so the class read as the
## captain with worse numbers.
##
## PARALLEL ROWS, NOT TWO PARAGRAPHS. A description of each class in turn is two
## things to hold in your head; a row is one question with two answers, and the
## answer to "what am I giving up" is then a sideways glance rather than an act
## of memory. The four numeric rows above the prose are DERIVED from `hp`,
## `speed`, `dashes` and `overpressure` — see `SkyGearData.class_stats()` — so
## the screen cannot drift away from the balance table the way a hand-written
## "100 health, 260 speed" row would, and did.
const COMPARE_MAX_W := 1220.0
const COMPARE_MIN_W := 880.0
const COMPARE_GAP := 18.0


## Which colour a class is, taken from the element its own auto-attack throws.
## Derived rather than picked, so the man who fights with steam is the pale
## violet the steam already is, everywhere else in the game.
func _class_hue(id: String) -> Color:
	var kit: Dictionary = SkyGearData.CLASSES.get(id, {})
	var element: String = str((kit.get("auto", {}) as Dictionary).get("element", ""))
	if SkyGearData.ELEMENTS.has(element):
		return SkyGearData.ELEMENTS[element].color
	return BRASS_LIT


func _draw_compare() -> void:
	_in_frame = false
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.015, 0.028, 0.93))
	var ids: Array = SkyGearData.CLASSES.keys()
	var stats: Array = SkyGearData.class_stats()
	## Row order comes from the first class's table and the second is read at the
	## same keys, so a table that has grown a row on one side only draws blank
	## rather than silently dropping it — and the harness fails on it.
	var keys: Array = (SkyGearData.CLASSES[ids[0]].compare as Dictionary).keys()

	## MEASURE THE COLUMNS BEFORE THE PAGE EXISTS. The width is fixed by the
	## window, so the interior width is knowable from a probe of the right width
	## and any plausible height — the rail is 48 flat above 246px tall, which every
	## page this builds is.
	var page_w: float = clampf(size.x - 80.0, COMPARE_MIN_W, COMPARE_MAX_W)
	var head_room: float = maxf(320.0, size.y - 72.0)
	var probe := writing_area(Rect2(0.0, 0.0, page_w, head_room))
	var room_w: float = probe.size.x
	## Both rails plus the bevel allowance at the foot, which is what the page has
	## to buy before a single row of it is drawn.
	var chrome: float = probe.position.y + (head_room - probe.end.y)
	var gutter: float = clampf(room_w * 0.14, 96.0, 160.0)
	var col_w: float = (room_w - gutter - COMPARE_GAP * 2.0) * 0.5

	## THE COPY YIELDS, THE PAGE DOES NOT OVERFLOW.
	##
	## Eight rows of two answers is a lot of text and 720p leaves 648 pixels of
	## page. The first version shrank the point size only, hit the 12pt floor with
	## a hundred pixels still to lose, and printed YOU LOSE BY straight through the
	## SAIL AS buttons — which is exactly the failure `_draw_how` grew its own
	## shrink for. So there are two levers and they are pulled in the order that
	## costs the reader least: the type comes down to the floor first, and only
	## then does the air between the rows.
	const TITLE_H := 68.0
	const HEAD_H := 36.0
	const STAT_H := 22.0
	const RULE_H := 12.0
	const FOOT_H := 52.0
	const PAD_MAX := 11.0
	const PAD_MIN := 4.0
	var prose_height := func(p: int, pad: float) -> float:
		var total := 0.0
		for key in keys:
			var lines := 1
			for id in ids:
				lines = maxi(lines, _wrapped_lines(
					str((SkyGearData.CLASSES[id].compare as Dictionary).get(key, "—")),
					col_w, p))
			total += float(lines) * (float(p) + 5.0) + pad
		return total
	var fixed: float = TITLE_H + HEAD_H + float(stats.size()) * STAT_H 		+ RULE_H * 2.0 + FOOT_H + chrome
	var pt := 15
	var pad := PAD_MAX
	while fixed + prose_height.call(pt, pad) > head_room:
		if pt > SkyGearInk.MIN_PT:
			pt -= 1
		elif pad > PAD_MIN:
			pad -= 1.0
		else:
			## Out of levers. The page is clamped to the window rather than allowed
			## to grow off the bottom of it, and `tools/text_audit.gd` reports the
			## overflow — which is the honest failure, not a silent one.
			break
	var line_h: float = float(pt) + 5.0
	var page_h: float = minf(head_room, fixed + prose_height.call(pt, pad))
	## Slightly above centre, for the same reason the how-to page is: a page of
	## text dead-centred sits lower than the eye goes looking for it.
	var page := Rect2(size.x * 0.5 - page_w * 0.5,
		maxf(48.0, (size.y - page_h) * 0.42), page_w, page_h)
	_sheet(page)
	_banner(size.x * 0.5, page.position.y - 10.0, 470.0)
	_center_text("WHO IS ABOARD", page.position.y + 48.0, 34, BRASS_LIT)
	## THE HOLE IN THE BRASS, HONESTLY. `interior()` is where the nine-slice
	## believes it cut and the painted corners curl further in than that — a SAIL
	## AS button laid out to the interior's right edge sits on the ornament at
	## 1280, where the page is nearly as wide as the window. `writing_area` is the
	## measurement that already knows this, and the two-column body is the widest
	## thing in the game to lay out against it.
	var room := writing_area(page)

	var col_x := [room.position.x + gutter + COMPARE_GAP,
		room.position.x + gutter + COMPARE_GAP * 2.0 + col_w]
	var y: float = room.position.y + TITLE_H
	var foot_y: float = room.end.y - 38.0

	## THE COLUMN YOU ARE CURRENTLY SAILING AS, lit down its whole length. Which
	## one is selected is the single most important thing on a picker and a tick
	## beside a name is easy to miss at a glance.
	for c in ids.size():
		var hue: Color = _class_hue(str(ids[c]))
		var chosen: bool = str(ids[c]) == str(game.class_id)
		var strip := Rect2(col_x[c] - 8.0, y - 24.0, col_w + 16.0,
			foot_y - y - 8.0)
		draw_rect(strip, Color(hue.r, hue.g, hue.b, 0.07 if chosen else 0.025))
		draw_rect(strip, Color(hue.r, hue.g, hue.b, 0.55 if chosen else 0.16),
			false, 2.0 if chosen else 1.0)

	## The heading row: who they are, and which one is aboard right now.
	_label("", Vector2(room.position.x, y), gutter, HORIZONTAL_ALIGNMENT_LEFT, 12)
	for c in ids.size():
		var id: String = str(ids[c])
		var hue: Color = _class_hue(id)
		var title: String = str(SkyGearData.CLASSES[id].name)
		_value(title, Vector2(col_x[c], y), col_w, HORIZONTAL_ALIGNMENT_CENTER,
			_fits(title, col_w, 22, 15), hue)
		if id == str(game.class_id):
			_label("ABOARD", Vector2(col_x[c], y + 17.0), col_w,
				HORIZONTAL_ALIGNMENT_CENTER, 12, Color("#37f0c8"))
	y += HEAD_H
	_compare_rule(room, y - RULE_H * 0.5)

	## THE FOUR NUMBERS, with the winner of each lit and the loser dimmed. Two
	## rows each way, which is the trade said without a sentence: he pays in speed
	## and in the dash, and he is paid in health and in damage.
	for row in stats:
		_label(str(row.name), Vector2(room.position.x, y + 12.0), gutter,
			HORIZONTAL_ALIGNMENT_LEFT, 12, Color("#8fa6c9"))
		for c in ids.size():
			var id: String = str(ids[c])
			var wins: bool = str(row.better) == id
			var text: String = str((row.values as Dictionary).get(id, "—"))
			_value(text, Vector2(col_x[c], y + 12.0), col_w,
				HORIZONTAL_ALIGNMENT_CENTER, _fits(text, col_w, 15, 12),
				BRASS_LIT if wins else Color("#8f8697"))
		y += STAT_H
	y += RULE_H
	_compare_rule(room, y - RULE_H * 0.5)

	## And the prose, one question per row.
	for key in keys:
		var tall := 1
		for id in ids:
			tall = maxi(tall, _wrapped_lines(
				str((SkyGearData.CLASSES[id].compare as Dictionary).get(key, "—")),
				col_w, pt))
		_label(str(key).to_upper(), Vector2(room.position.x, y + float(pt)),
			gutter, HORIZONTAL_ALIGNMENT_LEFT, _fits(str(key).to_upper(), gutter, 12),
			Color("#8fa6c9"))
		for c in ids.size():
			var id2: String = str(ids[c])
			_says(str((SkyGearData.CLASSES[id2].compare as Dictionary).get(key, "—")),
				Vector2(col_x[c], y + float(pt)), col_w, HORIZONTAL_ALIGNMENT_LEFT,
				pt, tall, Color("#e6ddd0"))
		y += float(tall) * line_h + pad

	## MOUSE-FIRST, and the screen is the picker rather than a page about the
	## picker: the button that ends it is the choice it was asked about. Only at
	## the title — swapping class mid-run is not a thing the simulation supports,
	## so mid-run this is a page you read and close.
	ui.begin("compare", self, font, get_local_mouse_position())
	if game.state_name == "TITLE":
		if ui.button(Rect2(room.position.x, foot_y, gutter, 34.0), "BACK",
				{"hint": "Esc"}):
			game.compare_open = false
		for c in ids.size():
			var id3: String = str(ids[c])
			var chosen3: bool = id3 == str(game.class_id)
			var label3: String = ("SAILING AS %s" if chosen3 else "SAIL AS %s") \
				% str(SkyGearData.CLASSES[id3].name)
			if ui.button(Rect2(col_x[c], foot_y, col_w, 34.0), label3,
					{"primary": chosen3}):
				game.set_class(id3)
				game.compare_open = false
	elif ui.button(Rect2(room.get_center().x - 110.0, foot_y, 220.0, 34.0), "BACK",
			{"primary": true, "hint": "Esc"}):
		game.compare_open = false


## A hairline across the table. Drawn rather than a `_says` of dashes, because a
## row of hyphens is a string the legibility pass has to have an opinion about.
func _compare_rule(room: Rect2, y: float) -> void:
	draw_line(Vector2(room.position.x, y), Vector2(room.end.x, y),
		Color(0.69, 0.51, 0.25, 0.35), 1.0)


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
	var kit: Dictionary = game.class_data()
	## THE ONE THING IS NOT THE SAME THING FOR BOTH OF THEM.
	##
	## Every sentence of this section is false by design for the Boilerwright —
	## his gauge does not fill from damage, does not empty when he backs off and
	## never vents itself — and the page said them at him anyway. A teaching
	## surface that teaches the wrong loop is worse than one that teaches nothing,
	## because the player acts on it and then cannot work out why it does not pay.
	##
	## Numbers from the tables, both sides, so neither half can drift.
	var one_thing: Array = []
	if game.gauge_is_banked():
		one_thing = [
			["THE ONE THING", ""],
			["", "%s does not fill from fighting. It fills only where you plant yourself: standing on the Boiler (%d a second, and the ship pays for it), at a deck vent (%d), or inside a steam main you cracked open with F (%d). It never decays and it never spends itself."
				% [str(kit.get("gauge", "HEAD")), int(kit.get("boiler_rate", 0)),
					int(kit.get("vent_rate", 0)), int(kit.get("tap_rate", 0))]],
			["", "WHILE THERE IS ANYTHING IN IT, EVERY WEAPON YOU OWN HITS %d%% HARDER. That is Overpressure and it is the whole class — the bank is not a resource you are saving for later, it is a damage bonus that is switched on right now. Every cast, every Bleed Jet, every Blowdown turns some of it off."
				% roundi(float(kit.get("overpressure", 0.0)) * 100.0)],
			["", "You have no dash. Space is a BLEED JET: %d units for %d Head, leaving scalding steam in the lane behind you — so every dodge is damage you did not do. Inside your own main you take %d%% less and cannot be knocked about."
				% [int((kit.get("jet", {}) as Dictionary).get("distance", 0)),
					int((kit.get("jet", {}) as Dictionary).get("cost", 0)),
					roundi(float(SkyGearData.TAP.anchor_resist) * 100.0)]],
		]
	else:
		one_thing = [
			["THE ONE THING", ""],
			["", "Your gauge fills from damage you land within %d units and from being crowded — and empties when you are not. It is not a reward for surviving, it is a reward for being in reach." % int(close.range)],
			["", "At full it VENTS by itself: %d damage in a %d radius and %d health back. Kiting is the losing line; the ship heals you for standing in it." % [int(close.vent_damage), int(close.vent_radius), int(close.vent_heal)]],
		]
	var lines: Array = one_thing + [
		["WHAT YOU LOSE BY", ""],
		["", "The Boiler, not you. It sits at the stern and boarders walk to it. You have %d health and it has %d; dying costs you the run, but so does letting three lanes through while you are alive and well." % [int(kit.get("hp", SkyGearPlayer.MAX_HP)), 500]],
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
	## Stops at the floor rather than at a local 11, because `_says` clamps to the
	## floor anyway — a loop that measures at 11 and a renderer that draws at 12
	## is the two-functions-one-number bug in miniature.
	while pt > SkyGearInk.MIN_PT:
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


## --- THE WORKSHOP -------------------------------------------------------------
##
## Reported: "we need to also work on making the workshop more of a visual tree —
## love the abilities and such, but the menu itself is quite dull/boring."
##
## The content is not the problem and none of it moves: the same 23 nodes at the
## same costs with the same rank counts, the same seven Articles, the same tier
## rule. What was wrong is that the dependency structure was IMPLIED — by the
## order of a list and by a grey sentence between two rows — and everything else
## on the screen was a rectangle with a name in it. Twenty-eight identical
## rectangles is a form, and a form is what it read as.
##
## So the structure is DRAWN. Four brass mains run down from four manifolds, one
## per branch; a handwheel valve sits at each tier gate and is visibly open or
## visibly shut; a spur runs off the main into every fitting and is hot if you
## own it, warm if you can buy it and cold if you cannot. The tier rule was
## always "two more in this branch" and now it is a valve you can see is closed.
##
## FIVE STATES, EACH SAID THREE WAYS, because a state said only in colour is a
## state a colour-blind player cannot read:
##
##   FULL    every rank fitted     green rim · every rivet filled
##   HELD    fitted, more to buy   brass rim, warm plate · some rivets · a cost
##   READY   affordable right now  brass rim, dark plate · no rivets · lit cost
##   DEAR    open, cannot pay      copper rim, cold spur · dimmed cost
##   LOCKED  the valve above is shut   iron rim · no cost · a shut wheel above it
##
## RANK IS RIVETS. Eleven of the twenty-three nodes have more than one rank and
## the only way to see it was to read "1/3" off the end of the name — inside the
## name's own box, competing with it for the width that made the name shrink.
##
## THE ARTICLES ARE A SIDEBAR, not a fifth column and not a row of buttons. They
## are a different object bought with a different currency and there is no
## refund, so they get a different shape: wax seals down the right-hand edge in
## the sigil violet, against the tree's rectangular brass. Moving them sideways
## also bought the vertical space the tree needed — the old two-row band of
## Articles was printing through the description strip at 1280x720, which every
## check passed because a stamped strip is not a widget and the overlap was
## forty-nine percent of a box rather than fifty.

## THE FIVE STATES, in the order they appear above.
enum Fit {LOCKED, DEAR, READY, HELD, FULL}

## The ink for each. Every one is either a bone/brass/green that clears the
## contrast floor on a dark plate, or one of `SkyGearInk.MUTED` — a fitting you
## cannot buy is SUPPOSED to recede, and the muted floor is what says how far it
## is allowed to.
const FIT_INK := [Color("#6f6878"), Color("#8f8697"), Color("#eee5d5"),
	Color("#e8c376"), Color("#7be8a8")]
## The rim, which is metal rather than text and so has no floor to clear. Copper
## for DEAR — it is a real fitting and it is not yours; cold iron-violet for
## LOCKED — there is nothing here to want yet.
const FIT_RIM := [Color("#4a4356"), Color("#8a5236"), Color("#b0813f"),
	Color("#e8c376"), Color("#5fc79a")]
const FIT_FILL := [Color(0.050, 0.045, 0.072, 0.90), Color(0.070, 0.048, 0.052, 0.88),
	Color(0.058, 0.052, 0.082, 0.90), Color(0.112, 0.084, 0.050, 0.94),
	Color(0.048, 0.098, 0.078, 0.94)]
## How hot the pipe feeding a fitting runs. The spur is the fourth channel and
## the cheapest one: a lit spur is a fitting you own, read across the whole board
## at a glance without looking at a single word.
const FIT_HEAT := [0.08, 0.30, 0.62, 1.0, 1.0]

## The Articles' violet, and the cold pipe. Named because they are each used in
## four places and a fifth shade of purple is how a palette dies.
const SIGIL_VIOLET := Color("#c9b6e8")

## THE BOARD'S FURNITURE. `SHOP_HEAD` is the only one of these that is measured
## rather than chosen: `frame_hud.png`'s banner region is 391x117, drawn 480 wide
## and therefore 143 tall, ten pixels above the plate — so anything above
## room.y + 82 is drawn on its lower brass, and the old scrip line was.
const SHOP_HEAD := 82.0
const SHOP_LEDGER := 28.0
const SHOP_LEDGER_GAP := 14.0
const SHOP_BRANCH_HEAD := 24.0
const SHOP_GATE := 18.0
## Board floor to plate floor: the description strip, the gap over it, the two
## buttons, and the painted bevel `writing_area` already knows about.
const SHOP_TAIL := 78.0
const SHOP_STEP_MAX := 42.0
const SHOP_STEP_MIN := 26.0
## The gutter the main runs down, inside each branch column, and the gap between
## two branches.
const SHOP_SPINE := 28.0
const SHOP_COL_GAP := 12.0
## One rivet every nine pixels. Three ranks is the most any node has, so the
## widest rank readout on the board is 26 pixels — against 30 for " 1/3" at the
## size the names want to be drawn at.
const SHOP_RIVET_STEP := 9.0


## A LENGTH OF BRASS PIPE. Three strokes, and the middle one is the only one
## carrying the state: the casing so it reads as a solid rather than as a
## coloured line, the metal, and the light along its upper side, because a pipe
## is a cylinder and one bright edge is the cheapest thing that says so.
func _pipe(from: Vector2, to: Vector2, bore: float, warm: float) -> void:
	var metal: Color = Color("#37303e").lerp(Color("#bb8b40"), warm)
	var shine: Color = Color("#4e4756").lerp(Color("#f8dcaa"), warm)
	draw_line(from, to, Color(0.02, 0.015, 0.03, 0.95), bore + 3.0)
	draw_line(from, to, metal, bore)
	var along := (to - from).normalized()
	var off := Vector2(-along.y, along.x) * (bore * 0.30)
	draw_line(from - off, to - off, shine, maxf(1.0, bore * 0.26))


## A FLANGE ACROSS A PIPE. Where two lengths meet, which on this board is every
## place the eye needs a full stop: under a manifold, either side of a valve.
func _collar(at: Vector2, along: Vector2, bore: float, warm: float) -> void:
	var across := Vector2(-along.y, along.x) * (bore * 1.05)
	var thick: float = maxf(3.0, bore * 0.55)
	draw_line(at - across, at + across, Color(0.02, 0.015, 0.03, 0.95), thick + 2.0)
	draw_line(at - across, at + across,
		Color("#443d4c").lerp(Color("#d7a75c"), warm), thick)


## THE TIER GATE, AS A HANDWHEEL. "tier 2 — buy 2 in this branch" was a grey
## sentence between two rows and it was doing the most important job on the
## screen: saying that the branch continues and what opens it.
##
## Shut, the wheel is turned forty-five degrees and drawn in cold iron, so the
## state is in the SHAPE as well as in the colour. Open, it is brass and square
## on, and the pipe either side of it runs hot.
func _valve(at: Vector2, radius: float, open: bool) -> void:
	var metal: Color = Color("#e0ad5e") if open else Color("#4f4859")
	draw_circle(at, radius + 2.0, Color(0.02, 0.015, 0.03, 0.95))
	draw_arc(at, radius, 0.0, TAU, 22, metal, 2.6)
	var turn: float = 0.0 if open else PI * 0.25
	for i in 4:
		var a: float = turn + PI * 0.5 * float(i)
		draw_line(at, at + Vector2(cos(a), sin(a)) * radius, metal, 2.0)
	draw_circle(at, maxf(1.5, radius * 0.30), metal)


## RANK, AS RIVETS. Filled is fitted. The unfilled ones are drawn as empty holes
## rather than omitted, because "this node has three ranks and you have one" and
## "this node has one rank and you have it" have to look different from across
## the board — that is most of what the pass was asked for.
func _rivets(at: Vector2, count: int, filled: int, tint: Color) -> void:
	for i in count:
		var c := at + Vector2(float(i) * SHOP_RIVET_STEP, 0.0)
		draw_circle(c, 3.7, Color(0.02, 0.015, 0.03, 0.9))
		if i >= filled:
			draw_arc(c, 2.8, 0.0, TAU, 12, Color("#6d6478"), 1.4)
			continue
		draw_circle(c, 2.9, tint)
		draw_circle(c - Vector2(0.8, 0.8), 1.0, Color(1, 1, 1, 0.4))


## How wide a run of rivets is, so the name beside them can be given the rest.
static func _rivet_span(count: int) -> float:
	return float(maxi(1, count) - 1) * SHOP_RIVET_STEP + 8.0


## WHAT KIND OF FITTING THIS IS, in twelve pixels of line work.
##
## `docs/META-PROGRESSION-DESIGN.md` §7 books 34 node icons as the most expensive
## art item in the project relative to what it buys, and says to ship on
## typography and shape glyphs instead. This is that: one glyph per BRANCH rather
## than one per node, which is four drawings instead of thirty-four and is also
## the distinction a player actually needs — the branch is the thing you scan for.
func _branch_glyph(centre: Vector2, branch: String, tint: Color) -> void:
	var r := 6.0
	match branch:
		"kit":
			## A blade. Her kit is the only branch that is about the captain.
			draw_polyline(PackedVector2Array([centre + Vector2(-r, r * 0.9),
				centre + Vector2(r * 0.35, -r), centre + Vector2(r, -r * 0.15)]),
				tint, 1.7)
		"gauge":
			draw_arc(centre, r * 0.92, 0.0, TAU, 18, tint, 1.5)
			draw_line(centre, centre + Vector2(r * 0.62, -r * 0.55), tint, 1.6)
		"ship":
			## A hull section: a deck line and a keel under it.
			draw_line(centre + Vector2(-r, -r * 0.45), centre + Vector2(r, -r * 0.45),
				tint, 1.6)
			draw_polyline(PackedVector2Array([centre + Vector2(-r * 0.85, -r * 0.45),
				centre + Vector2(0.0, r), centre + Vector2(r * 0.85, -r * 0.45)]),
				tint, 1.6)
		_:
			## Ruled lines. The Log is the branch that hands you information.
			for i in 3:
				var y: float = -r * 0.62 + float(i) * r * 0.62
				draw_line(centre + Vector2(-r, y), centre + Vector2(r, y), tint, 1.4)


## A FITTING'S PLATE. Dark field, rim in the state's metal, and a warm inner
## glow once it is yours — so a bought branch reads as lit pipework rather than
## as a column of ticks.
func _fitting(box: Rect2, state: int, lit: bool) -> void:
	draw_rect(box, FIT_FILL[state])
	if state >= Fit.HELD:
		## The glow sits inside the rim rather than under the plate, so it cannot
		## bleed into the node above at the compressed step 720p forces.
		draw_rect(box.grow(-2.0), Color(FIT_RIM[state].r, FIT_RIM[state].g,
			FIT_RIM[state].b, 0.10))
	var rim: Color = FIT_RIM[state]
	if lit:
		rim = rim.lerp(Color("#ffe6b0"), 0.55)
		draw_rect(box.grow(2.0), Color(rim.r, rim.g, rim.b, 0.16))
	draw_rect(box, rim, false, 2.0 if lit else 1.3)
	## Two rivets in the left edge, which is what makes it a plate bolted to a
	## machine rather than a rounded rectangle.
	for y in [box.position.y + 5.0, box.end.y - 5.0]:
		draw_circle(Vector2(box.position.x + 4.0, y), 1.3,
			Color(rim.r, rim.g, rim.b, 0.8))


## A WAX SEAL. The Articles' shape, and deliberately nothing like a fitting: a
## disc where the tree has rectangles, violet where the tree is brass, and no
## refund where the tree is free to respec. Three objects, three languages.
func _seal(centre: Vector2, radius: float, rim: Color, face: Color,
		lit: bool) -> void:
	draw_circle(centre, radius + 2.0, Color(0.02, 0.015, 0.03, 0.95))
	draw_circle(centre, radius, face)
	draw_arc(centre, radius, 0.0, TAU, 30, rim, 2.4 if lit else 1.7)
	for i in 8:
		var a: float = TAU * float(i) / 8.0 + PI * 0.125
		draw_circle(centre + Vector2(cos(a), sin(a)) * (radius - 3.2), 1.2,
			Color(rim.r, rim.g, rim.b, 0.85))


func _draw_workshop() -> void:
	_in_frame = false
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.015, 0.028, 0.94))
	var w: Dictionary = game.workshop

	## --- how deep the board wants to be -------------------------------------
	##
	## MEASURED, never estimated. The Captain's Kit is one node longer than every
	## estimate anyone has written into this file, and an estimate is what once
	## printed THE ARTICLES through WOUND KIT.
	var rows := 0
	var gates := 0
	for branch in SkyGearWorkshop.BRANCHES:
		var n := 0
		var tiers := {}
		for id in SkyGearWorkshop.NODES.keys():
			if str(SkyGearWorkshop.NODES[id].branch) != branch:
				continue
			n += 1
			tiers[int(SkyGearWorkshop.NODES[id].tier)] = true
		rows = maxi(rows, n)
		gates = maxi(gates, tiers.size() - 1)

	## Everything that is not a row of fittings, once: the two writing-area
	## insets, the banner's overhang, the ledger, the manifold nameplates, the
	## gates, and the foot. `wanted` is then one multiplication.
	var fixed: float = 62.0 + SHOP_HEAD + SHOP_LEDGER + SHOP_LEDGER_GAP \
		+ SHOP_BRANCH_HEAD + float(gates) * SHOP_GATE + SHOP_TAIL + 84.0
	var wanted: float = fixed + float(rows) * SHOP_STEP_MAX
	var tall: float = minf(size.y - 116.0, wanted)
	## AND IF IT DOES NOT FIT, THE ROWS CLOSE UP — never the chrome, and never the
	## point size. 1280x720 is the size this screen has broken at twice.
	var step := SHOP_STEP_MAX
	if wanted > tall:
		step = clampf((tall - fixed) / float(maxi(1, rows)),
			SHOP_STEP_MIN, SHOP_STEP_MAX)

	## THE PLATE TAKES THE WINDOW IT IS GIVEN. It was a fixed 1040 at every
	## resolution, which is 120 pixels of empty desk either side at 1280 while the
	## node names inside were being shrunk to fit, and a postage stamp adrift in
	## the middle of a 2560 ultrawide.
	var page_w: float = clampf(size.x - 96.0, 1040.0, 1420.0)
	var page := Rect2(size.x * 0.5 - page_w * 0.5,
		maxf(48.0, (size.y - tall) * 0.4), page_w, tall)
	_sheet(page)
	## The plate the audit measures every string on. `_stamp` moves it to whatever
	## strip is being written and each one hands it back here.
	var plate := _frame
	_banner(size.x * 0.5, page.position.y - 10.0, 480.0)
	_center_text("THE WORKSHOP", page.position.y + 48.0, 34, BRASS_LIT)

	var room := writing_area(page)
	ui.begin("workshop", self, font, get_local_mouse_position())

	## --- the ledger ---------------------------------------------------------
	##
	## What you hold, what you have committed, and what a respec would hand back —
	## which is the same number, said once, where a player can find it before
	## pressing the button rather than after. The board used to say "480 SCRIP · 2
	## SIGILS" in one teal line and nothing else about the state of your account.
	var committed := 0
	var fitted := 0
	var steps := 0
	for id in SkyGearWorkshop.NODES.keys():
		var have := SkyGearWorkshop.rank(w, id)
		committed += int(SkyGearWorkshop.NODES[id].cost) * have
		fitted += have
		steps += int(SkyGearWorkshop.NODES[id].ranks)
	var ledger := _stamp(Rect2(room.position.x, room.position.y + SHOP_HEAD,
		room.size.x, SHOP_LEDGER), 0.55)
	var cell: float = ledger.size.x / 4.0
	var base: float = ledger.position.y + 19.0
	var readouts := [
		["SCRIP", "%d" % int(w.scrip), Color("#37f0c8")],
		["COMMITTED", "%d" % committed, BRASS_LIT],
		["SIGILS", "%d" % int(w.sigils), SIGIL_VIOLET],
		["FITTINGS", "%d of %d" % [fitted, steps], BONE],
	]
	for i in readouts.size():
		var at: float = ledger.position.x + float(i) * cell
		if i > 0:
			draw_line(Vector2(at, ledger.position.y + 4.0),
				Vector2(at, ledger.end.y - 4.0), Color("#4a4356"), 1.0)
		_label(str(readouts[i][0]), Vector2(at + 12.0, base), cell - 24.0,
			HORIZONTAL_ALIGNMENT_LEFT, 12, Color("#8f8697"))
		_value(str(readouts[i][1]), Vector2(at + 12.0, base), cell - 24.0,
			HORIZONTAL_ALIGNMENT_RIGHT, 15, readouts[i][2] as Color)
	_frame = plate
	_in_frame = true

	## --- the board ----------------------------------------------------------
	var board_top: float = ledger.end.y + SHOP_LEDGER_GAP
	var board_h: float = SHOP_BRANCH_HEAD + float(rows) * step \
		+ float(gates) * SHOP_GATE
	var side_w: float = clampf(room.size.x * 0.20, 190.0, 260.0)
	var tree_w: float = room.size.x - side_w - 22.0
	var col_w: float = (tree_w - SHOP_COL_GAP * 3.0) / 4.0
	var node_w: float = col_w - SHOP_SPINE

	## WHAT THE THING UNDER YOUR HAND DOES, once, in a size you can read.
	##
	## Every node used to carry its own sentence inside its button — a 240px
	## column holding "the first killing blow leaves you at 1, once a run", which
	## `_fits` duly rendered at seven points. The sentence lives at the foot of
	## the page and belongs to whatever is focused; focus follows the mouse and
	## the keyboard both, so it costs no new interaction.
	##
	## THREE FIELDS now, not one. The old strip said what a node does and never
	## said what it costs, whether you can afford it, or why it is locked — so
	## every one of those had to be worked out from a colour.
	var told := {}

	for c in SkyGearWorkshop.BRANCHES.size():
		var branch: String = str(SkyGearWorkshop.BRANCHES[c])
		var x: float = room.position.x + float(c) * (col_w + SHOP_COL_GAP)
		var spine_x: float = x + SHOP_SPINE * 0.5
		var node_x: float = x + SHOP_SPINE

		## THE MANIFOLD. The branch's name, its glyph, and how much of it is
		## yours — as a figure and as a fill along the bottom of the plate, which
		## is the one place on this screen a bar is worth more than a number.
		var have_here := 0
		var steps_here := 0
		for id in SkyGearWorkshop.NODES.keys():
			if str(SkyGearWorkshop.NODES[id].branch) != branch:
				continue
			have_here += SkyGearWorkshop.rank(w, id)
			steps_here += int(SkyGearWorkshop.NODES[id].ranks)
		var head := Rect2(x, board_top, col_w, SHOP_BRANCH_HEAD - 5.0)
		_stamp(head, 0.5)
		draw_rect(head, Color("#7a5c30"), false, 1.0)
		var fill_w: float = head.size.x * float(have_here) / maxf(1.0, float(steps_here))
		draw_rect(Rect2(head.position.x, head.end.y - 2.0, fill_w, 2.0), BRASS_LIT)
		_branch_glyph(head.position + Vector2(12.0, head.size.y * 0.5), branch,
			BRASS_LIT if have_here > 0 else Color("#8a7d5e"))
		var head_name := str(SkyGearWorkshop.BRANCH_NAMES[branch])
		_label(head_name, Vector2(head.position.x + 22.0,
			head.position.y + head.size.y * 0.5 + 5.0), head.size.x - 62.0,
			HORIZONTAL_ALIGNMENT_LEFT, _fits(head_name, head.size.x - 62.0, 13),
			BRASS_LIT)
		_label("%d/%d" % [have_here, steps_here],
			Vector2(head.position.x, head.position.y + head.size.y * 0.5 + 5.0),
			head.size.x - 8.0, HORIZONTAL_ALIGNMENT_RIGHT, 12,
			BONE if have_here > 0 else Color("#8f8697"))
		_frame = plate
		_in_frame = true

		var y: float = head.end.y + 5.0
		var shown_tier := -1
		## THE OUTLET. A flange where the main leaves the manifold, so the branch
		## reads as one run of plumbing from the nameplate down rather than as a
		## column of plates with a line beside them.
		_collar(Vector2(spine_x, y + 2.0), Vector2(0.0, 1.0), 7.0, 1.0)
		var last_y: float = y
		for id in SkyGearWorkshop.NODES.keys():
			var node: Dictionary = SkyGearWorkshop.NODES[id]
			if str(node.branch) != branch:
				continue
			var tier := int(node.tier)
			var open: bool = SkyGearWorkshop.tier_open(w, branch, tier)
			if tier != shown_tier:
				shown_tier = tier
				if tier > 0:
					## THE GATE. The wheel on the main, and the condition beside
					## it — spelled out as PROGRESS rather than as a target,
					## because "buy 2 in this branch" never said how many of the
					## two you already had.
					var gate_y: float = y + SHOP_GATE * 0.5
					_pipe(Vector2(spine_x, y), Vector2(spine_x, gate_y - 9.0),
						7.0, 1.0 if open else 0.12)
					_valve(Vector2(spine_x, gate_y), 8.0, open)
					var need: int = tier * SkyGearWorkshop.TIER_STEP
					var got: int = mini(SkyGearWorkshop.bought_in(w, branch), need)
					var gate_text := "TIER %d · %d of %d fitted" % [tier + 1, got, need]
					if open:
						gate_text = "TIER %d · OPEN" % (tier + 1)
					_label(gate_text, Vector2(spine_x + 14.0, gate_y + 4.0),
						col_w - SHOP_SPINE * 0.5 - 16.0, HORIZONTAL_ALIGNMENT_LEFT,
						_fits(gate_text, col_w - SHOP_SPINE * 0.5 - 16.0, 12),
						Color("#37f0c8") if open else Color("#8f8697"))
					## AND THE MAIN RESUMES BELOW THE WHEEL. It used to resume at the
					## previous fitting, so the next segment was drawn straight over
					## the valve and every gate on the board was half a circle.
					last_y = gate_y + 9.0
					y += SHOP_GATE
			var have := SkyGearWorkshop.rank(w, id)
			var ranks := int(node.ranks)
			var cost := int(node.cost)
			var state: int = Fit.READY
			if have >= ranks:
				state = Fit.FULL
			elif have > 0:
				state = Fit.HELD
			elif not open:
				state = Fit.LOCKED
			elif int(w.scrip) < cost:
				state = Fit.DEAR

			var box := Rect2(node_x, y + 3.0, node_w, step - 6.0)
			var cy: float = box.get_center().y
			## The main down to this fitting, then the spur into it.
			_pipe(Vector2(spine_x, last_y), Vector2(spine_x, cy), 7.0,
				1.0 if open else 0.12)
			_pipe(Vector2(spine_x, cy), Vector2(box.position.x, cy), 5.0,
				FIT_HEAT[state])
			_collar(Vector2(spine_x, cy), Vector2(0.0, 1.0), 7.0,
				1.0 if open else 0.12)
			last_y = cy

			## EVERY FITTING IS FOCUSABLE, including the ones you cannot buy.
			##
			## They used to be `disabled`, which is right for a menu and wrong for
			## a board: `disabled` refuses the hover, so the description strip
			## went silent over exactly the nodes a player most wants to read
			## about — the expensive ones and the ones behind a shut valve. The
			## purchase is still refused, by `can_buy`, which is where that
			## decision belongs.
			var mine := ui.declared().size()
			if ui.button(box, "", {"bare": true}):
				SkyGearWorkshop.buy(w, id)
			var hot: bool = ui.lit(mine)
			_fitting(box, state, hot)
			_branch_glyph(Vector2(box.position.x + 12.0, cy), branch,
				Color(FIT_RIM[state].r, FIT_RIM[state].g, FIT_RIM[state].b, 0.9))
			## THE NAME GETS WHATEVER IS LEFT, and what is left was measured rather
			## than eyeballed: the longest node name in the table is Deep Pockets at
			## 85 pixels at 13pt, and the narrowest column this board ever draws
			## leaves it 85. One pixel of slack is not comfortable, so `_fits` is
			## still behind it — but it now yields at 12 rather than at 8, because
			## the rank no longer competes with the name for the same box.
			var span := _rivet_span(ranks)
			_rivets(Vector2(box.end.x - 34.0 - span + 4.0, cy), ranks, have,
				FIT_INK[state])
			var name_w: float = node_w - 22.0 - span - 10.0 - 24.0 - 8.0
			_label(str(node.name), Vector2(box.position.x + 22.0, cy + 5.0),
				name_w, HORIZONTAL_ALIGNMENT_LEFT,
				_fits(str(node.name), name_w, 13), FIT_INK[state])
			## No price on a finished fitting. Every rivet is filled and the rim
			## is green; a number there would be a number that means nothing.
			if state != Fit.FULL:
				_label("%d" % cost, Vector2(box.position.x, cy + 5.0),
					node_w - 8.0, HORIZONTAL_ALIGNMENT_RIGHT, 12,
					BRASS_LIT if state in [Fit.READY, Fit.HELD] else FIT_INK[state])

			if ui.focused() == mine:
				var status := "%d scrip · rank %d of %d" % [cost, have, ranks]
				match state:
					Fit.FULL:
						status = "every rank fitted"
					Fit.LOCKED:
						status = "locked · %d of %d fitted in this branch" % [
							mini(SkyGearWorkshop.bought_in(w, branch),
								tier * SkyGearWorkshop.TIER_STEP),
							tier * SkyGearWorkshop.TIER_STEP]
					Fit.DEAR:
						status = "%d scrip · you hold %d" % [cost, int(w.scrip)]
				told = {"name": str(node.name), "text": str(node.text),
					"status": status, "tint": FIT_INK[state]}
			y += step
		## AND THE MAIN IS CAPPED. A pipe that stops in mid-air says the branch
		## continues off the bottom of the plate, which is the one thing about
		## this tree that is not true — it is finite, and that is the point of it.
		_pipe(Vector2(spine_x, last_y), Vector2(spine_x, last_y + 9.0), 7.0, 1.0)
		_collar(Vector2(spine_x, last_y + 10.0), Vector2(0.0, 1.0), 8.0, 1.0)

	## --- the Articles -------------------------------------------------------
	## Six pixels off the writing area's right edge. The painted bevel runs
	## further in than the slice margin admits and the sigil pips were landing
	## on it — the one thing on this board that is drawn hard against the rail.
	var side := Rect2(room.end.x - side_w - 6.0, board_top, side_w, board_h)
	var side_head := Rect2(side.position.x, side.position.y, side.size.x,
		SHOP_BRANCH_HEAD - 5.0)
	_stamp(side_head, 0.5)
	draw_rect(side_head, Color("#5d4a73"), false, 1.0)
	_label("THE ARTICLES", Vector2(side_head.position.x + 10.0,
		side_head.position.y + side_head.size.y * 0.5 + 5.0),
		side_head.size.x - 20.0, HORIZONTAL_ALIGNMENT_LEFT, 13, SIGIL_VIOLET)
	_label("no refund", Vector2(side_head.position.x,
		side_head.position.y + side_head.size.y * 0.5 + 5.0),
		side_head.size.x - 8.0, HORIZONTAL_ALIGNMENT_RIGHT, 12, Color("#8f8697"))
	_frame = plate
	_in_frame = true

	var art_step: float = (board_h - SHOP_BRANCH_HEAD) \
		/ maxf(1.0, float(SkyGearWorkshop.ARTICLES.size()))
	var art_y: float = side_head.end.y + 5.0
	## THE CORD THE SEALS ARE STRUNG ON. The Articles are not a tree and must
	## not grow one, but seven discs floating in a column read as seven
	## unrelated buttons. A cord threaded behind them says they are one set,
	## which is what they are and what "you can never own the whole side" is
	## about. Drawn before the seals, so they sit on it.
	draw_line(Vector2(side.position.x + 20.0, art_y + art_step * 0.5),
		Vector2(side.position.x + 20.0,
			art_y + art_step * (float(SkyGearWorkshop.ARTICLES.size()) - 0.5)),
		Color(0.35, 0.28, 0.45, 0.75), 2.0)
	for id in SkyGearWorkshop.ARTICLES.keys():
		var art: Dictionary = SkyGearWorkshop.ARTICLES[id]
		var held: bool = SkyGearWorkshop.owns(w, id)
		var barred: bool = art.has("excludes") \
			and SkyGearWorkshop.owns(w, str(art.excludes))
		var takeable: bool = SkyGearWorkshop.can_take(w, id)
		var row := Rect2(side.position.x, art_y, side.size.x, art_step - 5.0)
		var mine := ui.declared().size()
		if ui.button(row, "", {"bare": true}):
			SkyGearWorkshop.take(w, id)
		var hot: bool = ui.lit(mine)

		var ink: Color = SIGIL_VIOLET if held else \
			(BONE if takeable else Color("#8f8697"))
		var rim: Color = Color("#a98fd6") if held else \
			(Color("#7a6a96") if takeable else Color("#4a4356"))
		if hot:
			rim = rim.lerp(Color("#efe2ff"), 0.5)
			draw_rect(row.grow(-1.0), Color(rim.r, rim.g, rim.b, 0.09))
		var radius: float = minf(13.0, row.size.y * 0.40)
		var disc := Vector2(row.position.x + 14.0, row.get_center().y)
		_seal(disc, radius, rim,
			Color(0.16, 0.12, 0.22, 0.95) if held else Color(0.05, 0.042, 0.075, 0.92),
			hot)
		if held:
			## A signature, not a tick: two strokes, and the only mark on this
			## board that is not made of pipework.
			draw_polyline(PackedVector2Array([
				disc + Vector2(-radius * 0.45, 0.0),
				disc + Vector2(-radius * 0.08, radius * 0.42),
				disc + Vector2(radius * 0.52, -radius * 0.45)]), SIGIL_VIOLET, 2.0)
		elif barred:
			## Struck through. An Article you can never hold while you hold its
			## twin is not the same thing as one you cannot afford.
			draw_line(disc + Vector2(-radius * 0.7, radius * 0.7),
				disc + Vector2(radius * 0.7, -radius * 0.7), Color("#8a5236"), 2.2)

		## The cost in sigil pips rather than a numeral, because the Articles cost
		## one to three of a currency you hold two of — a bar chart at that scale
		## is faster to read than arithmetic.
		var pips: float = _rivet_span(int(art.cost))
		if not held:
			_rivets(Vector2(row.end.x - 10.0 - pips + 4.0, row.get_center().y),
				int(art.cost), int(art.cost) if takeable else 0, ink)
		var key := str(art.get("key", ""))
		var key_w: float = 0.0
		if key != "":
			## The binding, on the seal. Brace, Recall and Scuttle are the three
			## Articles that are a KEY rather than a passive, and the one thing a
			## player has to know about them before buying is which key.
			key_w = 16.0
			var tab := Rect2(row.end.x - 12.0 - pips - key_w, row.get_center().y - 8.0,
				14.0, 16.0)
			draw_rect(tab, Color(0.05, 0.042, 0.075, 0.9))
			draw_rect(tab, rim, false, 1.0)
			_label(key, Vector2(tab.position.x, tab.position.y + 12.0), tab.size.x,
				HORIZONTAL_ALIGNMENT_CENTER, 12, ink)
		var art_name_w: float = row.size.x - 30.0 - pips - key_w - 14.0
		_label(str(art.name), Vector2(row.position.x + 30.0,
			row.get_center().y + 5.0), art_name_w, HORIZONTAL_ALIGNMENT_LEFT,
			_fits(str(art.name), art_name_w, 13), ink)

		if ui.focused() == mine:
			var blurb := str(art.text)
			if bool(art.get("captain_only", false)):
				blurb = "captain only · " + blurb
			var status := "%d sigils · you hold %d" % [int(art.cost), int(w.sigils)]
			if int(art.cost) == 1:
				status = "1 sigil · you hold %d" % int(w.sigils)
			if held:
				status = "signed"
			elif barred:
				status = "barred by %s" % str(
					SkyGearWorkshop.ARTICLES[str(art.excludes)].name)
			told = {"name": str(art.name), "text": blurb, "status": status,
				"tint": ink}
		art_y += art_step

	## --- the foot -----------------------------------------------------------
	##
	## On the writing area's floor rather than the interior's: on a page this tall
	## the painted bevel reaches 22 past where the slice margin says it does, and
	## BACK was parked half on the brass with its Esc hint fully on it.
	var foot: float = room.end.y - 34.0
	var strip := _stamp(Rect2(room.position.x, foot - 34.0, room.size.x, 26.0), 0.55)
	if not told.is_empty():
		## Name, then what it does, then what it costs and whether you can pay —
		## three fields, left to right, because that is the order the question is
		## asked in.
		var lead := "%s  ·  %s" % [str(told.name), str(told.text)]
		var lead_w: float = strip.size.x * 0.62
		_label(lead, Vector2(strip.position.x + 10.0, strip.end.y - 8.0), lead_w,
			HORIZONTAL_ALIGNMENT_LEFT, _fits(lead, lead_w, 14), Color("#dcd2c4"))
		_label(str(told.status), Vector2(strip.end.x - 10.0 - strip.size.x * 0.34,
			strip.end.y - 8.0), strip.size.x * 0.34, HORIZONTAL_ALIGNMENT_RIGHT,
			13, told.tint as Color)
	_frame = plate
	_in_frame = true

	## RESPEC SAYS WHAT IT RETURNS. "RESPEC (FREE)" told you the price of pressing
	## it and not the consequence, which is the number a player actually wants.
	var respec_label := "RESPEC · RETURNS %d" % committed
	if committed <= 0:
		respec_label = "NOTHING FITTED YET"
	if ui.button(Rect2(room.position.x, foot, 220.0, 34.0), respec_label,
			{"disabled": committed <= 0}) and committed > 0:
		SkyGearWorkshop.respec(w)
	_label("free, and never mid-run — experimenting is all a tree this small has to offer",
		Vector2(room.position.x + 232.0, foot + 22.0), room.size.x - 460.0,
		HORIZONTAL_ALIGNMENT_LEFT, 12)
	if ui.button(Rect2(room.end.x - 200.0, foot, 200.0, 34.0), "BACK",
			{"primary": true, "hint": "Esc"}):
		game.workshop_open = false


func _draw_settings() -> void:
	_in_frame = false
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.015, 0.028, 0.90))
	## Nine rows of chrome rather than eight, and the extra one is the banner:
	## its ornament hangs 115 below the top of the sheet and the first slider was
	## starting at 86.
	var rows := 9
	var tall: float = 150.0 + rows * 40.0 + 58.0
	var top: float = maxf(60.0, (size.y - tall) * 0.5)
	var sheet := Rect2(size.x * 0.5 - 330.0, top, 660.0, tall)
	_panel(sheet)
	_banner(size.x * 0.5, sheet.position.y - 10.0, 420.0)
	_center_text("SETTINGS", sheet.position.y + 48.0, 38, BRASS_LIT)

	ui.begin("settings", self, font, get_local_mouse_position())
	## Against the plate's interior, like everything else. 40 in from a 660-wide
	## sheet is fourteen pixels inside a fifty-four pixel rail, and 580 wide out
	## of 552 of interior overhangs it at both ends — every slider and every row
	## on this screen was drawn across the brass.
	var room := interior(sheet)
	var w: float = room.size.x
	var x: float = room.position.x
	var y: float = room.position.y + 62.0
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
	## On the writing area's floor, not the interior's: the interior's bottom
	## edge is the painted bevel, and this line was printed across it.
	_label("changes are saved when you leave this screen",
		Vector2(room.position.x, writing_area(sheet).end.y), room.size.x,
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
	## banner, title, reason, buttons, the log note — plus whatever the Workshop
	## adds underneath. A constant here was fine until Ledger and the payout line
	## started appearing, and then the footer sat on the bottom rail; the audit
	## found it on the first run after.
	var chrome := 360.0
	if game.talent("show_ledger") > 0.0:
		chrome += 18.0
	if not (game.banked as Dictionary).is_empty() and int(game.banked.get("scrip", 0)) > 0:
		chrome += 18.0
	_sheet(Rect2(size.x * 0.5 - 400.0, 52.0, 800.0,
		minf(size.y - 104.0, tall + chrome)))
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
	## LEDGER. This run against your best three, which is the difference between
	## "wave 9" and "wave 9, and your best is 12" — a number only means something
	## next to another number.
	if game.talent("show_ledger") > 0.0:
		var past: Array = SkyGearRunLog.load_all()
		var waves: Array[int] = []
		for entry in past:
			if entry is Dictionary:
				waves.append(int(entry.get("wave", 0)))
		waves.sort()
		waves.reverse()
		var best: Array[String] = []
		for i in mini(3, waves.size()):
			best.append("%d" % waves[i])
		if not best.is_empty():
			_label("this run reached %d · your best three: %s"
				% [game.wave, ", ".join(best)], Vector2(page.position.x, y + 14.0),
				page.size.x, HORIZONTAL_ALIGNMENT_CENTER, 12, Color("#8fa6c9"))
			y += 18.0

	## AND WHAT IT PAID. A run that quietly banked scrip is a run whose reward the
	## player finds two screens later, if at all.
	if not (game.banked as Dictionary).is_empty() and int(game.banked.get("scrip", 0)) > 0:
		var earned := "+%d scrip" % int(game.banked.scrip)
		if int(game.banked.get("sigils", 0)) > 0:
			earned += "  ·  +%d sigil" % int(game.banked.sigils)
		if bool(game.banked.get("first_win", false)):
			earned = "THE WORKSHOP IS OPEN  ·  " + earned
		_label(earned, Vector2(page.position.x, y + 14.0), page.size.x,
			HORIZONTAL_ALIGNMENT_CENTER, 13, Color("#e8c376"))
		y += 18.0

	var log_note := "saved to the run log" if game.run_logged 		else "COULD NOT WRITE THE RUN LOG — copy it before you leave"
	_center_text(log_note, y + 18.0, 14,
		Color("#6a6478") if game.run_logged else Color("#ff9a5a"))


func _center_text(text: String, y: float, font_size: int, color: Color) -> void:
	_say(text, Vector2(0, y), size.x, HORIZONTAL_ALIGNMENT_CENTER, font_size, color)

func _center_in_rect(text: String, rect: Rect2, font_size: int, color: Color) -> void:
	_say(text, rect.position + Vector2(0, font_size), rect.size.x,
		HORIZONTAL_ALIGNMENT_CENTER, font_size, color)

