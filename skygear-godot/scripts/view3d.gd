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

## --- the camera, solved from the browser's own numbers -----------------------
## An earlier version of this file guessed at framing ("lower and closer gives
## the same composition") and it did not: it put the cargo runs in the lens as
## black slabs and cropped the deck to a corridor. The browser is not doing
## anything mysterious, so there is nothing to guess at — its `CAM` is a pinhole
## with four constants and one solve, and all of it ports exactly.
const PITCH := 0.72                 ## radians below horizontal. Locked. See the brief.
const CAM_HEIGHT := 760.0           ## ground units above the deck  (browser: CAM.h)
const CAM_NEAR := 460.0             ## camera to focus point, along the deck (CAM.near)
const FOCAL := 1320.0               ## focal length at reference scale  (CAM.f)
const REF_HEIGHT := 860.0           ## the height that focal length is quoted at
const STAND_FRAC := 0.60            ## where the captain sits, as a fraction of screen
const CAM_TAU := 0.155              ## follow smoothing, seconds  (FEEL.camTau)
const WORLD_SCALE := 0.01           ## ground units -> metres, so Godot's units stay sane

## Cargo modules are tiled down a run rather than stretched over a box, which is
## what the browser does and the reason its crates read as lashed cargo instead
## of as a wall with a picture on it.
## Visual layers. Layer 1 is the ship; layer 2 is anybody standing on it.
##
## Decals project onto whatever geometry is inside their box, which is the whole
## point of them — and the captain, the crew and every boarder are inside those
## boxes. A mortar ring was being painted across her chest, the aura washed the
## crew to cream, and every contact shadow darkened the person standing on it.
## Splitting the layers is the fix: a ring belongs on the deck.
const LAYER_WORLD := 1
const LAYER_FIGURES := 2
## Contact shadows get their own layer so the effect decals do not project onto
## them — a mortar ring painted across a boarder's shadow is a ring that looks
## like it is on the deck twice.
const LAYER_SHADOWS := 4

## How tall each prop stands, in ground units. The browser's `PROP_H`.
const PROP_HEIGHT := {
	"keg": 100.0, "crate": 84.0, "crates": 148.0, "rope": 30.0, "lantern": 200.0,
	"brazier": 116.0, "mast": 340.0, "railing": 52.0, "hatch": 44.0,
	"ballista": 118.0, "vent": 52.0, "wreck": 210.0,
}

const WALL_MODULE_D := 100.0
const WALL_MODULE_H := 125.0

## THE AIRSTREAM (F-03) and THE SWAY (F-04).
##
## Both were reported against the browser build and both are still open there.
## The port had the airstream ported into `game.gd` and then hid the scene that
## drew it, so what actually shipped was nothing at all.
##
## Rebuilt here as what it always wanted to be: streaks in the air travelling
## past the camera, at the camera's own height, rather than lines drawn on a
## flat picture of a deck. The tester asked what they were supposed to look at to
## see the ship was flying, and the answer has to be something between them and
## the deck, moving.
## Tuned down hard from the first pass. Seventy-two ribbons at 0.4 additive were
## not air, they were fog: milky bands washing across the deck and the fight.
## Air you are moving through is a thing you notice in motion and barely see in a
## still, which is the right target for a still.
const STREAK_COUNT := 48
const STREAK_SPEED := 1450.0        ## ground units per second, toward the stern
const STREAK_DEPTH := 3000.0        ## the volume they live in, ahead of the camera
const STREAK_SPREAD := 1500.0       ## and across it

## And the sway. Reported as "very subtle, player didn't notice much even after
## being told" — because in 2D it could only ever be a small parallax nudge. A
## real camera can roll the horizon, which is what standing on a ship feels
## like, and one degree of roll is unmistakable where ten pixels of drift is not.
const SWAY_ROLL := 0.85             ## degrees
const SWAY_YAW := 0.42
const SWAY_HEAVE := 26.0            ## ground units, vertical

@export var game_path: NodePath = ^"SkyGear"

var game: SkyGearGame
var camera: Camera3D
var deck: MeshInstance3D
var _billboards: Dictionary = {}     ## key -> Sprite3D
var _used: Dictionary = {}
var _textures: Dictionary = {}
var _decals: Dictionary = {}         ## key -> Decal, projected onto the deck
var _volumes: Dictionary = {}        ## key -> MeshInstance3D, the aura cylinders
var _decals_used: Dictionary = {}
var _lights: Dictionary = {}         ## prop id -> OmniLight3D
var _envelope: MeshInstance3D
var _focus := Vector2.ZERO
var _focus_set := false
var _flicker := 0.0
var _made: Dictionary = {}           ## generated textures, by key
var _cloud_bands: Array[Dictionary] = []
var _sparks: Dictionary = {}          ## element -> GPUParticles3D
var _flashes: Array[OmniLight3D] = []
var _flash_next := 0
var _impact_rng := RandomNumberGenerator.new()
var _shadow_batch: MultiMeshInstance3D
var _shadow_at: PackedVector2Array = PackedVector2Array()
var _shadow_size: PackedFloat32Array = PackedFloat32Array()
var _shadow_alpha: PackedFloat32Array = PackedFloat32Array()
var _shadow_count := 0
var _warmup := SkyGearWarmup.new()
var _warm_frames := 0
## The actual free lists. `_billboards` and `_decals` hold what is IN USE this
## frame; these hold what has been returned and is waiting to be claimed again.
var _free_billboards: Array[Sprite3D] = []
var _free_decals: Array[Decal] = []
var _peak_decals := 0
var _peak_billboards := 0
var _rigs: Dictionary = {}            ## key -> SkyGearRig3D, for anything with a model
var _no_model: Dictionary = {}        ## kinds we have already looked for and not found
var _stream: Array[MeshInstance3D] = []
var _stream_v: PackedFloat32Array = PackedFloat32Array()
var _stream_len: PackedFloat32Array = PackedFloat32Array()   ## length, width, per streak
var _roll := 0.0
var _yaw := 0.0
## Off for the harness. A camera that is deliberately never still cannot also be
## the thing a framing check measures against, and the check is measuring the
## framing the sway moves AROUND.
var sway := true


func _ready() -> void:
	game = get_node_or_null(game_path)
	_build_world()
	if game != null:
		# the 2D scene keeps simulating; it just stops being what you look at
		game.visible = false
		# the HUD still draws over the fight, so it needs the lens we are using
		if game.hud != null:
			game.hud.view = self
		game.view = self


## How far behind the captain the focus point sits, so she lands at STAND_FRAC.
## Straight out of `CAM.recompute()`: the browser solves this rather than tuning
## it, because a hard-coded offset silently re-frames the whole fight the moment
## the pitch or the focal length moves.
static func camera_back() -> float:
	var r: float = (0.5 - STAND_FRAC) * REF_HEIGHT / FOCAL
	var den: float = sin(PITCH) - r * cos(PITCH)
	if absf(den) < 1e-4:
		return CAM_NEAR + 200.0
	return clampf(CAM_HEIGHT * (r * sin(PITCH) + cos(PITCH)) / den - CAM_NEAR, -260.0, 900.0)


func _build_world() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	## A real sky, because the top of the frame is where the horizon is and a
	## flat clear colour reads as a void rather than as altitude at dusk.
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("#100e1c")
	sky_mat.sky_horizon_color = Color("#2e2a4e")
	sky_mat.ground_bottom_color = Color("#1b1830")
	sky_mat.ground_horizon_color = Color("#3a3358")
	sky_mat.sun_angle_max = 30.0
	var sky_res := Sky.new()
	sky_res.sky_material = sky_mat
	e.background_mode = Environment.BG_SKY
	e.sky = sky_res
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("#4a4058")
	e.ambient_light_energy = 0.62
	e.fog_enabled = true
	e.fog_light_color = Color("#1d1930")
	e.fog_density = 0.011
	## Bloom. The browser fakes every glow by hand with radial gradients — the
	## lantern haze, the furnace mouth, the rim on a cleave — because Canvas 2D
	## has no post chain. Here it is one flag, and without it the emissive
	## surfaces read as flat orange paint rather than as light.
	e.glow_enabled = true
	e.glow_intensity = 0.32
	e.glow_bloom = 0.06
	e.glow_hdr_threshold = 1.05
	e.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	## Contact shadowing in the creases of the cargo, which is most of what makes
	## a box look like an object rather than a shape.
	e.ssao_enabled = true
	e.ssao_intensity = 1.6
	e.ssao_radius = 0.6
	## A1. THERE WAS NO TONEMAPPER, so the environment ran Linear and everything
	## above 1.0 hard-clipped to white — while this renderer deliberately pushes
	## above 1.0 everywhere: effect tints at 1.45x, impact particles at 1.7x, the
	## furnace emission at 2.6x, a glow threshold of 1.05. Every one of those was
	## clipping to white at exactly the moment it was meant to carry an element's
	## colour, which is the one job it had.
	##
	## Filmic rather than AgX: AgX desaturates hard in the highlights and this
	## palette is carrying information in the hue of a bright ring.
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.tonemap_exposure = 1.0
	e.tonemap_white = 6.0
	e.adjustment_enabled = true
	e.adjustment_contrast = 1.10
	e.adjustment_saturation = 1.04
	env.environment = e
	add_child(env)

	## Two sources, the same two the art is painted for: a steel-blue moon rim
	## from the upper left and a warm lantern fill from the lower right.
	var moon := DirectionalLight3D.new()
	moon.light_color = Color("#8fa6c9")
	moon.light_energy = 1.45
	moon.rotation_degrees = Vector3(-52, 34, 0)
	moon.shadow_enabled = true
	moon.shadow_blur = 2.2
	## 60 metres was roughly double the visible deck (16.8 x 23.2). Tightening it
	## to the deck plus a margin nearly doubles the effective shadow resolution
	## for nothing.
	moon.directional_shadow_max_distance = 34.0
	moon.shadow_opacity = 0.72
	add_child(moon)
	var lantern := DirectionalLight3D.new()
	lantern.light_color = Color("#ffb347")
	lantern.light_energy = 0.38
	lantern.rotation_degrees = Vector3(-28, -150, 0)
	add_child(lantern)
	_moon = moon
	_lantern = lantern
	_moon_energy = moon.light_energy
	_lantern_energy = lantern.light_energy
	_ambient_energy = e.ambient_light_energy
	_environment = e

	deck = MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(SkyGearGame.DECK_RECT.size.x, SkyGearGame.DECK_RECT.size.y) * WORLD_SCALE
	deck.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = _planking_texture()
	## 1.8 tiles across 1680 units puts a board at roughly 116 wide, which is the
	## browser's own plank width; 2.9 down 2320 puts a butt joint every ~400.
	mat.uv1_scale = Vector3(1.8, 7.0, 1.0)
	mat.roughness = 0.86
	## Anisotropy, for the same reason: a plank run receding to the bow is the
	## textbook case where trilinear alone turns detail into mush.
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	deck.material_override = mat
	deck.position = Vector3(
		(SkyGearGame.DECK_RECT.position.x + SkyGearGame.DECK_RECT.size.x * 0.5) * WORLD_SCALE,
		0.0,
		(SkyGearGame.DECK_RECT.position.y + SkyGearGame.DECK_RECT.size.y * 0.5) * WORLD_SCALE)
	add_child(deck)

	_build_cargo()

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
	## rather than as nothing.
	var clouds := MeshInstance3D.new()
	var cp := PlaneMesh.new()
	cp.size = Vector2(14000.0, 14000.0) * WORLD_SCALE
	clouds.mesh = cp
	var cmat := StandardMaterial3D.new()
	cmat.albedo_color = Color("#2e2a4e")
	cmat.roughness = 1.0
	clouds.material_override = cmat
	clouds.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	clouds.position = Vector3(0.0, -900.0 * WORLD_SCALE,
		(SkyGearGame.DECK_RECT.position.y + SkyGearGame.DECK_RECT.size.y * 0.5) * WORLD_SCALE)
	add_child(clouds)

	## And the painted bands on top of it. `clouds_far` and `clouds_near` are two
	## of the nineteen art files nothing referenced; in the browser they are the
	## parallax that says the ship is moving, and here they can be objects at two
	## real distances and parallax for free. They drift, at speeds the browser
	## settled on: 16 and 34 units a second.
	for band in [
		{"art": "res://assets/art/env/clouds_far.png", "z": -5200.0, "y": -520.0,
			"w": 11000.0, "h": 2750.0, "speed": 16.0, "alpha": 0.55},
		{"art": "res://assets/art/env/clouds_near.png", "z": -3000.0, "y": -760.0,
			"w": 7600.0, "h": 1900.0, "speed": 34.0, "alpha": 0.72},
	]:
		var tex := _texture(str(band.art))
		if tex == null:
			continue
		var layer := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(float(band.w), float(band.h)) * WORLD_SCALE
		layer.mesh = q
		var m := StandardMaterial3D.new()
		m.albedo_texture = tex
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = Color(1, 1, 1, float(band.alpha))
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		layer.mesh.material = m
		layer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		layer.position = Vector3(0.0, float(band.y) * WORLD_SCALE,
			(SkyGearGame.DECK_RECT.position.y + float(band.z)) * WORLD_SCALE)
		add_child(layer)
		_cloud_bands.append({"node": layer, "speed": float(band.speed),
			"span": float(band.w) * 0.5})

	## Another ship out there, which is the cheapest possible way to say this one
	## is not the only thing in the sky.
	var far_ship := _texture("res://assets/art/env/airship_distant.png")
	if far_ship != null:
		var other := MeshInstance3D.new()
		var oq := QuadMesh.new()
		oq.size = Vector2(1700.0, 850.0) * WORLD_SCALE
		other.mesh = oq
		var om := StandardMaterial3D.new()
		om.albedo_texture = far_ship
		om.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		om.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		om.albedo_color = Color(1, 1, 1, 0.8)
		om.cull_mode = BaseMaterial3D.CULL_DISABLED
		other.mesh.material = om
		other.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		other.position = Vector3(1900.0 * WORLD_SCALE, 420.0 * WORLD_SCALE,
			(SkyGearGame.DECK_RECT.position.y - 4200.0) * WORLD_SCALE)
		add_child(other)

	## The sky, the envelope and the bow: the three pieces that say "airship"
	## rather than "arena". All three exist as painted art already; in the
	## browser they are screen-space layers, and here they can simply be objects
	## in the world at the right distance, which is cheaper and parallaxes for
	## free.
	var sky_tex := _texture("res://assets/art/env/sky_backdrop.png")
	if sky_tex != null:
		var sky := MeshInstance3D.new()
		var sq := QuadMesh.new()
		sq.size = Vector2(9000.0, 4500.0) * WORLD_SCALE
		sky.mesh = sq
		var sm := StandardMaterial3D.new()
		sm.albedo_texture = sky_tex
		sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		sm.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
		sm.cull_mode = BaseMaterial3D.CULL_DISABLED
		sky.mesh.material = sm
		sky.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		sky.position = Vector3(0.0, 900.0 * WORLD_SCALE,
			(SkyGearGame.DECK_RECT.position.y - 3600.0) * WORLD_SCALE)
		add_child(sky)

	var bow_tex := _texture("res://assets/art/env/bow_prow.png")
	if bow_tex != null:
		var bow := Sprite3D.new()
		bow.texture = bow_tex
		bow.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		bow.shaded = true
		bow.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		bow.pixel_size = 900.0 * WORLD_SCALE / float(bow_tex.get_height())
		bow.rotation_degrees = Vector3(-90.0 + rad_to_deg(PITCH) * 0.35, 0.0, 0.0)
		bow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		bow.position = Vector3(0.0, 120.0 * WORLD_SCALE,
			(SkyGearGame.DECK_RECT.position.y - 150.0) * WORLD_SCALE)
		add_child(bow)

	## Our own gas bag, overhead. Tied to the camera rather than the world so it
	## stays where a thing hanging above you stays — and kept thin, because the
	## browser build was reported for exactly this: the envelope was covering the
	## top third of the frame, which is the direction boarders arrive from.
	var env_tex := _texture("res://assets/art/env/envelope_top.png")
	if env_tex != null:
		_envelope = MeshInstance3D.new()
		var eq := QuadMesh.new()
		eq.size = Vector2(3600.0, 1100.0) * WORLD_SCALE
		_envelope.mesh = eq
		var em := StandardMaterial3D.new()
		em.albedo_texture = env_tex
		em.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		em.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		em.albedo_color = Color(1, 1, 1, 0.85)
		em.cull_mode = BaseMaterial3D.CULL_DISABLED
		_envelope.mesh.material = em
		_envelope.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_envelope)

	_build_boiler()

	_build_airstream()
	_build_impacts()
	_shadow_at.resize(SHADOW_CAP)
	_shadow_size.resize(SHADOW_CAP)
	_shadow_alpha.resize(SHADOW_CAP)
	_build_shadows()
	## A4. Build every generated texture NOW rather than the first time it is
	## drawn. `_glow_map` runs a per-pixel GDScript loop and `_fan_texture` runs
	## atan2 and exp per pixel — the first cone cast was paying for a 128x128
	## texture mid-fight, which is a hitch at the exact moment the player is
	## reacting to something.
	_ring_texture()
	_streak_texture()
	_blob_texture()
	_spark_texture()
	_crate_texture()
	_grille_texture()
	_wall_texture()
	for arc in [0.9, 1.134, 1.658, 1.7, 2.443]:
		_fan_texture(arc, true)
		_fan_texture(arc, false)
	for key in PAINTED.keys():
		var painted := _texture(str(PAINTED[key]))
		if painted != null:
			_glow_map(painted)
	_glow_map(_ring_texture())
	_glow_map(_streak_texture())

	camera = Camera3D.new()
	## Not a taste dial. The browser's focal length is 1320 quoted against a
	## reference height of 860, so its vertical field of view is
	## 2·atan(430/1320) — about 36° — at every window size. Godot's `fov` is the
	## vertical one by default, so this is the same lens rather than a similar
	## one, and it is why the deck now reads to the horizon instead of the cargo
	## filling the frame.
	camera.fov = rad_to_deg(2.0 * atan((REF_HEIGHT * 0.5) / FOCAL))
	camera.near = 0.05
	camera.far = 400.0
	camera.current = true
	add_child(camera)
	_track_camera(1.0)


## Impact particles and impact light.
##
## VFX-PLAN.md items 1 and 2, REVISED after the rendering audit
## (`docs/VFX-RESEARCH-AUDIT.md` findings 3 and 4) found two real faults in the
## first version:
##
##   * **`restart()` on a shared one-shot emitter throws away the particles
##     already in flight.** Two boarders dying half a second apart meant the
##     second kill erased the first one's sparks. Every impact after the first
##     was, visually, the only impact.
##   * **`amount_ratio` does not reduce processing cost** — the capacity stays
##     allocated — so scaling it by damage bought nothing.
##
## `emit_particle` is the right API and was the answer to both: particles are
## injected individually with their own transform, velocity and colour, into a
## continuously live emitter that is never restarted. Overlapping impacts now
## overlap.
##
## And the systems are keyed by BEHAVIOUR rather than by element. Sparks fly and
## fade; steam rises and dissolves; frost shards go out hard and stop. Four
## elements share three behaviours, and the colour rides on the particle.
const SPARK_CAPACITY := 512
const FLASH_POOL := 8

## Which behaviour each element throws, and how it moves. The audit's finding 4
## is the reason this table exists at all: **coloured light is still a hue cue**,
## so it cannot be the accessibility answer on its own. Shape, direction and
## timing are the channels that survive colour blindness, and they are set here.
const ELEMENT_FX := {
	"EMBER": {"family": "spark", "rise": 40.0, "spread": 70.0, "speed": 230.0,
		"life": 0.70, "count": 14},
	"FROST": {"family": "shard", "rise": -40.0, "spread": 26.0, "speed": 420.0,
		"life": 0.28, "count": 12},
	"ARC": {"family": "spark", "rise": 10.0, "spread": 14.0, "speed": 520.0,
		"life": 0.22, "count": 10},
	"STEAM": {"family": "steam", "rise": 150.0, "spread": 88.0, "speed": 120.0,
		"life": 0.95, "count": 12},
}

func _build_impacts() -> void:
	for family in ["spark", "shard", "steam"]:
		var node := GPUParticles3D.new()
		node.amount = SPARK_CAPACITY
		node.lifetime = 1.0
		node.one_shot = false
		node.emitting = false          ## nothing auto-emits; everything is injected
		node.local_coords = false
		node.fixed_fps = 30
		node.interpolate = true
		node.preprocess = 0.0
		node.explosiveness = 0.0
		node.draw_order = GPUParticles3D.DRAW_ORDER_VIEW_DEPTH
		## An accurate box, or Godot culls the system when the emitter node is off
		## screen and the sparks vanish mid-flight.
		node.visibility_aabb = AABB(Vector3(-40, -40, -40), Vector3(80, 80, 80))
		var mesh := QuadMesh.new()
		mesh.size = Vector2(26.0 if family != "steam" else 46.0,
			26.0 if family != "steam" else 46.0) * WORLD_SCALE
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if family != "steam" \
			else BaseMaterial3D.BLEND_MODE_MIX
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		mat.vertex_color_use_as_albedo = true    ## the colour rides on the particle
		mat.albedo_texture = _art("steam" if family == "steam" else "ember",
			_spark_texture())
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mesh.material = mat
		node.draw_pass_1 = mesh
		var process := ParticleProcessMaterial.new()
		process.gravity = Vector3.ZERO         ## per-particle velocity does the work
		process.damping_min = 1.2
		process.damping_max = 3.0
		process.scale_min = 0.4
		process.scale_max = 1.0
		var curve := CurveTexture.new()
		var ramp := Curve.new()
		ramp.add_point(Vector2(0.0, 1.0))
		ramp.add_point(Vector2(1.0, 0.0))
		curve.curve = ramp
		process.scale_curve = curve
		process.alpha_curve = curve
		node.process_material = process
		node.layers = LAYER_FIGURES
		## A5. Particles do not cast. `cast_shadow` defaults ON, so three
		## 512-capacity systems were rendering into the shadow map of the one
		## shadowed light for no visible gain — the blob decals under everything
		## already carry the grounding.
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(node)
		_sparks[family] = node
		node.emitting = true

	## Eight pooled flashes, as reinforcement rather than as the cue. Shadowless
	## and with no volumetric contribution, or a fog-lit scene keeps a trail of
	## every hit for as long as the fog takes to settle.
	for i in FLASH_POOL:
		var light := OmniLight3D.new()
		light.light_energy = 0.0
		light.omni_range = 300.0 * WORLD_SCALE
		light.omni_attenuation = 1.6
		light.shadow_enabled = false
		light.light_volumetric_fog_energy = 0.0
		add_child(light)
		_flashes.append(light)


## A hit landed here, this hard, of this element.
func impact_at(ground: Vector2, element: String, damage: float) -> void:
	var spec: Dictionary = ELEMENT_FX.get(element, ELEMENT_FX.EMBER)
	var node: GPUParticles3D = _sparks.get(str(spec.family))
	var tint: Color = SkyGearData.ELEMENTS.get(element, {}).get("color", Color.WHITE)
	if node != null:
		var at := Vector3(ground.x * WORLD_SCALE, 48.0 * WORLD_SCALE,
			ground.y * WORLD_SCALE)
		var count: int = int(clampf(float(spec.count) * (0.4 + damage / 70.0),
			4.0, float(spec.count) * 2.0))
		var spread: float = deg_to_rad(float(spec.spread))
		for i in count:
			## Injected one at a time, into an emitter that is never restarted —
			## which is the whole fix. A `restart()` here would erase whatever is
			## still in the air from the last kill.
			var yaw: float = _impact_rng.randf() * TAU
			var pitch: float = _impact_rng.randf_range(0.0, spread)
			var dir := Vector3(sin(pitch) * cos(yaw), cos(pitch), sin(pitch) * sin(yaw))
			var speed: float = float(spec.speed) * _impact_rng.randf_range(0.55, 1.35)
			var velocity := dir * speed * WORLD_SCALE
			velocity.y += float(spec.rise) * WORLD_SCALE
			var scatter := Vector3(_impact_rng.randf_range(-14.0, 14.0), 0.0,
				_impact_rng.randf_range(-14.0, 14.0)) * WORLD_SCALE
			node.emit_particle(Transform3D(Basis(), at + scatter), velocity,
				Color(tint.r * 1.7, tint.g * 1.7, tint.b * 1.7, 1.0), Color.WHITE,
				GPUParticles3D.EMIT_FLAG_POSITION | GPUParticles3D.EMIT_FLAG_VELOCITY
					| GPUParticles3D.EMIT_FLAG_COLOR)
	if _flashes.is_empty():
		return
	var light: OmniLight3D = _flashes[_flash_next % _flashes.size()]
	_flash_next += 1
	light.light_color = tint
	light.light_energy = clampf(1.4 + damage / 40.0, 1.4, 5.0)
	## Timing is a channel colour blindness cannot take away. Frost snaps out,
	## Ember lingers — see `_flash_decay`.
	light.set_meta("decay", 26.0 if element == "FROST" or element == "ARC" else 8.0)
	light.position = Vector3(ground.x * WORLD_SCALE, 70.0 * WORLD_SCALE,
		ground.y * WORLD_SCALE)


## Streaks of moving air, as objects in the world. Unshaded, additive, and each
## one aligned to the direction it is travelling so it leans when the captain
## does — which is the half of F-03 the browser was missing when it was reviewed:
## constant rather than intermittent, and shearing with lateral movement so it
## says "you are moving through air" and not only "the ship is".
func _build_airstream() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = _streak_texture()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = Color(0.62, 0.74, 0.92, 0.19)
	## NOT billboarded. A billboard yaws to face the camera, which overrode the
	## heading and drew every streak as a horizontal bar across the screen —
	## precisely the one direction air rushing down a keel does not travel.
	## Instead each streak is a flat ribbon lying in the air, long axis along the
	## keel; a camera pitched 41 degrees projects that to a near-vertical line,
	## which is what the browser draws by hand.
	var rng := RandomNumberGenerator.new()
	rng.seed = 8811
	_stream_len.clear()
	for i in STREAK_COUNT:
		var node := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2.ONE
		node.mesh = quad
		node.material_override = mat
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(node)
		_stream.append(node)
		_stream_v.append(rng.randf())
		_stream_len.append(rng.randf_range(190.0, 430.0))
		_stream_len.append(rng.randf_range(1.1, 2.4))


## The cargo runs. In the browser these are `cargo_wall_module` billboards tiled
## down the run — 120 wide, stepped every 100, alternating mirror so one module
## does not read as a repeating stamp. Here they get to be a real box (which is
## what stops a boarder, and what the lane collision already assumes) with the
## module painted around it and a brass capping rail on top.
##
## The first version stretched the module texture over the box with alpha
## blending off, and since the module is a cut-out with a transparent surround,
## every crate rendered as a black slab. Cut-outs belong on billboards; a box
## gets a tiling texture, so this paints one.
func _build_cargo() -> void:
	var crate_mat := StandardMaterial3D.new()
	crate_mat.albedo_texture = _crate_texture()
	crate_mat.roughness = 0.88
	crate_mat.uv1_triplanar = true
	## One tile per 70 ground units. At 150 the module was larger than the box it
	## was on, so each run showed a single flat swatch of the middle of it.
	crate_mat.uv1_scale = Vector3(1.0, 1.0, 1.0) / (70.0 * WORLD_SCALE)
	var band_mat := StandardMaterial3D.new()
	band_mat.albedo_color = Color("#6d5227")
	band_mat.metallic = 0.45
	band_mat.roughness = 0.55
	for rect: Rect2 in SkyGearGame.CARGO_RECTS:
		var height := WALL_MODULE_H
		var box := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(rect.size.x, height, rect.size.y) * WORLD_SCALE
		box.mesh = mesh
		box.material_override = crate_mat
		box.position = Vector3((rect.position.x + rect.size.x * 0.5) * WORLD_SCALE,
			height * 0.5 * WORLD_SCALE, (rect.position.y + rect.size.y * 0.5) * WORLD_SCALE)
		add_child(box)
		## The brass capping rail. A full plate over the top face turned every
		## cargo run into a flat olive slab from this angle, which is what the
		## camera mostly sees — so it is four edge bars and the crate lids stay
		## visible between them.
		for edge in 4:
			var along_x: bool = edge < 2
			var cap := MeshInstance3D.new()
			var cm := BoxMesh.new()
			cm.size = Vector3(rect.size.x + 5.0 if along_x else 5.0, 6.0,
				5.0 if along_x else rect.size.y + 5.0) * WORLD_SCALE
			cap.mesh = cm
			var ox: float = 0.0 if along_x else (rect.size.x * 0.5) * (1.0 if edge == 2 else -1.0)
			var oz: float = 0.0 if not along_x else (rect.size.y * 0.5) * (1.0 if edge == 0 else -1.0)
			cap.material_override = band_mat
			cap.position = Vector3((rect.position.x + rect.size.x * 0.5 + ox) * WORLD_SCALE,
				(height + 2.0) * WORLD_SCALE,
				(rect.position.y + rect.size.y * 0.5 + oz) * WORLD_SCALE)
			add_child(cap)
		## The painted module, tiled down the run as decals.
		##
		## `cargo_wall_module.png` is what the browser paints its cargo with, and
		## the first 3D pass stretched it over the box with alpha off and got
		## eight black slabs. A cut-out belongs in a decal, not on a surface: the
		## alpha is respected, it wraps the box rather than facing one way, and
		## the procedural crate underneath fills whatever the module leaves bare.
		var module := _texture("res://assets/art/props/cargo_wall_module.png")
		var modules := maxi(1, int(round(rect.size.y / WALL_MODULE_D)))
		for i in modules:
			var t: float = 0.5 if modules == 1 else float(i) / float(modules - 1)
			var z: float = lerpf(rect.position.y + 34.0, rect.end.y - 34.0, t)
			if module != null:
				var skin := Decal.new()
				skin.cull_mask = 0xFFFFF & ~LAYER_FIGURES & ~LAYER_SHADOWS
				skin.texture_albedo = module
				skin.albedo_mix = 1.0
				skin.upper_fade = 0.05
				skin.lower_fade = 0.05
				skin.normal_fade = 0.0
				skin.size = Vector3(rect.size.x + 10.0, height + 30.0, WALL_MODULE_D) * WORLD_SCALE
				skin.position = Vector3((rect.position.x + rect.size.x * 0.5) * WORLD_SCALE,
					height * 0.5 * WORLD_SCALE, z * WORLD_SCALE)
				add_child(skin)
			# and a lashing strap, so the run reads as cargo rather than as wall
			var strap := MeshInstance3D.new()
			var sm2 := BoxMesh.new()
			sm2.size = Vector3(rect.size.x + 5.0, 7.0, 5.0) * WORLD_SCALE
			strap.mesh = sm2
			strap.material_override = band_mat
			strap.position = Vector3((rect.position.x + rect.size.x * 0.5) * WORLD_SCALE,
				height * 0.62 * WORLD_SCALE, z * WORLD_SCALE)
			add_child(strap)


## The Boiler, as geometry. There is no painted boiler in the manifest — the
## browser draws it procedurally — and borrowing another prop's sprite for the
## thing you lose by is worse than building it: a brass drum on a plinth with a
## furnace mouth, lit from inside.
func _build_boiler() -> void:
	var boiler := Node3D.new()
	boiler.position = Vector3(SkyGearGame.BOILER_POSITION.x * WORLD_SCALE, 0.0,
		SkyGearGame.BOILER_POSITION.y * WORLD_SCALE)
	add_child(boiler)
	var brass := StandardMaterial3D.new()
	brass.albedo_color = Color("#c9903c")
	brass.metallic = 0.5
	brass.roughness = 0.3
	var plinth := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = 84.0 * WORLD_SCALE
	pm.bottom_radius = 96.0 * WORLD_SCALE
	pm.height = 22.0 * WORLD_SCALE
	plinth.mesh = pm
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color("#4c4238")
	iron.metallic = 0.45
	iron.roughness = 0.58
	plinth.material_override = iron
	plinth.position.y = 11.0 * WORLD_SCALE
	boiler.add_child(plinth)
	## FLAT. The browser sets `boilerH` to 132 with the comment "a flat engine
	## block, not a tower", and it is not a style note: the captain spawns 130
	## units in front of this thing, so anything tall enough to be impressive is
	## tall enough to hide the player behind it for the first second of a run.
	## The first 3D pass built a 300-unit drum with a funnel and did exactly that.
	var drum := MeshInstance3D.new()
	var dm := CylinderMesh.new()
	dm.top_radius = 70.0 * WORLD_SCALE
	dm.bottom_radius = 76.0 * WORLD_SCALE
	dm.height = 84.0 * WORLD_SCALE
	drum.mesh = dm
	drum.material_override = brass
	drum.position.y = 64.0 * WORLD_SCALE
	boiler.add_child(drum)
	## A riveted lid, not a dome. The hemisphere version was a polished gold ball
	## the width of the deck sitting in the bottom of every frame — smooth
	## primitives read as toy, and the one object the player is defending is the
	## last place to put one.
	var lid := MeshInstance3D.new()
	var lm := CylinderMesh.new()
	lm.top_radius = 62.0 * WORLD_SCALE
	lm.bottom_radius = 72.0 * WORLD_SCALE
	lm.height = 16.0 * WORLD_SCALE
	lid.mesh = lm
	var lid_mat := StandardMaterial3D.new()
	lid_mat.albedo_color = Color("#5d4a33")
	lid_mat.metallic = 0.4
	lid_mat.roughness = 0.5
	lid.material_override = lid_mat
	lid.position.y = 112.0 * WORLD_SCALE
	boiler.add_child(lid)
	var rivets := StandardMaterial3D.new()
	rivets.albedo_color = Color("#c9903c")
	rivets.metallic = 0.55
	rivets.roughness = 0.34
	for r in 8:
		var a: float = TAU * float(r) / 8.0
		var rivet := MeshInstance3D.new()
		var rmesh := CylinderMesh.new()
		rmesh.top_radius = 5.0 * WORLD_SCALE
		rmesh.bottom_radius = 5.0 * WORLD_SCALE
		rmesh.height = 7.0 * WORLD_SCALE
		rivet.mesh = rmesh
		rivet.material_override = rivets
		rivet.position = Vector3(cos(a) * 52.0 * WORLD_SCALE, 122.0 * WORLD_SCALE,
			sin(a) * 52.0 * WORLD_SCALE)
		boiler.add_child(rivet)
	var valve := MeshInstance3D.new()
	var vm := TorusMesh.new()
	vm.inner_radius = 14.0 * WORLD_SCALE
	vm.outer_radius = 22.0 * WORLD_SCALE
	valve.mesh = vm
	valve.material_override = rivets
	valve.position.y = 128.0 * WORLD_SCALE
	boiler.add_child(valve)
	for band_y in [40.0, 88.0]:
		var band := MeshInstance3D.new()
		var bm := TorusMesh.new()
		bm.inner_radius = 71.0 * WORLD_SCALE
		bm.outer_radius = 78.0 * WORLD_SCALE
		band.mesh = bm
		band.material_override = iron
		band.position.y = band_y * WORLD_SCALE
		boiler.add_child(band)
	# the funnels lean AFT, away from the camera, so they never cross the fight
	for fx in [-46.0, 46.0]:
		var funnel := MeshInstance3D.new()
		var fu := CylinderMesh.new()
		fu.top_radius = 13.0 * WORLD_SCALE
		fu.bottom_radius = 17.0 * WORLD_SCALE
		fu.height = 86.0 * WORLD_SCALE
		funnel.mesh = fu
		funnel.material_override = iron
		funnel.position = Vector3(fx * WORLD_SCALE, 132.0 * WORLD_SCALE, 54.0 * WORLD_SCALE)
		funnel.rotation_degrees = Vector3(18.0, 0.0, 0.0)
		boiler.add_child(funnel)
	## The furnace face. This is the Boiler as anyone remembers it — a slatted
	## grille with fire behind it — and it has to be aimed at the camera, because
	## the camera never moves and a detail on the far side is a detail nobody
	## ever sees.
	var furnace := MeshInstance3D.new()
	var fm := QuadMesh.new()
	fm.size = Vector2(104.0, 62.0) * WORLD_SCALE
	furnace.mesh = fm
	var fire := StandardMaterial3D.new()
	fire.albedo_texture = _grille_texture()
	fire.emission_enabled = true
	fire.emission_texture = _grille_texture()
	fire.emission = Color("#ffb060")
	fire.emission_energy_multiplier = 2.6
	fire.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fire.cull_mode = BaseMaterial3D.CULL_DISABLED
	furnace.mesh.material = fire
	furnace.position = Vector3(0.0, 56.0 * WORLD_SCALE, 78.0 * WORLD_SCALE)
	furnace.rotation_degrees = Vector3(-14.0, 0.0, 0.0)
	boiler.add_child(furnace)
	# a bronze surround, so the grille is set into the drum rather than stuck on
	var bezel := MeshInstance3D.new()
	var bz := BoxMesh.new()
	bz.size = Vector3(120.0, 78.0, 12.0) * WORLD_SCALE
	bezel.mesh = bz
	var bronze := StandardMaterial3D.new()
	bronze.albedo_color = Color("#7d5a2c")
	bronze.metallic = 0.5
	bronze.roughness = 0.45
	bezel.material_override = bronze
	bezel.position = Vector3(0.0, 56.0 * WORLD_SCALE, 72.0 * WORLD_SCALE)
	boiler.add_child(bezel)
	var glow := OmniLight3D.new()
	glow.light_color = Color("#ff9a4a")
	glow.light_energy = 1.7
	glow.omni_range = 360.0 * WORLD_SCALE
	glow.position = Vector3(0.0, 60.0 * WORLD_SCALE, 96.0 * WORLD_SCALE)
	boiler.add_child(glow)


## PAINTED ART BEATS GENERATED ART.
##
## Everything below this line was being drawn with a texture written in code
## because, when the 3D view was built, nobody had gone looking for what was
## already in `assets/art/`. There is a painted ring for a player aura, a painted
## ring for an enemy one, a painted scorch, a soft shadow, an impact burst, a
## slash arc, a tesla bolt, steam and embers — nineteen files, none of them
## reachable from any script. The generated versions stay as the fallback, which
## is what they are good for.
const PAINTED := {
	"blob": "res://assets/art/ground/shadow_blob.png",
	"ring": "res://assets/art/ground/rune_player.png",
	"ring_hostile": "res://assets/art/ground/rune_enemy.png",
	"ring_filled": "res://assets/art/ground/rune_enemy_filled.png",
	"scorch": "res://assets/art/ground/decal_scorch.png",
	"oil": "res://assets/art/ground/decal_oil.png",
	"gears": "res://assets/art/ground/decal_gear_scatter.png",
	"burst": "res://assets/art/fx/burst_impact.png",
	"slash": "res://assets/art/fx/slash_arc.png",
	"bolt": "res://assets/art/fx/bolt_tesla.png",
	"steam": "res://assets/art/fx/puff_steam.png",
	"smoke": "res://assets/art/fx/puff_smoke_dark.png",
	"ember": "res://assets/art/fx/ember_particle.png",
}


## The painted version if it is on disk, otherwise the one we can always draw.
func _art(key: String, fallback: Texture2D) -> Texture2D:
	var path: String = str(PAINTED.get(key, ""))
	if path == "":
		return fallback
	var tex := _texture(path)
	return tex if tex != null else fallback


## --- generated textures ------------------------------------------------------
## Everything below is painted at startup rather than shipped as art, for the
## same reason the browser paints its deck in code: a tiling photo of wood reads
## as a floor and this has to read as a SHIP. Each one is cached by key.

## A2. Mipmaps, on everything generated.
##
## Every one of these was uploaded with `mipmaps = false` while the billboards
## asked for `TEXTURE_FILTER_LINEAR_WITH_MIPMAPS` against them, and the deck
## tiles planking 1.8 x 7.0 over a 23-metre plane seen at 41 degrees — which is
## grazing, which is the exact case mipmaps exist for. The result was shimmering
## planking and aliased rims on the telegraphs, and an aliased telegraph is a
## readability problem rather than an ugly one.
static func _with_mips(img: Image) -> ImageTexture:
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


## Planked timber.
func _planking_texture() -> ImageTexture:
	if _made.has("plank"):
		return _made.plank
	var size := 256
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	## Warmer and lighter than the browser's hex values, deliberately: those are
	## the colour of the finished pixel, and this one goes through a blue key and
	## a purple ambient before anyone sees it. Painting the browser's #3d2e30
	## here came out as grey stone tile.
	var base := Color("#5c433a")
	var dark := Color("#33262a")
	var light := Color("#856046")
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260727
	for y in size:
		for x in size:
			## Boards run along the KEEL. The plane maps u across the ship and v
			## down it, so a board is a column in this image — the first version
			## had them running athwartships, which is not how anyone has ever
			## planked a deck and read as floor tile at distance.
			var board := int(x / 32.0)
			var shade: float = 0.90 + fmod(float(board) * 0.37, 1.0) * 0.2
			var c := base * shade
			# the seam between two boards
			if x % 32 == 0:
				c = dark
			elif x % 32 == 31:
				c = c.lerp(light, 0.22)     # the lit lip of the next board over
			## Butt joints, staggered board to board — and FAINT. At full dark
			## every 128 rows they crossed the plank seams into a tile grid, and
			## a tiled deck is a floor rather than a ship.
			if (y + board * 61) % 128 < 2:
				c = c.lerp(dark, 0.28)
			# grain
			var grain := rng.randf()
			if grain < 0.06:
				c = c.lerp(dark, 0.5)
			elif grain > 0.965:
				c = c.lerp(light, 0.35)
			img.set_pixel(x, y, c)
	_made.plank = _with_mips(img)
	return _made.plank


## Lashed crate: vertical boards, an iron band top and bottom, corner plates.
## Tiles in both axes so it can go on a box triplanar without seams reading.
func _crate_texture() -> ImageTexture:
	if _made.has("crate"):
		return _made.crate
	var size := 128
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var wood := Color("#6b4c37")
	var dark := Color("#2d2128")
	var lit := Color("#9a7350")
	var band := Color("#94702f")
	var rng := RandomNumberGenerator.new()
	rng.seed = 419
	for y in size:
		for x in size:
			var c := wood
			# vertical planks, 16px, each its own shade
			var plank := int(x / 16.0)
			c = c * (0.86 + fmod(float(plank) * 0.41, 1.0) * 0.28)
			if x % 16 == 0:
				c = dark
			# iron bands across the top and bottom thirds
			if (y > 18 and y < 28) or (y > 100 and y < 110):
				c = band * (0.8 + 0.4 * float((x / 8) % 2))
			# rivets on the bands
			if ((y == 23 or y == 105) and x % 16 == 8):
				c = lit
			var n := rng.randf()
			if n < 0.07:
				c = c.lerp(dark, 0.45)
			elif n > 0.96:
				c = c.lerp(lit, 0.3)
			img.set_pixel(x, y, c)
	_made.crate = _with_mips(img)
	return _made.crate


## A soft ring, bright at the rim and hollow in the middle — the shape every
## radial ground effect in this game actually is.
func _ring_texture() -> ImageTexture:
	if _made.has("ring"):
		return _made.ring
	var size := 128
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var centre := Vector2(size, size) * 0.5
	for y in size:
		for x in size:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(centre) / (size * 0.5)
			var a := 0.0
			if d <= 1.0:
				## Mostly rim. The first version washed the inside at 0.22 alpha
				## additive, and at a mortar's radius that is a bright disc the
				## size of a lane sitting on top of the fight — the browser's
				## rings are a fill you can see through and an edge you cannot
				## miss, and the ratio is what makes them readable.
				a = 0.05 * (1.0 - d * 0.55)
				a += 1.0 * exp(-pow((d - 0.92) / 0.06, 2.0))
			img.set_pixel(x, y, Color(1, 1, 1, clampf(a, 0.0, 1.0)))
	_made.ring = _with_mips(img)
	return _made.ring


## A streak, for anything that goes from A to B: bright along the centreline,
## soft across it, faded at both ends. Beams and chains were being drawn as
## RINGS the size of their own length, which is where the two enormous blue
## hoops in the first 3D screenshot came from.
func _streak_texture() -> ImageTexture:
	if _made.has("streak"):
		return _made.streak
	var size := 128
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		var v: float = absf(float(y) / float(size - 1) - 0.5) * 2.0
		var across: float = exp(-pow(v / 0.30, 2.0))
		for x in size:
			var u := float(x) / float(size - 1)
			var ends: float = smoothstep(0.0, 0.06, u) * smoothstep(0.0, 0.06, 1.0 - u)
			img.set_pixel(x, y, Color(1, 1, 1, clampf(across * ends, 0.0, 1.0)))
	_made.streak = _with_mips(img)
	return _made.streak


## A fan, for cleaves and cones. `filled` is the difference between the two: a
## cone is a wedge of ground you are about to cook, a cleave is the rim of one.
## Cached per arc, because there are only ever a handful of distinct arcs.
func _fan_texture(arc: float, filled: bool) -> ImageTexture:
	var key := "fan%s_%d" % ["f" if filled else "r", int(arc * 24.0)]
	if _made.has(key):
		return _made[key]
	var size := 128
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := float(size) * 0.5
	var half: float = clampf(arc, 0.15, TAU) * 0.5
	for y in size:
		for x in size:
			var dx := float(x) + 0.5 - c
			var dy := float(y) + 0.5 - c
			var d := sqrt(dx * dx + dy * dy) / c
			var a := 0.0
			# the fan opens along +X of the decal, which the transform aims
			var off: float = absf(atan2(dy, dx))
			if d <= 1.0 and off <= half:
				# soften the two cut edges and the outer rim
				var edge: float = smoothstep(0.0, 0.16, (half - off) / maxf(0.001, half))
				if filled:
					a = (0.30 + 0.55 * d) * edge * smoothstep(1.0, 0.86, d)
				else:
					a = exp(-pow((d - 0.88) / 0.10, 2.0)) * edge
			img.set_pixel(x, y, Color(1, 1, 1, clampf(a, 0.0, 1.0)))
	_made[key] = _with_mips(img)
	return _made[key]


## The furnace grille: horizontal iron slats with fire behind them, hottest in
## the middle and cooling toward the edges.
func _grille_texture() -> ImageTexture:
	if _made.has("grille"):
		return _made.grille
	var w := 96
	var h := 64
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		var slat: bool = (y % 11) < 4
		for x in w:
			var u := (float(x) / float(w - 1)) * 2.0 - 1.0
			var v := (float(y) / float(h - 1)) * 2.0 - 1.0
			var heat: float = clampf(1.0 - sqrt(u * u * 0.7 + v * v * 1.1), 0.0, 1.0)
			var c := Color("#1b1418") if slat else 				Color("#ff4a12").lerp(Color("#ffe6a8"), heat * heat) * (0.35 + heat * 1.5)
			if y < 3 or y > h - 4 or x < 3 or x > w - 4:
				c = Color("#241b25")
			img.set_pixel(x, y, Color(c.r, c.g, c.b, 1.0))
	_made.grille = _with_mips(img)
	return _made.grille


## The wall of an aura: brightest at the top and bottom edges, thin in between,
## so a cylinder of it reads as a boundary rather than as a tube of fog.
func _wall_texture() -> ImageTexture:
	if _made.has("wall"):
		return _made.wall
	var w := 8
	var h := 64
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		var v := float(y) / float(h - 1)
		var a: float = exp(-pow(v / 0.16, 2.0)) * 0.9 + exp(-pow((1.0 - v) / 0.12, 2.0)) + 0.10
		for x in w:
			img.set_pixel(x, y, Color(1, 1, 1, clampf(a, 0.0, 1.0)))
	_made.wall = _with_mips(img)
	return _made.wall


## The emission map for a shape: its alpha, baked into RGB, opaque. Cached
## against the texture it came from, built once on first use.
func _glow_map(tex: Texture2D) -> Texture2D:
	var key := "glow_%d" % tex.get_instance_id()
	if _made.has(key):
		return _made[key]
	var src := tex.get_image()
	var out := Image.create(src.get_width(), src.get_height(), false, Image.FORMAT_RGBA8)
	for y in src.get_height():
		for x in src.get_width():
			var a: float = src.get_pixel(x, y).a
			out.set_pixel(x, y, Color(a, a, a, 1.0))
	_made[key] = _with_mips(out)
	return _made[key]


## A soft dark blob. Every billboard needs one under it or it floats: the
## browser calls this `entityShadow` and draws one for everything on the deck.
func _blob_texture() -> ImageTexture:
	if _made.has("blob"):
		return _made.blob
	var size := 64
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := Vector2(size, size) * 0.5
	for y in size:
		for x in size:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(c) / (size * 0.5)
			var a: float = 0.0 if d > 1.0 else pow(1.0 - d, 1.7)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	_made.blob = _with_mips(img)
	return _made.blob


## A hot point, for bolts and sparks.
func _spark_texture() -> ImageTexture:
	if _made.has("spark"):
		return _made.spark
	var size := 64
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := Vector2(size, size) * 0.5
	for y in size:
		for x in size:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(c) / (size * 0.5)
			var a: float = 0.0 if d > 1.0 else pow(1.0 - d, 2.4) + exp(-pow(d / 0.22, 2.0))
			img.set_pixel(x, y, Color(1, 1, 1, clampf(a, 0.0, 1.0)))
	_made.spark = _with_mips(img)
	return _made.spark


func _process(delta: float) -> void:
	if game == null:
		return
	## The shader warm-up: draw one of everything for a few frames, off-screen,
	## then take it down. A pipeline is created when something is first RENDERED
	## with a material, so the only honest way to pay that cost early is to
	## render it early. The first bench found a 150 ms worst frame here against
	## an 8.5 ms steady state.
	if _warmup != null:
		_warm_frames += 1
		if _warm_frames == 1:
			_warmup.warm(self)
		elif _warm_frames > SkyGearWarmup.HOLD_FRAMES:
			_warmup.cool()
			_warmup = null
	_flicker += delta
	_aim_from_cursor()
	_track_camera(delta)
	_used.clear()
	_decals_used.clear()
	_sync_all(delta)
	_sync_auras()
	_sync_effects()
	_sync_darkness(delta)
	_flush_shadows()
	_sync_airstream(delta)
	## The flashes fade. Ember lingers, Frost is instant — the decay carries the
	## element as much as the colour does.
	for light in _flashes:
		if light.light_energy > 0.0:
			light.light_energy = maxf(0.0, light.light_energy
				- delta * float(light.get_meta("decay", 11.0)))
	## The cloud bands drift across and wrap. Slower than the airstream by an
	## order of magnitude, which is the parallax: the near thing races and the
	## far thing crawls.
	for band in _cloud_bands:
		var node: MeshInstance3D = band.node
		node.position.x += float(band.speed) * delta * WORLD_SCALE
		if node.position.x > float(band.span) * WORLD_SCALE:
			node.position.x = -float(band.span) * WORLD_SCALE
	_recycle()


## Return what nobody claimed this frame — HIDE it, do not free it.
##
## The rendering audit was blunt about this and correct: freeing every unclaimed
## node each frame and building a new one when it is next needed is churn with
## the word "pool" written on it. A fight is a few dozen decals and billboards
## appearing and disappearing several times a second, which was several dozen
## node allocations a second for no reason.
##
## Freed only when the free list is deeper than anything has ever needed at once,
## so a keg chain does not leave four hundred hidden nodes resident for the rest
## of the run.
const POOL_SLACK := 24

func _recycle() -> void:
	for key in _billboards.keys():
		if not _used.has(key):
			var node: Sprite3D = _billboards[key]
			node.visible = false
			_free_billboards.append(node)
			_billboards.erase(key)
	for key in _decals.keys():
		if not _decals_used.has(key):
			var node: Decal = _decals[key]
			node.visible = false
			_free_decals.append(node)
			_decals.erase(key)
			_decal_live[_decal_class(key)] -= 1
	## Rigs are the exception: a character is a whole scene with a skeleton and an
	## animation player, and keeping a dead boarder's one alive to re-skin later
	## is holding far more than a sprite.
	for key in _rigs.keys():
		if not _used.has(key):
			var rig: SkyGearRig3D = _rigs[key]
			rig.queue_free()
			_rigs.erase(key)
	_trim(_free_billboards)
	_trim(_free_decals)


func _trim(free_list: Array) -> void:
	while free_list.size() > POOL_SLACK:
		var node: Node = free_list.pop_back()
		node.queue_free()


## The camera sits behind and above the captain and looks down the pitch, and
## the numbers are the browser's own — see `camera_back()`. She rides at 60% of
## screen height, which is what the art was framed against.
func _track_camera(delta: float) -> void:
	var back := camera_back()
	var p: Vector2 = game.player.global_position if game.player != null else Vector2.ZERO
	var deck_rect: Rect2 = SkyGearGame.DECK_RECT
	var slack: float = deck_rect.size.x * 0.22
	var centre_x: float = deck_rect.position.x + deck_rect.size.x * 0.5
	## The leash is against the DECK, not against the Boiler. Clamping to keep
	## the objective framed can shove the captain off the top of the screen at
	## the bow, and losing yourself is far worse than losing sight of a thing
	## that has an edge marker for exactly this reason.
	var target := Vector2(
		clampf(p.x, centre_x - slack, centre_x + slack),
		clampf(p.y + back, deck_rect.position.y + 300.0, deck_rect.end.y + 200.0))
	if not _focus_set:
		_focus = target
		_focus_set = true
	else:
		_focus = _focus.lerp(target, 1.0 - exp(-delta / CAM_TAU))
	## The sway. Three periods that do not divide into each other, so the motion
	## never resolves into a loop you can count: a long roll, a shorter yaw, and
	## a heave on its own clock. Deliberately at the top of what is comfortable
	## rather than the bottom — the browser's version was invisible.
	_roll = 0.0
	_yaw = 0.0
	var heave := 0.0
	if sway:
		_roll = sin(_flicker * 0.31) * 0.72 + sin(_flicker * 0.73) * 0.28
		_yaw = sin(_flicker * 0.47)
		heave = sin(_flicker * 0.58) * SWAY_HEAVE
	## Shake is ADDED to the sway, never assigned over it. Two systems both
	## writing the camera transform is two systems fighting, and the sway is the
	## one the ship is doing.
	var kick := game.impact.shake_offset() if game.impact != null else Vector2.ZERO
	camera.position = Vector3((_focus.x + kick.x) * WORLD_SCALE,
		(CAM_HEIGHT + heave + kick.y) * WORLD_SCALE,
		(_focus.y + CAM_NEAR) * WORLD_SCALE)
	camera.rotation = Vector3(-PITCH, deg_to_rad(SWAY_YAW * _yaw),
		deg_to_rad(SWAY_ROLL * _roll))
	if _envelope != null:
		# hangs above and ahead, angled to face the camera
		_envelope.position = camera.position + Vector3(0.0, 620.0 * WORLD_SCALE,
			-1500.0 * WORLD_SCALE)
		_envelope.rotation = Vector3(-PITCH * 0.55, 0.0, 0.0)


func _sync_airstream(delta: float) -> void:
	var shear: float = 0.0
	if game.player != null:
		shear = clampf(game.player.velocity.x / 320.0, -1.0, 1.0)
	var lean := -shear * 0.30                     # radians, against the movement
	## They never get closer than this. A ribbon that passes within a couple of
	## metres of the lens is a pale smear over half the frame no matter how thin
	## it is in world units, which is what the first two passes looked like.
	var near_z: float = camera.position.z / WORLD_SCALE - 430.0
	for i in _stream.size():
		var node := _stream[i]
		# a stable per-streak pseudo-random, so nothing pops when one recycles
		var salt := float(i) * 0.6180339887
		var t: float = _stream_v[i] + delta * (STREAK_SPEED * (0.7 + fmod(salt * 7.3, 1.0) * 0.8)) / STREAK_DEPTH
		if t >= 1.0:
			t = fmod(t, 1.0)
		_stream_v[i] = t
		var z: float = near_z - STREAK_DEPTH * (1.0 - t)
		var x: float = _focus.x + (fmod(salt * 31.7, 1.0) - 0.5) * STREAK_SPREAD
		var y: float = 70.0 + fmod(salt * 13.1, 1.0) * 420.0
		# aim it down the keel, leaned by the shear
		var angle: float = -PI * 0.5 + lean
		var ca := cos(angle)
		var sa := sin(angle)
		var basis := Basis(Vector3(ca, 0.0, sa), Vector3(sa, 0.0, -ca), Vector3(0.0, 1.0, 0.0))
		basis = basis.scaled(Vector3(_stream_len[i * 2] * WORLD_SCALE,
			_stream_len[i * 2 + 1] * WORLD_SCALE, 1.0))
		node.transform = Transform3D(basis, Vector3(x, y, z) * WORLD_SCALE)
		# fade in at the far end and out as it passes, so nothing appears in shot
		var fade: float = smoothstep(0.0, 0.16, t) * smoothstep(1.0, 0.70, t)
		node.transparency = 1.0 - fade


## Where the cursor is pointing, ON THE DECK.
##
## THIS WAS THE AIMING BUG. `Node2D.get_global_mouse_position()` returns the
## mouse in the 2D scene's coordinates — and the 2D scene is hidden. What the
## player is looking at is a perspective projection of the deck through a
## Camera3D forty-one degrees above it, and the two spaces have no relationship
## whatsoever. Every skill was aimed at a point that had nothing to do with the
## cursor: a Lance fired past the pointer, a Mortar landed somewhere else, and a
## Cleave aimed away from the boarder it looked like it was facing.
##
## The browser has `CAM.unproject` for exactly this and it is the same three
## lines: take the ray under the cursor and intersect it with the deck plane.
## THE LIGHTS GO OUT. Wave 8's event, and the reason it is not a second boarding
## hulk: an event should change how the deck plays, and darkness changes every
## decision on it at once — where you can afford to be, whether that shape at the
## rail is a crate or a boarder, whether chasing salvage into the bow is worth it.
##
## Eased rather than switched, over about a second and a half. A hard cut reads
## as a bug, and the slow failure of the lamps is most of the drama.
var _moon: DirectionalLight3D
var _lantern: DirectionalLight3D
var _environment: Environment
var _moon_energy := 1.45
var _lantern_energy := 0.38
var _ambient_energy := 0.62
var _darkness := 0.0
var _darkness_target := 0.0
const DARKNESS_TAU := 0.55
## Never fully black. At 1.0 the deck is unplayable rather than dangerous, and
## the moon is the one thing that should still be up there.
const DARKNESS_FLOOR := 0.22


func set_darkness(amount: float) -> void:
	_darkness_target = clampf(amount, 0.0, 1.0)


func _sync_darkness(delta: float) -> void:
	if is_equal_approx(_darkness, _darkness_target) and _darkness <= 0.0001:
		return
	_darkness = lerpf(_darkness, _darkness_target, 1.0 - exp(-delta / DARKNESS_TAU))
	var keep: float = lerpf(1.0, DARKNESS_FLOOR, _darkness)
	if _moon != null:
		## The moon dims least. Losing the rim light entirely turns every figure
		## into a silhouette you cannot identify, which is unfair rather than dark.
		_moon.light_energy = _moon_energy * lerpf(1.0, 0.52, _darkness)
	if _lantern != null:
		_lantern.light_energy = _lantern_energy * keep
	if _environment != null:
		_environment.ambient_light_energy = _ambient_energy * keep
		## And the fog thickens, so the far end of the deck goes first — the bow
		## is where a push comes from, so that is the part worth losing.
		_environment.fog_enabled = true


func _aim_from_cursor() -> void:
	if camera == null:
		return
	var viewport := camera.get_viewport()
	if viewport == null:
		return
	var mouse := viewport.get_mouse_position()
	var from := camera.project_ray_origin(mouse)
	var direction := camera.project_ray_normal(mouse)
	## Parallel to the deck means the cursor is on or above the horizon. Keep the
	## last good point rather than aiming at infinity behind the ship.
	if absf(direction.y) < 0.00001:
		return
	var distance := -from.y / direction.y
	if distance <= 0.0:
		return
	var hit := from + direction * distance
	game.set_cursor_ground(Vector2(hit.x, hit.z) / WORLD_SCALE)


## Ground point under a screen position, for the harness and for anything that
## needs to ask without waiting for a frame.
func ground_at(screen: Vector2) -> Vector2:
	var from := camera.project_ray_origin(screen)
	var direction := camera.project_ray_normal(screen)
	if absf(direction.y) < 0.00001:
		return Vector2.ZERO
	var hit := from + direction * (-from.y / direction.y)
	return Vector2(hit.x, hit.z) / WORLD_SCALE


## Effects, projected flat onto the deck.
##
## In the browser every skill draws its shape on the ground, and it is most of
## what a fight looks like: the arc of a cleave, the ring of a mortar, the wedge
## of a gale, the streak of a beam. They live in the 2D scene here, which is no
## longer the scene anyone looks at — so they are rebuilt as unshaded quads lying
## a centimetre above the planking, which is what a decal is and what the browser
## was approximating.
func _sync_effects() -> void:
	for i in game.effects.size():
		var fx: Dictionary = game.effects[i]
		## By ID, never by index. See `_fx()` in game.gd — these arrays compact
		## on expiry, so an index is a different effect from one frame to the
		## next and the node pooled against it inherits the wrong contents.
		var fid: int = int(fx.get("id", -1))
		if fid < 0:
			continue
		var kind := str(fx.kind)
		if kind == "banner":
			continue
		var progress: float = float(fx.time) / maxf(0.001, float(fx.life))
		var alpha: float = clampf(1.0 - progress, 0.0, 1.0)
		var colour: Color = fx.get("color", Color.WHITE)
		## Over 1.0 on purpose. The glow threshold is 1.05, so a skill drawn at
		## its own palette value never blooms — and the browser's rings all carry
		## a hand-painted halo. This is the same halo, from the post chain.
		var tint := Color(colour.r * 1.45, colour.g * 1.45, colour.b * 1.45, alpha)
		var centre: Vector2 = fx.get("position", Vector2.ZERO)
		match kind:
			"arc":
				var r: float = float(fx.get("radius", 120.0)) * (0.9 + progress * 0.2)
				_decal("fx%d" % fid, centre, float(fx.get("direction", 0.0)),
					r * 2.0, r * 2.0, _art("slash", _fan_texture(float(fx.get("arc", 1.7)), false)),
					tint)
			"cone":
				var rc: float = float(fx.get("radius", 120.0)) * (0.55 + progress * 0.55)
				_decal("fx%d" % fid, centre, float(fx.get("direction", 0.0)),
					rc * 2.0, rc * 2.0, _fan_texture(float(fx.get("arc", 0.9)), true),
					Color(tint.r, tint.g, tint.b, tint.a * 0.85))
			"circle":
				var rb: float = float(fx.get("radius", 120.0)) * maxf(0.25, progress)
				_decal("fx%d" % fid, centre, 0.0, rb * 2.0, rb * 2.0,
					_art("ring", _ring_texture()), tint)
			"burst":
				## A burst is an impact, and there is a painted one. It reads as
				## debris thrown out of a point rather than as a ring, which is
				## the difference between a kill and a spell landing.
				var rp: float = float(fx.get("radius", 120.0)) * (0.5 + progress * 0.9)
				_decal("fx%d" % fid, centre, 0.0, rp * 2.0, rp * 2.0,
					_art("burst", _ring_texture()), tint)
			"line", "beam":
				var from: Vector2 = fx.get("from", Vector2.ZERO)
				var to: Vector2 = fx.get("to", Vector2.ZERO)
				var span := to - from
				var width: float = (26.0 if kind == "line" else 54.0) * (1.0 - progress * 0.35)
				_decal("fx%d" % fid, (from + to) * 0.5, span.angle(),
					maxf(8.0, span.length()), width,
					_art("bolt", _streak_texture()) if kind == "line" else _streak_texture(),
					tint)
			_:
				var rr: float = float(fx.get("radius", 90.0))
				_decal("fx%d" % fid, centre, 0.0, rr * 2.0, rr * 2.0, _ring_texture(), tint)

	## Lingering fire. It is a hazard you have to read the floor for, so it gets
	## a decal that breathes rather than a static disc.
	for i in game.fire_fields.size():
		var f: Dictionary = game.fire_fields[i]
		var pulse: float = 0.72 + sin(_flicker * 7.0 + float(i)) * 0.14
		var fr: float = float(f.get("radius", 62.0)) * 2.2
		var fid2: int = int(f.get("id", i))
		# the scorch on the planking, and the fire standing on top of it
		_decal("scorch%d" % fid2, f.position, 0.0, fr, fr, _art("scorch", _blob_texture()),
			Color(0.10, 0.07, 0.08, 0.75), false)
		_decal("fire%d" % fid2, f.position, 0.0, fr * 0.82, fr * 0.82,
			_art("ring", _ring_texture()),
			Color(1.0, 0.52, 0.18, clampf(float(f.time) / 3.0, 0.0, 1.0) * pulse))

	## CRACKED MAINS. The Boilerwright's ground, and the only thing on the deck a
	## player put there on purpose — so it has to read as a place rather than as
	## an effect. A hard rim you can stand on the edge of, a soft fill, and steam
	## boiling off it; the rim is what matters, because the class is about knowing
	## exactly where the line is.
	for i in game.taps.size():
		var tap: Dictionary = game.taps[i]
		var left: float = clampf(float(tap.life) / maxf(0.1, float(tap.max_life)),
			0.0, 1.0)
		## The last two seconds pulse, same language the sentries use.
		var dying: bool = float(tap.life) < 2.0
		var beat: float = 1.0 if not dying else 0.55 + 0.45 * absf(sin(_flicker * 9.0))
		var span: float = float(tap.radius) * 2.0
		var steam := Color("#9be8d2")
		_decal("tapf%d" % i, tap.position, 0.0, span, span, _blob_texture(),
			Color(steam.r, steam.g, steam.b, 0.16 * beat), false)
		_decal("tapr%d" % i, tap.position, 0.0, span, span, _ring_texture(),
			Color(steam.r, steam.g, steam.b, 0.72 * beat))
		## And it is venting, visibly — three plumes off the rim rather than one
		## in the middle, because a main is a crack in the deck, not a fountain.
		for plume in 3:
			var angle: float = _flicker * 0.5 + float(plume) * TAU / 3.0
			var at: Vector2 = Vector2(tap.position) + Vector2(cos(angle), sin(angle)) 				* float(tap.radius) * 0.62
			_spark("tapv%d_%d" % [i, plume], at, 60.0 + sin(_flicker * 3.0 + plume) * 24.0,
				52.0 * beat, steam)

	## The ordnance the deck already knows about: a lit keg draws its blast.
	for prop in game.get_tree().get_nodes_in_group("props"):
		if is_instance_valid(prop) and not prop.dead and prop.fuse_left > 0.0:
			var f2: float = 1.0 - prop.fuse_left / 0.45
			_decal("keg%d" % prop.get_instance_id(), prop.global_position, 0.0, 350.0, 350.0,
				_ring_texture(), Color(0.95, 0.92, 1.0, 0.25 + f2 * 0.35))

	## Enemy telegraphs. The browser draws the reach of a windup on the deck in
	## red, and it is the single most important thing on screen when three of
	## them are on you — a boarder that is about to swing has to look different
	## from one that is walking.
	for enemy in game.get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or enemy.dead:
			continue
		if enemy.state == "windup":
			var reach: float = float(enemy.config.attack_range)
			var mid: Vector2 = enemy.global_position + enemy.attack_direction * reach * 0.5
			var beat: float = 0.55 + sin(_flicker * 22.0) * 0.22
			_decal("tg%d" % enemy.get_instance_id(), mid, enemy.attack_direction.angle(),
				reach, 34.0, _streak_texture(), Color(0.92, 0.18, 0.11, beat))
			## And the enemy rune under their feet, which is the painted plate
			## that exists for exactly this and had never been drawn: it fills as
			## the windup completes, so the tell has a clock on it.
			var wind: float = 1.0 - clampf(enemy.state_time / maxf(0.05,
				float(enemy.config.windup)), 0.0, 1.0)
			var mark: float = float(enemy.radius) * 3.2
			_decal("tr%d" % enemy.get_instance_id(), enemy.global_position, 0.0, mark, mark,
				_art("ring_filled" if wind > 0.62 else "ring_hostile", _ring_texture()),
				Color(0.95, 0.25, 0.16, 0.35 + wind * 0.5))
		elif enemy.state == "turn":
			var ring: float = (enemy.radius + 26.0 + sin(enemy.turn_time * 9.0) * 6.0) * 2.0
			_decal("tn%d" % enemy.get_instance_id(), enemy.global_position, 0.0, ring, ring,
				_art("ring", _ring_texture()), Color("#ffd36b"))


## One ground effect, pooled, as an actual projected decal.
##
## THIS WAS NOT 3D. Every skill shape, every fire field, every contact shadow was
## an unshaded quad lying one and a half centimetres above the deck plane, which
## is a 2D sticker that happens to live in a 3D scene. Three things follow from
## that and all three were visible:
##
##   1. **Z-fighting.** 0.015 m of separation inside a 0.05–400 m depth range is
##      inside the depth buffer's own precision. Rings shimmered.
##   2. **Slicing.** The quad is a flat plane, so where an effect reached a cargo
##      run it was cut off along a hard straight line instead of climbing it, and
##      where it reached the Boiler plinth it went through it.
##   3. **No conforming.** A mortar landing at the foot of a crate painted half a
##      ring on the floor and nothing on the crate.
##
## Godot's `Decal` is the fix and it is the whole reason to be in a 3D renderer
## for this: it projects down a box onto whatever geometry is inside it, so the
## ring wraps the deck AND the crate, cannot z-fight because it is not a surface,
## and needs no depth ordering against anything.
##
## `angle` aims the texture's +X down a direction in ground coordinates; `sx`/`sy`
## are its size along and across that.
## What a decal is FOR, and how many of each we will draw.
##
## The pooling was real but the budget was not: `_decal` would allocate an
## unbounded number of live decals, and a decorative scorch competed on equal
## footing with an enemy windup rune. On a bad frame the thing that gets dropped
## should never be the thing that tells you a boarder is about to hit you.
##
## Reserved rather than shared. A telegraph is guaranteed its capacity even when
## the deck is covered in scorch marks.
enum DecalClass { TELEGRAPH, PLAYER, DECOR }
const DECAL_BUDGET := {
	DecalClass.TELEGRAPH: 48,      ## enemy windups and turn rings — never dropped
	DecalClass.PLAYER: 24,         ## your own shapes, fields and aura edges
	DecalClass.DECOR: 40,          ## scorch, glow pools, keg blasts, bolt trails
}
var _decal_live := {DecalClass.TELEGRAPH: 0, DecalClass.PLAYER: 0, DecalClass.DECOR: 0}


## Which budget a key draws from. Derived from the key rather than passed in, so
## a new effect cannot forget to declare itself and quietly spend a telegraph.
static func _decal_class(key: String) -> DecalClass:
	if key.begins_with("tg") or key.begins_with("tr") or key.begins_with("tn"):
		return DecalClass.TELEGRAPH
	if key.begins_with("fx") or key.begins_with("aura") or key.begins_with("boiler"):
		return DecalClass.PLAYER
	return DecalClass.DECOR


func _decal(key: String, centre: Vector2, angle: float, sx: float, sy: float,
		texture: Texture2D, colour: Color, glowing: bool = true) -> void:
	## An existing decal keeps its slot; only a NEW one has to find budget, or a
	## long-lived aura would be evicted by its own next frame.
	if not _decals.has(key):
		var group := _decal_class(key)
		if _decal_live[group] >= int(DECAL_BUDGET[group]):
			return
		_decal_live[group] += 1
	_decals_used[key] = true
	var node: Decal = _decals.get(key)
	if node == null:
		if not _free_decals.is_empty():
			node = _free_decals.pop_back()
			node.visible = true
		else:
			node = Decal.new()
			node.cull_mask = 0xFFFFF & ~LAYER_FIGURES & ~LAYER_SHADOWS
			node.upper_fade = 0.1
			node.lower_fade = 0.1
			node.normal_fade = 0.0
			add_child(node)
		_decals[key] = node
		_peak_decals = maxi(_peak_decals, _decals.size())
	node.texture_albedo = texture
	node.modulate = Color(colour.r, colour.g, colour.b, 1.0)
	## Emission through a PREMULTIPLIED map, never through the albedo texture.
	## A Decal's emission channel ignores the texture's alpha and lights the
	## whole projection box, so feeding it the ring — white RGB, shaped alpha —
	## painted a solid glowing rectangle the size of the effect's bounding box
	## over the deck, the crates and the fight. Baking alpha into RGB makes the
	## hollow parts black, and black emits nothing.
	if glowing:
		node.texture_emission = _glow_map(texture)
		node.emission_energy = 0.85 * colour.a
	else:
		node.texture_emission = null
		node.emission_energy = 0.0
	node.albedo_mix = colour.a
	## The projection box. Tall enough to reach the top of a cargo run from above
	## so an effect that touches one climbs it, and to reach the deck from a metre
	## up so nothing falls short.
	var basis := Basis(Vector3(cos(angle), 0.0, sin(angle)), Vector3(0.0, 1.0, 0.0),
		Vector3(-sin(angle), 0.0, cos(angle)))
	node.transform = Transform3D(basis, Vector3(centre.x * WORLD_SCALE,
		90.0 * WORLD_SCALE, centre.y * WORLD_SCALE))
	node.size = Vector3(sx, 260.0, sy) * WORLD_SCALE


## Contact shadows, all of them, in one draw.
##
## Every figure, prop, cannon, crewman, projectile and pickup on the deck had its
## own `Decal` for the blob underneath it — about seventy clustered decals at
## bench load before a single telegraph or effect, and the largest remaining GPU
## item in the scene. They are all the same quad, the same texture and the same
## flat orientation, which is exactly what a MultiMesh is for.
##
## Written from scratch each frame rather than diffed: there is no persistent
## identity to preserve, the count is small, and a rebuild cannot leak a stale
## shadow under something that has died.
const SHADOW_CAP := 256

func _shadow(_key: String, centre: Vector2, width: float, alpha: float) -> void:
	if _shadow_count >= SHADOW_CAP:
		return
	_shadow_at[_shadow_count] = centre
	_shadow_size[_shadow_count] = width
	_shadow_alpha[_shadow_count] = alpha
	_shadow_count += 1


func _build_shadows() -> void:
	var mesh := QuadMesh.new()
	mesh.size = Vector2.ONE
	## Flat on the deck. Lying down is the quad's own orientation, not a
	## per-instance rotation, so every instance transform is a scale and an
	## offset and nothing more.
	mesh.orientation = PlaneMesh.FACE_Y
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_texture = _art("blob", _blob_texture())
	## The alpha rides on the instance colour, which is the whole reason this can
	## be one draw: a fading shadow needs no material of its own.
	mat.vertex_color_use_as_albedo = true
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	mat.no_depth_test = false
	_shadow_batch = MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = SHADOW_CAP
	mm.visible_instance_count = 0
	_shadow_batch.multimesh = mm
	_shadow_batch.material_override = mat
	_shadow_batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_shadow_batch.layers = LAYER_SHADOWS
	## The deck is 16.8 x 23.2 metres; without an explicit box the batch is culled
	## whenever its origin leaves the frustum and every shadow blinks out.
	_shadow_batch.custom_aabb = AABB(Vector3(-12, -1, -14), Vector3(24, 2, 28))
	add_child(_shadow_batch)


func _flush_shadows() -> void:
	if _shadow_batch == null:
		return
	var mm: MultiMesh = _shadow_batch.multimesh
	for i in _shadow_count:
		var width: float = _shadow_size[i] * WORLD_SCALE
		var basis := Basis().scaled(Vector3(width, 1.0, width * 0.62))
		mm.set_instance_transform(i, Transform3D(basis,
			Vector3(_shadow_at[i].x * WORLD_SCALE, 2.0 * WORLD_SCALE,
				_shadow_at[i].y * WORLD_SCALE)))
		mm.set_instance_color(i, Color(0.02, 0.015, 0.03, _shadow_alpha[i]))
	mm.visible_instance_count = _shadow_count
	_shadow_count = 0


## The aura, as a volume.
##
## A Field was the one skill in the game with NO visual at all: `_update_passives`
## ticks `_damage_circle` at the captain's radius and appended nothing, so a
## hundred and fifty units of standing damage were invisible and the player had
## no way to know where the edge of their own aura was. The other passives fake
## it by appending a circle every time they fire; a Field fires 1.8 times a
## second and would have strobed.
##
## So it gets what it actually is: a soft cylinder of charged air around her,
## plus a decal ring on the planking marking exactly where it stops. Both are
## driven from `skill_stats` each frame, so a card that widens the field widens
## the picture with no second place to change.
func _sync_auras() -> void:
	var index := 0
	for skill in game.skills:
		var shape: Dictionary = SkyGearData.SHAPES[skill.shape]
		if str(shape.get("kind", "")) != "aura":
			continue
		index += 1
		var st: Dictionary = game.skill_stats(skill)
		var radius := float(st.radius)
		var tint: Color = SkyGearData.ELEMENTS[skill.element].color
		var at: Vector2 = game.player.global_position
		# the edge, on the deck
		_decal("aura%d" % index, at, 0.0, radius * 2.0, radius * 2.0,
			_art("ring", _ring_texture()),
			Color(tint.r, tint.g, tint.b, 0.42 + sin(_flicker * 2.6) * 0.08))
		# and the air inside it
		var key := "auravol%d" % index
		_used[key] = true
		var vol: MeshInstance3D = _volumes.get(key)
		if vol == null:
			vol = MeshInstance3D.new()
			var cyl := CylinderMesh.new()
			cyl.top_radius = 1.0
			cyl.bottom_radius = 1.0
			cyl.height = 1.0
			cyl.radial_segments = 40
			cyl.cap_top = false
			cyl.cap_bottom = false
			vol.mesh = cyl
			var m := StandardMaterial3D.new()
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			m.albedo_texture = _wall_texture()
			m.disable_receive_shadows = true
			## Only the FAR wall. You are standing inside this thing, so the near
			## wall is between the camera and you — and drawn additively that
			## bleached the captain and anyone next to her every time a Field was
			## equipped. Culling the front faces leaves the boundary you are
			## looking at and removes the one you are looking through.
			m.cull_mode = BaseMaterial3D.CULL_FRONT
			vol.material_override = m
			vol.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(vol)
			_volumes[key] = vol
		var mat: StandardMaterial3D = vol.material_override
		mat.albedo_color = Color(tint.r, tint.g, tint.b, 0.22)
		vol.scale = Vector3(radius * WORLD_SCALE, 118.0 * WORLD_SCALE, radius * WORLD_SCALE)
		vol.position = Vector3(at.x * WORLD_SCALE, 59.0 * WORLD_SCALE, at.y * WORLD_SCALE)
	# a field that was dropped stops being drawn
	for key in _volumes.keys():
		if not _used.has(key):
			var dead: MeshInstance3D = _volumes[key]
			dead.queue_free()
			_volumes.erase(key)


func _sync_all(delta: float) -> void:
	if game.player != null and game.player.hp > 0.0:
		_shadow("player", game.player.global_position, 96.0, 0.55)
		if not _sync_captain(delta):
			_draw_figure("player", "hero", game.player.global_position,
				game.player.aim_direction, 150.0,
				game.player.attack_time > 0.0,
				game.player.velocity.length() > 35.0 and game.player.dash_time_left <= 0.0,
				game.run_time, game.player.attack_time)
			_xray("player", game.player.global_position, 150.0, Color(1.0, 0.86, 0.42, 0.62))
	for enemy in game.get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or enemy.dead:
			continue
		var config: Dictionary = SkyGearData.ENEMIES.get(enemy.kind, {})
		var height := 120.0 + float(config.get("radius", 22.0)) * 3.0
		var key := "e%d" % enemy.get_instance_id()
		_shadow(key, enemy.global_position, float(enemy.radius) * 2.6, 0.5)
		## Boarders come DOWN the deck, so most of the time you are looking at
		## their backs — which is the view the port never drew. They face you when
		## they turn to swing, and that turn is the tell.
		var heading: Vector2 = enemy.attack_direction
		if enemy.state == "move" and enemy.velocity.length_squared() > 1.0:
			heading = enemy.velocity
		var swinging: bool = enemy.state == "windup" or enemy.state == "recover"
		# a phase offset per boarder, or a lane of them marches in lockstep
		var phase: float = float(enemy.get_instance_id() % 97) * 0.113
		## A mesh if one has been ingested for this kind, the painted billboard
		## if not. Both paths are always here: the boarders will become models
		## one at a time, and the renderer should not need editing for each.
		if not _sync_rig(key, enemy.kind, enemy.global_position, heading, height,
				swinging, enemy.state == "move", enemy.velocity.length(),
				maxf(0.0, enemy.state_time), delta):
			_draw_figure(key, enemy.kind, enemy.global_position, heading, height, swinging,
				enemy.state == "move", game.run_time + phase, maxf(0.0, enemy.state_time))
		# burning boarders glow; frozen ones go blue. The status is the read.
		var node: Sprite3D = _billboards.get(key)
		if node != null:
			var tint := Color.WHITE
			if enemy.burn_stacks > 0:
				tint = Color(1.0, 0.72, 0.52).lerp(Color(1.6, 0.9, 0.6), 0.4)
			elif enemy.slow_time > 0.0:
				tint = Color(0.68, 0.86, 1.0)
			if enemy.stun_time > 0.0:
				tint = tint.lerp(Color(1.3, 1.25, 0.8), 0.5)
			node.modulate = tint
		_xray(key, enemy.global_position, height, Color(0.95, 0.30, 0.22, 0.55))
	for prop in game.get_tree().get_nodes_in_group("props"):
		if not is_instance_valid(prop) or prop.dead:
			continue
		var pkey := "p%d" % prop.get_instance_id()
		## Heights straight from the browser's `PROP_H`, which is the table that
		## decides whether a keg reads as ordnance or as a footstool.
		var ph: float = float(PROP_HEIGHT.get(prop.prop_type, 110.0))
		_shadow(pkey, prop.global_position, 80.0, 0.45)
		_place(pkey, _texture(prop.texture_path()), prop.global_position, ph)
	for i in game.crew.size():
		var c: Dictionary = game.crew[i]
		if bool(c.dead):
			continue
		_shadow("c%d" % i, c.position, 74.0, 0.45)
		## Crew push UP the deck, into the boarders, so they are almost always
		## showing you their backs. Drawing them front-on made a line of allies
		## look like it was retreating.
		var busy: bool = str(c.get("state", "move")) != "move"
		_draw_figure("c%d" % i, "CREW", c.position, Vector2(0, -1), 110.0,
			busy, not busy, game.run_time + float(i) * 0.21, float(c.get("state_time", 0.0)))
	## Deployed sentries. A short brass post with a live head on it, the range it
	## covers written on the planking, and a wick that burns down — you should be
	## able to tell at a glance, from across the deck, which of yours is about to
	## expire and whether the lane you are worried about is inside one.
	for s in game.sentries:
		var sid: int = int(s.id)
		var tint: Color = SkyGearData.ELEMENTS[str(s.element)].color
		var left: float = clampf(float(s.life) / maxf(0.1, float(s.max_life)), 0.0, 1.0)
		## The last two seconds pulse. Everything else about it is static, so the
		## only thing that moves is the thing that is running out.
		var urgent: bool = float(s.life) < 2.0
		var beat: float = 1.0 if not urgent else 0.55 + 0.45 * absf(sin(_flicker * 9.0))
		_shadow("sy%d" % sid, s.position, 92.0, 0.48)
		## THE RANGE RING, ON ARRIVAL ONLY. Drawn permanently it is 840 units
		## across — two of them cover the deck and the fight happens inside a pair
		## of glowing hoops. It is the answer to "what does this cover?", which is
		## a question you ask when you place it and never again, so it flares over
		## the first three quarters of a second and then goes.
		var age: float = game.run_time - float(s.born)
		if age < 0.75:
			var fade: float = 1.0 - age / 0.75
			_decal("syr%d" % sid, s.position, 0.0, float(s.range) * 2.0,
				float(s.range) * 2.0, _ring_texture(),
				Color(tint.r, tint.g, tint.b, 0.34 * fade * fade))
		## What stays is a small collar at its feet: enough to say "this one is
		## yours, and it is an ARC one", without claiming a quarter of the deck.
		_decal("syb%d" % sid, s.position, 0.0, 132.0, 132.0, _ring_texture(),
			Color(tint.r, tint.g, tint.b, 0.5 * beat))
		## The wick — a bar on the planking that shortens with the life left, so
		## the countdown is legible from across the deck without a number.
		_decal("syw%d" % sid, s.position + Vector2(0.0, 82.0), 0.0,
			104.0 * left, 11.0, _streak_texture(),
			Color(tint.r, tint.g, tint.b, 0.9 * beat))
		## A ballista rather than a deck cannon. Sharing art with the ship's own
		## cannons made a placed sentry invisible: five identical guns on the deck
		## and no way to tell which two you put there.
		_place("sy%d" % sid, _texture("res://assets/art/props/harpoon_ballista.png"),
			s.position, 104.0, 0.0, Color(1.0, 1.0, 1.0).lerp(tint, 0.30))
		_spark("syh%d" % sid, s.position, 104.0, 34.0 * beat, tint)

	for i in game.turrets.size():
		var t: Dictionary = game.turrets[i]
		var art := "res://assets/art/props/cannon_deck_destroyed.png" if bool(t.dead) \
			else "res://assets/art/props/cannon_deck.png"
		_shadow("t%d" % i, t.position, 118.0, 0.5)
		_place("t%d" % i, _texture(art), t.position, 130.0)

	## Ordnance in flight. These were missing entirely, which is why the fight
	## looked static: half of what is on screen at any moment in the browser is
	## something travelling between two people.
	## Every bolt in flight is hostile, and a tester could not track them (F-05).
	## The browser's fix was three things at once and all three port: a hot head,
	## a trail behind it, and a shadow on the planking directly under it — the
	## shadow is what tells you where it will cross you, because the head is in
	## the air and the deck is where you are.
	for i in game.projectiles.size():
		var b: Dictionary = game.projectiles[i]
		var bid: int = int(b.get("id", i))
		var col := Color("#ff6a4a")
		var trail: Array = b.get("trail", [])
		if trail.size() > 1:
			var tail: Vector2 = trail[trail.size() - 1]
			var span: Vector2 = b.position - tail
			if span.length() > 4.0:
				_decal("bt%d" % bid, (b.position + tail) * 0.5, span.angle(),
					span.length(), 20.0, _streak_texture(), Color(col.r, col.g, col.b, 0.45))
		_shadow("b%d" % bid, b.position, 40.0, 0.38)
		_spark("b%d" % bid, b.position, 60.0, 52.0, col)

	## Salvage on the deck, bobbing so it reads as a pickup and not as debris.
	for i in game.salvage.size():
		var s: Dictionary = game.salvage[i]
		var sid: int = int(s.get("id", i))
		var bob: float = sin(_flicker * 3.4 + float(sid) * 1.7) * 9.0
		_shadow("s%d" % sid, s.position, 56.0, 0.35)
		_place("s%d" % sid, _texture("res://assets/art/props/salvage_pile.png"),
			s.position, 62.0, bob)

	## The Boiler's health, as a ring on the planking around it.
	_decal("boiler_ring", game.boiler_position, 0.0, 330.0, 330.0, _ring_texture(),
		Color(0.91, 0.77, 0.46, 0.55) if game.boiler_hp > game.boiler_max_hp * 0.3
		else Color(1.0, 0.30, 0.22, 0.65))

	## Lanterns and braziers are light sources in a dark scene, and in 3D that
	## can simply be true rather than painted on. They flicker, because a fixed
	## point light on a ship at dusk is the one thing that says "render".
	for prop in game.get_tree().get_nodes_in_group("props"):
		if not is_instance_valid(prop):
			continue
		var id := prop.get_instance_id()
		var kind: String = prop.prop_type
		var wants_light: bool = (not prop.dead) and (kind == "lantern" or kind == "brazier")
		var light: OmniLight3D = _lights.get(id)
		if wants_light and light == null:
			light = OmniLight3D.new()
			add_child(light)
			_lights[id] = light
		elif not wants_light and light != null:
			light.queue_free()
			_lights.erase(id)
		if light != null:
			## Accents, not floodlights. At 3.4 energy over a five-metre radius
			## three braziers turned a dusk deck into an orange room; the browser
			## paints its lantern haze at a fraction of the deck's own value and
			## that ratio is the whole mood.
			var warm: bool = kind == "brazier"
			var jitter: float = 1.0 + sin(_flicker * (11.0 if warm else 6.0) + float(id % 17)) * 0.12
			light.light_color = Color("#ff8a3a") if warm else Color("#ffb347")
			light.light_energy = (1.5 if warm else 1.0) * jitter
			light.omni_range = (330.0 if warm else 260.0) * WORLD_SCALE
			light.position = Vector3(prop.global_position.x * WORLD_SCALE,
				(60.0 if warm else 110.0) * WORLD_SCALE, prop.global_position.y * WORLD_SCALE)
			## And the pool on the planking. A point light alone falls off into
			## the deck's own roughness and reads as nothing from this angle; the
			## browser paints a radial gradient under every flame for exactly
			## this reason, and it is most of why its deck looks lit rather than
			## bright.
			_decal("glow%d" % id, prop.global_position, 0.0,
				(430.0 if warm else 330.0), (430.0 if warm else 330.0), _blob_texture(),
				Color(1.0, 0.56, 0.22, 0.34 * jitter) if warm
				else Color(1.0, 0.72, 0.36, 0.24 * jitter))

	## The hulk has three painted states and the port only ever drew one. Sealed
	## while it is still grappling on, open while it is disgorging boarders,
	## wrecked once you break it — which is the only feedback that breaking it
	## did anything, since it stops existing in the simulation the same moment.
	if not game.hulk.is_empty():
		var broken: bool = bool(game.hulk.get("dead", false))
		var vulnerable: bool = bool(game.hulk.get("vulnerable", true))
		var art := "res://assets/art/props/boarding_hulk_destroyed.png" if broken \
			else ("res://assets/art/props/boarding_hulk_open.png" if vulnerable
				else "res://assets/art/props/boarding_hulk_sealed.png")
		_shadow("hulk", game.hulk.position, 300.0, 0.5)
		_place("hulk", _texture(art), game.hulk.position, 420.0)


## The captain, as a rigged, animated mesh.
##
## Every other figure on this deck is a painted billboard turned to face the
## camera, which is what the browser could do and all it could do. She is the
## one the player looks at for a whole run and the one constantly turning: a
## billboard cannot show which way you are facing, and in a game where a Cleave
## aimed away from a boarder does nothing, which way you are facing is a
## mechanic.
##
## The state machine, the crossfades, the rate-limited turn and the hit
## reactions all live in `SkyGearRig3D`, because none of that is about her —
## the boarders are next and they get the same component.
const USE_MESH_CAPTAIN := true
const CAPTAIN_SCENE := "res://assets/models/captain/captain.tscn"
const CAPTAIN_HEIGHT := 176.0        ## ground units, sole to crown
var _captain: SkyGearRig3D
var _captain_missing := false
## Her own key light. A standard trick and the honest one: the hero of a dark
## scene is lit for being the hero, not by whatever happens to be burning nearby.
var _hero: OmniLight3D


func _sync_captain(delta: float) -> bool:
	if not USE_MESH_CAPTAIN or _captain_missing:
		return false
	if _captain == null:
		_captain = SkyGearRig3D.new()
		add_child(_captain)
		if not _captain.setup(CAPTAIN_SCENE, CAPTAIN_HEIGHT * WORLD_SCALE, LAYER_FIGURES):
			_captain.queue_free()
			_captain = null
			_captain_missing = true
			return false
		## And put the cutlass in her hand. The fit is data — see
		## `assets/models/weapons.json` and `tools/weapon_fit.gd` — because it is a
		## dozen small nudges and none of them is worth a build.
		##
		## Not fatal when it fails: an empty hand is a worse captain, but a captain.
		var fit := SkyGearRig3D.weapon_fit("captain")
		if not fit.is_empty():
			var offset: Array = fit.get("offset", [0, 0, 0])
			var turn: Array = fit.get("rotation", [0, 0, 0])
			## Her height here is in METRES (the deck runs on WORLD_SCALE), and the
			## fit table was authored against a 1.8 m captain — so the blade scales
			## with her rather than being 0.95 m on a figure 1.76 units tall.
			var to_world: float = CAPTAIN_HEIGHT * WORLD_SCALE / 1.8
			_captain.hold(str(fit.path), str(fit.bone),
				Vector3(offset[0], offset[1], offset[2]) * to_world,
				Vector3(turn[0], turn[1], turn[2]),
				float(fit.get("length", 0.95)) * to_world, LAYER_FIGURES)
	var player := game.player
	## What she is doing, in the order the rig resolves it. Dash beats run, swing
	## beats dash — and the rig holds a one-shot for its own length rather than
	## having it cancelled on the next frame by the run underneath it.
	var speed: float = player.velocity.length()
	var doing := "idle"
	if player.hurt_time > 0.0:
		doing = "hurt"
	elif player.attack_time > 0.0:
		doing = "swing"
	elif player.dash_time_left > 0.0:
		doing = "dash"
	elif speed > (28.0 if _captain.state == "run" else 62.0):
		## HYSTERESIS. A single threshold at 35 meant a captain drifting near it
		## — which is most of the time, because friction decays speed through
		## that band every time you let go — flipped between run and idle every
		## frame. Each flip restarts a crossfade, and a crossfade restarted every
		## frame never gets anywhere: that is the popping. Enter the run fast,
		## leave it slow, and the band between is where she stays put.
		doing = "run"
	## The window travels with the state, so the rig can fit the clip to it.
	var window := 0.0
	if doing == "swing":
		window = player.attack_time
	elif doing == "dash":
		window = maxf(0.12, player.dash_time_left)
	elif doing == "hurt":
		window = maxf(0.2, player.hurt_time)
	_captain.want(doing, speed, window)
	## A flinch is worth seeing on the model as well as in the numbers.
	if player.hurt_time > 0.30:
		_captain.react_hit(1.0)
	## She turns to her aim rather than to her movement: aim is what the Cleave
	## uses, so aim is what the player has to be able to read off her.
	_captain.place(player.global_position, player.aim_direction, WORLD_SCALE, delta,
		player.velocity)

	if _hero == null:
		## OUTSIDE her transform. A light parented to a node scaled by 0.009 has
		## its range scaled by 0.009 too, which is a two centimetre lamp.
		_hero = OmniLight3D.new()
		_hero.light_color = Color("#ffd9b0")
		_hero.light_energy = 1.5
		_hero.omni_range = 250.0 * WORLD_SCALE
		_hero.omni_attenuation = 1.5
		_hero.shadow_enabled = false
		add_child(_hero)
	_hero.position = Vector3(player.global_position.x * WORLD_SCALE, 150.0 * WORLD_SCALE,
		(player.global_position.y + 90.0) * WORLD_SCALE)
	return true


## Where an ingested model for a kind would live. `SCRAPPER` -> `scrapper`, and
## `tools/models.json` writes to exactly that path, so adding a boarder model is
## a manifest entry and an ingest run rather than a code change.
static func model_path(kind: String) -> String:
	var slug := kind.to_lower()
	return "res://assets/models/%s/%s.tscn" % [slug, slug]


## Drive a rigged figure, if this kind has one. Returns false when it does not,
## so the caller falls back to the painted billboard.
func _sync_rig(key: String, kind: String, ground: Vector2, heading: Vector2,
		height: float, attacking: bool, moving: bool, speed: float,
		attack_clock: float, delta: float) -> bool:
	if _no_model.has(kind):
		return false
	var rig: SkyGearRig3D = _rigs.get(key)
	if rig == null:
		var path := model_path(kind)
		if not ResourceLoader.exists(path):
			_no_model[kind] = true
			return false
		rig = SkyGearRig3D.new()
		add_child(rig)
		if not rig.setup(path, height * WORLD_SCALE, LAYER_FIGURES):
			rig.queue_free()
			_no_model[kind] = true
			return false
		_rigs[key] = rig
	_used[key] = true
	var doing := "idle"
	if attacking:
		doing = "swing"
	elif moving and speed > 12.0:
		doing = "run"
	rig.want(doing, speed, attack_clock if attacking else 0.0)
	rig.place(ground, heading, WORLD_SCALE, delta)
	return true


## One figure: the right painted view, mirrored if it is heading right, running
## its cycle if that cycle has been delivered.
##
## Everything about which picture and which frame lives in `SkyGearSprites`, so
## this is only the part that is about being in a 3D scene. A cycle that has not
## been delivered returns -1 and the still is used, which is why this could be
## written before the art was.
func _draw_figure(key: String, kind: String, ground: Vector2, heading: Vector2,
		height: float, attacking: bool, moving: bool, clock: float,
		attack_clock: float) -> void:
	var v: Dictionary = SkyGearSprites.view_for(heading, attacking)
	var front: bool = v.front
	## Front views only. The cycles are authored facing the camera; a figure
	## walking away keeps its still, which is what the back view exists for.
	var cycle := ""
	if front:
		if attacking:
			cycle = "%s_attack" % kind
		elif moving:
			cycle = "%s_run" % kind
		else:
			cycle = "%s_idle" % kind
	var time: float = attack_clock if attacking else clock
	var index: int = SkyGearSprites.frame(cycle, time) if cycle != "" else -1
	var texture: Texture2D = SkyGearSprites.strip(cycle) if index >= 0 \
		else SkyGearSprites.still(kind, str(v.view))
	if texture == null:
		return
	_used[key] = true
	var node: Sprite3D = _billboards.get(key)
	if node == null:
		## From the free list when there is one. Every property below is set
		## unconditionally, which is what makes a reused node safe to hand out:
		## nothing carries over from whoever had it last.
		node = _free_billboards.pop_back() if not _free_billboards.is_empty() 			else Sprite3D.new()
		node.visible = true
		node.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		node.shaded = false
		node.double_sided = true
		node.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		node.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.layers = LAYER_FIGURES
		if node.get_parent() == null:
			add_child(node)
		_billboards[key] = node
		_peak_billboards = maxi(_peak_billboards, _billboards.size())
	node.texture = texture
	node.modulate = Color.WHITE
	node.flip_h = bool(v.mirror)
	var tall: float = float(texture.get_height())
	if index >= 0:
		var rect: Rect2 = SkyGearSprites.frame_rect(cycle, index, texture)
		node.region_enabled = true
		node.region_rect = rect
		tall = rect.size.y
	else:
		node.region_enabled = false
	node.pixel_size = height * WORLD_SCALE / maxf(1.0, tall)
	node.position = Vector3(ground.x * WORLD_SCALE, height * WORLD_SCALE * 0.5,
		ground.y * WORLD_SCALE)


## One billboard per entity, pooled. `BILLBOARD_ENABLED` is what makes a flat
## sprite stand up and face the camera — which is exactly what the browser's
## renderer does by hand, and what the art is painted for.
func _place(key: String, texture: Texture2D, ground: Vector2, height_units: float,
		lift: float = 0.0, tint: Color = Color.WHITE) -> void:
	if texture == null:
		return
	_used[key] = true
	var node: Sprite3D = _billboards.get(key)
	if node == null:
		## From the free list when there is one. Every property below is set
		## unconditionally, which is what makes a reused node safe to hand out:
		## nothing carries over from whoever had it last.
		node = _free_billboards.pop_back() if not _free_billboards.is_empty() 			else Sprite3D.new()
		node.visible = true
		node.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		## NOT shaded. Every character sprite in `assets/` was generated with the
		## scene's lighting already painted into it — steel-blue rim from the
		## upper left, warm bounce from below right — which is what the browser
		## composites and what the level-kit brief specifies. Re-lighting them
		## with the same two lamps applies the treatment twice and the result is
		## a deck of silhouettes.
		node.shaded = false
		node.double_sided = true
		node.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		node.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.layers = LAYER_FIGURES
		if node.get_parent() == null:
			add_child(node)
		_billboards[key] = node
		_peak_billboards = maxi(_peak_billboards, _billboards.size())
	node.texture = texture
	node.modulate = tint
	# scale so the sprite stands `height_units` tall in ground units, and lift it
	# by half of that so its feet meet the deck rather than its middle
	var pixel_height: float = maxf(1.0, float(texture.get_height()))
	node.pixel_size = height_units * WORLD_SCALE / pixel_height
	node.position = Vector3(ground.x * WORLD_SCALE,
		(height_units * 0.5 + lift) * WORLD_SCALE, ground.y * WORLD_SCALE)


## A hot point in the air — a bolt, a spark. Unshaded and additive, so the bloom
## catches it.
func _spark(key: String, ground: Vector2, height: float, size: float, colour: Color) -> void:
	_used[key] = true
	var node: Sprite3D = _billboards.get(key)
	if node == null:
		## From the free list when there is one. Every property below is set
		## unconditionally, which is what makes a reused node safe to hand out:
		## nothing carries over from whoever had it last.
		node = _free_billboards.pop_back() if not _free_billboards.is_empty() 			else Sprite3D.new()
		node.visible = true
		node.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		node.shaded = false
		node.double_sided = true
		node.transparent = true
		node.texture = _spark_texture()
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		mat.albedo_texture = _spark_texture()
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		node.material_override = mat
		node.layers = LAYER_FIGURES
		if node.get_parent() == null:
			add_child(node)
		_billboards[key] = node
		_peak_billboards = maxi(_peak_billboards, _billboards.size())
	if node.material_override is StandardMaterial3D:
		(node.material_override as StandardMaterial3D).albedo_color = colour
	node.pixel_size = size * WORLD_SCALE / 64.0
	node.position = Vector3(ground.x * WORLD_SCALE, height * WORLD_SCALE,
		ground.y * WORLD_SCALE)


## Where a sight line from the camera LEAVES a rect on the ground plane, as a
## parameter along the line, or -1 if it never crosses it. Slab test.
##
## The far side, not the near one. Looking down at 41 degrees from 760 up, the
## edge of a cargo run that hides anything is its far-top edge — the near face is
## the one you are looking over. Testing the entry point said nothing was ever
## occluded, which was technically a passing test.
static func _exit_t(a: Vector2, b: Vector2, rect: Rect2) -> float:
	var d := b - a
	var t_min := 0.0
	var t_max := 1.0
	for axis in 2:
		var origin: float = a.x if axis == 0 else a.y
		var delta: float = d.x if axis == 0 else d.y
		var lo: float = rect.position.x if axis == 0 else rect.position.y
		var hi: float = rect.end.x if axis == 0 else rect.end.y
		if absf(delta) < 0.0001:
			if origin < lo or origin > hi:
				return -1.0
			continue
		var t1 := (lo - origin) / delta
		var t2 := (hi - origin) / delta
		if t1 > t2:
			var swap := t1
			t1 = t2
			t2 = swap
		t_min = maxf(t_min, t1)
		t_max = minf(t_max, t2)
		if t_min > t_max:
			return -1.0
	if t_max <= 0.0 or t_min >= 1.0:
		return -1.0
	return minf(t_max, 1.0)


## Is this thing standing in the shadow of a cargo run, from where we are
## looking?
##
## The browser calls this its x-ray pass and turns it on for v3 onward, because
## the alternative is that a boarder walks behind a container and stops existing
## for two seconds — which in a game where the thing killing you is usually the
## one you lost track of is not an aesthetic problem. The cargo runs are the only
## geometry tall enough to hide anybody, so this is eight rectangles and a slab
## test rather than a physics query.
##
## The probe is the TORSO, not the head. From this camera a 125-tall box hides
## about forty units of deck behind it, so a boarder tucked against one is cut
## off at the chest while their head is still in clear air — which is exactly the
## case worth silhouetting, and the case a head test misses entirely.
func _occluded(ground: Vector2, stand: float) -> bool:
	var eye := Vector2(_focus.x, _focus.y + CAM_NEAR)
	var torso := stand * 0.5
	for rect: Rect2 in SkyGearGame.CARGO_RECTS:
		var t := _exit_t(eye, ground, rect.grow(4.0))
		if t < 0.0 or t >= 0.999:
			continue
		if CAM_HEIGHT + (torso - CAM_HEIGHT) * t < WALL_MODULE_H:
			return true
	return false


## The silhouette itself: the same sprite, flattened to one colour and drawn
## through everything. Pooled alongside the real one and only present while it
## is needed, so a clear deck costs nothing.
func _xray(key: String, ground: Vector2, height_units: float, tint: Color) -> void:
	var source: Sprite3D = _billboards.get(key)
	if source == null or source.texture == null:
		return
	if not _occluded(ground, height_units):
		return
	var ghost_key := "xr_" + key
	_used[ghost_key] = true
	var ghost: Sprite3D = _billboards.get(ghost_key)
	if ghost == null:
		ghost = _free_billboards.pop_back() if not _free_billboards.is_empty() 			else Sprite3D.new()
		ghost.visible = true
		ghost.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		ghost.shaded = false
		ghost.double_sided = true
		ghost.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		ghost.layers = LAYER_FIGURES
		ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ghost.no_depth_test = true
		ghost.render_priority = 8
		if ghost.get_parent() == null:
			add_child(ghost)
		_billboards[ghost_key] = ghost
	ghost.texture = source.texture
	ghost.pixel_size = source.pixel_size
	ghost.position = source.position
	ghost.modulate = tint


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
