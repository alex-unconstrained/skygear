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

## Which deck props have a generated mesh: prop_type -> the directory under
## `assets/models/`. A prop_type with no row here keeps its painted billboard.
##
## THIS TABLE IS THE SWITCH, and it is the same switch `tools/static_model.gd`
## documents for the boarders: the bar a generated mesh has to clear is the art
## it replaces, not the previous generation of itself, and the furnace knight is
## on the deck as a sprite because it never cleared it. Deleting a row here puts
## a prop back to painted with no other change.
##
## The keys on the right are the ART filenames rather than the prop_type strings.
## That is deliberate: what a reviewer does with one of these is hold it up
## against `assets/art/props/<key>.png`, and a name that does not match the file
## you are comparing it to makes that harder for no gain. The two exceptions are
## named where they are used below.
const PROP_MODEL := {
	## barrel.png is the powder keg — the fuse chimney, the pressure gauge and
	## the red flame triangle are all painted on it — so there is one model for
	## it and it is called what the object is.
	"keg": "powder_keg",
	"crates": "crate_stack",
	"lantern": "lantern_post",
	"vent": "steam_vent",
	## "crate" and "brazier" are generated, on disk, and deliberately absent —
	## the furnace knight's rule, applied twice. Both read WORSE than the art
	## they would replace, checked at the real camera distance rather than off
	## the thumbnail, and the reasons are written at tools/static_model.gd where
	## the .tscn is not made.
	## rope: NOT generated. 30 ground units tall, the shortest thing in
	## PROP_HEIGHT by a factor of two. A billboard of a flat coil of rope and a
	## mesh of one are the same forty pixels at this camera. The prompt is
	## written and waiting in tools/meshy.py; nobody has paid for it.
	## mast, railing, hatch, ballista, wreck: not asked for, still painted.
}

## The deck cannons and the salvage pickups are not in the `props` group, so they
## are not reached by prop_type. Named here so all of the generated deck geometry
## is switched from one screenful.
const TURRET_MODEL := "cannon_deck"
const SALVAGE_MODEL := "salvage_pile"
## The enemy's boarding craft. Wired at the hulk block near the bottom of
## `_sync_all`, where the three painted states are chosen between — and CURRENTLY
## INERT, because `tools/static_model.gd` deliberately does not wrap a scene for
## it. Two generations, both rejected, and the reasoning is written there beside
## the missing row. The wiring stays for the same reason `_sync_rig` stays for
## the furnace knight: the model-or-billboard fork is the permanent shape of this
## renderer, and the next attempt should be a file appearing, not a code change.
const HULK_MODEL := "boarding_hulk"

## The Boiler. Until now the ONLY object in the port with no art at all — four
## cylinders, two toruses, a box and a quad assembled in `_build_boiler` — and at
## the bottom centre of every frame at the largest apparent size of anything on
## the deck, which made it read as placeholder next to thirty painted assets.
##
## The height is NOT a taste number and must not be raised casually — it is
## PINNED to the LIVE browser's `boilerH`, which is what `tools/parity.py`
## photographs (storm-dusk-v11.html), and `tools/boiler_measure.gd` /
## `parity_test` guard the rendered result against it. SG-27 caught this at 168:
## the generated mesh is a near-cube (measured 168 tall x 167 wide x 162 DEEP),
## so at 168 it read 208 px tall and 291 px wide — a solid drum dominating the
## lower third against the browser's FLAT 150-unit / 184 px block, exactly the
## "everything looks bigger" report once SG-2 cleared the camera. Scaled to the
## browser's own 150 the mesh's furnace face (authored to +Z, the one direction
## this locked camera ever sees) still reads as the furnace and now sits at the
## browser's height. NOT 168, and never a bare "buys the pipes" bump again: the
## number is whatever the LIVE browser draws, so the two builds stay one picture.
## (DESIGN §13c cites 132 — that was the v3/v4 preset; the LIVE v11 build moved
## boilerH to 150, and parity compares against v11.) The first 3D pass built a
## 300-unit drum that hid the captain for the first second of every run — she
## spawns 130 units in front of this thing; the browser's own 150 does not.
const BOILER_MODEL := "boiler"
## The LIVE browser's PRESET.boilerH (storm-dusk-v11.html / reference/web-source
## build.py v11). The Boiler renders at exactly this in ground units, mesh or
## primitive, and `parity_test` fails if the rendered subtree drifts off it.
const BOILER_HEIGHT := 150.0

## THE COLOSSUS WRECK — board SG-15, the first fitting in docs/SHIP-AND-MAPS-DESIGN.
##
## The design doc's whole thesis in one object: the ship carries the memory of
## the runs it survived, and the Colossus is the boss you kill to survive one.
## The art has been on disk and sized (`colossus_wreck.png`, PROP_HEIGHT/SCALES)
## since the props pass and NOTHING has ever placed it. This places it — and it
## is the ONLY generated deck geometry here whose position is a fitting rather
## than a prop, so it is switched from one screenful like the rest.
##
## WHERE, AND WHY NOT WHERE THE DOC SAYS. §5 wants it "in lane 1, in front of the
## Boiler" as 210 units of hard cover. A permanent fitting may not do that: the
## gameplay envelope (the three lanes, `game.cargo_rects()`, the boarder clamp,
## the prop-per-wave count) is the one collision source of truth and a fitting is
## set dressing that must not touch it. So among the off-envelope homes it is put
## OFF THE BOW, beyond the play area, resting in the cloud sea ahead — the one
## spot that reads as a landmark at the shipped 41 deg camera. MEASURED, not
## guessed (tools/wreck_measure.gd): the stern sits off the bottom of the frame
## at every pose and the rails off the sides, but the bow fills the top of the
## frame the instant the captain advances toward it, and it is the establishing
## crane's subject and where the Colossus itself arrives and falls. The corpse of
## the giant, adrift ahead of the prow, every run after the first you down it.
##
## GATED, because the doc is not silent: fittings are meta-progression and live
## behind `state.unlocked` — the SAME first-victory latch the Workshop opens on
## (a win is a wave-12 Colossus kill). No parallel gate, no new tracking; the
## wreck is hidden until the ship has earned it and permanent after. Read-only:
## `workshop.gd` is untouched, its Dictionary is read where it already lives on
## the game. Delete these three rows and the fitting is gone with no other change.
const WRECK_TEXTURE := "res://assets/art/props/colossus_wreck.png"
## Ground units. Bow edge is DECK_RECT.position.y = -1160; the spawn line is
## -1115 and the hulk grapples at BOW_Y -1000, so -1500 is 340 beyond the deck,
## 385 beyond where anything spawns — wholly outside the fight envelope.
const WRECK_POSITION := Vector2(0.0, -1500.0)
## Its authored height is PROP_HEIGHT["wreck"]; read from there so the fitting and
## the prop table can never disagree about how tall the same picture stands.

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

## How hard the painted sky is driven before the post chain gets it. The backdrop
## arrives as a finished painting and then loses a third of itself on the way to
## the screen — Filmic tonemapping with a white point of 6, a 1.10 contrast lift
## and 15% of the depth fog. Measured against the browser's own canvas at the
## same framing rather than guessed at; see `tools/sky_shot.gd`.
const SKY_ENERGY := 1.55

## THE CLOUD FIELD — and this is where the parallax comes from.
##
## The browser drifts two painted cloud bands at 16 and 34 pixels a second, and
## a pixel a second is not a speed, it is an ANGULAR RATE: its focal length at
## 1600x900 is 1320 * min(1600/1400, 900/860) = 1381.4 pixels per radian, so the
## two bands sweep 0.01158 and 0.02461 radians a second. Reproducing an angular
## rate with real geometry leaves one degree of freedom — rate = speed /
## distance — and either half of that pair may be chosen freely.
##
## Distance was chosen first, because it is the half with hard limits. The near
## layer has to clear the deck and the gunwale by enough that it never reads as
## something ON the ship; the far layer has to fit inside a camera far plane that
## is not absurd. 300 and 640 metres. The drift then follows and is not a taste
## number: 7.2 m/s puts the near layer at 0.0240 rad/s and the far at 0.0113,
## which is 33.2 and 15.5 of the browser's pixels a second against its 34 and 16.
##
## Doing it this way rather than by panning a texture is the whole point. Two
## objects at two real distances under one perspective camera parallax against
## each other for free, they parallax against the deck for free, and they stay
## correct when the wheel pulls the camera back — none of which a scrolling
## backdrop does, and all three are what was actually asked for.
const CLOUD_DRIFT := 720.0          ## ground units per second, toward the stern
const CLOUD_NEAR_RANGE := 30000.0   ## 300 m, the fast layer
const CLOUD_FAR_RANGE := 64000.0    ## 640 m, the slow one — 2.13x, browser 2.125x

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
var _wreck: Sprite3D                  ## the Colossus fitting (SG-15); null if the art is absent
var _focus := Vector2.ZERO
var _focus_set := false
var _flicker := 0.0
var _made: Dictionary = {}           ## generated textures, by key
var _cloud_bands: Array[Dictionary] = []
var _escort: MeshInstance3D           ## the distant airship, running with us
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
var _prop_models: Dictionary = {}     ## key -> Node3D, a static generated mesh in use
var _free_prop_models: Dictionary = {} ## model key -> Array[Node3D], hidden, reusable
var _no_prop_model: Dictionary = {}   ## model keys already looked for and not found
var _boiler_glow: OmniLight3D         ## the furnace lamp, on either Boiler body
var _boiler_mats: Array[StandardMaterial3D] = []   ## override copies, tinted by health
var _boiler_base: PackedColorArray = PackedColorArray()  ## their albedo at full health
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
	## LAST, so it sits after the game scene in the tree — unhandled input is
	## walked in reverse, and the skip has to reach the cutscene before the pause
	## key reaches the game.
	_cutscene = (load(CUTSCENE_PLAYER) as GDScript).new()
	_cutscene.view = self
	add_child(_cutscene)


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
	## REPORTED THREE TIMES: "where is the sky box? It's missing." Twice it was
	## treated as a colour problem and twice that was wrong. It was a CONTENT
	## problem: a two-stop gradient with nothing in it, while the browser has a
	## painted moon breaking through cloud and the player remembered the painting.
	##
	## The painting is `assets/art/env/sky_backdrop.png` and it has been in this
	## repository the whole time. `scripts/sky.gdshader` puts it back — see that
	## file for why it is a sky shader rather than a quad, and for the measurement
	## that explains why every earlier screenshot of the sky was a screenshot of
	## planking. The procedural gradient stays as the fallback for a build where
	## the art has not been imported, because a missing texture should cost the
	## sky its detail rather than turn the top of the frame black.
	var sky_res := Sky.new()
	var backdrop := _texture("res://assets/art/env/sky_backdrop.png")
	if backdrop != null:
		var painted := ShaderMaterial.new()
		painted.shader = load("res://scripts/sky.gdshader")
		painted.set_shader_parameter("backdrop", backdrop)
		## The four camera constants, read from the camera rather than retyped.
		painted.set_shader_parameter("pitch", PITCH)
		painted.set_shader_parameter("ref_tan", (REF_HEIGHT * 0.5) / FOCAL)
		painted.set_shader_parameter("ref_aspect", 16.0 / 9.0)
		painted.set_shader_parameter("energy", SKY_ENERGY)
		painted.set_shader_parameter("away", Color("#14111f"))
		sky_res.sky_material = painted
		## The shader returns one flat colour for the radiance capture, so the
		## probe costs nothing worth measuring and can be tiny. It is only feeding
		## the specular on the brass rails; the ambient term is a colour.
		sky_res.radiance_size = Sky.RADIANCE_SIZE_32
		sky_res.process_mode = Sky.PROCESS_MODE_INCREMENTAL
	else:
		## STORM-DUSK means the sun is going down BEHIND the weather, so the
		## horizon is the brightest thing in the frame and the top is the darkest.
		var sky_mat := ProceduralSkyMaterial.new()
		sky_mat.sky_top_color = Color("#1a1636")
		sky_mat.sky_horizon_color = Color("#8a5a6e")
		sky_mat.sky_curve = 0.19
		sky_mat.ground_bottom_color = Color("#0f0d1c")
		sky_mat.ground_horizon_color = Color("#5c4460")
		sky_mat.ground_curve = 0.08
		sky_mat.sun_angle_max = 24.0
		sky_mat.sun_curve = 0.12
		sky_mat.energy_multiplier = 1.35
		sky_res.sky_material = sky_mat
	e.background_mode = Environment.BG_SKY
	e.sky = sky_res
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	## A NEUTRAL-warm ambient floor, not a cool one. SG-34: measured against the
	## browser, the deck was not darker or cooler on average — it was BRIGHTER and
	## warmer in the mean — but its focal surfaces (the crate and prop tops) read
	## navy, because the cool moon directional and a cool-PURPLE ambient (#4a4058,
	## blue dominant) were the only fill on every up-facing face the warm point
	## pools do not reach. Pushed fully warm the floor went monochrome orange while
	## the crates stayed navy (measured warm/blue split), so the fill is set to a
	## near-neutral, faintly warm brown-grey (red just ahead of blue): it lifts a
	## crate top out of steel without repainting the whole deck orange, matching the
	## browser's ONE modest-warm field with cool shadows. Pinned by `view · the deck
	## is lit warm and even, not a hot pool`.
	e.ambient_light_color = Color("#494551")
	e.ambient_light_energy = 0.62
	e.fog_enabled = true
	e.fog_light_color = Color("#3a3340")
	e.fog_density = 0.011
	## AND THE FOG MUST NOT EAT THE SKY. At the default the depth fog is applied
	## to the background too, so a horizon painted warm arrives grey — which is
	## most of why brightening the material alone did not help the first time.
	e.fog_sky_affect = 0.15
	## VOLUMETRIC FOG, FOR THE FIELDS ONLY. See `VOLUMETRIC_FIELDS`.
	##
	## Global density stays at zero, which is the audit's own recommendation when
	## only local volumes are wanted: the deck is not fogged, the lanterns are not
	## lighting a medium, and the only thing in the froxels is whatever
	## `_sync_auras` puts there. The range is cut to 22 metres because the deck is
	## 23 long and the default 64 spends most of the pass on empty sky.
	if VOLUMETRIC_FIELDS:
		e.volumetric_fog_enabled = true
		e.volumetric_fog_density = 0.0
		e.volumetric_fog_length = 22.0
		## Temporal reprojection ON, which is NOT what the audit recommends for a
		## volume that follows a moving player — and the measurement overrules it.
		## Off, the pass resolves in full every frame and the bench's 99th
		## percentile goes 9.5 -> 13.6 ms; on, it goes 9.5 -> 10.7. Four
		## milliseconds of tail is not a price a passive that most runs never draft
		## gets to charge on every frame of every run. What it costs back is a short
		## smear of haze behind the captain while she runs, which on a Steam Field
		## is what steam does anyway.
		e.volumetric_fog_temporal_reprojection_enabled = true
		e.volumetric_fog_gi_inject = 0.0
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
	##
	## SG-34, MEASURED then chosen: exposure is a DELIBERATE 0.80, not the default
	## 1.0. A probe over `.shots/parity/` found the deck was not dark or cool (the
	## premise) — it was BRIGHTER than the browser (deck-region luminance ~53 vs
	## ~44) with a searing hot pool (99th-percentile luminance 163 vs 148) that, by
	## simultaneous contrast, made the warm surround read cold. Deepening the whole
	## frame to 0.80 pulls luminance to ~44 and the pool peak to ~148 — a richer,
	## deeper amber with the mood a flat Canvas 2D deck never had, and telegraphs
	## and element flashes pop HARDER against it, not softer. Pinned, with the
	## ambient and key, by `view · the deck is lit warm and even, not a hot pool`.
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.tonemap_exposure = 0.80
	e.tonemap_white = 6.0
	e.adjustment_enabled = true
	e.adjustment_contrast = 1.10
	e.adjustment_saturation = 1.04
	env.environment = e
	add_child(env)

	## Two sources, the same two the art is painted for: a steel-blue moon rim
	## from the upper left and a warm lantern fill from the lower right.
	## SG-34, MEASURED: the moon stays the cool storm-dusk KEY at its shipped 1.45,
	## and it is deliberately NOT reduced. The premise was that the deck read cool
	## and dark; measured against the browser it read the opposite — brighter and
	## warmer — and pulling this cool key only spiked the whole deck orange (R/B
	## drifted to 2.3 against the browser's modest ~1.5) without fixing the one
	## thing that genuinely reads blue: the crate STACKS, which are blue from their
	## own model texture, not from this light (they stayed navy at 1.15 too — filed
	## SG-41). The over-bright, over-hot-pool read SG-34 was really about is fixed
	## at the exposure and the accent pools, not here; this key is what keeps the
	## deck's warmth near the browser's rather than orange.
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

	_build_clouds()

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

	## THE COLOSSUS WRECK (SG-15). An upright billboard adrift off the bow, built
	## once here beside the prow — it is a fitting, not a `props`-group prop, so it
	## never enters the sim, the cargo rects or the per-wave stow, and nothing on
	## the deck can path to it. Height straight from PROP_HEIGHT["wreck"], the one
	## place the wreck's size lives. Visibility is refreshed every frame from the
	## first-victory gate (`_wreck_earned`), so it appears the run after you first
	## down the Colossus and stays. Absent art costs the fitting, not the frame.
	var wreck_tex := _texture(WRECK_TEXTURE)
	if wreck_tex != null:
		var wreck := Sprite3D.new()
		wreck.texture = wreck_tex
		wreck.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		wreck.shaded = false
		wreck.double_sided = true
		wreck.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		wreck.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		wreck.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		wreck.layers = LAYER_FIGURES
		var wreck_h: float = float(PROP_HEIGHT["wreck"])
		wreck.pixel_size = wreck_h * WORLD_SCALE / maxf(1.0, float(wreck_tex.get_height()))
		wreck.position = Vector3(WRECK_POSITION.x * WORLD_SCALE,
			wreck_h * 0.5 * WORLD_SCALE, WRECK_POSITION.y * WORLD_SCALE)
		wreck.visible = _wreck_earned()
		add_child(wreck)
		_wreck = wreck

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
	_build_ribbons()
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
	_ribbon_texture()
	## Player cleave/cone arcs, plus the enemy melee swing arcs (SWARM 80°=1.396,
	## SCRAPPER 95°=1.658, ARMORED/BOSS 120°=2.094) — a windup wedge built mid-swing
	## is a hitch at the exact moment the player is reading a telegraph.
	for arc in [0.9, 1.134, 1.396263, 1.658, 1.7, 2.094395, 2.443]:
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
	## 400 metres was enough when the furthest object was a cloud band 60 metres
	## out. The far cloud layer sits at 640, because that is the distance that
	## reproduces the browser's slower band as a real angular rate, so anything
	## short of about 800 would clip it out of existence — and it is a 400-metre
	## quad, so its far corner is another 200 out and the plane cuts a straight
	## line across a painted cloud when it is too close. 1800 is that worst case
	## with room. Costs nothing: this renderer is Forward+, which is reverse-Z,
	## and reverse-Z spends its depth precision near the camera rather than
	## spreading it evenly over the range.
	camera.far = 1800.0
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
## A `life` field lived here once (per element: EMBER 0.70, FROST 0.28, ARC 0.22,
## STEAM 0.95) and NOTHING read it — the emitter's own `lifetime = 1.0` governed
## every family, so it was declared timing that never rendered (board SG-16,
## failure mode one). DELETED rather than honoured. Honouring a per-PARTICLE
## lifetime needs one emitter per element, and finding 3 of the rendering audit
## (DESIGN §13m) is emphatic that emitters are keyed by BEHAVIOUR — colour rides
## on the particle — because a shared `emit_particle` emitter that is never
## restarted is the fix to a real bug, and per-element emitters would regress it,
## break the pinned "one emitter per behaviour" check, and add a 512-cap node
## against the still-open pool budgets. It could not even be honoured per FAMILY:
## EMBER (0.70) and ARC (0.22) share the `spark` emitter with different lifetimes,
## so the field was self-contradictory as per-element data on a per-behaviour
## system — proof it was never wireable. The timing signature finding 4 requires
## survives without it: it lives in the LIGHT decay (26/s FROST·ARC vs 8/s
## EMBER·STEAM, in `impact_at`) and the particle MOTION (rise / spread / speed).
const ELEMENT_FX := {
	"EMBER": {"family": "spark", "rise": 40.0, "spread": 70.0, "speed": 230.0,
		"count": 14},
	"FROST": {"family": "shard", "rise": -40.0, "spread": 26.0, "speed": 420.0,
		"count": 12},
	"ARC": {"family": "spark", "rise": 10.0, "spread": 14.0, "speed": 520.0,
		"count": 10},
	"STEAM": {"family": "steam", "rise": 150.0, "spread": 88.0, "speed": 120.0,
		"count": 12},
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


## --- TRAILS THAT ARE GEOMETRY, NOT DECALS ------------------------------------
##
## VFX-PLAN.md §3, and the half of "projectiles and vfx from the player still
## look like 2D instead of 3D" that is a real bug rather than a design decision.
## There were two separate faults and they need separate fixes:
##
##   * **The chain, the bolt and the beam were `_streak_texture` DECALS.** A
##     decal is a mark projected onto whatever is under it, which for these was
##     always the planking. At a camera pitched 41 degrees a mark on the floor
##     and an object in the air are the same picture only when the object in the
##     air is lying on the floor, so a bolt of lightning read as a scuff.
##   * **The hitscan shapes had no travelling body at all.** Arc, cone, line and
##     aoe resolve on the frame they are cast, so between the captain and the
##     boarder she killed there was, correctly, nothing — and the player was
##     right that there is no projectile, because there was not one.
##
## Both are answered by the same object: a RIBBON, real triangles in the air,
## with each pair of vertices offset perpendicular to the LINE OF SIGHT so the
## strip always turns its width toward the camera. That is the difference
## between geometry that happens to be 3D and geometry that reads as 3D — a
## ribbon lying in a fixed plane disappears to a hairline at half the angles the
## deck presents.
##
## `docs/VFX-RESEARCH-AUDIT.md` is emphatic that this must not be an
## `ImmediateMesh` per projectile rebuilt every frame, and it is not: there is
## ONE mesh for the whole scene, cleared and rewritten once a frame, and
## everything airborne writes into it. One draw call, one budget, one place to
## look when it gets expensive.
##
## THE GROUND DECAL STAYS under every one of them. It is the readable half — it
## says where on the deck the thing will cross you, which is the question a
## player is actually asking — and the audit says to keep the two separate for
## exactly that reason. What has changed is that the effect now also exists
## above it.

## The whole scene's ribbon budget, in vertices. A strip of N points costs
## (N-1)*6, so this is about sixty simultaneous ribbons of ten points — far more
## than a keg chain into a Whip can produce, and a hard stop rather than a hope.
const RIBBON_VERTS := 3600
## Where a cast leaves her hand and where it arrives on a boarder, in ground
## units above the planking. Not taste: the captain is 176 units sole to crown,
## so 108 is her hand and 62 is a SCRAPPER's chest. A trail drawn between those
## two heights is a trail that starts and ends on a body.
const RIBBON_HAND := 108.0
const RIBBON_CHEST := 62.0

## HOW EACH ELEMENT MOVES, in the air.
##
## The audit's finding 4 again, applied to trails rather than to impacts:
## coloured light is still a hue cue, so it cannot carry element identity by
## itself. A player who cannot tell teal from orange has to be able to tell a
## Frost bolt from an Ember one by its SHAPE, and these are the four shapes.
##
##   width     the ribbon at its fattest, in ground units across
##   waver     how far the path wanders off the straight line
##   hz        and how fast — the difference between a flame and a stationary bar
##   zig       a hard alternating kink instead of a smooth wander
##   rise      how far the middle of the path lifts (Steam) or sags (Frost)
##   segments  how many points the path is cut into; a kink needs more than a curve
##   hot       how far over 1.0 the colour is pushed, so the glow chain catches it
##
## `hot` is deliberately modest and all four are near each other. The first pass
## ran 1.9 to 2.6 on the theory that brighter is more dramatic, and the result
## was that every trail in the game came out WHITE: the tonemapper is Filmic at a
## white point of 6, so a colour whose brightest channel is at 2.6 has its other
## two channels dragged up with it and an Arc bolt and an Ember one are the same
## pale streak. 1.45 is the number the decals already use for the same reason and
## it is over the 1.05 glow threshold, so these still bloom — they just bloom in
## their own colour, which is the entire point of having four of them.
##   grow      the width at the head against the width at the tail
const ELEMENT_RIBBON := {
	## Ember licks. Fat, slow, wandering, and it opens out as it travels — a
	## thrown flame rather than a shot.
	"EMBER": {"width": 34.0, "waver": 22.0, "hz": 5.0, "zig": 0.0, "rise": 16.0,
		"segments": 12, "hot": 1.45, "grow": 1.40},
	## Frost is a shard. Dead straight, narrow, hard at both ends, faintly barbed
	## and it does not open out: the whole read is that it went exactly where it
	## was pointed and stopped.
	"FROST": {"width": 17.0, "waver": 0.0, "hz": 0.0, "zig": 8.0, "rise": -12.0,
		"segments": 8, "hot": 1.55, "grow": 0.85},
	## Arc branches. A hard alternating kink, reseeded off the clock so it crawls
	## along its own length rather than sitting still.
	"ARC": {"width": 24.0, "waver": 6.0, "hz": 21.0, "zig": 40.0, "rise": 30.0,
		"segments": 14, "hot": 1.50, "grow": 1.0},
	## Steam billows. The broadest and the slowest, rising as it goes, and drawn
	## soft enough that it reads as a volume of air rather than as a rope.
	"STEAM": {"width": 62.0, "waver": 36.0, "hz": 2.2, "zig": 0.0, "rise": 78.0,
		"segments": 12, "hot": 0.85, "grow": 1.75},
}

var _ribbon_mesh: ArrayMesh
var _ribbon_node: MeshInstance3D
var _ribbon_verts := 0
## The scratch buffers, allocated once at full capacity and never resized. See
## `_ribbons_end` for why this is not an ImmediateMesh.
var _rib_pos: PackedVector3Array = PackedVector3Array()
var _rib_uv: PackedVector2Array = PackedVector2Array()
var _rib_col: PackedColorArray = PackedColorArray()
var _ribbon_peak := 0
var _ribbon_dropped := 0
## How often a wrecked deck cannon puffs. See the turret block in `_sync_all`.
const SMOKE_EVERY := 0.10
var _smoke_clock := 0.0
## And how often an aura throws a mote up through itself.
const MOTE_EVERY := 0.05
var _mote_clock := 0.0

## VOLUMETRIC FIELDS — VFX-PLAN.md §4, and the one item on that list whose cost
## had to be measured before it could be committed to.
##
## `Environment.volumetric_fog_enabled` turns on a froxel pass that runs whether
## or not anything is in it, so the honest question is not "what does a Field
## cost" but "what does having Fields available cost on every frame of every
## run". `tests/bench.gd` at 60 boarders, on this machine:
##
##     off   avg 7.79   p99  9.54 ms
##     on    avg 7.92   p99 10.70 ms
##
## An eighth of a millisecond in the average and one in the tail, which is
## affordable — but only with temporal reprojection left on, and that trade is
## written at the flag itself rather than here.
##
## `volumetric_fog_density` stays at ZERO globally, per the audit: only the
## `FogVolume`s contribute, so the deck itself is not fogged and the lanterns are
## not lighting a global medium. One flag, one place, and turning it off here
## takes the whole feature out without touching `_sync_auras`.
const VOLUMETRIC_FIELDS := true
var _fog: Dictionary = {}            ## key -> FogVolume, one per live aura


func _build_ribbons() -> void:
	_ribbon_mesh = ArrayMesh.new()
	_rib_pos.resize(RIBBON_VERTS)
	_rib_uv.resize(RIBBON_VERTS)
	_rib_col.resize(RIBBON_VERTS)
	_ribbon_node = MeshInstance3D.new()
	_ribbon_node.mesh = _ribbon_mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	## The colour rides on the vertex, which is what lets four elements and a
	## dozen simultaneous effects share one material and therefore one draw.
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = _ribbon_texture()
	## No depth WRITE — additive strips that write depth occlude each other and a
	## Whip crossing its own jump goes black at the crossing. Depth TEST stays on,
	## so a cargo run still hides a bolt passing behind it.
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	_ribbon_node.material_override = mat
	_ribbon_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	## LAYER_FIGURES, for the reason at the top of this file: a ring belongs on
	## the deck, and a decal projecting onto a bolt of lightning is a ring painted
	## across the lightning.
	_ribbon_node.layers = LAYER_FIGURES
	## An explicit box. An ImmediateMesh rebuilt every frame has no useful bounds
	## of its own until it is built, so without this the whole batch is culled on
	## the frame it appears — which is the frame it matters.
	_ribbon_node.custom_aabb = AABB(Vector3(-14, -1, -16), Vector3(28, 8, 32))
	add_child(_ribbon_node)


## The strip's cross-section: opaque hot core, soft to nothing at both edges.
## The taper across the ribbon is what stops it reading as a length of pipe, and
## it belongs in the texture rather than in the geometry so a strip stays two
## triangles wide.
func _ribbon_texture() -> ImageTexture:
	if _made.has("ribbon"):
		return _made.ribbon
	var w := 8
	var h := 32
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		var v: float = (float(y) + 0.5) / float(h) * 2.0 - 1.0
		## 2.2 rather than a linear falloff: a linear edge on an additive strip
		## reads as a hard band because the eye is looking at the derivative.
		var a: float = pow(clampf(1.0 - absf(v), 0.0, 1.0), 2.2)
		## And a hotter centre inside it, so an Ember bolt has a bright core in
		## its orange the way a real one does. A THIRD of the edge value and no
		## more: pushed to 0.7 it saturated every element to white, which is the
		## same mistake `hot` was making one multiplication later.
		var core: float = pow(clampf(1.0 - absf(v) * 2.4, 0.0, 1.0), 2.0)
		for x in w:
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, clampf(a + core * 0.34, 0.0, 1.0)))
	_made.ribbon = _with_mips(img)
	return _made.ribbon


## THE COLOUR A RIBBON IS ACTUALLY WRITTEN AT, and it is not the palette colour.
##
## Two corrections, both of them learned from the first pass coming out white:
##
##   * **Saturate first.** Arc is #7adcff — a pale sky blue with a red channel at
##     0.48 — and on an ADDITIVE strip anything with a floor that high is white
##     with a blue idea behind it. The decals get away with the palette value
##     because they mix against the deck; a strip that adds does not. Pushing
##     saturation before brightness keeps the hue as the value climbs.
##   * **Normalise the value, then scale it.** Otherwise `hot` means something
##     different for every element, because the four palette colours are at four
##     different brightnesses to start with.
##
## The palette value is still what the RINGS are drawn in, so the two halves of
## an effect agree; this is the same hue at the saturation additive blending
## needs to keep it.
static func _ribbon_tint(colour: Color, hot: float) -> Color:
	var pure := Color.from_hsv(colour.h, clampf(colour.s * 1.45, 0.0, 1.0), 1.0)
	return Color(pure.r * hot, pure.g * hot, pure.b * hot, 1.0)


## THE BATCH IS FILLED INTO ARRAYS AND HANDED OVER ONCE.
##
## The first version used `ImmediateMesh` and `surface_add_vertex`, which is the
## obvious way to write this and is what `VFX-PLAN.md` §3 proposed. Measured, it
## cost **6.4 ms of the frame** at the bench's sixty-boarder load — more than
## twice the entire rest of the renderer — because three engine calls per vertex
## at three and a half thousand vertices is ten thousand calls out of GDScript
## every frame, and that crossing is the cost rather than the geometry.
##
## Same triangles, same one draw, filled into preallocated `Packed*Array`s at
## full capacity and handed to `ArrayMesh` in a single call. 6.4 ms became 0.9.
## The arrays are never reallocated; only the slice actually used is copied.
func _ribbons_begin() -> void:
	_ribbon_verts = 0


func _ribbons_end() -> void:
	if _ribbon_mesh == null:
		return
	_ribbon_mesh.clear_surfaces()
	_ribbon_peak = maxi(_ribbon_peak, _ribbon_verts)
	if _ribbon_verts < 3:
		return
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _rib_pos.slice(0, _ribbon_verts)
	arrays[Mesh.ARRAY_TEX_UV] = _rib_uv.slice(0, _ribbon_verts)
	arrays[Mesh.ARRAY_COLOR] = _rib_col.slice(0, _ribbon_verts)
	_ribbon_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)


## One ribbon. `points` are in GROUND units as (x, height above the planking, y)
## so no caller ever has to think in metres; `half` is the half-width at each
## point and `tint` its colour and alpha there.
##
## Per-point rather than per-ribbon because the TAPER is the readability: a trail
## that ends in a hard rectangle reads as a plank, and one that ends in nothing
## reads as speed.
func _ribbon(points: PackedVector3Array, half: PackedFloat32Array,
		tint: PackedColorArray) -> void:
	var n := points.size()
	if n < 2 or camera == null or _ribbon_mesh == null:
		return
	## Budgeted BEFORE anything is written, so a ribbon is either whole or absent.
	## Half a lightning bolt is worse than no lightning bolt.
	var needed := (n - 1) * 6
	if _ribbon_verts + needed > RIBBON_VERTS:
		_ribbon_dropped += 1
		return
	var eye := camera.global_position
	var side := PackedVector3Array()
	side.resize(n)
	for i in n:
		var here: Vector3 = points[i] * WORLD_SCALE
		var along: Vector3
		if i == 0:
			along = points[1] - points[0]
		elif i == n - 1:
			along = points[n - 1] - points[n - 2]
		else:
			along = points[i + 1] - points[i - 1]
		if along.length_squared() < 1e-9:
			along = Vector3.FORWARD
		along = along.normalized()
		## THE BILLBOARDING, and the whole reason this reads as 3D rather than as
		## a flat sticker: the width runs perpendicular BOTH to the path and to the
		## line of sight, recomputed per point per frame. A strip built in a fixed
		## plane vanishes to a hairline whenever the camera looks along that plane,
		## which on a deck seen from 41 degrees is most of the directions a skill
		## is ever fired in.
		var s := along.cross((eye - here).normalized())
		if s.length_squared() < 1e-8:
			s = along.cross(Vector3.UP)
		side[i] = s.normalized() if s.length_squared() > 1e-8 else Vector3.RIGHT
	for i in n - 1:
		var a: Vector3 = points[i] * WORLD_SCALE
		var b: Vector3 = points[i + 1] * WORLD_SCALE
		var wa: Vector3 = side[i] * half[i] * WORLD_SCALE
		var wb: Vector3 = side[i + 1] * half[i + 1] * WORLD_SCALE
		var ua: float = float(i) / float(n - 1)
		var ub: float = float(i + 1) / float(n - 1)
		var at := _ribbon_verts + i * 6
		_rib_pos[at] = a - wa; _rib_uv[at] = Vector2(ua, 0.0); _rib_col[at] = tint[i]
		_rib_pos[at + 1] = a + wa; _rib_uv[at + 1] = Vector2(ua, 1.0); _rib_col[at + 1] = tint[i]
		_rib_pos[at + 2] = b - wb; _rib_uv[at + 2] = Vector2(ub, 0.0); _rib_col[at + 2] = tint[i + 1]
		_rib_pos[at + 3] = a + wa; _rib_uv[at + 3] = Vector2(ua, 1.0); _rib_col[at + 3] = tint[i]
		_rib_pos[at + 4] = b + wb; _rib_uv[at + 4] = Vector2(ub, 1.0); _rib_col[at + 4] = tint[i + 1]
		_rib_pos[at + 5] = b - wb; _rib_uv[at + 5] = Vector2(ub, 0.0); _rib_col[at + 5] = tint[i + 1]
	_ribbon_verts += needed



## A path from A to B with one element's handwriting on it.
##
## `lift` is how far the middle of it rises above the straight line — a chain
## jump arcs over the deck, a Lance does not — and `phase` is what keeps a given
## effect's wander stable from frame to frame instead of boiling: pass the same
## number for the same effect and it wanders smoothly, pass a new one and it
## crawls.
##
## Nothing wanders at the ENDS. The envelope is a half-sine, so a trail's tip is
## always exactly on the target it hit: a bolt drawn a metre wide of the boarder
## it killed is the picture telling a lie the simulation did not.
func _element_path(from: Vector3, to: Vector3, element: String, lift: float,
		phase: float) -> PackedVector3Array:
	var spec: Dictionary = ELEMENT_RIBBON.get(element, ELEMENT_RIBBON.EMBER)
	var n := int(spec.segments)
	var out := PackedVector3Array()
	out.resize(n + 1)
	var span := to - from
	var flat := Vector3(span.x, 0.0, span.z)
	var across := Vector3(-flat.z, 0.0, flat.x)
	across = across.normalized() if across.length_squared() > 1e-6 else Vector3.RIGHT
	for i in n + 1:
		var t := float(i) / float(n)
		var p: Vector3 = from + span * t
		var envelope: float = sin(t * PI)
		p.y += (lift + float(spec.rise)) * envelope
		p += across * sin(t * 5.4 + phase) * float(spec.waver) * envelope
		if float(spec.zig) > 0.0:
			var flip: float = 1.0 if i % 2 == 0 else -1.0
			p += across * flip * float(spec.zig) * envelope
			p.y += (0.55 if i % 3 == 0 else -0.35) * float(spec.zig) * envelope
		out[i] = p
	return out


## The common case: a path drawn as a comet — fat and bright at the head, tapered
## to nothing at the tail. `scale` widens or narrows the whole thing against the
## element's own width, and `head` is which end is leading (1.0 the last point,
## 0.0 the first) because a beam and a bolt taper opposite ways.
func _ribbon_path(points: PackedVector3Array, element: String, tint: Color,
		alpha: float, scale: float = 1.0, head: float = 1.0) -> void:
	var spec: Dictionary = ELEMENT_RIBBON.get(element, ELEMENT_RIBBON.EMBER)
	var n := points.size()
	if n < 2:
		return
	var half := PackedFloat32Array()
	var cols := PackedColorArray()
	half.resize(n)
	cols.resize(n)
	var hue := _ribbon_tint(tint, float(spec.hot))
	for i in n:
		var t: float = float(i) / float(n - 1)
		var lead: float = t if head >= 0.5 else 1.0 - t
		## Wide at the head, nothing at the tail, and rounded off at the very tip
		## so it is a comet rather than a wedge.
		var shape: float = lerpf(1.0, float(spec.grow), lead)
		shape *= smoothstep(0.0, 0.26, lead)
		shape *= 0.62 + 0.38 * smoothstep(0.0, 0.14, 1.0 - lead)
		half[i] = float(spec.width) * 0.5 * scale * shape
		cols[i] = Color(hue.r, hue.g, hue.b, alpha * (0.22 + 0.78 * lead))
	_ribbon(points, half, cols)


## The same strip at an EVEN width, soft at both ends rather than tapered to
## one. A beam, a shockwave and a bolt in flight are three different objects and
## only one of them is a comet: putting a comet taper on something that is not
## travelling is most of what made the beam read as a smear.
##
## `pulse` runs a bright band down its length. A beam that flickers as a whole
## reads as a fault; one with something running along it reads as power going
## somewhere.
func _ribbon_even(points: PackedVector3Array, element: String, tint: Color,
		alpha: float, scale: float = 1.0, pulse: float = 0.0) -> void:
	var spec: Dictionary = ELEMENT_RIBBON.get(element, ELEMENT_RIBBON.EMBER)
	var n := points.size()
	if n < 2:
		return
	var half := PackedFloat32Array()
	var cols := PackedColorArray()
	half.resize(n)
	cols.resize(n)
	var hue := _ribbon_tint(tint, float(spec.hot))
	for i in n:
		var t: float = float(i) / float(n - 1)
		var shape: float = smoothstep(0.0, 0.09, t) * smoothstep(0.0, 0.09, 1.0 - t)
		half[i] = float(spec.width) * 0.5 * scale * (0.35 + 0.65 * shape)
		var beat: float = 1.0 if pulse <= 0.0 else 0.72 + 0.28 * sin(t * 13.0 - _flicker * pulse)
		cols[i] = Color(hue.r, hue.g, hue.b, alpha * shape * beat)
	_ribbon(points, half, cols)


## A HITSCAN SHOT, GIVEN A BODY.
##
## Lance, Whip and the sentries all resolve on the frame they fire. That stays
## true — making them travel would be a balance change wearing a visual one, and
## the browser does not do it either — but there is a window of about a fifth of
## a second in which the effect exists, and a shot crossing 520 units inside that
## window is a shot the eye can follow.
##
## So the head runs out along the line over the first 42% of the effect's life
## and the tail chases it over the rest: a dash of light that leaves her hand,
## crosses the deck and is gone. Nothing new is tracked, nothing is added to the
## simulation, and the damage still lands on frame one.
##
## `lift` is how far the middle of the flight arcs over the deck. A Lance is flat
## and a Whip's jump is not — a chain link between two boarders is an arc through
## the air, which is exactly what `VFX-PLAN.md` §3 says it should have been.
func _bolt_ribbon(fid: int, from: Vector2, to: Vector2, element: String,
		colour: Color, alpha: float, progress: float, phase: float,
		lift: float) -> void:
	var head_t: float = ease(clampf(progress / 0.42, 0.0, 1.0), 0.62)
	var tail_t: float = clampf((progress - 0.24) / 0.76, 0.0, 1.0)
	if head_t - tail_t < 0.02:
		return
	var a3 := Vector3(from.x, RIBBON_HAND, from.y)
	var b3 := Vector3(to.x, RIBBON_CHEST, to.y)
	var tail := a3.lerp(b3, tail_t)
	var head := a3.lerp(b3, head_t)
	## The lift is scaled by how much of the flight is still drawn. Held at full
	## height while the tail catches up, a jump reads as a standing hoop rather
	## than as a whip going over.
	_ribbon_path(_element_path(tail, head, element, lift * (head_t - tail_t), phase),
		element, colour, alpha)
	## And the head as a hot billboard, because the ribbon is the MOTION and this
	## is the object doing the moving. Without it a bolt has no front, which is
	## most of what a projectile is.
	if head_t < 0.995:
		_spark("bh%d" % fid, Vector2(head.x, head.z), head.y,
			float(ELEMENT_RIBBON[element].width) * 2.2, colour)


## A HELD BEAM. Full length on its first frame, because that is what a beam is,
## but with a body: a wide soft sleeve and a narrow hot core inside it. Two
## layers is what the audit asks for on the weapon trail, and it is the whole
## difference between a beam and a line — one layer at any width reads as paint.
func _beam_ribbon(from: Vector2, to: Vector2, element: String, colour: Color,
		alpha: float, _progress: float, phase: float) -> void:
	var a3 := Vector3(from.x, RIBBON_HAND, from.y)
	var b3 := Vector3(to.x, RIBBON_CHEST + 14.0, to.y)
	var path := _element_path(a3, b3, element, 8.0, phase)
	## The sleeve first and the core over it, so the core is what the glow chain
	## finds. Both additive, so the order is only about which one is brighter.
	_ribbon_even(path, element, colour, alpha * 0.30, 1.9)
	_ribbon_even(path, element, colour, alpha * 0.95, 0.50, 26.0)


## THE SWING, IN THE AIR.
##
## The most-seen effect in the game by a wide margin: the captain's Cleave fires
## every 0.36 s for an entire run and the Boilerwright's Scald every 0.6, and
## both were a painted fan lying on the planking. A fan on the floor is a good
## answer to "how far does this reach" and no answer at all to "she just swung
## something", which is the thing the player is actually watching for.
##
## The blade LEADS and the trail follows it round. And the ribbon descends as it
## sweeps — 132 units off the deck at the start of the arc down to 58 at the end
## — so it reads as a diagonal chop through a body rather than as a hoop drawn
## round her waist. That diagonal is why it has to be geometry: a decal cannot be
## at one height at one end and a different height at the other.
func _sweep_ribbon(fx: Dictionary, _fid: int, centre: Vector2, radius: float,
		element: String, colour: Color, alpha: float, progress: float) -> void:
	var dir: float = float(fx.get("direction", 0.0))
	var half_arc: float = float(fx.get("arc", 1.7)) * 0.5
	var lead: float = clampf(progress / 0.52, 0.0, 1.0)
	var back: float = clampf((progress - 0.28) / 0.72, 0.0, 1.0)
	if lead - back < 0.03:
		return
	var spec: Dictionary = ELEMENT_RIBBON.get(element, ELEMENT_RIBBON.EMBER)
	var hue := _ribbon_tint(colour, float(spec.hot))
	var n := 9
	var pts := PackedVector3Array()
	var half := PackedFloat32Array()
	var cols := PackedColorArray()
	pts.resize(n)
	half.resize(n)
	cols.resize(n)
	for i in n:
		var u: float = float(i) / float(n - 1)
		var t: float = lerpf(back, lead, u)
		var a: float = dir + lerpf(-half_arc, half_arc, t)
		## Bellied out through the middle of the swing, because that is where the
		## blade is furthest from her and it is what makes an arc read as an arc
		## rather than as a segment of a circle drawn round a point.
		var r: float = radius * (0.78 + 0.16 * sin(t * PI))
		pts[i] = Vector3(centre.x + cos(a) * r, lerpf(132.0, 58.0, t),
			centre.y + sin(a) * r)
		half[i] = float(spec.width) * 0.66 * (0.18 + 0.82 * u)
		cols[i] = Color(hue.r, hue.g, hue.b, alpha * (0.16 + 0.84 * u))
	_ribbon(pts, half, cols)


## A CONE OF MOVING AIR. Five ribbons blown out of her rather than one wedge
## painted on the deck. The Boilerwright's whole class is about where the steam
## IS, and steam that exists only as a mark on the floor is steam you can stand
## in without noticing.
func _gust_ribbon(fx: Dictionary, fid: int, centre: Vector2, radius: float,
		element: String, colour: Color, alpha: float, progress: float) -> void:
	var dir: float = float(fx.get("direction", 0.0))
	var half_arc: float = float(fx.get("arc", 0.9)) * 0.5
	var reach: float = radius * (0.62 + progress * 0.5)
	var hz := float(ELEMENT_RIBBON[element].hz)
	## Five, and an odd number deliberately: an even fan has a seam straight down
	## the middle, which is exactly where the player is aiming.
	var lanes := 5
	for k in lanes:
		var u: float = float(k) / float(lanes - 1)
		var a: float = dir + lerpf(-half_arc, half_arc, u)
		var out := Vector2(cos(a), sin(a))
		var start := Vector3(centre.x + out.x * 30.0, RIBBON_HAND,
			centre.y + out.y * 30.0)
		var stop := Vector3(centre.x + out.x * reach, RIBBON_CHEST + 30.0,
			centre.y + out.y * reach)
		## Soft. Steam at full strength was five hard white chevrons stamped on
		## the deck rather than a cloud you could stand in — an additive strip 76
		## units across at 0.78 is a wall, not a gust.
		_ribbon_path(_element_path(start, stop, element, 0.0,
			float(fid) + float(k) * 2.1 + _flicker * hz),
			element, colour, alpha * 0.48, 0.58)


## A SHOCKWAVE, STANDING UP OFF THE DECK. The ring on the planking says where a
## Pulse or a vent REACHES, which is the gameplay question; this says what it is,
## which is a wall of air going out and up. Both, because they answer different
## questions, and the flat one on its own was reading as a stencil.
func _wave_ribbon(centre: Vector2, radius: float, element: String, colour: Color,
		alpha: float, progress: float) -> void:
	if radius < 30.0:
		return
	var spec: Dictionary = ELEMENT_RIBBON.get(element, ELEMENT_RIBBON.EMBER)
	var hue := _ribbon_tint(colour, float(spec.hot))
	## Twenty segments closes a circle without a visible corner at this camera
	## distance, and closing it costs one extra point rather than a second ribbon.
	var n := 20
	var pts := PackedVector3Array()
	var half := PackedFloat32Array()
	var cols := PackedColorArray()
	pts.resize(n + 1)
	half.resize(n + 1)
	cols.resize(n + 1)
	var rise: float = 22.0 + 96.0 * progress
	var fade: float = alpha * (1.0 - progress * 0.35)
	for i in n + 1:
		var a: float = TAU * float(i) / float(n)
		pts[i] = Vector3(centre.x + cos(a) * radius, rise,
			centre.y + sin(a) * radius)
		half[i] = float(spec.width) * 0.42 * (1.0 - progress * 0.5)
		cols[i] = Color(hue.r, hue.g, hue.b, fade)
	_ribbon(pts, half, cols)


## THE SHELL. A Mortar resolves at the target on the frame it is cast, so this is
## not a projectile in flight — it is the THROW, drawn in the tenth of a second
## after it happened. Which is honest: what the player did was lob something, and
## the arc says so without a shell having to arrive late and contradict a damage
## number already floating over the boarder.
func _lob_ribbon(fid: int, from: Vector2, to: Vector2, element: String,
		colour: Color, progress: float) -> void:
	var travel: float = clampf(progress / 0.40, 0.0, 1.0)
	var tail: float = clampf((progress - 0.16) / 0.52, 0.0, 1.0)
	if travel - tail < 0.03:
		return
	## The apex comes from the throw's own length, floored so a short lob still
	## leaves the deck and capped low. 0.55 of the distance was the first number
	## and it put a full-range Mortar's shell 340 units up, which at 41 degrees of
	## pitch is off the top of the frame: the camera has almost no sky in it, so an
	## arc that would look right from the side is an arc that leaves the picture.
	var apex: float = clampf(from.distance_to(to) * 0.34, 90.0, 190.0)
	var n := 10
	var pts := PackedVector3Array()
	pts.resize(n + 1)
	for i in n + 1:
		var g: float = lerpf(tail, travel, float(i) / float(n))
		var p := from.lerp(to, g)
		pts[i] = Vector3(p.x, RIBBON_HAND + apex * sin(g * PI), p.y)
	_ribbon_path(pts, element, colour, clampf(1.0 - progress * 1.2, 0.0, 1.0), 1.0)
	## The shell itself. Same argument as the bolt head: the ribbon is the throw
	## and this is the thing that was thrown.
	var lead := from.lerp(to, travel)
	_spark("lob%d" % fid, lead,
		RIBBON_HAND + apex * sin(travel * PI),
		float(ELEMENT_RIBBON[element].width) * 2.0, colour)


## Real clouds, at real distances, off both rails.
##
## WHERE THEY GO IS NOT A TASTE DECISION EITHER, and working it out is the thing
## three previous passes at the skybox skipped. At 41 degrees of pitch with a 36
## degree vertical field, the frame looks between 23 and 59 degrees BELOW
## horizontal — the horizon is never in it at any zoom — and a ray leaving the
## camera downward crosses the deck plane 7.6 metres below itself, so it clears
## the port gunwale only if it also travels 4.7 metres sideways in that distance.
## Solve the two together and the sky over the rail is a wedge roughly 17 to 30
## degrees off the keel and 23 to 40 degrees down, widening as it rises. Put a
## cloud outside that wedge and it is behind the ship's own planking.
##
## So each one is placed by the angle it should appear at rather than by a
## coordinate, and the coordinate is derived. Anything else is guessing, and the
## last two attempts at this file guessed and put the clouds under the hull.
## The angles below are where each cloud sits at the MIDDLE of its drift; it
## enters the wedge high and shallow and leaves it low and wide, because that is
## what an object passing a moving camera does.
##
## SIX, AND NOT TEN. The first pass put ten out there and they were a fog: at
## these distances one quad is 180 metres across and covers half the frame, so
## two overlapping is two painted cloudscapes multiplied together and the seam
## where one sorts in front of the other reads as a straight cut through the
## middle of a cloud. Six, spread across four azimuths and two phases, never has
## more than two in the wedge at once. Screenshotted at one, three and six before
## settling; `tools/sky_shot.gd` is what that was done with.
const CLOUD_FIELD := [
	## azimuth off the keel (negative is port), degrees below horizontal, layer
	{"az": -26.0, "el": 29.0, "far": false, "phase": 0.00},
	{"az":  27.0, "el": 30.0, "far": false, "phase": 0.30},
	{"az": -23.0, "el": 25.0, "far": false, "phase": 0.55},
	{"az":  24.0, "el": 26.0, "far": false, "phase": 0.80},
	{"az": -25.0, "el": 26.0, "far": true, "phase": 0.15},
	{"az":  26.0, "el": 27.0, "far": true, "phase": 0.65},
]
## How far a cloud travels before it is put back out ahead. 200 metres at 7.2 a
## second is a 28-second cycle, and with four near clouds phased across it one is
## crossing the wedge roughly every seven.
const CLOUD_WRAP := 20000.0
## Quad widths, not cloud widths: the painted mass is about a third of its
## 2048-pixel sheet and the rest is transparent. 180 metres at 300 subtends 11
## degrees of cloud, 400 at 640 subtends 9 — an object you notice against a
## 36-degree frame rather than a wall across it.
const CLOUD_NEAR_WIDTH := 18000.0
const CLOUD_FAR_WIDTH := 40000.0


func _build_clouds() -> void:
	var art := {
		false: _texture("res://assets/art/env/clouds_near.png"),
		true: _texture("res://assets/art/env/clouds_far.png"),
	}
	if art[false] == null and art[true] == null:
		return
	var centre_z: float = (SkyGearGame.DECK_RECT.position.y
		+ SkyGearGame.DECK_RECT.size.y * 0.5)
	## One material per layer rather than one per cloud, so the far six are a
	## single draw state and the near four another.
	var mats := {}
	for far in [false, true]:
		if art[far] == null:
			continue
		var m := StandardMaterial3D.new()
		m.albedo_texture = art[far]
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		## Y-billboarded: they yaw to face the camera and stay upright, which is
		## what a cloud bank does and what keeps them square-on however far round
		## the deck the captain has dragged the camera. It is also the only
		## orientation that survives the wheel without needing a second thought —
		## the GPU redoes it from the live view matrix every frame.
		m.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
		m.billboard_keep_scale = true
		## THE FOG MUST NOT REACH THEM. Depth fog at 0.011 per metre is total by
		## 400 metres, so left alone every one of these arrives as a flat patch of
		## fog colour — which is exactly the failure the flat cloud sea they
		## replace was already committing.
		m.disable_fog = true
		## The far layer is dimmer and cooler, which is the aerial perspective the
		## fog would have given them if it could be trusted at this range.
		m.albedo_color = (Color(0.60, 0.64, 0.84, 0.80) if far
			else Color(0.92, 0.90, 1.0, 0.96))
		mats[far] = m
	for spec in CLOUD_FIELD:
		var far: bool = bool(spec.get("far", false))
		if not mats.has(far):
			continue
		var range_units: float = CLOUD_FAR_RANGE if far else CLOUD_NEAR_RANGE
		var az := deg_to_rad(float(spec.az))
		var el := deg_to_rad(float(spec.el))
		var node := MeshInstance3D.new()
		var quad := QuadMesh.new()
		var width: float = CLOUD_FAR_WIDTH if far else CLOUD_NEAR_WIDTH
		## The sheets are 2048x512, and a quad that does not keep that ratio
		## stretches a painted cloud into a smear.
		quad.size = Vector2(width, width * 0.25) * WORLD_SCALE
		node.mesh = quad
		node.material_override = mats[far]
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		## A cloud a third of a kilometre wide has no business in the shadow
		## atlas or the SSAO pass either.
		node.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		add_child(node)
		var home := Vector3(
			range_units * sin(az),
			-range_units * tan(el),
			centre_z - range_units * cos(az))
		_cloud_bands.append({
			"node": node,
			"home": home,
			## Stored as distance already travelled rather than as a fraction, so
			## `_sync_clouds` is one addition and a wrap.
			"phase": float(spec.get("phase", 0.0)) * CLOUD_WRAP,
		})
	_sync_clouds(0.0)

	## And another ship out there, which is the cheapest possible way to say this
	## one is not the only thing in the sky. It used to sit 4.2 metres ABOVE the
	## deck and therefore above the top of the frame; it is now inside the same
	## wedge the clouds are, low and to port, running with us.
	var far_ship := _texture("res://assets/art/env/airship_distant.png")
	if far_ship == null:
		return
	_escort = MeshInstance3D.new()
	var oq := QuadMesh.new()
	oq.size = Vector2(9000.0, 4500.0) * WORLD_SCALE
	_escort.mesh = oq
	var om := StandardMaterial3D.new()
	om.albedo_texture = far_ship
	om.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	om.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	om.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	om.billboard_keep_scale = true
	om.disable_fog = true
	om.albedo_color = Color(0.78, 0.80, 0.94, 0.72)
	_escort.material_override = om
	_escort.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_escort.position = Vector3(
		-CLOUD_NEAR_RANGE * sin(deg_to_rad(21.0)),
		-CLOUD_NEAR_RANGE * tan(deg_to_rad(26.0)),
		centre_z - CLOUD_NEAR_RANGE * cos(deg_to_rad(21.0))) * WORLD_SCALE
	add_child(_escort)


## The field drifts aft and wraps. `_flicker` rather than a private clock because
## the sway, the flames and the airstream all already run off it, and a second
## clock is a second thing to keep in step.
func _sync_clouds(_delta: float) -> void:
	for band in _cloud_bands:
		var node: MeshInstance3D = band.node
		var home: Vector3 = band.home
		var travelled: float = fmod(_flicker * CLOUD_DRIFT + float(band.phase),
			CLOUD_WRAP)
		## `home` is where the cloud sits at the MIDDLE of its run, which is the
		## angle it was placed at, so the offset is measured from half a wrap.
		node.position = Vector3(home.x, home.y,
			home.z + travelled - CLOUD_WRAP * 0.5) * WORLD_SCALE
	if _escort != null:
		## The browser swings its escort across a third of the screen on a 0.06
		## rad/s sine. Same period, same idea, in metres.
		_escort.position.x = (-CLOUD_NEAR_RANGE * sin(deg_to_rad(21.0))
			+ sin(_flicker * 0.06) * 6000.0) * WORLD_SCALE


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
	## A generated mesh if one has been wrapped, the primitives below if not.
	## Both paths stay, and this one is not like the props: a prop that fails to
	## load falls back to a painted billboard, and there is no painted Boiler.
	## The object you lose the run by cannot be allowed to not exist.
	if _boiler_mesh(boiler):
		_boiler_fire(boiler)
		return
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
	fire.emission_energy_multiplier = 2.0
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
	_boiler_fire(boiler)


## The furnace light, and it belongs to the RENDERER rather than to whichever
## body it ends up on. A hot texture in an albedo map cannot light the planking
## the captain is standing on, and this lamp is most of what says the Boiler is
## alive from across the deck. Shared by the mesh path and the primitive one, so
## the two versions are lit identically and only the geometry differs.
func _boiler_fire(boiler: Node3D) -> void:
	_boiler_glow = OmniLight3D.new()
	_boiler_glow.light_color = Color("#ff9a4a")
	_boiler_glow.omni_range = 360.0 * WORLD_SCALE
	_boiler_glow.position = Vector3(0.0, 60.0 * WORLD_SCALE, 96.0 * WORLD_SCALE)
	boiler.add_child(_boiler_glow)


## THE BOILER'S DAMAGE, WITHOUT A SECOND MODEL.
##
## A damaged variant — scorched plates, sprung seams, venting — is a second
## generation, a second 11 MB GLB and a visible pop the moment it swaps in, for
## an object that is at the bottom centre of the frame the whole game. This is
## the cheaper read and it is also the better one, because it is CONTINUOUS: the
## fire goes out as the Boiler dies.
##
## Which is the fiction. It is a furnace that has been kept lit for thirty years
## (CLASS-2-DESIGN.md §1) and losing the run is that fire going out, so a lamp
## that dims and a body that goes cold and grey say the thing the ring at its
## feet can only count. The ring is a number; this is the object itself.
##
## The lamp also FLICKERS harder as it fails rather than merely dimming, because
## a light that only fades reads as dusk falling and a light that gutters reads
## as something wrong.
func _sync_boiler_damage() -> void:
	if _boiler_glow == null:
		return
	var life: float = clampf(game.boiler_hp / maxf(1.0, game.boiler_max_hp), 0.0, 1.0)
	## Never all the way out while the run is alive: at 1 hp left the Boiler is
	## still the brightest thing on the deck and still the thing you are stood on
	## defending. A quarter of the light is a dying fire, no light is a prop.
	var gutter: float = 1.0 if life > 0.35 else 0.72 + 0.28 * sin(_flicker * 13.0)
	_boiler_glow.light_energy = (0.38 + 0.95 * life) * gutter
	## And the body goes cold and grey. There is no `modulate` on a Node3D, and
	## `set_instance_shader_parameter` is a no-op against a StandardMaterial3D —
	## it needs a shader that declares the uniform, which an imported glTF
	## material does not. So the tint is written to per-surface OVERRIDE copies
	## made once at load, which is also what stops the Boiler dyeing every other
	## object that shares a material with it.
	var chill: float = 1.0 - life
	for i in _boiler_mats.size():
		_boiler_mats[i].albedo_color = _boiler_base[i].lerp(
			Color(0.40, 0.38, 0.42) * _boiler_base[i].a, chill)


## The generated Boiler, if `tools/static_model.gd` has wrapped one.
##
## Not `_sync_prop_model`: this is built once at startup, never moves, is never
## pooled and never recycled, and routing it through the per-frame prop path
## would put the one permanent object in the scene on a free list.
func _boiler_mesh(parent: Node3D) -> bool:
	var path := model_path(BOILER_MODEL)
	if not ResourceLoader.exists(path):
		return false
	var packed := load(path) as PackedScene
	var node: Node3D = packed.instantiate() as Node3D if packed != null else null
	if node == null:
		return false
	var measured: float = float(node.get_meta("model_height", 0.0))
	if measured <= 0.0:
		push_warning("boiler: no model_height - falling back to the primitives")
		node.queue_free()
		return false
	var s: float = BOILER_HEIGHT * WORLD_SCALE / measured
	node.scale = Vector3(s, s, s)
	## LAYER_FIGURES, which is a CHANGE from the primitive Boiler and a
	## deliberate one. The Boiler's own health ring is a 330-unit decal centred
	## on it, and against the primitives it projects up the dome and reads as a
	## halo round the objective rather than as a mark on the planking. The layer
	## comment at the top of this file says a ring belongs on the deck; this is
	## the largest object it was getting that wrong on.
	for child in node.find_children("*", "MeshInstance3D", true, false):
		var mi := child as MeshInstance3D
		mi.layers = LAYER_FIGURES
		if mi.mesh == null:
			continue
		## Own copies of the materials, made once, so `_sync_boiler_damage` has
		## something it can write a tint to every frame without editing the
		## imported resource — which is shared, cached by path, and would follow
		## the change into the next scene that loaded it.
		for surface in mi.mesh.get_surface_count():
			var mat := mi.get_active_material(surface) as StandardMaterial3D
			if mat == null:
				continue
			var own := mat.duplicate() as StandardMaterial3D
			mi.set_surface_override_material(surface, own)
			_boiler_mats.append(own)
			_boiler_base.append(own.albedo_color)
	parent.add_child(node)
	return true


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


## The Colossus fitting's gate (SG-15). True once the ship has ever survived a
## run — `workshop.unlocked`, the same latch the Workshop and Heat open behind,
## and a win is a wave-12 Colossus kill. Read straight off the game's own
## workshop Dictionary so `workshop.gd` stays untouched and there is one gate,
## not a parallel one. No save yet (a fresh boot) reads as not-earned.
func _wreck_earned() -> bool:
	return game != null and bool((game.workshop as Dictionary).get("unlocked", false))


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
	## AFTER the solve, never instead of it. `_track_camera` writes the gameplay
	## transform every frame from state a cutscene is forbidden to touch, so a
	## cutscene overwriting its RESULT here means "stop overwriting" is a complete
	## restore — see the header of `scripts/cutscene_player.gd`.
	_watch_cues()
	if _cutscene != null:
		## This frame's ship motion, in degrees, handed over rather than looked up:
		## `SWAY_ROLL` and `SWAY_YAW` live here and a cutscene that recomputed them
		## would be a second copy of a number `_track_camera` already owns.
		_cutscene.sway_roll = SWAY_ROLL * _roll
		_cutscene.sway_yaw = SWAY_YAW * _yaw
		_cutscene.advance(delta)
	## The fitting follows the save, not the run: the wreck shows the frame after
	## the persistent gate flips and stays. One dictionary read a frame.
	if _wreck != null:
		_wreck.visible = _wreck_earned()
	_used.clear()
	_decals_used.clear()
	## The ribbon batch is written from scratch every frame between these two, the
	## same way the shadow batch is and for the same reason: there is no persistent
	## identity to preserve, the count is small, and a rebuild cannot leave a stale
	## bolt hanging in the air over a boarder that died two seconds ago.
	_mote_clock += delta
	_ribbons_begin()
	_sync_all(delta)
	_sync_auras()
	_sync_effects()
	_ribbons_end()
	_sync_darkness(delta)
	_flush_shadows()
	_sync_airstream(delta)
	## The flashes fade. Ember lingers, Frost is instant — the decay carries the
	## element as much as the colour does.
	for light in _flashes:
		if light.light_energy > 0.0:
			light.light_energy = maxf(0.0, light.light_energy
				- delta * float(light.get_meta("decay", 11.0)))
	_sync_clouds(delta)
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
	## Prop meshes go back on a shelf instead, one shelf per model. They are not
	## rigs — there is no skeleton or AnimationPlayer to hold — and salvage is the
	## case that decides it: a pickup appears and is collected several times a
	## second all run, so freeing its mesh on collection is `load` and
	## `instantiate` on a repeating loop for a thing that will be needed again in
	## two seconds.
	for key in _prop_models.keys():
		if not _used.has(key):
			var node: Node3D = _prop_models[key]
			node.visible = false
			var model_key: String = str(node.get_meta("prop_model", ""))
			if not _free_prop_models.has(model_key):
				_free_prop_models[model_key] = []
			_free_prop_models[model_key].append(node)
			_prop_models.erase(key)
	for model_key in _free_prop_models:
		_trim(_free_prop_models[model_key])
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
	## ZOOM. Requested, and it is also the honest short-term answer to the parity
	## finding — side by side the port shows materially less deck than the browser
	## and nobody has diagnosed why yet. A wheel does not fix that, but it stops
	## the player being stuck inside it while I work out what moved.
	##
	## The camera pulls BACK ALONG ITS OWN AXIS rather than changing FOV. Both
	## show more deck; only one keeps the projection the whole game is calibrated
	## to. Changing the field of view would change the perspective every telegraph,
	## decal and billboard height was solved against.
	_zoom = lerpf(_zoom, _zoom_target, 1.0 - exp(-delta / ZOOM_TAU))
	camera.position = Vector3((_focus.x + kick.x) * WORLD_SCALE,
		(CAM_HEIGHT * _zoom + heave + kick.y) * WORLD_SCALE,
		(_focus.y + CAM_NEAR * _zoom) * WORLD_SCALE)
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
		## SCALED ON THE COLUMNS, not by `Basis.scaled()`.
		##
		## `scaled()` multiplies the basis ROWS, which is a scale in the PARENT
		## frame, and this basis is a 90 degree rotation — so the two did not line
		## up. At `angle = -PI/2` the local X column is (0, 0, -1), pointing down
		## the keel, and scaling the world-X row leaves it untouched: THE 367-UNIT
		## LENGTH WAS DISCARDED. It landed on the local Y column instead, which
		## points athwartships. Forty-eight additive plates, up to 430 units wide
		## ACROSS the ship at head height, sweeping over the deck.
		##
		## Invisible for months against a near-black sky and obvious the day a
		## moonlit cloudscape went in behind them — the pale horizontal bars in
		## the first sky screenshots were these. Found by measurement rather than
		## by eye: `tools/deck_probe.gd -- airsize` prints wanted against got.
		##
		## The comment eight lines above warns that a ribbon passing close to the
		## lens is a smear over half the frame, and then the code does exactly
		## that through a different door. Multiplying the columns applies the
		## scale in the quad's OWN frame, which is where length and width mean
		## what they are named.
		var along: float = _stream_len[i * 2] * WORLD_SCALE
		var across: float = _stream_len[i * 2 + 1] * WORLD_SCALE
		var basis := Basis(
			Vector3(ca, 0.0, sa) * along,
			Vector3(sa, 0.0, -ca) * across,
			Vector3(0.0, 1.0, 0.0))
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


## How far back the wheel has pulled the camera. 1.0 is the shipped framing, and
## it is the DEFAULT and the floor — you may pull out, never push in past the
## composition the art was built for.
var _zoom := 1.0
var _zoom_target := 1.0
const ZOOM_MIN := 1.0
const ZOOM_MAX := 1.55
const ZOOM_STEP := 0.09
const ZOOM_TAU := 0.11      ## eased, because a wheel notch that teleports is nausea


func zoom_by(notches: float) -> void:
	_zoom_target = clampf(_zoom_target + notches * ZOOM_STEP, ZOOM_MIN, ZOOM_MAX)


func zoom_amount() -> float:
	return _zoom_target


## --- CUTSCENES ---------------------------------------------------------------
##
## The camera is the one thing in this renderer another system is allowed to
## take, and this is the only door it can take it through. `cue()` names a
## MOMENT; whether anything is wired to that moment is a question for the files
## in `assets/cutscenes/`, and the answer is usually no. A cue with no cutscene
## costs one directory listing and does nothing, which is what makes adding a
## shot to an existing moment a data change rather than a code change.
##
## The four moments and where they are fired from are listed in
## `SkyGearCutscene.CUES`, and the harness reads this source file to prove each
## one of them is really called. Three of the four are fired below — the
## renderer already watches the game's state every frame, so a moment that is
## only a state transition needs nothing from `game.gd`. The fourth,
## `boss_arrival`, is not a state: it is the frame the Colossus is instantiated,
## and only the spawn knows about that.
## LOADED BY PATH, NOT NAMED. `SkyGearCutscenePlayer` reaches
## `SkyGearCutscene`, which reads the four camera constants at the top of this
## file — so naming either class here closes a ring, and GDScript answers a ring
## by refusing to compile a file at the far end of it with a message that points
## at the wrong place. A runtime `load` costs one resource lookup at startup and
## keeps the dependency one-way: cutscenes know about the camera, the camera does
## not know about cutscenes.
const CUTSCENE_PLAYER := "res://scripts/cutscene_player.gd"
var _cutscene
var _cue_state := -1
var _cue_wave := -1
## Off in `tools/cutscene_lab.gd`, and nowhere else. The lab stages wave 12 to
## frame the Colossus, and without this that fires the very cutscene being
## authored on top of the authoring — hiding the interface, locking the controls
## and fighting for the camera.
var cutscenes_enabled := true


## Fire a moment. Returns whether a cutscene actually started, so a call site
## can tell the difference between "nothing is wired here" and "it is running".
func cue(name: String, wave_number: int = 0) -> bool:
	if not cutscenes_enabled or _cutscene == null:
		return false
	return bool(_cutscene.cue(name, wave_number))


func play_cutscene(id: String) -> bool:
	if _cutscene == null:
		return false
	return bool(_cutscene.play(id))


func cutscene_active() -> bool:
	return _cutscene != null and _cutscene.active()


func stop_cutscene() -> void:
	if _cutscene != null:
		_cutscene.stop()


## Three of the four cues, from state the renderer is already reading. Edge
## triggered on purpose: `state` and `wave` are levels, and a cutscene fired
## from a level runs every frame the level holds.
func _watch_cues() -> void:
	if game == null or _cutscene == null:
		return
	var state := int(game.state)
	var wave_number := int(game.wave)
	var first := _cue_state < 0
	var state_changed := state != _cue_state
	var wave_changed := wave_number != _cue_wave
	_cue_state = state
	_cue_wave = wave_number
	## The first frame is not a transition — everything has "changed" from -1,
	## and firing a victory shot because the renderer just booted would be a very
	## strange bug to chase.
	if first or _cutscene.active():
		return
	if state_changed and state == int(SkyGearGame.State.VICTORY):
		cue("victory")
		return
	if state_changed and state == int(SkyGearGame.State.GAMEOVER):
		cue("defeat")
		return
	## The establishing shot, owed by `begin_run` and spent HERE — the one place a
	## camera is allowed, once the opening draft is behind us and the deck is in
	## PLAY. Spent before `wave_start` so wave 1 opens the run rather than firing a
	## milestone flourish, and the flag is cleared so a run plays it exactly once.
	if wave_changed and wave_number == 1 and state == int(SkyGearGame.State.PLAY) \
			and bool(game.run_opening):
		game.run_opening = false
		cue("run_open")
		return
	if wave_changed and wave_number > 0 and state == int(SkyGearGame.State.PLAY):
		cue("wave_start", wave_number)


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
		## WHICH ELEMENT THIS IS, from the effect rather than guessed from its
		## colour. The trails carry element identity in their SHAPE — see
		## `ELEMENT_RIBBON` — and shape cannot be recovered from a hue: two cards
		## can tint the same, and the keg and the vent are not elements at all.
		## Anything with no element falls back to Ember's handwriting, which is
		## also what the impact particles do.
		var element := str(fx.get("element", ""))
		if not ELEMENT_RIBBON.has(element):
			element = "EMBER"
		## Stable per effect, so a bolt's wander crawls along its own length
		## instead of boiling from frame to frame.
		var phase: float = float(fid) * 1.37 + _flicker * float(ELEMENT_RIBBON[element].hz)
		match kind:
			"arc":
				var r: float = float(fx.get("radius", 120.0)) * (0.9 + progress * 0.2)
				_decal("fx%d" % fid, centre, float(fx.get("direction", 0.0)),
					r * 2.0, r * 2.0, _art("slash", _fan_texture(float(fx.get("arc", 1.7)), false)),
					tint)
				_sweep_ribbon(fx, fid, centre, r, element, colour, alpha, progress)
			"cone":
				var rc: float = float(fx.get("radius", 120.0)) * (0.55 + progress * 0.55)
				_decal("fx%d" % fid, centre, float(fx.get("direction", 0.0)),
					rc * 2.0, rc * 2.0, _fan_texture(float(fx.get("arc", 0.9)), true),
					Color(tint.r, tint.g, tint.b, tint.a * 0.85))
				_gust_ribbon(fx, fid, centre, rc, element, colour, alpha, progress)
			"circle":
				var rb: float = float(fx.get("radius", 120.0)) * maxf(0.25, progress)
				_decal("fx%d" % fid, centre, 0.0, rb * 2.0, rb * 2.0,
					_art("ring", _ring_texture()), tint)
				## And the wall of it, standing up off the deck. A Pulse and a vent
				## are shockwaves through the air; the ring on the planking is where
				## they REACH, which is a different question from what they are.
				_wave_ribbon(centre, rb, element, colour, alpha * 0.9, progress)
				## A lobbed shell, when the effect came from somewhere. `from` is
				## written by the Mortar and nothing else, which is why this is the
				## only ring that has anything in the air over the throw.
				if fx.has("from"):
					_lob_ribbon(fid, Vector2(fx.from), centre, element, colour, progress)
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
				## The ground streak is kept and DIMMED. It is the readable half —
				## it says where across the deck the shot passed, which the audit is
				## right that an airborne trail communicates worse — but at full
				## strength it was also the only half, and it read as a scratch on
				## the planking. Half the alpha makes it the shadow of the bolt
				## rather than the bolt.
				var width: float = (26.0 if kind == "line" else 54.0) * (1.0 - progress * 0.35)
				_decal("fx%d" % fid, (from + to) * 0.5, span.angle(),
					maxf(8.0, span.length()), width,
					_art("bolt", _streak_texture()) if kind == "line" else _streak_texture(),
					Color(tint.r, tint.g, tint.b, tint.a * 0.45))
				if kind == "beam":
					_beam_ribbon(from, to, element, colour, alpha, progress, phase)
				else:
					_bolt_ribbon(fid, from, to, element, colour, alpha, progress,
						phase, float(fx.get("lift", 0.0)))
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

	## Enemy telegraphs. Design pillar 6 — every attack readable before it is
	## dangerous, and this is the single most important thing on screen when three
	## boarders are on you. The browser draws a MELEE windup as a filled oxblood
	## WEDGE covering the swing arc out to `reach`, brightening as the swing nears;
	## a RANGED shooter's shot as a danger band down its firing line; the Colossus
	## turn as a held gold ring. The port had shrunk the melee tell to a thin red
	## streak the width of a plank plus a small foot ring — present, but not the
	## thing you read across a crowd (board SG-3). Rebuilt at the same `reach`/`swing`
	## the swing itself uses (game_data), so what is DRAWN and what CONNECTS are one
	## shape, not a picture and a hit-check disagreeing about a number.
	##
	## PAL.danger #FF3D2E outer, PAL.dangerIn #FF8C1A inner — the browser's hostile
	## palette, oxblood-to-orange, never the player's teal.
	const TG_DANGER := Color(1.0, 0.239, 0.180)
	const TG_DANGER_IN := Color(1.0, 0.549, 0.102)
	const TG_SWING_ARC := 2.094395   # 120°, the fallback wedge for a reach-less melee
	for enemy in game.get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or enemy.dead:
			continue
		if enemy.state == "windup":
			## 0 at the start of the wind, 1 the instant it connects: the clock.
			var kk: float = 1.0 - clampf(enemy.state_time / maxf(0.05,
				float(enemy.config.windup)), 0.0, 1.0)
			var flick: float = 0.34 + 0.30 * kk + sin(_flicker * 22.0) * 0.06
			var ang: float = enemy.attack_direction.angle()
			if enemy.config.ai == "ranged":
				## The firing line: a danger band down the shot's path, atkRange + 80
				## (the browser's aim-line length), with a brighter hot core that runs
				## out as the wind completes so the band itself counts down.
				var flen: float = float(enemy.config.attack_range) + 80.0
				var fmid: Vector2 = enemy.global_position + enemy.attack_direction * flen * 0.5
				_decal("tg%d" % enemy.get_instance_id(), fmid, ang, flen, 28.0,
					_streak_texture(), Color(TG_DANGER.r, TG_DANGER.g, TG_DANGER.b, 0.18 + kk * 0.44))
				var clen: float = flen * (0.34 + 0.66 * kk)
				var cmid: Vector2 = enemy.global_position + enemy.attack_direction * clen * 0.5
				_decal("tr%d" % enemy.get_instance_id(), cmid, ang, clen, 13.0,
					_streak_texture(), Color(TG_DANGER_IN.r, TG_DANGER_IN.g, TG_DANGER_IN.b, 0.9))
			else:
				## The swing wedge. Apex on the boarder, opening down its facing to
				## `reach`, spanning `swing`. A reach-less melee (BOSS) gets a wide
				## wedge from its live range; its turn ring carries the phase change.
				var reach: float
				var arc: float
				if "reach" in enemy.config:
					reach = float(enemy.config.reach)
					arc = float(enemy.config.swing)
				else:
					reach = float(enemy.config.attack_range) + 26.0
					if enemy.kind == "BOSS" and enemy.beat == 1:
						reach += 90.0
					arc = TG_SWING_ARC
				_decal("tg%d" % enemy.get_instance_id(), enemy.global_position, ang,
					reach * 2.0, reach * 2.0, _fan_texture(arc, true),
					Color(TG_DANGER.r, TG_DANGER.g, TG_DANGER.b, flick * 0.5))
				## The inner wedge fills outward as the wind completes: the clock.
				var fill: float = maxf(0.10, kk)
				_decal("tr%d" % enemy.get_instance_id(), enemy.global_position, ang,
					reach * 2.0 * fill, reach * 2.0 * fill, _fan_texture(arc, true),
					Color(TG_DANGER_IN.r, TG_DANGER_IN.g, TG_DANGER_IN.b, 0.85))
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
		## AND THE AIR ITSELF. VFX-PLAN.md §4, and the reason it was worth doing
		## after the cylinder rather than instead of it: the cylinder is a WALL, so
		## a Field reads as a fence you are standing in the middle of, and the
		## inside of it is empty. A `FogVolume` puts something between the boarders
		## and the camera, which is the only way "you are standing in a cloud of
		## scalding steam" can be true rather than outlined.
		##
		## The ring on the planking is still the gameplay object — the exact edge —
		## and this is deliberately softer than it, so nothing about where the
		## damage stops is being read off a blur.
		if VOLUMETRIC_FIELDS:
			var fkey := "aurafog%d" % index
			_used[fkey] = true
			var fog: FogVolume = _fog.get(fkey)
			if fog == null:
				fog = FogVolume.new()
				fog.shape = RenderingServer.FOG_VOLUME_SHAPE_CYLINDER
				var fm := FogMaterial.new()
				## Low. Fog density is per METRE through the volume and the volume
				## is three metres across, so anything over about 0.1 is a wall of
				## milk with a fight somewhere behind it.
				fm.density = 0.055
				## The edge does the work: a hard-edged fog cylinder has a visible
				## seam where it meets clear air, which reads as geometry.
				fm.edge_fade = 0.55
				fm.height_falloff = 0.9
				fog.material = fm
				add_child(fog)
				_fog[fkey] = fog
			var fmat: FogMaterial = fog.material
			fmat.albedo = Color(tint.r, tint.g, tint.b)
			## Emission, not albedo, is what makes a Frost field glow rather than
			## merely fog: a fog volume with no light in it is grey at dusk, and
			## these are supposed to be the brightest thing at the player's feet.
			fmat.emission = Color(tint.r * 0.32, tint.g * 0.32, tint.b * 0.32)
			fog.size = Vector3(radius * 2.0, 150.0, radius * 2.0) * WORLD_SCALE
			fog.position = Vector3(at.x * WORLD_SCALE, 66.0 * WORLD_SCALE,
				at.y * WORLD_SCALE)
		## And motes rising through it, metered the same way the wreck smoke is.
		## Sparse on purpose: this is reinforcement for the ring, and a field full
		## of particles hides the boarders standing in it, which is the one thing
		## it must not do.
		if _mote_clock >= MOTE_EVERY:
			var family: String = str(ELEMENT_FX.get(skill.element, ELEMENT_FX.EMBER).family)
			var node: GPUParticles3D = _sparks.get(family)
			if node != null:
				var a: float = _impact_rng.randf() * TAU
				var d: float = sqrt(_impact_rng.randf()) * radius
				node.emit_particle(Transform3D(Basis(), Vector3(
						at.x + cos(a) * d, 14.0, at.y + sin(a) * d) * WORLD_SCALE),
					Vector3(0.0, _impact_rng.randf_range(70.0, 150.0), 0.0) * WORLD_SCALE,
					Color(tint.r * 1.5, tint.g * 1.5, tint.b * 1.5, 1.0), Color.WHITE,
					GPUParticles3D.EMIT_FLAG_POSITION | GPUParticles3D.EMIT_FLAG_VELOCITY
						| GPUParticles3D.EMIT_FLAG_COLOR)
	if _mote_clock >= MOTE_EVERY:
		_mote_clock = 0.0
	# a field that was dropped stops being drawn
	for key in _volumes.keys():
		if not _used.has(key):
			var dead: MeshInstance3D = _volumes[key]
			dead.queue_free()
			_volumes.erase(key)
	for key in _fog.keys():
		if not _used.has(key):
			var gone: FogVolume = _fog[key]
			gone.queue_free()
			_fog.erase(key)


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
		## HOW TALL A BOARDER STANDS, and it was wrong for the small ones.
		##
		## `120 + radius * 3` put a SCRAPPER at 186 and a GUNNER at 183 against a
		## captain of 176 — so the rank and file were TALLER THAN THE HERO, and
		## the three kinds that are meant to read as scurrying goblins read as a
		## line of men. Reported as "goblins probably need to be scaled down to
		## about 50%".
		##
		## Per-kind, because a flat halving would take the furnace knight from 216
		## to 108 and the boss from 330 to 165 — captain-sized — and those two are
		## frightening precisely because of their bulk. Shrinking the small three
		## makes that contrast sharper rather than flattening it.
		##
		## NOTE the footprint does not move: `radius` is gameplay, and the shadow
		## is drawn from it, so a goblin is now short and still as wide as it
		## always was to hit. That is deliberate — changing reach is a balance
		## change wearing a visual one — but it is the number to revisit if they
		## look stubby.
		var height: float = (120.0 + float(config.get("radius", 22.0)) * 3.0) 			* float(FIGURE_SCALE.get(enemy.kind, 1.0))
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
		## A mesh if one has been generated for this prop_type, the painted
		## billboard if not — PROP_MODEL is the switch and both paths stay.
		if not _sync_prop_model(pkey, str(PROP_MODEL.get(prop.prop_type, "")),
				prop.global_position, ph):
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
		## Only the LIVE cannon is a mesh. A wrecked one is a different object —
		## the painted version is a burst barrel lying in its own debris, not the
		## same gun tinted darker — and there is no model of it, so a dead turret
		## keeps its art and the pair still read as before and after.
		##
		## -90 degrees, the one prop that is not turned to face the player. These
		## guns shoot boarders, boarders come from the bow, and the bow is -z; a
		## cannon aimed at the camera is aimed at the deck it is defending.
		##
		## Ninety and not a hundred and eighty, which is what this said first:
		## the generated cannon's barrel lies along the model's X axis, not its
		## Z, so half a turn left all three guns broadside across the deck. Found
		## by looking at .shots/props/stern.png, which is the only way to find it.
		##
		## A SEPARATE KEY for the mesh. `_recycle` shelves anything `_used` did
		## not claim this frame, and a turret is the one thing here that swaps
		## representation mid-run: sharing one key would mark it used by the
		## billboard on the frame it died, so the intact brass cannon would never
		## be shelved and would stand inside its own wreck for the rest of the run.
		if bool(t.dead) or not _sync_prop_model("tm%d" % i, TURRET_MODEL,
				t.position, 130.0, 0.0, -90.0):
			_place("t%d" % i, _texture(art), t.position, 130.0)
		if not bool(t.dead):
			continue
		## A DEAD GUN HAS TO LOOK DEAD FROM ACROSS THE DECK.
		##
		## The painted wreck is a good picture and it is 130 units tall in a frame
		## full of 130-unit brass cannons, so at a glance the lane with the broken
		## gun in it looks like the two that still work. The bar over it says so in
		## the HUD; this says so in the world, which is where the player is looking
		## when they decide whether that lane is worth walking to.
		##
		## Scorch under it and smoke off it, and nothing else. A wreck that
		## FLICKERS reads as still burning and therefore as still doing something,
		## which is the opposite of the thing being communicated.
		_decal("tw%d" % i, t.position, 0.0, 300.0, 300.0,
			_art("scorch", _blob_texture()), Color(0.09, 0.06, 0.07, 0.62), false)
		## Warm, dull and low: the last of a fire rather than a fire. It sits at 40
		## units, in the burst barrel, not up where the muzzle used to be.
		_spark("tg%d" % i, t.position, 40.0, 34.0 + sin(_flicker * 4.3 + float(i)) * 8.0,
			Color(0.55, 0.20, 0.09))

	## The smoke off the wrecks, metered rather than emitted per frame. A dead
	## cannon stays dead for the rest of the wave, so an unbounded plume is an
	## unbounded plume for a minute and a half — three puffs every tenth of a
	## second is thirty particles a second against a 512 budget, and it looks the
	## same as three hundred would.
	_smoke_clock += delta
	if _smoke_clock >= SMOKE_EVERY:
		_smoke_clock = 0.0
		var smoke: GPUParticles3D = _sparks.get("steam")
		if smoke != null:
			for i in game.turrets.size():
				if not bool(game.turrets[i].dead):
					continue
				var at: Vector2 = game.turrets[i].position
				smoke.emit_particle(Transform3D(Basis(), Vector3(
						at.x + _impact_rng.randf_range(-24.0, 24.0), 70.0,
						at.y + _impact_rng.randf_range(-20.0, 20.0)) * WORLD_SCALE),
					Vector3(_impact_rng.randf_range(-18.0, 18.0), 120.0,
						_impact_rng.randf_range(-18.0, 18.0)) * WORLD_SCALE,
					## Dark, not bright. The steam family blends MIX rather than
					## ADD, which is the one emitter in the renderer that can draw
					## something the deck is darker for.
					Color(0.17, 0.15, 0.16, 1.0), Color.WHITE,
					GPUParticles3D.EMIT_FLAG_POSITION | GPUParticles3D.EMIT_FLAG_VELOCITY
						| GPUParticles3D.EMIT_FLAG_COLOR)

	## Ordnance in flight. These were missing entirely, which is why the fight
	## looked static: half of what is on screen at any moment in the browser is
	## something travelling between two people.
	## Every bolt in flight is hostile, and a tester could not track them (F-05).
	## The browser's fix was three things at once and all three port: a hot head,
	## a trail behind it, and a shadow on the planking directly under it — the
	## shadow is what tells you where it will cross you, because the head is in
	## the air and the deck is where you are.
	##
	## NOT every bolt is hostile any more. The deck cannons fire a real travelling
	## shot now, so two kinds of ordnance cross the same lanes in opposite
	## directions and they cannot look alike: ours is brass-hot and theirs is red,
	## which is the one distinction a player has to be able to make at a glance
	## while walking through the middle of both.
	for i in game.projectiles.size():
		var b: Dictionary = game.projectiles[i]
		var bid: int = int(b.get("id", i))
		var friendly: bool = bool(b.get("friendly", false))
		var col: Color = Color("#ffce7a") if friendly else Color("#ff6a4a")
		var fly: float = 66.0 if friendly else 60.0
		var trail: Array = b.get("trail", [])
		if trail.size() > 1:
			var tail: Vector2 = trail[trail.size() - 1]
			var span: Vector2 = b.position - tail
			if span.length() > 4.0:
				## The ground streak stays and is halved. It is what tells you where
				## the shot will cross YOU, which the airborne trail communicates
				## worse — but at full strength it was the whole of the effect, and
				## a bolt whose only representation is a mark on the floor is the
				## reported bug.
				_decal("bt%d" % bid, (b.position + tail) * 0.5, span.angle(),
					span.length(), 20.0, _streak_texture(), Color(col.r, col.g, col.b, 0.24))
			## And the trail in the air, off the same points the simulation was
			## already keeping — nine of them, which is inside the audit's six-to-ten
			## and cost nothing to reach because they already existed.
			var pts := PackedVector3Array()
			pts.resize(trail.size() + 1)
			pts[0] = Vector3(trail[trail.size() - 1].x, fly, trail[trail.size() - 1].y)
			for k in trail.size():
				var p: Vector2 = trail[trail.size() - 1 - k]
				pts[k] = Vector3(p.x, fly, p.y)
			pts[trail.size()] = Vector3(b.position.x, fly, b.position.y)
			## Ember's handwriting for a burning drone bolt, Frost's straight narrow
			## one for a cannon ball — a shot from a gun does not waver, and the
			## table already has a "goes exactly where it was pointed" entry.
			_ribbon_path(pts, "FROST" if friendly else "EMBER", col, 0.95,
				1.15 if friendly else 0.85)
		_shadow("b%d" % bid, b.position, 40.0, 0.38)
		_spark("b%d" % bid, b.position, fly, 62.0 if friendly else 52.0, col)

	## Salvage on the deck, bobbing so it reads as a pickup and not as debris.
	for i in game.salvage.size():
		var s: Dictionary = game.salvage[i]
		var sid: int = int(s.get("id", i))
		var bob: float = sin(_flicker * 3.4 + float(sid) * 1.7) * 9.0
		_shadow("s%d" % sid, s.position, 56.0, 0.35)
		## The bob goes in as `lift`, which for a mesh is height above the deck
		## and for the billboard is added to its half-height. Both end up the same
		## distance off the planking, which is why the same number serves.
		if not _sync_prop_model("s%d" % sid, SALVAGE_MODEL, s.position, 62.0, bob):
			_place("s%d" % sid, _texture("res://assets/art/props/salvage_pile.png"),
				s.position, 62.0, bob)

	## The Boiler's health, as a ring on the planking around it.
	_decal("boiler_ring", game.boiler_position, 0.0, 330.0, 330.0, _ring_texture(),
		Color(0.91, 0.77, 0.46, 0.55) if game.boiler_hp > game.boiler_max_hp * 0.3
		else Color(1.0, 0.30, 0.22, 0.65))
	_sync_boiler_damage()

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
			light.light_energy = (1.2 if warm else 0.82) * jitter
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
				Color(1.0, 0.56, 0.22, 0.26 * jitter) if warm
				else Color(1.0, 0.72, 0.36, 0.18 * jitter))

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
		## A mesh for the OPEN hulk only, and the painted art for the other two
		## states. That is not a shortcut, it is what the three pictures are:
		## the ramps are already down in all three, and the whole difference
		## between them is the round door in the middle — shut, blazing, or
		## blown apart. So one generation buys the state the player actually
		## fights in (`game.gd` sets `vulnerable` true on the frame it grapples
		## on and never sets it false, so SEALED is currently unreachable), and
		## the wreck stays painted because a wreck is a different object rather
		## than a darker one. Generating three would have been worse than one:
		## Meshy returns three different vehicles from three prompts, and the
		## swap would pop the whole silhouette mid-fight.
		##
		## Its own key, like the deck cannon's, so that when the hulk breaks the
		## mesh is left unclaimed and shelved instead of standing inside its own
		## wreckage for the rest of the wave.
		if broken or not vulnerable or not _sync_prop_model(
				"hulkm", HULK_MODEL, game.hulk.position, 420.0):
			_place("hulk", _texture(art), game.hulk.position, 420.0)
		elif not broken:
			## The furnace in its throat, as light rather than as texture. Same
			## argument as the Boiler's lamp: an emissive map cannot throw
			## anything onto the deck the boarders are walking down, and "it is
			## open" is the single most important thing this object says.
			_spark("hulkfire", game.hulk.position + Vector2(0.0, 70.0), 190.0,
				120.0, Color("#ff8a3a"))


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
## THE PLAYER'S MODEL, PER CLASS — board SG-12. `_sync_captain` loaded
## CAPTAIN_SCENE for BOTH classes, so the Boilerwright, a slow heavy engineer,
## rendered as the fast captain. This table is the fix: `game.class_id` picks the
## scene, the height and the weapon fit. Both classes stand the SAME height —
## they share the locked 41 degree camera and its telegraph calibration, and the
## SG-12 guard pins the two within tolerance — so bulk and stance, not scale, do
## the distinguishing. A class whose scene is absent or carries no clips falls
## back to its painted billboard through `SkyGearRig3D.setup()` returning false,
## so this seam is safe to wire before his rigged-and-retargeted scene lands.
const HERO_MODELS := {
	"captain": {"scene": CAPTAIN_SCENE, "height": CAPTAIN_HEIGHT, "fit": "captain"},
	"boilerwright": {
		"scene": "res://assets/models/boilerwright/boilerwright.tscn",
		"height": CAPTAIN_HEIGHT, "fit": "boilerwright"},
}
var _captain: SkyGearRig3D
var _captain_missing := false
var _captain_class := ""             ## which class the current figure was built for
## Her own key light. A standard trick and the honest one: the hero of a dark
## scene is lit for being the hero, not by whatever happens to be burning nearby.
var _hero: OmniLight3D


func _sync_captain(delta: float) -> bool:
	if not USE_MESH_CAPTAIN:
		return false
	## Which class we are drawing, and its model row. Default to the captain for
	## an unknown id so a bad save never leaves the player invisible.
	var who := str(game.class_id)
	var model: Dictionary = HERO_MODELS.get(who, HERO_MODELS["captain"])
	var model_height: float = float(model.get("height", CAPTAIN_HEIGHT))
	## Class changed since the figure was built — a new run, or the other class
	## picked. Drop the old rig and clear the missing latch so the new class gets
	## its own chance to load; the billboard covers the one frame in between.
	if _captain_class != who:
		if _captain != null:
			_captain.queue_free()
			_captain = null
		_captain_missing = false
		_captain_class = who
	if _captain_missing:
		return false
	if _captain == null:
		_captain = SkyGearRig3D.new()
		add_child(_captain)
		if not _captain.setup(str(model.get("scene", CAPTAIN_SCENE)),
				model_height * WORLD_SCALE, LAYER_FIGURES):
			_captain.queue_free()
			_captain = null
			_captain_missing = true
			return false
		## And put a weapon in the hand if the class has a fit. It is data — see
		## `assets/models/weapons.json` and `tools/weapon_fit.gd` — because it is a
		## dozen small nudges and none of them is worth a build. The Boilerwright's
		## tool is a separate unpriced asset (board row), so his fit is simply
		## absent for now and `weapon_fit` returns {} — an empty hand, not a crash.
		##
		## Not fatal when it fails: an empty hand is a worse captain, but a captain.
		var fit := SkyGearRig3D.weapon_fit(str(model.get("fit", who)))
		if not fit.is_empty():
			var offset: Array = fit.get("offset", [0, 0, 0])
			var turn: Array = fit.get("rotation", [0, 0, 0])
			## The height here is in METRES (the deck runs on WORLD_SCALE), and the
			## fit table was authored against a 1.8 m figure — so the blade scales
			## with the character rather than being 0.95 m on a figure 1.76 tall.
			var to_world: float = model_height * WORLD_SCALE / 1.8
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
## What each boarder's drawn height is multiplied by. One entry per kind that
## is not full size; anything absent stands at what the radius says.
const FIGURE_SCALE := {
	"SCRAPPER": 0.5,   ## 186 -> 93, a little over half the captain
	"GUNNER": 0.5,     ## 183 -> 92
	"SWARM": 0.5,      ## 165 -> 83, the smallest thing on the deck
}


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


## Stand a static generated mesh where a billboard would have gone. Returns false
## when that model is not on disk, so every caller falls back to `_place` and the
## painted art — the same always-both-paths rule `_sync_rig` follows for boarders,
## for the same reason: the props become meshes one at a time.
##
## NOT a `SkyGearRig3D`. That class exists for a skeleton, an AnimationPlayer, a
## blend, a hit flash and a squash, and a crate has none of them. There are
## twenty-eight rows in `PROP_LAYOUT`; running an animation tree on every barrel
## on the deck is twenty-eight of something for nothing.
##
## `yaw_degrees` is about +Y and measured from FACING THE CAMERA. The camera sits
## at +z looking toward -z — `_track_camera` focuses on `p.y + back` with `back`
## positive — and `tools/static_model.gd` has already turned every model so its
## own front is +Z. So zero is right for everything whose read is one face
## pointed at the player, and only the cannon disagrees.
func _sync_prop_model(key: String, model_key: String, ground: Vector2,
		height_units: float, lift: float = 0.0, yaw_degrees: float = 0.0) -> bool:
	## An empty key is a prop_type with no row in PROP_MODEL, which is the normal
	## way of saying "this one is still painted" — not an error, and not worth a
	## path lookup on `res://assets/models///.tscn` to discover.
	if model_key == "":
		return false
	var node: Node3D = _prop_models.get(key)
	if node == null:
		node = _claim_prop_model(model_key)
		if node == null:
			return false
		_prop_models[key] = node
	_used[key] = true
	## Written every frame rather than once on claim. The salvage pickups bob, so
	## the position has to move anyway, and PROP_HEIGHT is data another session
	## can edit — a scale cached at claim time would keep the old number for as
	## long as that prop lived, which is the whole run.
	var measured: float = float(node.get_meta("model_height", 0.0))
	var s: float = height_units * WORLD_SCALE / maxf(0.0001, measured)
	node.scale = Vector3(s, s, s)
	node.rotation.y = deg_to_rad(yaw_degrees)
	node.position = Vector3(ground.x * WORLD_SCALE, lift * WORLD_SCALE,
		ground.y * WORLD_SCALE)
	return true


## One instance of a generated prop scene, from the free list if one is waiting.
##
## The free list is per MODEL KEY, not one shared pool. A `Sprite3D` is
## interchangeable because `_place` overwrites every property of it; a mesh is
## not — handing a crate's node to a lantern would render a crate.
func _claim_prop_model(model_key: String) -> Node3D:
	var free: Array = _free_prop_models.get(model_key, [])
	if not free.is_empty():
		var reused: Node3D = free.pop_back()
		reused.visible = true
		return reused
	if _no_prop_model.has(model_key):
		return null
	var path := model_path(model_key)
	if not ResourceLoader.exists(path):
		_no_prop_model[model_key] = true
		return null
	var packed := load(path) as PackedScene
	var node: Node3D = packed.instantiate() as Node3D if packed != null else null
	if node == null:
		_no_prop_model[model_key] = true
		return null
	## `model_height` is written into the scene by `tools/static_model.gd`, which
	## measures the UNION of every MeshInstance3D. Without it there is no honest
	## number to scale by and the prop would be whatever size the exporter felt
	## like — so fall back to the billboard rather than guess. This is also the
	## symptom of the pruning bug: a .glb.import left on EXTRACT references
	## sibling PNGs that are no longer there and instantiates with NO MESHES.
	if float(node.get_meta("model_height", 0.0)) <= 0.0:
		push_warning("%s: no model_height on %s - re-run tools/static_model.gd"
			% [model_key, path])
		node.queue_free()
		_no_prop_model[model_key] = true
		return null
	## LAYER_FIGURES, exactly like the billboard it replaces. Effect decals are
	## culled against that layer (see `_decal`), so a crate on LAYER_WORLD would
	## suddenly start collecting every mortar ring and scorch mark that crossed
	## it — painted around its sides as though the crate were floor.
	for child in node.find_children("*", "MeshInstance3D", true, false):
		(child as MeshInstance3D).layers = LAYER_FIGURES
	## Stamped on the node so `_recycle` can shelve it on the right list without
	## carrying a second key -> model map that could disagree with this one.
	node.set_meta("prop_model", model_key)
	add_child(node)
	return node


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
## geometry tall enough to hide anybody, so this is a handful of rectangles and a
## slab test rather than a physics query.
##
## The probe is the TORSO, not the head. From this camera a 125-tall box hides
## about forty units of deck behind it, so a boarder tucked against one is cut
## off at the chest while their head is still in clear air — which is exactly the
## case worth silhouetting, and the case a head test misses entirely.
func _occluded(ground: Vector2, stand: float) -> bool:
	var eye := Vector2(_focus.x, _focus.y + CAM_NEAR)
	var torso := stand * 0.5
	## `game.cargo_rects()`, NOT the `CARGO_RECTS` const — the one cargo source of
	## truth SG-10 established: the eight fixed lane walls PLUS the live heaved
	## crate. The const missed the ninth, movable rect, so a boarder tucked on the
	## bow face of a deployed crate — where the funnel piles them, in the camera's
	## occlusion shadow — walked behind it and stopped existing (SG-31, failure
	## mode one). Reading the live method moves the occlusion with the crate.
	for rect: Rect2 in game.cargo_rects():
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
