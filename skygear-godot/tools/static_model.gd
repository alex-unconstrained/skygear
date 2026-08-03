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
	## The GUNNER, and it is the only boarder that BELONGS in this table.
	## Everything else here was a lump waiting for a rig; the drone is a lump on
	## purpose — no legs, no spine, no arms to put auto-rig markers on, and the
	## handoff spec called it before a file existed. Its `.glb` is not a Meshy
	## download any more: `tools/split_rotors.py` writes it, cutting the owner's
	## textured export into `Body` plus three `Rotor*` children so
	## `SkyGearView3D.ROTOR_MOTION` can turn them. This wrapper is unchanged by
	## that — it measures a union and stands it on the deck, and a model in four
	## pieces is exactly what its own `_measure` docstring was written for.
	"gunner": 0.0,
	## "swarm" is RIGGED now and its lump is deleted. The goblin was the last
	## handoff-3d figure; the owner modelled and auto-rigged it (board SG-89,
	## `tools/models.json`), so it is an ingest entry rather than a wrap, and
	## `assets/models/swarm/swarm.glb` is gone rather than shadowed — a wrapper
	## row pointing at a file that is not there is a `push_error` on every run
	## of this tool.
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

	## "boarding_hulk" is generated THREE times, and deliberately NOT here.
	## The owner reopened the two-rejection verdict for ONE more prompted
	## attempt with hard constraints (board SG-64), it failed on a NEW axis,
	## and by the owner's own condition THE HAND-MODEL VERDICT IS NOW FINAL
	## (board SG-21). Do not prompt a fourth.
	##
	## v1 came back a submarine. v2 came back a good model as deep as it was
	## wide, so at the locked 41-degree camera its mass went up out of frame
	## and what stayed on screen was a pale staircase.
	##
	## v3 (SG-64) said wall, theatre flat, "depth a quarter of its width",
	## ramps as low separate geometry — and the GEOMETRY LESSONS LANDED at the
	## judging pose (.shots/sg64/hulk-after-mid.png against hulk-before-mid):
	## a wall across the top of the frame, the fire door glowing mid-wall, a
	## ramp lying on the planking. Two failures anyway, either one fatal:
	##
	##   * the depth constraint was ignored a third time — measured 1.899 wide
	##     x 1.639 DEEP, 86% against the asked 25%. Three prompts, three
	##     depth failures: text-to-3D will not hold a depth ratio, now known
	##     at ninety credits' certainty.
	##   * "fortress gate" won over the palette: pale cracked STONE MASONRY
	##     where every painted state wears dark iron plate and near-black
	##     timber, battlement crenellations, and a Gothic ARCH for a door
	##     where sealed/open/destroyed all wear the round iris. The renderer
	##     keeps the painted art for the other two states by design, so a
	##     hulk that breaks would pop from a stone arch-gate to a blown iron
	##     iris — a different object mid-fight, which is the crate v1
	##     rejection reason at forty times the size.
	##
	## Ninety credits total, and what they bought is the full shape of the
	## problem: the sprite stays until someone hand-models a wide, shallow,
	## iron-and-timber wall with the iris in it.
	##
	## AND THEN THE OWNER MADE IT HIMSELF (board SG-76, 2026-08-02) — three
	## files, one per painted state, which is the thing three prompted attempts
	## could not buy at any price: the same object wearing three faces. Each
	## state is its own model key because `_sync_prop_model` claims by key and
	## a state swap has to be a different scene, not a different material.
	##
	## FACING 0 IS MEASURED, not assumed. All three came back with the door on
	## +Z: rendered square-on at the game camera each one lands on its painting
	## — chimneys at the top corners, ramps splayed from the bottom corners,
	## the round iris dead centre (.shots/models/hulk-raw/*.png).
	##
	## THE MAPPING IS THE OWNER'S FILE NAMES SWAPPED, and it was verified by
	## looking rather than by reading: "Ironbound Gate" (stated OPEN) is the
	## SEALED face — chevron plate over the door, one thin red seam, and an
	## emission map that is ENTIRELY BLACK — and "Emberforge Core" (stated
	## CLOSED) is the one with the blazing iris and the only emission map in
	## the three with anything alight in it. "Clockwork Gate Fortress" is the
	## wreck it says it is. Names are ambiguous; a furnace either burns or it
	## does not.
	"boarding_hulk_sealed": 0.0,
	"boarding_hulk_open": 0.0,
	"boarding_hulk_destroyed": 0.0,

	"crate_stack": 0.0,
	"powder_keg": 0.0,
	"lantern_post": 0.0,
	"steam_vent": 0.0,
	"cannon_deck": 0.0,
	"salvage_pile": 0.0,

	## The ship's own furniture, board SG-64 — the owner's 2D purge. The mast
	## was the strongest case on the deck: 340 units at dead centre, in frame
	## the whole run, and the billboard reads as a thin translucent smear with
	## rigging that anchors to nothing (.shots/sg64/mast-before.png — note the
	## pole behind the captain, not the brown sheet, which is her SG-63 cape).
	## The mesh is a dark banded timber column with a railed crow's nest, a
	## ladder and a hung rope coil — the house palette, judged on the deck at
	## .shots/sg64/mast-after.png. Two departures recorded: it is a TOWER of a
	## mast (0.887 wide x 1.899 tall — ~159 ground units across at height 340,
	## against the painting's slender pole; "thick upright column" in the
	## prompt bought exactly what it said), and the "spiked brass finial"
	## resolved into a small red mace-like standard leaning off the nest. Both
	## read as steampunk furniture at 636 px; neither loses to a ghost.
	"mast_section": 0.0,

	## The bow-corner harpoon emplacements. FACING 0 IS A MEASURED CHOICE, not
	## a default: the machine is 1.899 long x 0.366 DEEP, so turned to fire
	## up-deck (facing 90, .shots/sg64/ballista-f90.png) the whole silhouette
	## collapses to a 44-unit-wide telescope on a stand. Side-on (facing 0,
	## .shots/sg64/ballista-after.png) it spans ~229 units of bow arms,
	## harpoon and pedestal — the same left-pointing pose the painted
	## billboard has always struck at BOTH corners, so the mesh changes
	## nothing about the fiction, only stops it being a card. The placed
	## SENTRY deliberately keeps the tinted billboard (`_place` at the sentry
	## block): a sentry that looks different from the ship's own emplacements
	## is the point — five identical guns was a filed complaint once.
	"harpoon_ballista": 0.0,

	## v2, board SG-64 — the owner reopened the v1 rejection and the re-roll
	## with v1's two recorded faults written into the prompt CLEARED THE BAR.
	##
	## v1's verdict, kept because it is why the v2 prompt reads as it does: its
	## entire job on this deck is to be a FIRE — one of only two props the
	## renderer hangs an OmniLight on — and v1 came back a bowl of grey-blue
	## rock ("charred black timber" in the texture line was the culprit), 1.898
	## wide by 0.925 tall so PROP_HEIGHT's 116 made it 238 ground units across.
	## v2 removed the timber clause, refused grey stone by name, and led with
	## "upright, taller than it is wide": it measures 1.234 x 1.895 x 1.145 —
	## ~76 units wide on the deck — and at the real 41-degree camera the open
	## basket shows a coal bed blazing hot orange INTO the lens, agreeing with
	## its own light where the painted side-on bowl only implied it
	## (.shots/sg64/deck-brazier.png against deck-before.png). The dangling
	## side-strap greeble reads as tassel-sized at 217 px and was not worth a
	## re-roll against a 200-credit wave cap.
	"brazier": 0.0,

	## v2, board SG-64 — reopened with v1's lesson in the prompt, and CLEARED.
	##
	## v1 came back a bright orange treasure chest with a big gold clasp: "one
	## oxblood leather strap ... with a brass buckle" is a chest fastening, so
	## it was given a chest; and its SURFACE_WOOD frame asked for "warm polished
	## brass corner brackets" against the subject's blue-steel ones — the
	## furnace knight's contradiction hiding in a texture frame. v2 says sealed
	## munitions crate nailed shut, refuses lid/hinges/lock/clasp/gold by name,
	## drops the buckle from both prompts and carries its own SURFACE_CRATE
	## clause. What came back is the crate: warm planks, blue-steel brackets,
	## oxblood banding, no gold anywhere, judged beside the painting at the
	## real camera (.shots/sg64/deck-crate.png). Two departures recorded
	## honestly: two straps where the painting wears one, and 1.896 x 1.374 x
	## 1.499 — a shade oblong against the painted cube. Neither reads at
	## 157 px, and a real cube's corners catching the deck light beats a card
	## that shows the same face from every position.
	"crate_small": 0.0,
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
