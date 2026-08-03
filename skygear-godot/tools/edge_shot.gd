extends SceneTree
## STILL: NOT APPLICABLE — there is no deck here to freeze (SG-108). This builds
## its own empty world, adds ONE static mesh to it and photographs that: no
## simulation, no renderer, no boarders and not a single `AnimationPlayer` in
## the tree, so `SkyGearStill.freeze` would have nothing to hold. The half of
## SG-108 that DOES apply to a lone mesh is the readback, and that is not
## declared away — every grab below waits on `RenderingServer.frame_post_draw`
## rather than on `process_frame`, because the tree finishing a frame is not the
## renderer finishing one and the bad grab is intermittent.
##
## ONE DECK-EDGE PIECE, SEVERAL HEADINGS, AT THE SHIPPED CAMERA. SG-148.
##
##   godot --path . --headless --script tools/edge_shot.gd -- --tag before \
##       --keys bow_ram,stern_counter,mast_crowned
##   ... --keys mast_crowned_t3000 --tag ladder --angles 0,35,90
##   ... --keys mast_crowned --tag detail --zoom 3.5
##
## Writes `.shots/sg148/<tag>/<key>-y<angle>.png`.
##
## WHY THIS EXISTS WHEN `tests/_shot_models.gd` ALREADY PHOTOGRAPHS MODELS.
## That tool is the right camera and the wrong subject list. It renders EVERY
## key in its own `HEIGHT` table at ONE heading, which is exactly what a remesh
## regression sweep wants and exactly what judging a decimation does not: the
## question here is whether a specific piece lost a specific feature, and the
## feature is on one side of it. A single yaw cannot answer that, and its table
## is keyed to models the renderer places — these three are placed nowhere yet,
## which is the whole of SG-145.
##
## THE CAMERA IS COPIED DELIBERATELY AND NOT REINVENTED. Same solve as
## `_shot_models.gd`: `view3d.gd`'s own lens, its own 41-degree pitch, and the
## hypot(CAM_HEIGHT, CAM_NEAR) = 888-unit range that is how far the deck camera
## actually stands off what it looks at. A decimation argued at any other
## distance is an argument about pixels nobody is shown — which is the mistake
## `meshy.py`'s triangle law was written to stop, and the reason its budget for
## every piece in this kit is the 3,000 floor rather than the 8,000 ceiling.
##
## THE SCALE IS THE MODEL'S OWN. `_shot_models.gd` scales each key to the height
## the renderer gives it; nothing gives these a height yet (NEEDS_ALEX §14 —
## the kit's scale is the owner's and is reported rather than decided), so this
## renders them at the size they were authored, 1 m = 100 ground units. When
## placement is settled, pass `--height`.
##
## `--zoom` is the one departure from the shipped camera and it is for looking
## at damage, never for judging it: it divides the standoff, so a rigging line
## can be inspected after the shipped-distance frame has already decided
## whether it matters.
func _initialize() -> void: call_deferred("_run")


func _run() -> void:
	var tag := "shot"
	var keys: Array[String] = []
	var angles: Array[float] = [0.0, 35.0, -35.0, 90.0, 180.0]
	var zoom := 1.0
	var height := 0.0
	var argv := OS.get_cmdline_user_args()
	for i in argv.size():
		if argv[i] == "--tag" and i + 1 < argv.size():
			tag = str(argv[i + 1])
		if argv[i] == "--keys" and i + 1 < argv.size():
			for k in str(argv[i + 1]).split(","):
				if str(k).strip_edges() != "":
					keys.append(str(k).strip_edges())
		if argv[i] == "--angles" and i + 1 < argv.size():
			angles = []
			for a in str(argv[i + 1]).split(","):
				angles.append(float(a))
		if argv[i] == "--zoom" and i + 1 < argv.size():
			zoom = maxf(0.05, float(argv[i + 1]))
		if argv[i] == "--height" and i + 1 < argv.size():
			height = float(argv[i + 1])
	if keys.is_empty():
		push_error("edge_shot: --keys is required (comma separated)")
		quit(2)
		return

	## An absolute OS path. `.shots` is dot-prefixed so Godot's resource
	## filesystem never scans it and DirAccess cannot create inside "res://",
	## and "res://../.shots" resolves to a reserved Windows name — the trap
	## `_shot_models.gd` documents, avoided the same way it avoids it.
	var shots := ProjectSettings.globalize_path("res://") + ".shots/sg148/%s" % tag
	DirAccess.make_dir_recursive_absolute(shots)

	var vp := SubViewport.new()
	vp.size = Vector2i(int(ProjectSettings.get_setting("display/window/size/viewport_width", 1920)),
		int(ProjectSettings.get_setting("display/window/size/viewport_height", 1080)))
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.transparent_bg = false
	root.add_child(vp)
	var world := Node3D.new()
	vp.add_child(world)

	## The same lamplit room `_shot_models.gd` judges in. A metallic ceiling
	## exists because this deck has almost no environment to reflect
	## (tools/lamplit.py), so photographing these under a brighter rig than the
	## batch they will be compared against would flatter them.
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("#1b2030")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("#8a90a8")
	e.ambient_light_energy = 0.8
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	world.add_child(env)
	var key_light := DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-42.0, 34.0, 0.0)
	key_light.light_energy = 2.0
	world.add_child(key_light)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-18.0, -140.0, 0.0)
	fill.light_energy = 0.6
	fill.light_color = Color("#8fa6c9")
	world.add_child(fill)

	## The planking. A rail with gaps in it is judged by what shows THROUGH the
	## gaps — SG-145 passed the rail on exactly that, "the grid readable through
	## them" — so the floor under these carries a grid rather than being flat
	## brown. A welded-shut gap and an open one look identical against a void.
	var deck := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(60.0, 60.0)
	deck.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("#3a3226")
	deck.material_override = mat
	world.add_child(deck)
	var grid := MeshInstance3D.new()
	var im := ImmediateMesh.new()
	var gm := StandardMaterial3D.new()
	gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gm.albedo_color = Color("#6f6350")
	im.surface_begin(Mesh.PRIMITIVE_LINES, gm)
	var step := 0.1
	var half := 3.0
	var t := -half
	while t <= half + 0.0001:
		im.surface_add_vertex(Vector3(t, 0.002, -half))
		im.surface_add_vertex(Vector3(t, 0.002, half))
		im.surface_add_vertex(Vector3(-half, 0.002, t))
		im.surface_add_vertex(Vector3(half, 0.002, t))
		t += step
	im.surface_end()
	grid.mesh = im
	world.add_child(grid)

	var cam := Camera3D.new()
	cam.fov = rad_to_deg(2.0 * atan((SkyGearView3D.REF_HEIGHT * 0.5) / SkyGearView3D.FOCAL))
	cam.rotation = Vector3(-SkyGearView3D.PITCH, 0.0, 0.0)
	cam.near = 0.05
	cam.far = 400.0
	cam.current = true
	world.add_child(cam)
	var range_m: float = sqrt(SkyGearView3D.CAM_HEIGHT * SkyGearView3D.CAM_HEIGHT
		+ SkyGearView3D.CAM_NEAR * SkyGearView3D.CAM_NEAR) * SkyGearView3D.WORLD_SCALE / zoom

	for k in keys:
		var path := "res://assets/models/%s/%s.tscn" % [k, k]
		if not ResourceLoader.exists(path):
			path = "res://assets/models/%s/%s.glb" % [k, k]
		## A trimmed VARIANT lives beside the piece it came from, so
		## `mast_crowned_t3000` is a file in `mast_crowned/`, not a folder.
		if not ResourceLoader.exists(path):
			var stem := k
			while stem.rfind("_") > 0 and not ResourceLoader.exists(
					"res://assets/models/%s/%s.glb" % [stem.substr(0, stem.rfind("_")), k]):
				stem = stem.substr(0, stem.rfind("_"))
			if stem.rfind("_") > 0:
				path = "res://assets/models/%s/%s.glb" % [stem.substr(0, stem.rfind("_")), k]
		if not ResourceLoader.exists(path):
			print("MISSING %s" % k)
			continue
		var packed := load(path) as PackedScene
		if packed == null:
			print("FAIL    %s will not load" % k)
			continue

		var pivot := Node3D.new()
		world.add_child(pivot)
		var holder := Node3D.new()
		pivot.add_child(holder)
		var it := packed.instantiate()
		holder.add_child(it)

		var tall := float(it.get_meta("model_height", 0.0))
		var tris := 0
		var box := AABB()
		var first := true
		for child in it.find_children("*", "MeshInstance3D", true, false):
			var mi := child as MeshInstance3D
			if mi.mesh == null:
				continue
			for s in mi.mesh.get_surface_count():
				var arrays := mi.mesh.surface_get_arrays(s)
				if arrays.size() > Mesh.ARRAY_INDEX and arrays[Mesh.ARRAY_INDEX] != null:
					tris += (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
				elif arrays.size() > Mesh.ARRAY_VERTEX:
					tris += (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
			var wb: AABB = mi.global_transform * mi.get_aabb()
			box = wb if first else box.merge(wb)
			first = false
		if first:
			print("FAIL    %s HAS NO MESHES — the pruning trap, check "
				+ "gltf/embedded_image_handling=2 in its .import" % k)
			pivot.queue_free()
			continue
		if tall <= 0.0:
			tall = box.size.y

		## Native scale unless told otherwise: these are the owner's dimensions
		## and nothing has decided a placement height for them yet.
		var target: float = (height if height > 0.0 else tall / SkyGearView3D.WORLD_SCALE) \
			* SkyGearView3D.WORLD_SCALE
		var scale_k: float = target / maxf(0.0001, tall)
		holder.scale = Vector3(scale_k, scale_k, scale_k)
		holder.position = Vector3(-box.get_center().x, -box.position.y,
			-box.get_center().z) * scale_k
		cam.position = Vector3(0.0,
			target * 0.5 + range_m * sin(SkyGearView3D.PITCH),
			range_m * cos(SkyGearView3D.PITCH))

		for a in angles:
			pivot.rotation_degrees = Vector3(0.0, float(a), 0.0)
			for _i in 4:
				await process_frame
			## SG-29's idiom for SG-108's reason: the tree finishing its frame
			## is not the renderer finishing drawing it.
			await RenderingServer.frame_post_draw
			var shot := "%s/%s-y%03d.png" % [shots, k, int(round(a))]
			vp.get_texture().get_image().save_png(shot)
			print("%-26s %6d tris  yaw %4d  %5.0f gu  %5.1f px tall  -> %s"
				% [k, tris, int(round(a)), target / SkyGearView3D.WORLD_SCALE,
				target / SkyGearView3D.WORLD_SCALE * 1.87, shot])
		pivot.queue_free()
		await process_frame

	print("done")
	quit(0)
