class_name SkyGearEnemy
extends CharacterBody2D

var game: Node
var kind := "SCRAPPER"
var lane := 1
var config: Dictionary
var hp := 1.0
var max_hp := 1.0
var radius := 22.0
var state := "climb"
var state_time := 0.8
var attack_direction := Vector2.DOWN
var dead := false
var knock_velocity := Vector2.ZERO
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

func configure(owner_game: Node, enemy_kind: String, enemy_lane: int, wave: int) -> void:
	game = owner_game
	kind = enemy_kind
	lane = enemy_lane
	config = SkyGearData.ENEMIES[kind]
	var scaling := 1.0 + 0.06 * maxf(0.0, wave - 1.0)
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
		global_position = game.correct_enemy_position(global_position, lane, radius)
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
			state_time = float(config.windup)
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
	global_position = game.correct_enemy_position(global_position, lane, radius)
	queue_redraw()

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
	var mass := 2.6 if kind == "ARMORED" else (24.0 if kind == "BOSS" else 1.0)
	knock_velocity += away * knock / mass
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

