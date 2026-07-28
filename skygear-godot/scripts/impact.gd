class_name SkyGearImpact
extends Node

## Hit-stop, screen shake, and the pools that keep them from becoming the
## performance problem they are famous for.
##
## VFX-PLAN.md ranks the work by whether a player can answer a question faster
## with it. This is the top of that list and the cheapest thing on it: *did my
## hit land, and how hard*. The browser has `hitStop` and shake; the port had
## neither, which is most of why the same fight feels softer here.
##
## Three rules, all learned the expensive way in the browser build:
##
##   1. **Hit-stop is feedback, not decoration.** A big hit always lands. Small
##      ones respect a refractory window, or clearing a horde leaves the
##      simulation frozen a large fraction of the time.
##   2. **Shake is ADDITIVE to the sway**, never a replacement for it. Two
##      systems both writing the camera transform is two systems fighting.
##   3. **Everything is pooled and capped.** Every performance problem this
##      project has had — the browser's audio nodes, its uncapped effect list,
##      its 200-million-call health bar — was an unbounded collection.

## Seconds. Straight from the browser's `TUNING.feel`.
const STOP_KILL := 0.070
const STOP_BIG := 0.040
const STOP_THRESHOLD := 34.0      ## damage that counts as big
const STOP_REFRACTORY := 0.16     ## small hits wait this long between stops
const STOP_MAX := 0.12            ## nothing freezes longer than this

## Shake decays exponentially rather than linearly: a linear fade reads as the
## camera being dragged back, an exponential one as it settling.
const SHAKE_DECAY := 7.5
const SHAKE_MAX := 22.0           ## ground units, so a keg cannot throw the deck

## Off for the harness. Hit-stop hands the simulation a smaller delta, so a test
## that advances three seconds and kills things would actually advance less than
## three — every timing check in the harness would become a function of how many
## boarders happened to die, which is not a test.
var enabled := true
var stop_left := 0.0
var shake := 0.0
var _stop_until := 0.0
var _clock := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()


## Freeze the simulation for `seconds`. Returns whether it took, so the harness
## can assert the refractory rule rather than infer it.
func hit_stop(seconds: float) -> bool:
	if seconds <= 0.0:
		return false
	## A big hit always lands. Small ones are rate limited, because a Field
	## ticking into six boarders is six stops a second and that is not feedback,
	## it is a frame rate problem with a reason.
	if seconds < 0.06 and _clock < _stop_until:
		return false
	stop_left = minf(STOP_MAX, maxf(stop_left, seconds))
	_stop_until = _clock + STOP_REFRACTORY
	return true


func add_shake(amount: float) -> void:
	shake = minf(SHAKE_MAX, shake + amount)


## What a hit of this size does. One place, so a keg, a crit and a cannon cannot
## disagree about what counts as big.
func note_hit(damage: float, killed: bool) -> void:
	if killed:
		hit_stop(STOP_KILL)
		add_shake(3.2)
	elif damage >= STOP_THRESHOLD:
		hit_stop(STOP_BIG)
		add_shake(2.0)
	else:
		add_shake(0.5 + damage * 0.03)


func note_explosion(power: float) -> void:
	hit_stop(STOP_BIG)
	add_shake(clampf(power, 4.0, 14.0))


## The camera offset this frame, in ground units. Added to wherever the camera
## already is, never assigned over it.
func shake_offset() -> Vector2:
	if shake <= 0.01:
		return Vector2.ZERO
	## Two frequencies so it does not read as a single sine, and the vertical
	## component is smaller because a deck that heaves reads as a bug.
	return Vector2(
		sin(_clock * 71.0) * shake + _rng.randf_range(-0.4, 0.4) * shake,
		sin(_clock * 53.0 + 1.7) * shake * 0.55)


## Advance, and report how much simulation time the rest of the game should run.
##
## Called with the real frame delta; returns the delta the simulation should use.
## Hit-stop is the ONLY thing in this project that scales time, and it does it
## here rather than by touching `Engine.time_scale` — a global time scale also
## slows the animation blends, the music and the voice, which is not a hit
## landing, it is the game skipping.
func advance(delta: float) -> float:
	_clock += delta
	if not enabled:
		shake = 0.0
		stop_left = 0.0
		return delta
	shake = shake * exp(-delta * SHAKE_DECAY)
	if shake < 0.02:
		shake = 0.0
	if stop_left <= 0.0:
		return delta
	stop_left -= delta
	if stop_left > 0.0:
		return 0.0
	## The frame the stop ends on runs the remainder, so a stop costs exactly its
	## own length rather than its length rounded up to a frame.
	return -stop_left


func reset() -> void:
	stop_left = 0.0
	shake = 0.0
	_stop_until = 0.0
