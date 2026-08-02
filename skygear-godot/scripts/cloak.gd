class_name SkyGearCloak
extends Node3D

## The captain's cape — a bone chain, not a cloth solver (board SG-23).
##
## The ledger already chose the route: at this camera the cape is about forty
## pixels tall, and a figure that size does not need `SoftBody3D`, it needs
## four bones that trail when she runs, CRACK when she dashes, and hold a
## faint sway at the ship's own period when she stands still. The standing
## character rule is why this file exists at all: capes are their OWN layer,
## never baked into the character mesh — her model was generated bare-backed
## so this could be added as data, and the Boilerwright can opt in later with
## one row in `view3d.HERO_CLOAKS`.
##
## Everything here is presentation, like the rig it hangs off: it reads the
## simulation's velocity and writes bone poses. Nothing writes back.
##
## THE POOL LAW APPLIES TO ALLOCATIONS TOO. The chain is a fixed four bones,
## the state lives in preallocated packed arrays sized once in `build()`, and
## `drive()` — the per-frame path — allocates nothing: no arrays, no nodes,
## no dictionaries, only value types. The harness pins the subtree and the
## state arrays across a thousand driven frames.

## Four bones. Not a tunable — the mesh rings, the gain tables and the clamp
## tables below are all authored against exactly this count, and the harness
## asserts it.
const BONES := 4

## The cut, as fractions of the figure's height, so one cape pattern fits
## whichever class wears it. Anchored at the shoulder line (Spine2 carries
## both shoulders on the mixamo family), an arm-span across the back, falling
## to mid-calf with a slight flare at the hem.
const LENGTH_OF_HEIGHT := 0.56       ## shoulders to mid-calf
const SHOULDER_OF_HEIGHT := 0.44     ## across the back at the collar
const HEM_OF_HEIGHT := 0.56          ## the flare at the bottom
const COLS := 4                      ## quads across; five verts a ring

## THE REST DRAPE. A cape glued dead vertical reads as a board and clips the
## backs of her knees the moment a clip bends them, so at rest each bone leans
## a few degrees further off the back. These are the EXACT angles the chain
## settles to — the deterministic-rest rule below snaps to them bitwise, so a
## framing check diffing two still frames sees identical pixels.
const REST_PITCH := [0.10, 0.07, 0.05, 0.03]

## How hard forward speed pulls each bone back, at the authored run speed.
## Grows down the chain — the hem trails harder than the collar — for a
## cumulative ~54 degrees at a full sprint: visibly streaming, short of the
## horizontal crack the dash owns.
const TRAIL_GAIN := [0.16, 0.22, 0.26, 0.30]
const SIDE_GAIN := [0.08, 0.11, 0.14, 0.17]

## THE CONSTRAINTS. Swing limits per bone, radians off rest, so the cape can
## never cross her torso at the 41 degree camera: the forward (negative)
## budget totals 0.22 rad — with the anchor a hand's width behind the spine,
## the hem reaches her heels and no further, whatever the sim injects. The
## backward budget totals 2.0 rad, which is the dash crack lifting the hem
## past horizontal and no further than that.
const PITCH_MIN := [-0.03, -0.05, -0.06, -0.08]
const PITCH_MAX := [0.42, 0.48, 0.52, 0.58]
const SIDE_MAX := [0.16, 0.22, 0.26, 0.30]   ## symmetric, so no MIN table

## Spring per bone: stiff at the collar, loose at the hem, damped a shade
## under critical — enough follow-through to read as cloth on the dash,
## never enough to oscillate visibly at rest. (Damping ~0.75 of critical:
## 2·sqrt(k)·0.75.)
const STIFF := [90.0, 70.0, 55.0, 45.0]
const DAMP := [14.2, 12.5, 11.1, 10.1]

## The dash CRACK — the signature move gets the signature cloth. An angular
## impulse down the chain the frame the dash starts, largest at the hem, so
## the cape snaps out flat and whips back through the spring.
const CRACK := [7.0, 10.5, 14.0, 18.0]

## Ground units per second the trail gains are authored at — the same number
## the rig's run cycle is authored at, so the cape and the feet agree about
## what "full speed" is.
const AUTHORED_SPEED := 210.0

## The idle sway, matched to the ship's own periods (`view3d`: roll
## 0.31/0.73, heave 0.58 on the shared `_flicker` clock) so a standing
## captain's cape belongs to the deck that is rocking her. Faint — the whole
## cape is forty pixels — and FADED OUT by speed, because a running cape is
## already moving. Gated entirely by the caller's sway flag: the harness and
## the framing tools run sway off, and with it off the chain settles to
## REST_PITCH exactly (see the snap in `drive`).
const SWAY_AMP := 0.016
const SWAY_FADE_SPEED := 90.0

## Below these, with sway off and no motion asked for, the chain SNAPS to
## rest and stays there — a still screen has to actually be still.
const SNAP_ANGLE := 0.004
const SNAP_VEL := 0.02

var skeleton: Skeleton3D
var _mesh: MeshInstance3D
var _seg := 0.0                       ## one bone's length, metres
var _pitch := PackedFloat32Array()
var _pitch_vel := PackedFloat32Array()
var _side := PackedFloat32Array()
var _side_vel := PackedFloat32Array()
## REST_PITCH, stored at the state arrays' own precision, so "exactly at
## rest" is float32 equality against the very bits the snap writes — the
## 64-bit constants differ from their 32-bit storage in the eighth decimal,
## which is invisible on screen and fatal to a bitwise determinism claim.
var _rest := PackedFloat32Array()
var _dash_latch := false              ## edge detector: crack once per dash

static var _tex: ImageTexture = null


## Stand the cape up: bones, mesh, skin, material. `height_m` is the figure's
## world height in metres — the same number `SkyGearRig3D.setup` was asked
## for — so the cut scales with whoever wears it.
func build(height_m: float, layer: int) -> void:
	var length := height_m * LENGTH_OF_HEIGHT
	_seg = length / float(BONES)
	_pitch.resize(BONES)
	_pitch_vel.resize(BONES)
	_side.resize(BONES)
	_side_vel.resize(BONES)
	_rest.resize(BONES)
	for k in BONES:
		_rest[k] = float(REST_PITCH[k])

	skeleton = Skeleton3D.new()
	skeleton.name = "CapeBones"
	add_child(skeleton)
	for k in BONES:
		skeleton.add_bone("cape_%d" % k)
		if k > 0:
			skeleton.set_bone_parent(k, k - 1)
		skeleton.set_bone_rest(k, Transform3D(Basis.IDENTITY,
			Vector3.ZERO if k == 0 else Vector3(0.0, -_seg, 0.0)))
		skeleton.reset_bone_pose(k)

	## The banner: five rings of five verts, ring j at -j segments, each ring
	## rigidly bound to the bone whose origin it swings around — ring 0 sits
	## AT the root's origin, so the collar is pinned however the chain moves.
	var shoulder := height_m * SHOULDER_OF_HEIGHT
	var hem := height_m * HEM_OF_HEIGHT
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var bones := PackedInt32Array()
	var weights := PackedFloat32Array()
	var index := PackedInt32Array()
	## The columns curl forward at the edges — strongest at the collar, where
	## the cloth wraps her shoulders, relaxing toward the hem. A perfectly
	## flat strip read as a plank in the first fitting, not as cloth.
	var wrap_top := height_m * 0.055
	var wrap_hem := height_m * 0.015
	for j in BONES + 1:
		var t := float(j) / float(BONES)
		var width: float = lerpf(shoulder, hem, t)
		var wrap: float = lerpf(wrap_top, wrap_hem, t)
		var bone := maxi(0, j - 1)
		for c in COLS + 1:
			var u := float(c) / float(COLS)
			var bend: float = (u - 0.5) * 2.0
			verts.append(Vector3((u - 0.5) * width, -float(j) * _seg,
				wrap * bend * bend))
			normals.append(Vector3(0, 0, -1))
			uvs.append(Vector2(u, t))
			bones.append_array(PackedInt32Array([bone, 0, 0, 0]))
			weights.append_array(PackedFloat32Array([1.0, 0.0, 0.0, 0.0]))
	for j in BONES:
		for c in COLS:
			var a := j * (COLS + 1) + c
			var b := a + 1
			var d := a + (COLS + 1)
			var e := d + 1
			index.append_array(PackedInt32Array([a, b, d, b, e, d]))

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_BONES] = bones
	arrays[Mesh.ARRAY_WEIGHTS] = weights
	arrays[Mesh.ARRAY_INDEX] = index
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var skin := Skin.new()
	for k in BONES:
		skin.add_named_bind("cape_%d" % k,
			Transform3D(Basis.IDENTITY, Vector3(0.0, float(k) * _seg, 0.0)))

	_mesh = MeshInstance3D.new()
	_mesh.name = "Cape"
	_mesh.mesh = mesh
	_mesh.skin = skin
	_mesh.layers = layer
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	skeleton.add_child(_mesh)
	_mesh.skeleton = _mesh.get_path_to(skeleton)

	var mat := StandardMaterial3D.new()
	mat.albedo_texture = _cape_texture()
	mat.roughness = 0.95
	mat.metallic = 0.0
	## Both faces. A cape is the one piece of geometry on this deck the camera
	## legitimately sees from either side inside a single dash.
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mesh.material_override = mat

	rest_now()


## The per-frame drive. `travel` is the simulation's ground velocity (ground
## units/s), `facing` the rig's current yaw, `dashing` the sim's own dash
## window, and `sway_on`/`sway_clock` are the RENDERER'S sway flag and clock
## — the same pair the camera runs on, so the cape and the deck rock to one
## metronome and go still together when a framing check turns it off.
##
## NO ALLOCATIONS on this path — floats, Vector2/3s and Quaternions only.
func drive(delta: float, travel: Vector2, facing: float, dashing: bool,
		sway_on: bool, sway_clock: float) -> void:
	if skeleton == null:
		return
	var dt := clampf(delta, 0.0, 0.1)
	if dt <= 0.0:
		return
	## Her velocity in her own frame: how fast she is going the way she faces,
	## and how fast across it.
	var fwd := Vector2(sin(facing), cos(facing))
	var ahead: float = travel.dot(fwd)
	var across: float = travel.dot(Vector2(fwd.y, -fwd.x))
	var speed := travel.length()
	var trail: float = clampf(ahead / AUTHORED_SPEED, -0.6, 1.2)
	var drift: float = clampf(across / AUTHORED_SPEED, -1.0, 1.0)

	## The crack fires on the dash's leading edge, once, in the direction the
	## dash actually goes — a backward dash cracks the cape forward.
	if dashing and not _dash_latch:
		var whip := 1.0 if ahead >= -20.0 else -0.6
		for k in BONES:
			_pitch_vel[k] += float(CRACK[k]) * whip
			_side_vel[k] -= float(CRACK[k]) * 0.25 * drift
	_dash_latch = dashing

	## The ship's sway, on the ship's own periods, faded out by speed.
	var sway_pitch := 0.0
	var sway_side := 0.0
	if sway_on:
		var fade: float = clampf(1.0 - speed / SWAY_FADE_SPEED, 0.0, 1.0)
		sway_side = (sin(sway_clock * 0.31) * 0.72 + sin(sway_clock * 0.73) * 0.28) \
			* SWAY_AMP * fade
		sway_pitch = sin(sway_clock * 0.58) * SWAY_AMP * 0.6 * fade

	var still: bool = not sway_on and speed * speed < 1.0 and not dashing
	for k in BONES:
		var depth := float(k + 1)
		var pitch_target: float = _rest[k] + float(TRAIL_GAIN[k]) * trail \
			+ sway_pitch * depth
		var side_target: float = -float(SIDE_GAIN[k]) * drift + sway_side * depth
		var pv := _pitch_vel[k] + (float(STIFF[k]) * (pitch_target - _pitch[k])
			- float(DAMP[k]) * _pitch_vel[k]) * dt
		var sv := _side_vel[k] + (float(STIFF[k]) * (side_target - _side[k])
			- float(DAMP[k]) * _side_vel[k]) * dt
		var p := _pitch[k] + pv * dt
		var s := _side[k] + sv * dt
		## The constraint: clamp, and kill the velocity that was driving into
		## the wall, or the spring stores it and the cape buzzes on the limit.
		if p < _rest[k] + float(PITCH_MIN[k]):
			p = _rest[k] + float(PITCH_MIN[k])
			pv = maxf(pv, 0.0)
		elif p > _rest[k] + float(PITCH_MAX[k]):
			p = _rest[k] + float(PITCH_MAX[k])
			pv = minf(pv, 0.0)
		s = clampf(s, -float(SIDE_MAX[k]), float(SIDE_MAX[k]))
		if absf(s) >= float(SIDE_MAX[k]) - 0.0001:
			sv = 0.0
		## DETERMINISTIC REST. Sway off, nothing moving, and the bone close
		## enough: snap to the rest constants EXACTLY and stop. Two still
		## frames a minute apart are then bitwise the same pose — the rule
		## every framing check in this project leans on.
		if still and absf(p - _rest[k]) < SNAP_ANGLE \
				and absf(pv) < SNAP_VEL and absf(s) < SNAP_ANGLE and absf(sv) < SNAP_VEL:
			p = _rest[k]
			s = 0.0
			pv = 0.0
			sv = 0.0
		_pitch[k] = p
		_side[k] = s
		_pitch_vel[k] = pv
		_side_vel[k] = sv
		skeleton.set_bone_pose_rotation(k,
			Quaternion(Vector3.RIGHT, p) * Quaternion(Vector3.BACK, s))


## Straight to the drape, no settling time. Called at build, and available to
## any tool that needs the rest pose NOW rather than a second from now.
func rest_now() -> void:
	for k in BONES:
		_pitch[k] = _rest[k]
		_side[k] = 0.0
		_pitch_vel[k] = 0.0
		_side_vel[k] = 0.0
		skeleton.set_bone_pose_rotation(k,
			Quaternion(Vector3.RIGHT, _rest[k]))
	_dash_latch = false


func bone_count() -> int:
	return BONES if skeleton == null else skeleton.get_bone_count()


## Total backward lean of the chain, radians — the number the harness swings
## and settles. Positive is trailing behind her.
func pitch_total() -> float:
	var total := 0.0
	for k in BONES:
		total += _pitch[k]
	return total


## Is the chain sitting EXACTLY on its rest constants? Bitwise, not "close":
## the snap writes these exact values, so equality is the honest test.
func at_rest() -> bool:
	for k in BONES:
		if _pitch[k] != _rest[k] or _side[k] != 0.0 \
				or _pitch_vel[k] != 0.0 or _side_vel[k] != 0.0:
			return false
	return true


## Oxblood, worn at the edges — her palette, in the project's procedural
## style (`view3d._crate_texture` and family). Deterministic seed, built
## once, shared by every cape ever cut.
static func _cape_texture() -> ImageTexture:
	if _tex != null:
		return _tex
	var w := 64
	var h := 128
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var base := Color("#5a1f25")        ## oxblood — dark enough for the close
	var deep := Color("#361216")        ## lamps, light enough for the deck view
	var worn := Color("#845446")        ## sun-bleached, dust-rubbed
	var hem := Color("#2a0e11")
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260802
	for y in h:
		for x in w:
			var c := base
			## Vertical weave: every few columns a shade darker, like the
			## planking's boards but soft.
			var thread := int(x / 4.0)
			c = c * (0.92 + fmod(float(thread) * 0.53, 1.0) * 0.16)
			## Worn edges: the sides and the hem lighten and fray. Strongest
			## at the hem corners, where a cape actually wears.
			var edge_x: float = minf(float(x), float(w - 1 - x)) / float(w)
			var down: float = float(y) / float(h)
			var wear: float = clampf(0.5 - edge_x * 6.0, 0.0, 0.5) * (0.3 + down * 0.7)
			wear += clampf(down - 0.86, 0.0, 0.14) * 3.0 * (0.4 + rng.randf() * 0.6)
			c = c.lerp(worn, clampf(wear, 0.0, 0.55))
			## The hem's shadowed underside rows, and a darker yoke at the top.
			if y > h - 5:
				c = c.lerp(hem, 0.6)
			if y < 6:
				c = c.lerp(deep, 0.5 - float(y) * 0.08)
			var n := rng.randf()
			if n < 0.05:
				c = c.lerp(deep, 0.4)
			elif n > 0.97:
				c = c.lerp(worn, 0.25)
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	_tex = ImageTexture.create_from_image(img)
	return _tex
