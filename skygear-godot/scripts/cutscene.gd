class_name SkyGearCutscene
extends RefCounted

## A cutscene: a list of camera keyframes, and the arithmetic between them.
##
## THIS FILE IS THE READER. It was written before the authoring tool and before
## a single scene existed, because the one failure this project has committed
## five times is shipping a saved format nothing consumes — a table that reads
## as a feature and does nothing. `tools/cutscene_lab.gd` writes these files;
## `scripts/cutscene_player.gd` drives a real camera from them; `view3d.gd`
## calls `cue()` at four named moments. Every one of those existed before the
## first `.json` did.
##
## THE FORMAT, `assets/cutscenes/<id>.json`:
##
##     {
##       "id": "colossus_arrival",
##       "name": "THE COLOSSUS",
##       "cue": "boss_arrival",          which moment plays it, or "" for never
##       "wave": 0,                      narrows `wave_start` to one wave
##       "hold": true,                   lock the captain while it runs
##       "hide_hud": true,               and take the HUD down
##       "letterbox": 0.12,              bar height, as a fraction of the screen
##       "caption": "THE COLOSSUS",
##       "keys": [
##         {"t": 0.0, "eye": [0, 760, 1180], "look": [0, 0, 315],
##          "fov": 36.09, "roll": 0.0, "ease": "inout"},
##         ...
##       ]
##     }
##
## EVERY NUMBER IS IN GROUND UNITS, the simulation's own coordinates — the deck
## is 1680 x 2320 of them and every other spatial number in this project is
## quoted in them. `eye` and `look` are [x, height, z] where x and z are the
## ground plane exactly as the simulation sees it (ground y is depth) and
## height is up off the planking. `view3d.gd` multiplies by `WORLD_SCALE` on
## the way to metres and nothing else has to know that number exists.
##
## `fov` is the VERTICAL field in degrees. `shipped_fov()` is the one the whole
## game is calibrated to; a keyframe that carries it and sits at `shipped_eye`
## reproduces the gameplay framing to the pixel, which is what makes a cutscene
## able to start from where the player already was.

## Where they live. A flat directory of one file per cutscene, so a scene can be
## added, diffed, reverted and pull-requested on its own.
const DIR := "res://assets/cutscenes"
## And an index beside them, rewritten by `save_scene` every time.
##
## Not a hand-maintained list — those go stale within a week, and this project
## has the scars. It exists because `DirAccess` over `res://` is reliable in the
## editor and in a `--script` run but depends on what the exporter chose to pack,
## and a cutscene that plays in the lab and not in the build is the worst of the
## available failures. `list_ids()` reads the directory AND the index and
## returns the union; the harness asserts the two agree.
const INDEX := "res://assets/cutscenes/index.json"

## THE TRIGGER POINTS. A cue is a moment in the game with a call site in the
## shipped code; a cutscene names one and plays there. Adding a cutscene to an
## existing moment is a data change and needs no code at all — adding a NEW
## moment is a code change, which is honest, because a trigger point IS code.
##
## The right-hand side names the file and the function that fires it, and the
## harness (`cutscene · every cue this table names is actually called`) proves
## each one exists by reading the source. That check is the whole defence
## against this table drifting into fiction.
const CUES := {
	"boss_arrival": "the Colossus climbs aboard — scripts/game.gd, spawn_enemy",
	"run_open": "a run reaches its first wave; the establishing shot — scripts/game.gd raises the flag in begin_run, scripts/view3d.gd, _watch_cues spends it",
	"wave_start": "a wave begins; the `wave` field narrows it to one — scripts/view3d.gd, _watch_cues",
	"victory": "the twelfth wave is cleared — scripts/view3d.gd, _watch_cues",
	"defeat": "the Boiler goes — scripts/view3d.gd, _watch_cues",
}

## How a segment gets from one keyframe to the next.
##
## EASE IS NOT DECORATION HERE. A camera that lerps linearly between two poses
## reads as a machine sliding on a rail — it starts at full speed and stops
## dead, which is the single clearest tell of an unauthored shot. `inout` is the
## default for exactly that reason and is what almost every segment wants.
##
##   linear  constant speed. For a long continuous drift that must not settle.
##   in      slow away from this key, arriving fast. A push.
##   out     leaves fast, settles onto the next key. A recoil, or a reveal.
##   inout   slow at both ends. The default, and usually right.
##   hold    no motion at all until the next key, then a cut. A shot change.
const EASES := ["linear", "in", "out", "inout", "hold"]

## A blank scene is TWO keys a second apart rather than one, because a scene
## with a single key has no duration, no segment and nothing to scrub — the
## first thing anyone does with a new cutscene is drag the bar, and it has to
## move something.
const NEW_LENGTH := 2.0


# ------------------------------------------------------------------ the lens --

## The field of view the whole game is calibrated to, read off the renderer's
## own constants rather than retyped. Two functions disagreeing about one number
## is how three of this project's visual bugs were made; this is that number.
static func shipped_fov() -> float:
	return rad_to_deg(2.0 * atan((SkyGearView3D.REF_HEIGHT * 0.5) / SkyGearView3D.FOCAL))


## Where the gameplay camera sits when the captain is at `focus`, in ground
## units. Straight out of `_track_camera`, so a keyframe made from this is the
## shipped framing and a cutscene can begin from the shot the player was already
## looking at rather than cutting to somewhere else.
static func shipped_eye(focus: Vector2) -> Vector3:
	return Vector3(focus.x, SkyGearView3D.CAM_HEIGHT, focus.y + SkyGearView3D.CAM_NEAR)


## And what it is pointed at: the place its axis crosses the planking. The
## gameplay camera is a fixed pitch, so the look point is the eye run forward
## until height reaches zero — `CAM_HEIGHT / tan(PITCH)` along the deck.
static func shipped_look(focus: Vector2) -> Vector3:
	var reach: float = SkyGearView3D.CAM_HEIGHT / maxf(0.0001, tan(SkyGearView3D.PITCH))
	return Vector3(focus.x, 0.0, focus.y + SkyGearView3D.CAM_NEAR - reach)


# --------------------------------------------------------------- the numbers --

## `u` through a segment, eased. Kept tiny and pure so the harness can pin the
## shape of each curve rather than trusting the name on it.
static func ease_at(kind: String, u: float) -> float:
	var t := clampf(u, 0.0, 1.0)
	match kind:
		"linear":
			return t
		"in":
			return t * t
		"out":
			return 1.0 - (1.0 - t) * (1.0 - t)
		"hold":
			## A cut. Nothing moves until the next key is reached, and the caller
			## sees the outgoing pose for the whole segment.
			return 0.0 if t < 1.0 else 1.0
		_:
			## smoothstep. Zero derivative at both ends, which is what makes a move
			## look decided on rather than triggered.
			return t * t * (3.0 - 2.0 * t)


## Fill in everything a hand-written or half-written file left out, and put the
## keys in time order. Every reader goes through here, so nothing downstream has
## to defend itself against a missing field.
static func normalise(raw: Dictionary) -> Dictionary:
	var scene := raw.duplicate(true)
	scene["id"] = str(scene.get("id", ""))
	scene["name"] = str(scene.get("name", scene.id)).to_upper()
	scene["cue"] = str(scene.get("cue", ""))
	scene["wave"] = int(scene.get("wave", 0))
	scene["hold"] = bool(scene.get("hold", true))
	scene["hide_hud"] = bool(scene.get("hide_hud", true))
	scene["letterbox"] = clampf(float(scene.get("letterbox", 0.12)), 0.0, 0.3)
	scene["caption"] = str(scene.get("caption", ""))
	## The ship keeps moving under a cutscene unless the shot says otherwise. A
	## locked-off camera on a flying ship reads as a still image, and the sway is
	## the cheapest thing there is that says the deck is in the air.
	scene["sway"] = bool(scene.get("sway", true))
	var keys: Array = []
	for entry in (scene.get("keys", []) as Array):
		if entry is not Dictionary:
			continue
		var key: Dictionary = (entry as Dictionary).duplicate(true)
		key["t"] = maxf(0.0, float(key.get("t", 0.0)))
		key["eye"] = _triple(key.get("eye", null), Vector3(0.0, 760.0, 1180.0))
		key["look"] = _triple(key.get("look", null), Vector3(0.0, 0.0, 315.0))
		key["fov"] = clampf(float(key.get("fov", shipped_fov())), 4.0, 120.0)
		key["roll"] = clampf(float(key.get("roll", 0.0)), -90.0, 90.0)
		key["ease"] = str(key.get("ease", "inout"))
		if not EASES.has(key.ease):
			key["ease"] = "inout"
		## PINNED TO THE GAMEPLAY CAMERA. `"from": "gameplay"` means this key's
		## eye and look are not authored at all — they are whatever the shipped
		## solve is pointing at when the cutscene starts, filled in by `bind()`.
		##
		## This is what lets a shot begin and end without a cut. The gameplay
		## camera follows the captain, so where it IS depends on where she is
		## standing when the Colossus climbs aboard, and a keyframe with fixed
		## numbers cannot know that. A last key pinned this way lands the shot back
		## on the exact pose the player is about to be handed, which is the
		## difference between a cutscene ending and a cutscene stopping.
		key["from"] = str(key.get("from", ""))
		keys.append(key)
	keys.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.t) < float(b.t))
	scene["keys"] = keys
	return scene


static func _triple(value, fallback: Vector3) -> Array:
	if value is Array and (value as Array).size() >= 3:
		return [float(value[0]), float(value[1]), float(value[2])]
	return [fallback.x, fallback.y, fallback.z]


## Fill in every key pinned to the gameplay camera, for a camera that is
## currently following `focus`. Returns a copy — the file on disk still says
## "gameplay", which is the whole point: the pin travels with the scene and is
## resolved fresh every time it plays.
##
## Everything downstream (`sample`, `length`, the lab's scrub) works on the
## bound copy, so nothing else in the feature has to know pins exist.
static func bind(scene: Dictionary, focus: Vector2) -> Dictionary:
	var out := scene.duplicate(true)
	var eye := shipped_eye(focus)
	var look := shipped_look(focus)
	for entry in (out.get("keys", []) as Array):
		var key: Dictionary = entry
		if str(key.get("from", "")) != "gameplay":
			continue
		key["eye"] = [eye.x, eye.y, eye.z]
		key["look"] = [look.x, look.y, look.z]
		key["fov"] = shipped_fov()
		key["roll"] = 0.0
	return out


static func to_vector(triple) -> Vector3:
	if triple is Array and (triple as Array).size() >= 3:
		return Vector3(float(triple[0]), float(triple[1]), float(triple[2]))
	return Vector3.ZERO


## How long the whole thing runs: the last keyframe's time. There is no separate
## length field on purpose — two numbers that have to agree about one duration
## is the same bug as two functions that have to agree about one number.
static func length(scene: Dictionary) -> float:
	var keys: Array = scene.get("keys", [])
	if keys.is_empty():
		return 0.0
	return maxf(0.0, float((keys[keys.size() - 1] as Dictionary).get("t", 0.0)))


## THE CAMERA AT TIME `t`. Everything else in this feature is plumbing around
## this function: the lab scrubs it, playback advances it, and the headless shot
## calls it once.
##
## Before the first key and after the last it returns that key exactly, so a
## scene can be sampled at any time at all without the caller clamping first.
static func sample(scene: Dictionary, t: float) -> Dictionary:
	var keys: Array = scene.get("keys", [])
	if keys.is_empty():
		return {"eye": Vector3(0.0, 760.0, 1180.0), "look": Vector3(0.0, 0.0, 315.0),
			"fov": shipped_fov(), "roll": 0.0}
	var first: Dictionary = keys[0]
	if t <= float(first.t) or keys.size() == 1:
		return _pose(first)
	var last: Dictionary = keys[keys.size() - 1]
	if t >= float(last.t):
		return _pose(last)
	for i in keys.size() - 1:
		var a: Dictionary = keys[i]
		var b: Dictionary = keys[i + 1]
		if t < float(a.t) or t > float(b.t):
			continue
		var span: float = float(b.t) - float(a.t)
		## Two keys at the same instant are a cut, and dividing by that span is a
		## NaN camera — which renders as nothing at all and looks like the tool
		## crashed. Take the later one.
		if span <= 0.0001:
			return _pose(b)
		## The ease belongs to the OUTGOING key, which is the convention every
		## timeline anyone has already used follows: the curve you set on a key
		## describes how you leave it.
		var e := ease_at(str(a.ease), (t - float(a.t)) / span)
		return {
			"eye": to_vector(a.eye).lerp(to_vector(b.eye), e),
			"look": to_vector(a.look).lerp(to_vector(b.look), e),
			"fov": lerpf(float(a.fov), float(b.fov), e),
			"roll": lerpf(float(a.roll), float(b.roll), e),
		}
	return _pose(last)


static func _pose(key: Dictionary) -> Dictionary:
	return {"eye": to_vector(key.eye), "look": to_vector(key.look),
		"fov": float(key.fov), "roll": float(key.roll)}


## POINT A REAL CAMERA. One implementation, called by the runtime, by the lab's
## free-flight and by the headless shot — because the moment there are two, the
## shot you approved in the tool is not the shot the game plays.
##
## `sway_roll` and `sway_yaw` are the renderer's own ship motion in degrees,
## added on top rather than assigned over, the same rule the shake follows.
static func aim(camera: Camera3D, shot: Dictionary, sway_roll: float = 0.0,
		sway_yaw: float = 0.0) -> void:
	if camera == null:
		return
	var scale: float = SkyGearView3D.WORLD_SCALE
	var eye: Vector3 = (shot.eye as Vector3) * scale
	var look: Vector3 = (shot.look as Vector3) * scale
	var axis := look - eye
	## Degenerate poses happen while a keyframe is being dragged: eye on top of
	## look, or straight down, both of which make `look_at` throw and leave the
	## camera wherever it was. Nudge rather than refuse — a tool that stops
	## responding at the exact moment you drag past vertical is a tool you learn
	## to avoid one axis of.
	if axis.length() < 0.0005:
		axis = Vector3(0.0, -0.001, -0.01)
	var up := Vector3.UP
	if absf(axis.normalized().dot(up)) > 0.9995:
		up = Vector3.BACK
	camera.position = eye
	camera.look_at(eye + axis, up)
	camera.fov = clampf(float(shot.fov), 4.0, 120.0)
	var roll: float = float(shot.roll) + sway_roll
	if absf(roll) > 0.0001:
		## About the camera's own view axis, which is what roll means. Godot's
		## camera looks down local -Z, so BACK is the axis of the lens.
		camera.rotate_object_local(Vector3.BACK, deg_to_rad(roll))
	if absf(sway_yaw) > 0.0001:
		camera.rotate_object_local(Vector3.UP, deg_to_rad(sway_yaw))


# ------------------------------------------------------------------- on disk --

## Every cutscene id the build knows about. The directory and the index, unioned
## and sorted — see the comment on `INDEX` for why it is both and not either.
static func list_ids() -> Array[String]:
	var seen := {}
	if DirAccess.dir_exists_absolute(DIR):
		for file in DirAccess.get_files_at(DIR):
			var name := str(file)
			## `.remap` is what an exported build renames a packed file to, and a
			## build that lists `foo.json.remap` and then fails to open `foo.json`
			## is a confusing way to have no cutscenes.
			if name.ends_with(".remap"):
				name = name.substr(0, name.length() - 6)
			if not name.ends_with(".json") or name == "index.json":
				continue
			seen[name.substr(0, name.length() - 5)] = true
	## A build with no cutscenes at all has no index, which is normal rather than
	## an error — `JSON.parse_string("")` logs a parse failure that reads like a
	## corrupt file and is not one.
	var index_text := FileAccess.get_file_as_string(INDEX)
	var index = JSON.parse_string(index_text) if index_text != "" else null
	if index is Dictionary:
		for id in (index as Dictionary).get("cutscenes", []):
			if ResourceLoader.exists(path_for(str(id))) \
					or FileAccess.file_exists(path_for(str(id))):
				seen[str(id)] = true
	var out: Array[String] = []
	for id in seen.keys():
		out.append(str(id))
	out.sort()
	return out


static func path_for(id: String) -> String:
	return "%s/%s.json" % [DIR, id]


## Load one, normalised. An empty dictionary means there is no such cutscene,
## which every caller treats as "play nothing" rather than as an error — a
## missing shot must never be able to take the camera away from the player.
static func load_scene(id: String) -> Dictionary:
	if id == "":
		return {}
	var text := FileAccess.get_file_as_string(path_for(id))
	if text == "":
		return {}
	var parsed = JSON.parse_string(text)
	if parsed is not Dictionary:
		return {}
	var scene := normalise(parsed as Dictionary)
	scene["id"] = id
	return scene


## Write it, and rewrite the index. Returns whether both landed — the caller
## says so on screen, because a SAVE that silently did not is how a morning's
## framing gets lost.
static func save_scene(id: String, scene: Dictionary) -> bool:
	if id == "":
		return false
	if not DirAccess.dir_exists_absolute(DIR):
		DirAccess.make_dir_recursive_absolute(DIR)
	var out := normalise(scene)
	out["id"] = id
	var file := FileAccess.open(path_for(id), FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(out, "  "))
	file.close()
	return write_index()


## The index, rebuilt from what is actually on disk. Never appended to, so a
## deleted cutscene leaves it on the next save rather than lingering forever.
static func write_index() -> bool:
	var ids: Array[String] = []
	if DirAccess.dir_exists_absolute(DIR):
		for file in DirAccess.get_files_at(DIR):
			var name := str(file)
			if not name.ends_with(".json") or name == "index.json":
				continue
			ids.append(name.substr(0, name.length() - 5))
	ids.sort()
	var file := FileAccess.open(INDEX, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify({"cutscenes": ids}, "  "))
	file.close()
	return true


static func delete_scene(id: String) -> bool:
	if id == "" or not FileAccess.file_exists(path_for(id)):
		return false
	if DirAccess.remove_absolute(ProjectSettings.globalize_path(path_for(id))) != OK:
		return false
	return write_index()


## A new scene, framed on the shipped gameplay camera at the deck's centre line.
## It opens where the game already is so the first thing the author does is move
## AWAY from a known pose rather than find one from nothing.
static func blank(id: String, focus: Vector2 = Vector2(0.0, 720.0)) -> Dictionary:
	var eye := shipped_eye(focus)
	var look := shipped_look(focus)
	return normalise({
		"id": id,
		"name": id.replace("_", " ").to_upper(),
		"cue": "",
		"keys": [
			{"t": 0.0, "eye": [eye.x, eye.y, eye.z], "look": [look.x, look.y, look.z],
				"fov": shipped_fov(), "roll": 0.0, "ease": "inout"},
			{"t": NEW_LENGTH, "eye": [eye.x, eye.y + 260.0, eye.z - 420.0],
				"look": [look.x, look.y, look.z - 200.0],
				"fov": shipped_fov(), "roll": 0.0, "ease": "inout"},
		],
	})


# ------------------------------------------------------------------- the cue --

## Which cutscene, if any, is wired to this moment. `wave` narrows `wave_start`;
## every other cue ignores it.
##
## First match wins and the ids are sorted, so two cutscenes claiming one cue is
## deterministic rather than a coin toss — and the harness names it as a
## warning rather than letting it be discovered mid-run.
static func for_cue(cue: String, wave: int = 0) -> String:
	if cue == "":
		return ""
	for id in list_ids():
		var scene := load_scene(id)
		if scene.is_empty() or str(scene.cue) != cue:
			continue
		if cue == "wave_start" and int(scene.wave) > 0 and int(scene.wave) != wave:
			continue
		return id
	return ""
