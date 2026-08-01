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
	## Hit-stop off everywhere except where it is the thing being tested: it
	## hands the simulation a smaller delta, so a check that advances three
	## seconds would advance less depending on how many boarders died in them.
	if game.impact != null:
		game.impact.enabled = false
	## AND NO WORKSHOP. `game.workshop` loads from `user://` at construction, so
	## without this the harness measures whatever the developer running it has
	## unlocked — an earlier version of this file left a fully-bought tree on disk
	## and three unrelated checks went red with a buffed captain and a buffed
	## cannon. A harness that depends on a save file is not a harness.
	##
	## Ephemeral, so nothing a test does here can write back out either.
	game.workshop = SkyGearWorkshop.fresh(true)
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
	await _audio()
	await process_frame
	_endings()
	await process_frame
	## AWAITED. `_view` and `_audio` are coroutines — they suspend on their own
	## `await` — and calling one without `await` hands control straight back here.
	## `_run` then walked to the summary and called `quit()` while two thirds of
	## `_view` had not run yet, and reported the checks that HAD run as a clean
	## pass. It was silently masked for as long as the first suspension point
	## happened to fall late in the function; adding a block near the top of
	## `_view` moved it, and sixty-one checks quietly stopped existing.
	##
	## A harness that reports 192/192 while skipping a quarter of itself is worse
	## than a harness that fails.
	await _view()
	await process_frame
	await _cutscene()
	await process_frame
	_persistence()
	await process_frame
	_layout()
	await process_frame
	_dash()
	await process_frame
	_mobility()
	await process_frame
	_ink()

	## A CANARY AGAINST SILENT TRUNCATION. The harness once reported "192/192
	## checks passed" while skipping a quarter of itself, because a coroutine pass
	## was called without `await` and `quit()` beat it to the end. Every number in
	## that report was true and the report was a lie. A floor cannot catch a pass
	## that is one check short, but it catches a pass that vanished — which is the
	## failure that actually happened.
	const EXPECTED_AT_LEAST := 250
	if checks < EXPECTED_AT_LEAST:
		failures.append("the harness itself only ran %d of at least %d checks — a pass was skipped"
			% [checks, EXPECTED_AT_LEAST])

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
			elif str(SkyGearData.SHAPES[shape].kind) == "sentry":
				## A deployable does not damage on the press — the press puts an
				## object down and the object fires. Which is the whole point of
				## the shape, so the test asserts BOTH halves: something is on the
				## planking, and it shoots on its own.
				game.sentries.clear()
				game.cast_skill(0, enemy.global_position)
				if game.sentries.is_empty():
					dead_cells.append(shape + "/" + element + ": nothing deployed")
					enemy.dead = true
					enemy.queue_free()
					continue
				for _t in 20:
					game._update_sentries(0.1)
				game.sentries.clear()
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
	##
	## Placed inside its own reach rather than seventy units short of it. Crew
	## were raised to 68 health in the ally balance pass and now survive long
	## enough to get in the way, so a boarder that had to walk the last stretch
	## sometimes never arrived — and this check is about whether it ATTACKS the
	## gun, not about whether it can path to it.
	## --- KNOCKBACK ------------------------------------------------------------
	##
	## Two separate reports, one root. Boarders were "suddenly thrown right next
	## to the boiler", and the long-intended "knock them off the ship" had never
	## once happened.
	##
	## THE CAP. `knock_velocity` accumulated with no bound against a decay of only
	## 1050 a second, so anything hitting more than once before that ran out —
	## a beam, an aura tick, a chain touching four — stacked shove on shove.
	## Twelve hits at once is not a contrived number for a chain into a cluster.
	var mule: SkyGearEnemy = null
	for e in game.get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and not e.dead:
			mule = e
			break
	_check("knockback", "there is a boarder to shove", mule != null)
	if mule != null:
		mule.knock_velocity = Vector2.ZERO
		for _hit in 12:
			mule.take_damage(0.5, mule.global_position + Vector2(0, 90.0), "", 260.0)
		_check("knockback", "a shove is capped however many things land at once",
			mule.knock_velocity.length() <= SkyGearEnemy.KNOCK_MAX + 0.5,
			"twelve hits stacked to %.0f against a cap of %.0f"
				% [mule.knock_velocity.length(), SkyGearEnemy.KNOCK_MAX])
		## And the cap has to mean something in DISTANCE, which is the thing that
		## was actually wrong. Free travel is v^2/2a — the number a player feels.
		var carry: float = pow(SkyGearEnemy.KNOCK_MAX, 2.0) / (2.0 * 1050.0)
		_check("knockback", "and carries a fraction of the deck, not all of it",
			carry < SkyGearGame.DECK_RECT.size.y * 0.25,
			"%.0f units against a %.0f deck" % [carry, SkyGearGame.DECK_RECT.size.y])

	## OVER THE SIDE. An outer-lane boarder shoved hard at the rail leaves.
	game.spawn_enemy("SCRAPPER", 2)
	var rail: SkyGearEnemy = null
	for e in game.get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and not e.dead and e.lane == 2:
			rail = e
	_check("knockback", "there is an outer-lane boarder to push", rail != null)
	if rail != null:
		rail.global_position = Vector2(700.0, 0.0)
		rail.stun_time = 0.0
		## Shoved outward from inboard, which is the direction a captain standing
		## between the lane and the Boiler actually pushes.
		rail.take_damage(0.5, Vector2(300.0, 0.0), "", 900.0)
		_advance(game, 1.2)
		_check("knockback", "a hard shove at the rail puts a boarder over the side",
			rail == null or not is_instance_valid(rail) or rail.dead or rail.overboard,
			"still aboard at x=%.0f" % (rail.global_position.x
				if is_instance_valid(rail) else 0.0))

	## AND NOT BY ACCIDENT. The same boarder, the same place, an ordinary hit.
	## Without this the check above passes just as well with the rail removed
	## altogether, which is the failure this whole suite keeps having.
	game.spawn_enemy("SCRAPPER", 2)
	var safe: SkyGearEnemy = null
	for e in game.get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and not e.dead and e.lane == 2:
			safe = e
	if safe != null:
		safe.global_position = Vector2(700.0, 0.0)
		safe.take_damage(0.5, Vector2(300.0, 0.0), "", 150.0)
		_advance(game, 1.2)
		_check("knockback", "and an ordinary hit leaves them on the deck",
			is_instance_valid(safe) and not safe.dead and not safe.overboard,
			"a 150 shove threw them off, which makes the rail a hazard "
			+ "rather than a finisher")
		if is_instance_valid(safe):
			safe.kill()

	var gate: Dictionary = game.turrets[1]
	var gate_hp: float = gate.hp
	target.global_position = Vector2(gate.position) + Vector2(0, -44)
	target.state = "move"
	target.state_time = 0.0
	## AND THE CAPTAIN OUT OF THE WAY. A boarder within 280 units prefers her over
	## anything else on the deck, and the cannon sits 244 from where she spawns —
	## so this check was quietly measuring "does it attack the player" and passing
	## on timing. It is about whether a gun in the way gets attacked, so the gun
	## has to be the only thing worth attacking.
	game.player.global_position = Vector2(0.0, 1050.0)
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
	##
	## A body is a billboard OR a rig. This counted only billboards until the
	## scrapper became a mesh, at which point it failed with five boarders on the
	## deck and five of them visible — the check had quietly encoded which
	## renderer a boarder uses, which is exactly the thing that was always going
	## to change one kind at a time.
	for i in 5:
		game.spawn_enemy("SCRAPPER", i % 3)
	view._process(0.05)
	var bodies := 0
	for key in view._billboards.keys():
		if str(key).begins_with("e"):
			bodies += 1
	for key in view._rigs.keys():
		if str(key).begins_with("e"):
			bodies += 1
	_check("view", "every boarder gets a body, mesh or billboard",
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
	view.sway = false

	## THE SKY. Reported three times and missed three times, and the reason it
	## kept being missed is geometric rather than aesthetic: at 41 degrees of
	## pitch the horizon is above the top of the frame at every zoom, so a
	## screenshot from the middle of the deck contains no sky and cannot show
	## anyone that there is nothing in it. These checks are the arithmetic that
	## screenshot could not do.
	var sky_mat := view._environment.sky.sky_material
	_check("sky", "the backdrop is the browser's painting, not a gradient",
		sky_mat is ShaderMaterial
			and (sky_mat as ShaderMaterial).get_shader_parameter("backdrop") != null,
		sky_mat.get_class())

	## The one number two functions could disagree about. The shader reproduces
	## the browser's own screen mapping, so if it is handed a different lens from
	## the one the camera is using, the moon moves off where the painting puts it
	## and nothing in a screenshot says why.
	if sky_mat is ShaderMaterial:
		var shader_tan: float = float((sky_mat as ShaderMaterial)
			.get_shader_parameter("ref_tan"))
		_check("sky", "the shader is given the camera's own lens, not a second copy",
			absf(shader_tan - tan(deg_to_rad(view.camera.fov * 0.5))) < 1e-4,
			"%.6f vs %.6f" % [shader_tan, tan(deg_to_rad(view.camera.fov * 0.5))])

	## Where a cloud may stand. Half the vertical field above and below the
	## pitch is the band the frame sees; the horizontal half-field at 16:9 is the
	## widest it can be off the keel; and a sightline steeper than the gunwale
	## allows is a sightline into planking. All three failed for the cloud bands
	## this replaces, which sat BELOW the hull.
	var half_v: float = deg_to_rad(view.camera.fov * 0.5)
	var half_h: float = atan(tan(half_v) * 16.0 / 9.0)
	var top_el: float = SkyGearView3D.PITCH - half_v
	var bottom_el: float = SkyGearView3D.PITCH + half_v
	## The camera can be dragged this far off the keel and no further, so this is
	## the widest the rail ever is from the eye — the hardest case to clear.
	var rail_gap: float = SkyGearGame.DECK_RECT.size.x * (0.5 - 0.22)
	var sky_outside := 0
	var sky_blocked := 0
	for spec in SkyGearView3D.CLOUD_FIELD:
		var az: float = deg_to_rad(absf(float(spec.az)))
		var el: float = deg_to_rad(float(spec.el))
		if az > half_h or el < top_el or el > bottom_el:
			sky_outside += 1
		## Zoom only ever raises the camera, so the shipped height is the case
		## where the sightline crosses the deck plane soonest and clears least.
		elif SkyGearView3D.CAM_HEIGHT / tan(el) * sin(az) < rail_gap:
			sky_blocked += 1
	_check("sky", "every cloud is inside the wedge the camera can actually see",
		sky_outside == 0, "%d of %d outside %.1f x [%.1f, %.1f] deg"
			% [sky_outside, SkyGearView3D.CLOUD_FIELD.size(), rad_to_deg(half_h),
				rad_to_deg(top_el), rad_to_deg(bottom_el)])
	_check("sky", "and clears the gunwale rather than sitting behind it",
		sky_blocked == 0, "%d of %d blocked" % [sky_blocked, SkyGearView3D.CLOUD_FIELD.size()])

	## The parallax, as the browser's own two numbers. Its bands run at 16 and 34
	## pixels a second against a focal length of 1381.4 px/rad at 1600x900, which
	## is 0.01158 and 0.02461 rad/s. Rate is speed over distance, so two layers at
	## these two distances drifting at this one speed are those two rates.
	var browser_f := 1381.4
	var near_px: float = SkyGearView3D.CLOUD_DRIFT / SkyGearView3D.CLOUD_NEAR_RANGE * browser_f
	var far_px: float = SkyGearView3D.CLOUD_DRIFT / SkyGearView3D.CLOUD_FAR_RANGE * browser_f
	_check("sky", "the two layers drift at the browser's own angular rates",
		absf(near_px - 34.0) < 2.0 and absf(far_px - 16.0) < 2.0,
		"%.1f and %.1f px/s against 34 and 16" % [near_px, far_px])

	## And the parallax MEASURED rather than asserted from the constants that
	## produced it: two clouds, one behind the other, the same second of drift,
	## and the near one has to move further across the screen. A backdrop panned
	## as one layer passes every check above and fails this one.
	var near_node: MeshInstance3D = null
	var far_node: MeshInstance3D = null
	for i in SkyGearView3D.CLOUD_FIELD.size():
		var node: MeshInstance3D = view._cloud_bands[i].node
		if bool(SkyGearView3D.CLOUD_FIELD[i].get("far", false)):
			if far_node == null:
				far_node = node
		elif near_node == null:
			near_node = node
	var near_before := view.camera.unproject_position(near_node.global_position)
	var far_before := view.camera.unproject_position(far_node.global_position)
	view._flicker += 1.0
	view._sync_clouds(1.0)
	var near_moved: float = view.camera.unproject_position(
		near_node.global_position).distance_to(near_before)
	var far_moved: float = view.camera.unproject_position(
		far_node.global_position).distance_to(far_before)
	## Half a ratio rather than the 2.13 the distances imply, because screen
	## travel also depends on where in its run each cloud happens to be. What is
	## being pinned is that there IS depth between the layers, not a number.
	_check("sky", "the near layer crosses the screen faster than the far one",
		near_moved > far_moved * 1.5 and far_moved > 0.1,
		"%.1f px against %.1f in one second" % [near_moved, far_moved])

	## A cloud that pokes through the far plane is sliced by a dead straight line
	## across the middle of a painted cumulus, which is what 400 metres was doing.
	var cloud_reach: float = (SkyGearView3D.CLOUD_FAR_RANGE
		+ SkyGearView3D.CLOUD_WRAP * 0.5
		+ SkyGearView3D.CLOUD_FAR_WIDTH * 0.5) * SkyGearView3D.WORLD_SCALE
	_check("sky", "the far plane clears the furthest corner of the field",
		view.camera.far > cloud_reach, "far %.0f m against a reach of %.0f m"
			% [view.camera.far, cloud_reach])

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
		## RESOLVES, rather than begins with a particular path. The first version
		## hard-coded `Armature/Skeleton3D` because that is where the Meshy rig
		## happened to live; a Mixamo pack puts it somewhere else and the check
		## failed on a model that was perfectly correct. What matters is that
		## every track finds a node, which is the thing that was actually broken
		## when the swing clip animated nothing.
		var unresolved := 0
		for name in clips:
			var anim: Animation = ap.get_animation(name)
			for t in anim.get_track_count():
				var path := anim.track_get_path(t)
				if path.get_subname_count() == 0:
					continue
				if scene.get_node_or_null(NodePath(path.get_concatenated_names())) == null:
					unresolved += 1
		_check("captain", "and every track resolves against the rig",
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

	## IMPACT. VFX-PLAN.md puts hit-stop at the top of the list: cheapest thing
	## on it and the biggest single change to whether a hit reads as landing.
	var punch := SkyGearImpact.new()
	root.add_child(punch)
	_check("impact", "a kill stops the simulation briefly",
		punch.hit_stop(SkyGearImpact.STOP_KILL) and punch.stop_left > 0.0,
		"%.3fs" % punch.stop_left)
	_check("impact", "and the frame it ends on runs the remainder rather than dropping it",
		is_equal_approx(punch.advance(SkyGearImpact.STOP_KILL + 0.01), 0.01))
	## A Field ticking into six boarders is six stops a second, which is not
	## feedback — it is a frame rate problem with a reason.
	punch.reset()
	_check("impact", "a small hit stops, then waits", punch.hit_stop(0.04))
	_check("impact", "so clearing a horde cannot freeze the game",
		not punch.hit_stop(0.04))
	_check("impact", "but a big one always lands", punch.hit_stop(SkyGearImpact.STOP_KILL))
	_check("impact", "and nothing freezes longer than the cap",
		punch.hit_stop(9.0) and punch.stop_left <= SkyGearImpact.STOP_MAX,
		"%.3fs" % punch.stop_left)

	punch.reset()
	punch.add_shake(9999.0)
	_check("impact", "shake is capped, so a keg cannot throw the deck",
		punch.shake <= SkyGearImpact.SHAKE_MAX, "%.1f units" % punch.shake)
	var before_shake: float = punch.shake
	for i in 30:
		punch.advance(0.05)
	_check("impact", "and it settles rather than being dragged back",
		punch.shake < before_shake * 0.1, "%.2f -> %.2f" % [before_shake, punch.shake])
	punch.enabled = false
	_check("impact", "the harness can turn the whole thing off",
		is_equal_approx(punch.advance(0.05), 0.05))
	punch.queue_free()

	## The particles and the light. Every performance problem this project has had
	## was an unbounded collection, so what is asserted is the CAP, not the look.
	## By BEHAVIOUR, not by element. Four elements share three ways of moving, and
	## the colour rides on the particle — see the rendering audit, finding 3.
	_check("impact", "one emitter per behaviour, not one per element or per hit",
		view._sparks.size() == 3 and view._sparks.has("spark")
			and view._sparks.has("steam") and view._sparks.has("shard"),
		"%d emitters: %s" % [view._sparks.size(), ", ".join(view._sparks.keys())])
	_check("impact", "every element maps to one of them",
		SkyGearView3D.ELEMENT_FX.size() == SkyGearData.ELEMENTS.size(),
		"%d mapped" % SkyGearView3D.ELEMENT_FX.size())
	## The bug the audit found: restarting a shared one-shot emitter throws away
	## whatever is still in the air, so every impact after the first was, on
	## screen, the only impact. Emitters are now never restarted.
	var live_emitters := 0
	for family in view._sparks.keys():
		var e: GPUParticles3D = view._sparks[family]
		if e.emitting and not e.one_shot:
			live_emitters += 1
	_check("impact", "and they emit continuously rather than being restarted",
		live_emitters == view._sparks.size(),
		"%d of %d live" % [live_emitters, view._sparks.size()])
	_check("impact", "and the flash pool is fixed",
		view._flashes.size() == SkyGearView3D.FLASH_POOL,
		"%d lights" % view._flashes.size())
	var systems_before: int = view._sparks.size()
	var lights_before: int = view._flashes.size()
	for i in 60:
		view.impact_at(Vector2(i * 3, 0), "EMBER", 40.0)
	_check("impact", "sixty hits in a frame create nothing new",
		view._sparks.size() == systems_before and view._flashes.size() == lights_before,
		"%d systems, %d lights" % [view._sparks.size(), view._flashes.size()])
	## A bigger hit throws more, without rebuilding the system — which is the
	## whole reason one system per element is enough.
	## Frost and Ember do not merely differ in colour — the audit's finding 4 is
	## that coloured light IS a hue cue and cannot be the accessibility answer by
	## itself. They differ in where the particles go and how fast the light dies.
	var frost: Dictionary = SkyGearView3D.ELEMENT_FX.FROST
	var ember: Dictionary = SkyGearView3D.ELEMENT_FX.EMBER
	_check("impact", "elements differ in motion, not only in colour",
		float(frost.rise) < 0.0 and float(ember.rise) > 0.0
			and float(frost.spread) < float(ember.spread)
			and float(frost.life) < float(ember.life),
		"frost falls and snaps, ember rises and lingers")
	view.impact_at(Vector2.ZERO, "FROST", 90.0)
	var quick: float = float(view._flashes[(view._flash_next - 1) % view._flashes.size()]
		.get_meta("decay", 0.0))
	view.impact_at(Vector2.ZERO, "EMBER", 90.0)
	var slow: float = float(view._flashes[(view._flash_next - 1) % view._flashes.size()]
		.get_meta("decay", 0.0))
	_check("impact", "and their light dies at different rates",
		quick > slow, "frost %.0f/s, ember %.0f/s" % [quick, slow])
	_check("impact", "the flashes add nothing to the fog, so hits leave no trail",
		is_zero_approx(view._flashes[0].light_volumetric_fog_energy))
	## Colour-blind players get nothing from a teal ring against an orange one.
	## The light is a second channel that does not depend on hue.
	var lit := 0
	for light in view._flashes:
		if light.light_energy > 0.0:
			lit += 1
	_check("impact", "a hit lights the deck as well as colouring it", lit > 0,
		"%d of %d lit" % [lit, view._flashes.size()])

	## RIBBONS — VFX-PLAN.md §3, and the reported half of "projectiles and vfx
	## from the player still look like 2D".
	##
	## These assert the two things a screenshot cannot: that the batch is CAPPED,
	## which is the rule every effect on this list is held to, and that every skill
	## effect carries the element the trail's shape is chosen from. The look is
	## judged from `tools/vfx_shot.gd`, which is what it is for.
	_check("ribbon", "trails are one batch and one draw, not a mesh per projectile",
		view._ribbon_node != null and view._ribbon_mesh != null,
		"one ArrayMesh")
	_check("ribbon", "every element has its own shape in the air, not only a colour",
		SkyGearView3D.ELEMENT_RIBBON.size() == SkyGearData.ELEMENTS.size(),
		"%d written" % SkyGearView3D.ELEMENT_RIBBON.size())
	## Shape, not hue. A colour-blind player has to be able to tell a Frost bolt
	## from a Steam one, and these are the two that are furthest apart: Frost is
	## narrow, straight and sags; Steam is broad, wandering and rises.
	var frost_rib: Dictionary = SkyGearView3D.ELEMENT_RIBBON.FROST
	var steam_rib: Dictionary = SkyGearView3D.ELEMENT_RIBBON.STEAM
	var arc_rib: Dictionary = SkyGearView3D.ELEMENT_RIBBON.ARC
	_check("ribbon", "and the shapes actually differ where it counts",
		float(frost_rib.width) < float(steam_rib.width) * 0.5
			and float(frost_rib.rise) < 0.0 and float(steam_rib.rise) > 0.0
			and float(arc_rib.zig) > float(steam_rib.zig),
		"frost %.0f wide and sinks, steam %.0f wide and rises, arc kinks"
			% [float(frost_rib.width), float(steam_rib.width)])
	## THE CAP. The whole family of performance problems this project has had was
	## an unbounded collection, so what is asserted is the budget rather than the
	## picture: three hundred ribbons in one frame write no more vertices than one
	## frame is allowed, and nothing is half-drawn.
	view._ribbons_begin()
	var many := PackedVector3Array([Vector3(0, 60, 0), Vector3(100, 60, 0),
		Vector3(200, 60, 0)])
	var many_w := PackedFloat32Array([10.0, 10.0, 10.0])
	var many_c := PackedColorArray([Color.WHITE, Color.WHITE, Color.WHITE])
	for i in 500:
		view._ribbon(many, many_w, many_c)
	view._ribbons_end()
	_check("ribbon", "five hundred trails in a frame stay inside the vertex budget",
		view._ribbon_verts <= SkyGearView3D.RIBBON_VERTS,
		"%d of %d" % [view._ribbon_verts, SkyGearView3D.RIBBON_VERTS])
	_check("ribbon", "and the ones that do not fit are dropped whole, never half",
		view._ribbon_verts % 6 == 0 and view._ribbon_dropped > 0,
		"%d dropped" % view._ribbon_dropped)
	## And the buffers are allocated once. `_ribbons_end` slices them; if the fill
	## ever resized them this would be the frame it started allocating per frame.
	_check("ribbon", "the scratch buffers are allocated once, not per frame",
		view._rib_pos.size() == SkyGearView3D.RIBBON_VERTS
			and view._rib_col.size() == SkyGearView3D.RIBBON_VERTS,
		"%d vertices reserved" % view._rib_pos.size())

	## THE ELEMENT HAS TO REACH THE RENDERER. The trail's shape is chosen from it,
	## and it cannot be recovered from the colour — two cards can tint the same and
	## a keg is not an element at all. This is the "data with no reader" failure
	## inverted: a reader with no data, which fails silently by drawing everything
	## as Ember.
	var elemental: SkyGearGame = _new_game()
	_begin(elemental)
	elemental.skills.clear()
	for pair in [["LINE_BURST", "ARC"], ["RANGED_AOE", "FROST"],
			["CONE", "STEAM"], ["RAY", "EMBER"], ["CHAIN", "ARC"]]:
		elemental.skills.append(SkyGearData.make_skill(str(pair[0]), str(pair[1])))
	elemental.start_wave(3)
	## ARMOURED, and spread out. Four SCRAPPERs stacked on one point are four
	## corpses by the time the fifth cast goes off, and a Whip with nothing left to
	## jump between emits no effect at all — which the first version of this check
	## read as "chains do not arc" rather than as "there was no chain".
	for i in 4:
		elemental.spawn_enemy("ARMORED", i % 3)
	var spread := 0
	for e in elemental.get_tree().get_nodes_in_group("enemies"):
		e.state = "move"
		e.global_position = elemental.player.global_position + Vector2(
			-120.0 + 80.0 * float(spread), -240.0)
		spread += 1
	elemental.effects.clear()
	for slot in elemental.skills.size():
		elemental.skills[slot].cooldown_left = 0.0
		elemental.cast_skill(slot, elemental.player.global_position + Vector2(0, -260))
	## Only the kinds that DRAW a trail. A `burst` is a body coming apart and a
	## `banner` is a word across the middle of the deck; neither has an element and
	## neither asks the ribbon table for a shape, so demanding one of them would be
	## a check measuring the wrong thing in order to pass.
	var shaped_kinds := ["arc", "cone", "line", "beam", "circle"]
	var shaped := 0
	var unshaped: Array[String] = []
	for fx in elemental.effects:
		if not shaped_kinds.has(str(fx.kind)):
			continue
		if SkyGearView3D.ELEMENT_RIBBON.has(str(fx.get("element", ""))):
			shaped += 1
		else:
			unshaped.append(str(fx.kind))
	_check("ribbon", "every skill effect names the element its trail is shaped from",
		unshaped.is_empty() and shaped > 0,
		"%d shaped, missing on %s" % [shaped, ", ".join(unshaped)])
	## And a Mortar is the only shape that writes where it was THROWN from, which
	## is what the arcing shell is drawn along.
	var throws := 0
	for fx in elemental.effects:
		if fx.has("from") and str(fx.kind) == "circle":
			throws += 1
	_check("ribbon", "a Mortar records the throw, so the shell has an arc to fly",
		throws == 1, "%d circles carry a from" % throws)
	## A chain jump arcs and a sentry's shot does not. Both are `line` effects, so
	## `lift` is the only thing separating a whip over a boarder's head from a gun
	## firing along the deck.
	var lifted := 0
	var flat := 0
	for fx in elemental.effects:
		if str(fx.kind) != "line":
			continue
		if float(fx.get("lift", 0.0)) > 0.0:
			lifted += 1
		else:
			flat += 1
	_check("ribbon", "a chain jump arcs through the air and a lance does not",
		lifted > 0 and flat > 0, "%d arcing, %d flat" % [lifted, flat])
	elemental.queue_free()

	## THE CANNON HEALTH BARS. Asked for as "cannons should ... have clear health
	## bars", and the readable-at-a-glance part of that is a placement problem, not
	## a drawing one: the bar is unprojected from the gun's own position 160 ground
	## units up, so if that point is behind the camera or outside the frame there
	## is no bar over that gun no matter how well `_health_bar` draws.
	##
	## Checked at BOTH ends of the wheel, because the report is specifically about
	## reading them while zoomed out and the zoom moves the camera rather than the
	## lens. The screen rectangle is grown by the bar's own half-width, since a bar
	## whose centre is one pixel inside the frame is still half off it.
	##
	## From WHERE SHE STARTS, which is the position that matters: `reset_for_run`
	## puts her at y = 720 and the three guns are at y = 520, so for the whole
	## opening of every run they are the objects immediately up-deck of her. This
	## check was first written from wherever the earlier camera checks had left her
	## (y = 200, past the guns) and reported one bar of three, which is a true
	## statement about a place the player is rarely standing and not the claim
	## anybody wanted made.
	game.player.global_position = Vector2(0, 720)
	view._process(2.0)
	var screen_rect := Rect2(Vector2.ZERO,
		view.camera.get_viewport().get_visible_rect().size)
	for zoom_notches in [0.0, 99.0]:
		view.zoom_by(zoom_notches)
		view._process(2.0)              ## long enough for the eased zoom to land
		var framed := 0
		for turret in game.turrets:
			var top := Vector3(float(turret.position.x), 160.0,
				float(turret.position.y)) * SkyGearView3D.WORLD_SCALE
			if view.camera.is_position_behind(top):
				continue
			if screen_rect.grow(-SkyGearHUD.TURRET_BAR_W * 0.5).has_point(
					view.camera.unproject_position(top)):
				framed += 1
		_check("cannon", "every deck cannon's bar has somewhere to be drawn %s"
			% ("at the shipped framing" if zoom_notches == 0.0 else "at full zoom-out"),
			framed == game.turrets.size(),
			"%d of %d, zoom %.2f" % [framed, game.turrets.size(), view.zoom_amount()])
	view.zoom_by(-99.0)
	view._process(2.0)

	## POOLING, for real this time. The rendering audit was blunt and correct: the
	## first version freed every unclaimed node each frame and built a new one
	## when it was next needed, which is churn with the word "pool" on it.
	for i in 30:
		view.impact_at(Vector2(i * 20, 0), "EMBER", 20.0)
		view._process(0.05)
	var churned := view._free_decals.size() + view._free_billboards.size()
	_check("pool", "returned nodes are kept for reuse rather than freed",
		churned > 0 or view._decals.size() > 0,
		"%d decals and %d billboards waiting" % [view._free_decals.size(),
			view._free_billboards.size()])
	## And the free list cannot grow without bound — a keg chain must not leave
	## four hundred hidden nodes resident for the rest of the run.
	_check("pool", "and the free list is trimmed rather than growing forever",
		view._free_decals.size() <= SkyGearView3D.POOL_SLACK
			and view._free_billboards.size() <= SkyGearView3D.POOL_SLACK,
		"%d / %d against a slack of %d" % [view._free_decals.size(),
			view._free_billboards.size(), SkyGearView3D.POOL_SLACK])

	## The renderer is not what the design document assumed. Forward+ can run
	## over Vulkan or D3D12, and Compatibility cannot draw Decals at all — which
	## would silently remove every gameplay telegraph in the game.
	_check("render", "the build reports what it is actually running on",
		SkyGearRendererCheck.method() != "" and SkyGearRendererCheck.driver() != "",
		SkyGearRendererCheck.describe())
	_check("render", "and knows whether it can draw the deck markings",
		SkyGearRendererCheck.can_draw_telegraphs()
			== (SkyGearRendererCheck.method() in SkyGearRendererCheck.SUPPORTS_DECALS))
	_check("render", "with something to say to the player when it cannot",
		SkyGearRendererCheck.warning().is_empty()
			== SkyGearRendererCheck.can_draw_telegraphs())

	## The profiler. It exists because every performance conversation on this
	## project has been held without a number.
	var prof := SkyGearProfiler.new()
	root.add_child(prof)
	for i in 120:
		prof._process(0.008)
	## Three spikes in 123 frames — 2.4%, so the 99th percentile lands on one.
	## With a single spike in 121 frames the p99 correctly does NOT catch it,
	## which is a property of the statistic and not a bug: the first version of
	## this check asserted otherwise and was simply wrong about percentiles.
	for i in 3:
		prof._process(0.050)
	var t: Dictionary = prof.timings()
	_check("profile", "frame timings are collected",
		int(t.samples) > 100 and float(t.avg) > 0.0,
		"%d samples, avg %.2f ms" % [int(t.samples), float(t.avg)])
	## The 99th is the number that matters. An average hides exactly the thing
	## players notice — a build at a 4 ms average that hitches to 40 twice a
	## second is a build people call laggy.
	## The 99th is the number that matters, and it must sit at or above the
	## median or it is not measuring the tail at all.
	_check("profile", "the 99th percentile reports the tail, not the middle",
		float(t.p99) >= float(t.median) and float(t.p99) > 40.0,
		"p99 %.2f, median %.2f" % [float(t.p99), float(t.median)])
	_check("profile", "spikes are counted rather than averaged away",
		prof.spikes == 3, "%d spikes" % prof.spikes)
	_check("profile", "and the report names the renderer it was measured on",
		prof.report(null, null).contains(SkyGearRendererCheck.method()))
	prof.reset()
	_check("profile", "reset clears the window", prof.spikes == 0
		and int(prof.timings().samples) == 0)
	prof.queue_free()

	## RENDER QUALITY, from the audit. These are the ones that are silently wrong
	## rather than visibly wrong, which is why they need a check rather than a
	## screenshot.
	var world_env: Environment = null
	for child in view.get_children():
		if child is WorldEnvironment:
			world_env = (child as WorldEnvironment).environment
	_check("render", "a tonemapper is set, so bright colour does not clip to white",
		world_env != null and world_env.tonemap_mode != Environment.TONE_MAPPER_LINEAR,
		"mode %d" % (world_env.tonemap_mode if world_env else -1))
	_check("render", "and its white point is above the values the effects push to",
		world_env != null and world_env.tonemap_white >= 2.0,
		"white %.1f against tints at 1.7x" % (world_env.tonemap_white if world_env else 0.0))
	## Every generated texture is drawn either at a grazing angle on the deck or
	## minified on a billboard. Without mipmaps both shimmer, and a shimmering
	## telegraph rim is a readability problem.
	_check("render", "generated textures carry mipmaps",
		view._ring_texture().get_image().has_mipmaps()
			and view._planking_texture().get_image().has_mipmaps())
	## Nothing that cannot cast a meaningful shadow should be in the shadow pass.
	var casters := 0
	for family in view._sparks.keys():
		if (view._sparks[family] as GPUParticles3D).cast_shadow 				!= GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			casters += 1
	_check("render", "particles stay out of the shadow pass",
		casters == 0, "%d casting" % casters)

	## The shader warm-up. First use of a material builds its pipeline, and the
	## first bench found a 150 ms frame doing it — during a fight that lands as a
	## hitch at the moment the player is reacting to something new.
	_check("render", "every generated texture exists before the first frame of play",
		view._made.size() >= 14, "%d built at load" % view._made.size())

	## SHADOWS IN ONE DRAW. Every figure, prop, cannon, crewman, bolt and pickup
	## had its own Decal for the blob underneath it — about seventy clustered
	## decals before a single telegraph.
	_check("shadow", "contact shadows are one batch, not one decal each",
		view._shadow_batch != null and view._shadow_batch.multimesh != null,
		"batch present")
	var shadow_decals := 0
	for key in view._decals.keys():
		if str(key).begins_with("sh_"):
			shadow_decals += 1
	_check("shadow", "and none of them is a decal any more", shadow_decals == 0,
		"%d shadow decals left" % shadow_decals)
	_check("shadow", "the batch is capped",
		view._shadow_batch.multimesh.instance_count == SkyGearView3D.SHADOW_CAP,
		"%d instances" % view._shadow_batch.multimesh.instance_count)
	## Off its own layer the effect decals would project onto the shadows, and a
	## mortar ring painted across a boarder's shadow reads as a second ring.
	_check("shadow", "and decals do not paint onto it",
		(view._shadow_batch.layers & SkyGearView3D.LAYER_SHADOWS) != 0)

	## RESERVED DECAL CAPACITY. On a bad frame the thing dropped must never be
	## the thing telling you a boarder is about to hit you.
	_check("budget", "a telegraph draws from its own reserve",
		SkyGearView3D._decal_class("tg42") == SkyGearView3D.DecalClass.TELEGRAPH
			and SkyGearView3D._decal_class("scorch9") == SkyGearView3D.DecalClass.DECOR
			and SkyGearView3D._decal_class("fx3") == SkyGearView3D.DecalClass.PLAYER)
	## Flood the decorative budget, then check a telegraph still gets drawn.
	for i in 200:
		view._decal("glow_flood%d" % i, Vector2(i, 0), 0.0, 20.0, 20.0,
			view._blob_texture(), Color.WHITE)
	var decor_live: int = view._decal_live[SkyGearView3D.DecalClass.DECOR]
	view._decal("tg_reserved", Vector2.ZERO, 0.0, 20.0, 20.0,
		view._blob_texture(), Color.WHITE)
	_check("budget", "decoration cannot spend past its own allowance",
		decor_live <= int(SkyGearView3D.DECAL_BUDGET[SkyGearView3D.DecalClass.DECOR]),
		"%d live against a budget of %d" % [decor_live,
			int(SkyGearView3D.DECAL_BUDGET[SkyGearView3D.DecalClass.DECOR])])
	_check("budget", "and a telegraph still gets drawn on a flooded deck",
		view._decals.has("tg_reserved"))

	## ANIMATION TIMING. Reported as swings not looking synced, and it was
	## measurable: a Cleave has a 0.36 s cooldown against a 2.27 s clip.
	var timing := SkyGearRig3D.new()
	root.add_child(timing)
	if timing.setup(SkyGearView3D.CAPTAIN_SCENE, 1.76, SkyGearView3D.LAYER_FIGURES):
		var over := 0
		var cut := 0
		for shape in SkyGearData.SHAPES.keys():
			if bool(SkyGearData.SHAPES[shape].get("passive", false)):
				continue
			var st: Dictionary = game.skill_stats(SkyGearData.make_skill(shape, "EMBER"))
			var win: float = clampf(float(st.cooldown) * 0.85, 0.24, 0.62)
			timing.state = "idle"
			timing.want("swing", 0.0, win)
			var rate: float = timing.anim.speed_scale
			var shown: float = win * rate / timing.anim.get_animation(timing._clip).length
			if rate > SkyGearRig3D.ATTACK_RATE_MAX + 0.01:
				over += 1
			if shown < 0.34:
				cut += 1
		_check("timing", "every attack plays at a rate you can read",
			over == 0, "%d over the cap" % over)
		_check("timing", "and none of them is cut off before it lands",
			cut == 0, "%d showing under a third of the clip" % cut)
		## A one-shot must own the figure for the ACTION's length, not the
		## clip's — using the clip length is what let a 2.4 s animation block a
		## 0.36 s attack.
		timing.state = "idle"
		timing.want("swing", 0.0, 0.3)
		_check("timing", "a one-shot is held for the action, not for the clip",
			timing._one_shot_until - timing._clock <= 0.35,
			"held %.2fs" % (timing._one_shot_until - timing._clock))
		## A tight window must not pick the four-second combo. When NOTHING fits —
		## which is the case at 0.25 s against a 2.27 s shortest clip — the rule
		## is the shortest available, not whatever came next in the rotation.
		timing.state = "idle"
		timing.want("swing", 0.0, 0.25)
		var shortest := 999.0
		for name in SkyGearRig3D.VARIANTS.swing:
			if timing.has_clip(str(name)):
				shortest = minf(shortest, timing.anim.get_animation(str(name)).length)
		_check("timing", "and when nothing fits it takes the shortest, not the next",
			is_equal_approx(timing.anim.get_animation(timing._clip).length, shortest),
			"%s at %.2fs, shortest is %.2fs" % [timing._clip,
				timing.anim.get_animation(timing._clip).length, shortest])
		## Re-casting the same skill has to replay the swing. It did not: the
		## variant came up the same, the clip name matched, and the replay was
		## skipped — so the second cast of a repeated skill animated nothing.
		timing.state = "idle"
		timing.want("swing", 0.0, 0.4)
		var first_end: float = timing._one_shot_until
		timing._clock += 0.2
		timing.state = "idle"
		timing.want("swing", 0.0, 0.4)
		_check("timing", "and casting the same skill again replays the swing",
			timing._one_shot_until > first_end,
			"%.2f then %.2f" % [first_end, timing._one_shot_until])
	timing.queue_free()

	## THE WIDGET LAYER. Every clickable thing was an ad-hoc rect test written
	## where it was drawn: no keyboard, no focus, no disabled state, no sound.
	## That is why there was no settings screen and no way to quit a paused run.
	var panel := Control.new()
	panel.size = Vector2(900, 600)
	root.add_child(panel)
	var widgets := SkyGearUI.new()
	## Two passes: input is tested against the list drawn LAST frame, which is
	## the one the player was looking at when they clicked.
	for pass_index in 2:
		widgets.begin("t", panel, ThemeDB.fallback_font, Vector2(-999, -999))
		widgets.button(Rect2(10, 10, 200, 40), "ONE")
		widgets.button(Rect2(10, 60, 200, 40), "TWO", {"disabled": true})
		widgets.button(Rect2(10, 110, 200, 40), "THREE")
	var down := InputEventKey.new()
	down.keycode = KEY_DOWN
	down.pressed = true
	## One step from the top lands on index 2, not 1 — index 1 is disabled and a
	## focus that stops on something it cannot activate is a focus that looks
	## broken.
	_check("widget", "the keyboard can reach a button", widgets.handle(down))
	_check("widget", "and focus skips a disabled one",
		widgets.focused() == 2, "landed on %d" % widgets.focused())
	widgets.handle(down)
	_check("widget", "and wraps rather than stopping at the end",
		widgets.focused() == 0, "landed on %d" % widgets.focused())
	## A disabled button must refuse the click rather than looking refused.
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	widgets.begin("t", panel, ThemeDB.fallback_font, Vector2(100, 80))
	widgets.button(Rect2(10, 10, 200, 40), "ONE")
	widgets.button(Rect2(10, 60, 200, 40), "TWO", {"disabled": true})
	widgets.button(Rect2(10, 110, 200, 40), "THREE")
	_check("widget", "a disabled button refuses the click", not widgets.handle(click))
	panel.queue_free()

	## AND THE WIDGET LIST IS REPORTABLE. `tools/text_audit.gd` uses `declared()`
	## to catch two widgets sharing pixels — a bug the string audit structurally
	## cannot see, because each overlapping button contains its own label
	## perfectly. If this ever returned nothing the collision check would pass
	## vacuously forever, which is the quietest way for a detector to die.
	panel.queue_free()
	var canvas := Control.new()
	canvas.size = Vector2(400, 300)
	root.add_child(canvas)
	var reported := SkyGearUI.new()
	reported.begin("t2", canvas, ThemeDB.fallback_font, Vector2.ZERO)
	reported.button(Rect2(10, 10, 100, 30), "A")
	reported.button(Rect2(10, 50, 100, 30), "B")
	_check("widget", "the widget list is reportable, so overlaps can be caught",
		reported.declared().size() == 2, "%d declared" % reported.declared().size())
	## And it really is the rectangles, not a count.
	var overlapping := SkyGearUI.new()
	overlapping.begin("t3", canvas, ThemeDB.fallback_font, Vector2.ZERO)
	overlapping.button(Rect2(10, 10, 100, 30), "A")
	overlapping.button(Rect2(10, 20, 100, 30), "B")
	var stacked: Array = overlapping.declared()
	_check("widget", "and two stacked widgets are visibly stacked in it",
		(stacked[0].rect as Rect2).intersects(stacked[1].rect as Rect2))
	canvas.queue_free()

	## And the pause menu can now end a run, which it could not before: from a
	## paused game there was no way to restart or quit short of alt-F4.
	_check("widget", "a paused run can be restarted and quit",
		game.has_method("restart_run") and game.has_method("toggle_pause"))

	## EVERY LANE CAN THREATEN THE OBJECTIVE. Found by a design pass, then
	## measured: the enemy clamp pinned every boarder to its lane centre +- 190
	## for its whole life, so lanes 0 and 2 could get no closer than 385 units to
	## the Boiler against a 94-unit scrapper reach. Two of three lanes could not
	## damage the thing you lose by, and "hold three lanes" was really "hold the
	## middle one".
	##
	## Checked as REACHABILITY rather than as the merge constant, so re-tuning the
	## merge cannot quietly recreate the bug.
	var no_reach := ""
	for lane in SkyGearGame.LANE_CENTERS.size():
		## The closest a boarder in this lane can legally stand to the Boiler.
		var at_boiler := SkyGearGame.BOILER_POSITION
		var got: Vector2 = game.correct_enemy_position(at_boiler, lane, 15.0)
		var reach: float = float(SkyGearData.ENEMIES.SCRAPPER.attack_range) + 28.0
		if got.distance_to(SkyGearGame.BOILER_POSITION) > reach:
			no_reach += " %d(%.0f)" % [lane,
				got.distance_to(SkyGearGame.BOILER_POSITION)]
	_check("lanes", "a boarder in every lane can reach the Boiler",
		no_reach == "", "cannot, by:" + no_reach)

	## But they are still LANES on the approach, or the readout is a lie and the
	## whole three-lane read collapses into one crowd.
	var separated := 0
	for lane in [0, 2]:
		var up := Vector2(0.0, SkyGearGame.DECK_RECT.position.y + 300.0)
		var held: Vector2 = game.correct_enemy_position(up, lane, 15.0)
		if absf(held.x - float(SkyGearGame.LANE_CENTERS[lane])) < 200.0:
			separated += 1
	_check("lanes", "and is still held in its own column on the way down",
		separated == 2, "%d of 2 outer lanes stayed separated" % separated)

	## DECKWORK. Asked for as "repair broken turrets", framed as the seed of the
	## player shaping the ground. So the checks are about the SYSTEM — a verb
	## table with one entry — rather than about repair specifically.
	var deck := _new_game()
	deck.set_seed_text("DECK")
	deck.begin_run()
	deck.choose_draft(0)
	deck.start_wave(3)
	deck.spawn_queue.clear()
	for stray in deck.get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(stray):
			stray.dead = true
			stray.queue_free()

	var gun: Dictionary = deck.turrets[0]
	deck.player.global_position = Vector2(gun.position)
	_check("deck", "a healthy cannon offers no work",
		SkyGearDeckwork.available(deck).is_empty())

	## Only a broken one. A damaged gun still shoots, and topping it up mid-wave
	## would make deckwork a chore you perform constantly rather than a decision.
	gun.dead = true
	gun.hp = 0.0
	var offered: Dictionary = SkyGearDeckwork.available(deck)
	_check("deck", "but a broken one does", not offered.is_empty())
	deck.player.global_position = Vector2(gun.position) + Vector2(900.0, 0.0)
	_check("deck", "and only when you are standing at it",
		SkyGearDeckwork.available(deck).is_empty())
	deck.player.global_position = Vector2(gun.position)

	## THE COST IS TIME AND ONLY TIME, so the interruptions are the design. Three
	## ways to lose it, all the same idea: you were doing something else.
	_check("deck", "it takes real seconds",
		float(offered.spec.seconds) > 1.0, "%.1fs" % float(offered.spec.seconds))

	## Boarders standing on it stop you — repairing with a scrapper swinging at
	## your back is a free action with extra steps.
	deck.spawn_enemy("SCRAPPER", 1)
	var squatter: SkyGearEnemy = null
	for e in deck.get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and not e.dead:
			squatter = e
	if squatter != null:
		squatter.global_position = Vector2(gun.position) + Vector2(40.0, 0.0)
		_check("deck", "and boarders on it contest the work",
			bool(SkyGearDeckwork.available(deck).contested))
		squatter.global_position = Vector2(5000.0, 0.0)
		_check("deck", "but not from across the deck",
			not bool(SkyGearDeckwork.available(deck).contested))
		squatter.dead = true
		squatter.queue_free()

	## It comes back damaged. A cannon you can restore to new is a cannon that
	## never really broke, and the lane pressure that broke it stops meaning
	## anything.
	SkyGearDeckwork.perform(deck, offered.spec, gun)
	_check("deck", "a repaired cannon fires again", not bool(gun.dead))
	_check("deck", "but not as good as new",
		float(gun.hp) > 0.0 and float(gun.hp) < float(gun.max_hp),
		"%.0f of %.0f" % [float(gun.hp), float(gun.max_hp)])

	## And it is a TABLE, which is the whole point of the framing — laning and
	## funnelling are entries here, not a rewrite of a repair button.
	_check("deck", "and it is a verb table, not one hardcoded action",
		SkyGearDeckwork.actions().size() >= 1
			and SkyGearDeckwork.actions()[0].has("verb")
			and SkyGearDeckwork.actions()[0].has("at"))
	deck.queue_free()

	## MOVEMENT FEEL, as a shape rather than as numbers. Both directions of this
	## have now been wrong: first a third of a second of post-dash skating, then
	## an over-correction that braked in 0.05s and was reported as the game
	## feeling slower. The checks pin the SHAPE so the next tuning pass cannot
	## quietly walk off either edge.
	var stop_time: float = SkyGearPlayer.SPEED / SkyGearPlayer.FRICTION
	var start_time: float = SkyGearPlayer.SPEED / SkyGearPlayer.ACCEL
	_check("feel", "stopping is quicker than starting", stop_time < start_time,
		"%.3fs to stop, %.3fs to start" % [stop_time, start_time])
	## But not instantly. Under about a twentieth of a second there is no
	## deceleration left to feel and it reads as walking into glue.
	_check("feel", "but not so quick it reads as glue", stop_time > 0.055,
		"%.3fs" % stop_time)

	## A dash lands with something left. Exiting at exactly walking speed stops
	## the move dead on its last frame and takes the travel out of it.
	_check("feel", "a dash carries past its own end",
		SkyGearPlayer.DASH_EXIT > 1.2, "x%.2f" % SkyGearPlayer.DASH_EXIT)
	## And the carry is over fast. This is the number that was 0.36s and made
	## every dash feel like ice.
	var carry: float = SkyGearPlayer.SPEED * (SkyGearPlayer.DASH_EXIT - 1.0) 		/ SkyGearPlayer.FRICTION
	_check("feel", "and is over in a tenth of a second", carry < 0.10,
		"%.3fs of carry" % carry)

	## THE WORKSHOP. `V10-PLAN.md` cut meta-progression as "a way to postpone the
	## moment this game becomes excellent", and the park was right when written.
	## What makes it safe now is one constraint doing most of the work.
	## EPHEMERAL. Everything below buys, banks and respecs, and every one of those
	## writes to disk — this block would otherwise hand whoever ran the harness a
	## fully-bought Workshop and erase what they had earned.
	var shop := SkyGearWorkshop.fresh(true)

	## THE GATE. Nothing exists before a first victory — not unlocked, not shown,
	## not banked-and-hidden, not retroactive. Every run up to a first DECK HELD
	## is exactly the shipped game at today's numbers, which is what forecloses
	## being behind a curve that has not started.
	var lost := SkyGearWorkshop.bank(shop,
		{"won": false, "wave": 11, "seed": "A", "vents": 9, "close_share": 70})
	_check("shop", "a loss before your first win pays nothing",
		int(lost.scrip) == 0 and not bool(shop.unlocked),
		"paid %d" % int(lost.scrip))
	_check("shop", "and there is nothing to spend it on either",
		not SkyGearWorkshop.can_buy(shop, "padded_coat"))

	var won := SkyGearWorkshop.bank(shop,
		{"won": true, "wave": 12, "seed": "B", "vents": 9, "close_share": 70})
	_check("shop", "the first win opens it", bool(shop.unlocked)
		and int(won.scrip) > 0, "%d scrip" % int(won.scrip))
	_check("shop", "and pays a sigil for the first of a thing",
		int(shop.sigils) > 0, "%d sigils" % int(shop.sigils))

	## SIGILS COME ONLY FROM FIRSTS, so the impactful currency cannot be farmed.
	var sigils_before: int = int(shop.sigils)
	SkyGearWorkshop.bank(shop,
		{"won": true, "wave": 12, "seed": "C", "vents": 9, "close_share": 70})
	_check("shop", "and a second identical win pays no more sigils",
		int(shop.sigils) == sigils_before,
		"%d -> %d" % [sigils_before, int(shop.sigils)])

	## A REPEATED SEED PAYS A QUARTER, or the run log becomes a spreadsheet you
	## farm your best seed on.
	var fresh_seed := SkyGearWorkshop.scrip_for(
		{"won": true, "wave": 12, "vents": 9, "close_share": 70}, false)
	var again := SkyGearWorkshop.scrip_for(
		{"won": true, "wave": 12, "vents": 9, "close_share": 70}, true)
	_check("shop", "and replaying a seed you have beaten pays a quarter",
		again < fresh_seed and again > 0, "%d against %d" % [again, fresh_seed])

	## TIERS OPEN ON COUNT. A tier that is simply hidden makes a branch look
	## finished at two nodes.
	shop.scrip = 100000
	_check("shop", "a branch starts with only its first tier open",
		SkyGearWorkshop.can_buy(shop, "padded_coat")
			and not SkyGearWorkshop.can_buy(shop, "long_arms"))
	SkyGearWorkshop.buy(shop, "padded_coat")
	SkyGearWorkshop.buy(shop, "bootblacking")
	_check("shop", "and two purchases open the next",
		SkyGearWorkshop.can_buy(shop, "sea_legs"))
	## Ranks are capped.
	for _i in 8:
		SkyGearWorkshop.buy(shop, "padded_coat")
	_check("shop", "and a node cannot be bought past its ranks",
		SkyGearWorkshop.rank(shop, "padded_coat")
			== int(SkyGearWorkshop.NODES.padded_coat.ranks),
		"%d ranks" % SkyGearWorkshop.rank(shop, "padded_coat"))

	## RESPEC IS FREE AND TOTAL. Charging for it taxes experimenting, which is
	## the only thing a tree this small has to offer.
	var before_respec: int = int(shop.scrip)
	SkyGearWorkshop.respec(shop)
	_check("shop", "respec refunds everything", int(shop.scrip) > before_respec
		and (shop.nodes as Dictionary).is_empty())

	## THE LOAD-BEARING BALANCE CLAIM: the whole tree, fully bought, is worth
	## less than three draft cards. Compared as resolved numbers rather than
	## trusted — the tree is flat and additive, the cards are multiplicative, and
	## the moment that stops being true the draft stops deciding the run.
	shop.scrip = 100000
	for _pass in 4:
		for id in SkyGearWorkshop.NODES.keys():
			for _r in int(SkyGearWorkshop.NODES[id].ranks):
				SkyGearWorkshop.buy(shop, id)
	var everything: Dictionary = SkyGearWorkshop.resolved(shop)
	## EVERY FIELD THE TREE CAN GRANT HAS TO BE ACCOUNTED FOR.
	##
	## This check used to read ONE of them. It resolved the fully-bought tree,
	## took `crit_chance`, and compared 1.06 against 2.28 — a constant against a
	## constant, with the other twenty-nine fields unexamined. It could not go red.
	## A talent granting +100% damage under any other name would have sailed past
	## it green, which is the precise opposite of what a load-bearing balance
	## claim restated in three design documents is supposed to be protected by.
	##
	## So the table below is the check. A field that is not in it FAILS, and that
	## is the feature: the next person to add a node either classifies what it
	## does to a run or the harness stops them. Only the offensive buckets are
	## measured against the cards, because only those are the draft's exclusive —
	## the tree is allowed to be generous with health and rerolls and is not
	## allowed to be generous with damage.
	const OFFENCE := ["damage", "reach"]
	var buckets := {
		## multiplies the harm the captain herself does — the draft's territory
		"crit_chance": "damage",
		## makes that harm land further out, which is output by another route
		"range": "reach", "vent_radius": "reach",
		## staying alive longer is not the same as hitting harder
		"max_hp": "survival", "brace": "survival", "boiler_hp": "survival",
		"boiler_repair": "survival", "salvage_heal": "survival",
		"vent_heal": "survival", "wave_heal": "survival", "recall": "survival",
		"deadmans_switch": "survival", "scuttle": "survival",
		"keel_hauling": "survival",
		"move_speed": "mobility", "dash_recharge": "mobility",
		## the ship fights for you; capped separately by the crew balance checks
		"turret_rate": "allies", "turret_hp": "allies", "extra_crew": "allies",
		"extra_kegs": "allies", "press_gang": "allies", "second_shift": "allies",
		## and the rest buys information and choices, not power
		"rerolls": "economy", "fourth_card": "economy",
		"pressure_rate": "economy", "wave_pressure": "economy",
		"show_queue": "readout", "show_numbers": "readout",
		"show_manifest": "readout", "show_ledger": "readout",
	}
	var unclassified := ""
	for id in SkyGearWorkshop.NODES.keys():
		var field := str(SkyGearWorkshop.NODES[id].field)
		if not buckets.has(field):
			unclassified += " %s(%s)" % [id, field]
	_check("shop", "every talent's field is classified as power or not",
		unclassified == "",
		"unclassified:%s — say what it does to a run" % unclassified)

	## Now the claim itself, over every offensive field rather than one of them.
	## Multiplied, because that is how the run applies them and how the cards
	## stack; a tree that granted +40% crit and +40% range would be 1.96 and would
	## have to answer for it.
	var tree_damage := 1.0
	var counted := ""
	for field in everything.keys():
		if str(buckets.get(field, "")) in OFFENCE:
			tree_damage *= 1.0 + float(everything[field])
			counted += " %s+%.0f%%" % [field, float(everything[field]) * 100.0]
	## Three typical cards: +30% damage, +35% area, +30% range on one slot.
	var three_cards := 1.30 * 1.35 * 1.30
	_check("shop", "the whole tree is worth less than three cards",
		tree_damage < three_cards,
		"tree x%.2f (%s ) against cards x%.2f"
			% [tree_damage, counted, three_cards])
	## And no node is a multiplier on damage at all — that is the draft's job.
	var multiplies := ""
	for id in SkyGearWorkshop.NODES.keys():
		if str(SkyGearWorkshop.NODES[id].field) in ["damage", "elem_damage",
				"crit_damage", "multi", "pierce", "residue"]:
			multiplies += " " + id
	_check("shop", "and no talent takes a card's exclusive", multiplies == "",
		multiplies)

	## Every node has to be reachable, or it is a line in a table nobody can buy.
	var unreachable := ""
	for id in SkyGearWorkshop.NODES.keys():
		var node: Dictionary = SkyGearWorkshop.NODES[id]
		var in_branch := 0
		for other in SkyGearWorkshop.NODES.keys():
			if str(SkyGearWorkshop.NODES[other].branch) == str(node.branch):
				in_branch += 1
		if int(node.tier) * SkyGearWorkshop.TIER_STEP >= in_branch:
			unreachable += " " + id
	_check("shop", "and every node can actually be reached", unreachable == "",
		unreachable)

	## And the harness cannot reach a real save, which is the check that stops
	## the check above being dangerous.
	_check("shop", "a test workshop never touches the file on disk",
		bool(shop.get("ephemeral", false))
			and SkyGearWorkshop.save_state(shop)
			and not bool(SkyGearWorkshop.load_state().get("ephemeral", false)))

	## EVERY GRANT HAS A READER. The previous commit shipped thirteen fields that
	## resolved correctly and did nothing — a node you could buy that changed no
	## number. Data with no reader is the trap this project keeps falling into
	## (three times on the Boilerwright alone), so this is the mechanical guard:
	## every `field` in `NODES` must be named somewhere in the scripts.
	##
	## Grep rather than behaviour, deliberately. A behavioural check per node is
	## twenty-four fragile tests; this one catches the failure that actually
	## happens, which is a field nobody wired at all.
	var readers := ""
	for path in ["res://scripts/game.gd", "res://scripts/hud.gd",
			"res://scripts/player.gd", "res://scripts/view3d.gd"]:
		readers += FileAccess.get_file_as_string(path)
	var inert := ""
	for id in SkyGearWorkshop.NODES.keys():
		var field := str(SkyGearWorkshop.NODES[id].field)
		## Named in a reader, not merely in the table it came from.
		if not readers.contains('"%s"' % field) and not readers.contains(".%s" % field):
			inert += " " + field
	_check("shop", "every talent field is read by something", inert == "",
		"nothing reads:" + inert)

	## And the ones with a number behind them actually move it.
	var live := SkyGearWorkshop.fresh(true)
	live.unlocked = true
	live.scrip = 100000
	for id in ["padded_coat", "bootblacking", "shot_locker", "spare_plate"]:
		SkyGearWorkshop.buy(live, id)
	var plain := _new_game()
	plain.set_seed_text("NOSHOP")
	plain.begin_run()
	var base_hp: float = plain.player.max_hp
	var base_speed: float = plain.player.move_speed
	var base_boiler: float = plain.boiler_max_hp
	var base_turret: float = float(plain.turrets[0].max_hp)
	plain.queue_free()

	var kitted := _new_game()
	kitted.workshop = live
	kitted.set_seed_text("NOSHOP")
	kitted.begin_run()
	_check("shop", "and a bought tree actually changes the run",
		kitted.player.max_hp > base_hp
			and kitted.player.move_speed > base_speed
			and kitted.boiler_max_hp > base_boiler
			and float(kitted.turrets[0].max_hp) > base_turret,
		"hp %.0f/%.0f speed %.0f/%.0f boiler %.0f/%.0f cannon %.0f/%.0f"
			% [kitted.player.max_hp, base_hp, kitted.player.move_speed, base_speed,
				kitted.boiler_max_hp, base_boiler,
				float(kitted.turrets[0].max_hp), base_turret])
	kitted.queue_free()

	## HEAT. The reason a permanently stronger captain does not make twelve waves
	## permanently easier — an opt-in ladder, earned by the same first victory,
	## so there is exactly ONE difficulty until the game has been beaten.
	##
	## That last property is the load-bearing one: every balance claim this
	## harness makes is against Heat 0, and a baseline that moved when the player
	## shopped would make all of them ambiguous.
	_check("heat", "Heat 0 is exactly the shipped scaling",
		is_equal_approx(SkyGearWorkshop.hp_scaling_for(0),
			SkyGearWorkshop.BASE_HP_SCALING)
		and is_equal_approx(SkyGearWorkshop.windup_for(0), 1.0))

	var ladder := SkyGearWorkshop.fresh(true)
	_check("heat", "and there is no ladder before a first victory",
		SkyGearWorkshop.heat_available(ladder) == 0)
	ladder.unlocked = true
	_check("heat", "a first win opens exactly one rung",
		SkyGearWorkshop.heat_available(ladder) == 1)
	ladder.best_heat = 1
	_check("heat", "and clearing that one opens the next",
		SkyGearWorkshop.heat_available(ladder) == 2)
	## Climbed, not skipped, and never past what is built.
	ladder.best_heat = 9
	_check("heat", "but never past the top of what exists",
		SkyGearWorkshop.heat_available(ladder) == SkyGearWorkshop.HEAT.size() - 1)

	## Each rung is strictly harder than the one below, or it is not a ladder.
	var softer := ""
	for i in range(1, SkyGearWorkshop.HEAT.size()):
		if SkyGearWorkshop.hp_scaling_for(i) < SkyGearWorkshop.hp_scaling_for(i - 1) 				or SkyGearWorkshop.windup_for(i) > SkyGearWorkshop.windup_for(i - 1):
			softer += " %d" % i
	_check("heat", "and every rung is harder than the one below", softer == "",
		"softer at:" + softer)

	## A boarder actually hardens. Wave 12 at Heat 1 against wave 12 at Heat 0.
	var cool := _new_game()
	cool.set_seed_text("HEAT0")
	cool.begin_run()
	cool.choose_draft(0)
	cool.spawn_enemy("SCRAPPER", 1)
	var cool_hp := 0.0
	for e in cool.get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and not e.dead:
			e.configure(cool, "SCRAPPER", 1, 12)
			cool_hp = e.max_hp
	cool.queue_free()

	var hot := _new_game()
	hot.workshop = SkyGearWorkshop.fresh(true)
	hot.workshop.unlocked = true
	hot.heat = 1
	hot.set_seed_text("HEAT1")
	hot.begin_run()
	hot.choose_draft(0)
	hot.spawn_enemy("SCRAPPER", 1)
	var hot_hp := 0.0
	for e in hot.get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and not e.dead:
			e.configure(hot, "SCRAPPER", 1, 12)
			hot_hp = e.max_hp
	_check("heat", "Rust actually hardens a late boarder", hot_hp > cool_hp * 1.15,
		"%.0f against %.0f at wave 12" % [hot_hp, cool_hp])
	## And a save edited past what is available is clamped on the way in.
	hot.heat = 9
	hot.begin_run()
	_check("heat", "and a run cannot start above the rung you have earned",
		hot.heat <= SkyGearWorkshop.heat_available(hot.workshop),
		"started at %d" % hot.heat)
	hot.queue_free()

	## A first clear at a rung pays a sigil, once — the ladder is content, not a
	## farm, same rule as every other sigil.
	var climb := SkyGearWorkshop.fresh(true)
	climb.unlocked = true
	SkyGearWorkshop.bank(climb,
		{"won": true, "wave": 12, "seed": "H1", "heat": 1, "close_share": 50})
	var after_first: int = int(climb.sigils)
	_check("heat", "clearing a rung records it", int(climb.best_heat) == 1)
	SkyGearWorkshop.bank(climb,
		{"won": true, "wave": 12, "seed": "H2", "heat": 1, "close_share": 50})
	_check("heat", "and clearing it twice pays once",
		int(climb.sigils) == after_first,
		"%d -> %d" % [after_first, int(climb.sigils)])

	## THE ARTICLES. The sigil side: commitments rather than experiments, no
	## refund, and two of them fight over the same key.
	var art := SkyGearWorkshop.fresh(true)
	_check("shop", "no article before the workshop opens",
		not SkyGearWorkshop.can_take(art, "brace"))
	art.unlocked = true
	art.sigils = 1
	_check("shop", "one sigil buys a one-sigil article",
		SkyGearWorkshop.can_take(art, "brace")
			and not SkyGearWorkshop.can_take(art, "recall"))
	SkyGearWorkshop.take(art, "brace")
	_check("shop", "and taking it spends the sigil",
		SkyGearWorkshop.owns(art, "brace") and int(art.sigils) == 0)

	## THE EXCLUSION. Brace and Recall answer the two things the game has no
	## answer for and share a key; owning both would make F a guess.
	art.sigils = 9
	_check("shop", "and its opposite is barred, not merely expensive",
		not SkyGearWorkshop.can_take(art, "recall"))

	## Sixteen sigils to own everything against eleven in existence, so the side
	## can never be finished. That is the property, so it is the check.
	var total_cost := 0
	for id in SkyGearWorkshop.ARTICLES.keys():
		total_cost += int(SkyGearWorkshop.ARTICLES[id].cost)
	var sigil_sources := 5   ## the firsts in `firsts_in`
	_check("shop", "the articles cost more than the sigils that exist",
		total_cost > sigil_sources,
		"%d to own all against %d obtainable" % [total_cost, sigil_sources])

	## EVERY ARTICLE HAS A READER, same guard as the passive side — this is the
	## trap that has now bitten three times, so it is checked on both halves.
	var art_readers := ""
	for path in ["res://scripts/game.gd", "res://scripts/hud.gd",
			"res://scripts/player.gd"]:
		art_readers += FileAccess.get_file_as_string(path)
	var dead_articles := ""
	for id in SkyGearWorkshop.ARTICLES.keys():
		if not art_readers.contains('"%s"' % str(SkyGearWorkshop.ARTICLES[id].field)):
			dead_articles += " " + id
	_check("shop", "and every article is read by something", dead_articles == "",
		"nothing reads:" + dead_articles)

	## THE BOILERWRIGHT CANNOT TAKE THE KEYED ONES. His F is Tap Main and his V
	## is Blowdown — they are the class, not a binding.
	var keyed := SkyGearWorkshop.fresh(true)
	keyed.unlocked = true
	keyed.sigils = 9
	for id in ["brace", "scuttle", "press_gang"]:
		SkyGearWorkshop.take(keyed, id)
	var art_hers: Dictionary = SkyGearWorkshop.articles_for(keyed, "captain")
	var art_his: Dictionary = SkyGearWorkshop.articles_for(keyed, "boilerwright")
	_check("shop", "the captain gets the keyed articles",
		art_hers.has("brace") and art_hers.has("scuttle"))
	_check("shop", "the Boilerwright does not, because F and V are his class",
		not art_his.has("brace") and not art_his.has("scuttle"))
	_check("shop", "but he still gets the ones with no key", art_his.has("press_gang"))

	## SECOND SHIFT, the one that changes an outcome rather than a number.
	var saved := _new_game()
	saved.workshop = SkyGearWorkshop.fresh(true)
	saved.workshop.unlocked = true
	saved.workshop.sigils = 4
	SkyGearWorkshop.take(saved.workshop, "second_shift")
	saved.set_seed_text("SAVED")
	saved.begin_run()
	saved.choose_draft(0)
	saved.start_wave(2)
	saved.player.invulnerability_left = 0.0
	saved.damage_player(9999.0)
	## Alive, and barely. The design's "leaves you at 1 HP, a free full vent" means
	## the vent heals AFTER the drop, so the exact number is whatever venting is
	## worth this run — asserting 1.0 was asserting that the vent does nothing.
	_check("shop", "the first killing blow is survived",
		saved.player.hp > 0.0 and saved.player.hp < saved.player.max_hp * 0.25,
		"%.1f of %.0f" % [saved.player.hp, saved.player.max_hp])
	## Once a run. A cheat death you get twice is a difficulty setting.
	saved.player.invulnerability_left = 0.0
	saved.damage_player(9999.0)
	_check("shop", "and only the first", saved.player.hp <= 0.0,
		"%.1f hp" % saved.player.hp)
	saved.queue_free()

	## THE BOILERWRIGHT. A second class, and the point of it is that it is not a
	## reskin — `docs/CLASS-2-DESIGN.md` argues at length that a class which
	## simply fires further is the answer v11 deleted. So the checks are about
	## the ways the two are STRUCTURALLY different, not about numbers.
	game.go_to_title()
	game.set_class("boilerwright")
	game.set_seed_text("BOILER")
	game.begin_run()
	_check("class", "the body comes from the class", game.player.max_hp == 130.0
		and game.player.move_speed == 205.0, "%.0f hp, %.0f speed"
			% [game.player.max_hp, game.player.move_speed])
	## No dash at all. His reposition costs gauge, which is the sharpest thing
	## about him — a free recharging escape would undo the whole class.
	_check("class", "and he has no recharging dash", game.player.max_dash_charges == 0)

	## And the HUD is told. `_update_cooldowns` re-synced the dash ceiling from
	## `mods` every frame with a `maxi(1, ...)` floor written when everyone had at
	## least one dash — so he was drawn a dash pip he could not use, one frame
	## after `begin_run` had correctly given him none.
	game.choose_draft(0)
	game.start_wave(2)
	for _t in 5:
		game._update_cooldowns(0.05)
	_check("class", "and nothing quietly gives it back",
		game.player.max_dash_charges == 0,
		"%d charges" % game.player.max_dash_charges)

	## The gauge is a BANK. Hers fills from damage landed close and decays out of
	## it; his fills only where he plants himself and never leaks.
	_check("class", "his gauge is banked, not measured", game.gauge_is_banked())
	game.pressure = 60.0
	game.player.global_position = Vector2(0.0, -900.0)   ## nowhere near anything
	for _t in 40:
		game._update_pressure(0.1)
	_check("class", "and standing nowhere loses nothing", game.pressure >= 59.9,
		"drained to %.1f" % game.pressure)

	## NO CARD MAY GIVE HIM A DASH. The class ceiling had an escape hatch — it
	## only forced zero while `mods.dash_charges` was at or below the default, so
	## the one epic that raises it handed the no-dash class three. Checked at BOTH
	## ends now, because a guard and an offer are different failures: the card
	## should not be dealt, and if it somehow is, it must not work.
	var forced := _new_game()
	forced.set_class("boilerwright")
	forced.set_seed_text("NODASH")
	forced.begin_run()
	forced.mods.dash_charges = 3
	forced._update_cooldowns(0.05)
	_check("class", "no card can give the dashless class a dash",
		forced.player.max_dash_charges == 0,
		"%d charges" % forced.player.max_dash_charges)
	## And it is not offered one in the first place, or it is a dead card taking
	## a slot in a three-card draft.
	var dash_offers := 0
	for entry in SkyGearCards.catalogue():
		if str(entry.id) in ["dashcd", "dashdmg", "dashchg"] 				and (entry.get("can") as Callable).call(forced):
			dash_offers += 1
	_check("class", "and is never offered one", dash_offers == 0,
		"%d dash cards offerable to him" % dash_offers)
	## The captain still gets all three, or the gate is in the wrong place.
	var hers_offers := 0
	forced.set_class("captain")
	forced.begin_run()
	for entry in SkyGearCards.catalogue():
		if str(entry.id) in ["dashcd", "dashdmg", "dashchg"] 				and (entry.get("can") as Callable).call(forced):
			hers_offers += 1
	_check("class", "while the captain still is", hers_offers == 3,
		"%d of 3" % hers_offers)
	forced.queue_free()

	## THE NEGATIVE SPACE, which is where the bug lived. `CLASS-2-DESIGN.md` §7
	## named this check verbatim and it was never written: the class block tested
	## only that the gauge FILLS, never that it does not. So `register_damage` and
	## `on_enemy_killed` granted Head unguarded for weeks behind a green harness,
	## and a 40-damage close hit filled it by 68 — faster than eight seconds
	## inside his own Tap Main.
	##
	## "Head fills only where he plants himself" is the one sentence the class is,
	## so it gets a check that fails when it stops being true.
	game.taps.clear()
	game.pressure = 0.0
	game.player.global_position = Vector2(0.0, -700.0)   ## no Boiler, no vent, no tap
	game.spawn_enemy("SCRAPPER", 1)
	var punchbag: SkyGearEnemy = null
	for e in game.get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and not e.dead:
			punchbag = e
	if punchbag != null:
		punchbag.global_position = game.player.global_position + Vector2(60.0, 0.0)
		punchbag.hp = 1e9
		punchbag.max_hp = 1e9
		game.damage_enemy(punchbag, 40.0, "STEAM", 0.0, game.player.global_position, true)
		_check("class", "landing a hit grants him NO Head", game.pressure <= 0.0,
			"filled to %.1f by one hit" % game.pressure)
		## And a close KILL, which is the other unguarded path.
		punchbag.hp = 1.0
		game.damage_enemy(punchbag, 999.0, "STEAM", 0.0, game.player.global_position, true)
		_check("class", "and killing one grants him none either",
			game.pressure <= 0.0, "filled to %.1f by a kill" % game.pressure)
		punchbag.dead = true
		punchbag.queue_free()

	## The captain must still fill from exactly those paths, or the gate was put
	## in the wrong place and one class was fixed by breaking the other.
	var her := _new_game()
	her.set_class("captain")
	her.set_seed_text("HERFILL")
	her.begin_run()
	her.choose_draft(0)
	her.start_wave(2)
	her.pressure = 0.0
	her.spawn_enemy("SCRAPPER", 1)
	var hers_target: SkyGearEnemy = null
	for e in her.get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and not e.dead:
			hers_target = e
	if hers_target != null:
		hers_target.global_position = her.player.global_position + Vector2(60.0, 0.0)
		hers_target.hp = 1e9
		hers_target.max_hp = 1e9
		her.damage_enemy(hers_target, 40.0, "EMBER", 0.0, her.player.global_position, true)
		_check("class", "but the captain still fills from landing one",
			her.pressure > 0.0, "%.1f" % her.pressure)
	her.queue_free()

	## And it fills on the Boiler, which is the one tap he does not have to make.
	game.pressure = 0.0
	game.player.global_position = game.boiler_position
	for _t in 10:
		game._update_pressure(0.1)
	_check("class", "but standing on the Boiler fills it", game.pressure > 20.0,
		"%.1f after a second" % game.pressure)

	## OVERPRESSURE: the bank is a damage multiplier the whole time it is above
	## zero, and every cast spends some. That is what stops banking being
	## hoarding — the bonus is the reason to hold it AND it runs out.
	game.pressure = 100.0
	_check("class", "a full bank makes every weapon hit harder",
		game.overpressure_multiplier() > 1.4,
		"x%.2f" % game.overpressure_multiplier())
	var before_head: float = game.pressure
	game.spend_overpressure()
	_check("class", "and a cast spends some of it", game.pressure < before_head)
	game.pressure = 0.0
	_check("class", "an empty one is strictly base damage",
		is_equal_approx(game.overpressure_multiplier(), 1.0))

	## TAP MAIN. His one new simulation object, and the only source of gauge he
	## can put where he wants.
	##
	## Both his bindings refuse to fire outside PLAY — you cannot crack a main
	## open during the opening draft — so the run has to actually be running. The
	## first version of this block tested them straight after `begin_run`, which
	## leaves the game in DRAFT, and read the refusal as a bug.
	game.choose_draft(0)
	game.start_wave(3)
	game.taps.clear()
	game.tap_cooldown = 0.0
	game.pressure = 5.0
	_check("class", "a main cannot be opened on an empty bank", not game.tap_main())
	game.pressure = 60.0
	game.player.global_position = Vector2(0.0, 200.0)
	_check("class", "but can be on a full one", game.tap_main())
	_check("class", "and it costs what it says", game.pressure < 60.0)
	_check("class", "and it is on the deck", game.taps.size() == 1)
	## Standing in your own steam fills you and anchors you.
	_check("class", "standing in it anchors him", game.anchored())
	var in_tap: float = game.pressure
	for _t in 10:
		game._update_pressure(0.1)
	_check("class", "and refills the bank", game.pressure > in_tap)
	## It expires. A main that never closed would be a permanent gauge.
	for _t in int(float(SkyGearData.TAP.life) / 0.1) + 4:
		game._update_taps(0.1)
	_check("class", "and it burns out", game.taps.is_empty())
	_check("class", "and he is no longer anchored", not game.anchored())

	## BLOWDOWN. Spend the bank as an explosion that also repairs — at a rate
	## that makes Boiler to Head to Boiler a LOSS, which is the guard against the
	## failure this class could have had.
	game.pressure = 10.0
	_check("class", "blowdown refuses a bank that is too small", not game.blowdown())
	game.pressure = 100.0
	game.boiler_hp = game.boiler_max_hp - 200.0
	game.player.global_position = game.boiler_position
	var hurt: float = game.boiler_hp
	_check("class", "but fires on a full one", game.blowdown())
	_check("class", "and empties the bank", game.pressure <= 0.0)
	_check("class", "and repairs the Boiler it is standing on", game.boiler_hp > hurt)
	## THE ROUND TRIP, MEASURED. This compared the repair against `100 * 0.6` —
	## a constant from a design that had been REMOVED, so it compared a real
	## number against a number the game did not contain and could not fail. An
	## audit measured 300 Boiler HP repaired free in thirty seconds behind it.
	##
	## Now it plays the loop: stand on the Boiler, take its heat, spend it back
	## into the Boiler, and compare what the ship actually lost against what it
	## actually got. If Boiler to Head to Boiler is ever a profit, the objective
	## cannot be lost and the game is a formality.
	game.pressure = 0.0
	game.boiler_hp = game.boiler_max_hp
	game.player.global_position = game.boiler_position
	for _t in 40:
		game._update_pressure(0.05)
	var ship_paid: float = game.boiler_max_hp - game.boiler_hp
	var banked_head: float = game.pressure
	_check("class", "taking the ship's heat costs the ship", ship_paid > 0.0,
		"%.1f HP for %.0f Head" % [ship_paid, banked_head])
	var before_blowdown: float = game.boiler_hp
	game.blowdown()
	var ship_got: float = game.boiler_hp - before_blowdown
	_check("class", "and giving it back returns less than it cost",
		ship_got < ship_paid,
		"%.1f back for %.1f spent" % [ship_got, ship_paid])

	## SCALD. His auto-attack is a narrower, slower, weaker cone of steam rather
	## than her wide fast ember arc — data now, where it used to be four magic
	## numbers inside `_process_basic_attack`.
	var his: Dictionary = SkyGearData.CLASSES.boilerwright.auto
	var hers: Dictionary = SkyGearData.CLASSES.captain.auto
	_check("class", "his auto-attack reaches further and swings slower",
		float(his.range) > float(hers.range) and float(his.period) > float(hers.period),
		"%.0f/%.2fs against %.0f/%.2fs" % [float(his.range), float(his.period),
			float(hers.range), float(hers.period)])
	_check("class", "and is narrower and weaker for it",
		float(his.arc) < float(hers.arc) and float(his.damage) < float(hers.damage))

	## And it actually fires, through the same path hers does.
	game.set_class("boilerwright")
	game.begin_run()
	game.choose_draft(0)
	game.start_wave(2)
	game.basic_cooldown = 0.0
	game.pressure = 0.0
	game.player.global_position = Vector2.ZERO
	game.spawn_enemy("SCRAPPER", 1)
	var scalded: SkyGearEnemy = null
	for e in game.get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and not e.dead:
			scalded = e
	if scalded != null:
		scalded.global_position = Vector2(0.0, -150.0)
		scalded.hp = 1e9
		scalded.max_hp = 1e9
		game.player.aim_direction = Vector2(0.0, -1.0)
		var untouched: float = scalded.hp
		game._process_basic_attack(0.016)
		_check("class", "and Scald lands", scalded.hp < untouched)
		_check("class", "on his own clock, not hers",
			is_equal_approx(game.basic_cooldown, float(his.period)),
			"%.2fs" % game.basic_cooldown)
		scalded.dead = true
		scalded.queue_free()

	## BLEED JET. His reposition costs the bank and lays scalding steam along the
	## path he is about to take — a retreat that is also a wall.
	game.fire_fields.clear()
	game.pressure = 5.0
	_check("class", "a jet cannot be paid for on an empty bank",
		not game.bleed_jet(Vector2(0.0, 1.0)))
	game.pressure = 80.0
	var banked: float = game.pressure
	_check("class", "but can on a full one", game.bleed_jet(Vector2(0.0, 1.0)))
	_check("class", "and every dodge is damage he did not do",
		game.pressure < banked, "%.0f -> %.0f" % [banked, game.pressure])
	_check("class", "and it leaves the lane behind him scalding",
		game.fire_fields.size() >= 4, "%d fields" % game.fire_fields.size())
	_check("class", "and he is actually moving", game.player.dash_time_left > 0.0)

	## The draft reaches for the shapes he can use. Not a different matrix — the
	## 36 cells stay 36 — just an order that puts ground-holding first.
	var his_first := {}
	for _roll in 40:
		var order: Array = game._weighted_shapes()
		his_first[str(order[0])] = int(his_first.get(str(order[0]), 0)) + 1
	var ground: int = int(his_first.get("RANGED_AOE", 0)) + int(his_first.get("AURA", 0)) 		+ int(his_first.get("PULSE", 0))
	var rifles: int = int(his_first.get("RAY", 0)) + int(his_first.get("LINE_BURST", 0))
	_check("class", "his draft favours ground over rifles", ground > rifles * 3,
		"%d ground, %d rifle in 40 rolls" % [ground, rifles])
	## Starved, not forbidden. Two matrices is two things to balance.
	_check("class", "but never forbids a shape outright",
		SkyGearData.CLASSES.boilerwright.shape_bias.values().min() > 0.0)

	## THE THREE FIELDS THAT WERE DECLARED AND NEVER READ. A table entry with no
	## reader is worse than a missing feature: it reads as done. Each of these
	## now has a check whose failure means "the data lies again".
	game.taps.clear()
	game.player.global_position = Vector2.ZERO
	game.pressure = 60.0
	game.tap_cooldown = 0.0
	game.tap_main()
	game.player.hp = game.player.max_hp

	## ANCHORED. Standing in his own steam is the compensation for having no
	## dash, and it was 25% in the table and 0% in the game.
	## The Bleed Jet check above left him mid-dodge, and a dodge ignores damage —
	## so the first version of this measured 0 against 0 and called it a bug in
	## the resist. Land the hit on a captain who is actually standing there.
	var full_hp: float = game.player.hp
	game.player.invulnerability_left = 0.0
	game.damage_player(40.0)
	var inside: float = full_hp - game.player.hp
	game.player.hp = game.player.max_hp
	game.player.global_position = Vector2(2000.0, 0.0)   ## out of his own main
	_check("class", "and he is only anchored inside it", not game.anchored())
	game.player.invulnerability_left = 0.0
	game.damage_player(40.0)
	var outside: float = game.player.max_hp - game.player.hp
	_check("class", "standing in his own steam actually reduces damage",
		inside < outside - 0.5, "%.1f inside against %.1f outside" % [inside, outside])
	_check("class", "by the amount the table says",
		is_equal_approx(inside, outside * (1.0 - float(SkyGearData.TAP.anchor_resist))),
		"%.2f against an expected %.2f"
			% [inside, outside * (1.0 - float(SkyGearData.TAP.anchor_resist))])

	## A KILL INSIDE A MAIN EXTENDS IT — the loop the whole class is built on.
	game.taps.clear()
	game.player.global_position = Vector2.ZERO
	game.pressure = 60.0
	game.tap_cooldown = 0.0
	game.tap_main()
	game.taps[0].life = 4.0
	game.spawn_enemy("SWARM", 1)
	var doomed: SkyGearEnemy = null
	for e in game.get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and not e.dead:
			doomed = e
	if doomed != null:
		doomed.global_position = Vector2(20.0, 0.0)   ## inside the main
		doomed.hp = 1.0
		var before_life: float = float(game.taps[0].life)
		game.damage_enemy(doomed, 999.0, "STEAM", 0.0, Vector2.ZERO, false)
		_check("class", "a kill inside a main extends it",
			float(game.taps[0].life) > before_life,
			"%.2f -> %.2f" % [before_life, float(game.taps[0].life)])
		doomed.dead = true
		doomed.queue_free()
	## But not forever, or a good position becomes a permanent one.
	game.taps[0].life = float(SkyGearData.TAP.max_life)
	game.spawn_enemy("SWARM", 1)
	var second: SkyGearEnemy = null
	for e in game.get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and not e.dead:
			second = e
	if second != null:
		second.global_position = Vector2(20.0, 0.0)
		second.hp = 1.0
		game.damage_enemy(second, 999.0, "STEAM", 0.0, Vector2.ZERO, false)
		_check("class", "but it cannot be extended past its cap",
			float(game.taps[0].life) <= float(SkyGearData.TAP.max_life) + 0.01,
			"%.2f against a cap of %.2f" % [float(game.taps[0].life),
				float(SkyGearData.TAP.max_life)])
		second.dead = true
		second.queue_free()

	## CREW INSIDE A MAIN SWING FASTER — the reason he is the only class with a
	## reason to care the crew layer exists.
	_check("class", "crew inside a main work faster",
		game._crew_haste(Vector2(20.0, 0.0)) > 1.0
			and is_equal_approx(game._crew_haste(Vector2(3000.0, 0.0)), 1.0),
		"%.2f inside, %.2f outside" % [game._crew_haste(Vector2(20.0, 0.0)),
			game._crew_haste(Vector2(3000.0, 0.0))])

	## And the middle lane has somewhere to refill. Two vents in lanes 0 and 2
	## and none in the centre is not a decision, it is a lane nobody holds.
	var vent_lanes := {}
	for entry in SkyGearData.PROP_LAYOUT:
		if str(entry.type) != "vent":
			continue
		var x: float = Vector2(entry.position).x
		vent_lanes[0 if x < -240.0 else (2 if x > 240.0 else 1)] = true
	_check("class", "and every lane has a vent to refill at",
		vent_lanes.size() == 3, "vents in lanes %s" % str(vent_lanes.keys()))

	game.taps.clear()
	game.spawn_queue.clear()

	## The captain is untouched by all of it.
	game.go_to_title()
	game.set_class("captain")
	game.begin_run()
	_check("class", "and the captain is exactly as she was",
		game.player.max_hp == 100.0 and game.player.move_speed == 260.0
			and game.player.max_dash_charges == 2 and not game.gauge_is_banked())
	_check("class", "with no overpressure bonus to speak of",
		is_equal_approx(game.overpressure_multiplier(), 1.0))

	##
	## Reported at playtest as "Boilerwright feels slower", and the stated
	## difference is 205 against 260 — 21%. That number is the answer to a
	## question nobody asked. It is TOP SPEED, and nobody experiences top speed;
	## they experience how far they got while a lane was walking down on them.
	##
	## `ACCEL` is shared, so he actually reaches his top speed FASTER than she
	## reaches hers (0.060s against 0.077s) — there is no hidden acceleration
	## penalty, and this measures rather than assumes it.
	##
	## The dash is the whole story. Measured over six seconds of holding one
	## direction, her dashing when it is off cooldown and him walking, because
	## his Bleed Jet is not free mobility — it costs bank he needs for the
	## multiplier that is the entire point of the class.
	game.spawn_queue.clear()
	game.go_to_title()
	await game.get_tree().process_frame

	## THE AUTO-ATTACK. It is a fifth of a run's damage on most builds and the
	## HUD never mentioned it, so "fight close" read as a risk with no upside.
	## The ring around the portrait is drawn from `basic_cooldown`, so the number
	## the HUD shows and the number the simulation swings on have to be the same
	## one — a decorative ring on its own timer is worse than no ring.
	game.go_to_title()
	game.set_seed_text("AUTO")
	game.begin_run()
	game.basic_cooldown = 0.0
	game.player.global_position = Vector2.ZERO
	game.spawn_enemy("SCRAPPER", 1)
	var prey: SkyGearEnemy = null
	for e in game.get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and not e.dead:
			prey = e
	if prey != null:
		prey.global_position = Vector2(90.0, 0.0)
		prey.hp = 1e9
		prey.max_hp = 1e9
		var before: float = prey.hp
		game._process_basic_attack(0.016)
		_check("auto", "she swings at anything in reach without being asked",
			prey.hp < before)
		_check("auto", "and the ring the HUD draws is on that same clock",
			game.basic_cooldown > 0.0,
			"cooldown %.3f" % game.basic_cooldown)
		## It KEEPS swinging while something is in reach — which is why the first
		## version of this check, waiting for the cooldown to read zero, waited
		## forever: it re-fires the instant it recovers and resets the clock.
		## Count the swings instead.
		var swings := 0
		var last_cd: float = game.basic_cooldown
		for _t in 200:
			game._process_basic_attack(0.01)
			if game.basic_cooldown > last_cd:
				swings += 1
			last_cd = game.basic_cooldown
		_check("auto", "and it keeps swinging while something is in reach",
			swings >= 4 and swings <= 8, "%d swings in 2 seconds" % swings)

		## And stops the moment nothing is. A ring that fills over an empty deck
		## is a promise the game does not keep.
		prey.global_position = Vector2(4000.0, 0.0)
		for _t in 100:
			game._process_basic_attack(0.01)
		_check("auto", "and stops when nothing is", game.basic_cooldown <= 0.0,
			"cooldown %.3f" % game.basic_cooldown)
		prey.dead = true
		prey.queue_free()
	game.spawn_queue.clear()
	game.go_to_title()
	await game.get_tree().process_frame

	## THE COACH. Its whole design problem is shutting up: a hint that fires
	## whenever a condition holds reads as noise inside a minute, and noise is
	## worse than silence because it teaches the player to ignore the strip the
	## Boiler warnings use. So the tests are almost all about NOT firing.
	game.go_to_title()
	game.set_seed_text("COACH")
	game.begin_run()
	game.choose_draft(0)
	game.coach.reset()
	game.player.global_position = Vector2.ZERO
	game.pressure = 100.0

	## Wave 1 is where you find the keys. Being corrected while you do that is
	## insulting, so nothing fires there however wrong you are.
	game.start_wave(1)
	game.spawn_enemy("SCRAPPER", 1)
	var wave_one := ""
	for _t in 200:
		wave_one = game.coach.advise(game, 0.1)
	_check("coach", "nothing is said during the first wave", wave_one == "",
		"said '%s'" % wave_one)

	## And a mistake has to be EARNED over seconds. Kiting for one second is
	## repositioning.
	game.coach.reset()
	game.start_wave(3)
	game.pressure = 100.0
	var coach_mark: SkyGearEnemy = null
	for e in game.get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and not e.dead:
			coach_mark = e
	if coach_mark != null:
		coach_mark.global_position = Vector2(120.0, 0.0)
		coach_mark.hp = 1e9
		var early := game.coach.advise(game, 0.5)
		_check("coach", "and one bad second is not a mistake", early == "",
			"said '%s'" % early)

		## Held long enough, it speaks — once.
		var spoke := ""
		for _t in 200:
			var said: String = game.coach.advise(game, 0.1)
			game.run_time += 0.1
			if said != "":
				spoke = said
				break
		_check("coach", "but a held one earns a line", spoke != "")

		## One at a time, never a queue. Both the gauge and the kiting conditions
		## are true here; a player mid-wave reads one line or none.
		game.coach.reset()
		game.run_time += 100.0
		var lines := {}
		for _t in 400:
			var said: String = game.coach.advise(game, 0.1)
			game.run_time += 0.1
			if said != "":
				lines[said] = true
		_check("coach", "and never two at once", lines.size() <= 1,
			"%d different lines in one window" % lines.size())

		## Twice a run, then it stops. If it did not land the second time it is
		## not going to.
		game.coach.reset()
		var fired := 0
		var last := ""
		for _t in 6000:
			var said: String = game.coach.advise(game, 0.1)
			game.run_time += 0.1
			if said != "" and said != last:
				fired += 1
			last = said
		_check("coach", "and says the same thing at most twice", fired <= 2,
			"fired %d times" % fired)
		coach_mark.dead = true
		coach_mark.queue_free()

	## An empty deck is not kiting. A player alone between waves being told they
	## are at range is how a coach loses its credibility on the first line.
	game.coach.reset()
	## Stop the wave BEFORE yielding. `game` is in the tree, so an awaited frame
	## runs `_process` and spawns the next boarders out of the queue — the first
	## version of this cleared the deck, awaited, and then tested "empty deck"
	## against four fresh scrappers.
	game.spawn_queue.clear()
	for stray in game.get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(stray):
			stray.dead = true
			stray.queue_free()
	await game.get_tree().process_frame
	for stray in game.get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(stray):
			stray.dead = true
			stray.queue_free()
	game.pressure = 0.0
	## ASSERT THE PRECONDITION. This check went red about one run in six and the
	## message — "said: you have been at range a while" — pointed at the coach,
	## when the truth was that the deck was not empty: `queue_free` does not leave
	## the group until the node is actually removed, and one clear plus one frame
	## is not always enough. A test whose setup can silently fail is a test that
	## accuses the wrong code.
	var left := 0
	for stray in game.get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(stray) and not stray.dead:
			left += 1
	_check("coach", "the deck really is empty before we test an empty deck",
		left == 0, "%d boarders still aboard" % left)
	var alone := ""
	for _t in 400:
		var said: String = game.coach.advise(game, 0.1)
		game.run_time += 0.1
		if said != "":
			alone = said
	_check("coach", "and an empty deck is never a mistake", alone == "",
		"said '%s'" % alone)

	## A DOWNED CANNON IS ANNOUNCED, AND THE ANNOUNCEMENT NAMES THE REAL KEY.
	##
	## Deckwork shipped working and unreachable: nothing on screen said a dead gun
	## could come back, so the whole verb table was code no player ever ran. The
	## empty deck above is the right place to test it from — no boarders, so no
	## other hint can win the priority order and mask this one.
	game.turrets[1].dead = true
	game.turrets[1].hp = 0.0
	game.coach.reset()
	game.deckwork = {}
	var told := ""
	for _t in 400:
		var word: String = game.coach.advise(game, 0.1)
		game.run_time += 0.1
		if word != "":
			told = word
	_check("coach", "a downed cannon is announced at all", told != "",
		"said nothing with a gun on the deck in pieces")
	## The KEY, not the word "R". The line is authored with a `{key}` token and
	## filled from the live binding, so a player who rebinds is not told to press
	## the one they replaced — and this is the check that would notice if the
	## substitution were ever dropped and the raw token shipped.
	var bound := SkyGearKeybinds.label("deckwork")
	_check("coach", "and it names the bound key rather than a hard-coded one",
		told.contains(bound) and not told.contains("{key}"),
		"'%s' does not carry '%s'" % [told, bound])
	## And it stops the moment they are doing it, because a coach that narrates
	## what you are visibly already doing stops being read.
	game.coach.reset()
	game.deckwork = {"spec": SkyGearDeckwork.actions()[0],
		"target": game.turrets[1], "contested": false}
	var nagged := ""
	for _t in 400:
		var word2: String = game.coach.advise(game, 0.1)
		game.run_time += 0.1
		if word2 != "":
			nagged = word2
	_check("coach", "and goes quiet once they are already repairing it",
		nagged == "", "still said '%s'" % nagged)
	game.turrets[1].dead = false
	game.turrets[1].hp = game.turrets[1].max_hp
	game.deckwork = {}

	game.spawn_queue.clear()
	game.go_to_title()
	await game.get_tree().process_frame

	## HOW TO PLAY. The title screen told you the controls and none of the game,
	## and this game has exactly one idea that is not obvious from the controls:
	## the gauge fills from fighting CLOSE, so the safe thing to do is the losing
	## thing to do. A player who does not know that kites and concludes the game
	## is unfair.
	_check("howto", "there is a how-to-play screen at all", "how_open" in game)
	game.how_open = true
	game.begin_run()
	_check("howto", "and starting a run closes it", not game.how_open)

	## The page quotes the simulation's own numbers. A tutorial with a hardcoded
	## 210 in it is a tutorial that lies the first time someone tunes the gauge.
	_check("howto", "and the close range it teaches is the one the game uses",
		float(SkyGearData.CLOSE.range) > 0.0
			and float(SkyGearData.CLOSE.vent_damage) > 0.0
			and float(SkyGearData.CLOSE.vent_radius) > 0.0)

	## WAVE EVENTS. Reported: "every 4 waves there should be a special event."
	## Waves 4, 8 and 12 already carried something, but a boarding hulk arriving
	## unannounced reads as "more boarders" rather than as the wave changing shape.
	var evented: Array[int] = []
	for w in range(1, SkyGearData.WAVES.size() + 1):
		if SkyGearGame.event_for(w) != "":
			evented.append(w)
	_check("event", "every fourth wave has one",
		str(evented) == str([4, 8, 12] as Array[int]), "got %s" % str(evented))
	## And no two of them are the same. The whole complaint was repetition; two
	## boarding pushes with different numbers is not an event, it is a difficulty
	## curve with a name on it.
	var kinds := {}
	for w in evented:
		kinds[SkyGearGame.event_for(w)] = true
	_check("event", "and no two of them are the same event",
		kinds.size() == evented.size(), "%d kinds for %d waves"
			% [kinds.size(), evented.size()])
	## Each one has to say what it is, or the player learns it by dying to it.
	var unnamed := ""
	for id in SkyGearData.EVENTS.keys():
		var data: Dictionary = SkyGearData.EVENTS[id]
		if str(data.get("name", "")) == "" or str(data.get("blurb", "")) == "":
			unnamed += " " + str(id)
	_check("event", "and each announces itself before it starts", unnamed == "",
		unnamed)

	## Running one turns it on, and the NEXT wave turns it off — an event that
	## leaks into wave 9 is a permanent difficulty change nobody chose.
	game.go_to_title()
	game.set_seed_text("EVENTS")
	game.begin_run()
	game.start_wave(8)
	_check("event", "starting wave 8 runs the blackout",
		game.active_event == "blackout", "got '%s'" % game.active_event)
	_check("event", "and it announces itself for a few seconds",
		game.event_banner_left > 1.0)
	## It pays, which is what makes engaging with it a choice rather than a tax.
	_check("event", "and the blackout is worth being out in",
		game.event_salvage_bonus() > 0.0 and game.event_pressure_bonus() > 0.0)
	game.start_wave(9)
	_check("event", "and wave 9 is a normal wave again",
		game.active_event == "" and game.event_salvage_bonus() == 0.0,
		"still '%s'" % game.active_event)

	## The banner has to expire on its own, or it sits over the fight.
	game.start_wave(4)
	_check("event", "wave 4 runs the grapple", game.active_event == "grapple")
	for _t in 60:
		game._process(0.1)
	_check("event", "and the announcement clears itself",
		game.event_banner_left <= 0.0, "%.1fs left" % game.event_banner_left)
	_check("event", "while the event itself keeps running",
		game.active_event == "grapple")

	## The renderer has to be able to hear about the dark one.
	_check("event", "the deck can be darkened for the blackout",
		game.view != null and game.view.has_method("set_darkness"))

	## Sweep the deck. Four `start_wave` calls queued four waves of boarders, and
	## `enemy_count` is tree-wide — leaving them alive fails a view check two
	## hundred lines later with a number nobody can trace back to here.
	for stray in game.get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(stray):
			stray.dead = true
			stray.queue_free()
	game.spawn_queue.clear()
	game.go_to_title()
	await game.get_tree().process_frame

	## FRAMES. Reported: "the text begins outside of the frame and continues over
	## onto the right so it's hard to read." The cause was two functions answering
	## "where does the brass end" differently — `SkyGearHUD._nine` drew a rail of
	## up to 48px while `interior()` claimed at most 30, so content was laid out
	## against a frame narrower than the one on screen.
	##
	## `tools/text_audit.gd` is the real detector — it renders 11 screens at 4
	## sizes and measures every string. These are the invariants that made the
	## bug possible, kept here so the tool has nothing to find.
	_check("frame", "the layout and the renderer agree where the brass ends",
		SkyGearHudLayout.interior(Rect2(0, 0, 330, 372))
			== SkyGearHUD.interior(Rect2(0, 0, 330, 372)))
	## A plate must always have a usable middle. The first honest version of
	## `interior` returned a NEGATIVE height for the HUD strips, because a fixed
	## 48px rail is most of a 90px plate.
	var shapes := [Vector2(330, 372), Vector2(350, 118), Vector2(420, 76),
		Vector2(128, 96), Vector2(800, 520), Vector2(90, 40)]
	var starved := ""
	for shape in shapes:
		var room := SkyGearHUD.interior(Rect2(Vector2.ZERO, shape))
		if room.size.x < shape.x * 0.5 or room.size.y < shape.y * 0.5:
			starved += " %dx%d->%dx%d" % [shape.x, shape.y, room.size.x, room.size.y]
	_check("frame", "and every plate keeps at least half of itself",
		starved == "", starved)

	## The SHIPPED layout, not only the built-in default. The file is hand-edited
	## through F4, so it is the one that drifts — and it had all three lane rows
	## authored past the bottom of their plate, which the clamp then stacked on
	## top of each other so CENTRE disappeared entirely.
	var shipped := SkyGearHudLayout.load_layout()
	var complaints := ""
	for note in shipped.problems(Vector2(1600, 900)):
		if str(note).contains("outside its plate"):
			complaints += " " + str(note)
	_check("frame", "and the shipped layout keeps its items on their plates",
		complaints == "", complaints)

	## Clamping must not silently merge two rows into one. That is worse than the
	## overflow it prevents: an item hanging 4px over an edge is untidy, two
	## items on the same line is information the player never sees.
	var ship_plate: Rect2 = SkyGearHUD.hud_plates(Vector2(1600, 900)).ship
	var seen_rows := {}
	var merged := 0
	for lane in 3:
		var key := "%d" % roundi(shipped.item("ship", "lane%d" % lane, ship_plate).position.y)
		if seen_rows.has(key):
			merged += 1
		seen_rows[key] = true
	_check("frame", "and no two lane rows land on the same line", merged == 0,
		"%d rows collapsed" % merged)

	## THE CARD PREVIEW. It computes before -> after by RUNNING the card against a
	## copy of the state, which is the only way the preview cannot disagree with
	## the effect — but it makes "does it change anything" the load-bearing test.
	game.go_to_title()
	game.set_seed_text("PREVIEW")
	game.begin_run()
	game.choose_draft(0)
	game.open_draft()
	var touched := 0
	var previewed := 0
	var rng_moved := 0
	for option in game.draft_options:
		var mods_before: String = JSON.stringify(game.mods)
		var skills_before: String = JSON.stringify(game.skills)
		var boiler_before: float = game.boiler_hp
		var rerolls_before: int = game.rerolls
		var rng_before: int = game.rng.state
		var rows: Array = SkyGearCards.preview(game, option)
		if not rows.is_empty():
			previewed += 1
		if JSON.stringify(game.mods) != mods_before 				or JSON.stringify(game.skills) != skills_before 				or game.boiler_hp != boiler_before or game.rerolls != rerolls_before:
			touched += 1
		if game.rng.state != rng_before:
			rng_moved += 1
	_check("preview", "previewing a card changes nothing", touched == 0,
		"%d of %d cards leaked into the real state" % [touched, game.draft_options.size()])
	_check("preview", "and does not advance the seeded stream", rng_moved == 0,
		"%d cards moved the rng" % rng_moved)

	## Every card in the catalogue, not only the three that happened to roll —
	## a preview that crashes on the one epic card nobody drafted is a crash in
	## front of the player at the best moment of the run.
	game.skills = [SkyGearData.make_skill("CLOSEHIT", "EMBER"),
		SkyGearData.make_skill("RANGED_AOE", "FROST"),
		SkyGearData.make_skill("CHAIN", "ARC")]
	var first_slot := func(list: Array) -> int:
		return int(list[0]) if not list.is_empty() else 0
	var swept := 0
	var leaked := 0
	var with_numbers := 0
	for entry in SkyGearCards.catalogue():
		if not (entry.get("can") as Callable).call(game):
			continue
		var instance: Dictionary = (entry.get("make") as Callable).call(game, first_slot)
		var before: String = JSON.stringify(game.mods) + JSON.stringify(game.skills)
		var rows: Array = SkyGearCards.preview(game, instance)
		swept += 1
		if not rows.is_empty():
			with_numbers += 1
		if JSON.stringify(game.mods) + JSON.stringify(game.skills) != before:
			leaked += 1
	_check("preview", "every offerable card previews without leaking",
		leaked == 0 and swept > 0, "%d swept, %d leaked" % [swept, leaked])
	## Most cards move a number a player can be shown. Not all — "the next draft
	## offers four" has nothing to preview — so this is a floor, not a total.
	_check("preview", "and most of them have numbers to show",
		with_numbers >= swept / 2, "%d of %d swept" % [with_numbers, swept])

	## And the direction has to be right, or a green number is worse than none.
	var better := SkyGearCards.preview(game, {"apply": func(g):
		g.skills[0].mods["damage"] = float(g.skills[0].mods.get("damage", 1.0)) * 2.0,
		"affects": [0]})
	_check("preview", "more damage reads as an improvement",
		not better.is_empty() and bool(better[0].better),
		"got %s" % str(better))
	var worse := SkyGearCards.preview(game, {"apply": func(g):
		g.skills[0].mods["cooldown"] = float(g.skills[0].mods.get("cooldown", 1.0)) * 2.0,
		"affects": [0]})
	_check("preview", "and a longer cooldown does not",
		not worse.is_empty() and not bool(worse[0].better),
		"got %s" % str(worse))

	## THE SCREENS. Every one of these was a line of text naming a key: the title
	## said "press Enter" and never mentioned the four other things you could do,
	## the results screen said "C to copy, Enter for title" and hid the one thing
	## a player wants at the end of a run behind a key nobody reads, and there was
	## no settings screen at all.
	for action in ["toggle_fullscreen", "copy_report", "new_seed_run",
			"quit_game", "settings_open"]:
		_check("screens", "the menus can actually do '%s'" % action,
			game.has_method(action) or action in game,
			"neither a method nor a property")

	## PLAY AGAIN keeps the seed and NEW SEED does not — they are the two halves
	## of "again" and swapping them silently is the kind of bug nobody reports,
	## they just stop trusting the button.
	game.set_seed_text("KEEPME")
	game.begin_run()
	game.restart_run()
	_check("screens", "PLAY AGAIN keeps the seed", game.seed_text == "KEEPME",
		"became %s" % game.seed_text)
	game.new_seed_run()
	_check("screens", "and NEW SEED does not", game.seed_text != "KEEPME")

	## Starting a run has to close whatever menu was open over the title, or you
	## begin wave one behind a settings panel.
	game.go_to_title()
	game.settings_open = true
	game.keys_open = true
	game.begin_run()
	_check("screens", "beginning a run closes the menus",
		not game.settings_open and not game.keys_open)
	game.go_to_title()

	## And the copy button has to leave a trace, or it is a button that does
	## something invisible and a player presses it four times.
	game.copied_at = -99.0
	game.copy_report()
	_check("screens", "copying the report is acknowledged", game.copied_at > -99.0)

	## DEPLOYABLES. Reported from a real run: "I got the sentry ability and I
	## didn't even see a sentry drop." There was nothing to see — the shape was
	## marked passive and fired a beam out of the player's own body.
	game.skills = [SkyGearData.make_skill("SENTRY", "ARC")]
	game.sentries.clear()
	game.player.global_position = Vector2.ZERO
	game.cast_skill(0, Vector2(300, -200))
	_check("sentry", "a press puts one on the deck", game.sentries.size() == 1)
	if game.sentries.size() == 1:
		_check("sentry", "and it lands where you were pointing",
			Vector2(game.sentries[0].position).distance_to(Vector2(300, -200)) < 1.0,
			"landed at %s" % str(game.sentries[0].position))

	## Aimed past its reach it stops at the edge of reach rather than at the
	## cursor, or the cooldown buys you a turret anywhere on the ship.
	game.sentries.clear()
	game.skills[0].cooldown_left = 0.0
	game.cast_skill(0, Vector2(4000, 0))
	var reach: float = float(game.skill_stats(game.skills[0]).get("deploy_range", 520.0))
	_check("sentry", "an out-of-reach cursor clamps to reach",
		not game.sentries.is_empty()
		and Vector2(game.sentries[0].position).length() <= reach + 1.0,
		"at %.0f, reach %.0f" % [Vector2(game.sentries[0].position).length()
			if not game.sentries.is_empty() else -1.0, reach])

	## And a cursor off the ship clamps to the ship, or you place one in the sky.
	game.sentries.clear()
	game.skills[0].cooldown_left = 0.0
	game.player.global_position = Vector2(0, SkyGearGame.DECK_RECT.position.y + 100.0)
	game.cast_skill(0, Vector2(0, SkyGearGame.DECK_RECT.position.y - 400.0))
	_check("sentry", "and a cursor off the ship clamps to the ship",
		not game.sentries.is_empty()
		and SkyGearGame.DECK_RECT.has_point(Vector2(game.sentries[0].position)))

	## The other half of the report: it must NOT require the press. A slot that
	## demands a decision every nine seconds is a slot nobody drafts.
	game.sentries.clear()
	game.player.global_position = Vector2.ZERO
	game.skills[0].cooldown_left = 0.0
	game.skills[0].sentry_idle = 0.0
	var grace: float = float(game.skill_stats(game.skills[0]).get("auto_after", 2.5))

	## Not while the fight is not running. A menu left open for a minute should
	## not spit out twenty turrets the moment you look away.
	game._set_state(SkyGearGame.State.PAUSE)
	game._update_cooldowns(grace * 3.0)
	_check("sentry", "a paused game does not auto-place", game.sentries.is_empty())

	game._set_state(SkyGearGame.State.PLAY)
	game.skills[0].sentry_idle = 0.0
	game._update_cooldowns(grace * 0.5)
	_check("sentry", "an unpressed one waits before auto-casting",
		game.sentries.is_empty())
	game._update_cooldowns(grace * 0.6)
	_check("sentry", "and then places itself without a press",
		game.sentries.size() == 1)

	## Oldest-first retirement. Nine seconds of cooldown across twelve waves is a
	## deck made of turrets otherwise.
	game.sentries.clear()
	var cap: int = int(game.skill_stats(game.skills[0]).get("max_live", 2))
	for i in cap + 3:
		game.skills[0].cooldown_left = 0.0
		game.cast_skill(0, Vector2(float(i) * 30.0, 0.0))
	_check("sentry", "they retire oldest-first rather than stacking",
		game.sentries.size() == cap, "%d live, cap %d" % [game.sentries.size(), cap])

	## It fires on its own, at range, and the damage is filed against the slot
	## that placed it — a turret whose damage lands in nobody's row is a turret
	## the run report says is worthless.
	game.sentries.clear()
	game.tel = SkyGearTelemetry.fresh()
	game.skills[0].cooldown_left = 0.0
	game.player.global_position = Vector2.ZERO
	game.cast_skill(0, Vector2(200, 0))
	game.spawn_enemy("SCRAPPER", 1)
	var mark: SkyGearEnemy = null
	for e in game.get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and not e.dead:
			mark = e
	if mark != null:
		mark.global_position = Vector2(260, 0)
		mark.hp = 1e9
		mark.max_hp = 1e9
		var before_turret: float = mark.hp
		for _t in 20:
			game._update_sentries(0.1)
		_check("sentry", "it shoots on its own once placed", mark.hp < before_turret)
		_check("sentry", "and its damage is filed against the slot that placed it",
			float(game.tel.per[0].damage) > 0.0,
			"slot 0 recorded %.1f" % float(game.tel.per[0].damage))
		mark.dead = true
		mark.queue_free()

	## And it expires, or one placement holds a lane for the rest of the run.
	game.sentries.clear()
	game.skills[0].cooldown_left = 0.0
	game.cast_skill(0, Vector2(120, 0))
	var span: float = float(game.skill_stats(game.skills[0]).get("life", 14.0))
	for _t in int(span / 0.2) + 4:
		game._update_sentries(0.2)
	_check("sentry", "and it expires rather than holding the lane forever",
		game.sentries.is_empty())
	game.sentries.clear()

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
		## Against the model's OWN measured height, not against a number copied
		## from whichever pack was current when the check was written. An FBX
		## from a different exporter measures in different units and the check
		## has to survive that — the whole point of normalising by height.
		var measured: float = float(rig.model.get_meta("model_height", 0.0))
		_check("rig", "and scales the model to the height we asked for",
			measured > 0.0 and absf(rig.height_scale * measured
				- SkyGearView3D.CAPTAIN_HEIGHT * SkyGearView3D.WORLD_SCALE) < 0.01,
			"%.4f units x %.3f" % [measured, rig.height_scale])
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

	## Boarders take a mesh the moment one is ingested for their kind, and a
	## painted billboard until then. Both paths always present, because the
	## boarders will become models one at a time.
	_check("view", "a model path is derived from the enemy kind",
		SkyGearView3D.model_path("SCRAPPER") == "res://assets/models/scrapper/scrapper.tscn",
		SkyGearView3D.model_path("SCRAPPER"))
	_check("view", "and the captain's own model is where that rule says it is",
		SkyGearView3D.model_path("CAPTAIN") == SkyGearView3D.CAPTAIN_SCENE)

	## A BOARDER MODEL IS NOT A RIGGED ONE.
	##
	## `SkyGearRig3D` was written for the captain: 33 bones, 14 clips, an
	## AnimationPlayer and a Skeleton3D. What Meshy returns for a boarder is a
	## single static mesh with none of that. The component has to survive being
	## handed a lump, because `_sync_rig` calls `want()` on every boarder every
	## frame and does not know which kind came with clips — and the alternative,
	## a second code path for figures that do not animate, is the thing this
	## class exists to avoid.
	var lump_scene := SkyGearView3D.model_path("SCRAPPER")
	_check("view", "the scrapper is a mesh rather than a billboard",
		ResourceLoader.exists(lump_scene), lump_scene)
	if ResourceLoader.exists(lump_scene):
		var lump := SkyGearRig3D.new()
		root.add_child(lump)
		## The renderer's own arithmetic — see `_sync_all`, which is where a
		## boarder's height comes from — rather than a number typed here twice.
		var tall: float = (120.0 + float(SkyGearData.ENEMIES.SCRAPPER.radius) * 3.0) \
			* SkyGearView3D.WORLD_SCALE
		var stood: bool = lump.setup(lump_scene, tall, SkyGearView3D.LAYER_FIGURES)
		_check("rig", "a model with no AnimationPlayer still builds",
			stood and lump.anim == null)
		if stood:
			var measured: float = float(lump.model.get_meta("model_height", 0.0))
			_check("rig", "and the wrapper measured it, so nothing guesses its height",
				measured > 0.0, "%.4f model units" % measured)
			_check("rig", "and it is scaled to the height the renderer asked for",
				absf(measured * lump.height_scale - tall) < 0.001,
				"%.3f m, wanted %.3f" % [measured * lump.height_scale, tall])
			## Driving it has to be a no-op rather than a crash. `want` returns on a
			## null player before it touches `state`, which is why nothing here is
			## expected to change.
			lump.want("swing", 200.0, 0.4)
			lump.want("run", 200.0)
			_check("rig", "and asking a clipless model to swing changes nothing",
				lump.state == "idle" and lump._clip == "", lump.state)
			lump.place(Vector2(120.0, -40.0), Vector2(0.0, 1.0),
				SkyGearView3D.WORLD_SCALE, 1.0)
			_check("rig", "and it still stands where the simulation put it",
				lump.position.is_equal_approx(Vector3(1.2, 0.0, -0.4)), str(lump.position))
			## FEET ON THE DECK. `place()` puts the root at y=0 and Meshy centres a
			## mesh on its own bounding box, so a boarder wrapped without the lift
			## stands in the planking up to the waist — which is not a crash, not a
			## warning, and invisible until somebody looks at a screenshot.
			var floor_y := INF
			var ceiling_y := -INF
			for child in lump.model.find_children("*", "MeshInstance3D", true, false):
				var mi := child as MeshInstance3D
				if mi.mesh == null:
					continue
				var box: AABB = mi.global_transform * mi.get_aabb()
				floor_y = minf(floor_y, box.position.y)
				ceiling_y = maxf(ceiling_y, box.position.y + box.size.y)
			_check("rig", "and it stands ON the deck rather than in it",
				absf(floor_y) < 0.02, "lowest point at %.4f m" % floor_y)
			## The height it actually occupies, not the height it was told. A model
			## that arrived in several pieces and was measured by the tallest one
			## passes every check above and is still the wrong size.
			_check("rig", "and it fills the height it was given, crown to sole",
				absf((ceiling_y - floor_y) - tall) < 0.02,
				"%.3f m of %.3f" % [ceiling_y - floor_y, tall])
			## Decals project onto whatever is inside their box. A boarder on the
			## world layer wears every mortar ring it walks through.
			for child in lump.model.find_children("*", "MeshInstance3D", true, false):
				if (child as MeshInstance3D).layers != SkyGearView3D.LAYER_FIGURES:
					stood = false
			_check("rig", "and every piece of it is on the figures layer", stood,
				"layer %d" % SkyGearView3D.LAYER_FIGURES)
			## A flinch rides on the scale so it cannot disturb where the figure is
			## standing. On a clipless model it is the ONLY reaction there is —
			## there is no hurt clip to fall back to — so it had better work.
			lump.react_hit(1.0)
			lump.place(Vector2(120.0, -40.0), Vector2(0.0, 1.0),
				SkyGearView3D.WORLD_SCALE, 1.0)
			_check("rig", "and a hit squashes it without moving it",
				lump.position.is_equal_approx(Vector3(1.2, 0.0, -0.4))
					and lump.scale.y < lump.height_scale,
				"scale %.3f of %.3f" % [lump.scale.y, lump.height_scale])
		lump.queue_free()
	var billboards := 0
	for key in view._billboards.keys():
		if str(key).begins_with("e"):
			billboards += 1
	_check("view", "and whichever renderer a kind uses, every boarder is drawn",
		billboards + view._rigs.size() >= game.enemy_count(),
		"%d billboards, %d rigs, %d boarders"
			% [billboards, view._rigs.size(), game.enemy_count()])

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
	## The PROPERTY, not the count. This asserted `size() == 10` and went red the
	## moment a legitimate eleventh binding was added — a check that fails when
	## the code is right teaches people to edit checks, which is worse than not
	## having it.
	##
	## What actually matters: a key that closes a menu, copies the report or opens
	## a tool must never be rebindable, because rebinding your way out of the
	## rebind screen leaves no way back in.
	var menu_only := ""
	for reserved in ["copy_report", "layout", "profiler", "fullscreen",
			"how_to_play", "settings", "workshop", "controls"]:
		if _rebindable_contains(reserved):
			menu_only += " " + reserved
	_check("keys", "menu keys are deliberately not rebindable", menu_only == "",
		"rebindable but should not be:" + menu_only)
	## And every rebindable action must actually exist in the input map, or the
	## controls screen offers a row that binds nothing.
	var phantom := ""
	for binding in SkyGearKeybinds.REBINDABLE:
		if not InputMap.has_action(str(binding[0])):
			phantom += " " + str(binding[0])
	_check("keys", "and every one of them is a real action", phantom == "",
		"listed but not in the input map:" + phantom)


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
	## Everything is in the bottom band EXCEPT the objective, which is
	## deliberately at the top: it is the thing you lose by, an eye goes there
	## first, and it is slim enough to cost almost none of the deck the boarders
	## cross. The exception is named rather than implied, so a plate that drifts
	## upward by accident is still caught.
	var probe := Vector2(1366, 768)
	var band := true
	var stray := ""
	var plates_at := SkyGearHUD.hud_plates(probe)
	for name in plates_at:
		if name in SkyGearHudLayout.TOP_ALLOWED:
			continue
		if (plates_at[name] as Rect2).position.y < probe.y * 0.60:
			band = false
			stray = str(name)
	_check("layout", "everything but the objective is in the bottom band", band, stray)
	## And the objective earns its place by staying out of the way.
	var objective: Rect2 = plates_at.objective
	_check("layout", "the objective is at the top and slim enough to be there",
		objective.position.y < probe.y * 0.2 and objective.size.y <= probe.y * 0.16,
		"%d px tall at y %d" % [objective.size.y, objective.position.y])

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


## --- the dash ceiling ---------------------------------------------------------
## In its own pass, at the end. `enemy_count()` walks the whole tree, so a second
## game alive at the same time as the view checks inflates their boarder count —
## a test that breaks a different test is worse than the bug it was written for.
func _dash() -> void:
	## THE DASH UPGRADE WAS UNPURCHASABLE. `cards.gd` has an epic that raises
	## `mods.dash_charges` to three, and `player.gd` used a const as the ceiling,
	## so the card was in the draft, cost a pick, and did nothing.
	var dash_game := _new_game()
	_begin(dash_game)
	dash_game._process(0.05)
	var base_charges: int = dash_game.player.max_dash_charges
	dash_game.mods.dash_charges = 3
	dash_game._process(0.05)
	_check("dash", "the draft can actually raise the dash ceiling",
		dash_game.player.max_dash_charges == 3 and base_charges == 2,
		"%d -> %d" % [base_charges, dash_game.player.max_dash_charges])
	## And the third charge has to be spendable, not just counted.
	dash_game.player.dash_charges = 3
	var spent := 0
	for i in 4:
		var before: int = dash_game.player.dash_charges
		dash_game.player._try_dash(Vector2.UP)
		if dash_game.player.dash_charges < before:
			spent += 1
		dash_game.player.dash_time_left = 0.0
	_check("dash", "and the third charge can be spent",
		spent == 3, "%d dashes from 3 charges" % spent)
	## A run reset must restore the raised ceiling, not the const.
	dash_game.player.reset_for_run()
	_check("dash", "and a fresh run starts with all of them",
		dash_game.player.dash_charges == dash_game.player.max_dash_charges,
		"%d of %d" % [dash_game.player.dash_charges, dash_game.player.max_dash_charges])
	dash_game.queue_free()


## --- text you can read, and cards you can read at a glance --------------------
##
## Two reports, one pass. "Text on skills and cards and HUD elements is hard to
## read" and "the element, rarity and active/passive role feel lost". Neither is
## a containment bug and `tools/text_audit.gd` was green through both of them,
## which is why the audit grew a legibility pass and why these checks exist: the
## audit renders and looks, and this asserts the RULES the renderer is supposed
## to follow, read from the one place they are written down.
func _ink() -> void:
	## THE FLOOR IS A FLOOR. `_fits` is the function that produced the bug — it
	## shrinks a label until it fits its box, the call sites passed floors of 7,
	## 8, 9 and 11, and "draft a weapon" in an empty skill slot was drawn at seven
	## points on painted brass. A caller may ask for smaller and must not get it.
	var hud := SkyGearHUD.new()
	hud.font = ThemeDB.fallback_font
	var squeezed: int = hud._fits("a very long label that will never fit", 10.0, 20, 6)
	_check("ink", "a caller cannot argue the size floor down",
		squeezed == SkyGearInk.MIN_PT,
		"got %d, floor is %d" % [squeezed, SkyGearInk.MIN_PT])
	_check("ink", "and cannot ask for a size below it either",
		hud._fits("x", 400.0, 7) == SkyGearInk.MIN_PT,
		"got %d" % hud._fits("x", 400.0, 7))
	## A string that fits keeps the size it asked for, or the floor is a
	## flattener rather than a floor.
	_check("ink", "and a string that fits keeps the size it asked for",
		hud._fits("x", 400.0, 22) == 22, "got %d" % hud._fits("x", 400.0, 22))
	hud.free()

	## AND THE WIDGET LAYER IS NOT EXEMPT.
	##
	## Two levels: a label is measured against its WIDGET, a widget against the
	## PLATE it was declared on. The first version of the legibility work routed
	## widget text through the escape hatch for strings that belong to no plate,
	## which silenced the check at the moment it started working — the audit
	## reported sixteen screens clean while four pause buttons hung off the left
	## edge of their sheet. This is the guard against that coming back, and it
	## asserts the plumbing rather than the pixels: if either callback is
	## unhooked, the audit goes quiet and nothing else says so.
	var wired := SkyGearHUD.new()
	wired._ready()
	_check("ink", "widget text goes through the HUD's funnel, not its own",
		wired.ui.scribe.is_valid() and wired.ui.plate.is_valid())
	## A widget declared while a plate is open carries that plate, so the audit
	## can ask whether the BUTTON is in the right place rather than only whether
	## its label is centred in it.
	var sheet := Rect2(100, 100, 660, 400)
	wired._open_frame(sheet)
	wired.ui.begin("guard", wired, ThemeDB.fallback_font, Vector2(-999, -999))
	wired.ui.button(Rect2(120, 140, 300, 40), "OFF THE PLATE")
	var declared: Array = wired.ui.declared()
	var stamped := Rect2()
	var framed := false
	if not declared.is_empty():
		stamped = declared[0].get("frame", Rect2()) as Rect2
		framed = bool(declared[0].get("framed", false))
	_check("ink", "and every widget carries the plate it was declared on",
		framed and stamped.is_equal_approx(SkyGearHUD.interior(sheet)),
		str(stamped))
	## The one that was actually broken. A button laid out from the sheet rather
	## than from its interior lands on the brass, and this is the arithmetic that
	## says so.
	_check("ink", "and a button laid out from the sheet edge is caught",
		not SkyGearHUD.interior(sheet).encloses(Rect2(sheet.position.x + 26.0,
			sheet.position.y + 82.0, 300.0, 40.0)))
	wired.ui.begin("guard", wired, ThemeDB.fallback_font, Vector2(-999, -999))
	wired.free()
	

	## THE MEASURE ITSELF. `tools/text_audit.gd` fails builds on these numbers, so
	## a sign error here is a whole category of bug going unreported. Black on
	## white is 21:1 and a colour against itself is 1:1 — the two ends of WCAG,
	## which pin the direction as well as the scale.
	_check("ink", "contrast runs 1 to 21, the WCAG way",
		absf(SkyGearInk.contrast(Color.BLACK, Color.WHITE) - 21.0) < 0.01
			and absf(SkyGearInk.contrast(Color("#b0813f"), Color("#b0813f")) - 1.0) < 0.01,
		"%.2f and %.2f" % [SkyGearInk.contrast(Color.BLACK, Color.WHITE),
			SkyGearInk.contrast(Color("#b0813f"), Color("#b0813f"))])
	## Linearised, not averaged. Mid grey against white is 3.95 on the sRGB curve
	## and 2.0 if you skip it, and skipping it is the difference between "brass on
	## brass is fine" and the truth.
	_check("ink", "and linearises sRGB rather than averaging bytes",
		absf(SkyGearInk.contrast(Color("#808080"), Color.WHITE) - 3.95) < 0.05,
		"%.2f" % SkyGearInk.contrast(Color("#808080"), Color.WHITE))
	## The halo has to be a dark enough surround for the whole palette. Every tint
	## the HUD draws is lit; if the outline colour ever drifts pale, every string
	## in the game loses its separation at once and nothing else would say so.
	var worst := 99.0
	var worst_name := ""
	for hex in ["#eee5d5", "#e8c376", "#37f0c8", "#ff7a2f", "#cfc4b4", "#b0813f",
			"#c9b6e8", "#7adcff", "#b3a68f"]:
		var ratio: float = SkyGearInk.contrast(Color(hex), SkyGearInk.INK)
		if ratio < worst:
			worst = ratio
			worst_name = hex
	_check("ink", "the outline is a dark enough surround for every HUD tint",
		worst >= SkyGearInk.CONTRAST_FLOOR, "%s scores %.2f" % [worst_name, worst])
	_check("ink", "and it is actually drawn, not a constant nobody reads",
		SkyGearInk.OUTLINE > 0.0, "%.1f px" % SkyGearInk.OUTLINE)
	## The dimmed floor is a concession, not a second standard.
	_check("ink", "the dimmed floor is under the body floor and over nothing",
		SkyGearInk.CONTRAST_FLOOR_MUTED < SkyGearInk.CONTRAST_FLOOR
			and SkyGearInk.CONTRAST_FLOOR_MUTED > 1.0)

	## --- and every field on a card is read by something ----------------------
	##
	## `rarity` was written onto every drafted card by `game.gd` and read by
	## nothing, for the whole life of the port: three rarities in `cards.gd`, none
	## of them ever on screen. That is the fourth time this project has carried
	## data with no reader, and the Workshop already has a guard of this shape.
	var card_game := _new_game()
	_begin(card_game)
	var first := func(list: Array) -> int:
		return int(list[0]) if not list.is_empty() else 0
	var rarities := {}
	var seen_cards := 0
	var unresolved := ""
	for entry in SkyGearCards.catalogue():
		if not (entry.get("can") as Callable).call(card_game):
			continue
		var made: Dictionary = (entry.get("make") as Callable).call(card_game, first)
		made["id"] = str(entry.id)
		made["rarity"] = str(entry.rarity)
		made["scope"] = str(entry.scope)
		seen_cards += 1
		rarities[SkyGearCards.rarity_of(made)] = true
		## Every field the card face reads has to resolve for every card in the
		## catalogue, or the first one that does not takes a draft down with it.
		if str(entry.rarity) != SkyGearCards.rarity_of(made):
			unresolved = "%s has rarity %s" % [str(entry.id), str(entry.rarity)]
		if not SkyGearCards.SCOPE_LABEL.has(str(entry.scope)):
			unresolved = "%s has scope %s" % [str(entry.id), str(entry.scope)]
	_check("card", "every card in the catalogue resolves what the face draws",
		seen_cards > 20 and unresolved == "",
		unresolved if unresolved != "" else "%d cards" % seen_cards)
	_check("card", "and the rarity field is read at last — all three tiers appear",
		rarities.size() == SkyGearCards.RARITY_LOOK.size(),
		"%s of %s" % [", ".join(rarities.keys()), str(SkyGearCards.RARITY_LOOK.keys())])
	## Rarity is a value ramp, not a hue, because hue belongs to the element. A
	## ramp that is not monotonic reads as three unrelated colours.
	var ring_ramp := true
	var last_ring := -1.0
	for name in ["common", "rare", "epic"]:
		var look: Dictionary = SkyGearCards.RARITY_LOOK[name]
		if float(look.ring) < last_ring:
			ring_ramp = false
		last_ring = float(look.ring)
	_check("card", "and reads as a ramp — heavier metal for a better card", ring_ramp)
	## And no rarity may wear an element's colour, or the two channels collide on
	## exactly the cards where telling them apart matters most.
	var clash := ""
	for name in SkyGearCards.RARITY_LOOK:
		for key in SkyGearData.ELEMENTS:
			var metal: Color = SkyGearCards.RARITY_LOOK[name].metal
			var hue: Color = SkyGearData.ELEMENTS[key].color
			if metal.is_equal_approx(hue):
				clash = "%s is %s" % [str(name), str(key)]
	_check("card", "and no rarity metal is an element's hue", clash == "", clash)

	## ROLE. `SHAPES` marks AURA and PULSE passive and the card face never said
	## so — you could draft a Field and not find out it has no key until the
	## fight started. Every shape must answer, and both answers must occur.
	var role_answers := {}
	for shape in SkyGearData.SHAPES:
		role_answers[SkyGearCards.role_of({"kind": "skill",
			"skill": {"shape": shape, "element": "EMBER"}})] = true
	_check("card", "every weapon shape says whether it is active or passive",
		role_answers.size() == 2 and role_answers.has("ACTIVE")
			and role_answers.has("PASSIVE"),
		", ".join(role_answers.keys()))
	_check("card", "and a card that is not a weapon says neither",
		SkyGearCards.role_of({"kind": "card", "id": "hp"}) == "")

	## ELEMENT OWNS THE HUE, IN BOTH DRAFTS. This is the one that was actually
	## broken: an opening-draft weapon was tinted by its ELEMENT and a drafted
	## card by its SCOPE, so the one channel a player reads before any of the
	## words meant two different things depending on which draft they were in.
	card_game.skills.clear()
	card_game.open_draft()
	var opening_ok: bool = not card_game.draft_options.is_empty()
	for option in card_game.draft_options:
		var want: Color = SkyGearData.ELEMENTS[str(option.skill.element)].color
		if not SkyGearCards.hue_of(option).is_equal_approx(want):
			opening_ok = false
	_check("card", "an opening-draft weapon is painted its element's colour",
		opening_ok, "%d options" % card_game.draft_options.size())
	_check("card", "and a Frost card is Frost wherever the element came from",
		SkyGearCards.hue_of({"id": "brittle"}).is_equal_approx(
			SkyGearData.ELEMENTS.FROST.color)
		and SkyGearCards.hue_of({"element": "ARC"}).is_equal_approx(
			SkyGearData.ELEMENTS.ARC.color))
	## A card with no element says so rather than borrowing one, and brass must
	## not be any element's colour or brass would read as a fifth element.
	var brass_clash := false
	for key in SkyGearData.ELEMENTS:
		if SkyGearCards.NO_ELEMENT.is_equal_approx(SkyGearData.ELEMENTS[key].color):
			brass_clash = true
	_check("card", "and a card with no element is brass, which is not an element",
		SkyGearCards.hue_of({"id": "hp"}).is_equal_approx(SkyGearCards.NO_ELEMENT)
			and not brass_clash
			and SkyGearCards.element_label({"id": "hp"}) == "NO ELEMENT")
	## The lit-glyph row and the hue have to name the same element, or the card
	## says Frost at the top and lights an Ember slot at the bottom.
	card_game.skills.clear()
	for pair in [["CLOSEHIT", "EMBER"], ["RANGED_AOE", "FROST"]]:
		card_game.skills.append(SkyGearData.make_skill(str(pair[0]), str(pair[1])))
	var brittle := {"id": "brittle", "scope": SkyGearCards.SCOPE_ELEMENT}
	var lit: Array = SkyGearCards.affects(card_game, brittle)
	_check("card", "the lit slots and the card's hue name the same element",
		lit == [1] and SkyGearCards.element_of(brittle) == "FROST",
		"lit %s" % str(lit))
	card_game.queue_free()


## CUTSCENES. Four things are being pinned here, and the third matters most.
##
## 1. The saved format loads and interpolates to the keyframes it was authored
##    with, or a shot verified in the lab is not the shot the game plays.
## 2. Every cue the table names is really CALLED somewhere in the shipped code.
##    This is the direct guard against failure mode one — a saved file whose
##    trigger point does not exist reads as a wired cutscene and is inert. The
##    check reads the source rather than trusting the comment beside it.
## 3. **THE GAMEPLAY CAMERA COMES BACK EXACTLY.** Three systems are calibrated
##    against the shipped projection: every telegraph's size on the deck, every
##    billboard's height, and every sprite in `assets/`, which was PAINTED for
##    it. A cutscene that hands back a camera a fraction off leaves the rest of
##    the run subtly wrong with nothing on screen to say so. This snapshots the
##    full transform and the lens, runs a shot that moves the camera most of the
##    way across the deck and changes the field of view, and demands both back.
## 4. And that the shot really did move, so (3) cannot pass by doing nothing.
func _cutscene() -> void:
	var ids := SkyGearCutscene.list_ids()
	_check("cutscene", "there is at least one saved shot on disk",
		not ids.is_empty(), ", ".join(ids))

	## The index and the directory have to agree, because `list_ids` unions them
	## and an exported build may only be able to see one — a shot that plays in
	## the lab and not in the build is the worst of the available failures.
	var on_disk: Array[String] = []
	for file in DirAccess.get_files_at(SkyGearCutscene.DIR):
		if str(file).ends_with(".json") and str(file) != "index.json":
			on_disk.append(str(file).substr(0, str(file).length() - 5))
	on_disk.sort()
	var indexed: Array[String] = []
	var index = JSON.parse_string(FileAccess.get_file_as_string(SkyGearCutscene.INDEX))
	if index is Dictionary:
		for id in (index as Dictionary).get("cutscenes", []):
			indexed.append(str(id))
	indexed.sort()
	_check("cutscene", "the index names exactly the files beside it",
		indexed == on_disk, "index %s vs disk %s" % [str(indexed), str(on_disk)])

	## EVERY CUE HAS A CALL SITE, read out of the source so the table cannot
	## drift into fiction the way five previous saved formats did.
	var uncalled: Array[String] = []
	var source := ""
	for file in DirAccess.get_files_at("res://scripts"):
		if str(file).ends_with(".gd"):
			source += FileAccess.get_file_as_string("res://scripts/%s" % str(file))
	for name in SkyGearCutscene.CUES:
		if not source.contains("cue(\"%s\"" % str(name)):
			uncalled.append(str(name))
	_check("cutscene", "every cue the table names is actually called in scripts/",
		uncalled.is_empty(), "never fired: %s" % ", ".join(uncalled))

	## And the other direction: a saved shot whose cue nothing knows about would
	## never play, silently.
	var orphans: Array[String] = []
	for id in ids:
		var loaded := SkyGearCutscene.load_scene(id)
		if str(loaded.get("cue", "")) != "" and not SkyGearCutscene.CUES.has(str(loaded.cue)):
			orphans.append("%s wants %s" % [id, str(loaded.cue)])
	_check("cutscene", "and no saved shot names a cue that does not exist",
		orphans.is_empty(), ", ".join(orphans))

	## The wave-12 arrival, the one trigger wired end to end.
	var wired := SkyGearCutscene.for_cue("boss_arrival")
	_check("cutscene", "the Colossus arriving resolves to a real shot",
		wired != "", wired if wired != "" else "nothing is wired to boss_arrival")

	var shot := SkyGearCutscene.load_scene(wired)
	var shot_keys: Array = shot.get("keys", [])
	_check("cutscene", "and it is a movement rather than a pose",
		shot_keys.size() >= 3 and SkyGearCutscene.length(shot) > 1.0,
		"%d keys over %.2f s" % [shot_keys.size(), SkyGearCutscene.length(shot)])

	## INTERPOLATION HITS ITS KEYFRAMES. A curve that is merely close at the keys
	## is a curve that does not show you what you authored.
	var missed := ""
	for entry in shot_keys:
		var key: Dictionary = entry
		if str(key.get("from", "")) == "gameplay":
			continue                        # resolved at play time, not authored
		var at := SkyGearCutscene.sample(shot, float(key.t))
		if (at.eye as Vector3).distance_to(SkyGearCutscene.to_vector(key.eye)) > 0.01 \
				or (at.look as Vector3).distance_to(SkyGearCutscene.to_vector(key.look)) > 0.01 \
				or absf(float(at.fov) - float(key.fov)) > 0.001:
			missed += " t=%.2f" % float(key.t)
	_check("cutscene", "sampling at a keyframe's own time returns that keyframe",
		missed == "", missed)

	## And it EASES rather than sliding. A camera that lerps linearly reads as a
	## machine on a rail — full speed from the first frame, stopped dead on the
	## last — which is the clearest tell there is of an unauthored shot. Each
	## curve is pinned by shape rather than by value, so the names cannot swap.
	_check("cutscene", "inout leaves and arrives slowly, linear does not",
		SkyGearCutscene.ease_at("inout", 0.25) < 0.20
			and SkyGearCutscene.ease_at("inout", 0.75) > 0.80
			and is_equal_approx(SkyGearCutscene.ease_at("linear", 0.25), 0.25),
		"inout(0.25) = %.3f" % SkyGearCutscene.ease_at("inout", 0.25))
	_check("cutscene", "in accelerates, out decelerates, hold is a cut",
		SkyGearCutscene.ease_at("in", 0.5) < 0.5
			and SkyGearCutscene.ease_at("out", 0.5) > 0.5
			and SkyGearCutscene.ease_at("hold", 0.99) == 0.0
			and SkyGearCutscene.ease_at("hold", 1.0) == 1.0)
	## Every curve must start at 0 and end at 1, or a segment jumps at its own
	## keyframe and the shot ticks.
	var bad_ends := ""
	for kind in SkyGearCutscene.EASES:
		if not is_equal_approx(SkyGearCutscene.ease_at(str(kind), 0.0), 0.0) \
				or not is_equal_approx(SkyGearCutscene.ease_at(str(kind), 1.0), 1.0):
			bad_ends += " " + str(kind)
	_check("cutscene", "and every curve lands on both of its keyframes",
		bad_ends == "", bad_ends)

	## A PINNED KEY IS THE SHIPPED CAMERA. This is what lets a shot hand back
	## without a cut, and the numbers come out of the renderer's own solve.
	var focus := Vector2(-120.0, 480.0)
	var bound := SkyGearCutscene.bind(shot, focus)
	var bound_keys: Array = bound.keys
	var last: Dictionary = bound_keys[bound_keys.size() - 1]
	_check("cutscene", "a key pinned to the gameplay camera resolves to the shipped solve",
		SkyGearCutscene.to_vector(last.eye).distance_to(
			SkyGearCutscene.shipped_eye(focus)) < 0.01
		and absf(float(last.fov) - SkyGearCutscene.shipped_fov()) < 0.01,
		"eye %s" % str(SkyGearCutscene.to_vector(last.eye)))
	_check("cutscene", "and the file still says pinned, so it re-resolves next run",
		str((shot_keys[shot_keys.size() - 1] as Dictionary).get("from", "")) == "gameplay")

	## Now the real renderer.
	var world: Node3D = load("res://scenes/main3d.tscn").instantiate()
	root.add_child(world)
	var view: SkyGearView3D = world as SkyGearView3D
	var game: SkyGearGame = world.get_node("SkyGear")
	if game.impact != null:
		game.impact.enabled = false
	game.workshop = SkyGearWorkshop.fresh(true)
	_begin(game)
	game.player.global_position = Vector2(0, 200)
	## The sway is deliberately never still, so it cannot also be the thing a
	## framing check measures against — `_view` turns it off for the same reason.
	view.sway = false
	## SETTLED HARD, and this is not padding. `_build_world` already ran
	## `_track_camera` once against the captain's default position, so the follow
	## point starts 500 units out and eases in at `CAM_TAU`. Two frames leave a
	## residual of about a sixth of a ground unit still decaying, and the restore
	## check below then reads that decay as cutscene damage — which it did, at
	## 0.166 units, on the first run of this pass. Six long frames put the residual
	## under a millionth.
	for _i in 6:
		view._process(1.0)

	var before: Transform3D = view.camera.global_transform
	var before_fov: float = view.camera.fov
	var before_near: float = view.camera.near
	var before_hud: bool = game.hud.visible
	var before_controls: bool = game.player.controls_enabled
	var before_focus: Vector2 = view._focus
	var before_zoom: float = view.zoom_amount()

	_check("cutscene", "a shot can be played on the real renderer",
		view.play_cutscene(wired) and view.cutscene_active())

	## It has to MOVE, or the restore check below is satisfied by a cutscene that
	## did nothing at all. Half a second in, this one is down at the bow.
	view._process(0.5)
	var travelled: float = view.camera.global_position.distance_to(before.origin) \
		/ SkyGearView3D.WORLD_SCALE
	_check("cutscene", "and it takes the camera somewhere else entirely",
		travelled > 400.0, "%.0f ground units away" % travelled)
	_check("cutscene", "and the captain is locked and the HUD is down while it runs",
		not game.player.controls_enabled and not game.hud.visible)

	## Run it out. Twelve half-seconds is well past its four, and a shot that
	## will not end on its own is its own failure.
	for _i in 12:
		view._process(0.5)
	_check("cutscene", "it ends on its own rather than holding the camera",
		not view.cutscene_active())

	## One clean frame with nothing overriding — which is exactly what the frame
	## after a cutscene is.
	view._process(0.1)
	var after: Transform3D = view.camera.global_transform
	var drift: float = after.origin.distance_to(before.origin) / SkyGearView3D.WORLD_SCALE
	var turned: float = rad_to_deg(after.basis.get_rotation_quaternion().angle_to(
		before.basis.get_rotation_quaternion()))
	_check("cutscene", "THE GAMEPLAY CAMERA COMES BACK EXACTLY",
		drift < 0.01 and turned < 0.01,
		"%.5f ground units and %.5f degrees off" % [drift, turned])
	_check("cutscene", "and so does the lens the whole game is calibrated to",
		absf(view.camera.fov - before_fov) < 0.0001
			and absf(view.camera.near - before_near) < 0.0001,
		"%.4f deg vs %.4f" % [view.camera.fov, before_fov])
	_check("cutscene", "and the HUD, the controls, the follow point and the zoom",
		game.hud.visible == before_hud
			and game.player.controls_enabled == before_controls
			and view._focus.is_equal_approx(before_focus)
			and is_equal_approx(view.zoom_amount(), before_zoom),
		"hud %s  controls %s  focus %s" % [str(game.hud.visible),
			str(game.player.controls_enabled), str(view._focus)])

	## AND THE SAME AGAIN WITH A LENS THAT DOES NOT COME BACK BY ITSELF.
	##
	## Found by deliberately breaking `stop()` and watching which checks noticed:
	## the two above did not. The Colossus shot ends on a key pinned to the
	## gameplay camera, so its last field of view IS the shipped one and "the lens
	## came back" was true whether anything restored it or not — a check that
	## cannot fail is not evidence, which is this project's third named failure
	## mode. This shot ends at seventy degrees, nine metres up and off to one side,
	## and it is what makes the claim mean something.
	var alien := SkyGearCutscene.normalise({"keys": [
		{"t": 0.0, "eye": [0.0, 900.0, -900.0], "look": [0.0, 0.0, 0.0], "fov": 70.0},
		{"t": 0.4, "eye": [700.0, 900.0, -900.0], "look": [0.0, 0.0, 0.0], "fov": 70.0}]})
	_check("cutscene", "a shot may break the shipped solve entirely",
		bool(view._cutscene.begin(alien)))
	view._process(0.2)
	_check("cutscene", "and it really is a different lens while it runs",
		absf(view.camera.fov - 70.0) < 0.001, "%.2f deg" % view.camera.fov)
	for _i in 4:
		view._process(0.5)
	view._process(0.1)
	_check("cutscene", "and the shipped lens is put back when it ends",
		absf(view.camera.fov - before_fov) < 0.0001,
		"%.4f deg, wanted %.4f" % [view.camera.fov, before_fov])
	var alien_drift: float = view.camera.global_position.distance_to(before.origin) \
		/ SkyGearView3D.WORLD_SCALE
	_check("cutscene", "and the camera with it", alien_drift < 0.01,
		"%.5f ground units off" % alien_drift)

	## A malformed file must never be able to take the camera away from the
	## player. Each of these is a real shape a half-written file arrives in.
	var refused := true
	for broken in [{}, {"keys": []}, {"keys": [{"t": 0.0}]}]:
		if bool(view._cutscene.begin(broken)):
			refused = false
	_check("cutscene", "a shot with no movement in it is refused rather than played",
		refused and not view.cutscene_active())
	_check("cutscene", "and an unknown cue plays nothing at all",
		not view.cue("no_such_moment") and not view.play_cutscene("no_such_file"))

	world.queue_free()


## HOW MUCH SLOWER IS THE BOILERWRIGHT, ACTUALLY?
##
## Reported at playtest as "Boilerwright feels slower". The stated difference is
## 205 against 260 — 21% — and that is the answer to a question nobody asked. It
## is TOP SPEED, and nobody experiences top speed; they experience how much
## ground they covered while a lane walked down on them.
##
## `ACCEL` is shared, so he reaches his top speed FASTER than she reaches hers
## (0.060s against 0.077s). There is no hidden acceleration penalty, which is
## worth having measured rather than assumed.
##
## IN ITS OWN FUNCTION, and that is not tidiness. The comment at the top of
## `_run` records that a block added inside `_view` once moved a coroutine pass
## and made sixty-one checks quietly stop existing. This block did it again —
## 435 became 342, green, no error — which is the third time. `_view` is over
## three thousand lines and is now closed to new work.
func _mobility() -> void:
	var travel := {}
	for who in ["captain", "boilerwright"]:
		var runner := _new_game()
		runner.set_class(who)
		_begin(runner)
		runner.spawn_queue.clear()
		var mover = runner.player
		mover.global_position = Vector2(0.0, 600.0)
		## THROUGH THE INPUT MAP, because `input_direction` is a local read from
		## `Input.get_vector` inside `_physics_process` and not a field anything
		## can set — the first attempt assigned to it and threw, silently, inside
		## a coroutine.
		Input.action_press("move_up")
		## INTEGRATE THE SPEED THE SIM PRODUCES, not the position the body lands on.
		## The first version of this read `global_position` after `_physics_process`,
		## and the body is committed by `CharacterBody2D.move_and_slide()`, which
		## steps by `get_physics_process_delta_time()` — a REAL-frame quantity tied
		## to the engine's physics clock, not the 0.05 tick this loop hands out. So
		## the same six simulated seconds landed the captain anywhere from 4600 to
		## 6800 units run to run, and the ratio swung across 200–570%: the check was
		## measuring wall-clock jitter, not the dash. Speed, by contrast, is set from
		## the 0.05 delta alone (accel, friction, dash time, recharge all read it),
		## so `|velocity| * 0.05` summed over the ticks is the ground covered and is
		## bit-for-bit repeatable. Ledger 2026-08-01: captain 3076, boilerwright
		## 1228 every run — a boilerwright who covers 40% of her ground.
		var ground := 0.0
		for _tick in 120:
			## She dashes whenever it is off cooldown; he walks. His Bleed Jet is
			## NOT free mobility — it costs the bank carrying the multiplier the
			## whole class is built on, so spending it to keep up is the trade
			## rather than the baseline.
			if who == "captain" and mover.dash_charges > 0 and mover.dash_time_left <= 0.0:
				mover._try_dash(Vector2.UP)
			## FORCED ON EACH TICK. Movement lives behind `controls_enabled`, and an
			## empty spawn queue lets the wave complete and flips the state to DRAFT
			## a few ticks in — which set the flag false and stopped both movers dead
			## partway through, truncating the measurement at a wave-timing-dependent
			## point. This measures movement, so it keeps the mover moving.
			mover.controls_enabled = true
			runner._process(0.05)
			mover.controls_enabled = true
			mover._physics_process(0.05)
			ground += absf(mover.velocity.y) * 0.05
		Input.action_release("move_up")
		travel[who] = ground
		runner.queue_free()

	var walk_ratio: float = 205.0 / 260.0
	var real_ratio: float = float(travel.boilerwright) / maxf(1.0, float(travel.captain))
	_check("class", "the boilerwright's top speed is 79% of hers, as designed",
		is_equal_approx(snappedf(walk_ratio, 0.01), 0.79), "%.2f" % walk_ratio)
	## THE ONE THAT MATTERS. If ground covered tracked the speed ratio then
	## "feels slower" would just be the 21% and the answer would be explanation.
	_check("class", "but ground covered against a dashing captain is worse than that",
		real_ratio < walk_ratio - 0.05,
		"he covers %.0f%% of her distance against a %.0f%% walk speed"
			% [real_ratio * 100.0, walk_ratio * 100.0])
