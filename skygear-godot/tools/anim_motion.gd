extends SceneTree
## Does any clip MOVE the character off the position the simulation gave her?
##
## Reported: animation is "affecting where the character's model is so you can
## get stuck on terrain and objects". If a clip translates the root bone, the
## mesh drifts away from where the simulation thinks she is — she is drawn in
## one place and collides from another, which is what catching on geometry
## feels like. Mixamo ships "in place" variants for exactly this and this pack
## did not include them.
##
## MEASURED IN GROUND UNITS, which is the whole point. The first version of this
## tool read the raw track values, compared them against a threshold in model
## units, and reported every clip clean. But the rig is 0.018 units tall and is
## scaled by about ninety-nine to stand 176 units on the deck — so a 0.013 drift
## in the file is 129 units on the ship, which is most of a lane. A measurement
## in the wrong space is worse than no measurement, because it arrives with a
## verdict attached.
##
##   godot --path . --headless --script tools/anim_motion.gd
func _initialize() -> void: call_deferred("_run")

## Half a boarder's radius. Past that the mesh is visibly somewhere the
## simulation is not.
const DRIFT_LIMIT := 11.0
const TARGET_HEIGHT := 176.0


func _run() -> void:
	var scene := load("res://assets/models/captain/captain.tscn") as PackedScene
	var rig := scene.instantiate()
	root.add_child(rig)
	var player := rig.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var measured: float = float(rig.get_meta("model_height", 0.0))
	var to_ground: float = TARGET_HEIGHT / maxf(0.0001, measured)

	print("")
	print("ROOT DRIFT PER CLIP, in ground units")
	print("  model %.4f units tall, scaled x%.1f to stand %.0f on the deck"
		% [measured, to_ground, TARGET_HEIGHT])
	print("")
	var moving := 0
	var names := player.get_animation_list()
	for name in names:
		var anim: Animation = player.get_animation(name)
		var span := Vector3.ZERO
		var root_bone := ""
		for t in anim.get_track_count():
			if anim.track_get_type(t) != Animation.TYPE_POSITION_3D:
				continue
			var path := anim.track_get_path(t)
			if path.get_subname_count() == 0:
				continue
			var bone := String(path.get_subname(0))
			## Only the root. A forearm translating is a stretchy rig, not the
			## character walking away from herself.
			if not (bone.ends_with("Hips") or bone.ends_with("Root")):
				continue
			root_bone = bone
			var keys := anim.track_get_key_count(t)
			if keys == 0:
				continue
			var lo: Vector3 = anim.track_get_key_value(t, 0)
			var hi: Vector3 = lo
			for k in keys:
				var v: Vector3 = anim.track_get_key_value(t, k)
				lo = Vector3(minf(lo.x, v.x), minf(lo.y, v.y), minf(lo.z, v.z))
				hi = Vector3(maxf(hi.x, v.x), maxf(hi.y, v.y), maxf(hi.z, v.z))
			span = hi - lo
		var flat: float = Vector2(span.x, span.z).length() * to_ground
		var lift: float = span.y * to_ground
		var flag := ""
		if flat > DRIFT_LIMIT:
			flag = "   <-- SLIDES"
			moving += 1
		print("  %-10s %-18s  flat %6.1f   vertical %5.1f%s"
			% [name, root_bone, flat, lift, flag])

	print("")
	print("%d of %d clips slide the mesh off the simulation's position."
		% [moving, names.size()])
	if moving > 0:
		print("She is drawn where the animation put her and collides from where")
		print("the simulation kept her. That is what catching on geometry is.")
	quit(0 if moving == 0 else 1)
