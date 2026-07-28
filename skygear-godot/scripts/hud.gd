class_name SkyGearHUD
extends Control

var game: Node
var font: Font

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
		"DRAFT":
			_draw_game_hud()
			_draw_draft()
		"PAUSE":
			_draw_game_hud()
			_draw_overlay("PAUSED", _pause_text())
		"GAMEOVER":
			_draw_overlay("DECK LOST", game.end_reason + "\nEnter to return to title")
		"VICTORY":
			_draw_overlay("DECK HELD", "Twelve waves repelled.\nEnter to return to title")
		_:
			_draw_game_hud()

func _draw_title() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.025, 0.045, 0.72))
	_center_text("SKYGEAR", 150.0, 64, Color("#e8c376"))
	_center_text("STORM-DUSK · GODOT PORT", 205.0, 24, Color("#37f0c8"))
	_center_text("Keep the Boiler alive through twelve boarding waves.", 286.0, 22, Color("#eee5d5"))
	_center_text("WASD move · mouse aim · LMB/RMB/Q/E skills · Space dash", 330.0, 18, Color("#b9afaa"))
	_center_text("Press Enter to choose your opening weapon", 430.0, 26, Color("#ffe08a"))
	_center_text("Milestone 1 · v11 combat vertical slice", 675.0, 15, Color("#8f8697"))

func _draw_game_hud() -> void:
	var player: SkyGearPlayer = game.player
	draw_rect(Rect2(28, 24, 330, 98), Color(0.035, 0.028, 0.045, 0.90))
	_draw_bar(Rect2(48, 45, 270, 16), player.hp / player.max_hp, Color("#d54a35"), "CAPTAIN  %d / %d" % [player.hp, player.max_hp])
	_draw_bar(Rect2(48, 79, 270, 12), player.pressure / 100.0, Color("#e8c376"), "PRESSURE  %d" % player.pressure)
	draw_string(font, Vector2(48, 112), "DASH  " + "◆".repeat(player.dash_charges) + "◇".repeat(2 - player.dash_charges), HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("#37f0c8"))

	draw_rect(Rect2(size.x - 356, 24, 328, 76), Color(0.035, 0.028, 0.045, 0.90))
	_draw_bar(Rect2(size.x - 336, 45, 288, 15), game.boiler_hp / game.boiler_max_hp, Color("#37f0c8"), "BOILER  %d / %d" % [game.boiler_hp, game.boiler_max_hp])
	draw_string(font, Vector2(size.x - 336, 88), "WAVE %d / 12     BOARDERS %d" % [game.wave, game.enemy_count()], HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("#eee5d5"))

	var labels := ["LMB", "RMB", "Q", "E"]
	var total_width := 4 * 132
	var start_x := (size.x - total_width) * 0.5
	for i in 4:
		var rect := Rect2(start_x + i * 132, size.y - 94, 122, 66)
		draw_rect(rect, Color(0.035, 0.028, 0.045, 0.94))
		draw_rect(rect, Color("#b0813f"), false, 2.0)
		draw_string(font, rect.position + Vector2(8, 20), labels[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#e8c376"))
		if i < game.skills.size():
			var skill: Dictionary = game.skills[i]
			var name := SkyGearData.skill_name(skill)
			var ready := float(skill.cooldown_left) <= 0.0
			draw_string(font, rect.position + Vector2(8, 43), name, HORIZONTAL_ALIGNMENT_LEFT, 106, 14, Color("#eee5d5") if ready else Color("#7f7782"))
			if not ready:
				draw_string(font, rect.position + Vector2(8, 60), "%.1fs" % skill.cooldown_left, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#ff9a5a"))
		else:
			draw_string(font, rect.position + Vector2(8, 47), "LOCKED", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#5f5863"))

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
		draw_rect(rect, Color(0.08, 0.06, 0.09, 0.98))
		draw_rect(rect, Color("#b0813f"), false, 3.0)
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

		_center_in_rect(str(card.title), Rect2(rect.position + Vector2(15, 104), Vector2(card_width - 30, 72)), 22, tint)
		_center_in_rect(str(card.text), Rect2(rect.position + Vector2(20, 176), Vector2(card_width - 40, 96)), 16, Color("#eee5d5"))

		## And which of your skills it lands on, as glyphs, with the untouched
		## ones dim. A card that touches no skill says what it does touch —
		## four dark glyphs reads as "affects nothing".
		var hit: Array = card.get("affects", [])
		var row_y: float = rect.position.y + rect.size.y - 44.0
		if game.skills.is_empty() or hit.is_empty():
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
	_center_text(title, 92.0, 52, tint)
	var report: String = game.run_report()
	var lines := report.split("
")
	var y := 150.0
	for i in lines.size():
		var line: String = lines[i]
		var small := line.begins_with("  ")
		draw_string(font, Vector2(size.x * 0.5 - 340.0, y), line,
			HORIZONTAL_ALIGNMENT_LEFT, 680, 15 if small else 17,
			Color("#b9afaa") if small else Color("#eee5d5"))
		y += 20.0 if small else 23.0
	y += 18.0
	_center_text("C to copy the report · Enter to return to title", y, 18, Color("#37f0c8"))


func _draw_bar(rect: Rect2, ratio: float, color: Color, label: String) -> void:
	draw_rect(rect, Color("#241b25"))
	draw_rect(Rect2(rect.position, Vector2(rect.size.x * clampf(ratio, 0.0, 1.0), rect.size.y)), color)
	draw_rect(rect, Color("#e8c376"), false, 1.0)
	draw_string(font, rect.position + Vector2(4, -4), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#eee5d5"))

func _center_text(text: String, y: float, font_size: int, color: Color) -> void:
	draw_string(font, Vector2(0, y), text, HORIZONTAL_ALIGNMENT_CENTER, size.x, font_size, color)

func _center_in_rect(text: String, rect: Rect2, font_size: int, color: Color) -> void:
	draw_string(font, rect.position + Vector2(0, font_size), text, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, font_size, color)

