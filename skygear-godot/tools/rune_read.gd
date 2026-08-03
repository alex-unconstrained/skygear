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
## THE METHOD, AND THE THREE WAYS THAT FAILED FIRST (all three are `rig_probe`'s
## scars and they are kept here because the next tool to use this will be tempted
## by exactly them):
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
## What survives needs no second exposure to find the rune at all: the rune is
## found by its own COLOUR in one plate, the planking it is read against is the
## ring of pixels immediately around it in the SAME plate, and both plates are
## then measured over those two identical pixel sets. That is what "edge contrast
## against planking" means.
##
## USE:
##     var rune := SkyGearRune.mask(plate_a)
##     var ring := SkyGearRune.ring(rune, plate_a.get_width(), plate_a.get_height())
##     var before := SkyGearRune.edge(plate_a, rune, ring)
##     var after := SkyGearRune.edge(plate_b, rune, ring)

## THE RUNE, BY ITS OWN COLOUR. Every telegraph on this deck is a saturated
## red-to-amber warning drawn over grey-brown planking — the oxblood melee wedge
## and the ranged aim band both. Hue is taken in Godot's 0-1 turn, so the window
## is roughly 0-40 degrees plus the wrap above 340.
const RUNE_SAT := 0.55
const RUNE_VAL := 0.42
const RUNE_HUE := 0.11
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


## The rune pixels: saturated warning colour, found by hue rather than by a diff.
static func mask(img: Image) -> PackedInt32Array:
	var out := PackedInt32Array()
	var w := img.get_width()
	var h := img.get_height()
	var y := 0
	while y < h:
		var x := 0
		while x < w:
			var c := img.get_pixel(x, y)
			if c.s >= RUNE_SAT and c.v >= RUNE_VAL \
					and (c.h <= RUNE_HUE or c.h >= 1.0 - RUNE_HUE):
				out.append(x)
				out.append(y)
			x += STEP
		y += STEP
	return out


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
