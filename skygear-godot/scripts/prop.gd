class_name SkyGearProp
extends Node2D

var game: Node
var prop_type := "keg"
var hp := 1.0
var max_hp := 1.0
var radius := 25.0
var fuse_left := -1.0
var dead := false

const TEXTURES := {
	"keg": "res://assets/art/props/barrel.png",
	"crate": "res://assets/art/props/crate_small.png",
	"lantern": "res://assets/art/props/lantern_post.png",
}

const SCALES := {
	"keg": 0.19,
	"crate": 0.19,
	"lantern": 0.14,
}

func configure(owner_game: Node, kind: String) -> void:
	game = owner_game
	prop_type = kind
	match prop_type:
		"keg":
			max_hp = 34.0
			radius = 25.0
		"crate":
			max_hp = 26.0
			radius = 30.0
		"lantern":
			max_hp = 12.0
			radius = 18.0
	hp = max_hp
	$Sprite.texture = load(TEXTURES[prop_type])
	$Sprite.scale = Vector2.ONE * float(SCALES[prop_type])
	$Sprite.position.y = -34.0 if prop_type == "lantern" else -24.0
	add_to_group("props")
	queue_redraw()

func _process(delta: float) -> void:
	if fuse_left >= 0.0 and not dead:
		fuse_left -= delta
		if fuse_left <= 0.0:
			dead = true
			game.explode_keg(self)
			queue_free()
		queue_redraw()

func damage(amount: float) -> void:
	if dead or fuse_left >= 0.0 or amount <= 0.0:
		return
	hp -= amount
	if hp <= 0.0:
		if prop_type == "keg":
			fuse_left = 0.45
			game.play_sfx("prop/keg_fuse.ogg", -4.0)
		else:
			dead = true
			game.on_prop_destroyed(self)
			queue_free()
	queue_redraw()

func light_fuse() -> void:
	if prop_type == "keg" and not dead and fuse_left < 0.0:
		hp = 0.0
		fuse_left = 0.45
		game.play_sfx("prop/keg_fuse.ogg", -4.0)
		queue_redraw()

func is_targetable() -> bool:
	return not dead

func _draw() -> void:
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 28, Color(0.05, 0.03, 0.04, 0.7), 2.0)
	if fuse_left >= 0.0:
		var pulse := 0.55 + 0.45 * sin(Time.get_ticks_msec() * 0.035)
		draw_arc(Vector2.ZERO, 175.0, 0.0, TAU, 56, Color(1.0, 0.58, 0.18, pulse), 5.0)
		draw_circle(Vector2(0, -45), 7.0 + pulse * 3.0, Color("#ffe08a"))
	elif hp < max_hp:
		draw_rect(Rect2(-radius, -radius - 12, radius * 2.0, 4), Color("#28131a"))
		draw_rect(Rect2(-radius, -radius - 12, radius * 2.0 * hp / max_hp, 4), Color("#e8c376"))

