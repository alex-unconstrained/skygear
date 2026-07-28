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
