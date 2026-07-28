class_name SkyGearSprites
extends RefCounted

## Which picture of a figure to draw, and which frame of it.
##
## The port drew exactly one image per character — `*_front_idle.png` — for the
## captain, every boarder and every crewman, in every situation. There are three
## authored views of most of them and four delivered animation cycles sitting in
## `assets/art/`, and none of it was reachable. A deck where nothing has a back,
## nothing winds up, and nothing moves its feet is a deck of standees.
##
## Two pieces, both ported straight from the browser build:
##
##   * **`view_for`** — the front/back/attack choice and the mirror, out of
##     `_render_entities.js:viewFor`. The art is authored facing the camera and
##     facing left; +y is toward the camera and the sprite is flipped when the
##     figure is heading right, so two painted views cover all four quadrants.
##   * **`frame`** — one horizontal strip per cycle, sliced on demand, with the
##     browser's three timing modes.
##
## Undelivered cycles are listed and marked `pending`, exactly as the browser
## does, so the slot is documented and the loader stays off it. A missing strip
## falls back to the still, which is why this can ship before the art does.

const ART := "res://assets/art/"

## Delivered strips. Frames are 384 square, laid out left to right.
const STRIPS := {
	"hero_idle": {"path": "animations/hero_idle.png", "count": 12, "fps": 12, "pingpong": true},
	"hero_run": {"path": "animations/hero_run.png", "count": 13, "fps": 12},
	"SCRAPPER_idle": {"path": "animations/scrapper_idle.png", "count": 10, "fps": 10, "pingpong": true},
	"SCRAPPER_run": {"path": "animations/scrapper_run.png", "count": 15, "fps": 12},

	## Not delivered. Kept here so the slot is a decision rather than an
	## oversight, and so the loader can be asked what is outstanding.
	"hero_attack": {"path": "animations/hero_attack.png", "count": 10, "fps": 14, "once": true, "pending": true},
	"SCRAPPER_attack": {"path": "animations/scrapper_attack.png", "count": 10, "fps": 14, "once": true, "pending": true},
	"CREW_idle": {"path": "animations/crew_idle.png", "count": 12, "fps": 12, "pingpong": true, "pending": true},
	"CREW_run": {"path": "animations/crew_run.png", "count": 13, "fps": 12, "pending": true},
	"CREW_attack": {"path": "animations/crew_attack.png", "count": 10, "fps": 14, "once": true, "pending": true},
	"ARMORED_idle": {"path": "animations/armored_idle.png", "count": 12, "fps": 12, "pingpong": true, "pending": true},
	"ARMORED_run": {"path": "animations/armored_run.png", "count": 14, "fps": 12, "pending": true},
	"ARMORED_attack": {"path": "animations/armored_attack.png", "count": 10, "fps": 14, "once": true, "pending": true},
	"SWARM_run": {"path": "animations/swarm_run.png", "count": 12, "fps": 14, "pending": true},
	"SWARM_attack": {"path": "animations/swarm_attack.png", "count": 8, "fps": 16, "once": true, "pending": true},
	"GUNNER_idle": {"path": "animations/gunner_idle.png", "count": 12, "fps": 12, "pingpong": true, "pending": true},
	"GUNNER_attack": {"path": "animations/gunner_attack.png", "count": 10, "fps": 14, "once": true, "pending": true},
	"BOSS_idle": {"path": "animations/colossus_idle.png", "count": 14, "fps": 10, "pingpong": true, "pending": true},
	"BOSS_attack": {"path": "animations/colossus_attack.png", "count": 12, "fps": 12, "once": true, "pending": true},
}

## The three authored stills for each figure. A missing view falls back to the
## front idle — a drone has no back because it is a sphere and never needed one.
const VIEWS := {
	"hero": {"front_idle": "heroes/corsair_front_idle.png",
		"back_idle": "heroes/corsair_back_idle.png",
		"front_attack": "heroes/corsair_front_attack.png"},
	"CREW": {"front_idle": "allies/crew_front_idle.png",
		"back_idle": "allies/crew_back_idle.png",
		"front_attack": "allies/crew_front_attack.png"},
	"SCRAPPER": {"front_idle": "enemies/automaton_front_idle.png",
		"back_idle": "enemies/automaton_back_idle.png",
		"front_attack": "enemies/automaton_front_attack.png"},
	"ARMORED": {"front_idle": "enemies/furnace_knight_front_idle.png",
		"back_idle": "enemies/furnace_knight_back_idle.png",
		"front_attack": "enemies/furnace_knight_front_attack.png"},
	"GUNNER": {"front_idle": "enemies/drone_front_idle.png",
		"front_attack": "enemies/drone_front_attack.png"},
	"SWARM": {"front_idle": "enemies/gremlin_front_idle.png",
		"front_attack": "enemies/gremlin_front_attack.png"},
	"BOSS": {"front_idle": "enemies/colossus_front_idle.png",
		"back_idle": "enemies/colossus_back_idle.png",
		"front_attack": "enemies/colossus_front_attack.png"},
}

static var _cache: Dictionary = {}


## Which of the two authored views, and do we mirror?
##
## `+y` is toward the camera, so a figure heading up-deck is showing you its
## back. The art is painted facing left, so heading right is the mirrored case.
## Two paintings, four quadrants.
static func view_for(direction: Vector2, attacking: bool) -> Dictionary:
	var dir := direction.normalized() if direction.length_squared() > 0.0001 else Vector2.DOWN
	var front: bool = dir.y > -0.15
	var view := "front_idle" if front else "back_idle"
	if attacking and front:
		view = "front_attack"
	return {"view": view, "mirror": dir.x > 0.0, "front": front}


static func still(kind: String, view: String) -> Texture2D:
	var table: Dictionary = VIEWS.get(kind, {})
	var path: String = str(table.get(view, table.get("front_idle", "")))
	if path == "":
		return null
	return _load(ART + path)


## Which frame of a cycle is showing at `time`, or -1 if the cycle is not
## delivered. The three modes are the browser's:
##
##   loop      0..n-1, wrapping. For a run.
##   pingpong  0..n-1..0. For anything with no natural period — an idle authored
##             as a loop that does not close reads as a stutter every cycle.
##   once      runs to the last frame and holds. For a swing.
static func frame(key: String, time: float) -> int:
	var spec: Dictionary = STRIPS.get(key, {})
	if spec.is_empty() or bool(spec.get("pending", false)):
		return -1
	if _load(ART + str(spec.path)) == null:
		return -1
	var count: int = int(spec.count)
	var fps: float = float(spec.fps)
	var step: int = int(floor(maxf(0.0, time) * fps))
	if bool(spec.get("once", false)):
		return mini(step, count - 1)
	if bool(spec.get("pingpong", false)):
		var span: int = maxi(1, (count - 1) * 2)
		var j: int = step % span
		return j if j < count else span - j
	return step % count


## The strip itself, and where in it that frame sits.
static func strip(key: String) -> Texture2D:
	var spec: Dictionary = STRIPS.get(key, {})
	if spec.is_empty() or bool(spec.get("pending", false)):
		return null
	return _load(ART + str(spec.path))


static func frame_rect(key: String, index: int, texture: Texture2D) -> Rect2:
	var spec: Dictionary = STRIPS.get(key, {})
	var count: int = maxi(1, int(spec.get("count", 1)))
	var w: float = float(texture.get_width()) / float(count)
	return Rect2(w * float(index), 0.0, w, float(texture.get_height()))


## What is still outstanding, for the boot log and the harness. A number that
## goes down is the only honest progress report on an art pipeline.
static func pending() -> Array[String]:
	var out: Array[String] = []
	for key in STRIPS.keys():
		if bool(STRIPS[key].get("pending", false)):
			out.append(key)
	return out


static func _load(path: String) -> Texture2D:
	if _cache.has(path):
		return _cache[path]
	var tex: Texture2D = load(path) if ResourceLoader.exists(path) else null
	_cache[path] = tex
	return tex
