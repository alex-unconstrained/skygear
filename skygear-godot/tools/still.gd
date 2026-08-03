class_name SkyGearStill
extends RefCounted

## THE ONE FREEZE. Every tool in this repo that photographs the deck poses it
## through here, and nowhere else.
##
## SG-108, and it is the fourth confound in the family DECK-IDENTITY §7.5 has
## been collecting: **`set_process(false)` does not stop an `AnimationPlayer`.**
## `game.set_process(false)` holds the simulation and `view.set_process(false)`
## holds the renderer, but every rigged figure on this deck owns an
## `AnimationPlayer` that advances on the ENGINE's clock and answers to neither.
## Seventeen boarders breathing through a walk cycle move their limbs, their
## weapons and — the part that ruins a shadow measurement — their CAST SHADOWS,
## on every frame between two exposures of what a tool believed was one frozen
## scene. `tools/shadow_probe.gd` measured its own noise floor at **53%** before
## the cause was found. Frozen properly it is **0.00%**.
##
## `marks_shot.gd` had the identical hole and only escaped it by shooting its two
## plates one frame apart, which shrinks the effect without removing it — which
## is very likely the "residual that is not the marks and has not been found"
## SG-101's row records.
##
## SO THIS IS ONE HELPER RATHER THAN N COPIES OF THE SAME FIX. The failure mode
## STATUS.md names as "two functions disagreeing about one number" applies just
## as hard to two tools disagreeing about what "frozen" means: the first three
## fixes in this family were each written into one tool and each had to be
## rediscovered in the next. There is one list now, it lives here, and
## `parity_test.gd`'s `still ·` checks refuse a photographing tool that does not
## come through it.
##
## USE:
##     await SkyGearStill.freeze(self, view, game)
##     ## ... toggle the one thing under test, and only that ...
##     var floor := await SkyGearStill.floor_pct(self, DECK_BOX)
##
## `floor_pct` is the pre-committed check in tool form: two plates of a scene
## with NOTHING changed between them. If it is not 0.00 the scene is not still
## and every number the tool prints below it is that motion, not the feature.


## A pixel has to move by this much before it counts as changed rather than as
## the renderer's own dither. sRGB channel units, so 0.012 is about 3/255 — the
## usual "a person could see that" step. Same constant `shadow_probe.gd` uses,
## and it lives here now so the two cannot drift apart.
const MOVED := 0.012
## Sampling stride for a plate. A deck region is a million pixels and the median
## of half of them is the same median.
const STEP := 2


## STOP EVERYTHING THAT HAS ITS OWN CLOCK.
##
## Returns what it actually stopped, so a tool can print it — a freeze that
## silently found zero AnimationPlayers because the tree was not built yet is
## the "detector silenced to make a screen pass" failure mode wearing a helper.
##
## Walks from the SCENE TREE ROOT rather than from `view`: an `AnimationPlayer`
## parented to the HUD, to a cutscene rig or to anything else added beside the
## world is exactly as visible to the camera and exactly as unfrozen.
static func freeze(tree: SceneTree, view: Node, game: Node = null) -> Dictionary:
	var root := tree.get_root()

	## 1. THE SIMULATION. Tools step it by hand with an explicit delta after this.
	if game != null:
		game.set_process(false)

	## 2. THE ENGINE'S OWN CLOCK, which is the one `set_process(false)` never
	## touched. Everything below is belt AND braces on purpose: `time_scale`
	## alone would do it, but a tool that later sets `time_scale` back to 1 to
	## step something would silently un-freeze seventeen rigs, and per-node
	## `speed_scale` survives that.
	Engine.time_scale = 0.0

	## 3. EVERY RIG. This is SG-108 itself.
	var players := 0
	for node in root.find_children("*", "AnimationPlayer", true, false):
		var ap := node as AnimationPlayer
		ap.speed_scale = 0.0
		## `advance(0.0)` flushes the pose it is holding so the first plate is
		## the pose the second plate will also have, rather than one tick behind.
		if ap.is_playing():
			ap.advance(0.0)
		players += 1

	## 4. THE GPU'S OWN CLOCK. `GPUParticles3D` runs on the graphics card and does
	## not care that the tree stopped processing — embers and steam kept moving
	## between two plates and turned up in SG-101's contrast figures as if the
	## marks had done it. `speed_scale = 0` freezes them IN PLACE rather than
	## hiding them, which the earlier fix did: a plate with the braziers deleted
	## out of it is not the picture anybody is judging.
	var particles := 0
	for node in root.find_children("*", "GPUParticles3D", true, false):
		(node as GPUParticles3D).speed_scale = 0.0
		particles += 1

	## 5. THE TEMPORAL ACCUMULATORS. Debanding is a per-frame RANDOM dither: it
	## moves a little of every pixel on every frame whether the scene changed or
	## not, and with it on two identical plates differed across 53% of the deck.
	## Volumetric fog's temporal reprojection blends each frame into the last few
	## with a per-frame offset, so a completely frozen scene still produces a
	## different image every frame AND DOES NOT SETTLE — which is why averaging
	## eight exposures made SG-107's floor worse rather than better. The term is
	## not zero-mean noise, it is a drift.
	root.use_debanding = false
	var fog := false
	var env: Environment = _environment_of(view)
	if env != null:
		env.volumetric_fog_temporal_reprojection_enabled = false
		fog = true

	## 6. THE LIGHTING PHASE. `_flicker` advances on real frames, so two plates
	## reach the shutter with the braziers, the lantern and the vent at different
	## points in their cycle — and the first attempt at SG-101's measurement
	## reported the contrast getting WORSE when the marks got FAINTER, which is
	## the phase talking and not the marks. Pinned at a fixed value, both plates
	## are lit identically.
	if "_flicker" in view:
		view.set("_flicker", FLICKER)
	if view.has_method("set_process"):
		view.set_process(false)

	## Three ticks at a zero delta to flush the pinned phase and the held poses
	## into the frame, then two frames for the readback to be of THAT frame.
	for _i in 3:
		if view.has_method("_process"):
			view.call("_process", 0.0)
		await tree.process_frame
	await tree.process_frame

	return {"animation_players": players, "particles": particles,
		"debanding": true, "fog_reprojection": fog}


## The pinned brazier phase. Any fixed number works; this is the one SG-101 and
## SG-107 both used, kept so old plates and new plates are lit the same.
const FLICKER := 12.0


## AND BACK, for a tool that shoots more than one pose. A freeze that could not
## be undone would force a tool into one plate per process, which is exactly the
## two-process comparison DECK-IDENTITY §7.5 records reporting 0.72% and 13.55%
## on the same build — the braziers and the particle systems do not arrive at the
## shutter in the same place twice across two runs.
static func thaw(tree: SceneTree, view: Node, game: Node = null) -> void:
	var root := tree.get_root()
	Engine.time_scale = 1.0
	for node in root.find_children("*", "AnimationPlayer", true, false):
		(node as AnimationPlayer).speed_scale = 1.0
	for node in root.find_children("*", "GPUParticles3D", true, false):
		(node as GPUParticles3D).speed_scale = 1.0
	if view.has_method("set_process"):
		view.set_process(true)
	if game != null:
		game.set_process(true)
	await tree.process_frame


## THE PRE-COMMITTED CHECK, IN TOOL FORM. Two plates of a frozen scene with
## NOTHING changed between them; the fraction of sampled pixels that moved.
## Zero, or the tool is photographing the weather.
##
## `between` MUST be whatever the tool itself does between its two real plates —
## typically `view._process(0.0)` to re-flush a batch. A control that skips it is
## not a control for the measurement being taken: the first version of this ran
## two bare readbacks and reported 0.00% while the tool's own comparisons still
## carried whatever the re-flush moved. A floor is only a floor if it is measured
## through the same door.
static func floor_pct(tree: SceneTree, box: Rect2i,
		between: Callable = Callable()) -> float:
	if between.is_valid():
		between.call()
	var a := await plate(tree, box)
	if between.is_valid():
		between.call()
	var b := await plate(tree, box)
	return moved_pct(a, b)


## One exposure, sampled over `box` at `STEP`. Optionally saved.
## AND IT WAITS ON `frame_post_draw`, NOT ON `process_frame`. This is SG-29's
## idiom (`screen_shot.gd`, `text_audit.gd`) and SG-108 found out the hard way
## why the deck tools needed it too: `process_frame` fires when the TREE has
## finished its frame, which is not when the RENDERER has finished drawing it.
## Two bare `process_frame` awaits grab a frame that is usually but not always
## complete, and the failure is INTERMITTENT — `shadow_probe.gd` read a 0.97%
## noise floor on two runs out of three with a genuinely frozen scene. An
## intermittent floor is worse than a constant one: it passes often enough to be
## believed.
static func plate(tree: SceneTree, box: Rect2i, path: String = "") -> PackedFloat32Array:
	await RenderingServer.frame_post_draw
	var img := tree.get_root().get_texture().get_image()
	if path != "":
		img.save_png(path)
	var w: int = (box.size.x + STEP - 1) / STEP
	var h: int = (box.size.y + STEP - 1) / STEP
	var out := PackedFloat32Array()
	out.resize(w * h * 3)
	var i := 0
	var gy := 0
	while gy < h:
		var gx := 0
		while gx < w:
			var c := img.get_pixel(box.position.x + gx * STEP,
				box.position.y + gy * STEP)
			out[i] = c.r
			out[i + 1] = c.g
			out[i + 2] = c.b
			i += 3
			gx += 1
		gy += 1
	return out


## What fraction of the sampled region actually changed. Pixels, not opinions.
static func moved_pct(a: PackedFloat32Array, b: PackedFloat32Array) -> float:
	if a.size() != b.size() or a.is_empty():
		return 100.0
	var moved := 0
	var total := 0
	var i := 0
	while i < a.size():
		total += 1
		if maxf(absf(a[i] - b[i]), maxf(absf(a[i + 1] - b[i + 1]),
				absf(a[i + 2] - b[i + 2]))) >= MOVED:
			moved += 1
		i += 3
	return 0.0 if total == 0 else 100.0 * float(moved) / float(total)


## WHERE TWO PLATES DIFFER, AS A PICTURE. A percentage sends the next agent
## guessing; a mask sends them to the line of code. White is a pixel that moved.
static func save_mask(a: PackedFloat32Array, b: PackedFloat32Array,
		box: Rect2i, path: String) -> void:
	var w: int = (box.size.x + STEP - 1) / STEP
	var h: int = (box.size.y + STEP - 1) / STEP
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	var i := 0
	var y := 0
	while y < h and i + 2 < a.size():
		var x := 0
		while x < w and i + 2 < a.size():
			var d: float = maxf(absf(a[i] - b[i]), maxf(absf(a[i + 1] - b[i + 1]),
				absf(a[i + 2] - b[i + 2])))
			var v: float = 1.0 if d >= MOVED else minf(1.0, d * 20.0)
			img.set_pixel(x, y, Color(v, v, v))
			i += 3
			x += 1
		y += 1
	img.save_png(path)


## Mean luminance over a sampled plate, through `ink.gd` so the number means what
## every other luminance number in this project means.
static func lum(a: PackedFloat32Array) -> float:
	var sum := 0.0
	var n := 0
	var i := 0
	while i < a.size():
		sum += SkyGearInk.luminance(Color(a[i], a[i + 1], a[i + 2]))
		n += 1
		i += 3
	return 0.0 if n == 0 else sum / float(n)


## The renderer keeps its `Environment` under a name this helper should not have
## to guess at twice.
static func _environment_of(view: Node) -> Environment:
	if "_environment" in view:
		var env = view.get("_environment")
		if env is Environment:
			return env as Environment
	var cam := view.get_viewport().get_camera_3d() if view.is_inside_tree() else null
	if cam != null and cam.environment != null:
		return cam.environment
	return null
