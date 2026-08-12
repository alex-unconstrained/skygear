class_name SkyGearDemo
extends RefCounted

## THE DEMO CUT (board SG-213), AND THE ONE PLACE THAT KNOWS ABOUT IT.
##
## The problem this solves, stated as the audit found it: there is one export
## preset and it ships **100% of the game**. Uploading that exe as a demo hands
## over both heroes, the Colossus, the Workshop, the Berths, Articles, fittings
## and the whole Heat ladder — the last of which is reachable from a fresh save
## via OPEN ALL HEATS. `grep -i demo scripts/` returned nothing: there was no
## seam to hang a cut on.
##
## THE CUT IS THE OWNER'S OWN, WORD FOR WORD, from `docs/STEAM-LAUNCH.md`:
## *"waves 1–6, Captain only, Heat 0, no fittings/berths, results screen intact,
## and an end card that says what the full game has."* Nothing here is invented;
## every constant below points at that sentence.
##
## HOW IT IS SWITCHED, AND WHY NOT A CONSTANT. A `const DEMO := true` would mean
## two divergent source trees, which is the way a demo build acquires a bug the
## full game does not have. This reads an **export feature tag** instead — the
## `Windows Desktop (Demo)` preset in `export_presets.cfg` declares
## `custom_features="demo"` and the full preset does not — so both builds come
## off the same commit, the same harness run and the same everything else.
##
## `_forced` is the harness's door, and it is the only one. There is no way to
## turn the demo on from inside the game: a player-reachable switch would be the
## OPEN ALL HEATS mistake in reverse.

## The last wave a demo run reaches. Wave 7 is where the Colossus first appears
## in `SkyGearData.WAVES`, so six is "everything up to the boss" rather than an
## arbitrary stop — the demo shows the whole shape of a run and withholds the
## thing that ends it.
const LAST_WAVE := 6

## The one class a demo ships. The Boilerwright is the second-class reveal and
## the largest single "there is more of this" the store page has.
const CLASS_ID := "captain"

## -1 asks the build, 0 and 1 override it. The harness sets this to prove BOTH
## halves of every gate on one tree — a demo check that could only run in a demo
## build would never run at all.
static var _forced := -1


static func active() -> bool:
	if _forced >= 0:
		return _forced == 1
	return OS.has_feature("demo")


## The wave a run ends on. Everything that asks "is this the last one?" comes
## here; everything that INDEXES `WAVES` still asks `WAVES.size()`, because the
## table is unchanged and a demo build that shortened it would break the
## manifest, the music director and the push-wave lookup at once.
static func last_wave() -> int:
	return LAST_WAVE if active() else SkyGearData.WAVES.size()


## What the end card says the full game has. Kept here rather than in `hud.gd`
## so the promise and the gates that create it cannot drift apart: every line
## below is something this file actually withholds.
static func end_card() -> Array[String]:
	return [
		"THE FULL GAME CONTINUES FROM HERE",
		"twelve waves, and the Brass Colossus at the end of them",
		"the Boilerwright — a second captain who holds ground instead of taking it",
		"the Workshop, the Berths and the Articles between runs",
		"five rungs of Heat, and a ladder that remembers",
	]
