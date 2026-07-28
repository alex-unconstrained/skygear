class_name SkyGearView3D
extends Node3D

## The three-quarter view, in actual 3D.
##
## THIS IS A CORRECTION. The port rendered the deck as a flat overhead 2D scene,
## and the browser build it is porting has never been that: it hand-writes a
## perspective camera in Canvas 2D — height 760 above the deck, pitched 0.72 rad
## (41°), focal length 1320, dividing by depth — and paints every character as an
## upright billboard standing in it. `docs/LEVEL-KIT-BRIEF.md` calls the camera
## settled and locked, and every sprite in `assets/` was generated for it: figures
## painted 10–15° above horizontal so they read as standing on a deck seen from
## 41°, not as lying on it.
##
## Rendering that art straight down was showing the right pictures through the
## wrong camera. It is also the one thing an engine should not have to fake, and
## faking it was the browser's constraint, not ours.
##
## So: a real Camera3D at the same pitch, a real ground plane, and Sprite3D
## billboards. The simulation is untouched — it still runs in ground-plane
## coordinates in the 2D scene, and every one of the 44 parity checks still
## drives it directly. This node only mirrors that state into a 3D scene each
## frame. Ground (x, y) becomes world (x, 0, y); y is depth, exactly as in the
## browser's TUNING comment.

const PITCH := 0.72                 ## radians below horizontal. Locked. See the brief.
## Framing, tuned by looking at it. The browser's own numbers (760 above, 460
## behind) put the near edge of the deck in the middle of the screen and left
## the bottom 40% empty, because its camera is not free — it is a projection
## with a principal point at 0.60 of screen height doing the same job. Lower and
## closer gives the same composition here: deck to the bottom edge, captain
## sitting just below centre, and enough of the bow visible to see what is
## coming.
const CAM_HEIGHT := 470.0           ## ground units above the deck
## How far AHEAD of the captain the camera looks, toward the bow. The browser
## does this with `camBack`, for the same reason: aim at her and she sits in the
## middle of the frame with half the screen showing deck she has already crossed.
## Aim up-deck and she sits below centre with the boarders in front of her.
const CAM_LOOK_AHEAD := 260.0
const WORLD_SCALE := 0.01           ## ground units -> metres, so Godot's units stay sane

@export var game_path: NodePath = ^"SkyGear"

var game: SkyGearGame
var camera: Camera3D
var deck: MeshInstance3D
var _billboards: Dictionary = {}     ## key -> Sprite3D
var _used: Dictionary = {}
var _textures: Dictionary = {}


func _ready() -> void:
	game = get_node_or_null(game_path)
	_build_world()
	if game != null:
		# the 2D scene keeps simulating; it just stops being what you look at
		game.visible = false


func _build_world() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("#17152a")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("#4a4560")
	e.ambient_light_energy = 0.9
	e.fog_enabled = true
	e.fog_light_color = Color("#241f3a")
	e.fog_density = 0.006
	env.environment = e
	add_child(env)

	## Two sources, the same two the art is painted for: a steel-blue moon rim
	## from the upper left and a warm lantern fill from the lower right.
	var moon := DirectionalLight3D.new()
	moon.light_color = Color("#8fa6c9")
	moon.light_energy = 1.15
	moon.rotation_degrees = Vector3(-52, 34, 0)
	moon.shadow_enabled = true
	add_child(moon)
	var lantern := DirectionalLight3D.new()
	lantern.light_color = Color("#ffb347")
	lantern.light_energy = 0.55
	lantern.rotation_degrees = Vector3(-28, -150, 0)
	add_child(lantern)

	deck = MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(SkyGearGame.DECK_RECT.size.x, SkyGearGame.DECK_RECT.size.y) * WORLD_SCALE
	deck.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("#3d2e30")
	mat.roughness = 0.92
	deck.material_override = mat
	deck.position = Vector3(
		(SkyGearGame.DECK_RECT.position.x + SkyGearGame.DECK_RECT.size.x * 0.5) * WORLD_SCALE,
		0.0,
		(SkyGearGame.DECK_RECT.position.y + SkyGearGame.DECK_RECT.size.y * 0.5) * WORLD_SCALE)
	add_child(deck)

	# the cargo runs, as actual boxes — they are what a lane is made of
	for rect in SkyGearGame.CARGO_RECTS:
		var box := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(rect.size.x, 150.0, rect.size.y) * WORLD_SCALE
		box.mesh = mesh
		var bm := StandardMaterial3D.new()
		bm.albedo_color = Color("#54413c")
		bm.roughness = 0.95
		box.material_override = bm
		box.position = Vector3((rect.position.x + rect.size.x * 0.5) * WORLD_SCALE,
			75.0 * WORLD_SCALE, (rect.position.y + rect.size.y * 0.5) * WORLD_SCALE)
		add_child(box)

	## The gunwale. Without it the deck is a rectangle that stops, and at
	## altitude the thing you most need to read is where the edge is.
	var rail_mat := StandardMaterial3D.new()
	rail_mat.albedo_color = Color("#b0813f")
	rail_mat.roughness = 0.6
	rail_mat.metallic = 0.4
	for side in [-1.0, 1.0]:
		var rail := MeshInstance3D.new()
		var rm := BoxMesh.new()
		rm.size = Vector3(14.0, 40.0, SkyGearGame.DECK_RECT.size.y) * WORLD_SCALE
		rail.mesh = rm
		rail.material_override = rail_mat
		rail.position = Vector3(
			(SkyGearGame.DECK_RECT.position.x + (0.0 if side < 0.0 else SkyGearGame.DECK_RECT.size.x)) * WORLD_SCALE,
			20.0 * WORLD_SCALE,
			(SkyGearGame.DECK_RECT.position.y + SkyGearGame.DECK_RECT.size.y * 0.5) * WORLD_SCALE)
		add_child(rail)
	for end_z in [SkyGearGame.DECK_RECT.position.y, SkyGearGame.DECK_RECT.end.y]:
		var cap := MeshInstance3D.new()
		var cm := BoxMesh.new()
		cm.size = Vector3(SkyGearGame.DECK_RECT.size.x, 40.0, 14.0) * WORLD_SCALE
		cap.mesh = cm
		cap.material_override = rail_mat
		cap.position = Vector3(
			(SkyGearGame.DECK_RECT.position.x + SkyGearGame.DECK_RECT.size.x * 0.5) * WORLD_SCALE,
			20.0 * WORLD_SCALE, end_z * WORLD_SCALE)
		add_child(cap)

	## The hull below the deck, so the ship has a bottom and the frame does not
	## end in void where the planking stops.
	var hull := MeshInstance3D.new()
	var hm := BoxMesh.new()
	hm.size = Vector3(SkyGearGame.DECK_RECT.size.x * 0.94, 300.0,
		SkyGearGame.DECK_RECT.size.y * 0.98) * WORLD_SCALE
	hull.mesh = hm
	var hull_mat := StandardMaterial3D.new()
	hull_mat.albedo_color = Color("#241b25")
	hull.material_override = hull_mat
	hull.position = Vector3(
		(SkyGearGame.DECK_RECT.position.x + SkyGearGame.DECK_RECT.size.x * 0.5) * WORLD_SCALE,
		-152.0 * WORLD_SCALE,
		(SkyGearGame.DECK_RECT.position.y + SkyGearGame.DECK_RECT.size.y * 0.5) * WORLD_SCALE)
	add_child(hull)

	## A cloud sea far below and behind, so the void reads as ten thousand feet
	## rather than as nothing. It is the cheapest possible version of the
	## browser's parallax bands and it does the same job: something is down there.
	var clouds := MeshInstance3D.new()
	var cp := PlaneMesh.new()
	cp.size = Vector2(14000.0, 14000.0) * WORLD_SCALE
	clouds.mesh = cp
	var cmat := StandardMaterial3D.new()
	cmat.albedo_color = Color("#2e2a4e")
	cmat.roughness = 1.0
	clouds.material_override = cmat
	clouds.position = Vector3(0.0, -900.0 * WORLD_SCALE,
		(SkyGearGame.DECK_RECT.position.y + SkyGearGame.DECK_RECT.size.y * 0.5) * WORLD_SCALE)
	add_child(clouds)

	camera = Camera3D.new()
	camera.fov = 52.0
	camera.current = true
	add_child(camera)


func _process(_delta: float) -> void:
	if game == null:
		return
	_track_camera()
	_used.clear()
	_sync_all()
	# anything not claimed this frame is gone from the simulation
	for key in _billboards.keys():
		if not _used.has(key):
			var node: Sprite3D = _billboards[key]
			node.queue_free()
			_billboards.erase(key)


## The camera sits behind and above the captain and looks down the pitch. Framing
## matches the browser: she rides a little below centre so the deck she is
## walking into is the part you can see.
func _track_camera() -> void:
	var focus: Vector2 = game.player.global_position if game.player != null else Vector2.ZERO
	focus.y -= CAM_LOOK_AHEAD          # -y is the bow; that is where the fight is
	var height := CAM_HEIGHT * WORLD_SCALE
	var back := height / tan(PITCH)
	var target := Vector3(focus.x * WORLD_SCALE, 0.0, focus.y * WORLD_SCALE)
	camera.position = target + Vector3(0.0, height, back)
	camera.rotation = Vector3(-PITCH, 0.0, 0.0)


func _sync_all() -> void:
	if game.player != null and game.player.hp > 0.0:
		_place("player", _player_texture(), game.player.global_position, 150.0)
	for enemy in game.get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or enemy.dead:
			continue
		var config: Dictionary = SkyGearData.ENEMIES.get(enemy.kind, {})
		var height := 120.0 + float(config.get("radius", 22.0)) * 3.0
		_place("e%d" % enemy.get_instance_id(), _texture(str(config.get("texture", ""))),
			enemy.global_position, height)
	for prop in game.get_tree().get_nodes_in_group("props"):
		if not is_instance_valid(prop) or prop.dead:
			continue
		_place("p%d" % prop.get_instance_id(), _texture(prop.texture_path()),
			prop.global_position, 110.0)
	for i in game.crew.size():
		var c: Dictionary = game.crew[i]
		if bool(c.dead):
			continue
		_place("c%d" % i, _texture("res://assets/art/allies/crew_front_idle.png"),
			c.position, 110.0)
	for i in game.turrets.size():
		var t: Dictionary = game.turrets[i]
		var art := "res://assets/art/props/cannon_deck_destroyed.png" if bool(t.dead) \
			else "res://assets/art/props/cannon_deck.png"
		_place("t%d" % i, _texture(art), t.position, 130.0)
	if not game.hulk.is_empty() and not bool(game.hulk.dead):
		_place("hulk", _texture("res://assets/art/props/boarding_hulk_open.png"),
			game.hulk.position, 420.0)


## One billboard per entity, pooled. `BILLBOARD_ENABLED` is what makes a flat
## sprite stand up and face the camera — which is exactly what the browser's
## renderer does by hand, and what the art is painted for.
func _place(key: String, texture: Texture2D, ground: Vector2, height_units: float) -> void:
	if texture == null:
		return
	_used[key] = true
	var node: Sprite3D = _billboards.get(key)
	if node == null:
		node = Sprite3D.new()
		node.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		node.shaded = true
		node.double_sided = true
		node.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		node.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		add_child(node)
		_billboards[key] = node
	node.texture = texture
	# scale so the sprite stands `height_units` tall in ground units, and lift it
	# by half of that so its feet meet the deck rather than its middle
	var pixel_height: float = maxf(1.0, float(texture.get_height()))
	node.pixel_size = height_units * WORLD_SCALE / pixel_height
	node.position = Vector3(ground.x * WORLD_SCALE,
		height_units * WORLD_SCALE * 0.5, ground.y * WORLD_SCALE)


func _texture(path: String) -> Texture2D:
	if path == "":
		return null
	if _textures.has(path):
		return _textures[path]
	if not ResourceLoader.exists(path):
		_textures[path] = null
		return null
	var tex: Texture2D = load(path)
	_textures[path] = tex
	return tex


func _player_texture() -> Texture2D:
	var sprite := game.player.get_node_or_null("Sprite") as Sprite2D
	if sprite != null and sprite.texture != null:
		return sprite.texture
	return _texture("res://assets/art/heroes/corsair_front_idle.png")
