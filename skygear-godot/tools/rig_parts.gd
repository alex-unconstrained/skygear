extends SceneTree
## Build a SEGMENTED figure — a scene of rigid parts on hinges, with its clips
## baked as node-transform tracks — from the kit `tools/segment_parts.py` cuts.
##
##   godot --path . --headless --script tools/rig_parts.gd -- boss
##
## WHY THIS IS NOT A RIG. `tools/rig_local.gd` builds a skeleton and binds every
## vertex rigid to a bone, and its own header is honest about the price: a
## triangle spanning two bones stretches when the joint between them bends, and
## a patch of shoulder rides the arm. It pays that price because the scrapper
## arrives as ONE surface and a surface has to be cut somehow.
##
## The Colossus arrives already cut. Thirteen separate geometries, so there is
## no seam to stretch and no bind to weight — a part is a node, its joint is that
## node's origin, and a hinge is a rotation on it. That is the whole mechanism,
## and it is what the owner asked for:
##
##     "I feel like if we just do simple segmented movement it might work well
##     for the boss. It's not exactly a humanoid model, and it doesnt move that
##     much, and its death animation could be the parts just falling apart."
##
## WHAT IT PLUGS INTO, UNCHANGED. The output carries an `AnimationPlayer` with
## clips named the way `scripts/rig3d.gd` already asks for them, so every piece
## of machinery that file grew for skinned characters — the priority list, the
## one-shot that ends, the crossfade table, the speed-matched cycle, the death
## seam `view3d._recycle` hangs a corpse off — works on a pile of hinged boxes
## without knowing it is one. `SkyGearRig3D.skeleton` stays null and the two
## things that need a skeleton (`hold`, `wear`) already return false for that.
## The one state that did NOT exist is `turn`, and it is one row (see rig3d).
func _initialize() -> void: call_deferred("_run")


## THE HIERARCHY. Parent per part; "" hangs off the Parts node itself.
##
## The legs are NOT children of the torso, and that is the one structural
## decision in this file. A torso that rocks should not drag the legs with it —
## the machine's mass shifts ON its legs, which is what makes a walk read as
## weight rather than as a toy being waggled. Hips stay where the sim puts them;
## everything above them moves.
const PARENT := {
	"torso": "", "leg_l": "", "leg_r": "",
	"head": "torso", "back": "torso",
	"shoulder_l": "torso", "shoulder_r": "torso",
	"arm_l": "shoulder_l", "arm_r": "shoulder_r",
	"fist_l": "arm_l", "fist_r": "arm_r",
	"foot_l": "leg_l", "foot_r": "leg_r",
}

const FPS := 30.0

## Gravity for the disassembly, and it is not 9.8. Real gravity at this scale
## reads FLOATY — a part falling two and a half metres takes 0.71 s of a 1.6 s
## death window, so the machine drifts apart instead of dropping. Sixteen puts
## the same fall at 0.56 s and gives the parts the weight the owner asked the
## death to have. Metres per second squared.
const GRAVITY := 16.0

## How much of its speed a part keeps when it hits the planking. Steel on timber
## does not bounce; it lands, moves once, and stops.
const RESTITUTION := 0.22

## Each part's LOCAL rest position, keyed by the node path the clips address it
## by. Built once in `_run`; every clip needs it (see Clip.finish).
var _rest := {}


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var key: String = args[0] if args.size() > 0 else "boss"
	var dir := "res://assets/models/%s" % key
	var map_path := "%s/parts.json" % dir
	if not FileAccess.file_exists(map_path):
		print("FAIL no %s — run tools/segment_parts.py first" % map_path)
		quit(1); return
	var map: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(map_path))
	var kit := ProjectSettings.globalize_path(
		"res://.model_originals/%s_parts/%s_parts.glb" % [key, key])
	if not FileAccess.file_exists(kit):
		print("FAIL no kit at %s" % kit)
		quit(1); return

	## GLTFDocument rather than `load()`: the kit lives in `.model_originals/`,
	## which Godot does not scan and therefore never imports, and that is
	## deliberate — it is a source, like every other model original here, and
	## what ships is the scene built below.
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	if doc.append_from_file(kit, state) != OK:
		print("FAIL could not read ", kit); quit(1); return
	var imported: Node = doc.generate_scene(state)
	root.add_child(imported)

	var meshes := {}
	for mi in imported.find_children("*", "MeshInstance3D", true, false):
		meshes[(mi as MeshInstance3D).name] = (mi as MeshInstance3D).mesh
	var parts: Array = map.parts
	print("kit: %d meshes for %d parts" % [meshes.size(), parts.size()])

	## --- the scene -----------------------------------------------------------
	var out_root := Node3D.new()
	out_root.name = "Colossus"
	var holder := Node3D.new()
	holder.name = "Parts"
	out_root.add_child(holder)
	holder.owner = out_root

	var by_name := {}
	var joint := {}
	for row in parts:
		joint[row.name] = _v3(row.joint_m)
	var nodes := {}
	## Parents before children, so a child can read its parent's node.
	for pass_i in 4:
		for row in parts:
			var name: String = row.name
			if nodes.has(name):
				continue
			var parent_name: String = PARENT.get(name, "")
			if parent_name != "" and not nodes.has(parent_name):
				continue
			var mi := MeshInstance3D.new()
			mi.name = name
			mi.mesh = meshes.get(name)
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			## THE KIT'S OWN MATERIAL WINS WHEN THERE IS ONE, and until the
			## textured twin arrived there never was. The part-segmentation
			## export carries no UVs and no images, so this file painted every
			## part a flat role colour out of `parts.json` — which is precisely
			## what the owner was looking at when he said "not sure what's going
			## on with his texture". `tools/segment_parts.py` now cuts the parts
			## out of the PAINTED sculpt instead and they arrive wearing one
			## shared material with four maps on real UVs; overwriting that with
			## a flat albedo would throw the whole marriage away one line before
			## it shipped. The flat path stays for a kit that has nothing to lose.
			if not bool(row.get("textured", false)):
				var mat := StandardMaterial3D.new()
				mat.albedo_color = Color(str(row.colour))
				mat.metallic = float(row.metallic)
				mat.roughness = float(row.roughness)
				mi.mesh.surface_set_material(0, mat)
			var parent: Node3D = nodes.get(parent_name, holder)
			parent.add_child(mi)
			mi.owner = out_root
			## Local, not world: a hinge only works if the child's origin is
			## expressed in the parent it swings from.
			mi.position = joint[name] - (joint.get(parent_name, Vector3.ZERO)
				if parent_name != "" else Vector3.ZERO)
			nodes[name] = mi
			by_name[name] = row
	if nodes.size() != parts.size():
		print("FAIL placed %d of %d parts" % [nodes.size(), parts.size()])
		quit(1); return

	for row in parts:
		var pname: String = row.name
		var pparent: String = PARENT.get(pname, "")
		var anchor: Vector3 = joint[pparent] if pparent != "" else Vector3.ZERO
		_rest[_path(pname)] = (joint[pname] as Vector3) - anchor

	## --- the clips -----------------------------------------------------------
	var player := AnimationPlayer.new()
	player.name = "AnimationPlayer"
	out_root.add_child(player)
	player.owner = out_root
	var library := AnimationLibrary.new()

	var walk := _walk(joint, by_name)
	library.add_animation("idle", _idle(joint))
	library.add_animation("walk", walk.clip)
	library.add_animation("swing", _swing())
	library.add_animation("turn", _turn())
	library.add_animation("die", _die(parts, joint))
	player.add_animation_library("", library)
	player.root_node = NodePath("..")

	## Measured, not assumed (SG-45): the height the renderer will scale against
	## is the union of the parts as BUILT, walked through their own local
	## transforms, which is exactly what `SkyGearView3D.measure_span` does.
	var box := AABB()
	var first := true
	for name in nodes:
		var mi: MeshInstance3D = nodes[name]
		var local := Transform3D.IDENTITY
		var walkup: Node = mi
		while walkup != null and walkup != out_root:
			if walkup is Node3D:
				local = (walkup as Node3D).transform * local
			walkup = walkup.get_parent()
		var here: AABB = local * mi.get_aabb()
		box = here if first else box.merge(here)
		first = false
	out_root.set_meta("model_height", box.size.y)
	## What the WALK covers, so the harness can pin the stride law against the
	## simulation's own speed without re-deriving the geometry.
	out_root.set_meta("walk_stride_m", walk.stride)
	out_root.set_meta("walk_period", walk.period)
	out_root.set_meta("part_count", parts.size())

	var packed := PackedScene.new()
	packed.pack(out_root)
	## Binary: the meshes are embedded, and base64-in-a-tscn costs double what
	## the same bytes cost in a .scn (the rig_local.gd precedent).
	var scn := "%s/%s_parts.scn" % [dir, key]
	var err := ResourceSaver.save(packed, scn)

	## …and the thin TEXT scene the renderer actually resolves. `model_path` maps
	## a kind's slug to `<slug>/<slug>.tscn` and nothing else, which is what makes
	## wiring a boarder an asset change rather than a code change — so the shipped
	## entry point keeps that name and instances the binary. Same two-file shape
	## the prompted Colossus had (a wrapper around its glb), and the reason is the
	## same: a .tscn that embeds its own meshes stores them as base64.
	##
	## DELETE THIS FILE AND THE BOSS IS A PAINTED BILLBOARD AGAIN. `_sync_rig`
	## returns false when the path is missing and `_draw_figure` takes over with
	## `colossus_front_idle.png`, exactly as it did before any of this landed.
	var wrapper := "%s/%s.tscn" % [dir, key]
	var text := """[gd_scene load_steps=2 format=3]

[ext_resource type="PackedScene" path="res://assets/models/%s/%s_parts.scn" id="1_parts"]

; The SEGMENTED Colossus (board SG-90) — thirteen rigid parts on hinges, built
; by tools/rig_parts.gd from the kit tools/segment_parts.py cuts. Rebuild both
; rather than editing this file. `model_height` is measured off the built parts,
; not declared: scripts/rig3d.gd scales the figure by it.
[node name="Boss" type="Node3D"]
metadata/model_height = %.4f

[node name="Colossus" parent="." instance=ExtResource("1_parts")]
""" % [key, key, box.size.y]
	var file := FileAccess.open(wrapper, FileAccess.WRITE)
	if file == null:
		print("FAIL could not write ", wrapper)
		quit(1); return
	file.store_string(text)
	file.close()
	print("wrote ", wrapper)
	print("model_height %.4f m, box %.2f x %.2f x %.2f" % [box.size.y, box.size.x,
		box.size.y, box.size.z])
	print("walk: stride %.3f m over %.3f s authored -> %.1f ground units/s at rate %.2f"
		% [walk.stride, walk.period, walk.ground, walk.rate])
	print("%s %s" % ["OK saved" if err == OK else "FAIL saving", scn])
	quit(0 if err == OK else 1)


func _v3(a) -> Vector3:
	return Vector3(float(a[0]), float(a[1]), float(a[2]))


## --- clip construction --------------------------------------------------------
## Every clip is baked as node-transform tracks at FPS rather than written as a
## handful of keys with curves. Two reasons: the poses below are FORMULAS, and
## sampling a formula is the only way to keep what the file says and what the
## engine plays identical; and the death is an integration with a bounce in it,
## which has no keyframe form at all.
class Clip:
	var anim: Animation
	var rot := {}     ## node path -> track index
	var pos := {}
	var rest := {}    ## node path -> the local position the part sits at

	func _init(length: float, loop: bool, rest_local: Dictionary) -> void:
		anim = Animation.new()
		anim.length = length
		anim.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
		rest = rest_local

	## EVERY ANIMATED PART GETS A POSITION TRACK, even one that never moves.
	##
	## Found by measuring the built scene rather than by reading the docs: a part
	## carrying only a ROTATION track came back with its position at the ORIGIN,
	## so the first idle collapsed both shoulders into the middle of the torso —
	## 1.77 m of travel in a clip whose largest authored movement is 22 mm.
	## Godot's animation mixer composes a whole Transform3D for any node it
	## touches, and a component with no track of its own does not fall through to
	## the node's own value.
	##
	## It is exactly the class of bug the rigged figures here never hit, because
	## an imported clip keys location, rotation and scale on every bone. A clip
	## written by hand has to remember, so this remembers for it.
	func finish() -> void:
		for path in rest:
			if rot.has(path) and not pos.has(path):
				key_pos(str(path), 0.0, rest[path])
				key_pos(str(path), anim.length, rest[path])

	func track(path: String, rotate: bool) -> int:
		var book := rot if rotate else pos
		if book.has(path):
			return book[path]
		var i := anim.add_track(Animation.TYPE_ROTATION_3D if rotate
			else Animation.TYPE_POSITION_3D)
		anim.track_set_path(i, NodePath(path))
		anim.track_set_interpolation_type(i, Animation.INTERPOLATION_LINEAR)
		book[path] = i
		return i

	func key_rot(path: String, t: float, q: Quaternion) -> void:
		anim.rotation_track_insert_key(track(path, true), t, q)

	func key_pos(path: String, t: float, p: Vector3) -> void:
		anim.position_track_insert_key(track(path, false), t, p)


## Where a part's node lives, as the AnimationPlayer sees it (root_node is the
## scene root, so every path starts at Parts).
static func _path(name: String) -> String:
	var chain := name
	var at: String = PARENT.get(name, "")
	while at != "":
		chain = "%s/%s" % [at, chain]
		at = PARENT.get(at, "")
	return "Parts/" + chain


static func _euler(x: float, y: float, z: float) -> Quaternion:
	return Quaternion(Basis.from_euler(Vector3(deg_to_rad(x), deg_to_rad(y),
		deg_to_rad(z))))


## THE IDLE — a slow settle, and the owner's word for what it must not be is the
## specification: "pistons, not lungs". So nothing here swells. The torso SINKS
## and recovers on a long period, the back stack breathes a beat behind it
## because a boiler lags what drives it, the head scans, and the arms hang and
## sway on a period that does not divide the torso's — three cycles that never
## line up read as machinery idling, and one cycle everything shares reads as
## a toy on a spring.
func _idle(joint: Dictionary) -> Animation:
	var length := 4.4
	var clip := Clip.new(length, true, _rest)
	var steps := int(round(length * FPS))
	var torso_rest: Vector3 = joint["torso"]
	for i in steps + 1:
		var t := float(i) / FPS
		var u := TAU * t / length
		## The settle: down on the beat, back up slowly. sin^2 rather than sin,
		## so it dwells at the bottom the way a weight on a stop does.
		var sink := pow(sin(u), 2.0) * 0.022
		clip.key_pos(_path("torso"), t, torso_rest - Vector3(0, sink, 0))
		clip.key_rot(_path("torso"), t, _euler(1.1 * sin(u), 0.7 * sin(u * 0.5), 0))
		clip.key_rot(_path("back"), t, _euler(-1.6 * sin(u - 0.6), 0, 0))
		clip.key_rot(_path("head"), t, _euler(1.4 * sin(u * 1.5 + 0.9),
			5.0 * sin(u * 0.375), 0))
		for side in [1.0, -1.0]:
			var s := "l" if side > 0.0 else "r"
			var lag := 0.0 if side > 0.0 else 0.55
			clip.key_rot(_path("shoulder_" + s), t,
				_euler(0, 0, side * 1.3 * sin(u * 0.75 + lag)))
			clip.key_rot(_path("arm_" + s), t,
				_euler(2.1 * sin(u * 0.75 + lag), 0, side * 1.0 * sin(u * 0.75 + lag)))
			clip.key_rot(_path("fist_" + s), t, _euler(1.8 * sin(u * 0.75 + lag + 0.4), 0, 0))
	clip.finish()
	return clip.anim


## THE WALK, and its length is DERIVED, not chosen.
##
## `rig3d` matches a cycle to ground speed by scaling playback: the rate is
## `speed / (AUTHORED_WALK_SPEED * fit_height / AUTHORED_RUN_HEIGHT)`, clamped.
## Put the Colossus's own numbers in — 95 ground units a second at 3.30 m — and
## it asks for 0.512, which is UNDER the 0.55 floor. So its rate is not a
## variable at all: this figure will always play its walk at exactly 0.55, and
## the cycle therefore has to be authored to be right at that rate rather than
## at 1.0.
##
## That is the same lesson SG-85 wrote on the knight from the other end. He was
## being handed the RUN constant and played a walk in slow motion; the fix was
## to measure his pack and give walks their own number. The Colossus cannot be
## fixed that way because nothing was authored for it — so it is authored here,
## against the constant and against the clamp the renderer will actually apply.
##
## Given a hip height h and a leg swing of THETA, the body advances 4·h·sin(THETA)
## per cycle. Pick the swing a three-metre machine should have, work out how long
## the ground it covers takes at 95 units a second, and the authored length is
## that time times the rate the renderer is going to use.
const WALK_SWING_DEG := 20.0

func _walk(joint: Dictionary, _by_name: Dictionary) -> Dictionary:
	var height: float = SkyGearView3D.boarder_height("BOSS")            ## 330
	var speed: float = float(SkyGearData.ENEMIES["BOSS"]["speed"])      ## 95
	var fit: float = height * SkyGearView3D.WORLD_SCALE                 ## 3.30 m
	var stride_ratio: float = fit / SkyGearRig3D.AUTHORED_RUN_HEIGHT
	var rate: float = clampf(speed / (SkyGearRig3D.AUTHORED_WALK_SPEED * stride_ratio),
		0.55, 1.9)
	var hip: float = float((joint["leg_l"] as Vector3).y)
	var stride: float = 4.0 * hip * sin(deg_to_rad(WALK_SWING_DEG))     ## metres/cycle
	var ground_period: float = (stride / SkyGearView3D.WORLD_SCALE) / speed
	var length: float = ground_period * rate

	var clip := Clip.new(length, true, _rest)
	var steps := int(round(length * FPS))
	var torso_rest: Vector3 = joint["torso"]
	for i in steps + 1:
		var t := float(i) / FPS
		var u := TAU * float(i) / float(steps)
		## The legs are the cycle; everything else answers to them.
		for side in [1.0, -1.0]:
			var s := "l" if side > 0.0 else "r"
			var phase := u if side > 0.0 else u + PI
			var swing := WALK_SWING_DEG * sin(phase)
			clip.key_rot(_path("leg_" + s), t, _euler(swing, 0, 0))
			## The foot stays flat through the plant and rolls through the
			## swing — a rigid foot pitched with its leg reads as a stilt.
			clip.key_rot(_path("foot_" + s), t,
				_euler(-swing * 0.55 + 5.0 * maxf(0.0, sin(phase)), 0, 0))
			## Arms counter-swing, and at a fraction: this thing's arms are
			## armour, not pendulums.
			clip.key_rot(_path("arm_" + s), t, _euler(-swing * 0.42, 0, 0))
			clip.key_rot(_path("fist_" + s), t, _euler(-swing * 0.22, 0, 0))
			clip.key_rot(_path("shoulder_" + s), t, _euler(0, 0, side * 2.4 * sin(u)))
		## Two falls per cycle — the body drops onto each planted foot — plus a
		## roll toward whichever leg is carrying it.
		clip.key_pos(_path("torso"), t,
			torso_rest - Vector3(0, 0.030 * (0.5 - 0.5 * cos(2.0 * u)), 0))
		clip.key_rot(_path("torso"), t, _euler(2.0, 3.2 * sin(u), -3.4 * sin(u)))
		clip.key_rot(_path("back"), t, _euler(-1.4 - 1.0 * cos(2.0 * u), 0, 0))
		## The head holds level while the body under it pitches and rolls. A
		## head that rides the bob is what makes a walk cycle look bouncy.
		clip.key_rot(_path("head"), t, _euler(-1.6 + 1.0 * cos(2.0 * u), -2.0 * sin(u),
			3.0 * sin(u)))
	clip.finish()
	return {"clip": clip.anim, "stride": stride, "period": length, "rate": rate,
		"ground": (stride / SkyGearView3D.WORLD_SCALE) / (length / rate)}


## THE ATTACK — both fists up and down together. A one-shot, so `rig3d` stretches
## it to whatever window the simulation's windup and recover actually give it
## (0.90 + 1.0 for this archetype), and the authored length only has to be a
## sane middle so neither end of the rate clamp is hit.
func _swing() -> Animation:
	var length := 1.10
	var clip := Clip.new(length, false, _rest)
	var steps := int(round(length * FPS))
	for i in steps + 1:
		var t := float(i) / FPS
		var u := t / length
		## Wind up slowly over the first 45%, come down over 25%, settle.
		var lift: float = 0.0
		if u < 0.45:
			lift = pow(u / 0.45, 0.7)
		elif u < 0.70:
			lift = 1.0 - pow((u - 0.45) / 0.25, 2.0)
		else:
			lift = -0.16 * (1.0 - (u - 0.70) / 0.30)
		clip.key_rot(_path("torso"), t, _euler(-9.0 * lift, 0, 0))
		clip.key_rot(_path("back"), t, _euler(7.0 * lift, 0, 0))
		clip.key_rot(_path("head"), t, _euler(6.0 * lift, 0, 0))
		for side in [1.0, -1.0]:
			var s := "l" if side > 0.0 else "r"
			## A hair apart, because two arms doing the identical thing on the
			## identical frame is the one thing that reads as a puppet.
			var bias := 1.0 if side > 0.0 else 0.88
			clip.key_rot(_path("shoulder_" + s), t,
				_euler(-38.0 * lift * bias, 0, side * -10.0 * lift))
			clip.key_rot(_path("arm_" + s), t, _euler(-46.0 * lift * bias, 0, 0))
			clip.key_rot(_path("fist_" + s), t, _euler(-22.0 * lift * bias, 0, 0))
	clip.finish()
	return clip.anim


## THE TURN — the half-health beat, and the sim already treats it as a real
## moment: `enemy.gd` holds `state == "turn"` for 1.6 s and `take_damage`
## returns zero for the whole of it, so it cannot be burst through. The
## renderer's job is to make 1.6 seconds of invulnerability LOOK like something
## happening rather than like a pause.
##
## So the parts re-orient against each other: the body winds up one way, then
## comes round the other and overshoots, the shoulders lag and catch up, and the
## head leads — a machine slewing on its own bearing. The root yaw is the
## simulation's business (`rig3d.place`); this is everything the yaw does not say.
const TURN_LENGTH := 1.60

func _turn() -> Animation:
	var clip := Clip.new(TURN_LENGTH, false, _rest)
	var steps := int(round(TURN_LENGTH * FPS))
	for i in steps + 1:
		var t := float(i) / FPS
		var u := t / TURN_LENGTH
		## Wind against the turn for the first third, then sweep through it.
		var sweep: float = -sin(PI * minf(u, 0.33) / 0.66) if u < 0.33 \
			else sin(PI * (u - 0.33) / 0.67)
		var settle: float = 1.0 - pow(maxf(0.0, u - 0.75) / 0.25, 2.0)
		clip.key_rot(_path("torso"), t, _euler(-4.0 * absf(sweep),
			34.0 * sweep * settle, 0))
		clip.key_rot(_path("back"), t, _euler(3.0 * absf(sweep),
			-9.0 * sweep * settle, 0))
		## The head arrives first and holds, which is what makes it read as
		## looking rather than as being swung.
		clip.key_rot(_path("head"), t, _euler(0, 26.0 * sin(PI * minf(1.0, u * 1.7)), 0))
		for side in [1.0, -1.0]:
			var s := "l" if side > 0.0 else "r"
			var lag := clampf(u - 0.10, 0.0, 1.0) / 0.90
			var swept: float = sweep * (0.55 + 0.45 * lag)
			clip.key_rot(_path("shoulder_" + s), t,
				_euler(-8.0 * absf(swept), -14.0 * swept, side * 9.0 * swept))
			clip.key_rot(_path("arm_" + s), t, _euler(-14.0 * absf(swept), 0,
				side * 12.0 * absf(swept)))
			clip.key_rot(_path("fist_" + s), t, _euler(-10.0 * absf(swept), 0, 0))
			## The legs re-plant: it is turning its whole body, not its waist.
			clip.key_rot(_path("leg_" + s), t, _euler(0, 12.0 * swept, 0))
	clip.finish()
	return clip.anim


## THE DEATH — the owner's own idea, and the centre of this whole asset:
## "its death animation could be the parts just falling apart."
##
## HOW IT IS CONSTRUCTED. Each part gets a moment it LETS GO, a velocity, and a
## spin; from there it is integrated under gravity until it hits the planking,
## bounces once badly, and stops. The whole thing is baked, so what ships is a
## clip like any other — it goes through `view3d._recycle`'s existing death seam
## (`want("die")`, corpse, sink) with no simulation change and no new pool, and
## the parts are accounted for because they never leave the rig: they are the
## same thirteen nodes, moved.
##
## WHAT MAKES IT READ AS A MACHINE FAILING RATHER THAN AN EXPLOSION:
##
##   * **It breaks at the joints it hinged on.** A part's break point is its own
##     node origin — the elbow it bent at is the elbow it comes off at — so the
##     disassembly is the articulation running backwards.
##   * **It is asymmetric and it is a sequence.** The right shoulder shears
##     first and takes its arm and fist with it a few frames later; the head
##     goes; the boiler on its back lets go and throws itself backwards; then a
##     knee buckles and the mass comes down. Everything failing on one frame is
##     an explosion, and an explosion is not what a machine does.
##   * **The feet stay.** `foot_l` is never released — the machine collapses OFF
##     its own anchor and leaves it standing on the deck, which is the single
##     detail that says this thing was bolted down.
##   * **Weight, through the numbers.** Heavy parts get less velocity and less
##     spin than light ones, so the torso drops where the fists are thrown.
##
## time, velocity (m/s, +x is the figure's LEFT), spin axis, spin (deg/s)
const BREAK := {
	"shoulder_r": [0.00, Vector3(-2.6, 1.5, 0.5), Vector3(0.3, 0.2, 1.0), 260.0],
	"arm_r":      [0.06, Vector3(-2.2, 0.9, 0.7), Vector3(0.5, 0.3, 1.0), 320.0],
	"fist_r":     [0.10, Vector3(-2.0, 1.4, 1.5), Vector3(1.0, 0.6, 0.4), 420.0],
	"head":       [0.18, Vector3(0.3, 2.3, 1.1), Vector3(0.6, 1.0, 0.3), 300.0],
	"back":       [0.26, Vector3(-0.2, 1.9, -1.5), Vector3(1.0, 0.1, 0.2), 180.0],
	"leg_l":      [0.34, Vector3(1.1, 0.2, -0.6), Vector3(0.2, 0.1, 1.0), 150.0],
	"torso":      [0.46, Vector3(-0.4, 0.5, 0.9), Vector3(1.0, 0.2, 0.3), 95.0],
	"shoulder_l": [0.52, Vector3(2.3, 1.1, -0.4), Vector3(0.3, 0.2, 1.0), 240.0],
	"arm_l":      [0.58, Vector3(2.0, 0.7, 0.5), Vector3(0.4, 0.3, 1.0), 300.0],
	"fist_l":     [0.62, Vector3(1.8, 1.2, 1.3), Vector3(1.0, 0.5, 0.5), 400.0],
	"leg_r":      [0.72, Vector3(-1.0, 0.3, 0.7), Vector3(0.2, 0.1, 1.0), 165.0],
	"foot_r":     [1.05, Vector3(-0.7, 1.5, 0.5), Vector3(0.4, 0.0, 1.0), 150.0],
}

const DIE_LENGTH := 1.60     ## = SkyGearView3D.DEATH_WINDOW, so the rate is 1.0

func _die(parts: Array, joint: Dictionary) -> Animation:
	var clip := Clip.new(DIE_LENGTH, false, _rest)
	var steps := int(round(DIE_LENGTH * FPS))

	## Rest world transforms and the centre-of-mass offset each part tumbles
	## about — read off the built kit, so nothing here is a guessed pivot.
	var rest := {}
	var com := {}
	var corners := {}
	for row in parts:
		var name: String = row.name
		var at: Vector3 = joint[name]
		rest[name] = Transform3D(Basis.IDENTITY, at)
		var lo := _v3(row.local_min_m)
		var hi := _v3(row.local_max_m)
		com[name] = (lo + hi) * 0.5
		## THE PART'S OWN CORNERS, about its centre. A falling part lands when its
		## LOWEST POINT reaches the planking, and which point that is depends on
		## how far it has tumbled by then — so the deck test has to be taken
		## against the rotated box every frame.
		##
		## The first version used a fixed resting height (half the part's thinnest
		## dimension) and it put the torso 0.65 m and the back stack 0.72 m THROUGH
		## the deck, because a box resting on a corner stands far taller than a box
		## resting on a face. Measured, not reasoned about: the parts were sunk in
		## the probe before they were ever seen in a frame.
		var box: Array[Vector3] = []
		for cx in [lo.x, hi.x]:
			for cy in [lo.y, hi.y]:
				for cz in [lo.z, hi.z]:
					box.append(Vector3(cx, cy, cz) - (com[name] as Vector3))
		corners[name] = box

	## Integrate every part, frame by frame, in WORLD space.
	var state := {}
	for row in parts:
		state[row.name] = {"p": (rest[row.name] as Transform3D).origin
			+ (com[row.name] as Vector3), "v": Vector3.ZERO,
			"b": Basis.IDENTITY, "spin": 0.0, "axis": Vector3.UP, "down": false,
			"loose": false}

	var world := {}
	for i in steps + 1:
		var t := float(i) / FPS
		var dt := 1.0 / FPS
		for row in parts:
			var name: String = row.name
			var s: Dictionary = state[name]
			if BREAK.has(name) and not s.loose and t >= float(BREAK[name][0]):
				s.loose = true
				s.v = BREAK[name][1]
				s.axis = (BREAK[name][2] as Vector3).normalized()
				s.spin = deg_to_rad(float(BREAK[name][3]))
			if not s.loose:
				## Still attached — and SHUDDERING. The machine does not stand
				## still waiting to come apart; it fails under load first.
				var shake := 0.010 * sin(t * 47.0) * minf(1.0, t * 6.0)
				world[name] = Transform3D(Basis.from_euler(Vector3(shake, 0.0, shake * 1.7)),
					(rest[name] as Transform3D).origin + Vector3(shake * 0.4, 0, 0))
				continue
			if not s.down:
				s.v += Vector3(0, -GRAVITY, 0) * dt
				s.p += (s.v as Vector3) * dt
				s.b = Basis(s.axis, float(s.spin) * dt) * (s.b as Basis)
				## How far the lowest corner hangs below the centre, at the
				## attitude this part has actually reached.
				var drop := 0.0
				for corner in (corners[name] as Array[Vector3]):
					drop = minf(drop, ((s.b as Basis) * corner).y)
				var floor_y: float = -drop
				if float((s.p as Vector3).y) <= floor_y:
					var p: Vector3 = s.p
					p.y = floor_y
					s.p = p
					var v: Vector3 = s.v
					if absf(v.y) < 1.4:
						## Done bouncing: it lands, it grinds a little, it stops.
						s.down = true
						s.v = Vector3.ZERO
						s.spin = 0.0
					else:
						v.y = -v.y * RESTITUTION
						v.x *= 0.55
						v.z *= 0.55
						s.v = v
						s.spin = float(s.spin) * 0.35
			world[name] = Transform3D(s.b, (s.p as Vector3)
				- (s.b as Basis) * (com[name] as Vector3))

		## World -> local, parents first. This is what lets the parts fall as
		## free bodies while the scene keeps the hierarchy the walk needs: a
		## child's key is solved against wherever its parent actually IS this
		## frame, so a detached fist does not inherit its shoulder's tumble.
		for row in parts:
			var name: String = row.name
			var parent_name: String = PARENT.get(name, "")
			var local: Transform3D = world[name]
			if parent_name != "":
				local = (world[parent_name] as Transform3D).affine_inverse() * local
			clip.key_pos(_path(name), t, local.origin)
			clip.key_rot(_path(name), t, local.basis.get_rotation_quaternion())
	clip.finish()
	return clip.anim
