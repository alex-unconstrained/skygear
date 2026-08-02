extends SceneTree
## Judge a raw generated character mesh WITHOUT rendering a frame — headless
## get_image() hangs on this machine (SG-29), so pose is read off the geometry
## the way the SG-12 task asks: arms clear of the torso, feet apart, and the
## overall bounding box (a rig wants a clean A/T-pose, not a posed figure).
##
##   godot --path . --headless --script tools/mesh_pose.gd -- <glb-res-path>
##
## Prints the AABB in the mesh's own units, then two spread ratios sampled by
## height band: SHOULDER band (upper ~15%) and ANKLE band (lower ~12%). A clean
## A-pose reads a WIDE shoulder/arm band (arms out) and feet apart at the ankles.
func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var path := args[0] if args.size() > 0 else "res://assets/models/boilerwright/boilerwright.glb"
	if not ResourceLoader.exists(path):
		print("FAIL no ", path); quit(1); return
	var want_bones := "--bones" in args
	var scene := (load(path) as PackedScene).instantiate()
	root.add_child(scene)
	if want_bones:
		var sk := scene.find_child("*", true, false)
		var skel: Skeleton3D = null
		for n in scene.find_children("*", "Skeleton3D", true, false):
			skel = n as Skeleton3D
		if skel == null:
			print("BONES none — no Skeleton3D in ", path)
		else:
			print("BONES %d in the rig:" % skel.get_bone_count())
			var mixamo := 0
			for b in skel.get_bone_count():
				var nm := skel.get_bone_name(b)
				var par := skel.get_bone_parent(b)
				if nm.to_lower().contains("mixamo"):
					mixamo += 1
				print("  %2d  %-28s parent %d" % [b, nm, par])
			print("MIXAMO-NAMED %d of %d bones (retarget is one command if all; a name map if none)"
				% [mixamo, skel.get_bone_count()])
	var verts: PackedVector3Array = []
	var tris := 0
	for mi in scene.find_children("*", "MeshInstance3D", true, false):
		var m: Mesh = (mi as MeshInstance3D).mesh
		if m == null: continue
		for s in m.get_surface_count():
			var arr := m.surface_get_arrays(s)
			var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
			tris += (idx.size() / 3) if idx.size() > 0 else (v.size() / 3)
			for p in v: verts.append(p)
	if verts.is_empty():
		print("FAIL no vertices"); quit(1); return
	var lo := verts[0]; var hi := verts[0]
	for p in verts:
		lo = Vector3(minf(lo.x,p.x), minf(lo.y,p.y), minf(lo.z,p.z))
		hi = Vector3(maxf(hi.x,p.x), maxf(hi.y,p.y), maxf(hi.z,p.z))
	var size := hi - lo
	# A raw Meshy glb may be Y-up or Z-up; take the LONGEST axis as height and the
	# WIDEST of the remaining two as the span the arms/feet spread along.
	var up := 1
	if size.z >= size.y and size.z >= size.x: up = 2
	elif size.x >= size.y and size.x >= size.z: up = 0
	var span := 0
	var rest := [0, 1, 2]; rest.erase(up)
	span = rest[0] if size[rest[0]] >= size[rest[1]] else rest[1]
	var names := ["X", "Y", "Z"]
	var band := func(a: float, b: float) -> float:
		var c0 := lo[up] + size[up] * a
		var c1 := lo[up] + size[up] * b
		var slo := 1e9; var shi := -1e9
		for p in verts:
			if p[up] >= c0 and p[up] <= c1:
				slo = minf(slo, p[span]); shi = maxf(shi, p[span])
		return (shi - slo) / maxf(0.0001, size[span])
	print("verts %d  tris ~%d" % [verts.size(), tris])
	print("aabb  X %.4f  Y %.4f  Z %.4f  -> height axis %s (%.3f), span axis %s (%.3f)" %
		[size.x, size.y, size.z, names[up], size[up], names[span], size[span]])
	print("width/height %.3f   (broad build > ~0.40)" % (size[span]/maxf(0.0001,size[up])))
	print("shoulder band (0.82-0.97) span-fraction = %.3f  (arms out A-pose > ~0.75)" % band.call(0.82, 0.97))
	print("arm/hip band  (0.45-0.62) span-fraction = %.3f" % band.call(0.45, 0.62))
	print("ankle band    (0.00-0.12) span-fraction = %.3f  (feet apart > ~0.45)" % band.call(0.00, 0.12))
	scene.queue_free()
	quit(0)
