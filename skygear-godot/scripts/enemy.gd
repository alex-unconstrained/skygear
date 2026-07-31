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

var knock_velocity := Vector2.ZERO
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

func _windup_scale() -> float:
	if game == null or not ("heat" in game):
		return 1.0
	return SkyGearWorkshop.windup_for(int(game.heat))


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
		turn_time = 1.6
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
			if config.ai == "ranged":
				game.spawn_enemy_bolt(global_position, target_position, float(config.damage), float(config.bolt_speed))
				game.play_sfx("enemy/shoot_drone.ogg", -7.0)
			elif targets_player and global_position.distance_to(game.player.global_position) <= attack_range + 24.0:
				game.damage_player(float(config.damage), kind)
			elif not target_turret.is_empty() and global_position.distance_to(target_position) <= attack_range + 28.0:
				game.damage_turret(target_turret, float(config.damage))
			elif not target_crew.is_empty() and global_position.distance_to(target_position) <= attack_range + 24.0:
				game.hurt_crew(target_crew, float(config.damage))
			elif not targets_player and global_position.distance_to(game.boiler_position) <= attack_range + 28.0:
				game.damage_boiler(float(config.damage))
			state = "recover"
			state_time = float(config.recover)
	elif state == "recover":
		state_time -= delta
		velocity = Vector2.ZERO
		if state_time <= 0.0:
			state = "move"

	velocity += knock_velocity
	knock_velocity = knock_velocity.move_toward(Vector2.ZERO, 1050.0 * delta)
	move_and_slide()
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

