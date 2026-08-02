extends SceneTree
## Retarget an ALREADY-BAKED clip library onto a freshly rigged character.
##
## `tools/ingest_model.py` retargets clips out of the RAW animation-pack FBXs.
## Board SG-12 route 2 hit a wall the archive path cannot cross: the Pro Melee
## Axe Pack archive (and the captain's Meshy rig archive) are absent from this
## machine, so there are no raw clip FBXs to read. But the fourteen clips already
## live, retargeted once, inside `assets/models/captain/captain_anims.res` — so
## this tool retargets THEM onto the Boilerwright's Meshy rig instead, which is
## the same job with the clip source moved on-disk.
##
## The retarget MATH is `tools/ingest_model.gd`'s, unchanged, because it is not
## captain-specific: motion relative to rest transfers between two rests as
## `P_to = R_to * R_from^-1 * P_from`. The one new thing is a BONE-NAME MAP: the
## captain's clips are Mixamo-named, and if the auto-rig came back with Meshy's
## own bone names the map renames the rig's bones to the Mixamo names the clips
## address (never an edit to the clips — STATUS.md's standing rule). An empty map
## means the rig already speaks Mixamo.
##
##   godot --path . --headless --script tools/retarget_library.gd -- boilerwright
##
## Reads the entry from tools/models.json. Expected keys (see the manifest note):
##   rig_glb     res:// or repo-relative path to the rigged glb (skeleton+mesh)
##   clips_from  res:// scene whose AnimationPlayer library is the clip source
##   bone_map    {rig_bone_name: mixamo_bone_name}, or {} if already Mixamo
##   clips       which library clips to copy (default: all of them)
##   loop        which loop
##   height      ground units sole to crown; the renderer scales to this
##   facing      degrees about +Y at rest (0 = faces +Z)
func _initialize() -> void: call_deferred("_run")

const MANIFEST := "res://tools/models.json"


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


## ingest_model.gd's retarget, verbatim in intent: move a clip authored on rest
## `from` onto the kept rig whose rests are `to_rest`, and repath its tracks onto
## the kept skeleton. Valid only because the two rigs are the same character with
## the same bone names — which the bone map is there to make true.
func _retarget(anim: Animation, from_rest: Dictionary, to_rest: Dictionary,
		skeleton_path: String) -> Dictionary:
	var moved := 0
	var repathed := 0
	var unknown := 0
	for t in anim.get_track_count():
		var path := anim.track_get_path(t)
		if path.get_subname_count() == 0:
			continue
		var bone := String(path.get_subname(0))
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


func _strip_root_motion(anim: Animation) -> bool:
	var changed := false
	for t in anim.get_track_count():
		if anim.track_get_type(t) != Animation.TYPE_POSITION_3D:
			continue
		var path := anim.track_get_path(t)
		if path.get_subname_count() == 0:
			continue
		var bone := String(path.get_subname(0))
		if not (bone.ends_with("Hips") or bone.ends_with("Root")):
			continue
		var keys := anim.track_get_key_count(t)
		if keys == 0:
			continue
		var anchor: Vector3 = anim.track_get_key_value(t, 0)
		for k in keys:
			var v: Vector3 = anim.track_get_key_value(t, k)
			if is_equal_approx(v.x, anchor.x) and is_equal_approx(v.z, anchor.z):
				continue
			anim.track_set_key_value(t, k, Vector3(anchor.x, v.y, anchor.z))
			changed = true
	return changed


func _res(path: String) -> String:
	if path.begins_with("res://"):
		return path
	return "res://" + path


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var name := args[0] if args.size() > 0 else "boilerwright"
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	if manifest == null or not manifest.has(name):
		print("FAIL no %r in %s" % [name, MANIFEST]); quit(1); return
	var spec: Dictionary = manifest[name]
	var out := "res://assets/models/%s/" % name

	var rig_path := _res(str(spec.get("rig_glb", "%s%s_rigged.glb" % [out, name])))
	if not ResourceLoader.exists(rig_path):
		print("FAIL rigged glb not found: ", rig_path); quit(1); return
	var src := (load(rig_path) as PackedScene).instantiate()
	src.name = name.capitalize()
	var skel := _find(src, "Skeleton3D") as Skeleton3D
	var mesh_node := _find(src, "MeshInstance3D") as MeshInstance3D
	if skel == null or mesh_node == null:
		print("FAIL the rigged glb has no skeleton or mesh"); quit(1); return

	## Rename the rig's bones to the names the clips address. Nothing else in the
	## pipeline touches bone names, so this is the whole of "write the mapping,
	## don't edit the clips".
	var bone_map: Dictionary = spec.get("bone_map", {})
	var renamed := 0
	if not bone_map.is_empty():
		for b in skel.get_bone_count():
			var nm := skel.get_bone_name(b)
			if bone_map.has(nm):
				skel.set_bone_name(b, str(bone_map[nm]))
				renamed += 1
	var skeleton_path := String(src.get_path_to(skel))
	var to_rest := {}
	for b in skel.get_bone_count():
		to_rest[skel.get_bone_name(b)] = skel.get_bone_rest(b)
	print("rig ", skel.get_bone_count(), " bones under ", skeleton_path,
		"  (%d renamed by the map)" % renamed)

	## The clip source: another ingested scene, its library already retargeted
	## once. Its skeleton's rests are the "from" rests.
	var from_scene := (load(_res(str(spec.clips_from))) as PackedScene).instantiate()
	var from_skel := _find(from_scene, "Skeleton3D") as Skeleton3D
	var from_player := _find(from_scene, "AnimationPlayer") as AnimationPlayer
	if from_skel == null or from_player == null:
		print("FAIL clips_from has no skeleton or player: ", spec.clips_from); quit(1); return
	var from_rest := {}
	for b in from_skel.get_bone_count():
		from_rest[from_skel.get_bone_name(b)] = from_skel.get_bone_rest(b)

	## How many of the source bones the rig can actually receive: the retarget is
	## only as good as this overlap, so it is printed rather than assumed.
	var shared := 0
	for nm in from_rest.keys():
		if to_rest.has(nm):
			shared += 1
	print("clip source ", from_skel.get_bone_count(), " bones, ", shared,
		" shared with the rig by name")

	var want_clips: Array = spec.get("clips", from_player.get_animation_list())
	var loops: Array = spec.get("loop", [])
	var library := AnimationLibrary.new()
	var total_unknown := 0
	for clip in want_clips:
		if not from_player.has_animation(clip):
			print("  %-9s MISSING in the source library" % clip)
			continue
		var anim: Animation = from_player.get_animation(clip).duplicate(true)
		anim.loop_mode = Animation.LOOP_LINEAR if clip in loops else Animation.LOOP_NONE
		var slid := _strip_root_motion(anim)
		var fixes := _retarget(anim, from_rest, to_rest, skeleton_path)
		total_unknown += int(fixes.unknown)
		library.add_animation(clip, anim)
		print("  %-9s %5.2fs %2d tracks  retargeted %2d  repathed %2d%s%s"
			% [clip, anim.length, anim.get_track_count(), int(fixes.moved),
				int(fixes.repathed),
				"  UNKNOWN %d" % int(fixes.unknown) if int(fixes.unknown) > 0 else "",
				"  in-placed" if slid else ""])
	from_scene.queue_free()
	ResourceSaver.save(library, out + name + "_anims.res")

	## The mesh, baked into its own resource so the scene is self-contained. The
	## rigged glb stays committed, so keeping its imported material (whose textures
	## are the glb's own sub-resources) is self-contained within the repo.
	var mesh: ArrayMesh = mesh_node.mesh.duplicate(true)
	ResourceSaver.save(mesh, out + name + "_mesh.res")
	mesh_node.mesh = load(out + name + "_mesh.res")
	mesh_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	if mesh_node.skin != null:
		ResourceSaver.save(mesh_node.skin.duplicate(true), out + name + "_skin.res")
		mesh_node.skin = load(out + name + "_skin.res")

	## The AnimationPlayer, holding only the retargeted library.
	var player := _find(src, "AnimationPlayer") as AnimationPlayer
	if player == null:
		player = AnimationPlayer.new()
		player.name = "AnimationPlayer"
		src.add_child(player)
	player.root_node = player.get_path_to(src)
	for lib in player.get_animation_library_list():
		player.remove_animation_library(lib)
	player.add_animation_library("", load(out + name + "_anims.res"))

	root.add_child(src)
	var tall := 0.0
	for child in src.find_children("*", "MeshInstance3D", true, false):
		var mi := child as MeshInstance3D
		tall = maxf(tall, mi.get_aabb().size.y * mi.global_transform.basis.get_scale().y)
	root.remove_child(src)
	src.set_meta("model_height", tall)
	src.set_meta("target_height", float(spec.get("height", 176.0)))
	src.set_meta("facing_degrees", float(spec.get("facing", 0.0)))
	src.set_meta("clips", player.get_animation_list())
	print("height ", tall, " units -> target ", spec.get("height", 176.0))
	print("clips ", player.get_animation_list())
	if total_unknown > 0:
		var warn := "WARN %d tracks addressed a bone the rig does not have; the map is incomplete and those joints stay at rest"
		print(warn % total_unknown)

	_own(src, src)
	var packed := PackedScene.new()
	packed.pack(src)
	var err := ResourceSaver.save(packed, out + name + ".tscn")
	print("OK saved " if err == OK else "FAIL saving ", out + name + ".tscn")
	quit(0 if err == OK else 1)
