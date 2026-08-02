class_name SkyGearCloak
extends Node3D

## The captain's cape — a bone LATTICE, not a bone chain (board SG-63, the
## rebuild of SG-23 after the owner rejected it twice: "looks horrible", then
## "atrocious").
##
## THE POST-MORTEM, AND WHAT EACH LINE OF IT COST — because the first version
## was not badly tuned, it was badly SHAPED, and every one of these was
## geometry rather than taste (the SG-82 board row is the long form):
##
##   * **One chain of four bones, every ring bound RIGIDLY to one of them**
##     (`weights = [1,0,0,0]`). Eight degrees of freedom for the whole sheet,
##     four hinge lines, and each ring a straight rigid bar between them. A hem
##     could not ripple, a corner could not lift, a fold could not happen: the
##     cape could only swing as a board, because a board is what it was.
##   * **One baked normal, `(0,0,-1)`, on every vertex.** The whole sheet shaded
##     as ONE FLAT FACET under the deck lamps, so it never caught the moving
##     highlight that is most of how an eye decides something is cloth.
##   * **A plank's proportions.** `LENGTH_OF_HEIGHT 0.56` gave a 0.99 m drop
##     against a 0.99 m hem — as wide as it was long — with the collar nearly as
##     wide as the hem, which is a banner and not a garment.
##   * **The deck-planking painter, in red.** `_cape_texture()` drew "every few
##     columns a shade darker, like the planking's boards" in oxblood. Flat
##     facet, plus board stripes, plus board proportions, equals mahogany, which
##     is exactly the word the owner's screenshot deserved.
##
## THE REBUILD, in the order the post-mortem asked for it:
##
##   * **Three chains of six**, eighteen bones in a 3x6 lattice, so the cloth has
##     36 degrees of freedom instead of 8 — and, crucially, PER-COLUMN freedom:
##     the port edge, the middle and the starboard edge are separately sprung,
##     so a turn lifts one corner and leaves the other hanging.
##   * **Weights BLENDED across two chains and two rings**, bilinearly, so there
##     is no hinge line anywhere on the sheet. Four influences a vertex, which
##     is exactly what `ARRAY_WEIGHTS` carries, so this costs nothing extra.
##   * **Normals computed from the rest surface** by finite difference, not
##     baked flat — and the rest surface now has FOLDS in it, a soft ripple
##     across the width that opens toward the hem the way hanging cloth does.
##     That is what turns one facet into five and gives the lamps something to
##     travel across.
##   * **A cape's cut**: a narrow collar (0.30 of height) flaring to a wide hem
##     (0.56), over a longer drop (0.62). Nearly two to one, and longer than it
##     is wide, which is the silhouette the eye reads as a garment.
##   * **A twill, and a normal map to match.** Diagonal, fine, mottled, with the
##     weave in the surface as well as in the colour — anything with vertical
##     stripes at a regular pitch reads as timber and always will.
##
## Everything here is presentation, like the rig it hangs off: it reads the
## simulation's velocity and writes bone poses. Nothing writes back.
##
## THE POOL LAW APPLIES TO ALLOCATIONS TOO. The lattice is a fixed 3x6, the
## state lives in preallocated packed arrays sized once in `build()`, and
## `drive()` — the per-frame path — allocates nothing: no arrays, no nodes,
## no dictionaries, only value types. The harness pins the subtree and the
## state arrays across a thousand driven frames.

## The lattice. Not tunables — the gain, clamp and spring tables below are all
## authored against exactly these counts, and the harness asserts them.
const BONES := 6                     ## rings down each chain
const CHAINS := 3                    ## port, middle, starboard — the per-column half
const COLS := 8                      ## quads across the sheet; nine verts a ring

## Where each chain sits across the back, as a fraction from port (0) to
## starboard (1). Evenly spaced, and the outer two are what a corner lifts on.
const CHAIN_U := [0.0, 0.5, 1.0]

## The cut, as fractions of the figure's height, so one cape pattern fits
## whichever class wears it. Anchored at the shoulder line (Spine2 carries both
## shoulders on the mixamo family), NARROW at the collar and flared at the hem,
## falling past mid-calf.
##
## The numbers are the post-mortem's own prescription. On a 1.76 m captain that
## is a 1.02 m drop from a 0.53 m collar to a 0.88 m hem: longer than it is
## wide, and two thirds wider at the bottom than at the top.
const LENGTH_OF_HEIGHT := 0.58       ## shoulders to below mid-calf
const SHOULDER_OF_HEIGHT := 0.30     ## across the back at the collar
const HEM_OF_HEIGHT := 0.50          ## the flare at the bottom

## THE FOLDS. A hanging cape is not a surface, it is a set of them: the cloth
## gathers at the collar and the gathers open as they fall. `FOLD_WAVES` is how
## many run down the sheet, and the depth grows from collar to hem because that
## is the direction the cloth has room to swing in.
##
## This is the single change that stops it shading as one facet. Without a
## ripple there is nothing for a normal to vary across, and a normal that does
## not vary is a flat plate however many bones are under it.
const FOLD_WAVES := 2.5
const FOLD_TOP := 0.012              ## fold depth at the collar, fraction of height
const FOLD_HEM := 0.075              ## and at the hem

## THE HEM IS NOT A STRAIGHT LINE, and this is the other half of why the old
## one read as a board. A rectangle has a straight bottom edge and square
## corners, and at forty pixels the SILHOUETTE is most of the read — you can
## give a rectangle every normal and every bone in the world and the outline
## still says plank. So the hem SCALLOPS with the folds (cloth hangs lower
## where a fold bulges and rides up between them) and the two outer corners
## lift, which is what a cape does when it is gathered at the shoulders.
const HEM_SCALLOP := 0.085           ## dip, as a fraction of the drop
const HEM_CORNER := 0.13             ## and how far the corners ride up
## The shoulder wrap, on top of the folds: the whole sheet curls forward at its
## edges where it comes over her shoulders, relaxing as it falls.
const WRAP_TOP := 0.055
const WRAP_HEM := 0.018

## THE REST DRAPE. A cape glued dead vertical reads as a board and clips the
## backs of her knees the moment a clip bends them, so each ring leans a few
## degrees further off the back. These are the EXACT angles the chain settles
## to — the deterministic-rest rule below snaps to them bitwise, so a framing
## check diffing two still frames sees identical pixels. They total 0.25 rad,
## the same drape the four-bone version had, spread over six.
const REST_PITCH := [0.085, 0.060, 0.045, 0.030, 0.020, 0.010]

## How hard forward speed pulls each ring back, at the authored run speed.
## Grows down the chain — the hem trails harder than the collar — for the same
## cumulative ~54 degrees at a full sprint the SG-23 version had: visibly
## streaming, short of the horizontal crack the dash owns.
const TRAIL_GAIN := [0.09, 0.11, 0.13, 0.15, 0.16, 0.17]
const SIDE_GAIN := [0.05, 0.07, 0.09, 0.11, 0.12, 0.13]

## PER-CHAIN CHARACTER, and the reason there are three of them. The middle of a
## cape is held against the back and the edges are free, so the outer chains
## trail harder, are slacker, and LAG — which is what puts a diagonal through
## the cloth instead of moving it as one piece. `EDGE_SIDE` is how much of a
## turn's drift each chain takes, signed by which side it is on, so a hard turn
## lifts the outside corner and drops the inside one.
const EDGE_TRAIL := [1.22, 1.0, 1.22]
const EDGE_STIFF := [0.72, 1.0, 0.72]      ## outer edges are slacker
const EDGE_SIDE := [1.35, 1.0, 1.35]

## THE CONSTRAINTS. Swing limits per ring, radians off rest, so the cape can
## never cross her torso at the 41 degree camera: the forward (negative) budget
## totals 0.27 rad — with the anchor a hand's width behind the spine, the hem
## reaches her heels and no further, whatever the sim injects. The backward
## budget carries the dash crack past horizontal and no further.
const PITCH_MIN := [-0.02, -0.03, -0.04, -0.05, -0.06, -0.07]
const PITCH_MAX := [0.30, 0.34, 0.38, 0.42, 0.46, 0.50]
const SIDE_MAX := [0.11, 0.15, 0.19, 0.23, 0.26, 0.29]   ## symmetric, so no MIN table

## Spring per ring: stiff at the collar, loose at the hem, damped a shade under
## critical — enough follow-through to read as cloth on the dash, never enough
## to oscillate visibly at rest. (Damping ~0.75 of critical: 2·sqrt(k)·0.75.)
const STIFF := [104.0, 88.0, 74.0, 62.0, 52.0, 44.0]
const DAMP := [15.3, 14.1, 12.9, 11.8, 10.8, 9.9]

## The dash CRACK — the signature move gets the signature cloth. An angular
## impulse down each chain the frame the dash starts, largest at the hem, so the
## cape snaps out flat and whips back through the spring.
const CRACK := [5.0, 7.0, 9.0, 11.5, 14.0, 17.0]

## Ground units per second the trail gains are authored at — the same number
## the rig's run cycle is authored at, so the cape and the feet agree about
## what "full speed" is.
const AUTHORED_SPEED := 210.0

## The idle sway, matched to the ship's own periods (`view3d`: roll 0.31/0.73,
## heave 0.58 on the shared `_flicker` clock) so a standing captain's cape
## belongs to the deck that is rocking her. Faint — the whole cape is forty
## pixels — and FADED OUT by speed, because a running cape is already moving.
## Gated entirely by the caller's sway flag: the harness and the framing tools
## run sway off, and with it off the lattice settles to REST_PITCH exactly (see
## the snap in `drive`).
##
## Scaled down from SG-23's 0.016 because the amplitude accumulates down the
## chain and there are six rings now rather than four: the peak breath at the
## hem is the same few degrees it was.
const SWAY_AMP := 0.0088
const SWAY_FADE_SPEED := 90.0
## And each chain breathes on its own phase, so the sheet ripples across itself
## at rest rather than swinging as one slab. Radians of offset per chain.
const SWAY_PHASE := [0.0, 1.9, 3.6]

## Below these, with sway off and no motion asked for, the lattice SNAPS to rest
## and stays there — a still screen has to actually be still.
const SNAP_ANGLE := 0.004
const SNAP_VEL := 0.02

var skeleton: Skeleton3D
var _mesh: MeshInstance3D
var _seg := 0.0                       ## one ring's length, metres
## State, indexed chain-major: `_index(chain, ring)`. Flat packed arrays rather
## than an array of arrays, so `drive` touches no allocation at all.
var _pitch := PackedFloat32Array()
var _pitch_vel := PackedFloat32Array()
var _side := PackedFloat32Array()
var _side_vel := PackedFloat32Array()
## REST_PITCH, stored at the state arrays' own precision, so "exactly at rest"
## is float32 equality against the very bits the snap writes — the 64-bit
## constants differ from their 32-bit storage in the eighth decimal, which is
## invisible on screen and fatal to a bitwise determinism claim.
var _rest := PackedFloat32Array()
var _dash_latch := false              ## edge detector: crack once per dash

static var _tex: ImageTexture = null
static var _norm: ImageTexture = null


## Which flat slot a (chain, ring) pair lives in — and, because the skeleton is
## built in the same order, which BONE it is.
static func _index(chain: int, ring: int) -> int:
	return chain * BONES + ring


func bone_total() -> int:
	return CHAINS * BONES


## Stand the cape up: bones, mesh, skin, material. `height_m` is the figure's
## world height in metres — the same number `SkyGearRig3D.setup` was asked for —
## so the cut scales with whoever wears it.
func build(height_m: float, layer: int) -> void:
	var length := height_m * LENGTH_OF_HEIGHT
	_seg = length / float(BONES)
	var slots := CHAINS * BONES
	_pitch.resize(slots)
	_pitch_vel.resize(slots)
	_side.resize(slots)
	_side_vel.resize(slots)
	_rest.resize(slots)
	for c in CHAINS:
		for k in BONES:
			_rest[_index(c, k)] = float(REST_PITCH[k])

	var shoulder := height_m * SHOULDER_OF_HEIGHT
	var hem := height_m * HEM_OF_HEIGHT

	## THREE CHAINS, side by side, each hanging from its own point on the collar.
	## Bone `_index(c, k)` is chain c's ring k, and each chain's root sits at the
	## x its column of the collar starts at — so the port chain swings about the
	## port shoulder and not about the spine, which is what lets a corner lift.
	skeleton = Skeleton3D.new()
	skeleton.name = "CapeBones"
	add_child(skeleton)
	for c in CHAINS:
		var anchor_x: float = (float(CHAIN_U[c]) - 0.5) * shoulder
		for k in BONES:
			var bone := _index(c, k)
			skeleton.add_bone("cape_%d_%d" % [c, k])
			if k > 0:
				skeleton.set_bone_parent(bone, _index(c, k - 1))
			skeleton.set_bone_rest(bone, Transform3D(Basis.IDENTITY,
				Vector3(anchor_x, 0.0, 0.0) if k == 0
					else Vector3(0.0, -_seg, 0.0)))
			skeleton.reset_bone_pose(bone)

	## THE SHEET. Seven rings of nine verts, on the rest surface described by
	## `_drape` — the flare, the shoulder wrap and the folds together — with the
	## normals taken from that same surface by finite difference rather than
	## asserted. Every vertex is influenced by TWO chains and TWO rings,
	## bilinearly, which is why there is no hinge line on it anywhere.
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var tangents := PackedFloat32Array()
	var bones := PackedInt32Array()
	var weights := PackedFloat32Array()
	var index := PackedInt32Array()
	var du := 0.5 / float(COLS)
	var dv := 0.5 / float(BONES)
	for j in BONES + 1:
		var v := float(j) / float(BONES)
		for c in COLS + 1:
			var u := float(c) / float(COLS)
			var here := _drape(u, v, height_m)
			verts.append(here)
			uvs.append(Vector2(u, v))
			## The surface's own normal: cross the two tangents of the parametric
			## patch, sampled either side. This is the line the post-mortem is
			## about — a normal that VARIES is the difference between cloth and a
			## plate, and it cannot be varied by hand.
			var along_u := _drape(minf(1.0, u + du), v, height_m) 				- _drape(maxf(0.0, u - du), v, height_m)
			var along_v := _drape(u, minf(1.0, v + dv), height_m) 				- _drape(u, maxf(0.0, v - dv), height_m)
			var n := along_v.cross(along_u)
			if n.length_squared() < 1e-12:
				n = Vector3(0.0, 0.0, -1.0)
			n = n.normalized()
			## The sheet is seen from BEHIND her, so the outward face is -Z.
			if n.z > 0.0:
				n = -n
			normals.append(n)
			var t := along_u.normalized() if along_u.length_squared() > 1e-12 				else Vector3.RIGHT
			tangents.append_array(PackedFloat32Array([t.x, t.y, t.z, 1.0]))
			## BILINEAR SKINNING. `u` lands between two chains and `v` between two
			## rings; the four corners of that cell take the product weights. A
			## vertex on the seam gets one chain at full weight and its neighbour
			## at zero, which is continuous rather than a step — the thing the
			## rigid `[1,0,0,0]` binding could never be.
			var cu: float = u * float(CHAINS - 1)
			var c0: int = clampi(int(floor(cu)), 0, CHAINS - 2)
			var fu: float = clampf(cu - float(c0), 0.0, 1.0)
			var rv: float = maxf(0.0, v * float(BONES) - 0.5)
			var r0: int = clampi(int(floor(rv)), 0, BONES - 2)
			var fv: float = clampf(rv - float(r0), 0.0, 1.0)
			bones.append_array(PackedInt32Array([
				_index(c0, r0), _index(c0 + 1, r0),
				_index(c0, r0 + 1), _index(c0 + 1, r0 + 1)]))
			weights.append_array(PackedFloat32Array([
				(1.0 - fu) * (1.0 - fv), fu * (1.0 - fv),
				(1.0 - fu) * fv, fu * fv]))
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
	arrays[Mesh.ARRAY_TANGENT] = tangents
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_BONES] = bones
	arrays[Mesh.ARRAY_WEIGHTS] = weights
	arrays[Mesh.ARRAY_INDEX] = index
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	## The bind pose: each bone's rest position in the mesh's own frame. A chain
	## root sits at its column of the collar, and ring k hangs k segments below.
	var skin := Skin.new()
	for c in CHAINS:
		var anchor_x: float = (float(CHAIN_U[c]) - 0.5) * shoulder
		for k in BONES:
			skin.add_named_bind("cape_%d_%d" % [c, k],
				Transform3D(Basis.IDENTITY,
					Vector3(-anchor_x, float(k) * _seg, 0.0)))

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
	## The weave in the SURFACE, not only in the colour. At this camera the cape
	## is forty pixels and a diffuse pattern is mush; a normal map is what makes
	## the lamps pick out a weave at all.
	mat.normal_enabled = true
	mat.normal_texture = _cape_normal()
	mat.normal_scale = 0.85
	mat.roughness = 0.92
	mat.metallic = 0.0
	## Wool is not a mirror but it is not a chalkboard either — a little wrap
	## keeps the unlit side from going dead black under one moon.
	mat.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP
	## Both faces, and the back face's normal flipped so the inside of a fold is
	## lit as an inside rather than as a hole. A cape is the one piece of
	## geometry on this deck the camera legitimately sees from either side
	## inside a single dash.
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mesh.material_override = mat

	rest_now()


## THE REST SURFACE, as a function of (u across, v down). Everything shaped
## about this cape that is not motion is in here: the flare, the shoulder wrap,
## and the folds. Kept as ONE function because the normals are differenced from
## it — two copies of this arithmetic is the "two functions disagreeing about
## one number" failure with a lighting bug attached.
func _drape(u: float, v: float, height_m: float) -> Vector3:
	var width: float = lerpf(height_m * SHOULDER_OF_HEIGHT,
		height_m * HEM_OF_HEIGHT, v)
	## The edges curl forward, strongest at the collar where the cloth comes
	## over her shoulders.
	var wrap: float = lerpf(height_m * WRAP_TOP, height_m * WRAP_HEM, v)
	var bend: float = (u - 0.5) * 2.0
	## And the folds, opening as they fall. A cosine rather than a sawtooth: a
	## fold has a round bottom, and a sawtooth would put a crease line exactly
	## where the flat version already had one.
	var fold: float = lerpf(height_m * FOLD_TOP, height_m * FOLD_HEM, v * v)
	var ripple: float = cos(u * TAU * FOLD_WAVES) * fold
	## The hem, shaped: it dips under a fold and rises between them, and the
	## two corners ride up. `v` is scaled rather than the position offset, so
	## the whole column stretches with it and the weave does not shear.
	var scallop: float = 1.0 + HEM_SCALLOP * cos(u * TAU * FOLD_WAVES) * v
	var corner: float = 1.0 - HEM_CORNER * bend * bend * v
	return Vector3((u - 0.5) * width,
		-v * scallop * corner * float(BONES) * _seg,
		wrap * bend * bend + ripple)


## The per-frame drive. `travel` is the simulation's ground velocity (ground
## units/s), `facing` the rig's current yaw, `dashing` the sim's own dash
## window, and `sway_on`/`sway_clock` are the RENDERER'S sway flag and clock —
## the same pair the camera runs on, so the cape and the deck rock to one
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
	## dash actually goes — a backward dash cracks the cape forward. The outer
	## chains take more of it, which is what makes the crack a RIPPLE across the
	## cloth rather than a single flat snap.
	if dashing and not _dash_latch:
		var whip := 1.0 if ahead >= -20.0 else -0.6
		for c in CHAINS:
			for k in BONES:
				var slot := _index(c, k)
				_pitch_vel[slot] += float(CRACK[k]) * whip * float(EDGE_TRAIL[c])
				_side_vel[slot] -= float(CRACK[k]) * 0.25 * drift * float(EDGE_SIDE[c])
	_dash_latch = dashing

	var fade: float = clampf(1.0 - speed / SWAY_FADE_SPEED, 0.0, 1.0)
	var still: bool = not sway_on and speed * speed < 1.0 and not dashing
	for c in CHAINS:
		## Which side of the spine this chain hangs on, -1 to 1. A turn pushes
		## the outside edge out and the inside edge in, so the sheet twists.
		var side_of: float = (float(CHAIN_U[c]) - 0.5) * 2.0
		var sway_pitch := 0.0
		var sway_side := 0.0
		if sway_on:
			var ph: float = float(SWAY_PHASE[c])
			sway_side = (sin(sway_clock * 0.31 + ph) * 0.72
				+ sin(sway_clock * 0.73 + ph) * 0.28) * SWAY_AMP * fade
			sway_pitch = sin(sway_clock * 0.58 + ph) * SWAY_AMP * 0.6 * fade
		for k in BONES:
			var slot := _index(c, k)
			var depth := float(k + 1)
			var pitch_target: float = (_rest[slot]
				+ float(TRAIL_GAIN[k]) * trail * float(EDGE_TRAIL[c])
				+ sway_pitch * depth)
			## The twist: the outer chains are pushed apart by forward speed, so a
			## cape at a sprint OPENS rather than staying a closed slab.
			var side_target: float = (-float(SIDE_GAIN[k]) * drift * float(EDGE_SIDE[c])
				+ sway_side * depth
				+ side_of * float(SIDE_GAIN[k]) * 0.42 * maxf(0.0, trail))
			var stiff: float = float(STIFF[k]) * float(EDGE_STIFF[c])
			var damp: float = float(DAMP[k]) * sqrt(float(EDGE_STIFF[c]))
			var pv := _pitch_vel[slot] + (stiff * (pitch_target - _pitch[slot])
				- damp * _pitch_vel[slot]) * dt
			var sv := _side_vel[slot] + (stiff * (side_target - _side[slot])
				- damp * _side_vel[slot]) * dt
			var p := _pitch[slot] + pv * dt
			var s := _side[slot] + sv * dt
			## The constraint: clamp, and kill the velocity that was driving into
			## the wall, or the spring stores it and the cape buzzes on the limit.
			if p < _rest[slot] + float(PITCH_MIN[k]):
				p = _rest[slot] + float(PITCH_MIN[k])
				pv = maxf(pv, 0.0)
			elif p > _rest[slot] + float(PITCH_MAX[k]):
				p = _rest[slot] + float(PITCH_MAX[k])
				pv = minf(pv, 0.0)
			s = clampf(s, -float(SIDE_MAX[k]), float(SIDE_MAX[k]))
			if absf(s) >= float(SIDE_MAX[k]) - 0.0001:
				sv = 0.0
			## DETERMINISTIC REST. Sway off, nothing moving, and the bone close
			## enough: snap to the rest constants EXACTLY and stop. Two still
			## frames a minute apart are then bitwise the same pose — the rule
			## every framing check in this project leans on.
			if still and absf(p - _rest[slot]) < SNAP_ANGLE 					and absf(pv) < SNAP_VEL and absf(s) < SNAP_ANGLE and absf(sv) < SNAP_VEL:
				p = _rest[slot]
				s = 0.0
				pv = 0.0
				sv = 0.0
			_pitch[slot] = p
			_side[slot] = s
			_pitch_vel[slot] = pv
			_side_vel[slot] = sv
			skeleton.set_bone_pose_rotation(slot,
				Quaternion(Vector3.RIGHT, p) * Quaternion(Vector3.BACK, s))


## Straight to the drape, no settling time. Called at build, and available to
## any tool that needs the rest pose NOW rather than a second from now.
func rest_now() -> void:
	for c in CHAINS:
		for k in BONES:
			var slot := _index(c, k)
			_pitch[slot] = _rest[slot]
			_side[slot] = 0.0
			_pitch_vel[slot] = 0.0
			_side_vel[slot] = 0.0
			skeleton.set_bone_pose_rotation(slot,
				Quaternion(Vector3.RIGHT, _rest[slot]))
	_dash_latch = false


func bone_count() -> int:
	return CHAINS * BONES if skeleton == null else skeleton.get_bone_count()


## Total backward lean of the MIDDLE chain, radians — the number the harness
## swings and settles, and the same quantity SG-23's single chain reported, so
## the thresholds carry across the rebuild unchanged.
func pitch_total() -> float:
	return chain_pitch(CHAINS / 2)


## One chain's backward lean. The harness reads the edges against the middle to
## prove the columns are separately sprung, which is the whole point of there
## being three of them.
func chain_pitch(chain: int) -> float:
	var total := 0.0
	for k in BONES:
		total += _pitch[_index(chain, k)]
	return total


## How far apart the two edges of the hem are, radians of side-swing. Zero on a
## board; nonzero the moment the cloth twists, which is what SG-82 said could
## not happen.
func hem_spread() -> float:
	return absf(_side[_index(0, BONES - 1)] - _side[_index(CHAINS - 1, BONES - 1)])


## Is the lattice sitting EXACTLY on its rest constants? Bitwise, not "close":
## the snap writes these exact values, so equality is the honest test.
func at_rest() -> bool:
	for i in _pitch.size():
		if _pitch[i] != _rest[i] or _side[i] != 0.0 				or _pitch_vel[i] != 0.0 or _side_vel[i] != 0.0:
			return false
	return true


## How many DISTINCT normals the built sheet carries, to one part in a hundred.
## One, on the SG-23 cape — the whole thing was a single facet, which is most of
## why it shaded like timber. The harness reads this rather than trusting the
## comment above `build`.
func normal_variety() -> int:
	if _mesh == null or _mesh.mesh == null:
		return 0
	var arrays: Array = (_mesh.mesh as ArrayMesh).surface_get_arrays(0)
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var seen := {}
	for n in normals:
		seen["%d_%d_%d" % [roundi(n.x * 100.0), roundi(n.y * 100.0),
			roundi(n.z * 100.0)]] = true
	return seen.size()


## What fraction of the sheet's vertices are SHARED between bones rather than
## owned outright by one. On the SG-23 cape this was zero — every vertex carried
## `[1, 0, 0, 0]`, which is the rigid binding that gave the whole thing four
## hinge lines and no cloth between them. Here it is everything except the
## corners of the collar, which are pinned on purpose: that is what holds the
## cape on her shoulders, and a cape whose collar floats is a cape on the deck.
func blended_fraction() -> float:
	if _mesh == null or _mesh.mesh == null:
		return 0.0
	var arrays: Array = (_mesh.mesh as ArrayMesh).surface_get_arrays(0)
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var verts: int = weights.size() / 4
	if verts <= 0:
		return 0.0
	var shared := 0
	for i in verts:
		var worst := 0.0
		for k in 4:
			worst = maxf(worst, weights[i * 4 + k])
		if worst < 0.999:
			shared += 1
	return float(shared) / float(verts)


## The cut, as (length, collar, hem) in metres — so the harness can assert the
## silhouette is a garment's rather than a plank's without re-deriving it.
func cut(height_m: float) -> Vector3:
	return Vector3(height_m * LENGTH_OF_HEIGHT, height_m * SHOULDER_OF_HEIGHT,
		height_m * HEM_OF_HEIGHT)


## OXBLOOD TWILL — her palette, in the project's procedural style
## (`view3d._crate_texture` and family). Deterministic seed, built once, shared
## by every cape ever cut.
##
## NOT the planking painter. SG-23's version drew "every few columns a shade
## darker, like the planking's boards", which is the deck generator's own recipe
## in red and is exactly why the owner's word for it was mahogany. A woven cloth
## is DIAGONAL, its pitch is a couple of pixels rather than a couple of
## centimetres, and it is mottled rather than striped — dye takes unevenly, and
## the unevenness is at a different scale from the weave.
static func _cape_texture() -> ImageTexture:
	if _tex != null:
		return _tex
	var w := 128
	var h := 256
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var base := Color("#5f2129")        ## oxblood — dark enough for the close
	var deep := Color("#33121a")        ## lamps, light enough for the deck view
	var worn := Color("#8a5a4e")        ## sun-bleached, dust-rubbed
	var hem := Color("#280d13")
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260803
	for y in h:
		for x in w:
			var c := base
			## THE TWILL. A 2/2 diagonal: the float steps one across for every
			## row down, so the light catches a line running at 45 degrees and
			## nothing anywhere runs straight up the cloth.
			var diag: int = (x + y) % 4
			c = c * (0.90 + float(diag) * 0.055)
			## And the counter-twill, half strength, the other way — a real weave
			## has a warp as well as a weft and the crossing is what stops the
			## diagonal reading as corduroy.
			var anti: int = (x - y + w * 4) % 6
			c = c * (0.97 + float(anti) * 0.011)
			## The dye, mottled at a scale ten times the weave's. Two octaves of
			## smooth noise faked with sines, which is enough at 128 px.
			var mottle: float = sin(float(x) * 0.13 + float(y) * 0.07) * 0.5 				+ sin(float(x) * 0.041 - float(y) * 0.058) * 0.5
			c = c.lerp(deep, clampf(0.10 + mottle * 0.09, 0.0, 0.30))
			## Worn edges: the sides and the hem lighten and fray. Strongest at
			## the hem corners, where a cape actually wears.
			var edge_x: float = minf(float(x), float(w - 1 - x)) / float(w)
			var down: float = float(y) / float(h)
			var wear: float = clampf(0.5 - edge_x * 6.0, 0.0, 0.5) * (0.3 + down * 0.7)
			wear += clampf(down - 0.88, 0.0, 0.12) * 3.4 * (0.4 + rng.randf() * 0.6)
			c = c.lerp(worn, clampf(wear, 0.0, 0.55))
			## The hem's shadowed underside rows, and a darker yoke at the top.
			if y > h - 9:
				c = c.lerp(hem, 0.6)
			if y < 12:
				c = c.lerp(deep, 0.5 - float(y) * 0.04)
			var n := rng.randf()
			if n < 0.04:
				c = c.lerp(deep, 0.35)
			elif n > 0.975:
				c = c.lerp(worn, 0.22)
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	_tex = ImageTexture.create_from_image(img)
	return _tex


## The same weave, as a NORMAL map. Without this the twill is a pattern printed
## on a smooth sheet, and a smooth sheet at forty pixels is the flat facet all
## over again — the colour says cloth and the lighting says plate, and the
## lighting wins every time.
static func _cape_normal() -> ImageTexture:
	if _norm != null:
		return _norm
	var w := 128
	var h := 256
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			## Height of the weave at this thread crossing, differenced into a
			## slope. Same 2/2 diagonal the albedo carries, so the ridge the eye
			## sees and the ridge the light finds are the same ridge.
			var here: float = _weave_height(x, y)
			var dx: float = _weave_height(x + 1, y) - here
			var dy: float = _weave_height(x, y + 1) - here
			var n := Vector3(-dx, -dy, 1.0).normalized()
			img.set_pixel(x, y, Color(n.x * 0.5 + 0.5, n.y * 0.5 + 0.5,
				n.z * 0.5 + 0.5))
	img.generate_mipmaps()
	_norm = ImageTexture.create_from_image(img)
	return _norm


static func _weave_height(x: int, y: int) -> float:
	var diag: float = float((x + y) % 4) / 3.0
	var anti: float = float((x - y + 512) % 6) / 5.0
	return diag * 0.7 + anti * 0.3
