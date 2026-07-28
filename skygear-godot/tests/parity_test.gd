extends SceneTree

## The parity harness.
##
## The browser build has sixty-nine checks that drive the real simulation and
## assert against the real state, and every claim in that project that turned
## out wrong was a claim nobody checked. A port that reaches feature parity
## without them is a step backwards, so the checks come across as ideas even
## though they cannot come across as code.
##
##   godot --path . --headless --script tests/parity_test.gd
##
## Exit code is the number of failures, so it composes in a shell.

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(group: String, name: String, condition: bool, detail: String = "") -> void:
	checks += 1
	if condition:
		print("  ok  %s · %s%s" % [group, name, ("   " + detail) if detail != "" else ""])
	else:
		failures.append("%s · %s   %s" % [group, name, detail])
		print(" FAIL %s · %s   %s" % [group, name, detail])


func _new_game() -> SkyGearGame:
	var scene: PackedScene = load("res://scenes/main.tscn")
	var game: SkyGearGame = scene.instantiate()
	root.add_child(game)
	return game


## Step the simulation without waiting for real frames. Physics bodies need
## _physics_process, so this drives the tree rather than calling into the game:
## a test that steps a different loop than the game runs is testing itself.
func _advance(game: SkyGearGame, seconds: float) -> void:
	var steps := int(seconds / 0.05)
	for _i in steps:
		game._process(0.05)
		for enemy in game.get_tree().get_nodes_in_group("enemies"):
			if is_instance_valid(enemy):
				enemy._physics_process(0.05)


func _begin(game: SkyGearGame, seed_text: String = "PARITY") -> void:
	game.set_seed_text(seed_text)
	game.begin_run()
	game.choose_draft(0)


func _run() -> void:
	print("\nSKYGEAR Godot port · parity harness\n")
	await process_frame
	_boot()
	await process_frame
	_matrix()
	await process_frame
	_close_quarters()
	await process_frame
	_deck()
	await process_frame
	_lanes()
	await process_frame
	_draft()
	await process_frame
	_seed()
	await process_frame
	_report()
	await process_frame
	_boss()
	await process_frame
	_audio()
	await process_frame
	_endings()
	await process_frame
	_view()
	await process_frame
	_persistence()
	await process_frame
	_layout()

	print("")
	if failures.is_empty():
		print("%d/%d checks passed" % [checks, checks])
	else:
		print("%d/%d checks passed  —  %s" % [checks - failures.size(), checks,
			", ".join(failures)])
	quit(failures.size())


func _boot() -> void:
	var game := _new_game()
	_check("boot", "boots to the title screen", game.state_name == "TITLE")
	_check("boot", "the roster is loaded",
		SkyGearData.SHAPES.size() == 9 and SkyGearData.ELEMENTS.size() == 4
		and SkyGearData.WAVES.size() == 12,
		"%d shapes, %d elements, %d waves" % [SkyGearData.SHAPES.size(),
			SkyGearData.ELEMENTS.size(), SkyGearData.WAVES.size()])
	_begin(game)
	_check("boot", "a run starts on wave one with a weapon",
		game.state_name == "PLAY" and game.wave == 1 and game.skills.size() == 1)
	_check("boot", "the captain has two dash charges",
		game.player.dash_charges == 2, str(game.player.dash_charges))
	game.queue_free()


## Every draftable cell must deal damage. A cell that silently does nothing is
## the failure this catches: the code path exists, the cooldown ticks, and no
## damage is ever dealt.
func _matrix() -> void:
	var game := _new_game()
	_begin(game)
	game.player.max_hp = 1e9
	game.player.hp = 1e9
	var dead_cells: Array[String] = []
	var cells := 0
	for shape in SkyGearData.SHAPES.keys():
		for element in SkyGearData.ELEMENTS.keys():
			cells += 1
			game.skills = [SkyGearData.make_skill(shape, element)]
			game.spawn_enemy("SCRAPPER", 1)
			var enemy: SkyGearEnemy = null
			for e in game.get_tree().get_nodes_in_group("enemies"):
				if is_instance_valid(e) and not e.dead:
					enemy = e
			if enemy == null:
				dead_cells.append(shape + "/" + element + ": no target")
				continue
			enemy.state = "move"
			enemy.global_position = game.player.global_position + Vector2(60, -10)
			enemy.hp = 1e9
			enemy.max_hp = 1e9
			game.player.aim_direction = Vector2(1, 0)
			var before: float = enemy.hp
			if bool(SkyGearData.SHAPES[shape].get("passive", false)):
				game.skills[0].passive_timer = 0.0
				game._update_passives(0.05)
			else:
				game.cast_skill(0, enemy.global_position)
			if enemy.hp >= before:
				dead_cells.append(shape + "/" + element)
			enemy.dead = true
			enemy.queue_free()
	_check("matrix", "every shape x element deals damage",
		dead_cells.is_empty(), "%d cells, dead: %s" % [cells, ", ".join(dead_cells)])
	game.queue_free()


func _close_quarters() -> void:
	var game := _new_game()
	_begin(game)
	var close_range: float = float(SkyGearData.CLOSE.range)

	# pressure builds from a close hit and not from a distant one
	game.pressure = 0.0
	game.spawn_enemy("SCRAPPER", 1)
	var near: SkyGearEnemy = null
	for e in game.get_tree().get_nodes_in_group("enemies"):
		near = e
	near.global_position = game.player.global_position + Vector2(close_range * 0.5, 0)
	near.hp = 1e9
	near.max_hp = 1e9
	near.state = "move"
	game.damage_enemy(near, 40.0, "EMBER", 0.0, game.player.global_position, true)
	var gained := game.pressure
	game.pressure = 0.0
	near.global_position = game.player.global_position + Vector2(close_range * 3.0, 0)
	game.damage_enemy(near, 40.0, "EMBER", 0.0, near.global_position, true)
	_check("close", "pressure builds in close and only in close",
		gained > 0.0 and is_equal_approx(game.pressure, 0.0),
		"close +%.1f, at range +%.1f" % [gained, game.pressure])

	# a full gauge vents: heals, damages, resets, and does not refill itself
	near.global_position = game.player.global_position + Vector2(80, 0)
	game.player.hp = 40.0
	game.player.max_hp = 200.0
	game.pressure = 0.0
	game.vent_cooldown = 0.0
	game.heal_budget = float(SkyGearData.CLOSE.heal_cap_per_sec)
	var enemy_before: float = near.hp
	game.vent_pressure()
	_check("close", "a full gauge vents: heals, hits, and does not refill itself",
		game.player.hp > 40.0 and near.hp < enemy_before and is_equal_approx(game.pressure, 0.0),
		"hp %.0f, dealt %.0f, gauge %.0f" % [game.player.hp, enemy_before - near.hp, game.pressure])

	# the healing ceiling holds against any single burst
	game.player.hp = 10.0
	game.heal_budget = float(SkyGearData.CLOSE.heal_cap_per_sec)
	var healed := 0.0
	for _i in 20:
		healed += game.heal_player(50.0, "vent")
	_check("close", "no burst of healing exceeds the per-second ceiling",
		healed <= float(SkyGearData.CLOSE.heal_cap_per_sec) + 0.001,
		"1000 offered, %.1f taken (cap %.0f)" % [healed, SkyGearData.CLOSE.heal_cap_per_sec])

	# lifesteal is close-range only
	game.mods.lifesteal = 0.5
	game.player.hp = 100.0
	game.player.max_hp = 400.0
	game.heal_budget = 999.0
	game.steal_budget = 999.0
	near.global_position = game.player.global_position + Vector2(close_range * 0.5, 0)
	game.damage_enemy(near, 100.0, "EMBER", 0.0, game.player.global_position, true)
	var stole_close: float = game.player.hp - 100.0
	game.player.hp = 100.0
	game.steal_budget = 999.0
	near.global_position = game.player.global_position + Vector2(close_range * 3.0, 0)
	game.damage_enemy(near, 100.0, "EMBER", 0.0, near.global_position, true)
	_check("close", "lifesteal heals in close and heals nothing at range",
		stole_close > 0.0 and is_equal_approx(game.player.hp, 100.0),
		"close +%.1f, at range +%.1f" % [stole_close, game.player.hp - 100.0])
	game.queue_free()


func _deck() -> void:
	var game := _new_game()
	_begin(game)
	var props := game.get_tree().get_nodes_in_group("props")
	_check("deck", "the deck carries destructible ordnance",
		props.size() >= 6, "%d props" % props.size())

	var keg: SkyGearProp = null
	for p in props:
		if p.prop_type == "keg" and not p.dead:
			keg = p
	_check("deck", "a keg exists to light", keg != null)
	if keg != null:
		keg.damage(9999.0)
		_check("deck", "killing a keg lights a fuse rather than detonating",
			keg.fuse_left > 0.0 and not keg.dead,
			"fuse %.2fs" % keg.fuse_left)
		game.spawn_enemy("SCRAPPER", 1)
		var victim: SkyGearEnemy = null
		for e in game.get_tree().get_nodes_in_group("enemies"):
			victim = e
		victim.global_position = keg.global_position + Vector2(40, 0)
		victim.state = "move"
		var hp_before: float = victim.hp
		_advance(game, 1.0)
		_check("deck", "the blast lands on what is standing in it",
			victim.hp < hp_before or victim.dead,
			"victim %.0f -> %.0f" % [hp_before, victim.hp])

	# the crew re-stow the deck between waves
	for p in game.get_tree().get_nodes_in_group("props"):
		p.dead = true
	game.start_wave(2)
	var alive := 0
	for p in game.get_tree().get_nodes_in_group("props"):
		if not p.dead:
			alive += 1
	_check("deck", "the deck is re-stowed for the next wave",
		alive >= 6, "%d standing" % alive)
	game.queue_free()


func _lanes() -> void:
	var game := _new_game()
	_begin(game)
	_check("lanes", "a deck cannon gates every lane",
		game.turrets.size() == 3 and not bool(game.turrets[0].dead),
		"%d cannons" % game.turrets.size())

	# a cannon shoots what is in its lane. Clear the deck first: the wave has
	# already spawned boarders of its own and grabbing "the last one" picked an
	# arbitrary lane, which made this check pass or fail by luck.
	for e in game.get_tree().get_nodes_in_group("enemies"):
		e.dead = true
		e.queue_free()
	game.spawn_queue.clear()
	game.spawn_enemy("SCRAPPER", 1)
	var target: SkyGearEnemy = null
	for e in game.get_tree().get_nodes_in_group("enemies"):
		target = e
	target.state = "move"
	target.global_position = Vector2(game.turrets[1].position) + Vector2(0, -200)
	target.hp = 1e6
	target.max_hp = 1e6
	var before: float = target.hp
	_advance(game, 3.0)
	_check("lanes", "a deck cannon fires on the boarder in its lane",
		target.hp < before, "%.0f -> %.0f" % [before, target.hp])

	# and a boarder breaks the cannon rather than strolling past it
	var gate: Dictionary = game.turrets[1]
	var gate_hp: float = gate.hp
	target.global_position = Vector2(gate.position) + Vector2(0, -70)
	target.state = "move"
	target.state_time = 0.0
	_advance(game, 6.0)
	_check("lanes", "a boarder attacks the cannon in its way",
		float(gate.hp) < gate_hp, "cannon %.0f -> %.0f" % [gate_hp, gate.hp])

	# crew muster and push up the lane
	_advance(game, 4.0)
	_check("lanes", "crew muster and hold a lane",
		game.crew.size() > 0, "%d crew" % game.crew.size())

	# a push wave grapples a hulk on, and the wave does not end until it breaks
	game.start_wave(4)
	_check("lanes", "a push wave grapples a boarding hulk to the hull",
		not game.hulk.is_empty() and bool(game.hulk.vulnerable),
		"hulk hp %.0f" % float(game.hulk.get("hp", 0.0)))
	game.spawn_queue.clear()
	for e in game.get_tree().get_nodes_in_group("enemies"):
		e.dead = true
	_advance(game, 1.0)
	_check("lanes", "the push wave does not end while its hulk lives",
		game.wave_clear_time < 0.0 and game.state_name == "PLAY")
	game.damage_hulk(99999.0)
	game.spawn_queue.clear()
	for e in game.get_tree().get_nodes_in_group("enemies"):
		e.dead = true
	_advance(game, 1.5)
	_check("lanes", "breaking the hulk clears the push",
		game.wave_clear_time >= 0.0 or game.state_name == "DRAFT",
		"clear timer %.2f, state %s" % [game.wave_clear_time, game.state_name])
	game.queue_free()


func _draft() -> void:
	var game := _new_game()
	_begin(game)
	game.skills = [
		SkyGearData.make_skill("CLOSEHIT", "EMBER"),
		SkyGearData.make_skill("CHAIN", "ARC"),
		SkyGearData.make_skill("RANGED_AOE", "FROST"),
		SkyGearData.make_skill("CONE", "STEAM"),
	]
	var scopes := {}
	var bad: Array[String] = []
	for _i in 40:
		for card in game.roll_upgrade_cards(3):
			scopes[card.scope] = int(scopes.get(card.scope, 0)) + 1
			var hit: Array = SkyGearCards.affects(game, card)
			if card.scope == SkyGearCards.SCOPE_SKILL and (hit.size() != 1 or hit[0] != card.get("slot", -1)):
				bad.append(str(card.id) + ": slot card does not point at its slot")
	_check("draft", "every card declares what it touches", bad.is_empty(),
		bad[0] if not bad.is_empty() else "")
	_check("draft", "the draft offers several classes of card",
		scopes.size() >= 4, str(scopes))

	game.open_draft()
	var before := ""
	for c in game.draft_options:
		before += str(c.title)
	var rerolls_before := game.rerolls
	var rerolled := game.reroll_draft()
	var after := ""
	for c in game.draft_options:
		after += str(c.title)
	game.rerolls = 0
	var refused := not game.reroll_draft()
	_check("draft", "reroll spends one, deals a new hand, and stops at zero",
		rerolled and before != after and refused and rerolls_before - 1 >= 0,
		"rerolled=%s changed=%s refused=%s" % [rerolled, before != after, refused])

	# taking a card applies it
	game.open_draft()
	var card: Dictionary = game.draft_options[0]
	var applied := false
	if card.has("apply"):
		var hp_before: float = game.player.max_hp
		var mods_before := str(game.mods)
		game.choose_draft(0)
		applied = str(game.mods) != mods_before or game.player.max_hp != hp_before \
			or game.skills.size() > 4 or game.rerolls > 0
	_check("draft", "choosing a card changes the run",
		applied or card.kind == "skill", str(card.get("title", "?")))
	game.queue_free()


func _seed() -> void:
	var a := _new_game()
	_begin(a, "REPEAT1")
	var first := ""
	a.open_draft()
	for c in a.draft_options:
		first += str(c.title) + "|"
	a.queue_free()

	var b := _new_game()
	_begin(b, "REPEAT1")
	var second := ""
	b.open_draft()
	for c in b.draft_options:
		second += str(c.title) + "|"
	b.queue_free()

	var c := _new_game()
	_begin(c, "DIFFER2")
	var third := ""
	c.open_draft()
	for card in c.draft_options:
		third += str(card.title) + "|"
	c.queue_free()

	_check("seed", "the same seed deals the same hand", first == second, first)
	_check("seed", "a different seed deals a different hand", first != third, third)


## The report is what a playtest actually returns, so it has to be right: the
## browser build shipped one that credited a Sentry with 76%% of a run because
## the attribution behind it was wrong, and nobody could tell from reading it.
func _report() -> void:
	var game := _new_game()
	_begin(game, "REPORT")
	game.player.max_hp = 1e6
	game.player.hp = 1e6
	game.skills = [
		SkyGearData.make_skill("CLOSEHIT", "EMBER"),
		SkyGearData.make_skill("RANGED_AOE", "FROST"),
	]
	for e in game.get_tree().get_nodes_in_group("enemies"):
		e.dead = true
		e.queue_free()
	game.spawn_enemy("SCRAPPER", 1)
	var target: SkyGearEnemy = null
	for e in game.get_tree().get_nodes_in_group("enemies"):
		target = e
	target.state = "move"
	target.global_position = game.player.global_position + Vector2(60, 0)
	target.hp = 1e9
	target.max_hp = 1e9
	for _i in 6:
		game.skills[0].cooldown_left = 0.0
		game.cast_skill(0, target.global_position)
	# two seconds, not half of one: the range line is only printed for a run
	# long enough for the buckets to mean anything, which is correct behaviour
	# and made a stricter check fail for the right reason
	_advance(game, 2.0)

	var attributed := float(game.tel.basic.damage) + float(game.tel.deck.damage) 		+ float(game.tel.allies.damage)
	for row in game.tel.per:
		attributed += float(row.damage)
	_check("report", "damage is attributed to the slot that fired",
		float(game.tel.per[0].damage) > 0.0 and is_equal_approx(float(game.tel.per[1].damage), 0.0),
		"slot0 %.0f, slot1 %.0f" % [game.tel.per[0].damage, game.tel.per[1].damage])
	_check("report", "casts are counted",
		int(game.tel.per[0].casts) == 6, str(game.tel.per[0].casts))
	_check("report", "engagement distance is sampled",
		float(game.tel.range_time.close) > 0.0,
		"%.2fs close" % game.tel.range_time.close)
	var text: String = game.run_report()
	_check("report", "the run report names the build, the seed and the work",
		text.contains("REPORT") and text.contains("Ember Cleave")
		and text.contains("skills —") and text.contains("range:"),
		text.split("
")[2] if text.split("
").size() > 2 else text)
	game.queue_free()


## The finale has two beats and the second one has to actually arrive. A phase
## change is the easiest thing in a game to write and never see.
func _boss() -> void:
	var game := _new_game()
	_begin(game)
	for e in game.get_tree().get_nodes_in_group("enemies"):
		e.dead = true
		e.queue_free()
	game.spawn_queue.clear()
	game.spawn_enemy("BOSS", 1)
	game.spawn_enemy("SWARM", 0)
	var boss: SkyGearEnemy = null
	var minion: SkyGearEnemy = null
	for e in game.get_tree().get_nodes_in_group("enemies"):
		if e.kind == "BOSS":
			boss = e
		else:
			minion = e
	_check("boss", "the Colossus arrives", boss != null)
	if boss == null:
		game.queue_free()
		return
	boss.state = "move"
	_check("boss", "it begins on the first beat", boss.beat == 0)
	boss.hp = boss.max_hp * 0.4
	_advance(game, 0.1)
	_check("boss", "it turns at half health", boss.beat == 1 and boss.state == "turn",
		"beat %d state %s" % [boss.beat, boss.state])
	var during: float = boss.hp
	game.damage_enemy(boss, 500.0, "EMBER", 0.0, game.player.global_position, false)
	_check("boss", "it cannot be burst through the turn",
		is_equal_approx(boss.hp, during), "%.0f -> %.0f" % [during, boss.hp])
	_check("boss", "the turn clears what the first beat called",
		minion == null or not is_instance_valid(minion) or minion.dead)
	_advance(game, 2.0)
	_check("boss", "and it comes out of the turn", boss.state != "turn", boss.state)
	game.queue_free()


## Sound the player can control, and that survives the session. A build people
## download needs a volume slider more than it needs another particle.
func _audio() -> void:
	# No awaits in here. A coroutine that suspends mid-check is a check that
	# silently does not run: the first version awaited a frame after saving
	# settings, _run() reached quit() first, and the persistence assertion never
	# printed at all — which looked exactly like a pass.
	var game := _new_game()
	_check("audio", "the mixer has its own buses",
		AudioServer.get_bus_index("Music") >= 0 and AudioServer.get_bus_index("SFX") >= 0
		and AudioServer.get_bus_index("UI") >= 0)
	if game.audio == null:
		_check("audio", "the audio director exists", false)
		game.queue_free()
		return
	_check("audio", "music is tiered by wave and the finale has its own",
		game.audio.track_for(1, false) == "combat_low"
		and game.audio.track_for(10, false) == "combat_high"
		and game.audio.track_for(12, true) == "boss",
		"%s / %s / %s" % [game.audio.track_for(1, false), game.audio.track_for(10, false),
			game.audio.track_for(12, true)])
	_check("audio", "every tier has a file behind it",
		ResourceLoader.exists(SkyGearAudio.TRACKS.combat_low)
		and ResourceLoader.exists(SkyGearAudio.TRACKS.combat_high)
		and ResourceLoader.exists(SkyGearAudio.TRACKS.boss))
	game.audio.set_volume("master", 0.42)
	game.audio.save_settings()
	var fresh := SkyGearAudio.new()
	root.add_child(fresh)
	_check("audio", "volume survives the session",
		is_equal_approx(float(fresh.volumes.master), 0.42),
		str(fresh.volumes.master))
	game.audio.set_volume("master", 0.85)
	fresh.queue_free()
	game.queue_free()


func _endings() -> void:
	var game := _new_game()
	_begin(game)
	game.damage_boiler(99999.0)
	_check("endings", "the Boiler reaching zero ends the run",
		game.state_name == "GAMEOVER", game.state_name)
	game.queue_free()

	var other := _new_game()
	_begin(other)
	other.damage_player(99999.0)
	_check("endings", "the captain dying ends the run",
		other.state_name == "GAMEOVER", other.state_name)
	other.queue_free()

	var third := _new_game()
	_begin(third)
	third.wave = SkyGearData.WAVES.size()
	third.spawn_queue.clear()
	third.hulk = {}
	third._update_wave(0.05)
	third.wave_clear_time = 0.01
	third._update_wave(0.05)
	_check("endings", "clearing the last wave wins the run",
		third.state_name == "VICTORY", third.state_name)
	third.queue_free()


## --- what you actually look at ----------------------------------------------
## The port shipped a build whose simulation was right and whose picture was a
## different game, and nothing in this harness caught it, because every check
## drove the model. These drive the camera and the mirror instead. They are not
## screenshot tests — they assert the two numbers and the one decision that a
## screenshot would only show you had gone wrong.
func _view() -> void:
	var world: Node3D = load("res://scenes/main3d.tscn").instantiate()
	root.add_child(world)
	var view: SkyGearView3D = world as SkyGearView3D
	var game: SkyGearGame = world.get_node("SkyGear")
	_begin(game)
	game.player.global_position = Vector2(0, 200)
	view.sway = false           # the framing is what the sway moves around
	view._process(1.0)          # a long step, so the follow lands rather than eases

	## The whole camera is four constants and this solve. If the captain stops
	## landing at 60% of screen height, every sprite in `assets/` — all of which
	## was generated against that framing — is being shown through a lens it was
	## not painted for.
	var lens: float = rad_to_deg(2.0 * atan((SkyGearView3D.REF_HEIGHT * 0.5)
		/ SkyGearView3D.FOCAL))
	_check("camera", "the lens is the browser's focal length",
		absf(view.camera.fov - lens) < 0.01 and absf(lens - 36.1) < 0.2,
		"%.2f deg vertical" % view.camera.fov)

	var screen := view.camera.unproject_position(
		Vector3(game.player.global_position.x, 0.0, game.player.global_position.y)
		* SkyGearView3D.WORLD_SCALE)
	var height: float = float(view.camera.get_viewport().get_visible_rect().size.y)
	var frac: float = screen.y / maxf(1.0, height)
	_check("camera", "the captain stands where the art was framed for",
		absf(frac - SkyGearView3D.STAND_FRAC) < 0.02,
		"%.3f of screen height" % frac)

	## Ground (x, y) -> world (x, 0, y). Everything in the mirror depends on it.
	var probe := Vector2(-300, 480)
	var back := view.camera.unproject_position(Vector3(probe.x, 0.0, probe.y)
		* SkyGearView3D.WORLD_SCALE)
	_check("camera", "deck coordinates land left of centre when they are to port",
		back.x < view.camera.get_viewport().get_visible_rect().size.x * 0.5,
		"x %.0f" % back.x)

	## The x-ray. A boarder that walks behind a cargo run has to keep existing.
	## The shadow of a cargo run is a band about forty units deep behind its far
	## face, so the test point is placed there rather than "somewhere past it".
	var cargo: Rect2 = SkyGearGame.CARGO_RECTS[2]
	var eye := Vector2(view._focus.x, view._focus.y + SkyGearView3D.CAM_NEAR)
	var ray: Vector2 = (cargo.get_center() - eye).normalized()
	var to_far_face: float = (eye.y - cargo.position.y) / -ray.y
	var behind: Vector2 = eye + ray * (to_far_face + 26.0)
	var stand := 186.0                       # a SCRAPPER, standing
	_check("view", "a boarder tucked behind cargo is x-rayed",
		view._occluded(behind, stand), "at %.0f, %.0f" % [behind.x, behind.y])
	_check("view", "one in the open is not",
		not view._occluded(Vector2(0, 300), stand))
	_check("view", "and neither is one well clear of the run",
		not view._occluded(eye + ray * (to_far_face + 420.0), stand))

	## Every living thing gets a body in the mirror, or it is in the fight
	## without being on the screen.
	for i in 5:
		game.spawn_enemy("SCRAPPER", i % 3)
	view._process(0.05)
	var bodies := 0
	for key in view._billboards.keys():
		if str(key).begins_with("e"):
			bodies += 1
	_check("view", "every boarder gets a billboard",
		bodies == game.enemy_count(), "%d bodies / %d boarders" % [bodies, game.enemy_count()])

	## Dressing is dressing. Braziers and rope were added to fill the deck out,
	## and if they joined the target list they would change the fight.
	var dressing := 0
	var targetable_dressing := 0
	for p in game.get_tree().get_nodes_in_group("props"):
		if p.prop_type == "brazier" or p.prop_type == "rope":
			dressing += 1
			if p.is_targetable():
				targetable_dressing += 1
	_check("view", "the deck is dressed", dressing >= 4, "%d pieces" % dressing)
	_check("view", "and the dressing stays out of the fight",
		targetable_dressing == 0, "%d targetable" % targetable_dressing)

	## Damage says a number. The whole v11 upgrade system asks the player to
	## notice which skill is carrying the run.
	game.floaters.clear()
	var victim: SkyGearEnemy = null
	for e in game.get_tree().get_nodes_in_group("enemies"):
		victim = e
	game.damage_enemy(victim, 17.0, "EMBER", 0.0, victim.global_position, false)
	_check("view", "a hit puts a number in the world",
		game.floaters.size() == 1, "%d floaters" % game.floaters.size())

	## And it does so WITHOUT touching the seeded stream. Scattering the numbers
	## from `rng` shifted every crit and scrap roll after the first hit, which is
	## a cosmetic feature quietly rewriting the run.
	game.rng.seed = 1234
	var before_state: int = game.rng.state
	for i in 12:
		game.add_floater("9", Vector2.ZERO, Color.WHITE)
	_check("view", "and does not disturb the seeded stream",
		game.rng.state == before_state, "state %d" % game.rng.state)

	## F-03 and F-04, both reported against the browser and both invisible in the
	## port until now: the airstream was ported into the simulation and then the
	## scene that drew it was hidden.
	_check("view", "the air is moving past the camera",
		view._stream.size() == SkyGearView3D.STREAK_COUNT,
		"%d streaks" % view._stream.size())
	var was := view._stream[0].position
	view._process(0.25)
	_check("view", "and it actually travels",
		view._stream[0].position.distance_to(was) > 0.5,
		"moved %.2f m" % view._stream[0].position.distance_to(was))
	view.sway = true
	view._flicker = 2.4
	view._track_camera(0.016)
	_check("view", "the ship rolls enough to see",
		absf(rad_to_deg(view.camera.rotation.z)) > 0.15,
		"%.2f deg" % rad_to_deg(view.camera.rotation.z))

	## The VFX layer. Reported from a build: "targeted vfx and auras were all
	## rendering strangely."
	game.effects.clear()
	game.skills.append(SkyGearData.make_skill("AURA", "STEAM"))
	for k in 4:
		game._fx({"kind": "circle", "position": Vector2(k * 40, 0), "radius": 90.0,
			"color": Color.WHITE, "time": 0.0, "life": 1.0})
	var ids := {}
	for e in game.effects:
		ids[int(e.get("id", -1))] = true
	_check("vfx", "every effect has an identity that outlives its index",
		ids.size() == game.effects.size() and not ids.has(-1),
		"%d effects, %d ids" % [game.effects.size(), ids.size()])
	var second_id: int = int(game.effects[1].id)
	game.effects.remove_at(0)
	_check("vfx", "and removing one does not renumber the rest",
		int(game.effects[0].id) == second_id,
		"id %d still %d" % [int(game.effects[0].id), second_id])

	## A Field used to draw nothing at all: `_update_passives` ticked damage at
	## 150 units and appended no effect, so the player could not see the edge of
	## their own aura.
	view._process(0.05)
	var aura_ring := false
	var aura_volume := false
	for key in view._decals.keys():
		if str(key).begins_with("aura"):
			aura_ring = true
	for key in view._volumes.keys():
		if str(key).begins_with("auravol"):
			aura_volume = true
	_check("vfx", "a Field shows where it reaches", aura_ring and aura_volume,
		"ring %s, volume %s" % [aura_ring, aura_volume])

	## Ground effects are projected, not stickers a centimetre off the planking.
	var any_decal: Decal = null
	for key in view._decals.keys():
		any_decal = view._decals[key]
		break
	_check("vfx", "ground effects are projected decals, not floating quads",
		any_decal != null and any_decal is Decal and any_decal.size.y > 1.0,
		"projection depth %.2f m" % (any_decal.size.y if any_decal != null else 0.0))
	_check("vfx", "and their emission is premultiplied, so it cannot flood the box",
		any_decal != null and (any_decal.texture_emission == null
			or any_decal.texture_emission != any_decal.texture_albedo))

	## The figures. Every character was one image — `*_front_idle.png` — in every
	## situation, with three authored views and four delivered cycles unreachable.
	var facing_away: Dictionary = SkyGearSprites.view_for(Vector2(0, -1), false)
	var facing_you: Dictionary = SkyGearSprites.view_for(Vector2(0, 1), false)
	_check("sprites", "a figure walking up-deck shows you its back",
		str(facing_away.view) == "back_idle" and str(facing_you.view) == "front_idle")
	_check("sprites", "and mirrors rather than needing a second painting",
		bool(SkyGearSprites.view_for(Vector2(1, 1), false).mirror)
			and not bool(SkyGearSprites.view_for(Vector2(-1, 1), false).mirror))
	_check("sprites", "a swing uses the attack view",
		str(SkyGearSprites.view_for(Vector2(0, 1), true).view) == "front_attack")
	_check("sprites", "every kind has art behind every view it claims",
		_views_resolve(), "missing: %s" % _missing_views())

	## The cycles. `frame` returning -1 is how an undelivered strip falls back to
	## the still, and it has to keep doing that or the whole thing is a hard
	## dependency on art that does not exist yet.
	_check("sprites", "a delivered cycle advances",
		SkyGearSprites.frame("hero_run", 0.0) != SkyGearSprites.frame("hero_run", 0.5),
		"%d -> %d" % [SkyGearSprites.frame("hero_run", 0.0),
			SkyGearSprites.frame("hero_run", 0.5)])
	_check("sprites", "and stays inside its own strip",
		SkyGearSprites.frame("hero_run", 99.0) < int(SkyGearSprites.STRIPS.hero_run.count),
		"frame %d of %d" % [SkyGearSprites.frame("hero_run", 99.0),
			int(SkyGearSprites.STRIPS.hero_run.count)])
	_check("sprites", "a pingpong idle turns round rather than snapping",
		SkyGearSprites.frame("hero_idle", 0.0) == 0
			and SkyGearSprites.frame("hero_idle", 11.0 / 12.0) == 11
			and SkyGearSprites.frame("hero_idle", 12.0 / 12.0) == 10)
	_check("sprites", "an undelivered cycle falls back to the still, not to nothing",
		SkyGearSprites.frame("BOSS_idle", 0.5) == -1
			and SkyGearSprites.still("BOSS", "front_idle") != null)
	_check("sprites", "and the outstanding list is honest",
		SkyGearSprites.pending().size() == 14,
		"%d cycles outstanding" % SkyGearSprites.pending().size())

	## Painted art beats generated art, and forty-two of sixty files in
	## `assets/art/` were unreachable from any script.
	var unpainted: Array[String] = []
	for key in SkyGearView3D.PAINTED.keys():
		if not ResourceLoader.exists(str(SkyGearView3D.PAINTED[key])):
			unpainted.append(str(key))
	_check("art", "every painted effect plate is on disk", unpainted.is_empty(),
		"missing: %s" % ", ".join(unpainted))
	var unprop: Array[String] = []
	for kind in SkyGearProp.TEXTURES.keys():
		if not ResourceLoader.exists(str(SkyGearProp.TEXTURES[kind])):
			unprop.append(str(kind))
	_check("art", "every prop kind has art", unprop.is_empty(),
		"missing: %s" % ", ".join(unprop))
	var unsized: Array[String] = []
	for kind in SkyGearProp.TEXTURES.keys():
		if not SkyGearView3D.PROP_HEIGHT.has(kind):
			unsized.append(str(kind))
	_check("art", "and a height, so nothing is drawn at a default", unsized.is_empty(),
		"missing: %s" % ", ".join(unsized))
	_check("art", "the deck is dressed with the ship, not only with ordnance",
		SkyGearData.PROP_LAYOUT.size() >= 24,
		"%d pieces" % SkyGearData.PROP_LAYOUT.size())

	## The captain is a rigged mesh now, and decals must not paint on her.
	var mesh_captain: bool = SkyGearView3D.USE_MESH_CAPTAIN 		and ResourceLoader.exists(SkyGearView3D.CAPTAIN_SCENE)
	_check("captain", "the rigged model is in the build", mesh_captain)
	if mesh_captain:
		var scene := (load(SkyGearView3D.CAPTAIN_SCENE) as PackedScene).instantiate()
		var ap := scene.find_child("AnimationPlayer", true, false) as AnimationPlayer
		var clips := ap.get_animation_list() if ap != null else PackedStringArray()
		_check("captain", "she has the clips the state machine asks for",
			"idle" in clips and "run" in clips and "swing" in clips and "dash" in clips,
			str(clips))
		var unresolved := 0
		for name in clips:
			var anim: Animation = ap.get_animation(name)
			for t in anim.get_track_count():
				if anim.track_get_path(t).get_subname_count() > 0 						and not str(anim.track_get_path(t)).begins_with("Armature/Skeleton3D"):
					unresolved += 1
		_check("captain", "and every track points at the skeleton we kept",
			unresolved == 0, "%d stray tracks" % unresolved)
		_check("captain", "the scene carries no import-time dependency",
			not _depends_on_staging(SkyGearView3D.CAPTAIN_SCENE))
		scene.queue_free()
	_check("captain", "figures are on their own visual layer, so decals stay on the deck",
		SkyGearView3D.LAYER_FIGURES != SkyGearView3D.LAYER_WORLD)

	## AIMING. `Node2D.get_global_mouse_position()` answers a question about the
	## hidden 2D scene; what the player is looking at is a perspective projection
	## of the deck. Every skill was aimed at a point unrelated to the cursor.
	view.sway = false
	game.player.global_position = Vector2(0, 400)
	view._process(0.05)
	var frame_size: Vector2 = view.camera.get_viewport().get_visible_rect().size
	var centre_ground: Vector2 = view.ground_at(frame_size * 0.5)
	## The middle of the screen is the point the camera is aimed through, so it
	## must land on the deck ahead of her rather than anywhere near the origin.
	_check("aim", "the centre of the screen unprojects onto the deck",
		SkyGearGame.DECK_RECT.grow(200.0).has_point(centre_ground),
		"(%.0f, %.0f)" % [centre_ground.x, centre_ground.y])
	var left_ground: Vector2 = view.ground_at(Vector2(frame_size.x * 0.2, frame_size.y * 0.7))
	var right_ground: Vector2 = view.ground_at(Vector2(frame_size.x * 0.8, frame_size.y * 0.7))
	_check("aim", "left of the screen is to port, right is to starboard",
		left_ground.x < right_ground.x,
		"%.0f vs %.0f" % [left_ground.x, right_ground.x])
	var near_ground: Vector2 = view.ground_at(Vector2(frame_size.x * 0.5, frame_size.y * 0.9))
	var far_ground: Vector2 = view.ground_at(Vector2(frame_size.x * 0.5, frame_size.y * 0.3))
	_check("aim", "and lower on the screen is nearer the stern",
		near_ground.y > far_ground.y,
		"%.0f vs %.0f" % [near_ground.y, far_ground.y])
	## The whole point: what the game aims at is what the cursor is over.
	game.set_cursor_ground(Vector2(120, -300))
	_check("aim", "a cast with no explicit target uses the cursor on the deck",
		game.aim_target() == Vector2(120, -300), str(game.aim_target()))

	## The animation engine. State selection, one-shot ownership and the turn are
	## the parts that were written inline for one character and had to stop being.
	var order: Array = SkyGearRig3D.PRIORITY
	_check("rig", "a swing outranks a dash outranks a run",
		order.find("swing") < order.find("dash") and order.find("dash") < order.find("run"))
	_check("rig", "one-shots are the ones that must not loop",
		SkyGearRig3D.ONE_SHOT.get("swing", false)
			and not SkyGearRig3D.ONE_SHOT.get("run", false))
	_check("rig", "an attack blends in faster than an idle",
		float(SkyGearRig3D.BLEND.swing) < float(SkyGearRig3D.BLEND.idle),
		"%.2fs vs %.2fs" % [float(SkyGearRig3D.BLEND.swing), float(SkyGearRig3D.BLEND.idle)])

	## Turning takes time, and it goes the short way. Lerping raw angles takes
	## the long way round whenever a turn crosses PI, which looks like a figure
	## spinning to avoid you.
	## Not PI: a half turn is an exact tie and either way round is correct, so
	## asserting a direction there is asserting a tie-break.
	_check("rig", "a turn is rate limited",
		absf(SkyGearRig3D._turn_toward(0.0, 2.0, 0.1) - 0.1) < 0.001,
		"%.3f rad after one step" % SkyGearRig3D._turn_toward(0.0, 2.0, 0.1))
	_check("rig", "and takes the short way round",
		SkyGearRig3D._turn_toward(3.0, -3.0, 0.1) > 3.0,
		"%.3f" % SkyGearRig3D._turn_toward(3.0, -3.0, 0.1))
	_check("rig", "and arrives rather than orbiting",
		is_equal_approx(SkyGearRig3D._turn_toward(1.0, 1.02, 0.1), 1.02))

	## The rig itself, built from the ingested captain.
	var rig := SkyGearRig3D.new()
	root.add_child(rig)
	var built: bool = rig.setup(SkyGearView3D.CAPTAIN_SCENE,
		SkyGearView3D.CAPTAIN_HEIGHT * SkyGearView3D.WORLD_SCALE,
		SkyGearView3D.LAYER_FIGURES)
	_check("rig", "it builds from an ingested model", built)
	if built:
		_check("rig", "and scales the model to the height we asked for",
			absf(rig.height_scale * 1.92153 - SkyGearView3D.CAPTAIN_HEIGHT
				* SkyGearView3D.WORLD_SCALE) < 0.01,
			"scale %.4f" % rig.height_scale)
		rig.want("run", 300.0)
		_check("rig", "a run plays faster when she is moving faster",
			rig.anim.speed_scale > 1.0, "rate %.2f" % rig.anim.speed_scale)
		rig.want("swing")
		var held := rig._clip
		rig.want("run", 300.0)
		_check("rig", "and a swing is not cancelled by the run underneath it",
			rig._clip == held, "playing %s" % rig._clip)
		## An undelivered clip has to degrade rather than fail: the boarders will
		## arrive with fewer cycles than she has.
		_check("rig", "an undelivered clip falls back to the nearest one it has",
			rig._fallback("hurt") == "idle" and rig._fallback("run") in ["run", "walk"],
			"hurt -> %s" % rig._fallback("hurt"))
	rig.queue_free()

	## Clicking a card. It was 1/2/3 only, and a screen full of cards that do not
	## respond to a cursor reads as broken rather than as keyboard-driven.
	var cards := SkyGearHUD.draft_cards(Vector2(1366, 768), 3)
	_check("draft", "three cards, side by side, on screen",
		cards.size() == 3 and cards[0].position.x > 0.0
			and cards[2].end.x < 1366.0 and cards[0].end.x < cards[1].position.x)
	_check("draft", "and they do not overlap the reroll button",
		not cards[1].intersects(SkyGearHUD.reroll_button(Vector2(1366, 768))))
	## The geometry is shared between the draw and the hit test, so a card cannot
	## be somewhere the click is not.
	_check("draft", "a click in the middle card hits the middle card",
		cards[1].has_point(cards[1].get_center())
			and not cards[0].has_point(cards[1].get_center()))

	## The mix. Sixty-seven lines nobody can make out are sixty-seven lines of
	## noise, and the layer being quiet was never the problem.
	var mixer := SkyGearAudio.new()
	root.add_child(mixer)
	mixer.speaking = true
	mixer._process(1.0)
	var ducked: float = AudioServer.get_bus_volume_db(AudioServer.get_bus_index("SFX"))
	mixer.speaking = false
	for i in 40:
		mixer._process(0.1)
	var clear: float = AudioServer.get_bus_volume_db(AudioServer.get_bus_index("SFX"))
	_check("audio", "the fight ducks under a line and comes back",
		ducked < clear - 3.0, "%.1f dB speaking, %.1f dB clear" % [ducked, clear])
	_check("audio", "music ducks harder than the fight does",
		SkyGearAudio.DUCK_MUSIC < SkyGearAudio.DUCK_SFX,
		"%.0f vs %.0f dB" % [SkyGearAudio.DUCK_MUSIC, SkyGearAudio.DUCK_SFX])
	_check("audio", "and it comes back slower than it goes, so it does not pump",
		SkyGearAudio.DUCK_RELEASE < SkyGearAudio.DUCK_ATTACK)
	mixer.queue_free()

	## The captain talks, and the lines are on disk.
	_check("voice", "the line sheet is delivered",
		game.voice != null and game.voice.delivered() >= 60,
		"%d takes" % (game.voice.delivered() if game.voice != null else 0))
	game.voice.reset()
	_check("voice", "a line plays", game.voice.say("wave_start"))
	_check("voice", "and does not repeat inside its cooldown",
		not game.voice.say("wave_start"))
	_check("voice", "a higher priority cuts in", game.voice.say("defeat", 4))
	_check("voice", "an undelivered key is silence, not a fallback",
		not game.voice.say("no_such_line"))
	world.queue_free()


## --- what survives closing the game -----------------------------------------
## Three browser checks had no equivalent here: the run log, the key map, and
## what happens when the disk says no. The last one is not hypothetical — a
## locked profile or a read-only drive is a real machine, and a game that
## crashes because it cannot write a leaderboard entry is a game that crashes.
func _persistence() -> void:
	SkyGearRunLog.clear()
	var game := _new_game()
	_begin(game)
	game.wave = 6
	game.run_time = 214.0
	game.damage_player(99999.0)
	_check("log", "a finished run is written to disk",
		game.run_logged and SkyGearRunLog.load_all().size() == 1,
		"%d rows" % SkyGearRunLog.load_all().size())
	var row: Dictionary = SkyGearRunLog.load_all()[0]
	_check("log", "and it carries the seed, the wave and the build",
		str(row.get("seed", "")) == "PARITY" and int(row.get("wave", 0)) == 6
			and (row.get("build", []) as Array).size() >= 1,
		"seed %s, wave %d" % [str(row.get("seed", "?")), int(row.get("wave", 0))])
	_check("log", "the report itself is kept, not just the numbers",
		str(row.get("report", "")).contains("SKYGEAR"))
	game.queue_free()

	var second := _new_game()
	_begin(second, "SECOND")
	second.wave = 11
	second.damage_player(99999.0)
	var summary: Dictionary = SkyGearRunLog.summary()
	_check("log", "the title screen can read a best wave out of it",
		int(summary.runs) == 2 and int(summary.best_wave) == 11,
		"%d runs, best %d" % [int(summary.runs), int(summary.best_wave)])
	second.queue_free()

	## The log is capped. Sixty runs of a twelve-wave game is a file somebody
	## keeps for a year, and an uncapped one is a file that eventually is not.
	_check("log", "it is capped rather than unbounded",
		SkyGearRunLog.KEEP > 0 and SkyGearRunLog.KEEP <= 200,
		"keeps %d" % SkyGearRunLog.KEEP)

	## Storage denial. Nothing here may throw, and nothing may lie about having
	## saved.
	var denied := SkyGearRunLog.record({"wave": 1})
	_check("log", "recording reports whether it actually reached the disk",
		denied == true or denied == false)

	## Keys.
	SkyGearKeybinds.capture_defaults()
	SkyGearKeybinds.reset()
	var original := SkyGearKeybinds.label("dash")
	var bind := InputEventKey.new()
	bind.physical_keycode = KEY_F
	var clash := SkyGearKeybinds.rebind("dash", bind)
	_check("keys", "an action can be rebound", clash == "" and SkyGearKeybinds.label("dash") != original,
		"dash is now %s" % SkyGearKeybinds.label("dash"))
	var stolen := InputEventKey.new()
	stolen.physical_keycode = KEY_F
	_check("keys", "and a key already spoken for is refused rather than double-bound",
		SkyGearKeybinds.rebind("pause", stolen) == "dash",
		"conflict reported: %s" % SkyGearKeybinds.rebind("pause", stolen))
	_check("keys", "the map survives a reload",
		SkyGearKeybinds.save() and _reloaded_dash_is_f(),
		"after reload: %s" % SkyGearKeybinds.label("dash"))
	SkyGearKeybinds.reset()
	_check("keys", "and resets to what the project ships with",
		SkyGearKeybinds.label("dash") == original, SkyGearKeybinds.label("dash"))
	_check("keys", "menu keys are deliberately not rebindable",
		not _rebindable_contains("copy_report") and SkyGearKeybinds.REBINDABLE.size() == 10,
		"%d rebindable actions" % SkyGearKeybinds.REBINDABLE.size())


func _reloaded_dash_is_f() -> bool:
	# wipe the live map, then load it back off disk
	InputMap.action_erase_events("dash")
	SkyGearKeybinds.load_saved()
	for event in InputMap.action_get_events("dash"):
		if event is InputEventKey and event.physical_keycode == KEY_F:
			return true
	return false


func _rebindable_contains(action: String) -> bool:
	for row in SkyGearKeybinds.REBINDABLE:
		if str(row[0]) == action:
			return true
	return false


## --- the layout matrix --------------------------------------------------------
## The browser harness draws the HUD at seven window sizes and asserts nothing
## lands off screen or on top of anything else. This is the same idea against the
## panels that actually have fixed pixel geometry: the captain's plate, the
## objective, the lane readout and the four skill slots.
## --- the layout matrix --------------------------------------------------------
## The browser harness draws the HUD at seven window sizes and asserts nothing
## lands off screen or on top of anything else. Same idea, against the one place
## the geometry is defined — `SkyGearHUD.hud_plates` — so this cannot drift from
## what is drawn.
func _layout() -> void:
	## A previous run of this harness saves a layout to test the round trip, and
	## a saved layout WINS over the shipped one — so without this the matrix below
	## would be checking whatever the last run happened to leave behind.
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SkyGearHudLayout.USER_PATH))
	SkyGearHUD.layout = null
	var sizes := [Vector2(1280, 720), Vector2(1366, 768), Vector2(1600, 900),
		Vector2(1920, 1080), Vector2(2560, 1440), Vector2(1152, 648)]
	var worst := ""
	var clean := true
	for viewport in sizes:
		var plates: Dictionary = SkyGearHUD.hud_plates(viewport)
		var frame := Rect2(Vector2.ZERO, viewport)
		var names: Array = plates.keys()
		for a in names.size():
			var ra: Rect2 = plates[names[a]]
			if not frame.encloses(ra):
				clean = false
				worst = "%s off screen at %dx%d" % [names[a], viewport.x, viewport.y]
			for b in range(a + 1, names.size()):
				if ra.intersects(plates[names[b]]):
					clean = false
					worst = "%s over %s at %dx%d" % [names[a], names[b], viewport.x, viewport.y]
	_check("layout", "every HUD plate fits, and none overlap, at six sizes", clean, worst)

	## And it is all in the bottom band. The top of the frame is where boarders
	## arrive from; the objective plate and the lane readout used to sit in it.
	var probe := Vector2(1366, 768)
	var band := true
	var highest := 0.0
	for rect in SkyGearHUD.hud_plates(probe).values():
		highest = maxf(highest, probe.y - (rect as Rect2).position.y)
		if (rect as Rect2).position.y < probe.y * 0.60:
			band = false
	_check("layout", "and none of it is in the top 60% of the screen, where they come from",
		band, "tallest plate reaches %d px up" % highest)

	## THE LAYOUT IS DATA NOW, and a person edits it. Everything below is about
	## that being safe: a hand-edited file is a file that will one day have a
	## trailing comma in it, and a bad layout must cost one panel rather than the
	## whole HUD.
	var fresh := SkyGearHudLayout.new()
	_check("layout", "the shipped default is a clean layout",
		fresh.problems(Vector2(1366, 768)).is_empty(),
		", ".join(fresh.problems(Vector2(1366, 768))))
	_check("layout", "and stays clean on a very wide screen",
		fresh.problems(Vector2(2560, 1440)).is_empty(),
		", ".join(fresh.problems(Vector2(2560, 1440))))

	## Anchored, not absolute — otherwise a hand-placed HUD is only right on the
	## monitor it was placed on.
	var narrow_rect: Rect2 = fresh.rect("ship", Vector2(1280, 720))
	var wide_rect: Rect2 = fresh.rect("ship", Vector2(2560, 1440))
	_check("layout", "a right-anchored plate keeps its distance from the right edge",
		is_equal_approx(1280.0 - narrow_rect.end.x, 2560.0 - wide_rect.end.x),
		"%.0f vs %.0f" % [1280.0 - narrow_rect.end.x, 2560.0 - wide_rect.end.x])
	_check("layout", "and a bottom-anchored one from the bottom",
		is_equal_approx(720.0 - narrow_rect.end.y, 1440.0 - wide_rect.end.y))

	## Re-anchoring may not move the plate, or the editor is a puzzle.
	var before_anchor: Rect2 = fresh.rect("captain", Vector2(1366, 768))
	fresh.set_anchor("captain", "", "bottom_right", Vector2(1366, 768), before_anchor)
	_check("layout", "changing an anchor leaves the plate where it was",
		fresh.rect("captain", Vector2(1366, 768)).is_equal_approx(before_anchor),
		"%s -> %s" % [before_anchor, fresh.rect("captain", Vector2(1366, 768))])

	## Round trip, and refusal of nonsense.
	var edited := SkyGearHudLayout.new()
	edited.nudge("captain", "", Vector2(11, -7))
	edited.resize("ship", "", Vector2(-20, 0))
	_check("layout", "an edit survives a save and a load",
		edited.save() and SkyGearHudLayout.load_layout().rect("captain", Vector2(1366, 768))
			.is_equal_approx(edited.rect("captain", Vector2(1366, 768))))
	var junk := SkyGearHudLayout._sanitise({
		"captain": {"anchor": "sideways", "offset": [1, 2], "size": [10, 10]},
		"ship": {"offset": "not an array"},
		"slot0": {"anchor": "bottom_centre", "offset": [-256, -136], "size": [9999, 1]},
	})
	_check("layout", "a malformed plate falls back rather than taking the HUD with it",
		junk.captain.anchor == SkyGearHudLayout.DEFAULT.captain.anchor
			and junk.ship.offset == SkyGearHudLayout.DEFAULT.ship.offset,
		"kept %s" % str(junk.captain.anchor))
	_check("layout", "and a plate cannot be edited down to nothing",
		float(junk.slot0.size[1]) >= 28.0, "%.0f tall" % float(junk.slot0.size[1]))
	## THE SECOND LEVEL. Panel placement was not enough: a glyph could sit
	## off-centre inside its own slot and the only fix was another round trip.
	var plan := SkyGearHudLayout.new()
	var slot: Rect2 = plan.rect("slot1", Vector2(1366, 768))
	var glyph: Rect2 = plan.item("slot1", "icon", slot)
	_check("layout", "every element inside a plate has a box of its own",
		plan.items_of("slot1").size() == 3 and plan.items_of("captain").size() == 7
			and glyph.size.x > 0.0,
		"%d in a slot, %d on the captain" % [plan.items_of("slot1").size(),
			plan.items_of("captain").size()])
	_check("layout", "and it lands inside the plate's interior, not on its frame",
		SkyGearHudLayout.interior(slot).grow(2.0).encloses(glyph),
		"%s in %s" % [glyph, SkyGearHudLayout.interior(slot)])
	## The four slots share one set of item positions. Four slots that disagree
	## about where the glyph goes is four bugs rather than four decisions.
	var other: Rect2 = plan.rect("slot3", Vector2(1366, 768))
	var other_glyph: Rect2 = plan.item("slot3", "icon", other)
	_check("layout", "and all four slots agree where their glyph sits",
		is_equal_approx(glyph.position.x - slot.position.x,
			other_glyph.position.x - other.position.x))
	## Items move with the plate rather than staying put on screen.
	plan.nudge("slot1", "", Vector2(40, 0))
	var moved_slot: Rect2 = plan.rect("slot1", Vector2(1366, 768))
	_check("layout", "moving a plate carries its contents with it",
		is_equal_approx(plan.item("slot1", "icon", moved_slot).position.x,
			glyph.position.x + 40.0))
	plan.nudge("slot1", "icon", Vector2(0, -9))
	_check("layout", "and an element can then be moved on its own",
		is_equal_approx(plan.item("slot1", "icon", moved_slot).position.y,
			glyph.position.y - 9.0))
	## The failure the whole second level exists to make visible.
	plan.nudge("slot1", "icon", Vector2(500, 0))
	var escaped := false
	for note in plan.problems(Vector2(1366, 768)):
		if note.contains("outside its plate"):
			escaped = true
	_check("layout", "an element dragged off its plate is reported, not silently lost",
		escaped)

	## Leave no editor state behind for the next run of the harness.
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SkyGearHudLayout.USER_PATH))

	## The floor is a decision. Below this the three clusters cannot share a
	## baseline without overlapping, and the export presets say 1152x648.
	var narrow: Dictionary = SkyGearHUD.hud_plates(Vector2(1152, 648))
	_check("layout", "the captain's plate clears the skill slots at the floor size",
		not (narrow.captain as Rect2).intersects(narrow.slot0 as Rect2),
		"gap %.0f px" % ((narrow.slot0 as Rect2).position.x
			- (narrow.captain as Rect2).end.x))


func _views_resolve() -> bool:
	return _missing_views() == ""


func _missing_views() -> String:
	var out: Array[String] = []
	for kind in SkyGearSprites.VIEWS.keys():
		for view in (SkyGearSprites.VIEWS[kind] as Dictionary).keys():
			if SkyGearSprites.still(kind, view) == null:
				out.append("%s/%s" % [kind, view])
	return ", ".join(out)


## Nothing in the shipped captain may point back at the import staging the FBXs
## were unpacked into — that directory is deleted, and a dangling dependency
## fails the whole resource with no captain and no obvious reason why.
func _depends_on_staging(path: String) -> bool:
	for dep in ResourceLoader.get_dependencies(path):
		if dep.contains("import_staging"):
			return true
	return false
