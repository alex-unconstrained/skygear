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

func _draw_title() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.025, 0.045, 0.72))
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


## A brass plate: dark fill, hard ink edge, a brass inlay inside it, a rivet in
## each corner. Every panel is this, which is what makes them read as one
## instrument rather than four boxes.
func _panel(rect: Rect2) -> void:
	draw_rect(rect, PANEL_FILL)
	draw_rect(rect, Color("#0d0b12"), false, 5.0)
	draw_rect(rect.grow(-4.0), BRASS, false, 2.0)
	for corner in [rect.position + Vector2(9, 9), rect.position + Vector2(rect.size.x - 9, 9),
			rect.position + Vector2(9, rect.size.y - 9),
			rect.position + Vector2(rect.size.x - 9, rect.size.y - 9)]:
		draw_circle(corner, 2.6, BRASS)


func _draw_game_hud() -> void:
	var player: SkyGearPlayer = game.player

	## --- the captain: portrait, health, pressure, dash ---------------------
	var panel := Rect2(24, 20, 350, 112)
	_panel(panel)
	var portrait := _tex("res://assets/art/ui/portrait_corsair.png")
	var pr := 34.0
	var centre := panel.position + Vector2(20 + pr, panel.size.y * 0.5)
	if portrait != null:
		draw_texture_rect_region(portrait, Rect2(centre - Vector2(pr, pr), Vector2(pr * 2, pr * 2)),
			Rect2(Vector2.ZERO, portrait.get_size()))
	draw_arc(centre, pr + 2.0, 0.0, TAU, 40, BRASS, 2.4)

	var bx := panel.position.x + 24 + pr * 2 + 12
	var bw := panel.size.x - (bx - panel.position.x) - 18
	_bar(Rect2(bx, panel.position.y + 26, bw, 20), player.hp / player.max_hp,
		Color("#e8542e"), Color("#8b2418"), "CAPTAIN", "%d / %d" % [player.hp, player.max_hp])

	# the pressure gauge, with its own icon watermarked into the bar
	var gauge := Rect2(bx, panel.position.y + 56, bw, 12)
	var pressure_ratio: float = player.pressure / 100.0
	draw_rect(gauge, Color("#0b0910"))
	if pressure_ratio > 0.0:
		draw_rect(Rect2(gauge.position, Vector2(gauge.size.x * pressure_ratio, gauge.size.y)),
			Color("#c9b6e8") if pressure_ratio < 1.0 else Color("#f2eaff"))
	draw_rect(gauge, Color("#0d0b12"), false, 2.0)
	draw_line(gauge.position + Vector2(gauge.size.x * 0.5, 0),
		gauge.position + Vector2(gauge.size.x * 0.5, gauge.size.y), BRASS, 1.5)
	var gauge_icon := _tex("res://assets/art/ui/icon_vent.png" if pressure_ratio >= 1.0
		else "res://assets/art/ui/icon_pressure.png")
	if gauge_icon != null:
		draw_texture_rect_region(gauge_icon,
			Rect2(gauge.position + Vector2(2, -3), Vector2(18, 18)),
			Rect2(Vector2.ZERO, gauge_icon.get_size()))
	draw_string(font, gauge.position + Vector2(gauge.size.x - 66, gauge.size.y - 1),
		"VENTING" if pressure_ratio >= 1.0 else "PRESSURE",
		HORIZONTAL_ALIGNMENT_RIGHT, 64, 10,
		Color("#f2eaff") if pressure_ratio >= 1.0 else Color("#7e7392"))

	draw_string(font, Vector2(bx, panel.position.y + 96), "DASH", HORIZONTAL_ALIGNMENT_LEFT,
		-1, 12, Color("#8b8296"))
	for i in 2:
		var lit := i < player.dash_charges
		var pip := Vector2(bx + 46 + i * 20, panel.position.y + 92)
		draw_circle(pip, 7.0, Color("#37f0c8") if lit else Color("#201c28"))
		draw_arc(pip, 7.0, 0.0, TAU, 16, Color("#0d0b12"), 2.0)

	## --- the objective ------------------------------------------------------
	var right := Rect2(size.x - 372, 20, 348, 92)
	_panel(right)
	_bar(Rect2(right.position.x + 18, right.position.y + 30, right.size.x - 36, 18),
		game.boiler_hp / game.boiler_max_hp, Color("#37f0c8"), Color("#1c6f61"),
		"BOILER", "%d / %d" % [game.boiler_hp, game.boiler_max_hp])
	draw_string(font, right.position + Vector2(18, 76),
		"WAVE %d / 12" % game.wave, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, BRASS_LIT)
	draw_string(font, right.position + Vector2(right.size.x - 158, 76),
		"BOARDERS %d" % game.enemy_count(), HORIZONTAL_ALIGNMENT_LEFT, -1, 17, BONE)

	## --- the lane readout ---------------------------------------------------
	## Which lane is breaking, without having to look at it: three tracks, the
	## cannon still standing in each drawn as its remaining health, and the
	## deepest boarder marked on it.
	var lanes := Rect2(size.x - 372, 122, 348, 92)
	_panel(lanes)
	var names := ["PORT", "CENTRE", "STARBOARD"]
	for lane in 3:
		var row := lanes.position + Vector2(18, 30 + lane * 22)
		draw_string(font, row, names[lane], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#8b8296"))
		var track := Rect2(row + Vector2(84, -9), Vector2(lanes.size.x - 130, 11))
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
		draw_rect(track, Color("#0d0b12"), false, 1.6)
		draw_string(font, row + Vector2(lanes.size.x - 40, 0), str(count),
			HORIZONTAL_ALIGNMENT_RIGHT, 26, 12, BONE)

	## --- the hand -----------------------------------------------------------
	var labels := ["LMB", "RMB", "Q", "E"]
	var slot_w := 128.0
	var start_x := (size.x - slot_w * 4.0) * 0.5
	for i in 4:
		var rect := Rect2(start_x + i * slot_w, size.y - 104, slot_w - 8, 86)
		_panel(rect)
		draw_string(font, rect.position + Vector2(10, 20), labels[i],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13, BRASS_LIT)
		if i >= game.skills.size():
			draw_string(font, rect.position + Vector2(10, 54), "LOCKED",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#5f5863"))
			continue
		var skill: Dictionary = game.skills[i]
		var element: Color = SkyGearData.ELEMENTS[skill.element].color
		var icon := _tex(str(SLOT_ICONS.get(skill.shape, "")))
		var icon_at := rect.position + Vector2(rect.size.x * 0.5 - 18, 24)
		if icon != null:
			draw_texture_rect_region(icon, Rect2(icon_at, Vector2(36, 36)),
				Rect2(Vector2.ZERO, icon.get_size()), element)
		var ready: bool = float(skill.cooldown_left) <= 0.0
		if not ready:
			# the cooldown eats the icon from the bottom, as it does in the browser
			var st: Dictionary = game.skill_stats(skill)
			var frac: float = clampf(float(skill.cooldown_left) / maxf(0.01, float(st.cooldown)), 0.0, 1.0)
			draw_rect(Rect2(icon_at + Vector2(0, 36.0 * (1.0 - frac)), Vector2(36, 36.0 * frac)),
				Color(0.04, 0.03, 0.06, 0.72))
		draw_string(font, rect.position + Vector2(6, rect.size.y - 10),
			SkyGearData.skill_name(skill), HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 12, 12,
			element if ready else Color("#7f7782"))


func _bar(rect: Rect2, ratio: float, top: Color, bottom: Color, label: String, value: String) -> void:
	draw_rect(rect, Color("#0b0910"))
	var filled := Rect2(rect.position, Vector2(rect.size.x * clampf(ratio, 0.0, 1.0), rect.size.y))
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
	draw_string(font, rect.position + Vector2(2, -4), label, HORIZONTAL_ALIGNMENT_LEFT,
		-1, 11, Color("#8b8296"))
	draw_string(font, Vector2(rect.position.x, rect.position.y - 4), value,
		HORIZONTAL_ALIGNMENT_RIGHT, rect.size.x, 12, BONE)


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
		var at := Vector2(head.at.x, maxf(head.at.y, 26.0))
		if at.x < 400.0 and at.y < 150.0:
			at.y = maxf(at.y, 150.0)
		elif at.x > size.x - 400.0 and at.y < 230.0:
			at.y = maxf(at.y, 230.0)
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
			draw_string(font, Vector2(x - 130.0, size.y * 0.30 + lane * 24.0),
				"%s LANE BREAKING" % LANE_NAMES[lane], HORIZONTAL_ALIGNMENT_CENTER, 260, 18,
				Color("#ff4d37"))

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


func _draw_draft() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.015, 0.028, 0.78))
	_center_text("CHOOSE ONE", 128.0, 34, Color("#e8c376"))
	_center_text("Every weapon is a shape crossed with an element.", 158.0, 18, Color("#b9afaa"))
	# reroll: two per RUN, so spending one is a decision about which hand
	var reroll_label := ("REROLL  x%d   (R)" % game.rerolls) if game.rerolls > 0 else "NO REROLLS LEFT"
	_center_text(reroll_label, 580.0, 20,
		Color("#e8c376") if game.rerolls > 0 else Color("#6a6478"))
	var card_width := 280.0
	var gap := 28.0
	var start_x := (size.x - (card_width * 3.0 + gap * 2.0)) * 0.5
	for i in mini(3, game.draft_options.size()):
		var card: Dictionary = game.draft_options[i]
		var rect := Rect2(start_x + i * (card_width + gap), 200, card_width, 340)
		_panel(rect)
		_center_in_rect(str(i + 1), Rect2(rect.position + Vector2(0, 16), Vector2(card_width, 30)), 22, Color("#ffe08a"))

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
	_panel(sheet)
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
	_panel(Rect2(size.x * 0.5 - 400.0, 52.0, 800.0, minf(size.y - 104.0, tall + 232.0)))
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

