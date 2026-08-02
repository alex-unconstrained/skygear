extends SceneTree
## Every generated model, alone, at the size and angle the game actually shows it.
##
##   godot --path . --headless --resolution 1920x1080 --script tests/_shot_models.gd -- before
##   godot --path . --headless --resolution 1920x1080 --script tests/_shot_models.gd -- after
##
## Writes .shots/models/<tag>/<key>.png, one per model, so the two runs can be
## put side by side.
##
## `tools/model_lab.gd` already views a model and reports its triangles, and it
## frames each one on its own bounding box so a keg and a Colossus are both
## legible. That is the right thing for judging a model AS a model and the wrong
## thing for the only question a remesh raises, which is: at THIS camera, at the
## real distance, did anything get worse? A keg that fills the frame in the lab
## is 187 pixels tall on the deck, and detail arguments settled at the wrong
## size are how you end up paying for triangles nobody can see.
##
## So the camera here is not a viewer's camera. It is view3d.gd's, solved from
## the same four constants, and the model is scaled to the same ground-unit
## height the renderer scales it to. What comes out is the number of pixels the
## player gets.
func _initialize() -> void: call_deferred("_run")

## key -> height in ground units, the same numbers view3d.gd places them at:
## PROP_HEIGHT, BOILER_HEIGHT, 120 + radius*3 for a boarder, and weapons.json
## length for a weapon. Kept here rather than imported because four of these
## models are deliberately NOT wired into the renderer — brazier, crate_small
## and boarding_hulk are on disk and painted over — and they still have to be
## looked at, at the size they would have had. (`armored` was the fourth until
## board SG-85: the owner's furnace knight ships as `armored.tscn`, so this
## renders the shipped rig now, at the height the renderer gives it. The
## `.tscn`-before-`.glb` preference below made that a zero-line change.)
const HEIGHT := {
	"sword_cutlass": 95.0, "sword_gearblade": 95.0,
	"scrapper": 186.0, "gunner": 183.0, "armored": 216.0, "swarm": 165.0,
	"boss": 330.0, "boiler": 168.0, "boarding_hulk": 420.0,
	## The owner's own three-state hulk (SG-76). Same 420 as the sprite it
	## replaces, three times, because the three states are one object wearing
	## three faces and a state that came out a different size would pop.
	"boarding_hulk_sealed": 420.0, "boarding_hulk_open": 420.0,
	"boarding_hulk_destroyed": 420.0,
	"crate_stack": 148.0, "crate_small": 84.0, "powder_keg": 100.0,
	"lantern_post": 200.0, "brazier": 116.0, "steam_vent": 52.0,
	"cannon_deck": 130.0, "salvage_pile": 62.0, "captain": 176.0,
	"mast_section": 340.0, "harpoon_ballista": 118.0,
}


func _run() -> void:
	var tag := "shot"
	var argv := OS.get_cmdline_user_args()
	if argv.size() > 0:
		tag = str(argv[0])
	## An absolute OS path, not "res://.shots/...". `.shots` starts with a dot,
	## so Godot's resource filesystem does not scan it and DirAccess will not
	## create inside it; and the "res://../.shots/" the older shot scripts use
	## resolves to a reserved Windows pipe name and fails with two errors and a
	## success message, which is how this was found.
	var shots := ProjectSettings.globalize_path("res://") + ".shots/models/%s" % tag
	DirAccess.make_dir_recursive_absolute(shots)

	## A SubViewport at exactly the project's viewport size, not the window.
	## `--resolution 1920x1080` was ignored here (project.godot sets
	## window/size/mode=3) and the first pass came out 2560x1440, which silently
	## makes every "how many pixels is this" number 33% wrong. Rendering into a
	## fixed viewport makes the answer independent of whoever's monitor this ran on.
	var vp := SubViewport.new()
	vp.size = Vector2i(int(ProjectSettings.get_setting("display/window/size/viewport_width", 1920)),
		int(ProjectSettings.get_setting("display/window/size/viewport_height", 1080)))
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.transparent_bg = false
	root.add_child(vp)
	var world := Node3D.new()
	vp.add_child(world)
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

	## The planking, so a silhouette is judged against something and not against
	## a void. Big enough to run past the bottom of frame at this pitch.
	var deck := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(60.0, 60.0)
	deck.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("#3a3226")
	deck.material_override = mat
	world.add_child(deck)

	## view3d.gd's lens, not a similar one: the same
	## 2*atan(REF_HEIGHT/2 / FOCAL). A model looked at through anything else is
	## a model looked at at the wrong size.
	var cam := Camera3D.new()
	cam.fov = rad_to_deg(2.0 * atan((SkyGearView3D.REF_HEIGHT * 0.5) / SkyGearView3D.FOCAL))
	cam.rotation = Vector3(-SkyGearView3D.PITCH, 0.0, 0.0)
	cam.near = 0.05
	cam.far = 400.0
	cam.current = true
	world.add_child(cam)

	## THE DISTANCE IS THE POINT, and it is the game's: the deck camera sits
	## CAM_HEIGHT above the planking and CAM_NEAR back along it, so it is
	## hypot(760, 460) = 888 ground units from what it is looking at. Placing the
	## camera at that same range, at the same 41-degree pitch, aimed at the
	## middle of each model, gives each one the pixel height the player gets and
	## puts it in the middle of the frame instead of half out of the bottom of
	## it — which is what the first pass did, having copied the camera's absolute
	## position and left the model at the origin below the optical axis.
	var range_m: float = sqrt(SkyGearView3D.CAM_HEIGHT * SkyGearView3D.CAM_HEIGHT
		+ SkyGearView3D.CAM_NEAR * SkyGearView3D.CAM_NEAR) * SkyGearView3D.WORLD_SCALE

	var keys: Array[String] = []
	for dir in DirAccess.get_directories_at("res://assets/models"):
		if HEIGHT.has(str(dir)):
			keys.append(str(dir))
	keys.sort()

	for k in keys:
		var path := "res://assets/models/%s/%s.tscn" % [k, k]
		if not ResourceLoader.exists(path):
			path = "res://assets/models/%s/%s.glb" % [k, k]
		if not ResourceLoader.exists(path):
			print("MISSING %s" % k)
			continue
		var packed := load(path) as PackedScene
		if packed == null:
			print("FAIL    %s will not load" % k)
			continue
		var holder := Node3D.new()
		world.add_child(holder)
		var it := packed.instantiate()
		holder.add_child(it)

		## Measured the same way static_model.gd measures, and for the same
		## reason: the max of the individual mesh heights is not the union as
		## soon as a model arrives in more than one piece. A .glb loaded raw has
		## no model_height meta, so both paths are needed.
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
			print("FAIL    %s HAS NO MESHES - the pruning trap, check "
				+ "gltf/embedded_image_handling=2 in its .import" % k)
			holder.queue_free()
			continue
		if tall <= 0.0:
			tall = box.size.y

		var target: float = float(HEIGHT[k]) * SkyGearView3D.WORLD_SCALE
		var scale_k: float = target / maxf(0.0001, tall)
		holder.scale = Vector3(scale_k, scale_k, scale_k)
		## Stood on the deck and centred, because a raw .glb is centred on its
		## own bounding box and would otherwise be buried to the waist.
		holder.position = Vector3(-box.get_center().x, -box.position.y, -box.get_center().z) * scale_k

		cam.position = Vector3(0.0,
			target * 0.5 + range_m * sin(SkyGearView3D.PITCH),
			range_m * cos(SkyGearView3D.PITCH))

		for _i in 4:
			await process_frame
		var shot := "%s/%s.png" % [shots, k]
		vp.get_texture().get_image().save_png(shot)
		print("%-16s %6d tris  %5.0f ground units  -> %s" % [k, tris, HEIGHT[k], shot])
		holder.queue_free()
		await process_frame

	print("done")
	quit(0)
