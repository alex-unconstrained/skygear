class_name ClipMath
extends RefCounted

## Pure, headless-testable planning for the clip tool (tools/clip.gd).
##
## It lives OUTSIDE the tool on purpose, the same split as `LabMath`: the clip
## tool is a windowed SceneTree — the readback path hangs under `--headless` on
## this machine (board SG-29) — so the tool itself cannot be driven by the
## harness. The three things a motion-evidence tool must get right BEFORE a
## window ever opens are arithmetic and table lookups, and those are pulled out
## here where the harness loads and asserts them directly:
##
##   * how many frames N seconds at F fps actually is, in whole sim ticks;
##   * that every scenario the tool advertises resolves to something posable —
##     including one scenario per shipped cutscene, which is what closes SG-32
##     (a cutscene is a posed clip);
##   * what the stitcher should be told about per-frame delay.
##
## The tool wires these numbers; the harness pins them (`clip ·` checks).

## The simulation is stepped at the fixed tick the whole project steps it at —
## `game._process(1.0 / 60.0)`, the vfx_shot/cloak_shot idiom. A clip's clock is
## TICKS, not wall time, so its duration survives whatever refresh rate the
## capturing machine happens to run at.
const SIM_HZ := 60.0

## 60 / 20 is a whole number of ticks per frame and a whole 50 ms per GIF frame
## — GIF delays are quantised to 10 ms, so an fps that divides both cleanly is
## the one that plays back at the speed the deck actually ran.
const DEFAULT_FPS := 20.0

## How long a cutscene clip keeps rolling after the scene's last keyframe: long
## enough to SHOW the hand-back — the gameplay camera returning exactly is the
## claim the harness pins in geometry, and the tail is that claim on film.
const CUTSCENE_TAIL := 0.75

## The smoke: the shortest clip that still proves the whole pipeline — pose,
## real sim+render, frames on disk, a stitched animation whose frame count
## matches the plan. Run by `hub -- all` (the tool's bare invocation), so it is
## deliberately small: one second of the dash at 12 fps is 12 frames.
const SMOKE := {"scenario": "dash", "seconds": 1.0, "fps": 12.0, "out": "smoke"}

## The scenarios that are not cutscenes. Every entry poses the way
## `scripts/screen_poser.gd` and `tools/vfx_shot.gd` pose theirs — a plausible
## game, driven by hand, one tick at a time.
##
##   kind      how tools/clip.gd stages it (fight / dash / projectiles)
##   seconds   default length; `--seconds` overrides
##   still     ONLY a scenario that asks for stillness gets the sway forced off
##             (the deterministic-rest rule). None of these do: a motion clip of
##             a dead-still ship is evidence about the wrong game.
const SCENARIOS := [
	{"id": "fight", "kind": "fight", "seconds": 5.0, "still": false,
		"what": "wave 3 mid-swarm — the real spawn queue, autos, cannons and a cast, five seconds in"},
	{"id": "dash", "kind": "dash", "seconds": 2.0, "still": false,
		"what": "the cloak's crack (SG-23) — a held run through the real key, then the dash"},
	{"id": "projectiles", "kind": "projectiles", "seconds": 3.0, "still": false,
		"what": "the SG-40 bolt heads in flight — a mortar shell's arc, a lance, and the deck guns"},
	{"id": "scrapper", "kind": "scrapper", "seconds": 6.0, "still": false,
		"what": "the scrapper pilot's witness (SG-55): a rank of scrappers walks the deck and closes to swing — today the statue-glide, and the same lens judges the rig when it lands"},
	{"id": "boilerwright", "kind": "boilerwright", "seconds": 6.0, "still": false,
		"what": "the second class on his own rig (SG-74): a march up-deck, two heavy wrench cuts off the variant rotation, then Tap Main's kneel — the plant, on film"},
	{"id": "knight", "kind": "knight", "seconds": 7.0, "still": false,
		"what": "the furnace knight (SG-85): three walls walk the deck at seventy-five, close and cut — and then two of them DIE, which no figure in this game had ever done on screen"},
	{"id": "boss", "kind": "boss", "seconds": 10.0, "still": false,
		"what": "the segmented Colossus (SG-90): the walk at ninety-five, a two-fisted slam, the half-health TURN it cannot be burst through — and then it COMES APART, thirteen parts breaking at the joints they hinged on and landing on the planking"},
	{"id": "crew", "kind": "crew", "seconds": 8.0, "still": false,
		"what": "your own sailors, on a rig at last (SG-88): a lane of crew working up the deck beside a gun, the bayonet stab they close a boarder with — and then one of them DIES, which is the first time an ALLY has gone down on screen rather than blinking out"},
	{"id": "crewassist", "kind": "crewassist", "seconds": 9.0, "still": false,
		"what": "the owner's crew ask on film (SG-187): a FULL watch of twelve at their stations, five boarders in the middle lane and NOTHING in the outer two — before, the eight outer men stand at the head of an empty lane swinging at bare planking; after, the ones who can reach step across to the fight, one man per boarder, and each lane keeps its anchor"},
	{"id": "swarm", "kind": "swarm", "seconds": 8.0, "still": false,
		"what": "the goblin (SG-89), and the deck is all mesh: SIX of them at two hundred and thirty units a second, three different swings on the same crew, and two dying — the figure a player sees most after the captain, moving for the first time"},
	{"id": "drone", "kind": "drone", "seconds": 6.0, "still": false,
		"what": "the gunner flies (SG-87): four propeller drones hovering and bobbing over a real fight, rotors turning, shooting from three hundred and forty units — the one boarder whose whole animation is arithmetic"},
]


## Frame plan for `seconds` of sim at roughly `fps` captured frames a second.
## Everything downstream is derived from two integers:
##
##   every    sim ticks per captured frame (>= 1, so fps above 60 clamps to 60)
##   frames   captured frames (>= 1, so a degenerate ask still produces a clip)
##
## `ticks` is frames * every exactly — the tool's loop runs that many sim steps
## and captures on the last tick of each group, so the file count on disk CANNOT
## disagree with this plan without the loop being broken. `seconds` is the real
## duration the clip ends up with (requested seconds rounded UP to whole
## frames), and `delay_ms` is what the stitcher stamps on each frame so playback
## runs at sim speed.
static func plan(seconds: float, fps: float) -> Dictionary:
	var every := maxi(1, roundi(SIM_HZ / clampf(fps, 1.0, SIM_HZ)))
	var wanted_ticks := maxi(1, ceili(maxf(0.0, seconds) * SIM_HZ))
	var frames := maxi(1, ceili(float(wanted_ticks) / float(every)))
	return {
		"every": every,
		"frames": frames,
		"ticks": frames * every,
		"seconds": float(frames * every) / SIM_HZ,
		"delay_ms": roundi(1000.0 * float(every) / SIM_HZ),
	}


## Every scenario the tool will answer to: the three staged ones, then one per
## shipped cutscene, straight off `SkyGearCutscene.list_ids()`. Derived rather
## than copied so a cutscene authored next month is a clip scenario the same
## day, with nobody remembering to add it — a hand-maintained twin of that list
## is exactly the two-lists-disagreeing failure STATUS names.
static func ids() -> Array[String]:
	var out: Array[String] = []
	for spec in SCENARIOS:
		out.append(str(spec.id))
	for id in SkyGearCutscene.list_ids():
		out.append(str(id))
	return out


## Resolve a name to its spec, or {} for a name the tool does not know. A
## cutscene scenario carries the loaded scene's own cue and wave so the tool can
## stage the deck the moment actually happens on (wave 4 for the grapple shot,
## wave 12 for the Colossus).
static func find(id: String) -> Dictionary:
	for spec in SCENARIOS:
		if str(spec.id) == id:
			return spec
	var scene := SkyGearCutscene.load_scene(id)
	if scene.is_empty() or SkyGearCutscene.length(scene) <= 0.0:
		return {}
	return {"id": id, "kind": "cutscene", "cutscene": id,
		"cue": str(scene.get("cue", "")), "wave": int(scene.get("wave", 0)),
		"seconds": default_seconds_for_cutscene(scene), "still": false,
		"what": "the %s cutscene, played through the real cutscene_player, hand-back included" % id}


## A cutscene clip's default length: the whole authored scene, plus the tail
## that films the camera coming back. `--seconds` can still cut it short — that
## is a person's call to make, not a default's.
static func default_seconds_for_cutscene(scene: Dictionary) -> float:
	return SkyGearCutscene.length(scene) + CUTSCENE_TAIL
