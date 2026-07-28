extends SceneTree
## Point every clip at the skeleton we actually kept.
##
## Meshy's clips do not agree on where the rig lives: five are authored under
## `Armature/Skeleton3D` and the swing came off a Rigify export under
## `target_character/Skeleton3D`. Godot resolves animation tracks by node path,
## so the odd one out silently animated nothing and logged twenty warnings.
##
## Bone NAMES all agree — the rest-pose retarget in build_captain.gd already
## checks that — so this only has to rewrite the node half of each path.
func _initialize() -> void: call_deferred("_run")

const LIB := "res://assets/models/captain/captain_anims.res"
const SKELETON := "Armature/Skeleton3D"

func _run() -> void:
	var library: AnimationLibrary = load(LIB)
	var fixed := 0
	for name in library.get_animation_list():
		var anim: Animation = library.get_animation(name)
		for t in anim.get_track_count():
			var path := anim.track_get_path(t)
			if path.get_subname_count() == 0:
				continue
			var want := NodePath("%s:%s" % [SKELETON, path.get_subname(0)])
			if path != want:
				anim.track_set_path(t, want)
				fixed += 1
		print("  %-9s %d tracks" % [name, anim.get_track_count()])
	print("rewrote %d track paths" % fixed)
	print("save: ", ResourceSaver.save(library, LIB))
	quit(0)
