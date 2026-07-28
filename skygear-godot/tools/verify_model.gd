extends SceneTree
## Prove an ingested model stands on its own, with its sources deleted.
##
## The captain passed a "does it load" check while the FBXs were still on disk
## and then failed to load in the game, because the check was run before the
## staging directory was removed. This runs after.
func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var name := args[0] if args.size() > 0 else "captain"
	var path := "res://assets/models/%s/%s.tscn" % [name, name]
	var bad := 0

	if not ResourceLoader.exists(path):
		print("FAIL %s does not exist" % path)
		quit(1)
		return
	for dep in ResourceLoader.get_dependencies(path):
		if dep.contains("import_staging"):
			print("FAIL depends on staging: %s" % dep)
			bad += 1
	var scene := load(path) as PackedScene
	if scene == null:
		print("FAIL %s will not load" % path)
		quit(1)
		return
	var root := scene.instantiate()
	root3d_check(root)
	var player := root.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if player == null:
		print("FAIL no AnimationPlayer")
		bad += 1
	else:
		var clips := player.get_animation_list()
		print("OK   %d clips: %s" % [clips.size(), ", ".join(clips)])
		var stray := 0
		for clip in clips:
			var anim: Animation = player.get_animation(clip)
			if anim.get_track_count() == 0:
				print("FAIL clip %s has no tracks" % clip)
				bad += 1
			for t in anim.get_track_count():
				var p := anim.track_get_path(t)
				if p.get_subname_count() > 0 and root.get_node_or_null(NodePath(p.get_concatenated_names())) == null:
					stray += 1
		if stray > 0:
			print("FAIL %d tracks point at a node that is not in the scene" % stray)
			bad += 1
		else:
			print("OK   every track resolves against the rig")
	if float(root.get_meta("model_height", 0.0)) <= 0.0:
		print("FAIL no measured height in the scene metadata")
		bad += 1
	else:
		print("OK   measured height %.3f, target %.0f units"
			% [float(root.get_meta("model_height")), float(root.get_meta("target_height", 0.0))])
	root.queue_free()
	print("OK   %s is self-contained" % name if bad == 0 else "FAIL %d problem(s)" % bad)
	quit(bad)

func root3d_check(root: Node) -> void:
	var meshes := root.find_children("*", "MeshInstance3D", true, false)
	if meshes.is_empty():
		print("FAIL no mesh in the scene")
		return
	var surfaces := 0
	var textured := 0
	for m in meshes:
		var mi := m as MeshInstance3D
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			surfaces += 1
			var mat := mi.mesh.surface_get_material(i)
			if mat is StandardMaterial3D and (mat as StandardMaterial3D).albedo_texture != null:
				textured += 1
	print("OK   %d surface(s), %d textured" % [surfaces, textured])
