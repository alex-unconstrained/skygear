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

	## 2, 4, 5, 6 — THE CLOCKS THAT ARE NOT THE SCENE TREE'S. Split into
	## `pin_clocks` for board SG-295 so a tool can pin them BEFORE its settle
	## rather than only at the shutter; see that function for why that matters.
	var pinned := pin_clocks(tree, view)

	## 3. EVERY RIG. This is SG-108 itself.
	var players := 0
	for node in root.find_children("*", "AnimationPlayer", true, false):
		var ap := node as AnimationPlayer
		ap.speed_scale = 0.0
		## `advance(0.0)` flushes the pose it is holding so the first plate is
		## the pose the second plate will also have, rather than one tick behind.
		if ap.is_playing():
			## AND THE POSE IS PINNED, NOT MERELY STOPPED (board SG-295).
			##
			## `speed_scale = 0` freezes a rig WHERE IT HAS GOT TO, and where it
			## has got to depends on the frame its scene finished loading on —
			## which is disk timing, and differs run to run. Measured on
			## `prop_shot.gd` with every other clock already pinned: the residual
			## difference between two runs was one solid blob, and the blob was
			## the captain, one idle frame apart. Everything else in the frame was
			## edge speckle.
			##
			## So the rigs get the same treatment `_flicker` has had since SG-101:
			## a phase pinned to a fixed number rather than to whatever happened.
			## `fposmod` because these clips are all different lengths and the
			## number has to land inside every one of them.
			var clip := ap.get_animation(ap.current_animation)
			if clip != null and clip.length > 0.0:
				ap.seek(fposmod(POSE, clip.length), true)
			ap.advance(0.0)
		players += 1

	if view.has_method("set_process"):
		view.set_process(false)

	## Three ticks at a zero delta to flush the pinned phase and the held poses
	## into the frame, then two frames for the readback to be of THAT frame.
	for _i in 3:
		if view.has_method("_process"):
			view.call("_process", 0.0)
		await tree.process_frame
	await tree.process_frame

	return {"animation_players": players, "particles": int(pinned.particles),
		"debanding": true, "fog_reprojection": bool(pinned.fog_reprojection)}


## THE CLOCKS THAT DO NOT BELONG TO THE SCENE TREE — pinned, and separable from
## the rest of `freeze` (board SG-295).
##
## WHY THIS IS ITS OWN FUNCTION NOW. `freeze` runs at the SHUTTER, which is the
## right moment to stop everything and the wrong moment to have started. These
## four clocks ignore `set_process(false)` and run on wall time, so a tool that
## settles its scene for forty frames and freezes afterwards freezes them
## WHEREVER THAT RUN'S WALL CLOCK HAPPENED TO PUT THEM — a phase that is
## different every run. `thaw`'s own comment has recorded the consequence for
## months: *"the braziers and the particle systems do not arrive at the shutter
## in the same place twice across two runs"*, at 0.72% and 13.55% on one build.
## Pinned BEFORE the settle instead, they arrive at the shutter in the same place
## every time, and a before/after taken across two processes becomes a thing you
## can believe.
##
## THE WHOLE MEASURED CLIMB DOWN, on `prop_shot.gd`, same arguments, two runs
## back to back at each step — because a fix of this shape is worth nothing
## stated as "it is better now":
##
##     96.31%   as found. Not noise: one run photographed the OPENING FILM
##              (`game.gd::replay_opening` refused only under headless, and every
##              capture tool is windowed by necessity).
##     19.84%   with the film refused for tool runs.
##      2.21%   with the settle on a fixed clock instead of `await process_frame`
##              (the camera eases with `1.0 - exp(-delta / CAM_TAU)`, so forty
##              wall-clock frames landed it somewhere new every run).
##      1.49%   with these clocks pinned BEFORE the settle rather than at the
##              shutter.
##      0.19%   with rig poses pinned as well (see `POSE`).
##
## AND 0.19% IS NOT 0.00%, WHICH IS THE PASS CONDITION THIS FILE'S OWN HEADER
## SETS. It is a low-amplitude speckle along high-contrast edges — peak channel
## disagreement 85 of 255, nothing at all above 120, spread evenly over the
## frame rather than pooled on any object. ONE HYPOTHESIS WAS TESTED AND
## REJECTED: SSAO is noisy per frame and looked like the obvious candidate, and
## disabling it in this function made the floor WORSE, 0.19% -> 4.04%. That is
## recorded rather than dropped, because a rejected hypothesis is the cheapest
## thing the next person can be handed. The residual is unattributed, and until
## it is zero the tools say so at the point of use rather than implying a
## precision they do not have.
##
## `freeze` calls this too, so there is exactly one statement of what a pinned
## clock is rather than one here and a second at the shutter.
static func pin_clocks(tree: SceneTree, view: Node) -> Dictionary:
	var root := tree.get_root()
	## THE ENGINE'S OWN CLOCK, which is the one `set_process(false)` never
	## touched. Belt AND braces with the per-node scales below on purpose:
	## `time_scale` alone would do it, but a tool that later sets `time_scale`
	## back to 1 to step something would silently un-freeze seventeen rigs, and
	## per-node `speed_scale` survives that.
	Engine.time_scale = 0.0

	## THE GPU'S OWN CLOCK. `GPUParticles3D` runs on the graphics card and does
	## not care that the tree stopped processing — embers and steam kept moving
	## between two plates and turned up in SG-101's contrast figures as if the
	## marks had done it. `speed_scale = 0` freezes them IN PLACE rather than
	## hiding them, which the earlier fix did: a plate with the braziers deleted
	## out of it is not the picture anybody is judging.
	var particles := 0
	for node in root.find_children("*", "GPUParticles3D", true, false):
		(node as GPUParticles3D).speed_scale = 0.0
		particles += 1

	## THE TEMPORAL ACCUMULATORS. Debanding is a per-frame RANDOM dither: it
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

	## THE LIGHTING PHASE. `_flicker` advances on real frames, so two plates
	## reach the shutter with the braziers, the lantern and the vent at different
	## points in their cycle — and the first attempt at SG-101's measurement
	## reported the contrast getting WORSE when the marks got FAINTER, which is
	## the phase talking and not the marks. Pinned at a fixed value, both plates
	## are lit identically.
	if "_flicker" in view:
		view.set("_flicker", FLICKER)
	return {"particles": particles, "debanding": true, "fog_reprojection": fog}


## The pinned brazier phase. Any fixed number works; this is the one SG-101 and
## SG-107 both used, kept so old plates and new plates are lit the same.
const FLICKER := 12.0

## The pinned RIG phase, same idea one system over (board SG-295). Any fixed
## number works and this one is chosen to be past the start of a breathing idle
## without being at its exact midpoint — a figure caught dead on 0.0 reads as a
## bind pose in a judging frame. Taken `fposmod` a clip's own length, so one
## number lands inside a 0.9 s flinch and a 4.6 s death alike.
const POSE := 0.75

## WHAT A CROSS-RUN COMPARISON THROUGH A ONE-PLATE-PER-PROCESS TOOL IS WORTH
## (board SG-295). Measured, two runs, same arguments, nothing changed between
## them. It is not zero, so the tools that publish one plate per process PRINT it
## rather than letting a reader assume the difference they are looking at is the
## feature. Numbers, not feelings, and they live here so a tool and a check
## cannot come to different conclusions about the same instrument.
##
## `prop_shot` — 0.19%. Was 96.31% when this row opened: one run photographed the
## OPENING FILM. See the full climb down in `pin_clocks`.
##
## `vfx_shot` — 7.73% (the `arc` scene; `aoe` 6.56%). Was 22.45%, and the film
## refusal is most of what it lost. **It does not get `prop_shot`'s treatment and
## it cannot.** Its whole subject is particles in flight, and every lever that
## makes a frame reproducible — `Engine.time_scale`, `GPUParticles3D.speed_scale`
## — is the lever that stops the thing being photographed from existing. A tool
## that photographs motion across two processes is measuring the motion, and the
## honest fix is for it to say so rather than to be quietly rebuilt into a tool
## that photographs nothing.
const CROSS_RUN_FLOOR := {
	"prop_shot": 0.19,
	"vfx_shot": 7.73,
}


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
