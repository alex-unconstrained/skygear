class_name SkyGearRune
extends RefCounted

## HOW LEGIBLE IS A TELEGRAPH AGAINST THE PLANKING IT IS DRAWN ON — one answer,
## in one place.
##
## This is `rig_probe.gd`'s measurement, lifted out of it (SG-108) because
## `marks_shot.gd` needed the identical one and STATUS.md's second recurring
## failure mode is *two functions disagreeing about one number*. A mark-density
## answer and a rig answer that were computed by two separately-written rune
## masks would not be comparable to each other, and both are measured against the
## same 3% relative gate.
##
##
## WHERE THE RUNE PIXELS COME FROM, AND WHY THEY NO LONGER COME FROM A COLOUR
##
## Until SG-116 this file found the rune by its COLOUR: any pixel with
## `s >= 0.55, v >= 0.42` and hue within 0.11 of red. That window does not
## describe a telegraph. It describes *warm things*, and this deck is full of
## them. On the wave-6 pose it selected **26,095 pixels**, and a large share of
## them were:
##
##   * **the brazier bowls** — `view3d.gd` draws a floor pool as a DECOR decal at
##     `Color(1.0, 0.56, 0.22)`, which is h≈0.062 s≈0.78 v=1.0: not near the
##     window, dead centre of it. The vent glow (`glowv`) is the same colour and
##     the brazier's own omni is `#ff8a3a`, so it warmed the surrounding planking
##     into the window too — the RING was contaminated as well as the mask.
##   * **an ARMORED boarder's lit plating** — `assets/models/lights.json` gives
##     model key `armored` an omni at `ff7a30`, h≈0.055, `"shape": "flicker"`.
##     That is lit GEOMETRY rather than a decal, so no colour test could ever
##     separate it from a rune that is also a warm mark on a dark deck.
##
## A relative A/B answer measured over a contaminated set is not *invented*, it
## is DILUTED — the extra pixels are the same in both plates, so they pull the
## difference toward zero. That is why every published rune-contrast cost was an
## understatement rather than a fabrication, and it is why SG-116 was filed P3
## rather than P1. It is also why the numbers had to be re-taken: a comfortable
## pass measured over a pixel set that is mostly not the thing under test is not
## a comfortable pass, it is an unread gauge.
##
## THE MASK ASKS THE RENDERER INSTEAD. A telegraph decal is a node. Hide the
## telegraph decals, photograph the same frozen frame again, and the pixels that
## CHANGED are the pixels the telegraph authored — by construction rather than by
## resemblance. Nothing else in the frame moved, because `SkyGearStill.freeze`
## stopped every clock that could have moved it and the caller has already proved
## its own floor is exactly zero.
##
## Which decals are telegraph is not a judgement this file makes. `view3d.gd`'s
## `_decal_class()` keys telegraphs by the `tg`/`tr`/`tn` prefix and that is the
## authority; `TELEGRAPH_PREFIXES` below is that predicate quoted, with a harness
## check holding the two spellings together so the quote cannot go stale.
##
## AND IT IS FALSIFIABLE, WHICH THE COLOUR WINDOW WAS NOT. A colour window has no
## frame on which it is *required* to select nothing, so nothing about it could
## ever fail. This one does: pose a deck with a brazier lit and no enemy in
## windup, and the mask must come back EMPTY. `tools/rune_probe.gd` is that
## assertion, it is registered in the hub, and it is the check the old mask fails
## — the old mask finds thousands of pixels on that frame, every one of them fire.
##
## WHAT THIS MASK IS STILL NOT (SG-123, filed before this was written). The
## ranged windup also draws **aim dashes** through `_aim_dash_ribbon()`, and
## those go into `_ribbon_node` — ONE `MeshInstance3D` shared with blade trails
## and bolt ribbons. Hiding it would hide things that are not telegraph, which is
## the same contamination this file exists to remove, only pointing the other
## way. So the dashes are OUTSIDE this mask. The wedge, the inner windup-clock
## fill, the ranged aim band and the boss turn ring — every telegraph pixel that
## is a decal — are inside it.
##
##
## THE THREE WAYS THAT FAILED BEFORE THIS ONE (all three are `rig_probe`'s scars
## and they are kept here because the next tool to use this will be tempted by
## exactly them):
##
##   1. **Re-arming the windups for a second exposure.** A windup's decal is
##      authored when the state is ENTERED, so re-entering it inside a stopped
##      simulation brought back one telegraph out of four; the second plate was
##      mostly bare planking and the tool read that as lost contrast.
##   2. **Two independently-derived masks.** Deriving the rune pixels separately
##      from each plate compares two different sets of pixels and calls the
##      difference a result. The sets differed by a third.
##   3. **Diffing against `effects.clear()`.** A ranged windup's aim band is
##      drawn off the ENEMY'S OWN state, not out of the effects list, so the
##      "bare" plate came back still carrying the band and the tool reported the
##      rig IMPROVING legibility by 60%.
##
## The mask below is a diff and it is NOT number 3. It hides the decal NODES,
## which is where the band actually is, rather than clearing a list the band was
## never in. It is not number 2 either: ONE mask is derived, from one pair, and
## every later plate is measured over it. And it is not number 1: no state is
## re-entered and no simulation is stepped — the only thing that changes between
## the two exposures is a `visible` flag.
##
## The planking a rune is read against is unchanged: the ring of pixels
## immediately around it in the SAME plate. Both plates are then measured over
## those two identical pixel sets. That is what "edge contrast against planking"
## means.
##
## USE:
##     var got := await SkyGearRune.mask_of(view, shoot)   ## `shoot` takes a plate
##     var rune: PackedInt32Array = got.mask
##     var ring := SkyGearRune.ring(rune, w, h)
##     var before := SkyGearRune.edge(got.plate, rune, ring)
##     var after := SkyGearRune.edge(other_plate, rune, ring)

## WHICH DECALS ARE TELEGRAPH. Quoted from `view3d.gd`'s `_decal_class()`:
## `tg` is the wedge and the ranged aim band, `tr` the inner fill that runs the
## windup clock, `tn` the boss turn ring. The harness check
## `rune · the telegraph prefixes here are the ones view3d actually draws`
## fails if that function's prefixes and these ever drift apart.
const TELEGRAPH_PREFIXES := ["tg", "tr", "tn"]

## The planking a rune is read against: the ring just outside it. 12 px at
## 1600x900 is about the width of the band itself, which is the distance an eye
## actually uses to find an edge.
const RING_PX := 12
## Every other pixel. A band is tens of thousands of pixels and the median of
## half of them is the same median.
const STEP := 2
## The relative gate DECK-IDENTITY §7.5 established, after `ink.gd`'s
## `CONTRAST_FLOOR = 4.5` turned out to be a floor for TEXT that the shipped
## rune-against-planking figure of 1.91 has never come near.
const COST_GATE := 3.0


## Is this decal key a telegraph? `view3d.gd:_decal_class()` is the authority and
## this is that predicate; it is restated here only because a tool cannot call a
## private static, and the harness holds the two together.
static func is_telegraph_key(key: String) -> bool:
	for prefix in TELEGRAPH_PREFIXES:
		if key.begins_with(prefix):
			return true
	return false


## Hide every telegraph decal currently drawn. Returns the nodes hidden so the
## caller can put them back — the same `visible` idiom `rig_probe.gd` uses on
## `_rigging` and `marks_shot.gd` uses on `_mark_batch`.
##
## MUST be called on a FROZEN scene. `view3d.gd` rebuilds the whole telegraph
## from `enemy.state` every frame, and its `_decals.has(key)` fast path does not
## re-set `visible`, so a `_sync_effects` tick between the hide and the restore
## would neither undo this nor be undone by it.
static func hide(view) -> Array:
	var hidden: Array = []
	for key in view._decals.keys():
		if not is_telegraph_key(str(key)):
			continue
		var node = view._decals[key]
		if node != null and is_instance_valid(node) and node.visible:
			node.visible = false
			hidden.append(node)
	return hidden


static func show(hidden: Array) -> void:
	for node in hidden:
		if is_instance_valid(node):
			node.visible = true


## THE RUNE PIXELS, IN ONE DANCE THAT BOTH TOOLS DO IDENTICALLY.
##
## `shoot` is the CALLER'S own plate function — `func(slug: String) -> Image` —
## because each tool already has one that saves a PNG and, more importantly,
## waits on `RenderingServer.frame_post_draw` rather than on `process_frame`
## (SG-114). Passing it in rather than reimplementing it here keeps this file out
## of the readback business entirely and keeps every plate in the project going
## through the same door.
##
## Returns `{mask, plate, dark, decals}`: the rune pixels, the lit plate they
## were taken from (which is the plate the caller wants anyway), the plate with
## the telegraphs hidden, and how many decals were hidden to find them. A caller
## that gets `decals == 0` posed no telegraph and must say so rather than divide
## by it.
static func mask_of(view, shoot: Callable) -> Dictionary:
	var lit: Image = await shoot.call("tele")
	var hidden := hide(view)
	var dark: Image = await shoot.call("notele")
	show(hidden)
	return {"mask": mask(lit, dark), "plate": lit, "dark": dark,
		"decals": hidden.size()}


## Which pixels differ between the two exposures. `SkyGearStill.MOVED` is this
## project's ONE definition of "this pixel changed" and it is reused rather than
## restated — a second threshold here would be failure mode 2 with a number
## attached.
static func mask(lit: Image, dark: Image) -> PackedInt32Array:
	var out := PackedInt32Array()
	if lit == null or dark == null:
		return out
	var w := mini(lit.get_width(), dark.get_width())
	var h := mini(lit.get_height(), dark.get_height())
	var y := 0
	while y < h:
		var x := 0
		while x < w:
			var a := lit.get_pixel(x, y)
			var b := dark.get_pixel(x, y)
			if maxf(absf(a.r - b.r), maxf(absf(a.g - b.g), absf(a.b - b.b))) \
					>= SkyGearStill.MOVED:
				out.append(x)
				out.append(y)
			x += STEP
		y += STEP
	return out


## WHICH PIXELS A NUMBER WAS MEASURED OVER, AS A PICTURE. `still.gd` keeps the
## same habit for the same reason: a percentage sends the next agent guessing,
## a picture sends them to the thing itself. Every cost this file computes is a
## median over the white pixels here, so this is the one artefact that makes a
## published figure checkable by looking rather than by re-deriving.
static func save_mask(pts: PackedInt32Array, w: int, h: int, path: String) -> void:
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	img.fill(Color.BLACK)
	var i := 0
	while i < pts.size():
		## Drawn at STEP so a sampled mask still reads as a shape rather than as
		## a stipple; the pixel set itself is unchanged.
		for dy in STEP:
			for dx in STEP:
				var x: int = pts[i] + dx
				var y: int = pts[i + 1] + dy
				if x < w and y < h:
					img.set_pixel(x, y, Color.WHITE)
		i += 2
	img.save_png(path)


## How many of `pts` fall inside `box`. For a probe that wants to assert a mask
## does NOT reach into a region it has no business in — a brazier bowl, say.
static func count_in(pts: PackedInt32Array, box: Rect2i) -> int:
	var n := 0
	var i := 0
	while i < pts.size():
		if box.has_point(Vector2i(pts[i], pts[i + 1])):
			n += 1
		i += 2
	return n


## The planking a rune is read against: a ring `RING_PX` out from it that is not
## itself rune. Built on a coarse occupancy grid so the dilation is a lookup
## rather than a search.
static func ring(rune: PackedInt32Array, w: int, h: int) -> PackedInt32Array:
	var gw := w / STEP + 2
	var gh := h / STEP + 2
	var grid := PackedByteArray()
	grid.resize(gw * gh)
	var i := 0
	while i < rune.size():
		grid[(rune[i + 1] / STEP) * gw + rune[i] / STEP] = 1
		i += 2
	var reach := RING_PX / STEP
	var out := PackedInt32Array()
	var gy := 0
	while gy < gh:
		var gx := 0
		while gx < gw:
			if grid[gy * gw + gx] == 0:
				var near := false
				var dy := -reach
				while dy <= reach and not near:
					var dx := -reach
					while dx <= reach:
						var ax := gx + dx
						var ay := gy + dy
						if ax >= 0 and ay >= 0 and ax < gw and ay < gh \
								and grid[ay * gw + ax] == 1:
							near = true
							break
						dx += 1
					dy += 1
				## The grid is padded by two cells so the dilation never has to
				## test a bound; those pad cells are not pixels, so they are
				## dropped here rather than sampled off the end of the image.
				if near and gx * STEP < w and gy * STEP < h:
					out.append(gx * STEP)
					out.append(gy * STEP)
			gx += 1
		gy += 1
	return out


## `ink.gd`'s own contrast formula, so this number means what every other
## contrast number in the project means. Medians, not means — §7.5's yardstick,
## and a mean is hostage to the few pixels at a rune's antialiased rim.
static func edge(img: Image, rune: PackedInt32Array,
		around: PackedInt32Array) -> float:
	if rune.is_empty() or around.is_empty():
		return 0.0
	return SkyGearInk.contrast(median(img, rune), median(img, around))


static func median(img: Image, pts: PackedInt32Array) -> Color:
	var ls: Array[float] = []
	var i := 0
	while i < pts.size():
		ls.append(SkyGearInk.luminance(img.get_pixel(pts[i], pts[i + 1])))
		i += 2
	ls.sort()
	var m: float = ls[ls.size() / 2]
	## A grey of the same relative luminance: `contrast()` only reads luminance,
	## and a median COLOUR is not a thing that exists.
	var v: float = pow((m + 0.055) / 1.055, 1.0 / 2.4) if m > 0.0031308 \
		else m * 12.92
	return Color(v, v, v)


## How much of the planking ring the thing under test actually darkens. Reported
## because a gate that passes because the thing under test never touched the
## thing it threatened is a coincidence, not a gate.
static func darkened(with_it: Image, without: Image,
		around: PackedInt32Array) -> float:
	if around.is_empty():
		return 0.0
	var hit := 0
	var i := 0
	while i < around.size():
		if SkyGearInk.luminance(without.get_pixel(around[i], around[i + 1])) \
				- SkyGearInk.luminance(with_it.get_pixel(around[i], around[i + 1])) >= 0.004:
			hit += 1
		i += 2
	return 200.0 * float(hit) / float(around.size())
