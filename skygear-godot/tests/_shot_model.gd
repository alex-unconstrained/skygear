extends SceneTree
## The captain on her own, four sides, neutral light. Sorting out "is the model
## wrong" from "is the scene washing her out" needs her away from the scene.
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var root3d := Node3D.new()
	root.add_child(root3d)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("#1a1826")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("#8a90a8")
	e.ambient_light_energy = 1.0
	env.environment = e
	root3d.add_child(env)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35, 145, 0)
	key.light_energy = 1.6
	root3d.add_child(key)
	var mesh: Mesh = load("res://assets/models/captain/captain.obj")
	print("aabb ", mesh.get_aabb())
	for i in 4:
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.position = Vector3(-3.0 + i * 2.0, 0, 0)
		mi.rotation = Vector3(0, TAU * float(i) / 4.0, 0)
		root3d.add_child(mi)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 0.35, 4.2)
	cam.fov = 45.0
	cam.current = true
	root3d.add_child(cam)
	for i in 6:
		await process_frame
	root.get_texture().get_image().save_png("res://../.shots/captain-model.png")
	print("shot saved")
	quit(0)
