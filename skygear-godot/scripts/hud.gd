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
			_draw_overlay("PAUSED", "Esc / P to return to the deck")
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
	_center_text("Every weapon is a shape crossed with an element.", 166.0, 18, Color("#b9afaa"))
	var card_width := 280.0
	var gap := 28.0
	var start_x := (size.x - (card_width * 3.0 + gap * 2.0)) * 0.5
	for i in mini(3, game.draft_options.size()):
		var card: Dictionary = game.draft_options[i]
		var rect := Rect2(start_x + i * (card_width + gap), 220, card_width, 300)
		draw_rect(rect, Color(0.08, 0.06, 0.09, 0.98))
		draw_rect(rect, Color("#b0813f"), false, 3.0)
		_center_in_rect(str(i + 1), Rect2(rect.position + Vector2(0, 24), Vector2(card_width, 35)), 24, Color("#ffe08a"))
		_center_in_rect(str(card.title), Rect2(rect.position + Vector2(15, 88), Vector2(card_width - 30, 72)), 22, card.color)
		_center_in_rect(str(card.text), Rect2(rect.position + Vector2(20, 185), Vector2(card_width - 40, 72)), 16, Color("#eee5d5"))

func _draw_overlay(title: String, subtitle: String) -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.015, 0.028, 0.86))
	_center_text(title, 260.0, 52, Color("#e8c376"))
	var lines := subtitle.split("\n")
	for i in lines.size():
		_center_text(lines[i], 330.0 + i * 34.0, 22, Color("#eee5d5"))

func _draw_bar(rect: Rect2, ratio: float, color: Color, label: String) -> void:
	draw_rect(rect, Color("#241b25"))
	draw_rect(Rect2(rect.position, Vector2(rect.size.x * clampf(ratio, 0.0, 1.0), rect.size.y)), color)
	draw_rect(rect, Color("#e8c376"), false, 1.0)
	draw_string(font, rect.position + Vector2(4, -4), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#eee5d5"))

func _center_text(text: String, y: float, font_size: int, color: Color) -> void:
	draw_string(font, Vector2(0, y), text, HORIZONTAL_ALIGNMENT_CENTER, size.x, font_size, color)

func _center_in_rect(text: String, rect: Rect2, font_size: int, color: Color) -> void:
	draw_string(font, rect.position + Vector2(0, font_size), text, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, font_size, color)

