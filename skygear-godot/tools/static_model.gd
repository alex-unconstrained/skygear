extends SceneTree
## Wrap a generated GLB as a scene the renderer can already drive.
##
##   godot --path . --headless --import                  (once, after downloading)
##   godot --path . --headless --script tools/static_model.gd
##
## `tools/ingest_model.py` exists for RIGGED characters and solves six problems
## none of which a Meshy text-to-3D result has: it has no skeleton, no clips, no
## second rest pose to retarget from and no 190 MB archive. Running it here would
## be most of an afternoon of machinery to move one mesh. What a static model
## does need is four things, and every one of them is a bug we have already paid
## for once:
##
##   1. **A holder.** The imported root carries the exporter's unit scale.
##      `SkyGearRig3D.place()` writes a transform onto the node it was given, so
##      the model goes one level down and the scene root takes the writes. This
##      is the bug that rendered the captain at one hundredth of a metre.
##   2. **Feet at the origin.** Meshy centres a mesh on its own bounding box, and
##      `place()` puts the rig root on the deck at y=0 — so a centred boarder
##      stands in the planking up to the waist. The holder is lifted by the
##      measured floor of the mesh instead.
##   3. **A facing.** `place()` yaws from the aim vector and a yaw of zero looks
##      down +Z. Nothing makes a generator agree, and a boarder charging at you
##      backwards is worse than a billboard that never turns at all. One number
##      per model, in the table below, checked by looking.
##   4. **A measured height.** `setup()` falls back to the TALLEST single
##      MeshInstance3D when there is no `model_height`, which is the whole model
##      only for as long as every model arrives in one piece. A boarder whose
##      weapon or backpack came back as its own mesh would be scaled to the
##      height of the tallest part instead of to its own. The union is measured
##      here, once, and written into the scene as `model_height`.
##
## Output is `assets/models/<key>/<key>.tscn`, which is exactly where
## `SkyGearView3D.model_path()` looks. No renderer change: dropping a boarder in
## is running this.
func _initialize() -> void: call_deferred("_run")


## key -> degrees about +Y to turn the model so it faces +Z, which is the rest
## facing every other figure on this deck is placed against.
##
## Checked by rendering both sides, not guessed — the first pass through here
## assumed 180 and put the whole batch on the deck backwards, which at a locked
## 41-degree camera reads as five boarders retreating.
##
## This batch all came back facing +Z already, so every number is zero. The
## column stays because it is per-model: the value is a property of whatever
## exported the file, and the next asset from anywhere else has no reason to
## agree with these five.
##
## It is also the switch for WHICH boarders are meshes. A kind with no entry
## here gets no `.tscn`, `_sync_rig` does not find one, and the renderer keeps
## its painted billboard — which is the right answer whenever a generated model
## reads worse than the art it is replacing.
const MODELS := {
	"scrapper": 0.0,
	"gunner": 0.0,
	"swarm": 0.0,
	"boss": 0.0,
	## "armored" is generated and on disk and is deliberately NOT here.
	##
	## TWO ATTEMPTS. The first came back a slim red knight with a teal lamp on its
	## belt. The second — after fixing a real prompt contradiction, where PALETTE
	## ended with "no glow" while the same prompt asked for a GLOWING orange
	## furnace grate — came back a heavy plate knight with the right silhouette,
	## a grey-and-yellow palette that is not ours, a dark grille where the furnace
	## should burn, no chimney, and a teal axe blade.
	##
	## The billboard is a barrel-chested hulk in brass and oxblood with an orange
	## furnace burning in its chest, a chimney over one shoulder and a pressure
	## gauge on the pauldron. Both are "an armoured figure with an axe"; only one
	## of them is unmistakably THIS game, and only one reads as the enemy with 180
	## hp that you cannot simply walk through.
	##
	## The generator is good at silhouette and bad at a specific character, and
	## sixty credits was a fair price for finding that out. The painted knight
	## stays. If someone re-rolls again, the bar is the billboard, not the
	## previous mesh.

	## --- the deck props ------------------------------------------------------
	## Same table, same two jobs, and for these the FACING column earns its
	## keep in a way it did not for the boarders. A boarder turns to face
	## whatever it is walking at, so a wrong rest facing is wrong for one frame
	## in ten; a prop never turns at all, so whichever face the generator put on
	## +Z is the face the player looks at for the whole run. The keg's red flame
	## triangle, the vent's gauge and the lantern's lit panes are each on exactly
	## one side of the object.
	##
	## `SkyGearView3D.PROP_MODEL` is the other half of the switch: a model can be
	## wrapped here and still be left painted there, which is the cheap way to
	## park one that came back wrong without deleting the file.
	## The objective. Faces +Z already, which for this one is not luck being
	## relied on but the thing to check first: the furnace door is on one face,
	## the camera never leaves +Z, and a boiler turned round is a brass barrel.
	"boiler": 0.0,

	## "boarding_hulk" is generated TWICE, both on disk, and deliberately NOT
	## here. The furnace knight's rule again, and the closest parallel to it.
	##
	## v1 came back a submarine. v2 fixed that — a wide armoured box, a round
	## door standing open with fire in its throat, a ramp down, brass straps —
	## and as a MODEL it is good. It still loses, and it loses to something no
	## prompt can fix, which is why the third attempt is not worth buying:
	##
	## The painted hulk works because it is a FLAT FACADE and a billboard turns
	## to face the camera, so all 420 units of it are always presented square-on:
	## a wall of armour across the top of the frame with a glowing hole in the
	## middle. The mesh is as DEEP as it is wide. At a locked 41-degree camera
	## its mass goes up out of frame and what remains on screen is the ramp —
	## a pale blue-grey staircase laid across the middle of the deck, with the
	## door, the funnels and the straps all invisible. Posed side by side with
	## the sprite at the bow and again from mid-deck, it is not a close call.
	##
	## Shrinking it does not help: it is a shape problem, not a size one. A mesh
	## only beats this sprite if it is much wider and much SHALLOWER than
	## anything text-to-3D returned — a wall with its ramps as separate low
	## geometry — and at that point it is modelled by hand, not prompted.
	##
	## Sixty credits, and what it bought is knowing the sprite was right.

	"crate_stack": 0.0,
	"powder_keg": 0.0,
	"lantern_post": 0.0,
	"steam_vent": 0.0,
	"cannon_deck": 0.0,
	"salvage_pile": 0.0,

	## "brazier" is generated and on disk and is deliberately NOT here.
	##
	## Its entire job on this deck is to be a FIRE — it is one of only two props
	## the renderer hangs an OmniLight on, and the painted one is a bowl of coals
	## burning orange. The mesh came back with a bowl of grey-blue rock. Standing
	## inside its own orange light, contradicting it, it reads as a bathtub full
	## of rubble. The prompt asked for "burning coals that glow hot orange" and
	## the texture line asked twice; what it also said was "charred black timber",
	## and that is the likeliest culprit for the next person to fix.
	##
	## It is also the wrong SHAPE: 1.898 wide by 0.925 tall, so scaling it to
	## PROP_HEIGHT's 116 makes it 238 ground units across — wider than the
	## captain is tall, against a painted brazier of about ninety. Two faults,
	## either one disqualifying.

	## "crate_small" is generated and on disk and is deliberately NOT here.
	##
	## It came back a bright orange treasure chest with a big gold clasp. The
	## billboard is a dark blue-brown plank cube with blue-steel corner brackets
	## and one oxblood strap; the mesh is the most saturated object on the deck
	## and sits four feet from cargo runs painted in blue-grey. It is not that it
	## is ugly — it is that it is a different object in a different palette, and
	## a deck of eight generated props and twelve painted ones only holds
	## together if they are the same objects.
	##
	## The lesson for the re-roll is in the prompt: "one oxblood leather strap
	## ... with a brass buckle" is a chest fastening, and it was given a chest.
	## The painted strap is decoration over a nailed lid, not a lock.
	## "rope_coil" is deliberately absent and was never generated. It is 30
	## ground units tall — the shortest entry in PROP_HEIGHT by a factor of two —
	## and a mesh of a flat coil of rope and a billboard of one are the same
	## forty pixels at a locked 41-degree camera. The prompt is in
	## tools/meshy.py so the decision can be revisited for 30 credits.
}


func _run() -> void:
	var bad := 0
	for key in MODELS:
		if not _wrap(str(key), float(MODELS[key])):
			bad += 1
	quit(bad)


func _wrap(key: String, facing_degrees: float) -> bool:
	var glb_path := "res://assets/models/%s/%s.glb" % [key, key]
	if not ResourceLoader.exists(glb_path):
		push_error("%s: no %s - generate it first (python tools/meshy.py run boarders)"
			% [key, glb_path])
		return false
	var packed_glb := load(glb_path) as PackedScene
	if packed_glb == null:
		push_error("%s: %s did not load as a scene" % [key, glb_path])
		return false

	var root := Node3D.new()
	root.name = key.capitalize()
	## IN THE TREE while we measure. `global_transform` on a detached node returns
	## an identity and a warning, so the first version of this measured every model
	## unrotated and stood the boss on his own chin.
	get_root().add_child(root)
	var holder := Node3D.new()
	holder.name = "Holder"
	root.add_child(holder)
	holder.owner = root
	var model := packed_glb.instantiate()
	model.name = "Model"
	holder.add_child(model)
	## Owned by the ROOT, not by the holder, or `pack()` drops it: a node whose
	## owner is not the scene root is not part of the scene being packed.
	model.owner = root

	holder.rotation.y = deg_to_rad(facing_degrees)
	## Force the transforms down the tree before measuring. `get_global_transform`
	## on a node added this frame is still the value it was created with, and the
	## first measurement written this way was of an unrotated model.
	root.force_update_transform()
	holder.force_update_transform()

	var box := _measure(model, root)
	if box.size.y <= 0.0:
		push_error("%s: no mesh in the GLB, nothing to measure" % key)
		root.queue_free()
		return false
	## Stand it on the deck and centre it over its own feet. Both are measured
	## AFTER the yaw, because turning a model that was not centred moves it.
	holder.position = Vector3(-box.position.x - box.size.x * 0.5, -box.position.y,
		-box.position.z - box.size.z * 0.5)
	root.set_meta("model_height", box.size.y)

	var out := "res://assets/models/%s/%s.tscn" % [key, key]
	var scene := PackedScene.new()
	var packed_ok: bool = scene.pack(root) == OK
	var saved_ok: bool = packed_ok and ResourceSaver.save(scene, out) == OK
	root.queue_free()
	if not packed_ok:
		push_error("%s: pack failed" % key)
		return false
	if not saved_ok:
		push_error("%s: could not write %s" % [key, out])
		return false
	print("%-9s %5.3f x %5.3f x %5.3f model units, facing %+.0f deg -> %s"
		% [key, box.size.x, box.size.y, box.size.z, facing_degrees, out])
	return true


## The union of every mesh, in the scene root's frame — which is the frame
## `SkyGearRig3D` then scales. The max of the individual heights is not the same
## number as soon as a model arrives in more than one piece.
func _measure(model: Node, relative_to: Node3D) -> AABB:
	var box := AABB()
	var first := true
	var inverse := relative_to.global_transform.affine_inverse()
	for child in model.find_children("*", "MeshInstance3D", true, false):
		var mi := child as MeshInstance3D
		if mi.mesh == null:
			continue
		var here := (inverse * mi.global_transform) * mi.get_aabb()
		box = here if first else box.merge(here)
		first = false
	return box
