extends SceneTree
## Build a Mixamo-named skeleton and rigid skin for a generated mesh LOCALLY,
## because Meshy's rigger will not (board SG-65).
##
## THE MEASURED FACT THIS TOOL EXISTS FOR: Meshy's pose estimation is gated on
## humanoid PROPORTION, not just pose. The scrapper was regenerated TWICE to
## the standing rules — v4 is a verifiably symmetric A-pose (mesh_pose: arms
## out to ±0.91 of a 1.9-unit figure, clear gaps, a neck, feet apart) — and
## POST /openapi/v1/rigging refused every submission of every version:
## twelve 422s across three meshes, five submission paths (datauri, refine
## task, texture-hinted, three heights), zero credits charged. The docs name
## the criterion: "humanoid assets with unclear limb and body structure" are
## unsupported, and a ball with limbs is exactly that, however cleanly it
## poses. The Boilerwright passed because he is HUMAN-shaped.
##
## So the skeleton is built here instead, from landmarks measured off the
## mesh (tools/mesh_pose.gd and a slice map), and every vertex is bound RIGID
## to its nearest limb. For a riveted machine that is not a fallback, it is
## the true material: a scrapper has no flesh to bend, and a candy-wrapper
## elbow would be WRONG on it. The trade, named honestly: triangles that span
## two rigid parts stretch when a clip bends the joint between them, and a
## patch of ball surface under each shoulder rides the arm. At 174 px on the
## deck, judge it from the clip, not from this comment (SG-65's read-verdict).
##
##   godot --path . --headless --script tools/rig_local.gd -- scrapper
##
## Output: assets/models/<name>/<name>_rigged.tscn — skeleton + skinned mesh,
## Mixamo bone names (bone_map {} in tools/models.json), feet on y=0. Then
## tools/retarget_library.gd retargets the captain's baked clips onto it, the
## same one command the Boilerwright used.
func _initialize() -> void: call_deferred("_run")


## Joint positions in the MESH'S OWN centred frame, measured per model from
## the slice map. One entry per model this tool has been pointed at; the
## numbers are data about one specific generation and are useless for any
## other, which is why they live here beside the tool that read them and not
## in models.json beside things a renderer consumes.
const LANDMARKS := {
	"scrapper": {
		## y −0.947..0.948 in the v4 glb; ball centre (0, +0.08, 0).
		"hips":      Vector3(0.0, -0.46, 0.0),
		"spine":     Vector3(0.0, -0.28, 0.0),
		"spine1":    Vector3(0.0, -0.02, 0.0),
		"spine2":    Vector3(0.0, 0.26, 0.0),
		"neck":      Vector3(0.0, 0.52, 0.0),
		"head":      Vector3(0.0, 0.62, 0.0),
		"head_top":  Vector3(0.0, 0.95, 0.0),
		"shoulder":  Vector3(0.24, 0.36, -0.03),   ## clavicle root, +x side
		"arm":       Vector3(0.48, 0.42, -0.05),   ## upper arm attach
		"forearm":   Vector3(0.58, 0.10, 0.05),    ## elbow
		"hand":      Vector3(0.72, -0.16, 0.14),   ## wrist; hook hangs below
		"hand_end":  Vector3(0.60, -0.50, 0.10),   ## hook tip
		"upleg":     Vector3(0.33, -0.52, 0.0),
		"leg":       Vector3(0.33, -0.72, 0.0),    ## knee
		"foot":      Vector3(0.35, -0.86, 0.0),    ## ankle
		"toe":       Vector3(0.36, -0.92, 0.10),
		"toe_end":   Vector3(0.36, -0.94, 0.24),
		## Region rules used by _bone_for(), same frame.
		"head_over": 0.58, "neck_over": 0.50, "core_radius": 0.33,
		"leg_under": -0.52, "leg_split_x": 0.10,
		"knee_y": -0.72, "ankle_y": -0.86, "toe_z": 0.10,
		"arm_min_x": 0.30, "arm_axis_max": 0.17,
		"elbow_y": 0.10, "wrist_y": -0.16,
	},
}


func _run() -> void:
	## Keep portable texture buffers CPU-side through save (see the same line
	## in retarget_library.gd — without it every save writes empty shells).
	PortableCompressedTexture2D.set_keep_all_compressed_buffers(true)
	var args := OS.get_cmdline_user_args()
	var name := args[0] if args.size() > 0 else "scrapper"
	if not LANDMARKS.has(name):
		print("FAIL no landmarks measured for %r — read them off a slice map first" % name)
		quit(1); return
	var marks: Dictionary = LANDMARKS[name]
	var glb := "res://assets/models/%s/%s.glb" % [name, name]
	if not ResourceLoader.exists(glb):
		print("FAIL no ", glb); quit(1); return
	var src: Node = (load(glb) as PackedScene).instantiate()
	root.add_child(src)
	var src_mesh: MeshInstance3D = null
	for mi in src.find_children("*", "MeshInstance3D", true, false):
		src_mesh = mi as MeshInstance3D
	if src_mesh == null:
		print("FAIL no mesh in ", glb); quit(1); return

	## --- the skeleton: Mixamo topology, Y-along-bone rests --------------------
	## name -> [parent, joint position, aim point (for the basis Y axis)]
	var mirror := func(v: Vector3) -> Vector3: return Vector3(-v.x, v.y, v.z)
	var bones := [
		["mixamorig_Hips", "", marks.hips, marks.spine],
		["mixamorig_Spine", "mixamorig_Hips", marks.spine, marks.spine1],
		["mixamorig_Spine1", "mixamorig_Spine", marks.spine1, marks.spine2],
		["mixamorig_Spine2", "mixamorig_Spine1", marks.spine2, marks.neck],
		["mixamorig_Neck", "mixamorig_Spine2", marks.neck, marks.head],
		["mixamorig_Head", "mixamorig_Neck", marks.head, marks.head_top],
		["mixamorig_HeadTop_End", "mixamorig_Head", marks.head_top,
			marks.head_top + Vector3(0, 0.05, 0)],
		["mixamorig_RightShoulder", "mixamorig_Spine2", marks.shoulder, marks.arm],
		["mixamorig_RightArm", "mixamorig_RightShoulder", marks.arm, marks.forearm],
		["mixamorig_RightForeArm", "mixamorig_RightArm", marks.forearm, marks.hand],
		["mixamorig_RightHand", "mixamorig_RightForeArm", marks.hand, marks.hand_end],
		["mixamorig_LeftShoulder", "mixamorig_Spine2", mirror.call(marks.shoulder), mirror.call(marks.arm)],
		["mixamorig_LeftArm", "mixamorig_LeftShoulder", mirror.call(marks.arm), mirror.call(marks.forearm)],
		["mixamorig_LeftForeArm", "mixamorig_LeftArm", mirror.call(marks.forearm), mirror.call(marks.hand)],
		["mixamorig_LeftHand", "mixamorig_LeftForeArm", mirror.call(marks.hand), mirror.call(marks.hand_end)],
		["mixamorig_RightUpLeg", "mixamorig_Hips", marks.upleg, marks.leg],
		["mixamorig_RightLeg", "mixamorig_RightUpLeg", marks.leg, marks.foot],
		["mixamorig_RightFoot", "mixamorig_RightLeg", marks.foot, marks.toe],
		["mixamorig_RightToeBase", "mixamorig_RightFoot", marks.toe, marks.toe_end],
		["mixamorig_LeftUpLeg", "mixamorig_Hips", mirror.call(marks.upleg), mirror.call(marks.leg)],
		["mixamorig_LeftLeg", "mixamorig_LeftUpLeg", mirror.call(marks.leg), mirror.call(marks.foot)],
		["mixamorig_LeftFoot", "mixamorig_LeftLeg", mirror.call(marks.foot), mirror.call(marks.toe)],
		["mixamorig_LeftToeBase", "mixamorig_LeftFoot", mirror.call(marks.toe), mirror.call(marks.toe_end)],
	]

	var skel := Skeleton3D.new()
	skel.name = "Skeleton3D"
	var global_rest := {}         ## bone name -> global Transform3D
	for row in bones:
		var bname: String = row[0]
		var parent: String = row[1]
		var joint: Vector3 = row[2]
		var aim: Vector3 = row[3]
		var basis := _aim_basis(aim - joint)
		var g := Transform3D(basis, joint)
		global_rest[bname] = g
		var idx := skel.get_bone_count()
		skel.add_bone(bname)
		var local := g
		if parent != "":
			skel.set_bone_parent(idx, skel.find_bone(parent))
			local = (global_rest[parent] as Transform3D).affine_inverse() * g
		skel.set_bone_rest(idx, local)
		skel.set_bone_pose_position(idx, local.origin)
		skel.set_bone_pose_rotation(idx, local.basis.get_rotation_quaternion())
	print("skeleton %d bones" % skel.get_bone_count())

	## --- the skin: every vertex rigid to its region's bone --------------------
	var arrays: Array = src_mesh.mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var xf := src_mesh.global_transform
	var bone_ids := PackedInt32Array()
	var weights := PackedFloat32Array()
	bone_ids.resize(verts.size() * 4)
	weights.resize(verts.size() * 4)
	var tally := {}
	for i in verts.size():
		var w: Vector3 = xf * verts[i]
		var bname := _bone_for(w, marks)
		var b := skel.find_bone(bname)
		tally[bname] = int(tally.get(bname, 0)) + 1
		bone_ids[i * 4] = b
		weights[i * 4] = 1.0
		for k in range(1, 4):
			bone_ids[i * 4 + k] = 0
			weights[i * 4 + k] = 0.0
		## The mesh keeps its own vertex positions; only the transform the glb
		## carried is baked in, so the skin binds and the vertices agree.
		verts[i] = w
	arrays[Mesh.ARRAY_VERTEX] = verts
	if arrays[Mesh.ARRAY_NORMAL] != null:
		var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var nb := xf.basis.orthonormalized()
		for i in norms.size():
			norms[i] = (nb * norms[i]).normalized()
		arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_BONES] = bone_ids
	arrays[Mesh.ARRAY_WEIGHTS] = weights
	for bname in tally.keys():
		print("  %-26s %5d verts" % [bname, tally[bname]])

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, _portable(src_mesh.mesh.surface_get_material(0)))

	var skin := Skin.new()
	for b in skel.get_bone_count():
		var bname := skel.get_bone_name(b)
		skin.add_bind(b, (global_rest[bname] as Transform3D).affine_inverse())
		skin.set_bind_name(skin.get_bind_count() - 1, bname)

	## --- the scene: feet on y = 0, the frame place() expects ------------------
	var out_root := Node3D.new()
	out_root.name = name.capitalize()
	var lift := Node3D.new()
	lift.name = "Armature"
	var floor_y := INF
	for i in verts.size():
		floor_y = minf(floor_y, verts[i].y)
	lift.position = Vector3(0.0, -floor_y, 0.0)
	out_root.add_child(lift)
	lift.add_child(skel)
	var inst := MeshInstance3D.new()
	inst.name = "Mesh"
	inst.mesh = mesh
	inst.skin = skin
	skel.add_child(inst)
	lift.owner = out_root
	skel.owner = out_root
	inst.owner = out_root

	var packed := PackedScene.new()
	packed.pack(out_root)
	## Binary, not text: the scene embeds its textures, and base64-in-a-tscn
	## doubles what the same bytes cost in a .scn.
	var out := "res://assets/models/%s/%s_rigged.scn" % [name, name]
	var err := ResourceSaver.save(packed, out)
	print("floor %.3f lifted; %s %s" % [floor_y, "OK saved" if err == OK else "FAIL saving", out])
	src.queue_free()
	quit(0 if err == OK else 1)


## The imported glb's material carries CompressedTexture2D sub-resources that
## live inside `.godot/imported/` — saving a scene that references them writes
## texture SHELLS that come back NULL after the next reimport ("Parameter tex
## is null", and a white scrapper). The Boilerwright's baked mesh embeds its
## image DATA (2.3 MB of it) for exactly this reason. So: decompress every
## map to an Image and rebuild the material around embeddable ImageTextures.
func _portable(mat: Material) -> Material:
	var src := mat as BaseMaterial3D
	if src == null:
		return mat
	var out := StandardMaterial3D.new()
	out.albedo_color = src.albedo_color
	out.metallic = src.metallic
	out.roughness = src.roughness
	out.normal_enabled = src.normal_enabled
	out.normal_scale = src.normal_scale
	out.emission_enabled = src.emission_enabled
	out.emission = src.emission
	out.emission_energy_multiplier = src.emission_energy_multiplier
	out.metallic_texture_channel = src.metallic_texture_channel
	out.roughness_texture_channel = src.roughness_texture_channel
	for slot in [BaseMaterial3D.TEXTURE_ALBEDO, BaseMaterial3D.TEXTURE_METALLIC,
			BaseMaterial3D.TEXTURE_ROUGHNESS, BaseMaterial3D.TEXTURE_NORMAL,
			BaseMaterial3D.TEXTURE_EMISSION]:
		var tex := src.get_texture(slot)
		if tex == null:
			continue
		var img := tex.get_image()
		if img == null:
			continue
		if img.is_compressed():
			img.decompress()
		## A black JPEG decodes to a single-channel format the real renderer
		## refuses to sample — the texture binds WHITE, and white x the glTF's
		## white emission factor is a figure drawn as a flat white silhouette
		## (found by rendering, invisible to every headless probe). Force a
		## format everything samples, and drop an emission channel whose map
		## is black: Meshy bakes this model's lens glow into the albedo, so a
		## black emission map is a channel that can only ever hurt.
		img.convert(Image.FORMAT_RGBA8)
		if slot == BaseMaterial3D.TEXTURE_EMISSION:
			var lit := false
			for y in range(0, img.get_height(), 4):
				for x in range(0, img.get_width(), 4):
					if img.get_pixel(x, y).get_luminance() > 0.02:
						lit = true
						break
				if lit:
					break
			if not lit:
				out.emission_enabled = false
				continue
		## Plain ImageTexture, the Boilerwright's own precedent (his baked
		## mesh embeds 2.3 MB of image data) — because both compressed forms
		## FAILED here in ways only a rendered frame reveals: referencing the
		## import artifact's CompressedTexture2D saves shells that reload
		## null, and PortableCompressedTexture2D (lossy WebP, buffers kept)
		## probed fine headless and still sampled WHITE under the real
		## renderer. Raw pixels at full size are 17 MB of commit, so the maps
		## are first cut to the meshy.py budget for a sub-260 px figure:
		## 512 albedo, 256 normal, 128 for the modulation maps.
		var side := 512 if slot == BaseMaterial3D.TEXTURE_ALBEDO else \
			(256 if slot == BaseMaterial3D.TEXTURE_NORMAL else 128)
		if img.get_width() > side or img.get_height() > side:
			img.resize(mini(side, img.get_width()), mini(side, img.get_height()),
				Image.INTERPOLATE_LANCZOS)
		out.set_texture(slot, ImageTexture.create_from_image(img))
	return out


## An orthonormal basis whose Y runs along the bone — the convention every
## humanoid rig this repo has met uses, and the one the retarget math needs
## the two rigs to share for clip rotations to land about the right axes.
func _aim_basis(along: Vector3) -> Basis:
	var y := along.normalized()
	var ref := Vector3(0, 0, 1)
	if absf(y.dot(ref)) > 0.95:
		ref = Vector3(1, 0, 0)
	var x := ref.cross(y).normalized()
	var z := x.cross(y).normalized()
	return Basis(x, y, z).orthonormalized()


## Which rigid part a vertex belongs to. Regions, not distances: measured off
## the slice map, ordered so the specific (head, legs, arms) claim their
## territory before the ball takes everything left.
func _bone_for(w: Vector3, m: Dictionary) -> String:
	var side := "Right" if w.x >= 0.0 else "Left"
	var r := Vector2(w.x, w.z).length()
	if w.y > float(m.head_over) and r < float(m.core_radius):
		return "mixamorig_Head"
	if w.y > float(m.neck_over) and r < float(m.core_radius):
		return "mixamorig_Neck"
	if w.y < float(m.leg_under):
		if absf(w.x) < float(m.leg_split_x):
			return "mixamorig_Hips"
		if w.y < float(m.ankle_y):
			if w.z > float(m.toe_z):
				return "mixamorig_%sToeBase" % side
			return "mixamorig_%sFoot" % side
		if w.y < float(m.knee_y):
			return "mixamorig_%sLeg" % side
		return "mixamorig_%sUpLeg" % side
	if absf(w.x) > float(m.arm_min_x) and _near_arm(w, m):
		if w.y > float(m.elbow_y):
			return "mixamorig_%sArm" % side
		if w.y > float(m.wrist_y):
			return "mixamorig_%sForeArm" % side
		return "mixamorig_%sHand" % side
	return "mixamorig_Spine1"


## Distance from the measured arm polyline (shoulder -> elbow -> wrist -> hook
## tip), mirrored by the vertex's own side.
func _near_arm(w: Vector3, m: Dictionary) -> bool:
	var s := signf(w.x) if w.x != 0.0 else 1.0
	var chain := [
		Vector3(s * absf((m.arm as Vector3).x), (m.arm as Vector3).y, (m.arm as Vector3).z),
		Vector3(s * absf((m.forearm as Vector3).x), (m.forearm as Vector3).y, (m.forearm as Vector3).z),
		Vector3(s * absf((m.hand as Vector3).x), (m.hand as Vector3).y, (m.hand as Vector3).z),
		Vector3(s * absf((m.hand_end as Vector3).x), (m.hand_end as Vector3).y, (m.hand_end as Vector3).z),
	]
	var best := INF
	for i in chain.size() - 1:
		best = minf(best, _seg_dist(w, chain[i], chain[i + 1]))
	return best < float(m.arm_axis_max)


func _seg_dist(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 1e-9), 0.0, 1.0)
	return p.distance_to(a + ab * t)
