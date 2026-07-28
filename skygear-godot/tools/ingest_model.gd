extends SceneTree
## The engine half of the model ingest. Driven by `tools/ingest_model.py`, which
## has already unpacked the archive, downscaled the maps and staged the files
## Godot needs to import. Everything here needs the importer to have run.
##
## Reads `import_staging/job.json`, writes `assets/models/<name>/`:
##
##   <name>.tscn        the rig, self-contained
##   <name>_mesh.res    the skinned mesh, with our material baked onto it
##   <name>_skin.res    the bind poses
##   <name>_anims.res   every clip, retargeted onto the rig we kept
##
## Nothing it writes refers to `import_staging/`, which the caller then deletes.
## See `tools/ingest_model.py` for the six problems this exists to solve.
func _initialize() -> void: call_deferred("_run")

const STAGING := "res://import_staging/"


func _find(node: Node, type: String) -> Node:
	if node.get_class() == type:
		return node
	for child in node.get_children():
		var hit := _find(child, type)
		if hit != null:
			return hit
	return null


func _own(node: Node, owner: Node) -> void:
	for child in node.get_children():
		child.owner = owner
		_own(child, owner)


## Move a clip from the rig it was baked on to the rig we are keeping.
##
## What transfers between two rests is the motion relative to rest. For a bone
## with rest R and animated local pose P that is `D = R^-1 * P`, so replaying it
## on rest A gives `P_A = R_A * R_B^-1 * P_B`. Translation moves as an offset
## between the two rest positions. Valid only because both rigs are the same
## character with the same bones and hierarchy, which is asserted.
func _retarget(anim: Animation, from: Skeleton3D, to_rest: Dictionary,
		skeleton_path: String) -> Dictionary:
	var from_rest := {}
	for b in from.get_bone_count():
		from_rest[from.get_bone_name(b)] = from.get_bone_rest(b)
	var moved := 0
	var repathed := 0
	var unknown := 0
	for t in anim.get_track_count():
		var path := anim.track_get_path(t)
		if path.get_subname_count() == 0:
			continue
		var bone := String(path.get_subname(0))
		## Clips do not agree where the rig lives — five under `Armature`, one
		## under `target_character` off a Rigify export — and Godot resolves
		## tracks by node path, so the odd one out animates nothing at all.
		var want := NodePath("%s:%s" % [skeleton_path, bone])
		if path != want:
			anim.track_set_path(t, want)
			repathed += 1
		if not from_rest.has(bone) or not to_rest.has(bone):
			unknown += 1
			continue
		var rb: Transform3D = from_rest[bone]
		var ra: Transform3D = to_rest[bone]
		var kind := anim.track_get_type(t)
		if kind == Animation.TYPE_ROTATION_3D:
			var fix := ra.basis.get_rotation_quaternion() * rb.basis.get_rotation_quaternion().inverse()
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
	return {"moved": moved, "repathed": repathed, "unknown": unknown}


func _run() -> void:
	var file := FileAccess.open(STAGING + "job.json", FileAccess.READ)
	if file == null:
		print("FAIL no job.json in import_staging")
		quit(1)
		return
	var job: Dictionary = JSON.parse_string(file.get_as_text())
	file.close()
	var name := str(job.name)
	var out := "res://assets/models/%s/" % name

	## The rig we keep. For Meshy this is an animation export rather than the
	## character file, because the character file's rest pose matches none of the
	## clips and clips are what has to look right.
	var rig_scene := load(STAGING + str(job.rig)) as PackedScene
	if rig_scene == null:
		print("FAIL could not load rig ", job.rig)
		quit(1)
		return
	var src := rig_scene.instantiate()
	src.name = name.capitalize()
	var skeleton := _find(src, "Skeleton3D") as Skeleton3D
	var mesh_node := _find(src, "MeshInstance3D") as MeshInstance3D
	if skeleton == null or mesh_node == null:
		print("FAIL no skeleton or mesh in the rig file")
		quit(1)
		return
	var skeleton_path := String(src.get_path_to(skeleton))
	var base_rest := {}
	for b in skeleton.get_bone_count():
		base_rest[skeleton.get_bone_name(b)] = skeleton.get_bone_rest(b)
	print("bones ", skeleton.get_bone_count(), " under ", skeleton_path)

	## --- the clips ----------------------------------------------------------
	var library := AnimationLibrary.new()
	var loops: Array = job.get("loop", [])
	for clip in (job.clips as Dictionary).keys():
		var scene := (load(STAGING + str(job.clips[clip])) as PackedScene).instantiate()
		var sk := _find(scene, "Skeleton3D") as Skeleton3D
		var player := _find(scene, "AnimationPlayer") as AnimationPlayer
		if player == null or sk == null:
			print("  %-9s FAIL no rig or player" % clip)
			scene.queue_free()
			continue
		var picked := ""
		for a in player.get_animation_list():
			if a != "RESET":
				picked = a
		if picked == "":
			print("  %-9s FAIL no clip inside" % clip)
			scene.queue_free()
			continue
		var worst := 0.0
		for b in sk.get_bone_count():
			var bone := sk.get_bone_name(b)
			if base_rest.has(bone):
				worst = maxf(worst, base_rest[bone].basis.get_rotation_quaternion()
					.angle_to(sk.get_bone_rest(b).basis.get_rotation_quaternion()))
		var anim: Animation = player.get_animation(picked).duplicate(true)
		anim.loop_mode = Animation.LOOP_LINEAR if clip in loops else Animation.LOOP_NONE
		var fixes := _retarget(anim, sk, base_rest, skeleton_path)
		library.add_animation(clip, anim)
		print("  %-9s %5.2fs %2d tracks  rest %5.1f deg  retargeted %2d  repathed %2d%s"
			% [clip, anim.length, anim.get_track_count(), rad_to_deg(worst),
				int(fixes.moved), int(fixes.repathed),
				"  UNKNOWN BONES %d" % int(fixes.unknown) if int(fixes.unknown) > 0 else ""])
		scene.queue_free()
	ResourceSaver.save(library, out + name + "_anims.res")

	## --- the mesh -----------------------------------------------------------
	var mesh: ArrayMesh = mesh_node.mesh.duplicate(true)
	var maps: Dictionary = job.get("maps", {})
	var skin := StandardMaterial3D.new()
	if maps.has("albedo"):
		skin.albedo_texture = load(out + str(maps.albedo))
	if maps.has("normal"):
		skin.normal_enabled = true
		skin.normal_texture = load(out + str(maps.normal))
	if maps.has("rough"):
		skin.roughness_texture = load(out + str(maps.rough))
		skin.roughness = 1.0
	if maps.has("metal"):
		skin.metallic_texture = load(out + str(maps.metal))
		skin.metallic = 1.0
	## A whisper of rim, so a lit mesh reads against a deck of unshaded painted
	## billboards. Any more bleaches it — most of a small figure seen at 41
	## degrees is grazing angle, which is the opposite of what rim lighting
	## assumes.
	skin.rim_enabled = true
	skin.rim = 0.16
	skin.rim_tint = 0.75
	## Onto the MESH, not as an instance override. The surface still carries the
	## material Godot built while importing, and that one points at a texture
	## unpacked into the staging directory — saving it saves a dependency on a
	## file that is about to be deleted, and the resource then fails to load with
	## nothing on screen and no error anyone would connect to it.
	for i in mesh.get_surface_count():
		mesh.surface_set_material(i, skin)
	ResourceSaver.save(mesh, out + name + "_mesh.res")
	mesh_node.mesh = load(out + name + "_mesh.res")
	mesh_node.set_surface_override_material(0, null)
	mesh_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	if mesh_node.skin != null:
		ResourceSaver.save(mesh_node.skin.duplicate(true), out + name + "_skin.res")
		mesh_node.skin = load(out + name + "_skin.res")

	## --- the scene ----------------------------------------------------------
	var player2 := _find(src, "AnimationPlayer") as AnimationPlayer
	if player2 == null:
		player2 = AnimationPlayer.new()
		player2.name = "AnimationPlayer"
		src.add_child(player2)
	player2.root_node = player2.get_path_to(src)
	for lib in player2.get_animation_library_list():
		player2.remove_animation_library(lib)
	player2.add_animation_library("", load(out + name + "_anims.res"))

	## The height, measured with every baked scale in the chain applied, written
	## into the scene as metadata so the renderer does not have to guess. FBX
	## measures in centimetres and the importer bakes a unit scale into the root.
	## In the tree first: `global_transform` on a detached node is undefined and
	## Godot says so. The chain scale is the whole reason this is measured rather
	## than read off the AABB.
	root.add_child(src)
	var tall := 0.0
	for child in src.find_children("*", "MeshInstance3D", true, false):
		var mi := child as MeshInstance3D
		tall = maxf(tall, mi.get_aabb().size.y * mi.global_transform.basis.get_scale().y)
	root.remove_child(src)
	src.set_meta("model_height", tall)
	src.set_meta("target_height", float(job.get("height", 176.0)))
	src.set_meta("facing_degrees", float(job.get("facing", 0.0)))
	src.set_meta("clips", player2.get_animation_list())
	print("height ", tall, " units  -> target ", job.get("height", 176.0))
	print("clips ", player2.get_animation_list())

	_own(src, src)
	var packed := PackedScene.new()
	packed.pack(src)
	var err := ResourceSaver.save(packed, out + name + ".tscn")
	print("OK saved " if err == OK else "FAIL saving ", out + name + ".tscn")
	quit(0 if err == OK else 1)
