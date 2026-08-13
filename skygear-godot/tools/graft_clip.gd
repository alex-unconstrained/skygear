extends SceneTree
## GRAFT ONE ALREADY-BAKED CLIP FROM ONE RIG ONTO ANOTHER (board SG-282).
##
##   godot --path . --headless --script tools/graft_clip.gd -- \
##       <target> <clip> <source> [source_clip] [--dry]
##
##   godot --path . --headless --script tools/graft_clip.gd -- captain die crew --dry
##   godot --path . --headless --script tools/graft_clip.gd -- captain die crew
##
## `<target>` and `<source>` are model folder names under `assets/models/`.
## `<clip>` is what the clip will be CALLED on the target; `[source_clip]`
## defaults to the same name. `--dry` does every step and saves nothing, because
## this writes into a shipping asset and the money-law habit is the right habit
## even where no money is involved.
##
## WHY THIS EXISTS RATHER THAN A RE-INGEST. `tools/ingest_model.py` retargets out
## of raw animation-pack FBXs and `tools/retarget_library.gd` rebuilds a whole
## character from a rig glb plus a donor library. Neither reaches the case this
## project actually has: a figure that is ALREADY BUILT, whose own source archive
## is gone from this machine (`retarget_library.gd:5-9` — the Pro Melee Axe Pack
## and the captain's Meshy archive are both absent), and which is missing exactly
## one clip that some OTHER figure in this same repository already carries,
## baked, stripped and retargeted once.
##
## The captain is that figure and `die` is that clip. She has fourteen clips and
## no death, so for the whole life of the port she has stood in a breathing idle
## through her own defeat cutscene.
##
## THE MATH IS `tools/ingest_model.gd:43-85`'S, GENERALISED IN ONE PLACE. Motion
## relative to rest transfers between two rests as `P_to = R_to * R_from^-1 *
## P_from`; that file writes the position half as `v + (R_to.origin -
## R_from.origin)`, which is the same thing as `R_to.origin + (v -
## R_from.origin)` and is correct only while both rigs measure in the same units.
##
## THEY DO NOT ALWAYS. `metadata/model_height` is each model's own measured
## height in its own units and `rig3d.setup` divides the wanted height by it, so
## the captain (0.017797) and the crew (0.018974) agree to seven per cent — and
## the SCRAPPER is **1.897212**, a hundred times either. A hips track copied to
## the scrapper unscaled would move it a hundred times too far. So the delta from
## rest is scaled by `model_height(target) / model_height(source)`, which is 1.0
## for two rigs of the same build and is the only reason this tool can be pointed
## at the scrapper at all (SG-284).
##
## VALID ONLY BETWEEN RIGS THAT SHARE BONE NAMES AND HIERARCHY, and this asserts
## it rather than assuming it: every bone the clip addresses that the target does
## not have is REMOVED from the grafted copy (Godot resolves tracks by node path
## and a track pointing at a bone that is not there is a warning per play, for
## ever). The count is printed. If it is large, the two rigs are not the same
## build and the graft is wrong no matter what the clip looks like.
##
## The captain's 33 bones are a strict subset of the crew's 41 — the difference
## is eight `*HandThumb*` bones and nothing else (`comm -23` over the two
## `bones/N/name` lists). That is what makes this graft honest.
func _initialize() -> void: call_deferred("_run")


func _skeleton_of(root: Node) -> Skeleton3D:
	var found: Skeleton3D = null
	for child in root.find_children("*", "Skeleton3D", true, false):
		found = child as Skeleton3D
	return found


func _rest_of(skeleton: Skeleton3D) -> Dictionary:
	var rest := {}
	for b in skeleton.get_bone_count():
		rest[skeleton.get_bone_name(b)] = skeleton.get_bone_rest(b)
	return rest


## The path `rig3d` will resolve the tracks against once the clip is playing on
## the TARGET's own AnimationPlayer. Read off the target scene rather than
## assumed, because the two rigs do not have to agree about where the skeleton
## lives and this is exactly the mismatch `ingest_model.gd:56-59` records.
func _skeleton_path(player: AnimationPlayer, skeleton: Skeleton3D) -> String:
	return str(player.get_parent().get_path_to(skeleton))


func _run() -> void:
	var argv := OS.get_cmdline_user_args()
	var dry := argv.has("--dry")
	var args: Array[String] = []
	for a in argv:
		if not str(a).begins_with("--"):
			args.append(str(a))
	if args.size() < 3:
		print("usage: graft_clip.gd -- <target> <clip> <source> [source_clip] [--dry]")
		quit(2)
		return
	var target := args[0]
	var clip := args[1]
	var source := args[2]
	var source_clip := args[3] if args.size() > 3 else clip

	var target_scene := "res://assets/models/%s/%s.tscn" % [target, target]
	var source_scene := "res://assets/models/%s/%s.tscn" % [source, source]
	for path in [target_scene, source_scene]:
		if not ResourceLoader.exists(path):
			print("MISSING: %s" % path)
			quit(1)
			return

	var tnode := (load(target_scene) as PackedScene).instantiate()
	var snode := (load(source_scene) as PackedScene).instantiate()
	root.add_child(tnode)
	root.add_child(snode)

	var tplayer := tnode.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var splayer := snode.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var tskel := _skeleton_of(tnode)
	var sskel := _skeleton_of(snode)
	if tplayer == null or splayer == null or tskel == null or sskel == null:
		print("one of the two scenes has no AnimationPlayer or no Skeleton3D")
		quit(1)
		return
	if not splayer.has_animation(source_clip):
		print("%s has no clip named '%s' — it has: %s"
			% [source, source_clip, ", ".join(splayer.get_animation_list())])
		quit(1)
		return
	if tplayer.has_animation(clip):
		print("%s ALREADY has a clip named '%s'. Refusing to overwrite a shipping"
			% [target, clip])
		print("asset; delete it deliberately first if that is really what you want.")
		quit(1)
		return

	## Scale between the two models' own units. 1.0 for two rigs of the same
	## build; a hundred for the scrapper against anything else.
	var tall_t: float = float(tnode.get_meta("model_height", 0.0))
	var tall_s: float = float(snode.get_meta("model_height", 0.0))
	if tall_t <= 0.0 or tall_s <= 0.0:
		print("one of the two scenes carries no model_height metadata")
		quit(1)
		return
	var unit: float = tall_t / tall_s

	var trest := _rest_of(tskel)
	var srest := _rest_of(sskel)
	var missing_bones: Array[String] = []
	for name in srest.keys():
		if not trest.has(name):
			missing_bones.append(str(name))

	var anim: Animation = splayer.get_animation(source_clip).duplicate(true)
	var want_path := _skeleton_path(tplayer, tskel)

	var moved := 0
	var repathed := 0
	var dropped := 0
	var untouched := 0
	## Backwards, because dropping a track renumbers everything after it.
	for t in range(anim.get_track_count() - 1, -1, -1):
		var path := anim.track_get_path(t)
		if path.get_subname_count() == 0:
			untouched += 1
			continue
		var bone := String(path.get_subname(0))
		if not trest.has(bone) or not srest.has(bone):
			anim.remove_track(t)
			dropped += 1
			continue
		var want := NodePath("%s:%s" % [want_path, bone])
		if path != want:
			anim.track_set_path(t, want)
			repathed += 1
		var rs: Transform3D = srest[bone]
		var rt: Transform3D = trest[bone]
		var kind := anim.track_get_type(t)
		if kind == Animation.TYPE_ROTATION_3D:
			var fix := rt.basis.get_rotation_quaternion() \
				* rs.basis.get_rotation_quaternion().inverse()
			if fix.angle_to(Quaternion.IDENTITY) < 0.0005:
				continue
			for k in anim.track_get_key_count(t):
				anim.track_set_key_value(t, k,
					(fix * (anim.track_get_key_value(t, k) as Quaternion)).normalized())
			moved += 1
		elif kind == Animation.TYPE_POSITION_3D:
			## Rest-relative and scaled, not offset. See the header: the offset
			## form in `ingest_model.gd` is this with `unit` pinned to 1.
			for k in anim.track_get_key_count(t):
				var v: Vector3 = anim.track_get_key_value(t, k)
				anim.track_set_key_value(t, k, rt.origin + (v - rs.origin) * unit)
			moved += 1

	## THE INSTRUMENT REPORTS ITSELF FIRST. How far the hips travel horizontally
	## across the clip, in the TARGET's drawn ground units — the number
	## `ingest_model._strip_root_motion` exists to keep at zero, because the
	## simulation owns where a figure is and a clip that also moves it draws the
	## body somewhere it is not. A grafted clip that has picked up root motion is
	## a grafted clip that will slide.
	var drift := 0.0
	var drawn: float = float(tnode.get_meta("target_height", 0.0)) / maxf(0.0001, tall_t)
	for t in anim.get_track_count():
		if anim.track_get_type(t) != Animation.TYPE_POSITION_3D:
			continue
		var bone := String(anim.track_get_path(t).get_subname(0))
		if not (bone.ends_with("Hips") or bone.ends_with("Root")):
			continue
		var lo := Vector2(INF, INF)
		var hi := Vector2(-INF, -INF)
		for k in anim.track_get_key_count(t):
			var v: Vector3 = anim.track_get_key_value(t, k)
			lo = Vector2(minf(lo.x, v.x), minf(lo.y, v.z))
			hi = Vector2(maxf(hi.x, v.x), maxf(hi.y, v.z))
		if hi.x > -INF:
			drift = maxf(drift, (hi - lo).length() * drawn)

	print("graft %s.%s  <-  %s.%s" % [target, clip, source, source_clip])
	print("  length      %.3f s   loop_mode %d   tracks %d"
		% [anim.length, anim.loop_mode, anim.get_track_count()])
	print("  unit scale  %.4f  (model_height %.6f / %.6f)" % [unit, tall_t, tall_s])
	print("  retargeted  %d tracks   repathed %d   dropped %d   untouched %d"
		% [moved, repathed, dropped, untouched])
	print("  bones the target does not have (%d): %s"
		% [missing_bones.size(), ", ".join(missing_bones)])
	print("  hips horizontal travel: %.2f ground units  (0.00 is the pass condition)" % drift)
	print("  skeleton path: %s" % want_path)

	if dry:
		print("DRY — nothing written.")
		quit(0)
		return

	var library := tplayer.get_animation_library("")
	if library == null:
		print("the target's AnimationPlayer has no default library")
		quit(1)
		return
	var library_path: String = library.resource_path
	if library_path == "":
		print("the target's library is embedded in the scene, not an external .res;")
		print("this tool only writes the external `<name>_anims.res` form.")
		quit(1)
		return
	library.add_animation(clip, anim)
	var err := ResourceSaver.save(library, library_path)
	if err != OK:
		print("SAVE FAILED (%d): %s" % [err, library_path])
		quit(1)
		return
	print("WROTE %s  (%d clips)" % [library_path, library.get_animation_list().size()])

	## And the human-readable ledger beside it, so the scene file and the library
	## do not become a fact known in one place and contradicted in another. This
	## is a one-line text edit rather than a repack: `metadata/clips` is written
	## by the ingest tools and read by no runtime code (`rig3d.has_clip` asks the
	## AnimationPlayer), so repacking the whole scene to update a comment would
	## risk far more than it fixes.
	if not _rewrite_clip_metadata(target_scene, library.get_animation_list()):
		print("NOTE: %s's metadata/clips line was not updated — do it by hand." % target)
	quit(0)


func _rewrite_clip_metadata(scene_path: String, clips: PackedStringArray) -> bool:
	var file := FileAccess.open(scene_path, FileAccess.READ)
	if file == null:
		return false
	var text := file.get_as_text()
	file.close()
	var sorted := Array(clips)
	sorted.sort()
	var quoted: Array[String] = []
	for c in sorted:
		quoted.append('"%s"' % str(c))
	var line := "metadata/clips = PackedStringArray(%s)" % ", ".join(quoted)
	var start := text.find("metadata/clips = PackedStringArray(")
	if start < 0:
		return false
	var stop := text.find(")", start)
	if stop < 0:
		return false
	text = text.substr(0, start) + line + text.substr(stop + 1)
	var out := FileAccess.open(scene_path, FileAccess.WRITE)
	if out == null:
		return false
	out.store_string(text)
	out.close()
	print("UPDATED %s metadata/clips -> %d names" % [scene_path, sorted.size()])
	return true
