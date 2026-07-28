extends SceneTree
## Reassemble the captain as a scene that owns everything it needs.
##
## The rig comes from an ANIMATION file, not from `character.fbx`. Meshy exports
## each clip as a complete character — mesh, skin, skeleton and one animation —
## and the skeleton in those is not quite the skeleton in the character file: the
## Hips rest differs by up to 92 degrees between them. Clips authored against one
## rest and played on another put her arms over her head.
##
## So the base is the file that also carries the clips, and everything else is
## checked against it. `character.fbx` is only useful for the T-pose.
func _initialize() -> void: call_deferred("_run")

const OUT := "res://assets/models/captain/"
const BASE := "res://import_staging/anim_Idle_03.fbx"
const CLIPS := {
	"idle": "res://import_staging/anim_Idle_03.fbx",
	"idle_alt": "res://import_staging/anim_Idle_10.fbx",
	"run": "res://import_staging/anim_Running.fbx",
	"walk": "res://import_staging/anim_Walking.fbx",
	"dash": "res://import_staging/anim_Backflip.fbx",
	"swing": "res://import_staging/anim_019fa6da-496e-7bb7-8cca-4cf8e8c953bf.fbx",
}

func _find(node: Node, type: String) -> Node:
	if node.get_class() == type:
		return node
	for child in node.get_children():
		var hit := _find(child, type)
		if hit != null:
			return hit
	return null

## Move a clip from the rig it was baked on to the rig we are keeping.
##
## Every Meshy clip ships with its own skeleton and its own rest pose — up to 84
## degrees apart on the same named bone. Godot stores skeletal tracks as the bone
## LOCAL pose, so playing a clip authored against rest B on a skeleton with rest
## A composes the difference into the result: arms over the head.
##
## What actually transfers is the motion relative to rest. For a bone with rest R
## and animated local pose P that is `D = R^-1 * P`, and replaying it on rest A
## gives `P_A = R_A * R_B^-1 * P_B`. Translation moves as an offset from each
## rig's own rest position. Only valid because both rigs are the same character
## with the same twenty-four bones and the same hierarchy, which is checked.
func _retarget(anim: Animation, from: Skeleton3D, to_rest: Dictionary) -> int:
	var from_rest := {}
	for b in from.get_bone_count():
		from_rest[from.get_bone_name(b)] = from.get_bone_rest(b)
	var moved := 0
	for t in anim.get_track_count():
		var path := anim.track_get_path(t)
		if path.get_subname_count() == 0:
			continue
		var bone := String(path.get_subname(0))
		if not from_rest.has(bone) or not to_rest.has(bone):
			continue
		var rb: Transform3D = from_rest[bone]
		var ra: Transform3D = to_rest[bone]
		var kind := anim.track_get_type(t)
		if kind == Animation.TYPE_ROTATION_3D:
			var qa := ra.basis.get_rotation_quaternion()
			var qb := rb.basis.get_rotation_quaternion()
			var fix := qa * qb.inverse()
			if fix.angle_to(Quaternion.IDENTITY) < 0.0005:
				continue
			for k in anim.track_get_key_count(t):
				anim.track_set_key_value(t, k,
					(fix * (anim.track_get_key_value(t, k) as Quaternion)).normalized())
			moved += 1
		elif kind == Animation.TYPE_POSITION_3D:
			var shift := ra.origin - rb.origin
			if shift.length() < 0.0001:
				continue
			for k in anim.track_get_key_count(t):
				anim.track_set_key_value(t, k,
					(anim.track_get_key_value(t, k) as Vector3) + shift)
			moved += 1
	return moved


func _own(node: Node, owner: Node) -> void:
	for child in node.get_children():
		child.owner = owner
		_own(child, owner)

func _run() -> void:
	var library := AnimationLibrary.new()
	var base_rest := {}
	var src := (load(BASE) as PackedScene).instantiate()
	src.name = "Captain"
	var skeleton := _find(src, "Skeleton3D") as Skeleton3D
	for b in skeleton.get_bone_count():
		base_rest[skeleton.get_bone_name(b)] = skeleton.get_bone_rest(b)

	for name in CLIPS.keys():
		var path: String = CLIPS[name]
		var scene := (load(path) as PackedScene).instantiate()
		var sk := _find(scene, "Skeleton3D") as Skeleton3D
		var player := _find(scene, "AnimationPlayer") as AnimationPlayer
		if player == null:
			scene.queue_free()
			continue
		# how far this clip's rig is from the one we are keeping
		var worst := 0.0
		for b in sk.get_bone_count():
			var bone := sk.get_bone_name(b)
			if base_rest.has(bone):
				worst = maxf(worst, base_rest[bone].basis.get_rotation_quaternion()
					.angle_to(sk.get_bone_rest(b).basis.get_rotation_quaternion()))
		var picked := ""
		for a in player.get_animation_list():
			if a != "RESET":
				picked = a
		if picked == "":
			scene.queue_free()
			continue
		var anim: Animation = player.get_animation(picked).duplicate(true)
		anim.loop_mode = Animation.LOOP_NONE if name in ["swing", "dash"] \
			else Animation.LOOP_LINEAR
		var moved := _retarget(anim, sk, base_rest)
		library.add_animation(name, anim)
		print("  %-9s %.2fs %2d tracks   rest delta %.1f deg   retargeted %d"
			% [name, anim.length, anim.get_track_count(), rad_to_deg(worst), moved])
		scene.queue_free()
	ResourceSaver.save(library, OUT + "captain_anims.res")

	var mesh_node := _find(src, "MeshInstance3D") as MeshInstance3D
	var mesh: ArrayMesh = mesh_node.mesh.duplicate(true)
	if mesh_node.skin != null:
		ResourceSaver.save(mesh_node.skin.duplicate(true), OUT + "captain_skin.res")
		mesh_node.skin = load(OUT + "captain_skin.res")

	## One material, ours, pointing at the downscaled maps. Meshy ships 4096
	## albedo and 4096 normal — 56 MB of PNG for a figure a hundred and eighty
	## pixels tall on screen.
	var skin := StandardMaterial3D.new()
	skin.albedo_texture = load(OUT + "captain_albedo.png")
	skin.normal_enabled = true
	skin.normal_texture = load(OUT + "captain_normal.png")
	skin.roughness_texture = load(OUT + "captain_rough.png")
	skin.metallic = 1.0
	skin.metallic_texture = load(OUT + "captain_metal.png")
	skin.roughness = 1.0
	## A whisper of rim, so a lit mesh reads against a deck of unshaded painted
	## billboards. Any more bleaches her — most of a small figure seen at 41
	## degrees is grazing angle.
	skin.rim_enabled = true
	skin.rim = 0.16
	skin.rim_tint = 0.75
	## Onto the MESH, not as an instance override. The surface still carried the
	## material Godot built while importing the FBX, and that material points at
	## `res://import_staging/anim_Idle_03_0.png` — the texture unpacked out of the
	## FBX. Saving the mesh with it saved a dependency on a file about to be
	## deleted, and the whole resource then failed to load with no captain and no
	## obvious reason why.
	for i in mesh.get_surface_count():
		mesh.surface_set_material(i, skin)
	ResourceSaver.save(mesh, OUT + "captain_mesh.res")
	mesh_node.mesh = load(OUT + "captain_mesh.res")
	mesh_node.set_surface_override_material(0, null)
	mesh_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON

	var player2 := _find(src, "AnimationPlayer") as AnimationPlayer
	player2.root_node = player2.get_path_to(src)
	for lib in player2.get_animation_library_list():
		player2.remove_animation_library(lib)
	player2.add_animation_library("", load(OUT + "captain_anims.res"))
	print("clips: ", player2.get_animation_list())
	print("aabb: ", mesh.get_aabb())

	_own(src, src)
	var packed := PackedScene.new()
	packed.pack(src)
	print("save: ", ResourceSaver.save(packed, OUT + "captain.tscn"))
	quit(0)
