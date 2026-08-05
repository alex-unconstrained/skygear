class_name SkyGearPlayer
extends CharacterBody2D

signal dash_started

const MAX_HP := 100.0
const SPEED := 260.0
## Reaching full speed in 0.084s and stopping in 0.096s already sounds crisp on
## paper, and the report was still "like the protagonist is ice skating". The
## rest of the fix is in the rig — the wrong cycle for the direction of travel —
## but stopping wants to be sharper than starting regardless: a player releasing
## a key has decided to stop, and a body that keeps going is a body that ignored
## them. Starting soft and stopping hard is the shape almost every action game
## uses, and this had them nearly equal.
const ACCEL := 3400.0
## 5200 was an over-correction and it cost the game its pace. Reported straight
## back: "the removal of the skating makes the game feel slower."
##
## The skating was three things and only two of them were the slide. The wrong
## animation cycle and the third-of-a-second post-dash glide were real bugs and
## stay fixed. Braking in 0.05s was me fixing a fourth thing that was not broken
## — a stop that instant reads as walking into glue, and every step costs the
## distance the old brake used to carry you.
##
## 3600 stops in 0.072s against 0.096s before: still crisper than it was, no
## longer a wall.
const FRICTION := 3600.0
## And the dash covers more ground, because the OLD dash effectively did — it
## travelled 220 and then glided for another third of a second. Removing the
## glide without lengthening the dash took real distance out of the move.
const DASH_DISTANCE := 265.0
const DASH_TIME := 0.16
## What a dash hands back when it ends, as a multiple of walking speed. The bug
## was exiting at 1375 and decaying for 0.36s with no control; the over-fix was
## exiting at exactly walking speed, which stops a dash dead the frame it ends.
## 1.55 decays back in about 0.08s — you feel the landing, you do not skate.
const DASH_EXIT := 1.55
const DASH_SPEED := DASH_DISTANCE / DASH_TIME
## SEA LEGS shortens this. A const cannot be the answer once a talent moves it —
## the same lesson as `SPEED` and `START_DASH_CHARGES`, learned three times now.
const DASH_RECHARGE := 1.0
var dash_recharge_bonus := 0.0


func dash_recharge_time() -> float:
	return maxf(0.25, DASH_RECHARGE + dash_recharge_bonus)
## The STARTING number. The ceiling is `max_dash_charges`, which the draft can
## raise — `cards.gd` has an epic that sets `mods.dash_charges` to 3 and nothing
## read it, so the card was purchasable and did nothing. A const used as a
## ceiling is a const that quietly outranks the upgrade system.
const START_DASH_CHARGES := 2

var game: Node
var hp := MAX_HP
var max_hp := MAX_HP
var pressure := 0.0
var aim_direction := Vector2.UP
var controls_enabled := false
## The class sets this. `SPEED` stays as the default and as the number the
## animation's authored pace is measured against, but a const cannot be the
## answer when two captains move at different speeds.
var move_speed := SPEED
var dash_charges := START_DASH_CHARGES
var max_dash_charges := START_DASH_CHARGES
var dash_recharge_left := 0.0
var dash_time_left := 0.0
var _dash_speed := 0.0
## How long she is still mid-swing, for the renderer. A cast is instantaneous in
## the simulation and has to last long enough to be a picture — the attack view
## and the swing cycle both key off this, and without it she casts six times a
## second while standing perfectly still.
var attack_time := 0.0
## How long she is still reacting to being hit. The melee pack ships a proper
## flinch and the state machine had nothing to trigger it with.
var hurt_time := 0.0
var dash_direction := Vector2.UP
var invulnerability_left := 0.0
var dash_serial := 0

func _ready() -> void:
	queue_redraw()

func reset_for_run() -> void:
	hp = MAX_HP
	max_hp = MAX_HP
	pressure = 0.0
	dash_charges = max_dash_charges
	dash_recharge_left = 0.0
	dash_time_left = 0.0
	attack_time = 0.0
	hurt_time = 0.0
	invulnerability_left = 0.0
	velocity = Vector2.ZERO
	global_position = Vector2(0, 720)
	queue_redraw()

func _physics_process(delta: float) -> void:
	if game == null:
		return
	invulnerability_left = maxf(0.0, invulnerability_left - delta)
	_update_dash_recharge(delta)
	_update_aim()

	if not controls_enabled:
		velocity = velocity.move_toward(Vector2.ZERO, FRICTION * delta)
		move_and_slide()
		return

	attack_time = maxf(0.0, attack_time - delta)
	hurt_time = maxf(0.0, hurt_time - delta)
	if dash_time_left > 0.0:
		dash_time_left -= delta
		## From the distance the MOVE asked for, not the captain's constant — a
		## Bleed Jet that travelled her 220-over-0.16 would be her dash with a
		## different name.
		velocity = dash_direction * (_dash_speed if _dash_speed > 0.0 else DASH_SPEED)
		invulnerability_left = maxf(invulnerability_left, 0.08)
		## The frame the dash ENDS, drop to running speed rather than decaying
		## from 1375 down to 260 at the normal rate. That decay is a third of a
		## second of gliding at up to five times walking pace with no control
		## authority, after every dash, and it is most of what "slippery" means
		## here. Keep the direction, lose the excess.
		if dash_time_left <= 0.0:
			velocity = dash_direction * move_speed * DASH_EXIT
	else:
		var input_direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		var combat_scale: float = game.combat_move_scale() \
			if game.has_method("combat_move_scale") else 1.0
		var target_velocity: Vector2 = input_direction * move_speed * combat_scale
		var rate := ACCEL if input_direction.length_squared() > 0.0 else FRICTION
		velocity = velocity.move_toward(target_velocity, rate * delta)
		if Input.is_action_just_pressed("dash"):
			## One key, two moves. Hers spends a charge; his spends the bank and
			## leaves the lane scalding. The class decides which, so neither has
			## to know the other exists.
			if game != null and game.has_method("bleed_jet") 					and not (game.class_data().get("jet", {}) as Dictionary).is_empty():
				game.bleed_jet(input_direction)
			else:
				_try_dash(input_direction)

	move_and_slide()
	global_position = game.correct_player_position(global_position, 17.0)
	queue_redraw()

func _update_aim() -> void:
	## Through the game, not through the 2D viewport: the visible scene is a 3D
	## projection and the 2D mouse position is an answer about a hidden space.
	var aim_at: Vector2 = game.aim_target() if game != null else get_global_mouse_position()
	var mouse_delta := aim_at - global_position
	if mouse_delta.length_squared() > 4.0:
		aim_direction = mouse_delta.normalized()
		$Sprite.flip_h = aim_direction.x < 0.0

## A move with no charge behind it. The Boilerwright's Bleed Jet pays in gauge
## rather than in charges, so it cannot go through `_try_dash` — that function's
## first line is a charge check, and he never has one.
func jet(direction: Vector2, distance: float, time: float) -> void:
	dash_direction = direction.normalized()
	_dash_speed = distance / maxf(0.01, time)
	dash_time_left = time
	dash_serial += 1
	## Briefly untouchable, same as a dash: the move is a dodge or it is nothing.
	invulnerability_left = time + 0.08
	dash_started.emit()


func _try_dash(move_direction: Vector2) -> void:
	if dash_charges <= 0:
		return
	dash_direction = move_direction.normalized() if move_direction.length_squared() > 0.0 else aim_direction
	if dash_direction.length_squared() == 0.0:
		dash_direction = Vector2.UP
	dash_charges -= 1
	_dash_speed = DASH_SPEED
	dash_time_left = DASH_TIME
	dash_serial += 1
	invulnerability_left = DASH_TIME + 0.08
	if dash_recharge_left <= 0.0:
		dash_recharge_left = dash_recharge_time()
	dash_started.emit()

func _update_dash_recharge(delta: float) -> void:
	if dash_charges >= max_dash_charges:
		dash_recharge_left = 0.0
		return
	dash_recharge_left -= delta
	if dash_recharge_left <= 0.0:
		dash_charges += 1
		dash_recharge_left = dash_recharge_time() if dash_charges < max_dash_charges else 0.0

func refund_dash(seconds: float) -> void:
	if dash_charges < max_dash_charges:
		dash_recharge_left = maxf(0.0, dash_recharge_left - seconds)

## `grants_invuln` defaults TRUE, so every discrete hit — a swing, a bolt, a keg
## — keeps exactly the behaviour it has always had. Periodic sources pass FALSE
## (SG-117).
##
## The i-frames are still CHECKED whatever the source: a hazard tick cannot land
## on a captain who is mid-dash or who just ate a swing. What changes is that a
## hazard tick no longer *grants* them. That asymmetry is the whole fix, and it
## is the right way round: the 0.55 s window exists so a single swing cannot be
## double-counted and so a hit reads as one hit, and a fire pool ticking four
## times a second was minting that window continuously. A captain standing in
## fire was therefore immune to EVERYTHING — `invulnerability_left` is one
## global variable, not a per-source one — for 0.55 of every 0.75 s, about 73%
## of the time, a boarder's 26-damage swing included. The safest place on the
## deck was inside the fire.
func take_damage(amount: float, grants_invuln: bool = true) -> bool:
	if amount <= 0.0 or invulnerability_left > 0.0 or hp <= 0.0:
		return false
	hp = maxf(0.0, hp - amount)
	if grants_invuln:
		invulnerability_left = 0.55
	queue_redraw()
	return true

func heal(amount: float) -> float:
	var before := hp
	hp = minf(max_hp, hp + maxf(0.0, amount))
	queue_redraw()
	return hp - before

func set_pressure(value: float) -> void:
	pressure = clampf(value, 0.0, 100.0)
	queue_redraw()

func _draw() -> void:
	draw_arc(Vector2.ZERO, 27.0, -PI * 0.5, -PI * 0.5 + TAU * pressure / 100.0, 48, Color("#e8c376"), 4.0)
	if invulnerability_left > 0.0:
		draw_arc(Vector2.ZERO, 31.0, 0.0, TAU, 40, Color(0.9, 0.95, 1.0, 0.48), 2.0)

