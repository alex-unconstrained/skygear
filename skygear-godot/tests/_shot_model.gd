extends SceneTree
## The captain on her own: four headings across the idle, then a strip of the
## run. Sorting out "is the model wrong" from "is the scene washing her out"
## needs her away from the scene.
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
	e.ambient_light_energy = 0.9
	env.environment = e
	root3d.add_child(env)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35, 145, 0)
	key.light_energy = 1.7
	root3d.add_child(key)
	var scene: PackedScene = load("res://assets/models/captain/captain.tscn")
	var clip := "idle"
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		clip = args[0]
	for i in 4:
		var it := scene.instantiate()
		it.position = Vector3(-3.0 + i * 2.0, -0.95, 0)
		it.rotation = Vector3(0, TAU * float(i) / 4.0, 0)
		root3d.add_child(it)
		var p := it.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if p != null and clip != "none":
			p.play(clip)
			p.seek(0.6 + i * 0.25, true)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 0.25, 4.2)
	cam.fov = 45.0
	cam.current = true
	root3d.add_child(cam)
	for i in 6:
		await process_frame
	root.get_texture().get_image().save_png("res://../.shots/captain-%s.png" % clip)
	print("shot ", clip)
	quit(0)
