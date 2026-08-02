class_name SkyGearRig3D
extends Node3D

## An animated 3D character, driven by simulation state.
##
## The captain's first pass had her state machine written inline in the
## renderer: four `if`s picking a clip name, a yaw written straight onto the
## transform, and no notion of a clip finishing. That is enough for one
## character and wrong for two, and there are five boarders and a crew behind
## her waiting for the same treatment.
##
## What a character on this deck actually needs, none of which is specific to
## whose model it is:
##
##   * **Clips chosen by state, with priority.** A swing beats a dash beats a
##     run, because the one you most need to see is the one about to damage
##     something.
##   * **One-shots that end.** A swing plays once, holds its last frame, and
##     hands back to whatever was underneath when the simulation says the swing
##     is over — not when the clip happens to run out.
##   * **Turning, not snapping.** Writing a yaw straight from the aim vector
##     makes a figure spin on the spot at mouse speed. Real turns take time, and
##     a rate limit is the difference between a character and a cursor.
##   * **Speed-matched playback.** A run cycle authored at one speed slides on
##     the deck at any other. Scaling the clip's rate by actual speed over
##     authored speed is what stops the feet skating.
##   * **Reactions.** A hit flash, a squash on landing, a scale pop on spawn.
##     These are tweens on the visual only and must never touch the simulation.
##
## Everything here is presentation. It reads simulation state and writes to a
## mesh; nothing in this file may write back.

## What a figure can be doing, most urgent first. `pick()` walks this in order
## and takes the first that applies, so adding a state is adding a row.
const PRIORITY := ["die", "hurt", "swing", "dash", "run", "walk", "idle"]

## Clips that play once and hold rather than looping. A looping swing is a
## character having a fit.
const ONE_SHOT := {"swing": true, "dash": true, "hurt": true, "die": true}

## Attacks alternate. A melee pack ships four or five swings and the state
## machine only ever asks for one, so without this the captain performs the
## identical horizontal cut every time she casts anything — which reads worse
## than a billboard, because a billboard never claimed to be swinging.
##
## Named after the state, so `want("swing")` picks the next of whichever of
## these have actually been delivered.
const VARIANTS := {
	"swing": ["swing", "swing2", "swing3", "spin", "combo"],
}
var _variant := 0

## How long to crossfade into each state. A swing has to land NOW; an idle can
## ease. Zero would pop, and a quarter second on an attack is a quarter second
## of the player not knowing they pressed the button.
const BLEND := {
	"swing": 0.06, "dash": 0.05, "hurt": 0.05, "die": 0.10,
	"run": 0.14, "walk": 0.16, "idle": 0.22,
}

## Ground units per second the run cycle was authored at. Playback rate scales
## by actual speed over this, so the feet stop skating at any move-speed card.
const AUTHORED_RUN_SPEED := 210.0

## ONE-SHOTS ARE FITTED TO THE WINDOW THEY GET.
##
## Measured by `tools/anim_timing.gd`: a Cleave has a 0.36 second cooldown and
## the shortest swing in the pack is 2.27 seconds — thirteen times too long. The
## clip played its first eight per cent and cut back to idle, which is exactly
## what "the swing is not synced" looks like. Every attack in the game had the
## same problem because the animation pack was authored for a game with slower
## attacks, which is true of every animation pack.
##
## So a one-shot is told how long it has and plays at whatever rate fits. Capped,
## because past about four times a swing stops reading as a swing and starts
## reading as a glitch — beyond that the shortest variant is chosen instead and
## the tail is what gets lost, which is the right thing to lose.
const ATTACK_RATE_MAX := 4.0
const ATTACK_RATE_MIN := 0.75

## Radians per second the figure can turn. Fast enough to feel responsive,
## slow enough that a flicked mouse does not spin her like a top.
const TURN_RATE := 12.0

signal clip_finished(clip: String)

var model: Node3D                     ## the instantiated character scene
var anim: AnimationPlayer
var skeleton: Skeleton3D              ## found once at setup; null for a static lump
var height_scale := 1.0               ## model units -> our units
var fit_height := 0.0                 ## the world height (metres) setup was asked for
var facing := 0.0                     ## radians, current
var target_facing := 0.0              ## radians, wanted
var state := "idle"
var _clip := ""
var _one_shot_until := 0.0
var _clock := 0.0
var _flash := 0.0
var _squash := 0.0
var _base_scale := Vector3.ONE
var _missing := false


## Build from an ingested model. Returns false if it is not on disk, so a caller
## can fall back to a billboard rather than showing nothing.
func setup(scene_path: String, target_height: float, layer: int) -> bool:
	if _missing:
		return false
	if not ResourceLoader.exists(scene_path):
		_missing = true
		return false
	var packed := load(scene_path) as PackedScene
	if packed == null:
		_missing = true
		return false
	## A HOLDER, and the scene inside it untouched. FBX measures in centimetres,
	## so the importer bakes a unit scale into the root — and writing a transform
	## onto that root, which is what a naive placement does, removes it. The
	## captain rendered at one hundredth of a metre and could not be found.
	model = packed.instantiate()
	add_child(model)
	anim = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	for child in model.find_children("*", "Skeleton3D", true, false):
		skeleton = child as Skeleton3D
	fit_height = target_height
	var measured: float = float(model.get_meta("model_height", 0.0))
	if measured <= 0.0:
		for child in model.find_children("*", "MeshInstance3D", true, false):
			var mi := child as MeshInstance3D
			measured = maxf(measured, mi.get_aabb().size.y
				* mi.global_transform.basis.get_scale().y)
	height_scale = target_height / maxf(0.0001, measured)
	for child in model.find_children("*", "MeshInstance3D", true, false):
		(child as MeshInstance3D).layers = layer
	_base_scale = Vector3(height_scale, height_scale, height_scale)
	scale = _base_scale
	return true


## Put something in her hand.
##
## A `BoneAttachment3D` rather than a transform written every frame: the skeleton
## already solves the hand's position for whatever clip is playing, and reading
## that solution is both cheaper and correct during blends — a hand-written
## follow lags by exactly one frame, which on a 0.3s swing is visible.
##
## The fit comes from `assets/models/weapons.json` so it can be nudged without a
## build. See `tools/weapon_fit.gd`.
## `length_m` and `offset` are both in METRES OF WORLD, which is the only frame a
## human can hold in their head. Bone space is not: the rig stands 1.8 m tall from
## a model 0.018 units tall, so the skeleton carries a scale of about a hundred
## and an innocent 4 cm offset written in bone space puts the sword four metres
## away. The compensation is measured off the mount once it is in the tree rather
## than assumed, because the FBX root carries a unit scale of its own.
func hold(weapon_scene: String, bone: String, offset: Vector3, rotation_deg: Vector3,
		length_m: float, layer: int) -> bool:
	if held != null:
		held.queue_free()
		held = null
	if model == null or not ResourceLoader.exists(weapon_scene):
		return false
	if skeleton == null:
		return false
	var index := skeleton.find_bone(bone)
	if index < 0:
		return false
	var mount := BoneAttachment3D.new()
	mount.bone_name = bone
	mount.bone_idx = index
	skeleton.add_child(mount)
	held = mount

	var packed := load(weapon_scene) as PackedScene
	if packed == null:
		return false
	## Same holder rule as the rig itself: the imported root carries a unit scale
	## and writing a transform onto it throws that away.
	var weapon := packed.instantiate()
	var holder := Node3D.new()
	holder.add_child(weapon)
	mount.add_child(holder)
	## The skeleton is already inside the rig's height scale, and the bone pose is
	## in the model's own units — so the weapon inherits both and the only thing
	## left to say is how much bigger or smaller than "one model unit" it should
	## read.
	## What one bone-space unit is worth in metres, measured.
	var at_bone: Vector3 = mount.global_transform.basis.get_scale()
	var per_unit: float = maxf(0.0001, (at_bone.x + at_bone.y + at_bone.z) / 3.0)

	## And how long the weapon is in its own units, so `length_m` can mean what it
	## says whatever the generator happened to export at.
	var span := 0.0
	for child in weapon.find_children("*", "MeshInstance3D", true, false):
		var box: AABB = (child as MeshInstance3D).get_aabb()
		span = maxf(span, maxf(box.size.x, maxf(box.size.y, box.size.z)))
	if span <= 0.0:
		span = 1.0

	holder.scale = Vector3.ONE * (maxf(0.01, length_m) / (span * per_unit))
	holder.position = offset / per_unit
	holder.rotation = Vector3(deg_to_rad(rotation_deg.x), deg_to_rad(rotation_deg.y),
		deg_to_rad(rotation_deg.z))
	## Where the business end of this blade is, in the MOUNT's own space, measured
	## once while everything is placed — the weapon trail (SG-18) reads it back
	## every frame through the swing, and mount space is the one frame in which a
	## rigid tip never moves whatever clip is playing. The tip is simply the point
	## of the weapon's geometry furthest from the hand, which is what "tip" means
	## for a cutlass, a wrench and anything else a generator returns.
	var far := mount.global_position
	var far_d := -1.0
	for child in weapon.find_children("*", "MeshInstance3D", true, false):
		var box: AABB = (child as MeshInstance3D).get_aabb()
		for corner in 8:
			var at: Vector3 = (child as MeshInstance3D).global_transform \
				* box.get_endpoint(corner)
			var d := at.distance_squared_to(mount.global_position)
			if d > far_d:
				far_d = d
				far = at
	mount.set_meta("blade_tip", mount.global_transform.affine_inverse() * far)
	for child in weapon.find_children("*", "MeshInstance3D", true, false):
		var mi := child as MeshInstance3D
		mi.layers = layer
		## She is lit by the deck lamps; so is what she is carrying, or a steel
		## blade reads as a cardboard cut-out the moment she turns.
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return true


## The hand bones the trail can hang off, most specific first. The captain's fit
## names `mixamorig_RightHand` in `weapons.json`; the Boilerwright's retargeted
## rig carries the same family. The suffix scan is the fallback for whatever the
## next exporter renames the prefix to.
const HAND_BONES := ["mixamorig_RightHand", "mixamorig:RightHand", "RightHand"]


## A mount on the hand even when the hand is EMPTY — the Boilerwright's case,
## whose tool is a separate unpriced asset (board SG-38). The weapon trail
## (SG-18) needs a bone-solved point to sample whichever class is swinging, and
## an empty fist still cuts an arc. Reuses `held`, so a later `hold()` replaces
## it cleanly and a figure never carries two mounts.
func mount_hand() -> bool:
	if held != null and is_instance_valid(held):
		return true
	if skeleton == null:
		return false
	var index := -1
	var bone := ""
	for name in HAND_BONES:
		index = skeleton.find_bone(str(name))
		if index >= 0:
			bone = str(name)
			break
	if index < 0:
		for i in skeleton.get_bone_count():
			if skeleton.get_bone_name(i).ends_with("RightHand"):
				index = i
				bone = skeleton.get_bone_name(i)
				break
	if index < 0:
		return false
	var mount := BoneAttachment3D.new()
	mount.bone_name = bone
	mount.bone_idx = index
	skeleton.add_child(mount)
	held = mount
	return true


## Both ends of what the hand is swinging, in WORLD space (metres): [base, tip].
## The base is the hand itself; the tip is the measured blade point when a
## weapon is held, and a knuckle's reach along the hand bone when it is not —
## mixamo hands run +Y toward the fingers. Empty when there is no mount, so a
## caller can fall back to the effect-clock sweep rather than drawing nothing.
##
## The transform comes off the SKELETON, not off the attachment node: the
## engine refreshes a `BoneAttachment3D`'s own transform on the next frame's
## skeleton pass, and a trail sampled through it would trail the pose by one
## frame — the exact lag the mount exists to avoid (see `hold`'s header).
## `get_bone_global_pose` reads the solved pose the moment it is asked.
func blade_points() -> PackedVector3Array:
	if held == null or not is_instance_valid(held) or not held.is_inside_tree():
		return PackedVector3Array()
	var at := _mount_transform()
	var base: Vector3 = at.origin
	var tip: Vector3
	if held.has_meta("blade_tip"):
		tip = at * Vector3(held.get_meta("blade_tip"))
	else:
		var along: Vector3 = at.basis.y
		along = along.normalized() if along.length_squared() > 1e-12 else Vector3.UP
		tip = base + along * maxf(0.2, fit_height * 0.34)
	return PackedVector3Array([base, tip])


## The hand bone's world transform, solved NOW. Falls back to the attachment
## node's own (frame-late) transform if the bone index ever goes missing.
func _mount_transform() -> Transform3D:
	if skeleton != null and held is BoneAttachment3D:
		var idx: int = (held as BoneAttachment3D).bone_idx
		if idx >= 0:
			return skeleton.global_transform * skeleton.get_bone_global_pose(idx)
	return held.global_transform


## Read the fit table once. Returns {} when there is nothing to hold, which is
## the normal case for every figure that is not the captain.
static func weapon_fit(who: String) -> Dictionary:
	if not ResourceLoader.exists(WEAPON_TABLE):
		return {}
	var text := FileAccess.get_file_as_string(WEAPON_TABLE)
	var parsed = JSON.parse_string(text)
	if parsed is not Dictionary or not parsed.has(who):
		return {}
	var fit: Dictionary = parsed[who]
	var weapons: Dictionary = parsed.get("weapons", {})
	var key := str(fit.get("weapon", ""))
	if not weapons.has(key):
		return {}
	fit = fit.duplicate()
	fit["path"] = str((weapons[key] as Dictionary).get("path", ""))
	return fit


const WEAPON_TABLE := "res://assets/models/weapons.json"
var held: BoneAttachment3D = null


func has_clip(clip: String) -> bool:
	return anim != null and anim.has_animation(clip)


## Ask for a state. Idempotent — call it every frame with whatever the
## simulation says and it only acts when something changed.
## Is she travelling backwards relative to the way she is facing? Set by
## `place`, read by `want` on the next frame, because the renderer knows the
## heading and the simulation knows the velocity and they meet here.
var _reverse := false

## How far the body is allowed to lead the aim when strafing, in radians. There
## is no strafe clip in the pack, so a pure sideways walk has no honest cycle;
## letting the shoulders turn part of the way into the movement buys a diagonal
## that `run` can actually sell. Not all the way, or she stops facing her cursor
## and the Cleave lands somewhere the player did not point.
const LEAN_MAX := 0.62


func want(next: String, speed: float = 0.0, window: float = 0.0) -> void:
	if anim == null:
		return
	## A one-shot owns the figure until its own timer runs out, unless something
	## higher up the list interrupts it. Without this a swing is cancelled on the
	## next frame by the run that is still true underneath it.
	if _clock < _one_shot_until and PRIORITY.find(next) > PRIORITY.find(state):
		next = state
	## A new one-shot picks the next variant; holding the same state keeps the
	## clip it is already playing, or an attack would reshuffle every frame.
	var starting: bool = next != state
	state = next
	var clip := _variant_of(next, window) if starting else _clip
	if clip == "" or not has_clip(clip):
		clip = next if has_clip(next) else _fallback(next)
	if clip == "":
		return
	## A one-shot RESTARTS whenever it is newly asked for, even when the clip that
	## came up is the one already playing. Skipping the replay because the name
	## matched meant casting the same skill twice in a row played the swing once:
	## the second cast found `clip == _clip`, did not seek back, and did not
	## extend the window — so the animation ended mid-attack and she stood still
	## through the rest of it.
	if clip != _clip or (starting and ONE_SHOT.get(next, false)):
		anim.play(clip, float(BLEND.get(next, 0.15)))
		if starting and ONE_SHOT.get(next, false):
			anim.seek(0.0, true)
		_clip = clip
		if ONE_SHOT.get(next, false):
			## The window, not the clip length: a swing owns the figure for as
			## long as the SKILL takes, and the clip is stretched or compressed
			## to match. Using the clip length here is what let a 2.4 second
			## animation block a 0.36 second attack.
			_one_shot_until = _clock + (window if window > 0.0
				else anim.get_animation(clip).length)
	elif not anim.is_playing():
		anim.play(clip)
	## Speed-matched playback. A run authored for 210 units a second played by
	## someone moving at 300 is a figure skating; the cycle has to keep up with
	## the ground it is covering.
	if next == "run" or next == "walk":
		## And BACKWARDS when she is going backwards. She faces her cursor, not
		## her movement — that is deliberate, because aim is what the Cleave uses
		## — so half the time she is travelling away from the way she is pointed
		## while a forward run cycle plays. That is the ice-skating: feet driving
		## one way, body going the other. `run_back` was in the pack from the
		## first ingest and nothing ever asked for it.
		if _reverse and has_clip("run_back") and _clip != "run_back":
			anim.play("run_back", 0.12)
			_clip = "run_back"
		elif not _reverse and _clip == "run_back" and has_clip(clip):
			anim.play(clip, 0.12)
			_clip = clip
		anim.speed_scale = clampf(speed / AUTHORED_RUN_SPEED, 0.55, 1.9)
	elif ONE_SHOT.get(next, false) and window > 0.0 and has_clip(clip):
		anim.speed_scale = clampf(anim.get_animation(clip).length / window,
			ATTACK_RATE_MIN, ATTACK_RATE_MAX)
	else:
		anim.speed_scale = 1.0


## Nearest usable clip when the wanted one has not been delivered. Walking is a
## slow run; a hurt is a very short idle; anything else falls to idle.
## The next delivered variant of a state, round robin. Falls back to the state
## itself when no variants exist, which is every state but the attack.
func _variant_of(next: String, window: float = 0.0) -> String:
	var options: Array = VARIANTS.get(next, [])
	var live: Array[String] = []
	for name in options:
		if has_clip(str(name)):
			live.append(str(name))
	if live.is_empty():
		return next
	## When the window is tight, only the variants that can actually be played
	## inside it at the maximum rate are candidates. Rotating a 4.7 second combo
	## into a 0.36 second attack shows a twelfth of it, which is not a variation,
	## it is a different bug every fifth cast.
	if window > 0.0:
		var fits: Array[String] = []
		for name in live:
			if anim.get_animation(name).length <= window * ATTACK_RATE_MAX:
				fits.append(name)
		if not fits.is_empty():
			live = fits
		else:
			## Nothing fits: take the shortest rather than whatever is next.
			var best := live[0]
			for name in live:
				if anim.get_animation(name).length < anim.get_animation(best).length:
					best = name
			return best
	_variant = (_variant + 1) % live.size()
	return live[_variant]


func _fallback(next: String) -> String:
	match next:
		"run":
			return "walk" if has_clip("walk") else _or_idle()
		"walk":
			return "run" if has_clip("run") else _or_idle()
		"dash":
			return "run" if has_clip("run") else _or_idle()
		_:
			return _or_idle()


func _or_idle() -> String:
	if has_clip("idle"):
		return "idle"
	if anim != null and not anim.get_animation_list().is_empty():
		return anim.get_animation_list()[0]
	return ""


## Where the figure is standing and which way it is trying to face. Position is
## exact; facing is a rate-limited turn.
func place(ground: Vector2, heading: Vector2, world_scale: float, delta: float,
		travel: Vector2 = Vector2.ZERO) -> void:
	## Lean into the direction of travel, up to a limit. Without this a strafe is
	## a forward run cycle sliding sideways, which is the single loudest source of
	## "she is ice skating" — the feet have no relationship to the ground.
	_reverse = false
	if travel.length_squared() > 400.0 and heading.length_squared() > 0.0001:
		var forward := heading.normalized()
		var going := travel.normalized()
		var dot := forward.dot(going)
		_reverse = dot < -0.35
		if not _reverse:
			var offset := wrapf(atan2(going.x, going.y) - atan2(forward.x, forward.y),
				-PI, PI)
			heading = forward.rotated(-clampf(offset, -LEAN_MAX, LEAN_MAX))
	if heading.length_squared() > 0.0001:
		## `atan2(x, y)` rather than the usual `atan2(y, x)`: a yaw of zero looks
		## down +Z, which is where an ingested rig faces at rest.
		target_facing = atan2(heading.x, heading.y)
	facing = _turn_toward(facing, target_facing, TURN_RATE * delta)
	var basis := Basis(Vector3(0, 1, 0), facing)
	## Reactions ride on the scale, so they cannot disturb where she is standing
	## or which way she is looking.
	var squash := 1.0 - _squash * 0.22
	basis = basis.scaled(_base_scale * Vector3(1.0 / maxf(0.4, squash), squash, 1.0 / maxf(0.4, squash)))
	transform = Transform3D(basis, Vector3(ground.x * world_scale, 0.0, ground.y * world_scale))


## Shortest-way-round, rate limited. Lerping raw angles takes the long way round
## whenever a turn crosses PI, which looks like a figure spinning to avoid you.
static func _turn_toward(from: float, to: float, step: float) -> float:
	var difference := wrapf(to - from, -PI, PI)
	if absf(difference) <= step:
		return to
	return from + signf(difference) * step


## A hit. White for a moment, and a squash that recovers — both purely visual.
func react_hit(strength: float = 1.0) -> void:
	_flash = clampf(strength, 0.0, 1.0)
	_squash = maxf(_squash, 0.6 * clampf(strength, 0.0, 1.0))


func react_land() -> void:
	_squash = maxf(_squash, 0.85)


func _process(delta: float) -> void:
	_clock += delta
	## Tweened by hand rather than with a Tween node: these fire several times a
	## second in a fight, and a Tween allocation per hit is a Tween allocation
	## per hit. Exponential decay is frame-rate independent and free.
	_flash = maxf(0.0, _flash - delta * 5.5)
	_squash = _squash * exp(-delta * 9.0)
	if _squash < 0.002:
		_squash = 0.0
	if model != null and _flash > 0.0:
		for child in model.find_children("*", "MeshInstance3D", true, false):
			var mi := child as MeshInstance3D
			mi.set_instance_shader_parameter("flash", _flash)
	if anim != null and _clip != "" and _clock >= _one_shot_until \
			and ONE_SHOT.get(state, false) and _one_shot_until > 0.0:
		_one_shot_until = 0.0
		clip_finished.emit(_clip)
