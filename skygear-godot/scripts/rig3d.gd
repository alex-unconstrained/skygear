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
var height_scale := 1.0               ## model units -> our units
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


func has_clip(clip: String) -> bool:
	return anim != null and anim.has_animation(clip)


## Ask for a state. Idempotent — call it every frame with whatever the
## simulation says and it only acts when something changed.
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
func place(ground: Vector2, heading: Vector2, world_scale: float, delta: float) -> void:
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
