class_name SkyGearEnemy
extends CharacterBody2D

var game: Node
var kind := "SCRAPPER"
## HOW HARD THIS IS TO SHOVE. Was a local inside `take_damage`, so knockback knew
## about it and nothing else could — Keel Hauling read `enemy.mass`, got a null,
## and towed a Colossus at the same rate as a gremlin.
var mass := 1.0
var lane := 1
var config: Dictionary
var hp := 1.0
var max_hp := 1.0
var radius := 22.0
var state := "climb"
var state_time := 0.8
var attack_direction := Vector2.DOWN
var dead := false
## HOW HARD A SHOVE CAN EVER BE.
##
## `knock_velocity` ACCUMULATED with nothing bounding it, and decays at only
## 1050 a second — so any skill that hits more than once before that decay runs
## out stacks shove on top of shove. A beam, an aura ticking, a chain touching
## four boarders: each tick added its full `knock / mass` again. Reported as
## boarders "suddenly thrown right next to the boiler", and the arithmetic
## agrees — at 3000 a second the travel before it decays is about 4,300 units
## down a deck that is 2,320 long.
##
## Capped, a full shove carries about 386 units. That is a real displacement you
## can feel and use, and it is a sixth of the deck rather than all of it.
const KNOCK_MAX := 900.0

## And how hard it has to be to put someone over the rail. Well above a single
## hit from anything — going overboard should be something you SET UP, with a
## heavy shape or a stacked pair, not a thing that happens by accident to
## whoever is standing nearest the edge.
const OVERBOARD_SPEED := 520.0

## HOW FAR A SHOVE CAN EVER CARRY — in GROUND, not velocity. The July-31 cap
## bounded `knock_velocity` and asserted the distance it implies analytically
## (v²/2a = 386), but never measured the enemy's own frame. The frame betrayed
## it: `velocity += knock_velocity` folded the capped shove into the WALK
## velocity, and the walk lerp only bleeds ~10% a frame — so the shove was
## integrated a second time with a ninefold gain. Measured: ONE capped hit on
## a moving boarder carried 1,338 units, mid-deck to the stern wall, straight
## past the Boiler (board SG-62, the owner's "game breaking"). The walk keeps
## only the walk now (see the bottom of `_physics_process`), and this cap is
## POSITIONAL — anchored where the shove began, enforced after the move, so no
## stack of multipliers and no future integration slip can carry past it.
const KNOCK_TRAVEL_MAX := 390.0

## THE STERN LINE. Knockback may STOP a boarder; it may never DELIVER one.
## Spawn is at the bow (y = -1115), the Boiler at the stern (y = +850), so a
## hit taken from the bow side points `away` stern-ward — which made hitting a
## boarding party from behind the fastest way to hand it to the Boiler. While
## a shove is live, a boarder may not end a frame more than this many units
## stern-ward of where the shove began. Sideways and bow-ward stay free: the
## rail kill and pushing them back the way they came are the point of knockback.
const KNOCK_STERN_GIVE := 60.0

var knock_velocity := Vector2.ZERO
## Where the live shove began — the anchor `KNOCK_TRAVEL_MAX` and
## `KNOCK_STERN_GIVE` measure from. A hit landing while a shove is already
## live keeps the OLD anchor, so chained hits cannot ratchet the line forward;
## the anchor releases only when the shove has fully decayed.
var knock_anchor := Vector2.ZERO
var knock_live := false
## Past the rail and no longer the lane's problem. Kept as state rather than
## resolved on the spot because the clamp has to STOP running for them, and a
## boarder mid-fall is briefly outside every rule the deck has.
var overboard := false
var slow_time := 0.0
var slow_amount := 0.0
var stun_time := 0.0
var burn_time := 0.0
var burn_stacks := 0
var burn_tick := 0.25
var spawn_serial := 0
## The Colossus fights in two beats and the turn between them is a real moment:
## it cannot be burst through, it clears what it called, and the second beat
## reaches the whole deck. A phase change you can skip is not a phase change.
var beat := 0
var turn_time := 0.0

## How long that turn holds. It was a literal at the one place it is assigned,
## which is fine until something outside the simulation needs to know how long
## the beat lasts — and something does now: the segmented Colossus plays a
## `turn` clip through it (board SG-90), and a one-shot in `scripts/rig3d.gd` is
## fitted to the WINDOW it is given. Reading `turn_time` itself would not do, on
## the SG-85 lesson: it counts DOWN, and a window that shrinks every frame is a
## clip that accelerates as it plays. Same number, named once.
const TURN_TIME := 1.6

func _windup_scale() -> float:
	if game == null or not ("heat" in game):
		return 1.0
	return SkyGearWorkshop.windup_for(int(game.heat))


## DOES THE SWING LAND — and the answer is the shape that was DRAWN.
##
## Board SG-3 made the reach one number instead of two: the wedge is drawn at
## `config.reach` and the sim connects at `config.reach + target_radius`. But it
## only ever unified the RADIUS. The connect test stayed a bare
## `distance_to(...) <= swing_reach` — a full 360° circle — while the telegraph
## on the deck is a 120° (knight), 95° (scrapper) or 80° (gremlin) FAN pointed
## along `attack_direction`. So a player who did the thing the picture asks for
## — step out of the lit wedge, sideways, around the flank — was still hit by a
## swing that visibly went the other way. That is STATUS failure mode two in the
## dimension nobody checked, and it is most of why "designed to be dodged"
## (build-44, the furnace knight) did not describe the game.
##
## The wedge is now the hitbox in BOTH dimensions. Two notes on the geometry:
##
##   * The test is against the target's BODY, not its centre — a disc of radius
##     `body` overlaps the fan if its centre is within `swing/2 + asin(body/d)`
##     of the swing's axis. Being clipped by the edge of the picture should
##     hurt; only getting clear should not.
##   * Enemies with no `swing` (the Colossus, which telegraphs with a phase ring
##     rather than a fan, and any future shape) keep the circle. There is no
##     drawn wedge to be honest to, so there is nothing to be honest about.
##
## Nothing that stands still notices this: `attack_direction` is locked pointing
## at the target when the windup trips, so the boiler, a cannon and a crewman are
## dead centre of the fan and connect exactly as before. It is a change to what
## a MOVING captain can do, which is the whole point.
func _swing_hits(point: Vector2, swing_reach: float, body: float) -> bool:
	var offset := point - global_position
	var distance := offset.length()
	if distance > swing_reach:
		return false
	if not ("swing" in config):
		return true
	if distance <= body or distance <= 0.001:
		return true
	var half: float = float(config.swing) * 0.5 + asin(clampf(body / distance, 0.0, 1.0))
	return absf(attack_direction.angle_to(offset)) <= half


func configure(owner_game: Node, enemy_kind: String, enemy_lane: int, wave: int) -> void:
	mass = 2.6 if enemy_kind == "ARMORED" else (24.0 if enemy_kind == "BOSS" else 1.0)
	game = owner_game
	kind = enemy_kind
	lane = enemy_lane
	config = SkyGearData.ENEMIES[kind]
	## HEAT 1 · RUST hardens this. The 0.06 was a literal here and nowhere else,
	## which is fine until a difficulty wants to move it.
	var per_wave: float = SkyGearWorkshop.BASE_HP_SCALING
	if game != null and "heat" in game:
		per_wave = SkyGearWorkshop.hp_scaling_for(int(game.heat))
	var scaling := 1.0 + per_wave * maxf(0.0, wave - 1.0)
	max_hp = float(config.hp) * scaling
	hp = max_hp
	radius = float(config.radius)
	$CollisionShape2D.shape.radius = radius
	$Sprite.texture = load(config.texture)
	$Sprite.scale = Vector2.ONE * float(config.scale)
	$Sprite.position.y = -radius * 1.8
	add_to_group("enemies")
	queue_redraw()

func _physics_process(delta: float) -> void:
	if game == null or dead or not game.is_playing():
		velocity = Vector2.ZERO
		return
	_update_statuses(delta)
	if dead:
		return
	# the turn, fired once, on the frame the second beat begins
	if kind == "BOSS" and beat == 0 and hp <= max_hp * 0.5:
		beat = 1
		state = "turn"
		turn_time = TURN_TIME
		velocity = Vector2.ZERO
		game.on_boss_turn(self)
	if state == "turn":
		turn_time -= delta
		velocity = Vector2.ZERO
		if turn_time <= 0.0:
			state = "move"
		queue_redraw()
		return
	if state == "climb":
		state_time -= delta
		velocity = Vector2.ZERO
		if state_time <= 0.0:
			state = "move"
		queue_redraw()
		return
	if stun_time > 0.0:
		velocity = knock_velocity
		knock_velocity = knock_velocity.move_toward(Vector2.ZERO, 900.0 * delta)
		move_and_slide()
		_rein_in_knock()
		if _went_over():
			return
		global_position = game.correct_enemy_position(global_position, lane, radius,
			knock_velocity.length() > OVERBOARD_SPEED)
		return

	## What this boarder is walking at, in priority order:
	##   the captain if she is close enough to be the problem,
	##   the deck cannon gating this lane while it still stands,
	##   a crewman in the way,
	##   otherwise the Boiler.
	## The cannon matters most: without it a lane is a stripe on the floor, and
	## boarders stroll past the thing that is supposed to be stopping them.
	var target_position: Vector2 = game.boiler_position
	var target_radius: float = float(game.boiler_radius)
	var targets_player := false
	var target_turret: Dictionary = {}
	var target_crew: Dictionary = {}
	if global_position.distance_to(game.player.global_position) < 280.0:
		target_position = game.player.global_position
		target_radius = 17.0
		targets_player = true
	else:
		var gate: Dictionary = game.turret_in_lane(lane)
		if not gate.is_empty() and global_position.y < float(gate.position.y) + 40.0:
			target_position = gate.position
			target_radius = float(gate.radius)
			target_turret = gate
		else:
			var nearest_crew: Dictionary = game.nearest_crew(global_position, 220.0)
			if not nearest_crew.is_empty():
				target_position = nearest_crew.position
				target_radius = float(nearest_crew.radius)
				target_crew = nearest_crew
	var to_target := target_position - global_position
	var distance := to_target.length()
	var direction := to_target.normalized() if distance > 0.001 else Vector2.DOWN
	var attack_range: float = float(config.attack_range) + target_radius
	if kind == "BOSS" and beat == 1:
		attack_range += 90.0            # the second beat reaches the whole deck

	if state == "move":
		if distance <= attack_range:
			state = "windup"
			## HEAT 2 · SHORT FUSE. Faster to swing, not harder — the telegraph is
			## still there and still readable, which is the pillar this ladder is
			## not allowed to break.
			state_time = float(config.windup) * _windup_scale()
			attack_direction = direction
			velocity = Vector2.ZERO
			game.play_sfx("enemy/telegraph.ogg", -10.0)
		else:
			var speed_scale := 1.0 - slow_amount if slow_time > 0.0 else 1.0
			var desired := direction * float(config.speed) * speed_scale
			velocity = velocity.lerp(desired, 1.0 - pow(0.0015, delta))
	elif state == "windup":
		state_time -= delta
		velocity = Vector2.ZERO
		if state_time <= 0.0:
			## The swing lands out to `reach` (the browser's tuned melee reach),
			## measured to the target's near edge — so `reach + target_radius`, and
			## `attack_range` here already carries `+ target_radius`. The telegraph
			## wedge in view3d.gd is drawn at exactly this `reach`, so what is shown
			## and what connects are ONE number, not a drawing and a `+24..28` fudge
			## disagreeing about it (STATUS failure mode two). Enemies with no `reach`
			## (BOSS) keep the old ~26-unit reach past their trip range.
			var swing_reach: float = attack_range + \
				((float(config.reach) - float(config.attack_range)) if "reach" in config else 26.0)
			if config.ai == "ranged":
				game.spawn_enemy_bolt(global_position, target_position, float(config.damage), float(config.bolt_speed))
				game.play_sfx("enemy/shoot_drone.ogg", -7.0)
			elif targets_player and _swing_hits(game.player.global_position, swing_reach, 17.0):
				game.damage_player(float(config.damage), kind)
			elif not target_turret.is_empty() and _swing_hits(target_position, swing_reach, target_radius):
				game.damage_turret(target_turret, float(config.damage))
			elif not target_crew.is_empty() and _swing_hits(target_position, swing_reach, target_radius):
				game.hurt_crew(target_crew, float(config.damage))
			elif not targets_player and _swing_hits(game.boiler_position, swing_reach, float(game.boiler_radius)):
				game.damage_boiler(float(config.damage))
			state = "recover"
			state_time = float(config.recover)
	elif state == "recover":
		state_time -= delta
		velocity = Vector2.ZERO
		if state_time <= 0.0:
			state = "move"

	## THE SG-62 VECTOR LIVED ON THIS LINE. `velocity += knock_velocity` looks
	## like "add the shove for this frame", but `velocity` PERSISTS — the move
	## state's lerp keeps ~90% of it each frame — so every frame re-added the
	## whole shove on top of what the lerp still remembered of the last one.
	## A capped 900 shove integrated that way peaks near nine times itself and
	## carried 1,338 measured units. The walk keeps only the walk now: the shove
	## is added for the move and taken back off before the lerp can bank it.
	var walk := velocity
	velocity = walk + knock_velocity
	knock_velocity = knock_velocity.move_toward(Vector2.ZERO, 1050.0 * delta)
	move_and_slide()
	velocity = walk
	_rein_in_knock()
	if _went_over():
		return
	## The lane clamp is RELAXED while a real shove is on them, and that single
	## argument is the whole reason knocking someone off the ship was impossible
	## before. Every frame ended by pinning each boarder back inside a band 190
	## units either side of its lane centre — the outer bands stop at 750 and the
	## rail is at 840, so the ninety units where you would go over the side were
	## unreachable by construction, however hard you hit.
	global_position = game.correct_enemy_position(global_position, lane, radius,
		knock_velocity.length() > OVERBOARD_SPEED)
	queue_redraw()

## The two positional laws of a shove, enforced the frame it moved them —
## AFTER `move_and_slide`, BEFORE the rail and lane checks, in both the stunned
## and the walking paths:
##
##   1. `KNOCK_TRAVEL_MAX` — no shove carries more than this from its anchor,
##      whatever stack of multipliers or integration arithmetic produced it.
##   2. `KNOCK_STERN_GIVE` — no shove ends a frame more than this stern-ward of
##      its anchor. Stopped, never delivered to the Boiler.
##
## Positional on purpose: every earlier attempt capped a VELOCITY and was then
## beaten by whatever integrated that velocity (board SG-62's history, twice).
func _rein_in_knock() -> void:
	if not knock_live:
		return
	var offset := global_position - knock_anchor
	if offset.length() > KNOCK_TRAVEL_MAX:
		global_position = knock_anchor + offset.limit_length(KNOCK_TRAVEL_MAX)
	var stern_line := knock_anchor.y + KNOCK_STERN_GIVE
	if global_position.y > stern_line:
		global_position.y = stern_line
		## And stop pushing at the line, so the clamp is a wall rather than a
		## fight the shove keeps having every frame.
		knock_velocity.y = minf(knock_velocity.y, 0.0)
	if knock_velocity.length() <= 1.0:
		knock_live = false
		knock_velocity = Vector2.ZERO

## Are they past the rail? Called after the move and before the clamp, because
## the clamp is what would put them back.
##
## Only the SIDES count. The bow and the stern are where boarders arrive and
## where the Boiler stands, and a shove that deleted a boarder by pushing it off
## the front would make the safest thing you can do to a boarding party be to
## hit it back the way it came.
func _went_over() -> bool:
	if overboard or dead:
		return false
	var deck: Rect2 = SkyGearGame.DECK_RECT
	if global_position.x > deck.position.x and global_position.x < deck.end.x:
		return false
	overboard = true
	game.on_enemy_overboard(self)
	return true


func take_damage(amount: float, origin: Vector2, element: String, knock: float) -> float:
	# The Colossus cannot be burst through its turn. The second beat is the
	# encounter's point and a phase you can skip is not one.
	if state == "turn":
		return 0.0
	if dead or amount <= 0.0:
		return 0.0
	var dealt := minf(hp, amount)
	hp -= amount
	var away := (global_position - origin).normalized()
	if away.length_squared() == 0.0:
		away = Vector2.UP
	knock_velocity = (knock_velocity + away * knock / mass).limit_length(KNOCK_MAX)
	## The shove's ground rules are measured from where it BEGAN. A fresh hit
	## on an already-flying boarder keeps the old anchor — that is what stops a
	## fast-ticking build (the SG-62 report: Frost Mortar + Pulse + the auto,
	## SLEDGE FORCE on top) from ratcheting the travel and stern lines forward
	## hit by hit.
	if not knock_live and knock_velocity.length() > 1.0:
		knock_live = true
		knock_anchor = global_position
	_apply_element(element)
	if hp <= 0.0:
		dead = true
		game.on_enemy_killed(self)
		queue_free()
	queue_redraw()
	return dealt

## One way to die, so a caller never has to remember the three steps.
func kill() -> void:
	if dead:
		return
	dead = true
	hp = 0.0
	game.on_enemy_killed(self)
	queue_free()


func _apply_element(element: String) -> void:
	match element:
		"EMBER":
			burn_stacks = mini(3, burn_stacks + 1)
			burn_time = 3.0
		"FROST":
			slow_time = 2.0
			slow_amount = 0.40
		"ARC":
			if game.rng.randf() < 0.20:
				stun_time = maxf(stun_time, 0.45)
		"STEAM":
			state = "move"

func _update_statuses(delta: float) -> void:
	slow_time = maxf(0.0, slow_time - delta)
	stun_time = maxf(0.0, stun_time - delta)
	if burn_time > 0.0:
		burn_time -= delta
		burn_tick -= delta
		if burn_tick <= 0.0:
			burn_tick += 0.25
			var amount := 5.0 * burn_stacks * 0.25
			var dealt := minf(hp, amount)
			hp -= amount
			game.register_damage(dealt, global_position)
			if hp <= 0.0 and not dead:
				dead = true
				game.on_enemy_killed(self)
				queue_free()
	if burn_time <= 0.0:
		burn_stacks = 0

func _draw() -> void:
	_draw_flat_ellipse(Vector2(0, 7), radius * 1.25, radius * 0.48, Color(0.01, 0.01, 0.02, 0.50))
	if state == "turn":
		# the turn reads as a held moment: a bright ring, and nothing else
		draw_arc(Vector2.ZERO, radius + 26.0 + sin(turn_time * 9.0) * 6.0, 0.0, TAU, 48,
			Color("#ffd36b"), 7.0)
	if state == "climb":
		draw_arc(Vector2.ZERO, radius + 8.0, 0.0, TAU, 32, Color("#e8c376"), 3.0)
	if state == "windup":
		var reach := float(config.attack_range)
		draw_line(Vector2.ZERO, attack_direction * reach, Color(0.88, 0.20, 0.12, 0.72), 4.0)
	if hp < max_hp:
		draw_rect(Rect2(-radius, -radius * 2.3, radius * 2.0, 5), Color("#28131a"))
		draw_rect(Rect2(-radius, -radius * 2.3, radius * 2.0 * hp / max_hp, 5), Color("#e14f35"))

func _draw_flat_ellipse(center: Vector2, width: float, height: float, color: Color) -> void:
	var points := PackedVector2Array()
	for i in 24:
		var angle := TAU * float(i) / 24.0
		points.append(center + Vector2(cos(angle) * width, sin(angle) * height))
	draw_colored_polygon(points, color)

