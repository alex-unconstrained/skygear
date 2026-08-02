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
	## And the SHIP re-read from that bench (SG-56): `_ready` snapshotted the
	## berthed set off the dev machine's real save, and a harness whose decks
	## carry the developer's own wreck is a harness that depends on a save file.
	game.refresh_berthed()
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
	_stow()
	await process_frame
	_fittings()
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
	## AWAITED — this pass draws real frames. See the note above `_view`.
	await _screen_editor()
	await process_frame
	## AWAITED — this one poses real sandboxes over a live run. Same rule.
	await _screen_poser()
	await process_frame
	_dash()
	await process_frame
	_mobility()
	await process_frame
	_ink()
	await process_frame
	_lab()
	await process_frame
	_clip()

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


## What survived the stowage spine (board SG-48/SG-51). The seeded per-wave
## deal was built to SHIP-AND-MAPS §4/§9, measured by §7.1's own kill-test,
## and CUT when close-share came back indistinguishable flat vs live — the
## verdict and the numbers are on the board row, the spine is at commit
## d10f09c. The POWDER STORE spacing fix was a real bug regardless, and this
## pins it: §7.3's chain says any keg within 200 units of a detonation
## detonates too, and the drop could stack its keg onto a stowed one.
func _stow() -> void:
	var a := _new_game()
	_begin(a, "STOW")
	a.talents = {"extra_kegs": 8.0}
	a.restow_props()
	var keg_at: Array[Vector2] = []
	for p in a.props():
		if p.prop_type == "keg" and not p.dead:
			keg_at.append(p.global_position)
	var nearest := INF
	for i in keg_at.size():
		for j in range(i + 1, keg_at.size()):
			nearest = minf(nearest, keg_at[i].distance_to(keg_at[j]))
	_check("stow", "the powder store keeps its kegs two hundred apart",
		keg_at.size() >= 12 and nearest >= SkyGearData.KEG_SPACING,
		"%d kegs, nearest pair %.0f" % [keg_at.size(), nearest])
	a.talents = {}
	a.queue_free()


## --- THE FITTINGS (board SG-56) ------------------------------------------------
## Between-run ship modification, under the owner's midnight rule: fittings are
## earned by finishing waves, chosen into six berths BETWEEN runs, applied once
## at run start, and the ship never changes mid-run. The §7.2 baseline, the
## forbidden-field shape, every award rule, the berth rules, persistence, and
## the deck changes themselves are each pinned below.
func _fittings() -> void:
	## 1 · THE TABLE'S SHAPE. The hard rule from SHIP-AND-MAPS §5, structural:
	## a fitting may only change the DECK or the VERB TABLE, so its row may
	## only carry the keys those changes need — and no row may so much as NAME
	## `mods`, `player`, or any Workshop field.
	var allowed := ["name", "text", "earn", "props", "wall", "turret", "verb"]
	var stray := ""
	var named := ""
	var forbidden: Array[String] = ["mods", "player"]
	for node_id in SkyGearWorkshop.NODES.keys():
		forbidden.append(str(SkyGearWorkshop.NODES[node_id].field))
	for id in SkyGearFittings.FITTINGS.keys():
		var entry: Dictionary = SkyGearFittings.FITTINGS[id]
		for key in entry.keys():
			if str(key) not in allowed:
				stray += " %s.%s" % [id, key]
		var flat := JSON.stringify(entry)
		for bad in forbidden:
			if flat.contains('"%s"' % bad):
				named += " %s->%s" % [id, bad]
	_check("fittings", "no fitting names a forbidden field",
		stray == "" and named == "", ("stray:%s named:%s" % [stray, named])
			if stray != "" or named != "" else "6 rows, keys within {%s}" % ",".join(allowed))

	## And a verb-granting fitting must name a row the verb table actually has,
	## with the row naming it back — the cross-link that keeps the `verb` key
	## from becoming data with no reader.
	var verb_link := true
	var link_note := ""
	for id in SkyGearFittings.FITTINGS.keys():
		var verb := str((SkyGearFittings.FITTINGS[id] as Dictionary).get("verb", ""))
		if verb == "":
			continue
		var found := false
		for spec in SkyGearDeckwork.actions():
			if str(spec.id) == verb and str(spec.get("fitting", "")) == str(id):
				found = true
		verb_link = verb_link and found
		link_note += " %s<->%s:%s" % [id, verb, found]
	_check("fittings", "a verb-granting fitting names a real verb row, and the row names it back",
		verb_link, link_note)

	## 2 · THE AWARD RULES, fixture rows through the real `bank()` — the one
	## place that knows the meta rule. At most one per run, behind the latch.
	var shop := SkyGearWorkshop.fresh(true)
	var out: Dictionary = SkyGearWorkshop.bank(shop,
		{"won": false, "wave": 11, "salvage": 30})
	_check("fittings", "nothing is earned before the first victory",
		str(out.get("fitting", "?")) == ""
			and SkyGearFittings.earned_count(shop) == 0)
	out = SkyGearWorkshop.bank(shop, {"won": true, "wave": 12, "seed": "FIT1"})
	_check("fittings", "the first victory keeps the wreck, and it berths itself",
		str(out.get("fitting", "")) == "wreck"
			and SkyGearFittings.is_berthed(shop, "wreck"))
	out = SkyGearWorkshop.bank(shop, {"won": true, "wave": 12, "heat": 1,
		"class_id": "boilerwright", "healed": 0, "salvage": 30, "seed": "FIT2"})
	_check("fittings", "at most one fitting per run — the first unowned rule in table order",
		str(out.get("fitting", "")) == "bow_barricade"
			and SkyGearFittings.earned_count(shop) == 2,
		"kept %s" % str(out.get("fitting", "")))
	out = SkyGearWorkshop.bank(shop, {"won": true, "wave": 12, "heat": 2, "seed": "FIT3"})
	_check("fittings", "a Heat win pays the spare gun",
		str(out.get("fitting", "")) == "spare_gun", str(out.get("fitting", "")))
	out = SkyGearWorkshop.bank(shop, {"won": true, "wave": 12,
		"class_id": "boilerwright", "seed": "FIT4"})
	_check("fittings", "a Boilerwright win pays his vent",
		str(out.get("fitting", "")) == "fourth_vent", str(out.get("fitting", "")))
	out = SkyGearWorkshop.bank(shop, {"won": false, "wave": 5, "salvage": 12, "seed": "FIT5"})
	_check("fittings", "twelve salvage pays the winch, win or lose",
		str(out.get("fitting", "")) == "winch", str(out.get("fitting", "")))
	out = SkyGearWorkshop.bank(shop, {"won": true, "wave": 12, "healed": 0, "seed": "FIT6"})
	_check("fittings", "an unhealed win pays the scupper grating",
		str(out.get("fitting", "")) == "scupper_grating", str(out.get("fitting", "")))
	out = SkyGearWorkshop.bank(shop, {"won": true, "wave": 12, "heat": 3,
		"class_id": "boilerwright", "healed": 0, "salvage": 99, "seed": "FIT7"})
	_check("fittings", "and a ship that owns the set earns nothing more",
		str(out.get("fitting", "")) == ""
			and SkyGearFittings.earned_count(shop) == SkyGearFittings.FITTINGS.size())
	_check("fittings", "six earned fittings berthed themselves into exactly six berths",
		SkyGearFittings.berthed_ids(shop).size() == SkyGearFittings.CAP,
		str(SkyGearFittings.berthed_ids(shop)))

	## 3 · THE BERTH RULES: the cap, the lock, and the latch.
	var refit := SkyGearWorkshop.fresh(true)
	refit.unlocked = true
	refit.fittings = {"wreck": true, "bow_barricade": true}
	refit.berths = ["b1", "b2", "b3", "b4", "b5", "b6"]
	_check("fittings", "the berth cap refuses a seventh",
		not SkyGearFittings.can_berth(refit, "wreck")
			and not SkyGearFittings.berth(refit, "wreck"),
		"%d berthed" % SkyGearFittings.berthed_ids(refit).size())
	refit.berths = []
	_check("fittings", "a fitting the ship has not earned refuses to berth",
		not SkyGearFittings.berth(refit, "spare_gun"))
	var still_locked := SkyGearWorkshop.fresh(true)
	still_locked.fittings = {"wreck": true}
	_check("fittings", "and nothing berths before the first victory",
		not SkyGearFittings.berth(still_locked, "wreck")
			and SkyGearFittings.sailing(still_locked).is_empty())
	_check("fittings", "berthing and clearing round-trip the state",
		SkyGearFittings.berth(refit, "wreck")
			and SkyGearFittings.is_berthed(refit, "wreck")
			and SkyGearFittings.unberth(refit, "wreck")
			and not SkyGearFittings.is_berthed(refit, "wreck"))

	## 4 · PERSISTENCE, against the real file — backed up first and restored
	## after, because "round-trips the save" cannot be proven on a dictionary
	## in memory. The runlog checks already own `user://runs.json` this way.
	var had_file := FileAccess.file_exists(SkyGearWorkshop.PATH)
	var backup := FileAccess.get_file_as_string(SkyGearWorkshop.PATH) if had_file else ""
	var real := SkyGearWorkshop.fresh()
	real.unlocked = true
	real.fittings = {"wreck": true, "winch": true}
	real.berths = ["winch"]
	var wrote := SkyGearWorkshop.save_state(real)
	var back := SkyGearWorkshop.load_state()
	_check("fittings", "the earned set and the berthed set round-trip the save file",
		wrote and SkyGearFittings.earned(back, "wreck")
			and SkyGearFittings.earned(back, "winch")
			and SkyGearFittings.berthed_ids(back) == ["winch"]
			and not SkyGearFittings.is_berthed(back, "wreck"),
		"berths %s" % str(SkyGearFittings.berthed_ids(back)))
	## A pre-berth winner's save — no `fittings` key at all — keeps its trophy:
	## the wreck's earn rule IS the first victory, applied once by the load
	## migration. And the round-trip above proves the migration cannot re-berth
	## a wreck the player chose to clear (the `has` latch).
	var legacy := FileAccess.open(SkyGearWorkshop.PATH, FileAccess.WRITE)
	legacy.store_string(JSON.stringify({"unlocked": true, "scrip": 120,
		"sigils": 1, "nodes": {}, "articles": {"first_win": true}, "seeds": []}))
	legacy.close()
	var migrated := SkyGearWorkshop.load_state()
	_check("fittings", "a pre-berth winner's save keeps its wreck — earned and berthed by migration",
		SkyGearFittings.earned(migrated, "wreck")
			and SkyGearFittings.is_berthed(migrated, "wreck")
			and int(migrated.scrip) == 120)
	## The denied-write shape: an ephemeral save reports success and the disk
	## does not move — so no test, and no sandboxed player, can lose a refit
	## to a write that never happened.
	var ghost := SkyGearWorkshop.fresh(true)
	ghost.fittings = {"spare_gun": true}
	var ghost_saved := SkyGearWorkshop.save_state(ghost)
	var after := SkyGearWorkshop.load_state()
	_check("fittings", "a denied write reports clean without reaching the disk",
		ghost_saved and not SkyGearFittings.earned(after, "spare_gun"))
	if had_file:
		var restore := FileAccess.open(SkyGearWorkshop.PATH, FileAccess.WRITE)
		restore.store_string(backup)
		restore.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SkyGearWorkshop.PATH))

	## 5 · THE BARE-SHIP BASELINE (§7.2, byte for byte). A ship that has EARNED
	## everything and berthed NOTHING starts today's exact run — same seed,
	## identical DECK and identical starting numbers to a fresh save, down to
	## the seeded stream's state. Pinned at run start deliberately: run start
	## is the only moment a fitting is allowed to touch anything, so the deck's
	## identity there IS the whole claim — and advanced enemy positions are not
	## reproducible across game instances even bare-vs-bare (the SG-1
	## `move_and_slide` lesson; two identical games measurably drift), so a
	## trajectory compare would pin the harness's noise, not the fittings.
	## If a fitting cannot be added without moving this, it is not a fitting.
	var bare := _new_game()
	bare.set_seed_text("REFIT")
	bare.begin_run()
	var bare_rng: int = bare.rng.state
	bare.choose_draft(0)
	var bare_snap := _ship_snapshot(bare)
	var bare_vents := _prop_count(bare, "vent")
	## And the winch verb does not exist on a ship without the fitting.
	var bare_stack: SkyGearProp = null
	for p in bare.props():
		if is_instance_valid(p) and not p.dead and str(p.prop_type) == "crates" \
				and p != bare.barricade:
			bare_stack = p
			break
	bare.player.global_position = bare_stack.global_position + Vector2(0.0, 120.0)
	var bare_offer := SkyGearDeckwork.available(bare)
	_check("fittings", "the winch verb does not exist on a ship without the fitting",
		bare_offer.is_empty() or str(bare_offer.spec.id) != "winch_crate",
		"offered %s" % (str(bare_offer.spec.id) if not bare_offer.is_empty() else "nothing"))
	bare.queue_free()

	var earned_all := _new_game()
	earned_all.workshop.unlocked = true
	for id in SkyGearFittings.FITTINGS.keys():
		(earned_all.workshop.fittings as Dictionary)[id] = true
	earned_all.set_seed_text("REFIT")
	earned_all.begin_run()
	earned_all.choose_draft(0)
	var unberthed_snap := _ship_snapshot(earned_all)
	_check("fittings", "a ship with nothing berthed sails today's deck exactly — byte for byte",
		unberthed_snap == bare_snap and bare_vents == 3,
		"%d vs %d chars, %d vents" % [unberthed_snap.length(), bare_snap.length(), bare_vents])
	earned_all.queue_free()

	## 6 · EVERY DECK CHANGE PRESENT AFTER `begin_run`, whole set berthed.
	var kitted := _new_game()
	kitted.workshop.unlocked = true
	for id in SkyGearFittings.FITTINGS.keys():
		(kitted.workshop.fittings as Dictionary)[id] = true
		SkyGearFittings.berth(kitted.workshop, str(id))
	kitted.set_seed_text("REFIT")
	kitted.begin_run()
	_check("fittings", "placing the whole berth set consumes nothing from the seeded stream",
		kitted.rng.state == bare_rng, "rng %d vs %d" % [kitted.rng.state, bare_rng])
	kitted.choose_draft(0)
	_check("fittings", "the fourth vent and the scupper's vent stand at run start",
		_prop_count(kitted, "vent") == 5, "%d vents" % _prop_count(kitted, "vent"))
	var bow_line := 0
	for p in kitted.props():
		if is_instance_valid(p) and not p.dead and str(p.prop_type) == "crates" \
				and bool(p.get_meta("fitting", false)):
			bow_line += 1
	_check("fittings", "the bow barricade's crate line stands where the boarders land",
		bow_line == 2, "%d fixed crates" % bow_line)
	_check("fittings", "the spare gun is a fourth cannon and it ships broken",
		kitted.turrets.size() == 4 and bool(kitted.turrets[3].dead)
			and float(kitted.turrets[3].hp) == 0.0
			and int(kitted.turrets[3].lane) == 1,
		"%d guns" % kitted.turrets.size())
	_check("fittings", "and the lane's own gun still gates the lane while it lives",
		is_same(kitted.turret_in_lane(1), kitted.turrets[1]))
	kitted.player.global_position = Vector2(40.0, 640.0)
	var job := SkyGearDeckwork.available(kitted)
	_check("fittings", "the repair verb that already exists is how the spare gun comes back",
		not job.is_empty() and str(job.spec.id) == "repair_turret"
			and is_same(job.target, kitted.turrets[3]))
	var inside := Vector2(-280.0, 515.0)
	var pushed: Vector2 = kitted.correct_player_position(inside, 18.0)
	_check("fittings", "the scupper grating is closed to the captain",
		pushed != inside, "corrected to %.0f,%.0f" % [pushed.x, pushed.y])
	_check("fittings", "and invisible to the boarders' world — the cargo list is untouched",
		kitted.cargo_rects().size() == SkyGearGame.CARGO_RECTS.size() + 1,
		"%d rects (8 walls + the flank crate)" % kitted.cargo_rects().size())

	## The stow.gd-style invariant: with EVERY fitting berthed, the deck's
	## lateral movement graph survives. The scupper seals port-stern by
	## design; the other five crossings stay walkable — including the two the
	## fittings put a VENT in, because a vent is not a wall.
	var open_port := 0
	var open_star := 0
	for cross in [Vector2(-280.0, -470.0), Vector2(-280.0, 15.0), Vector2(-280.0, 515.0),
			Vector2(280.0, -470.0), Vector2(280.0, 15.0), Vector2(280.0, 515.0)]:
		if kitted.correct_player_position(cross, 18.0) == cross:
			if cross.x < 0.0:
				open_port += 1
			else:
				open_star += 1
	_check("fittings", "cross-passages stay passable with every fitting berthed",
		open_port == 2 and open_star == 3,
		"port %d of 3 open (the scupper seals one by design), starboard %d of 3"
			% [open_port, open_star])

	## THE WINCH, berthed: offered at a crate stack, one fixed step per tap,
	## and the stack can never land on the captain.
	var stack: SkyGearProp = null
	for p in kitted.props():
		if is_instance_valid(p) and not p.dead and str(p.prop_type) == "crates" \
				and p != kitted.barricade and not bool(p.get_meta("fitting", false)):
			stack = p
			break
	_check("fittings", "there is a crate stack for the winch to haul", stack != null)
	if stack != null:
		kitted.player.global_position = stack.global_position + Vector2(0.0, 120.0)
		var offer := SkyGearDeckwork.available(kitted)
		_check("fittings", "the winch verb exists exactly while its fitting is berthed",
			not offer.is_empty() and str(offer.spec.id) == "winch_crate",
			"offered %s" % (str(offer.spec.id) if not offer.is_empty() else "nothing"))
		kitted.player.global_position = stack.global_position + Vector2(0.0, 320.0)
		var start: Vector2 = stack.global_position
		kitted.winch_crate(stack)
		var first_step: float = start.distance_to(stack.global_position)
		kitted.winch_crate(stack)
		var close_gap: float = stack.global_position.distance_to(
			kitted.player.global_position)
		var parked: Vector2 = stack.global_position
		kitted.winch_crate(stack)
		_check("fittings", "a tap hauls one fixed step, and the stack can never land on the captain",
			absf(first_step - SkyGearGame.WINCH_STEP) < 0.5
				and absf(close_gap - SkyGearGame.WINCH_GAP) < 1.5
				and stack.global_position == parked,
			"step %.0f, parked at %.0f" % [first_step, close_gap])

	## 7 · THE RUN LOG carries the berthed set (SG-53's blocked half), and the
	## report names the refit — the deck half of what reproduces a run.
	SkyGearRunLog.clear()
	kitted.wave = 4
	kitted.damage_player(99999.0)
	var rows_all := SkyGearRunLog.load_all()
	var last: Dictionary = rows_all[rows_all.size() - 1] if not rows_all.is_empty() else {}
	_check("log", "the row carries the berthed set that reproduces the deck",
		(last.get("ship", []) as Array) == kitted.run_fittings
			and (last.get("ship", []) as Array).size() == SkyGearFittings.CAP,
		str(last.get("ship", [])))
	_check("log", "and the report names the refit",
		str(last.get("report", "")).contains("refit · THE WRECK"),
		str(last.get("report", "")).split("\n")[3] if str(last.get("report", "")) != "" else "")
	kitted.queue_free()

	## 8 · THE OWNER'S RULE ITSELF: the ship never changes mid-run. Sign every
	## berth into the save DURING a run and let the deck re-stow — nothing may
	## arrive until the next `begin_run` collects it.
	var mid := _new_game()
	mid.set_seed_text("REFIT")
	mid.begin_run()
	mid.choose_draft(0)
	mid.workshop.unlocked = true
	for id in SkyGearFittings.FITTINGS.keys():
		(mid.workshop.fittings as Dictionary)[id] = true
		SkyGearFittings.berth(mid.workshop, str(id))
	mid.start_wave(2)
	_check("fittings", "the ship never changes mid-run — a berth signed mid-run waits for the next run",
		_prop_count(mid, "vent") == 3 and mid.turrets.size() == 3
			and mid.fitting_walls.is_empty() and not mid.fitted("winch"),
		"%d vents, %d guns, %d walls" % [_prop_count(mid, "vent"),
			mid.turrets.size(), mid.fitting_walls.size()])
	mid.begin_run()
	mid.choose_draft(0)
	_check("fittings", "and the next run collects everything that was signed",
		_prop_count(mid, "vent") == 5 and mid.turrets.size() == 4
			and mid.fitting_walls.size() == 1 and mid.fitted("winch"),
		"%d vents, %d guns, %d walls" % [_prop_count(mid, "vent"),
			mid.turrets.size(), mid.fitting_walls.size()])
	mid.queue_free()


## One run's starting ship, byte for byte: the captain's numbers, the
## objective, the seeded stream's state, every stowed prop, every gun and the
## fitting walls. Two runs that print the same string begin on the same deck
## with the same numbers — which is everything a fitting is allowed to touch.
func _ship_snapshot(game: SkyGearGame) -> String:
	var props_list: Array = []
	for p in game.props():
		if is_instance_valid(p) and not p.dead:
			props_list.append("%s@%.2f,%.2f" % [p.prop_type,
				p.global_position.x, p.global_position.y])
	props_list.sort()
	var guns: Array = []
	for t in game.turrets:
		guns.append("L%d@%.0f,%.0f hp%.2f/%.2f dead:%s" % [int(t.lane),
			t.position.x, t.position.y, float(t.hp), float(t.max_hp), str(t.dead)])
	return "|".join([var_to_str(game.player.global_position),
		"hp%.3f/%.3f" % [game.player.hp, game.player.max_hp],
		"speed%.3f" % game.player.move_speed,
		"boiler%.3f/%.3f" % [game.boiler_hp, game.boiler_max_hp],
		"rerolls%d" % game.rerolls, "rng%d" % game.rng.state,
		"walls%d" % game.fitting_walls.size(),
		",".join(PackedStringArray(props_list)),
		",".join(PackedStringArray(guns))])


func _prop_count(game: SkyGearGame, kind: String) -> int:
	var n := 0
	for p in game.props():
		if is_instance_valid(p) and not p.dead and str(p.prop_type) == kind:
			n += 1
	return n


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

	## SG-27. The Boiler is the one prop every parity judgement now leans on —
	## bottom-centre of every frame, largest apparent object on the deck. The
	## regression that started this: its generated mesh was scaled to a taste
	## number (168) rather than to what the browser draws, and because the mesh is
	## a near-cube (168 tall x 167 wide x 162 DEEP, measured) it rendered 208 px
	## tall / 291 px wide — a solid drum dominating the lower third against the
	## browser's FLAT 150-unit block. `BOILER_HEIGHT` is now pinned to the LIVE
	## browser's `boilerH` (storm-dusk-v11 = 150). This measures the ACTUAL
	## rendered subtree — mesh or primitive fallback — so the next generated mesh
	## dropped in cannot silently come back taller. A screenshot would only show
	## you it had; this fails the build.
	var browser_boiler_h := 150.0        # PRESET.boilerH, storm-dusk-v11 (LIVE)
	var want_boiler: Vector3 = Vector3(SkyGearGame.BOILER_POSITION.x, 0.0,
		SkyGearGame.BOILER_POSITION.y) * SkyGearView3D.WORLD_SCALE
	var boiler_node: Node3D = null
	for child in view.get_children():
		if child is Node3D and (child as Node3D).position.distance_to(want_boiler) < 0.001:
			boiler_node = child
			break
	var boiler_h_gu := -1.0
	if boiler_node != null:
		var bbox := AABB()
		var bfirst := true
		for mi_any in boiler_node.find_children("*", "MeshInstance3D", true, false):
			var mi := mi_any as MeshInstance3D
			if mi.mesh == null:
				continue
			var here := mi.global_transform * mi.get_aabb()
			bbox = here if bfirst else bbox.merge(here)
			bfirst = false
		if not bfirst:
			boiler_h_gu = bbox.size.y / SkyGearView3D.WORLD_SCALE
	_check("boiler", "renders at the browser's boilerH, not a taller mesh's own height",
		boiler_node != null and absf(boiler_h_gu - browser_boiler_h) < 3.0
			and absf(SkyGearView3D.BOILER_HEIGHT - browser_boiler_h) < 0.01,
		"%.1f ground units vs browser boilerH %.0f" % [boiler_h_gu, browser_boiler_h])

	## SG-30 — AND THE FALLBACK TIER IS HONEST TOO. The check above measures
	## whichever body is LIVE, which today is the generated mesh — so the old
	## primitive fallback sat behind it at 178x192x192, a smooth golden dome that
	## would have FAILED that check the moment the mesh row vanished, and §13c's
	## "deleting the mesh falls back to the flat block" was false as written.
	## This stands the fallback path up EXPLICITLY (`_boiler_primitive`, the
	## exact geometry `_build_boiler` erects when the mesh is not on disk) and
	## measures it against the same boilerH, so both tiers answer to one number.
	var fallback := Node3D.new()
	root.add_child(fallback)
	view._boiler_primitive(fallback)
	var fb_box := AABB()
	var fb_first := true
	for mi_any in fallback.find_children("*", "MeshInstance3D", true, false):
		var fmi := mi_any as MeshInstance3D
		if fmi.mesh == null:
			continue
		var fhere := fmi.global_transform * fmi.get_aabb()
		fb_box = fhere if fb_first else fb_box.merge(fhere)
		fb_first = false
	var fb_h: float = fb_box.size.y / SkyGearView3D.WORLD_SCALE
	var fb_w: float = maxf(fb_box.size.x, fb_box.size.z) / SkyGearView3D.WORLD_SCALE
	_check("boiler", "the primitive fallback measures at boilerH on the fallback path itself",
		not fb_first and absf(fb_h - browser_boiler_h) < 3.0,
		"%.1f ground units against boilerH %.0f" % [fb_h, browser_boiler_h])
	## The flat slatted furnace block §13c describes: footprint narrower than the
	## old 192-unit ball, taller than it is wide, with an emissive slatted grate
	## aimed at the camera — never a smooth polished dome again.
	var fb_slats := false
	for mi_any in fallback.find_children("*", "MeshInstance3D", true, false):
		var fmi := mi_any as MeshInstance3D
		if fmi.mesh is QuadMesh and fmi.mesh.material is StandardMaterial3D \
				and (fmi.mesh.material as StandardMaterial3D).emission_enabled:
			fb_slats = true
	_check("boiler", "and it is the flat slatted furnace block, not the old golden ball",
		fb_w < 130.0 and fb_h > fb_w and fb_slats,
		"%.0f wide x %.0f tall, grate %s" % [fb_w, fb_h, str(fb_slats)])
	fallback.queue_free()

	## SG-34 — THE DECK IS LIT WARM AND EVEN, NOT A HOT POOL. The premise was that
	## the Godot deck read dark, cool and vignetted; MEASURED against the browser
	## (probe over `.shots/parity/`), it read the OPPOSITE — brighter, warmer, and
	## flatter — with the real fault a searing hot pool (boiler emission + brazier
	## and lantern accents) that, by simultaneous contrast, crushed the warm
	## surround so it *looked* cold. The fix deepened the exposure and calmed the
	## accent pools; the cool moon stays the KEY (the storm-dusk light the art is
	## painted for) so the deck keeps its depth without the surfaces going orange.
	## This pins the shipped environment so a future edit cannot silently undo it:
	## re-brighten to the washed HEAD (exposure back near 1.0), re-cool the fill
	## (a blue-dominant ambient), flood the deck with the cool key (moon energy
	## back to a floodlight), drop the warm lantern fill, or re-sear the pool (the
	## boiler furnace emission back to its old 2.6). Constants, not a frame readback
	## (SG-29 blocks that). Frame the values as informed by the browser, not chained
	## to it — the owner's 2026-08-01 directive: warm, even, legible, with the mood
	## a flat Canvas 2D never had.
	var env := view._environment
	var amb: Color = env.ambient_light_color
	var moon_c: Color = view._moon.light_color
	var lant_c: Color = view._lantern.light_color
	## The boiler furnace emission — the brightest single source of the pool.
	var furnace_emit := -1.0
	if boiler_node != null:
		for mi_any in boiler_node.find_children("*", "MeshInstance3D", true, false):
			var m := (mi_any as MeshInstance3D).get_active_material(0) as StandardMaterial3D
			if m != null and m.emission_enabled:
				furnace_emit = maxf(furnace_emit, m.emission_energy_multiplier)
	var warm_even: bool = (
		env.tonemap_mode == Environment.TONE_MAPPER_FILMIC
		and env.tonemap_exposure >= 0.70 and env.tonemap_exposure <= 0.92
		and amb.b - amb.r <= 0.05                        # a near-neutral fill: a FAINT cool fill is
		                                                # wanted for depth, a strong cool cast is not
		and env.ambient_light_energy >= 0.45 and env.ambient_light_energy <= 0.80
		and view._moon.light_energy >= 1.0 and view._moon.light_energy <= 1.6  # a key, not a flood
		and moon_c.b > moon_c.r                          # and it is the cool storm-dusk key
		and view._lantern.light_energy >= 0.25 and lant_c.r > lant_c.b  # warm fill floor present
		and furnace_emit > 0.0 and furnace_emit <= 2.3)  # pool calmed, not the old 2.6 sear
	_check("view", "the deck is lit warm and even, not a hot pool", warm_even,
		"expo %.2f · amb #%02x%02x%02x e%.2f · moon e%.2f · lantern e%.2f · furnace %.2f"
		% [env.tonemap_exposure, int(amb.r * 255), int(amb.g * 255), int(amb.b * 255),
			env.ambient_light_energy, view._moon.light_energy, view._lantern.light_energy,
			furnace_emit])

	## SG-41 — NO STEEL-NAVY CARGO ON A WARM DECK. The board blamed the
	## `crate_stack` MODEL's baked texture for the one genuinely cool object on
	## the SG-34 deck; MEASURED (posed at the real camera, the model's screen
	## rect sampled directly), the premise was misattributed: the model's albedo
	## is warm (mean R/B ~2.0, navy band 0.04%) and it POSES warm (R/B 1.56 at
	## the fight framing). The actual navy was the painted steel-blue chest in
	## `cargo_wall_module.png` — the browser draws that module side-on where the
	## chest is a sliver, but `_build_cargo` projects it across every cargo run's
	## TOP face, which is most of what a 41-degree camera sees, so the baked navy
	## band (11.5% of its opaque pixels) became the up-face of all eight runs and
	## survived SG-34's key-light cut BECAUSE it was paint, not lighting. The
	## band is hue-shifted to the house timber (SG-41, in-place, zero credits);
	## these read the actual pixels so neither asset can quietly go navy again —
	## a regenerated model, a re-exported module, either fails the build here.
	var crate_glb := load("res://assets/models/crate_stack/crate_stack.glb") as PackedScene
	var crate_albedo := {"warmth": 0.0, "navy": 1.0}
	if crate_glb != null:
		var crate_node := crate_glb.instantiate()
		for mi_any in crate_node.find_children("*", "MeshInstance3D", true, false):
			var cmat := (mi_any as MeshInstance3D).mesh.surface_get_material(0) as BaseMaterial3D
			if cmat != null and cmat.albedo_texture != null:
				crate_albedo = _albedo_stats(cmat.albedo_texture.get_image())
				break
		crate_node.free()
	_check("cargo", "the crate_stack albedo is warm, not navy",
		float(crate_albedo.warmth) >= 1.0 and float(crate_albedo.navy) <= 0.02,
		"mean R/B %.2f, navy band %.1f%%"
		% [float(crate_albedo.warmth), 100.0 * float(crate_albedo.navy)])
	var module_img := Image.load_from_file(ProjectSettings.globalize_path(
		"res://assets/art/props/cargo_wall_module.png"))
	var module_stats: Dictionary = _albedo_stats(module_img)
	_check("cargo", "and the painted cargo module carries no steel-navy band",
		float(module_stats.warmth) >= 1.0 and float(module_stats.navy) <= 0.02,
		"mean R/B %.2f, navy band %.1f%% (was 11.5%% before SG-41)"
		% [float(module_stats.warmth), 100.0 * float(module_stats.navy)])

	## SG-15 — THE COLOSSUS WRECK fitting. docs/SHIP-AND-MAPS-DESIGN §5/§8's first
	## fitting: the art was on disk and sized and NOTHING had ever placed it. It is
	## placed as set dressing OFF THE BOW (`WRECK_POSITION`), NOT the doc's "hard
	## cover in lane 1" — a permanent fitting may not touch the one collision source
	## of truth (the lanes, `cargo_rects()`, the prop-per-wave count). These guard
	## that it stays a fitting: present where the fitting says, clear of the whole
	## envelope, and gated behind the same first-victory latch the Workshop opens
	## on — so it can never quietly become cover or stand on a bare ship (failure
	## modes 1 and 2). The at-camera verdict is `tools/wreck_measure.gd`, which a
	## headless build cannot photograph (SG-29).
	var wreck_pos: Vector2 = SkyGearView3D.WRECK_POSITION
	_check("fitting", "the Colossus wreck is placed off the bow",
		view._wreck != null and view._wreck.texture != null
			and absf(view._wreck.position.z / SkyGearView3D.WORLD_SCALE - wreck_pos.y) < 1.0,
		"at (%.0f, %.0f)" % [wreck_pos.x, wreck_pos.y])
	## Outside the deck, every cargo rect (incl. the movable crate), every lane
	## band, and beyond the spawn line — and not in the `props` group, so it adds
	## nothing to the per-wave count and nothing on the deck can path to it.
	var wreck_in_cargo := false
	for r in game.cargo_rects():
		if (r as Rect2).has_point(wreck_pos):
			wreck_in_cargo = true
	var wreck_in_lane := false
	for c in SkyGearGame.LANE_CENTERS:
		if absf(wreck_pos.x - float(c)) <= 190.0 and SkyGearGame.DECK_RECT.has_point(wreck_pos):
			wreck_in_lane = true
	var wreck_is_prop := false
	for p in game.get_tree().get_nodes_in_group("props"):
		if is_instance_valid(p) and p.global_position.distance_to(wreck_pos) < 1.0:
			wreck_is_prop = true
	_check("fitting", "and it never touches the gameplay envelope",
		not SkyGearGame.DECK_RECT.has_point(wreck_pos)
			and not wreck_in_cargo and not wreck_in_lane and not wreck_is_prop
			and wreck_pos.y < -1115.0,
		"deck=%s cargo=%s lane=%s prop=%s" % [
			SkyGearGame.DECK_RECT.has_point(wreck_pos), wreck_in_cargo, wreck_in_lane, wreck_is_prop])
	## The gate, second edition (SG-56): the wreck is the berth system's first
	## resident. Hidden on a bare ship, RIDING while berthed, and cleared from
	## the sky when the berth is — refreshed between runs through
	## `refresh_berthed()`, which is how the title deck follows the save.
	game.workshop = SkyGearWorkshop.fresh(true)
	game.refresh_berthed()
	view._process(0.05)
	var wreck_locked_hidden: bool = view._wreck != null and not view._wreck.visible
	var grate_locked_hidden: bool = view._grating != null and not view._grating.visible
	game.workshop.unlocked = true
	(game.workshop.fittings as Dictionary)["wreck"] = true
	(game.workshop.fittings as Dictionary)["scupper_grating"] = true
	game.workshop.berths = ["wreck", "scupper_grating"]
	game.refresh_berthed()
	view._process(0.05)
	var wreck_berthed_shown: bool = view._wreck != null and view._wreck.visible
	var grate_berthed_shown: bool = view._grating != null and view._grating.visible
	game.workshop.berths = []
	game.refresh_berthed()
	view._process(0.05)
	var wreck_cleared_hidden: bool = view._wreck != null and not view._wreck.visible
	_check("fitting", "hidden on a bare ship, riding while berthed, cleared with the berth",
		wreck_locked_hidden and wreck_berthed_shown and wreck_cleared_hidden,
		"bare->hidden %s · berthed->shown %s · cleared->hidden %s"
			% [wreck_locked_hidden, wreck_berthed_shown, wreck_cleared_hidden])
	## And the scupper grating is VISIBLE geometry while berthed — a closure
	## the captain's clamp enforces must be a thing the eye can see (SG-56).
	_check("fitting", "the scupper grating stands in its crossing while berthed, and only then",
		grate_locked_hidden and grate_berthed_shown,
		"bare->hidden %s · berthed->shown %s" % [grate_locked_hidden, grate_berthed_shown])

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

	## SG-31. The heaved crate (SG-10) is a NINTH, movable cargo rect. `_occluded`
	## read the eight-rect const and never saw it, so a boarder tucked on the bow
	## face of a deployed crate — where the funnel piles them — got no silhouette.
	## It now reads `game.cargo_rects()`, the one source of truth (the 8 walls +
	## the live crate), so the x-ray shadow moves with the crate the player heaves.
	## The crate is parked in the port lane, OUTBOARD of the fixed wall columns
	## (x -340..-220 and 220..340), so it is the sole occluder of the test point.
	game.barricade.global_position = Vector2(-560.0, -480.0)
	var crate: Rect2 = game.barricade_rect()
	_check("view", "the heaved crate is a cargo rect the x-ray can see",
		crate.size.x > 0.0 and game.cargo_rects().has(crate))
	var cray: Vector2 = (crate.get_center() - eye).normalized()
	var crate_far: float = (eye.y - crate.position.y) / -cray.y
	var behind_crate: Vector2 = eye + cray * (crate_far + 26.0)
	_check("view", "a boarder tucked behind the heaved crate is x-rayed",
		view._occluded(behind_crate, stand),
		"at %.0f, %.0f" % [behind_crate.x, behind_crate.y])
	## And it is the CRATE doing it, not a fixed wall behind it: take the crate off
	## the deck and the same spot stands in clear air. This is the exact SG-31 bug
	## in reverse — with the const, the crate was never an occluder at all.
	var live_crate: SkyGearProp = game.barricade
	game.barricade = null
	_check("view", "and with the crate gone that same spot is clear",
		not view._occluded(behind_crate, stand))
	game.barricade = live_crate
	## Moving the crate moves the occlusion with it: heave it far to starboard and
	## the old shadow is empty while a new one falls behind the new footprint.
	game.barricade.global_position = Vector2(600.0, -480.0)
	_check("view", "moving the crate moves its x-ray shadow with it",
		not view._occluded(behind_crate, stand))
	var moved: Rect2 = game.barricade_rect()
	var mray: Vector2 = (moved.get_center() - eye).normalized()
	var moved_far: float = (eye.y - moved.position.y) / -mray.y
	_check("view", "and a boarder behind the crate's new footprint is x-rayed",
		view._occluded(eye + mray * (moved_far + 26.0), stand))
	game.barricade.global_position = Vector2(
		SkyGearGame.BARRICADE_STAGES[0], SkyGearGame.BARRICADE_Y)

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

	## ENEMY ATTACK TELEGRAPHS — design pillar 6, every attack readable before it is
	## dangerous (board SG-3). The port had shrunk the browser's filled swing WEDGE
	## to a plank-wide streak; these guard the rebuilt tell against the two ways it
	## dies silently: the drawn shape stops matching where the swing connects, and
	## the windup pool spends past its reserve.
	##
	## ONE NUMBER, not two. The renderer draws the wedge at `config.reach` and the
	## sim connects at `config.reach + target_radius`; move one without the other and
	## the tell lies (STATUS failure mode two). So every melee enemy carries a `reach`
	## and a `swing`, and the reach must cover the range that TRIPPED the windup —
	## nothing may connect from outside the shape that was drawn.
	var tele_bad := ""
	for kind in ["SCRAPPER", "ARMORED", "SWARM"]:
		var cfg: Dictionary = SkyGearData.ENEMIES[kind]
		if not ("reach" in cfg and "swing" in cfg):
			tele_bad += " %s(no reach/swing)" % kind
		elif float(cfg.reach) < float(cfg.attack_range):
			tele_bad += " %s(reach %.0f < trip %.0f)" % [kind, cfg.reach, cfg.attack_range]
		elif float(cfg.swing) <= 0.0:
			tele_bad += " %s(swing 0)" % kind
	_check("telegraph", "every melee windup has a reach and a swing arc to draw",
		tele_bad == "", "bad:" + tele_bad)
	## Ranged keeps its own identity — a firing line down the lane, never a swing.
	_check("telegraph", "a ranged shooter is not handed a melee swing",
		not ("reach" in SkyGearData.ENEMIES.GUNNER),
		"GUNNER carries a reach it will never swing")

	## The lead time IS the windup: the tell is on the deck the instant a boarder
	## enters `windup`, and the hit lands `windup` seconds later — so the browser's
	## tuned windups are the warning times and must not shrink below them.
	var lead_bad := ""
	for pair in [["SCRAPPER", 0.40], ["ARMORED", 0.55], ["SWARM", 0.40], ["GUNNER", 0.45]]:
		if float(SkyGearData.ENEMIES[str(pair[0])].windup) < float(pair[1]) - 0.001:
			lead_bad += " %s" % str(pair[0])
	_check("telegraph", "the windup gives at least the browser's warning time",
		lead_bad == "", "shorter than the browser:" + lead_bad)

	## And it reaches the renderer: pose a boarder mid-windup, mirror it, and confirm
	## a telegraph decal is appended and sized in ground units to the swing's reach.
	var tg_enemy: SkyGearEnemy = null
	for e in game.get_tree().get_nodes_in_group("enemies"):
		if e.kind == "SCRAPPER" and not e.dead:
			tg_enemy = e
	tg_enemy.state = "windup"
	tg_enemy.state_time = float(tg_enemy.config.windup) * 0.5
	tg_enemy.attack_direction = Vector2.DOWN
	view._process(0.05)
	var tg_key := "tg%d" % tg_enemy.get_instance_id()
	_check("telegraph", "a windup appends a telegraph decal to the deck",
		view._decals.has(tg_key)
			and SkyGearView3D._decal_class(tg_key) == SkyGearView3D.DecalClass.TELEGRAPH,
		"no telegraph decal for a winding boarder")
	## Ground size read back through WORLD_SCALE: the wedge box is reach*2 across, so
	## a plank-wide streak (the old bug) would read far under the tuned reach.
	var drawn_reach: float = view._decals[tg_key].size.x / (2.0 * SkyGearView3D.WORLD_SCALE)
	_check("telegraph", "the wedge is drawn at the reach the swing connects at",
		absf(drawn_reach - float(tg_enemy.config.reach)) < 1.0,
		"drew %.0f against a reach of %.0f" % [drawn_reach, float(tg_enemy.config.reach)])

	## The windup pool is capped like every other on this deck: sixty boarders
	## winding at once cannot spend past the telegraph reserve (STATUS: every perf
	## problem this project has had was an uncapped collection, never a slow loop).
	for i in 120:
		view._decal("tg_flood%d" % i, Vector2(i * 30, 0), 0.0, 40.0, 40.0,
			view._fan_texture(1.658, true), Color.WHITE)
	_check("telegraph", "the windup pool stays inside its reserve under flood",
		view._decal_live[SkyGearView3D.DecalClass.TELEGRAPH]
			<= int(SkyGearView3D.DECAL_BUDGET[SkyGearView3D.DecalClass.TELEGRAPH]),
		"%d live against %d" % [view._decal_live[SkyGearView3D.DecalClass.TELEGRAPH],
			int(SkyGearView3D.DECAL_BUDGET[SkyGearView3D.DecalClass.TELEGRAPH])])

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
	## Motion, not colour: Frost falls (rise < 0), snaps outward in a narrow cone
	## (small spread) and travels FAST; Ember rises, spreads wide and drifts. The
	## timing half of the signature is the LIGHT decay, tested just below — the old
	## `.life` field that used to sit in this clause was deleted (SG-16), because
	## nothing read it and honouring it would have split the behaviour-keyed
	## emitters. These fields all render; `life` never did.
	_check("impact", "elements differ in motion, not only in colour",
		float(frost.rise) < 0.0 and float(ember.rise) > 0.0
			and float(frost.spread) < float(ember.spread)
			and float(frost.speed) > float(ember.speed),
		"frost falls and snaps, ember rises and drifts")
	view.impact_at(Vector2.ZERO, "FROST", 90.0)
	var quick: float = float(view._flashes[(view._flash_next - 1) % view._flashes.size()]
		.get_meta("decay", 0.0))
	view.impact_at(Vector2.ZERO, "EMBER", 90.0)
	var slow: float = float(view._flashes[(view._flash_next - 1) % view._flashes.size()]
		.get_meta("decay", 0.0))
	_check("impact", "and their light dies at different rates",
		quick > slow, "frost %.0f/s, ember %.0f/s" % [quick, slow])
	## EVERY ELEMENT_FX FIELD HAS A READER. `life` sat in this table for four
	## elements and nothing consumed it — the emitter's `lifetime = 1.0` governed
	## all of them, so it read as a per-element timing cue and rendered nothing
	## (SG-16, failure mode one). The twin of the talent-field and article guards:
	## every key on every ELEMENT_FX entry must be NAMED in the renderer, so the
	## table cannot quietly grow another dead field. Grep, not behaviour — the
	## failure that actually happens is a field nobody wired at all.
	var fx_src := FileAccess.get_file_as_string("res://scripts/view3d.gd")
	var fx_inert := ""
	for element in SkyGearView3D.ELEMENT_FX.keys():
		for field in (SkyGearView3D.ELEMENT_FX[element] as Dictionary).keys():
			var name := str(field)
			if fx_src.contains('.%s' % name) or fx_src.contains('"%s"' % name):
				continue
			if not fx_inert.contains(" " + name):
				fx_inert += " " + name
	_check("impact", "every ELEMENT_FX field is read by the renderer",
		fx_inert == "", "nothing reads:" + fx_inert)
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

	## SG-40 — THE PROJECTILE CORE IS EMISSIVE GEOMETRY, NOT A PAINTED SPRITE.
	## The owner's first post-parity ask: the bolt heads were `_spark`, a flat
	## billboard turned to face the camera, and that read cheap. They are a real
	## oriented mesh now — a low sphere stretched into a teardrop down its own
	## velocity, lit by its own emission so the glow chain catches it. These pin
	## the things a screenshot cannot: the mesh is the DEFAULT with the sprite kept
	## as the fallback tier, every element's bolt carries identity in its MOTION,
	## the pool is capped, and the per-bolt light is a smaller pool that lights only
	## the nearest few (so a lane of bolts is not the SG-34 hot pool reborn). The
	## look is judged from `tools/vfx_shot.gd` and the effects scene.
	var core_src := FileAccess.get_file_as_string("res://scripts/view3d.gd")
	_check("core", "the bolt head is a mesh by default, the painted sprite kept as fallback",
		SkyGearView3D.USE_MESH_CORES and view._core_mesh is SphereMesh
			and core_src.contains("_spark(key, ground, height, size, colour)"),
		"USE_MESH_CORES %s, fallback %s" % [SkyGearView3D.USE_MESH_CORES,
			core_src.contains("_spark(key, ground, height, size, colour)")])
	## Motion, not hue — the audit's finding 4, the same rule the impacts and the
	## trails already carry. Across the four elements at least two non-hue axes must
	## take distinct values, so a colour-blind player reads a Frost slug from an
	## Ember lick by SHAPE and BEHAVIOUR: here stretch (length), pulse (flicker) and
	## wake (rise vs sink) each spread across the four.
	var eb := SkyGearView3D.ELEMENT_BOLT
	var stretches := {}
	var pulses := {}
	var wakes := {}
	for el in ["EMBER", "FROST", "ARC", "STEAM"]:
		stretches[float((eb[el] as Dictionary).stretch)] = true
		pulses[float((eb[el] as Dictionary).pulse)] = true
		wakes[float((eb[el] as Dictionary).wake)] = true
	_check("core", "every element's bolt differs on two motion axes, not only its colour",
		eb.size() >= SkyGearData.ELEMENTS.size()
			and stretches.size() >= 3 and pulses.size() >= 3 and wakes.size() >= 3
			and float(eb.FROST.stretch) > float(eb.STEAM.stretch)
			and float(eb.FROST.wake) < 0.0 and float(eb.STEAM.wake) > 0.0,
		"stretch %d / pulse %d / wake %d distinct of four" % [stretches.size(),
			pulses.size(), wakes.size()])
	## Behavioural: a bolt actually in flight draws a core by the default path — the
	## reader-with-no-data failure inverted, caught by firing one and looking.
	game.projectiles.clear()
	game.spawn_enemy_bolt(Vector2.ZERO, Vector2(0.0, 300.0), 10.0, 300.0)
	view._process(0.05)
	var bolt_cored := false
	for k in view._cores.keys():
		if str(k).begins_with("b"):
			bolt_cored = true
	_check("core", "a bolt in flight draws an emissive core, not a spark billboard",
		bolt_cored, "%d cores live" % view._cores.size())
	## THE CAP. Bolts flood a lane, and every perf problem here was an unbounded
	## collection — so past the reserve a bolt keeps its ribbon and its shadow but
	## goes without a body, never half-built and never unbounded.
	for i in 200:
		view._core("cf%d" % i, Vector2(i * 20, 0), 60.0, Vector2.DOWN, "EMBER",
			Color.WHITE)
	_check("core", "the core pool stays inside its cap under flood",
		view._cores.size() <= SkyGearView3D.CORE_CAP,
		"%d live against %d" % [view._cores.size(), SkyGearView3D.CORE_CAP])
	## THE LIGHT BUDGET. The light pool is smaller than the core pool on purpose,
	## and a flood of requests lights only the nearest few — the cap SG-34 fought a
	## hot pool over, held by construction rather than by hope.
	_check("core", "the bolt light pool is smaller than the bolt pool",
		view._core_lights.size() == SkyGearView3D.CORE_LIGHT_POOL
			and SkyGearView3D.CORE_LIGHT_POOL < SkyGearView3D.CORE_CAP,
		"%d lights against a %d core cap" % [view._core_lights.size(),
			SkyGearView3D.CORE_CAP])
	view._core_light_req.clear()
	for i in 40:
		view._core_light_req.append({
			"pos": Vector3(float(i) * 0.5, 0.6, 0.0), "col": Color.WHITE})
	view._flush_core_lights()
	var lit_bolts := 0
	for lt in view._core_lights:
		if (lt as OmniLight3D).light_energy > 0.0:
			lit_bolts += 1
	_check("core", "a flood of bolts lights only the nearest few, never all of them",
		lit_bolts <= SkyGearView3D.CORE_LIGHT_POOL and lit_bolts > 0,
		"%d of a %d flood lit" % [lit_bolts, 40])
	## And those lights respect SG-34: low energy, small radius, no shadow, no fog
	## contribution — an accent under the bolt, never a floodlight or a smear.
	var lights_clean := SkyGearView3D.CORE_LIGHT_ENERGY <= 3.0
	for lt in view._core_lights:
		var ol := lt as OmniLight3D
		if not is_zero_approx(ol.light_volumetric_fog_energy) or ol.shadow_enabled \
				or ol.omni_range > 400.0 * SkyGearView3D.WORLD_SCALE:
			lights_clean = false
	_check("core", "and the bolt lights add nothing to the fog and cast no shadow",
		lights_clean, "energy %.1f, radius %.0f" % [SkyGearView3D.CORE_LIGHT_ENERGY,
			SkyGearView3D.CORE_LIGHT_RANGE])

	## SG-18 — THE WEAPON TRAIL IS THE BLADE'S OWN PATH, NOT AN EFFECT CLOCK.
	## `_sweep_ribbon` drew the Cleave where the blade APPROXIMATELY is: a circle
	## segment swept by the effect's own timer at the skill table's radius, while
	## the actual cutlass — bone-mounted, five swing variants deep — went wherever
	## the clip took it. The trail now samples the blade tip off the hand mount
	## every swinging frame, so it matches whatever the animation actually does.
	## These pin the three ways that dies silently: the source stops being a bone,
	## the samples stop being taken, or the buffer outlives the swing.
	var cap_rig: SkyGearRig3D = view._captain
	var cap_bone := ""
	if cap_rig != null and cap_rig.held is BoneAttachment3D:
		cap_bone = str((cap_rig.held as BoneAttachment3D).bone_name)
	_check("trail", "the trail's source is a mount on the hand bone, holding the blade tip",
		cap_rig != null and cap_bone.ends_with("RightHand") and cap_rig.blade_points().size() == 2,
		"mount on '%s'" % cap_bone)
	## Bone, not timer: two different times of the SAME swing clip put the blade
	## in two different places. A timer-driven arc cannot fail this, and a trail
	## reading the bone cannot pass it by accident.
	var tip_early := Vector3.ZERO
	var tip_late := Vector3.ZERO
	if cap_rig != null and cap_rig.anim != null and cap_rig.has_clip("swing"):
		var swing_len: float = cap_rig.anim.get_animation("swing").length
		cap_rig.anim.play("swing")
		cap_rig.anim.seek(swing_len * 0.12, true)
		tip_early = cap_rig.blade_points()[1]
		cap_rig.anim.seek(swing_len * 0.55, true)
		tip_late = cap_rig.blade_points()[1]
	_check("trail", "the blade tip moves with the swing clip — a bone is being sampled, not a timer",
		tip_early.distance_to(tip_late) > 0.10,
		"tip travelled %.2f m between two clip times" % tip_early.distance_to(tip_late))
	## The samples are taken, and they are the blade: one mirrored frame of a
	## live swing puts the rig's own solved tip into the buffer.
	view._trail.clear()
	game.player.attack_time = 0.5
	view._process(0.05)
	var trail_sampled: bool = view._trail.size() > 0
	var sample_err := 999.0
	if trail_sampled and cap_rig != null and cap_rig.blade_points().size() == 2:
		sample_err = (Vector3(view._trail.back().tip) * SkyGearView3D.WORLD_SCALE) \
			.distance_to(cap_rig.blade_points()[1])
	_check("trail", "a swing samples the blade into the trail, and the sample IS the tip",
		trail_sampled and sample_err < 0.25,
		"%d samples, last one %.3f m off the live tip" % [view._trail.size(), sample_err])
	## Capped through a held swing — the ring is a pool like every other — and
	## while the blade drives, the effect-clock sweep stands down so one swing is
	## never two disagreeing drawings.
	if cap_rig != null and cap_rig.anim != null and cap_rig.has_clip("swing"):
		var swing_len2: float = cap_rig.anim.get_animation("swing").length
		for i in 40:
			cap_rig.anim.play("swing")
			cap_rig.anim.seek(fmod(float(i) * 0.13, swing_len2), true)
			view._process(0.005)
	_check("trail", "the sample ring stays inside its cap through a held swing",
		view._trail.size() <= SkyGearView3D.TRAIL_SAMPLES and view._trail.size() >= 10,
		"%d samples against a cap of %d" % [view._trail.size(), SkyGearView3D.TRAIL_SAMPLES])
	_check("trail", "and while the blade drives, the effect-clock sweep stands down",
		view._blade_trail_live())
	## It dies with the swing. No timer of its own to keep running: the moment
	## the simulation says the attack is over, the samples age out inside
	## TRAIL_LIFE and the buffer is empty.
	game.player.attack_time = 0.0
	for _i in 8:
		view._process(0.05)
	_check("trail", "and the trail dies with the swing instead of running its own clock",
		view._trail.is_empty(), "%d stale samples" % view._trail.size())

	## SG-23 — THE CAPTAIN'S CAPE IS A BONE CHAIN: DRIVEN, CLAMPED, AND STILL
	## WHEN THE SCREEN MUST BE. Four bones on a mount at her chest carry a
	## skinned banner (the standing rule: capes are their OWN layer, never
	## baked into the character mesh — her model was generated bare-backed for
	## exactly this). The sim's velocity swings the chain, the dash cracks it,
	## the swing is clamped clear of her torso, and with the sway off it snaps
	## to its rest constants bitwise — the framing-check rule: a still screen
	## has to actually be still.
	var cape: SkyGearCloak = cap_rig.cloak if cap_rig != null else null
	var cape_bone := ""
	if cape != null and cape.get_parent() is BoneAttachment3D:
		cape_bone = str((cape.get_parent() as BoneAttachment3D).bone_name)
	_check("cloak", "the captain wears a cape: a four-bone chain mounted at her shoulders",
		cape != null and cape.bone_count() == SkyGearCloak.BONES
			and cape_bone.ends_with("Spine2"),
		"%d bones on '%s'" % [cape.bone_count() if cape != null else 0, cape_bone])
	## Driven, and it comes home: a full-run velocity injected straight into
	## the chain trails it visibly; taking the velocity away settles it back
	## to the rest constants EXACTLY (the snap writes those very bits).
	var run_swing := 0.0
	var rest_exact := false
	if cape != null:
		cape.rest_now()
		for _i in 40:
			cape.drive(0.05, Vector2(0.0, 210.0), 0.0, false, false, 0.0)
		run_swing = cape.pitch_total()
		for _i in 200:
			cape.drive(0.05, Vector2.ZERO, 0.0, false, false, 0.0)
		rest_exact = cape.at_rest()
	_check("cloak", "injected velocity swings the chain, and rest brings it back exactly",
		run_swing > 0.6 and rest_exact,
		"%.2f rad trailing at a full run, then bitwise rest" % run_swing)
	## The dash is the signature move, so the cape CRACKS on it — an impulse
	## the spring then swallows — measurably harder than the steady run trail.
	var dash_peak := 0.0
	if cape != null:
		cape.rest_now()
		for _i in 30:
			cape.drive(0.02, Vector2(0.0, 300.0), 0.0, true, false, 0.0)
			dash_peak = maxf(dash_peak, cape.pitch_total())
	_check("cloak", "a dash cracks the cape harder than a run trails it",
		dash_peak > run_swing + 0.3,
		"dash peak %.2f rad against the run's %.2f" % [dash_peak, run_swing])
	## The constraint: blow the cape forward as hard as the sim ever could and
	## the chain stops inside its forward budget — it cannot cross her torso
	## at the 41 degree camera, whatever gets injected.
	var blown := 999.0
	var forward_budget := 0.0
	for k in SkyGearCloak.BONES:
		forward_budget += float(SkyGearCloak.PITCH_MIN[k])
	if cape != null:
		for _i in 120:
			cape.drive(0.05, Vector2(0.0, -400.0), 0.0, false, false, 0.0)
		blown = cape.pitch_total()
		cape.rest_now()
	_check("cloak", "the forward swing is clamped so the cape never crosses her torso",
		blown >= -0.05 and blown < run_swing and forward_budget >= -0.30,
		"blown to %.2f rad against a %.2f budget" % [blown, forward_budget])
	## The sway flag is the RENDERER'S own: on, the cape breathes at the
	## ship's period; off, two still frames any distance apart are the same
	## pose — the deterministic-rest mode the framing tools rely on.
	var breathed := 0.0
	var still_frames := true
	if cape != null:
		cape.rest_now()
		var clock := 0.0
		for _i in 120:
			clock += 0.05
			cape.drive(0.05, Vector2.ZERO, 0.0, false, true, clock)
			breathed = maxf(breathed, absf(cape.pitch_total()))
		for _i in 200:
			cape.drive(0.05, Vector2.ZERO, 0.0, false, false, clock)
		still_frames = cape.at_rest()
		for _i in 60:
			cape.drive(0.05, Vector2.ZERO, 0.0, false, false, clock)
		still_frames = still_frames and cape.at_rest()
	_check("cloak", "sway on the cape breathes; sway off it is bitwise still — the framing rule",
		breathed > 0.26 and still_frames,
		"breathed to %.3f rad off a 0.25 rest, then held rest across 60 more frames" % breathed)
	## The pool law applies to allocations too: a thousand driven frames of
	## flailing velocity, dashes and sway grow NOTHING — same nodes, same
	## fixed-size state, same bone count.
	var nodes_before := 0
	var nodes_after := 0
	var state_fixed := false
	if cape != null:
		nodes_before = cape.find_children("*", "", true, false).size()
		var t := 0.0
		for _i in 1000:
			t += 0.016
			cape.drive(0.016, Vector2(sin(t) * 300.0, cos(t * 1.7) * 300.0),
				t, fmod(t, 1.0) < 0.1, true, t)
		nodes_after = cape.find_children("*", "", true, false).size()
		state_fixed = cape.bone_count() == SkyGearCloak.BONES \
			and cape._pitch.size() == SkyGearCloak.BONES \
			and cape._side.size() == SkyGearCloak.BONES
		cape.rest_now()
	_check("cloak", "a thousand driven frames grow nothing: fixed bones, pooled state",
		nodes_before > 0 and nodes_before == nodes_after and state_fixed,
		"%d nodes before and %d after" % [nodes_before, nodes_after])
	## The class rule is one row per class, and the fallback is intact: a rig
	## built WITHOUT its row carries nothing cape-shaped anywhere in its tree
	## — she renders exactly as she did before capes existed — and the
	## Boilerwright has no row, so his leathers stay bare until one is added.
	var unworn := SkyGearRig3D.new()
	root.add_child(unworn)
	var unworn_up := unworn.setup("res://assets/models/captain/captain.tscn", 1.76, 2)
	var unworn_clean: bool = unworn_up and unworn.cloak == null \
		and unworn.find_children("CapeBones", "", true, false).is_empty() \
		and unworn.find_children("*", "SkyGearCloak", true, false).is_empty()
	_check("cloak", "without the class row nothing cape-shaped exists — the fallback is intact",
		unworn_clean and SkyGearView3D.HERO_CLOAKS.has("captain")
			and not SkyGearView3D.HERO_CLOAKS.has("boilerwright"),
		"a bare rig carries no cape nodes; rows: captain only")
	unworn.queue_free()

	## SG-28 — THE RANGED AIM LINE TRAVELS. SG-3's solid band says "this lane is
	## dangerous"; the browser additionally marches a dashed line down the shot
	## path (setLineDash([14,12]), offset -rt*90), which says "something is about
	## to come down it, THIS way". Decals cannot dash, so the dashes are ribbon
	## geometry — inside the windup only, hostile oxblood, gone at the shot.
	game.spawn_enemy("GUNNER", 2)
	var gunner: SkyGearEnemy = null
	for e in game.get_tree().get_nodes_in_group("enemies"):
		if e.kind == "GUNNER" and not e.dead:
			gunner = e
	gunner.global_position = Vector2(200.0, 100.0)
	gunner.state = "windup"
	gunner.state_time = float(gunner.config.windup) * 0.5
	gunner.attack_direction = Vector2.DOWN
	view._process(0.05)
	_check("aimline", "a ranged windup runs a dashed strip down the shot path, as geometry",
		view._aim_dashes_drawn > 0, "%d dashes this frame" % view._aim_dashes_drawn)
	## The march is the browser's own 90 units a second — and post-parity it
	## QUICKENS as the wind completes, so the line itself says how close the
	## shot is. Pure function, pinned at both ends.
	var march: float = SkyGearView3D.aim_dash_travel(1.0, 0.0) \
		- SkyGearView3D.aim_dash_travel(0.0, 0.0)
	_check("aimline", "the dashes march at the browser's 90 units a second and quicken as the shot nears",
		absf(march - 90.0) < 0.001
			and SkyGearView3D.aim_dash_travel(1.0, 0.9) > SkyGearView3D.aim_dash_travel(1.0, 0.2)
			and SkyGearView3D.aim_dash_travel(0.0, 1.0) > 0.0,
		"base %.0f u/s, +%.0f units by the shot" % [march,
			SkyGearView3D.aim_dash_travel(0.0, 1.0)])
	## Gone the frame the shot fires: the dash is a warning, and a warning about
	## a shot already taken is a lie on the deck.
	gunner.state = "recover"
	view._process(0.05)
	_check("aimline", "and the dashes are gone the frame the shot fires",
		view._aim_dashes_drawn == 0, "%d dashes after the shot" % view._aim_dashes_drawn)
	## Capped like every pool: a firing line a mile long still draws AIM_DASH_MAX
	## dashes and not one more.
	view._ribbons_begin()
	view._aim_dash_ribbon(Vector2.ZERO, Vector2.DOWN, 100000.0, 0.5)
	view._ribbons_end()
	_check("aimline", "a mile of firing line still draws a capped number of dashes",
		view._aim_dashes_drawn > 0 and view._aim_dashes_drawn <= SkyGearView3D.AIM_DASH_MAX,
		"%d dashes against a cap of %d" % [view._aim_dashes_drawn, SkyGearView3D.AIM_DASH_MAX])

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

	## HEADLESS CAPTURE (SG-29). Under --headless there is no rendering device
	## at all, so a GPU readback can never succeed and `await frame_post_draw`
	## never resolves. The capture tools now ask before stalling — and this
	## harness IS the headless environment, so the detection is provable here.
	_check("capture", "headless is detected, so a capture tool refuses instead of stalling",
		SkyGearRendererCheck.can_capture()
			== (DisplayServer.get_name() != "headless"),
		"display %s, can_capture %s" % [DisplayServer.get_name(),
			SkyGearRendererCheck.can_capture()])
	_check("capture", "and the refusal tells you the fix",
		SkyGearRendererCheck.capture_refusal().contains("--headless")
			and SkyGearRendererCheck.capture_refusal().contains("SG-29"))

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
	## the Boiler against a 92-unit scrapper reach. Two of three lanes could not
	## damage the thing you lose by, and "hold three lanes" was really "hold the
	## middle one".
	##
	## Checked as REACHABILITY rather than as the merge constant, so re-tuning the
	## merge cannot quietly recreate the bug. The reach is the scrapper's tuned swing
	## `reach` — the same number the sim connects at and the telegraph is drawn at.
	var no_reach := ""
	for lane in SkyGearGame.LANE_CENTERS.size():
		## The closest a boarder in this lane can legally stand to the Boiler.
		var at_boiler := SkyGearGame.BOILER_POSITION
		var got: Vector2 = game.correct_enemy_position(at_boiler, lane, 15.0)
		var reach: float = float(SkyGearData.ENEMIES.SCRAPPER.reach)
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

	## THE SECOND VERB — SHOVE THE CRATE (board SG-10, reworked SG-37). The first
	## entry that shapes the ground rather than mending it, and the proof the table
	## was worth being a table. The owner played the SG-10 hold-to-heave and
	## rejected it: the 2.8s channel was not fun and the crate trapped the captain.
	## So this is now an INSTANT tap-shove (no channel, a short cooldown instead)
	## that the captain can never be blocked by — the checks below are rewritten to
	## that contract, and the funnel/open-side pair is carried forward from SG-10
	## intact because the boarders MUST stay funnelled.
	_check("deck", "the deck carries a movable crate to heave",
		deck.barricade != null and is_instance_valid(deck.barricade)
			and not bool(deck.barricade.dead))
	## Its footprint is derived from the PROP the player sees, and it is in the ONE
	## cargo source of truth — so the collision clamp, the boarder funnel and the
	## debug draw cannot disagree about where it is (STATUS failure mode two).
	_check("deck", "the crate joins the one cargo source of truth",
		deck.barricade_rect().size.x > 0.0
			and deck.cargo_rects().size() == SkyGearGame.CARGO_RECTS.size() + 1)

	## Stand at it and the table offers a HEAVE, not a repair — same held key, read
	## from the target you are next to.
	deck.barricade_stage = 0
	deck.barricade.global_position = Vector2(
		SkyGearGame.BARRICADE_STAGES[0], SkyGearGame.BARRICADE_Y)
	deck.player.global_position = deck.barricade.global_position
	var crate_job: Dictionary = SkyGearDeckwork.available(deck)
	_check("deck", "standing at the crate offers a heave",
		not crate_job.is_empty() and str(crate_job.spec.id) == "heave_crate")
	## The generic prompt draws it because the spec carries a verb and a refusal
	## reason, exactly like repair — no HUD change to reach the second verb.
	_check("deck", "the heave verb has a prompt and a reason it refuses",
		not crate_job.is_empty()
			and str(crate_job.spec.get("verb", "")) != ""
			and str(crate_job.spec.get("blocked", "")) != "")

	## HEAVING MOVES THE SIM RECT — the actual footprint boarders path against, not
	## only the picture.
	var before_x: float = deck.barricade.global_position.x
	SkyGearDeckwork.perform(deck, crate_job.spec, crate_job.target)
	_check("deck", "heaving actually moves the crate's footprint",
		absf(deck.barricade.global_position.x - before_x) > 40.0,
		"%.0f -> %.0f" % [before_x, deck.barricade.global_position.x])

	## AND A BOARDER'S PATH RESPONDS. Heave the crate to its funnel stage and a
	## boarder walking that column is displaced clear of the footprint — the routing
	## measurably narrows, rather than a wall drawn over boarders who stroll through
	## it (STATUS failure mode one). Tested straight through `correct_enemy_position`,
	## the three lines the boarders actually path by.
	deck.barricade_stage = 2
	deck.barricade.global_position = Vector2(
		SkyGearGame.BARRICADE_STAGES[2], SkyGearGame.BARRICADE_Y)
	var choke := Vector2(SkyGearGame.BARRICADE_STAGES[2], SkyGearGame.BARRICADE_Y)
	var routed: Vector2 = deck.correct_enemy_position(
		choke, SkyGearGame.BARRICADE_LANE, 15.0)
	_check("deck", "a boarder in the port lane is funnelled by the heaved crate",
		routed.distance_to(choke) > 30.0
			and not deck.barricade_rect().has_point(routed),
		"stayed at %.0f, %.0f" % [routed.x, routed.y])
	## But the OUTBOARD side stays open — one crate narrows a lane, it never walls it
	## shut for free. That is the balance, and it is geometry, not a new currency.
	var outboard := Vector2(-720.0, SkyGearGame.BARRICADE_Y)
	var through: Vector2 = deck.correct_enemy_position(
		outboard, SkyGearGame.BARRICADE_LANE, 15.0)
	_check("deck", "and the open side of the funnelled lane still passes",
		through.distance_to(outboard) < 30.0,
		"outboard route bent to %.0f, %.0f" % [through.x, through.y])
	## With the crate stowed, the very same column is clear — proof the funnel is the
	## crate and not the lane clamp doing it anyway.
	deck.barricade_stage = 0
	deck.barricade.global_position = Vector2(
		SkyGearGame.BARRICADE_STAGES[0], SkyGearGame.BARRICADE_Y)
	var stowed_route: Vector2 = deck.correct_enemy_position(
		choke, SkyGearGame.BARRICADE_LANE, 15.0)
	_check("deck", "and stowing the crate re-opens that column",
		stowed_route.distance_to(choke) < 30.0)

	## THE RE-STOW DECISION, PINNED. The deck re-stows between waves (a pinned
	## behavior) and the crate re-stows WITH it, by design: a flank you close is one
	## you pay to close again next wave, never a permanent free wall. So a deployed
	## crate returns to its home the moment the next wave is stowed.
	deck.barricade_stage = 2
	deck.barricade.global_position = Vector2(500.0, 200.0)
	deck.start_wave(4)
	_check("deck", "the crate re-stows to its home for the next wave",
		deck.barricade != null and int(deck.barricade_stage) == 0
			and absf(deck.barricade.global_position.x
				- SkyGearGame.BARRICADE_STAGES[0]) < 1.0
			and absf(deck.barricade.global_position.y - SkyGearGame.BARRICADE_Y) < 1.0,
		"stage %d at %.0f, %.0f" % [int(deck.barricade_stage),
			deck.barricade.global_position.x, deck.barricade.global_position.y])

	## SG-37 REWORK — THE INSTANT SHOVE. The channel is gone: the crate verb is
	## flagged `instant` and carries NO `seconds`, so nothing fills before it fires
	## and one `perform` steps the footprint at once (the "moves the crate's
	## footprint" check above already proves the single-call step). The repair verb
	## still carries channel seconds — the divergence is deliberate, the crate is
	## the ONLY instant verb. If the channel ever creeps back onto the crate, this
	## fails.
	var heave_spec: Dictionary = SkyGearDeckwork.actions()[1]
	var repair_spec: Dictionary = SkyGearDeckwork.actions()[0]
	_check("deck", "the shove is instant — no channel gates it",
		str(heave_spec.id) == "heave_crate"
			and bool(heave_spec.get("instant", false))
			and not heave_spec.has("seconds")
			and float(repair_spec.get("seconds", 0.0)) > 1.0,
		"heave instant=%s seconds?=%s · repair seconds=%.1f" % [
			bool(heave_spec.get("instant", false)), heave_spec.has("seconds"),
			float(repair_spec.get("seconds", 0.0))])

	## THE COST THAT REPLACES THE CHANNEL — a short per-crate cooldown so the shove
	## cannot be machine-gunned across the deck. It is a real, positive duration, it
	## ticks down over time, and it drains back to zero (recovers). The tick runs at
	## the top of `_update_deckwork` regardless of state, so this exercises the real
	## code path, not a stand-in.
	deck.barricade_cooldown = SkyGearGame.BARRICADE_COOLDOWN
	deck._update_deckwork(0.25)
	var cd_ticks: bool = deck.barricade_cooldown > 0.0 \
		and deck.barricade_cooldown < SkyGearGame.BARRICADE_COOLDOWN
	deck._update_deckwork(SkyGearGame.BARRICADE_COOLDOWN)
	_check("deck", "the shove cooldown holds",
		SkyGearGame.BARRICADE_COOLDOWN >= 0.5 and cd_ticks
			and deck.barricade_cooldown <= 0.0,
		"const %.1fs · ticked %s · drained to %.2f" % [
			SkyGearGame.BARRICADE_COOLDOWN, cd_ticks, deck.barricade_cooldown])

	## THE CAPTAIN IS NEVER BLOCKED BY THE CRATE (board SG-37, the owner's core
	## complaint). Her collision (`correct_player_position`) clamps only the eight
	## FIXED walls, never the movable crate, so a point inside the crate's footprint
	## comes back UNCHANGED — a path across it succeeds for her. The same call still
	## clamps her OUT of a fixed wall, so collision is not globally off: the crate,
	## and only the crate, is excluded. This is the deliberate divergence from the
	## enemy rects (the funnel checks above prove boarders ARE still shaped by it),
	## stated at the site per STATUS failure mode two. Under the SG-10 code (which
	## clamped `cargo_rects()`, crate included) this point was pushed clear of the
	## crate and this check would fail — that is the rework, pinned.
	deck.barricade_stage = 1
	deck.barricade.global_position = Vector2(
		SkyGearGame.BARRICADE_STAGES[1], SkyGearGame.BARRICADE_Y)
	var crate_c: Vector2 = deck.barricade.global_position
	var in_crate: Vector2 = deck.correct_player_position(crate_c, 17.0)
	var wall: Rect2 = SkyGearGame.CARGO_RECTS[0]
	var in_wall: Vector2 = deck.correct_player_position(wall.get_center(), 17.0)
	_check("deck", "the captain is never blocked by the heaved crate",
		in_crate.distance_to(crate_c) < 0.5
			and in_wall.distance_to(wall.get_center()) > 1.0,
		"crate push %.1f (want ~0) · fixed-wall push %.1f (want >0)" % [
			in_crate.distance_to(crate_c), in_wall.distance_to(wall.get_center())])
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
		## the two vows (SG-26): both trade in WHICH choices exist, not in how
		## hard anything hits — the Bid narrows the run to a plan, the Second
		## Hand widens the hand at a card's expense
		"opening_bid": "economy", "second_hand": "economy",
		"show_queue": "readout", "show_numbers": "readout",
		"show_manifest": "readout", "show_ledger": "readout",
	}
	var unclassified := ""
	for id in SkyGearWorkshop.NODES.keys():
		var field := str(SkyGearWorkshop.NODES[id].field)
		if not buckets.has(field):
			unclassified += " %s(%s)" % [id, field]
	## And the ARTICLES answer the same question. The seven originals were in
	## the table but nothing FAILED if a new one was not — which is exactly how
	## a field slips in unclassified — so the sigil side is enforced now too.
	for id in SkyGearWorkshop.ARTICLES.keys():
		var field := str(SkyGearWorkshop.ARTICLES[id].field)
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
	## And the three cards the claim is measured against, taken from the LIVE
	## catalogue rather than typed in as three numbers. The check used to inline
	## `1.30 * 1.35 * 1.30`, which happened to be the real HEAVY HIT / WIDE BLAST /
	## LONG REACH multipliers — until the day someone buffs one in `cards.gd` and
	## this side keeps asserting a card the game no longer deals, the two halves of
	## the inequality drifting apart in silence (failure mode four, a number carried
	## from memory). So both sides are measured now: the tree resolved above, and
	## the cards applied to a sandbox captain's opening skill here.
	##
	## These three — the per-skill offensive COMMONS, stacked on one slot exactly as
	## a run stacks them — are the design's "three draft cards", and deliberately the
	## MODEST choice: the claim has to hold against the cards a player sees every
	## draft, not against the rarest, which would make it trivially true.
	var card_game := _new_game()
	_begin(card_game)
	var slot0: Dictionary = card_game.skills[0]
	var base_dmg := float(slot0.mods.get("damage", 1.0))
	var base_area := float(slot0.mods.get("area", 1.0))
	var base_range := float(slot0.mods.get("range", 1.0))
	var pick0 := func(opts: Array) -> int: return int(opts[0]) if not opts.is_empty() else 0
	var applied := ""
	for card in SkyGearCards.catalogue():
		if str(card.get("id", "")) in ["dmg", "aoe", "range"]:
			var made: Dictionary = card.make.call(card_game, pick0)
			(made.apply as Callable).call(card_game)
			applied += " " + str(card.id)
	var three_cards := (float(slot0.mods.get("damage", 1.0)) / base_dmg) \
		* (float(slot0.mods.get("area", 1.0)) / base_area) \
		* (float(slot0.mods.get("range", 1.0)) / base_range)
	card_game.queue_free()
	## Every one of the three has to have been found and applied, or "measured from
	## live data" is a lie and the product silently reads x1.00.
	_check("shop", "the three-card yardstick is the real catalogue, not three typed numbers",
		applied.split(" ", false).size() == 3 and three_cards > 1.5,
		"applied [%s ] -> x%.2f" % [applied, three_cards])
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

	## THE STACK IS CUMULATIVE, PROVEN ON THE DATA. Each rung must carry every
	## modifier the rung below it introduced — the whole point of re-listing them
	## in the table — and must not soften any of them. A rung that dropped a lower
	## Heat's field would make a high difficulty easier than a low one on that
	## axis, and a reader asking `heat_data(5)` would silently get the Heat-0
	## default back. This walks every field of every rung against its predecessor
	## through the HEAT_HARDER direction table, so the re-listing cannot rot.
	var not_cumulative := ""
	for i in range(1, SkyGearWorkshop.HEAT.size()):
		var below: Dictionary = SkyGearWorkshop.HEAT[i - 1]
		var here: Dictionary = SkyGearWorkshop.HEAT[i]
		for field in below.keys():
			if field == "name" or field == "blurb":
				continue
			if not here.has(field):
				not_cumulative += " %d:dropped-%s" % [i, field]
				continue
			var dir: Variant = SkyGearWorkshop.HEAT_HARDER.get(field, 0)
			var lo: Variant = below[field]
			var hi: Variant = here[field]
			if dir is String:  ## a latch — once set, never un-set
				if bool(lo) and not bool(hi):
					not_cumulative += " %d:un-set-%s" % [i, field]
			elif lo is Array:  ## a set that may only grow
				for v in (lo as Array):
					if not (v in (hi as Array)):
						not_cumulative += " %d:shrank-%s" % [i, field]
						break
			elif int(dir) == 1:  ## bigger is harder
				if float(hi) < float(lo):
					not_cumulative += " %d:softer-%s" % [i, field]
			elif int(dir) == -1:  ## smaller is harder
				if float(hi) > float(lo):
					not_cumulative += " %d:softer-%s" % [i, field]
	_check("heat", "the stack is cumulative — no rung drops or softens a lower one",
		not_cumulative == "", "at:" + not_cumulative)

	## EVERY HEAT FIELD HAS A READER. The twin of the talent guard, and the same
	## failure it exists to catch: a modifier written into the ladder that nothing
	## consumes, so a rung reads as harder and plays identically (failure mode
	## one). A field appears in the table as `"x":` and in a reader as `.get("x"`,
	## so grepping the module for the latter proves a reader references it without
	## the table counting as its own witness.
	var heat_src := FileAccess.get_file_as_string("res://scripts/workshop.gd")
	var heat_fields := {}
	for rung in SkyGearWorkshop.HEAT:
		for field in (rung as Dictionary).keys():
			if field != "name" and field != "blurb":
				heat_fields[field] = true
	var heat_inert := ""
	for field in heat_fields.keys():
		if not heat_src.contains('.get("%s"' % field):
			heat_inert += " " + str(field)
	_check("heat", "every Heat modifier is read by something", heat_inert == "",
		"nothing reads:" + heat_inert)

	## And each of the three new rungs moves a number the sim reads — not the same
	## number, a DIFFERENT one apiece, which is the identity the ask was about. A
	## workshop that has cleared to the top so the whole ladder is reachable.
	var open_ladder := SkyGearWorkshop.fresh(true)
	open_ladder.unlocked = true
	open_ladder.best_heat = SkyGearWorkshop.HEAT.size() - 1

	## HEAT 3 · COLD DECK — a colder hand. Two cards, one reroll, against three
	## and two at Heat 0, measured on a real begin_run and a real draft.
	var warm := _new_game()
	warm.workshop = open_ladder.duplicate(true)
	warm.heat = 0
	warm.set_seed_text("COLD0")
	warm.begin_run()
	var warm_rerolls: int = warm.rerolls
	warm.open_draft()
	var warm_offers: int = warm.draft_options.size()
	warm.queue_free()

	var cold := _new_game()
	cold.workshop = open_ladder.duplicate(true)
	cold.heat = 3
	cold.set_seed_text("COLD3")
	cold.begin_run()
	var cold_rerolls: int = cold.rerolls
	cold.open_draft()
	var cold_offers: int = cold.draft_options.size()
	cold.queue_free()
	_check("heat", "Cold Deck deals two cards on one reroll, not three on two",
		warm_offers == 3 and warm_rerolls == 2
			and cold_offers == 2 and cold_rerolls == 1,
		"warm %d cards/%d rerolls · cold %d cards/%d rerolls"
			% [warm_offers, warm_rerolls, cold_offers, cold_rerolls])

	## HEAT 4 · BOARDERS ALOFT — a hulk on 4, 6, 8 and 10. The base pushes on 4
	## and 8 hold at every Heat; the extra two open only here. Read through the
	## one question `is_push_wave`, the same one the wave loop asks.
	var h_flat := _new_game()
	h_flat.workshop = open_ladder.duplicate(true)
	h_flat.heat = 0
	h_flat.begin_run()
	var aloft := _new_game()
	aloft.workshop = open_ladder.duplicate(true)
	aloft.heat = 4
	aloft.begin_run()
	_check("heat", "Boarders Aloft grapples a hulk on the odd pushes too",
		h_flat.is_push_wave(4) and h_flat.is_push_wave(8)
			and not h_flat.is_push_wave(6) and not h_flat.is_push_wave(10)
			and aloft.is_push_wave(4) and aloft.is_push_wave(6)
			and aloft.is_push_wave(8) and aloft.is_push_wave(10),
		"flat 4/6/8/10 = %s/%s/%s/%s · aloft = %s/%s/%s/%s" % [
			h_flat.is_push_wave(4), h_flat.is_push_wave(6), h_flat.is_push_wave(8),
			h_flat.is_push_wave(10), aloft.is_push_wave(4), aloft.is_push_wave(6),
			aloft.is_push_wave(8), aloft.is_push_wave(10)])
	var flat_turret: float = float(h_flat.turrets[0].hp)
	h_flat.queue_free()
	aloft.queue_free()

	## HEAT 5 · SKELETON CREW — no muster, half-dead cannons. The cannons come up
	## at half the health Heat 0 gives them, and the periodic muster is off.
	var h_alone := _new_game()
	h_alone.workshop = open_ladder.duplicate(true)
	h_alone.heat = 5
	h_alone.begin_run()
	var alone_turret: float = float(h_alone.turrets[0].hp)
	_check("heat", "Skeleton Crew halves the cannons and stops the muster",
		is_equal_approx(alone_turret, flat_turret * 0.5)
			and SkyGearWorkshop.musters(5) == false
			and SkyGearWorkshop.musters(0) == true,
		"cannon %.0f against %.0f · musters %s"
			% [alone_turret, flat_turret, SkyGearWorkshop.musters(5)])
	h_alone.queue_free()

	## And the summit pays only the record. Heat 5 clears record the rung but hand
	## back no sigil — §5's rule that the top of the ladder is not a power reward.
	var summit := SkyGearWorkshop.fresh(true)
	summit.unlocked = true
	## Every OTHER first already claimed, so the only sigil this win could pay is
	## the rung's — which is exactly the one Heat 5 withholds.
	summit.articles = {"first_win": true, "reach_eight": true, "won_close": true,
		"won_unhealed": true, "win_boilerwright": true}
	var h_top: int = SkyGearWorkshop.HEAT.size() - 1
	var before_sigils: int = int(summit.sigils)
	SkyGearWorkshop.bank(summit,
		{"won": true, "wave": 12, "seed": "TOP", "heat": h_top, "close_share": 50})
	_check("heat", "clearing the summit records it but pays no sigil",
		int(summit.best_heat) == h_top and int(summit.sigils) == before_sigils,
		"best %d · sigils %d -> %d" % [int(summit.best_heat), before_sigils,
			int(summit.sigils)])

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

	## THE OPENING BID (SG-26). The benefit is that every weapon draft is the
	## whole matrix, NAMED rather than dealt; the trade is that the bid is
	## final — no rerolls, all run, not even bought ones. Both halves are
	## EXECUTED here, not read off the table, because a vow whose drawback only
	## exists in its price string is a bonus wearing a vow's name.
	var bid := _new_game()
	bid.workshop = SkyGearWorkshop.fresh(true)
	bid.workshop.unlocked = true
	## Deep Pockets bought first (behind its tier gate), so the zero below is
	## the vow REFUSING A GRANT rather than counting an empty purse.
	bid.workshop.scrip = 200
	for id in ["bootblacking", "padded_coat", "deep_pockets"]:
		SkyGearWorkshop.buy(bid.workshop, id)
	bid.workshop.sigils = 2
	SkyGearWorkshop.take(bid.workshop, "opening_bid")
	bid.set_seed_text("BID")
	bid.begin_run()
	var all_weapons := true
	for option in bid.draft_options:
		if str(option.kind) != "skill":
			all_weapons = false
	_check("shop", "the bid opens the whole matrix, not a deal",
		bid.draft_options.size() == 32 and all_weapons,
		"%d cells, all weapons: %s" % [bid.draft_options.size(), str(all_weapons)])
	_check("shop", "and the bid is final — a bought reroll is still refused",
		int(bid.rerolls) == 0 and not bid.reroll_draft(),
		"rerolls %d with Deep Pockets bought" % int(bid.rerolls))
	bid.choose_draft(0)
	bid.open_draft()
	_check("shop", "and the matrix shrinks by the shape you now hold",
		bid.draft_options.size() == 28 and bid.skills.size() == 1,
		"%d cells after the first pick" % bid.draft_options.size())
	## SPARE PARTS would be +2 rerolls the vow refuses to spend — a card worse
	## than a skip, which rule 3 of the design forbids. It leaves the catalogue.
	var spares_can := false
	var spares_found := false
	for entry in SkyGearCards.catalogue():
		if str(entry.id) == "spares":
			spares_found = true
			spares_can = bool((entry.can as Callable).call(bid))
	_check("shop", "and SPARE PARTS leaves the catalogue rather than dealing dead",
		spares_found and not spares_can,
		"found %s · dealable under the bid %s" % [str(spares_found), str(spares_can)])

	## THE SECOND HAND (SG-26). The benefit is a fifth slot; the trade is WHERE
	## it is dealt — the draft that would have been the run's first upgrade
	## cards — and WHAT it may hold: only the shapes that fight alone, because
	## no fifth key exists and an active in a keyless slot is a dead button.
	var hand := _new_game()
	hand.workshop = SkyGearWorkshop.fresh(true)
	hand.workshop.unlocked = true
	hand.workshop.sigils = 3
	SkyGearWorkshop.take(hand.workshop, "second_hand")
	hand.set_seed_text("HAND")
	hand.begin_run()
	_check("shop", "the second hand raises the capacity and its telemetry together",
		hand.skill_capacity() == 5 and (hand.tel.per as Array).size() == 5,
		"capacity %d · buckets %d" % [hand.skill_capacity(),
			(hand.tel.per as Array).size()])
	hand.choose_draft(0)
	hand.skills.clear()
	for pair in [["CLOSEHIT", "EMBER"], ["RANGED_AOE", "FROST"],
			["CHAIN", "ARC"], ["SENTRY", "STEAM"]]:
		hand.skills.append(SkyGearData.make_skill(str(pair[0]), str(pair[1])))
	hand.open_draft()
	var fifth_alone := true
	for option in hand.draft_options:
		if str(option.get("kind", "")) != "skill" or not bool(
				SkyGearData.SHAPES[option.skill.shape].get("passive", false)):
			fifth_alone = false
	_check("shop", "the fifth is dealt where the first card would be, and fights alone",
		not hand.draft_options.is_empty() and fifth_alone,
		"%d options, weapons that work unkeyed: %s" % [hand.draft_options.size(),
			str(fifth_alone)])
	hand.choose_draft(0)
	_check("shop", "and the hand is five", hand.skills.size() == 5,
		"%d skills" % hand.skills.size())
	## The control: the same full hand WITHOUT the Article deals cards — which
	## is exactly the card the Second Hand's fifth weapon displaced.
	var bare := _new_game()
	bare.set_seed_text("HAND")
	bare.begin_run()
	bare.choose_draft(0)
	bare.skills.clear()
	for pair in [["CLOSEHIT", "EMBER"], ["RANGED_AOE", "FROST"],
			["CHAIN", "ARC"], ["SENTRY", "STEAM"]]:
		bare.skills.append(SkyGearData.make_skill(str(pair[0]), str(pair[1])))
	bare.open_draft()
	var any_weapon := false
	for option in bare.draft_options:
		if str(option.get("kind", "")) == "skill":
			any_weapon = true
	_check("shop", "and without the article that same draft deals cards",
		not bare.draft_options.is_empty() and not any_weapon,
		"%d options, none a weapon" % bare.draft_options.size())

	## THE THIRD EXCLUSION, and the seals' states. Two sigils is the Workshop
	## pose's purse: the Bid affordable, the Second Hand visible-but-unpayable —
	## then signing the Bid turns the Second Hand BARRED, which is the third
	## distinct state the sidebar draws (`owns` / `can_take` / excluded-by).
	var seals := SkyGearWorkshop.fresh(true)
	seals.unlocked = true
	seals.sigils = 2
	_check("shop", "two sigils: the bid affordable, the second hand not",
		SkyGearWorkshop.can_take(seals, "opening_bid")
			and not SkyGearWorkshop.can_take(seals, "second_hand"))
	SkyGearWorkshop.take(seals, "opening_bid")
	seals.sigils = 9
	_check("shop", "and the signed bid bars the second hand at any purse",
		SkyGearWorkshop.owns(seals, "opening_bid")
			and not SkyGearWorkshop.can_take(seals, "second_hand"))
	var seals2 := SkyGearWorkshop.fresh(true)
	seals2.unlocked = true
	seals2.sigils = 9
	SkyGearWorkshop.take(seals2, "second_hand")
	_check("shop", "and the bar holds the other way round",
		SkyGearWorkshop.owns(seals2, "second_hand")
			and not SkyGearWorkshop.can_take(seals2, "opening_bid"))

	## FOURTH CARD (SG-46), found building the Bid's matrix: the talent dealt a
	## fourth weapon and the draft UI capped BOTH the screen and the click test
	## at three, with no fourth key — a 160-scrip purchase that was invisible
	## and unchoosable. The sim half is proven here; the drawn cap is 4 now and
	## the four-card geometry has to fit the 1280 floor the audit poses.
	var fourth := _new_game()
	fourth.workshop = SkyGearWorkshop.fresh(true)
	fourth.workshop.unlocked = true
	fourth.workshop.scrip = 400
	for id in ["manifest", "tally", "ledger", "watch_bill", "fourth_card"]:
		SkyGearWorkshop.buy(fourth.workshop, id)
	fourth.set_seed_text("FOURTH")
	fourth.begin_run()
	fourth.choose_draft(0)
	fourth.open_draft()
	_check("shop", "fourth card deals four on the opening hand",
		fourth.draft_options.size() == 4,
		"%d options" % fourth.draft_options.size())
	fourth.choose_draft(3)
	_check("shop", "and the fourth is choosable and arms a slot",
		fourth.skills.size() == 2, "%d skills" % fourth.skills.size())
	var four_cards := SkyGearHUD.draft_cards(Vector2(1280, 720), 4)
	var four_fit := true
	for rect in four_cards:
		if not Rect2(Vector2.ZERO, Vector2(1280, 720)).encloses(rect):
			four_fit = false
	_check("shop", "and four cards fit the 1280 floor the audit poses",
		four_cards.size() == 4 and four_fit,
		"span %d at 1280" % int(four_cards[3].end.x - four_cards[0].position.x))

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
	## HIS enemies, not the tree's (board SG-50): this used to take the LAST
	## group entry tree-wide — frequently a leaked earlier game's boarder — and
	## passed only because the attack swept tree-wide too. The sweep is honest
	## now, so the victim has to be too.
	for e in game.enemies():
		if not e.dead:
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
	## HIS enemies, not the tree's (board SG-50) — same story as the Scald
	## victim above.
	for e in game.enemies():
		if not e.dead:
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

	## THE SHAPING VERB IS INVISIBLE TOO. Like the downed cannon, nothing on screen
	## says a crate can be heaved to funnel a lane, so the coach announces it — and
	## like every keyed line it carries the LIVE binding, never the raw {key} token.
	## This is the check that catches the substitution being dropped for the new
	## line. Its own game, so the crate is freshly stowed and the state is known.
	var shaper := _new_game()
	shaper.set_seed_text("SHAPE")
	shaper.begin_run()
	shaper.choose_draft(0)
	shaper.start_wave(3)
	shaper.spawn_queue.clear()
	shaper.coach.reset()
	shaper.deckwork = {}
	shaper.pressure = 0.0
	shaper.barricade_stage = 0
	if shaper.barricade != null and is_instance_valid(shaper.barricade):
		shaper.barricade.global_position = Vector2(
			SkyGearGame.BARRICADE_STAGES[0], SkyGearGame.BARRICADE_Y)
	## A lane walking through, the captain committed elsewhere — and standing on a
	## boarder, so the kiting line (higher priority) cannot win ahead of this one.
	shaper.player.global_position = Vector2(400.0, -300.0)
	shaper.spawn_enemy("SCRAPPER", 1)
	shaper.spawn_enemy("SCRAPPER", 0)
	var walker: SkyGearEnemy = null
	var nearby: SkyGearEnemy = null
	for e in shaper.get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or e.dead:
			continue
		if e.lane == 0:
			walker = e
		else:
			nearby = e
	if walker != null:
		walker.global_position = Vector2(-560.0, 300.0)
		walker.state = "move"
	if nearby != null:
		nearby.global_position = shaper.player.global_position
		nearby.state = "move"
	## Capture the FIRST hint to fire, not the last: `shape_lane` and the plain
	## `lane` line share the same trigger, and `shape_lane` wins the priority order,
	## so it speaks first — a loop that kept the last word would catch `lane`
	## overwriting it seconds later and read the wrong line.
	var crate_told := ""
	for _t in 400:
		var w3: String = shaper.coach.advise(shaper, 0.1)
		shaper.run_time += 0.1
		if w3 != "":
			crate_told = w3
			break
	_check("coach", "the crate's heave is announced with a lane walking through",
		crate_told != "", "said nothing with a lane being lost and the crate stowed")
	_check("coach", "and the heave line names the bound key, not the {key} token",
		crate_told.contains(bound) and not crate_told.contains("{key}"),
		"'%s' does not carry '%s'" % [crate_told, bound])
	shaper.queue_free()

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

	## --- board SG-12: the second class is not the first ----------------------
	## `_sync_captain` loaded ONE CAPTAIN_SCENE for both classes, so the
	## Boilerwright — a slow, heavy engineer — rendered as the fast captain. The
	## per-class HERO_MODELS table is the fix; these pin the seam so it cannot
	## silently collapse back to one scene for both.
	var cap_row: Dictionary = SkyGearView3D.HERO_MODELS["captain"]
	var bw_row: Dictionary = SkyGearView3D.HERO_MODELS["boilerwright"]
	_check("figure", "the Boilerwright loads a scene that is not the captain's",
		str(bw_row.scene) != str(cap_row.scene)
			and str(bw_row.scene) != SkyGearView3D.CAPTAIN_SCENE,
		"%s vs %s" % [str(bw_row.scene).get_file(), str(cap_row.scene).get_file()])
	_check("figure", "and the captain's own row still points at the ingested captain",
		str(cap_row.scene) == SkyGearView3D.CAPTAIN_SCENE)
	## They share the locked 41 degree camera and its telegraph calibration, so
	## the two classes must be drawn at the same height — bulk and stance do the
	## distinguishing, never scale.
	_check("figure", "and both classes stand the captain's height for the shared camera",
		absf(float(bw_row.height) - float(cap_row.height)) <= 4.0,
		"%.0f vs %.0f units" % [float(bw_row.height), float(cap_row.height)])
	## Every class id the simulation can hold has a model row, or a class the
	## draft can pick renders as nothing.
	var rows_ok := true
	for cid in SkyGearData.CLASSES.keys():
		if not SkyGearView3D.HERO_MODELS.has(cid):
			rows_ok = false
	_check("figure", "every class the sim can be has a player model row",
		rows_ok, "classes %s" % str(SkyGearData.CLASSES.keys()))

	## SG-45 — THE SKIN MUST AGREE WITH THE SKELETON, PER ROW. The Boilerwright
	## shipped THREE BUILDS INVISIBLE: the SG-12 retarget renamed his skeleton's
	## bones to mixamorig_* but left the mesh's Skin binds Meshy-named, so every
	## bind failed to resolve by name and the skinned mesh drew NOTHING — while
	## the rig built, all fourteen clips resolved and every check above stayed
	## green, because none of them asked whether the mesh could DRAW. This one
	## asks: every named bind in every committed hero scene's Skin must name a
	## bone its own skeleton has — the exact agreement rendering needs, checkable
	## headless with no pixel readback, and it would have gone red the moment
	## SG-12's scene was committed. Iterates the table so the third class (and
	## every HERO_MODELS row after it) cannot repeat the mismatch.
	for hid in SkyGearView3D.HERO_MODELS.keys():
		var hpath := str(SkyGearView3D.HERO_MODELS[hid].scene)
		if not ResourceLoader.exists(hpath):
			continue
		var hero: Node = (load(hpath) as PackedScene).instantiate()
		var hskel: Skeleton3D = null
		for sk in hero.find_children("*", "Skeleton3D", true, false):
			hskel = sk as Skeleton3D
			break
		var skinned := 0
		var named := 0
		var bad_binds := PackedStringArray()
		for mi_node in hero.find_children("*", "MeshInstance3D", true, false):
			var hskin: Skin = (mi_node as MeshInstance3D).skin
			if hskin == null:
				continue
			skinned += 1
			for bi in hskin.get_bind_count():
				var bname := String(hskin.get_bind_name(bi))
				if bname == "":
					continue
				named += 1
				if hskel == null or hskel.find_bone(bname) < 0:
					if not bad_binds.has(bname):
						bad_binds.append(bname)
		_check("figure", "%s: every Skin bind resolves to a bone its own skeleton has — an unresolved bind draws NOTHING" % hid,
			hskel != null and skinned > 0 and named > 0 and bad_binds.is_empty(),
			"%d skinned mesh(es), %d named binds, %d unresolved%s"
				% [skinned, named, bad_binds.size(),
					"" if bad_binds.is_empty() else " (" + ", ".join(bad_binds) + ")"])
		hero.free()
		## And the BUILT rig must stand at human height — SG-45's second fault.
		## The Boilerwright's Meshy glb is mixed-unit (mesh in metres, bones in
		## centimetres under an 0.01 Armature), so the ingest's static-AABB
		## ruler read 0.018 where the skeleton draws 1.8 at scale 1, and the
		## renderer scaled the whole rig a hundredfold: hips ninety metres off
		## the deck, exactly as invisible as an unbound skin. This measures the
		## skeleton the renderer will actually pose, through the same setup()
		## the game uses.
		var srig := SkyGearRig3D.new()
		root.add_child(srig)
		var sbuilt: bool = srig.setup(hpath,
			float(SkyGearView3D.HERO_MODELS[hid].height) * SkyGearView3D.WORLD_SCALE,
			SkyGearView3D.LAYER_FIGURES)
		var hip_y := -1.0
		if sbuilt and srig.skeleton != null:
			## Posed by a clip, not read at rest: the game never shows the rest
			## pose (a clip is always driving), and the captain's axe-pack rest
			## parks her hips below the deck while every played frame stands her
			## up. Sample the skeleton the way the renderer meets it.
			if srig.has_clip("idle"):
				srig.anim.play("idle")
				srig.anim.seek(0.05, true)
			var hip: int = srig.skeleton.find_bone("mixamorig_Hips")
			if hip >= 0:
				hip_y = (srig.skeleton.global_transform
					* srig.skeleton.get_bone_global_pose(hip)).origin.y
		_check("figure", "%s: the built rig stands its hips at human height — a mis-scaled skeleton is off-frame, not on it" % hid,
			hip_y > 0.3 and hip_y < 1.5, "hips %.2f m above the deck" % hip_y)
		srig.queue_free()

	## The Boilerwright's own rig — generated by Meshy, remeshed to budget BEFORE
	## rigging, auto-rigged, then the fourteen axe-pack clips retargeted onto him
	## from the captain's baked library (the archive being absent) via a bone-name
	## map. His scene is committed, so these assert the real file the way the
	## captain's rig checks above do.
	var bw_scene := str(bw_row.scene)
	if ResourceLoader.exists(bw_scene):
		var bwrig := SkyGearRig3D.new()
		root.add_child(bwrig)
		var bw_built: bool = bwrig.setup(bw_scene,
			float(bw_row.height) * SkyGearView3D.WORLD_SCALE, SkyGearView3D.LAYER_FIGURES)
		_check("figure", "the Boilerwright's rig builds from his retargeted scene", bw_built)
		if bw_built:
			## The same fourteen clips as the captain — so both classes move on the
			## SAME clock, which is the whole reason route 2 was chosen.
			var have := 0
			for c in ["idle", "idle_alt", "walk", "run", "run_back", "swing", "swing2",
					"swing3", "spin", "combo", "dash", "hurt", "block", "taunt"]:
				if bwrig.has_clip(c):
					have += 1
			_check("figure", "and his rig resolves all fourteen retargeted clips",
				have == 14, "%d of 14" % have)
			## Remeshed to ~3000 before rigging, so he is NOT the captain's SG-13
			## (30,634 triangles, a rigged mesh no remesh can safely decimate) again.
			var bwtris := 0
			for mi in bwrig.model.find_children("*", "MeshInstance3D", true, false):
				var mm: Mesh = (mi as MeshInstance3D).mesh
				for s in mm.get_surface_count():
					var ar := mm.surface_get_arrays(s)
					var iii: PackedInt32Array = ar[Mesh.ARRAY_INDEX]
					var vvv: PackedVector3Array = ar[Mesh.ARRAY_VERTEX]
					bwtris += (iii.size() / 3) if iii.size() > 0 else (vvv.size() / 3)
			_check("figure", "and his triangle count is inside the remesh budget",
				bwtris > 0 and bwtris <= 4000,
				"%d tris (target ~3000; the captain's SG-13 was 30634)" % bwtris)
			## SG-18 — HIS EMPTY HAND STILL CARRIES THE TRAIL. The wrench landed
			## (SG-38, the block below), but the knuckle mount stays pinned as
			## the FALLBACK tier: a missing or renamed wrench scene must degrade
			## to the empty fist drawing its arc, never to no trail at all.
			## Same rig family as the captain, same mount, same reader.
			var bw_mounted: bool = bwrig.mount_hand()
			var bw_pts := bwrig.blade_points()
			var bw_early := Vector3.ZERO
			var bw_late := Vector3.ZERO
			if bw_mounted and bwrig.has_clip("swing"):
				var bw_len: float = bwrig.anim.get_animation("swing").length
				bwrig.anim.play("swing")
				bwrig.anim.seek(bw_len * 0.12, true)
				bw_early = bwrig.blade_points()[1]
				bwrig.anim.seek(bw_len * 0.55, true)
				bw_late = bwrig.blade_points()[1]
			_check("trail", "the Boilerwright's empty hand mounts the trail, and it moves with his retargeted swing",
				bw_mounted and bw_pts.size() == 2
					and bw_pts[0].distance_to(bw_pts[1]) > 0.05
					and bw_early.distance_to(bw_late) > 0.10,
				"reach %.2f m, tip travelled %.2f m between two clip times"
					% [bw_pts[0].distance_to(bw_pts[1]) if bw_pts.size() == 2 else -1.0,
						bw_early.distance_to(bw_late)])
			## SG-38 — AND NOW THE WRENCH LANDS IN THAT HAND. The empty-hand
			## mount above stays pinned as the fallback tier; these assert the
			## delivered tool on top of it: his fit row exists, the generated
			## scene loads self-contained (the prune trap is a scene with no
			## meshes and no error), `hold()` replaces the empty fist with the
			## real mesh through the same call the renderer makes, and the
			## measured tip — the trail's own source — reaches PAST the knuckle
			## fallback, so his blade trail now traces the wrench's head.
			var bw_knuckle: float = bw_pts[0].distance_to(bw_pts[1]) \
				if bw_pts.size() == 2 else 0.0
			var bw_fit := SkyGearRig3D.weapon_fit("boilerwright")
			_check("weapon", "the Boilerwright has a weapons.json fit, and his wrench is on disk",
				not bw_fit.is_empty()
					and ResourceLoader.exists(str(bw_fit.get("path", ""))),
				"fit '%s' -> %s" % [str(bw_fit.get("weapon", "NO FIT")),
					str(bw_fit.get("path", "no path"))])
			if not bw_fit.is_empty() and ResourceLoader.exists(str(bw_fit.get("path", ""))):
				var bw_off: Array = bw_fit.get("offset", [0, 0, 0])
				var bw_turn: Array = bw_fit.get("rotation", [0, 0, 0])
				## The same metres-of-world conversion `_sync_captain` applies —
				## the fit table is authored against a 1.8 m figure.
				var bw_world: float = float(bw_row.height) * SkyGearView3D.WORLD_SCALE / 1.8
				var bw_held: bool = bwrig.hold(str(bw_fit.path), str(bw_fit.bone),
					Vector3(bw_off[0], bw_off[1], bw_off[2]) * bw_world,
					Vector3(bw_turn[0], bw_turn[1], bw_turn[2]),
					float(bw_fit.get("length", 0.95)) * bw_world,
					SkyGearView3D.LAYER_FIGURES)
				_check("weapon", "his mount carries the wrench itself now, not the empty hand",
					bw_held and bwrig.held != null and bwrig.held.has_meta("blade_tip"),
					"held through the renderer's own hold(), tip measured in mount space")
				var held_pts := bwrig.blade_points()
				var bw_reach: float = held_pts[0].distance_to(held_pts[1]) \
					if held_pts.size() == 2 else 0.0
				_check("weapon", "and his trail tip measures the wrench — nonzero, past the empty hand's knuckle reach",
					bw_reach > 0.0 and bw_reach >= bw_knuckle,
					"tip %.2f m against the empty hand's %.2f m" % [bw_reach, bw_knuckle])
				## Budgets, the same reader as his own body above: the wrench is a
				## prop remesh (3000 triangles, 512 base colour) and has to stay one.
				var wrench_scene := load(str(bw_fit.path)) as PackedScene
				var wrench_node: Node = wrench_scene.instantiate() if wrench_scene != null else null
				var wrench_tris := 0
				var wrench_side := 0
				if wrench_node != null:
					root.add_child(wrench_node)
					for mi in wrench_node.find_children("*", "MeshInstance3D", true, false):
						var wm: Mesh = (mi as MeshInstance3D).mesh
						if wm == null:
							continue
						for s in wm.get_surface_count():
							var war := wm.surface_get_arrays(s)
							var wii: PackedInt32Array = war[Mesh.ARRAY_INDEX]
							var wvv: PackedVector3Array = war[Mesh.ARRAY_VERTEX]
							wrench_tris += (wii.size() / 3) if wii.size() > 0 \
								else (wvv.size() / 3)
							var wmat := wm.surface_get_material(s) as BaseMaterial3D
							if wmat != null and wmat.albedo_texture != null:
								wrench_side = maxi(wrench_side,
									maxi(wmat.albedo_texture.get_width(),
										wmat.albedo_texture.get_height()))
					wrench_node.queue_free()
				_check("weapon", "and the wrench sits inside the prop remesh budget — triangles and base colour both",
					wrench_tris > 0 and wrench_tris <= 4000
						and wrench_side > 0 and wrench_side <= 512,
					"%d tris, %d px base colour (budget 3000 / 512)"
						% [wrench_tris, wrench_side])
				## The captain is untouched by his fit landing: her row still
				## names her cutlass and its scene still resolves — one table,
				## two wearers, neither able to eat the other's entry.
				var cap_fit := SkyGearRig3D.weapon_fit("captain")
				_check("weapon", "and the captain's own fit still carries her cutlass beside his",
					not cap_fit.is_empty()
						and str(cap_fit.get("weapon", "")) == "sword_cutlass"
						and ResourceLoader.exists(str(cap_fit.get("path", ""))),
					"captain holds '%s'" % str(cap_fit.get("weapon", "nothing")))
		bwrig.queue_free()

	## --- board SG-55: the scrapper pilot's guard rail, laid before the rig ---
	## The SG-45 pair above iterates HERO_MODELS; the boarders reach the same
	## renderer through `model_path(kind)` and `_sync_rig`, so the same two
	## faults — Skin binds resolving against nothing, and a rig scaled off the
	## frame — get the same guard, iterating every kind the simulation can
	## spawn. Today every committed boarder scene is a STATIC statue (Meshy's
	## rig endpoint refused the scrapper's fused anatomy — the pilot is blocked
	## on a T-pose regeneration, see the SG-55 row); the moment the first rigged
	## boarder scene lands, the skinned half of this loop is the check that
	## meets it, at the height `_sync_all` will actually draw it.
	var boarder_scenes := 0
	var boarder_rigged := 0
	var boarder_faults := PackedStringArray()
	for ekind in SkyGearData.ENEMIES.keys():
		var epath := SkyGearView3D.model_path(str(ekind))
		if not ResourceLoader.exists(epath):
			continue
		boarder_scenes += 1
		var enode: Node = (load(epath) as PackedScene).instantiate()
		var eskel: Skeleton3D = null
		for esk in enode.find_children("*", "Skeleton3D", true, false):
			eskel = esk as Skeleton3D
			break
		var emeshes := enode.find_children("*", "MeshInstance3D", true, false)
		if emeshes.is_empty():
			boarder_faults.append("%s: no meshes" % ekind)
		## The ruler `SkyGearRig3D.setup` scales by: the scene's own measured
		## height, or a measurable AABB when the meta is absent. A scene with
		## neither is drawn at whatever size the exporter felt like.
		var eruler: float = float(enode.get_meta("model_height", 0.0))
		if eruler <= 0.0:
			for emi in emeshes:
				eruler = maxf(eruler, (emi as MeshInstance3D).get_aabb().size.y)
		if eruler <= 0.0:
			boarder_faults.append("%s: no honest ruler" % ekind)
		if eskel != null:
			## SG-45 fault one, boarder edition: every named bind resolves
			## against the skeleton it ships beside, or the mesh draws NOTHING.
			for emi in emeshes:
				var eskin: Skin = (emi as MeshInstance3D).skin
				if eskin == null:
					continue
				for ebi in eskin.get_bind_count():
					var ebn := String(eskin.get_bind_name(ebi))
					if ebn != "" and eskel.find_bone(ebn) < 0:
						boarder_faults.append("%s: bind %s unresolved" % [ekind, ebn])
		enode.free()
		if eskel == null:
			continue
		boarder_rigged += 1
		## SG-45 fault two, boarder edition: built through the game's own
		## setup() at the height boarder_height() says — the renderer's one
		## copy of that arithmetic — the hips stand at CREATURE height. A
		## scrapper is drawn 93 units (0.93 m); its hips belong inside a metre
		## of the planking, not 89 of them up.
		var eheight: float = SkyGearView3D.boarder_height(str(ekind))
		var erig := SkyGearRig3D.new()
		root.add_child(erig)
		var ebuilt: bool = erig.setup(epath, eheight * SkyGearView3D.WORLD_SCALE,
			SkyGearView3D.LAYER_FIGURES)
		var ehip := -1.0
		if ebuilt and erig.skeleton != null:
			if erig.has_clip("idle"):
				erig.anim.play("idle")
				erig.anim.seek(0.05, true)
			var ehipb: int = erig.skeleton.find_bone("mixamorig_Hips")
			if ehipb >= 0:
				ehip = (erig.skeleton.global_transform
					* erig.skeleton.get_bone_global_pose(ehipb)).origin.y
		if not (ebuilt and ehip > eheight * SkyGearView3D.WORLD_SCALE * 0.15
				and ehip < eheight * SkyGearView3D.WORLD_SCALE * 1.1):
			boarder_faults.append("%s: hips %.2f m against a %.0f-unit figure"
				% [ekind, ehip, eheight])
		erig.queue_free()
	_check("figure", "every committed boarder scene keeps the SG-45 bargain — meshes, an honest ruler, and any skeleton it carries resolving its binds at creature height",
		boarder_scenes > 0 and boarder_faults.is_empty(),
		"%d scenes (%d rigged, %d static): %s" % [boarder_scenes, boarder_rigged,
			boarder_scenes - boarder_rigged,
			"clean" if boarder_faults.is_empty() else ", ".join(boarder_faults)])

	## --- board SG-55: speed-sync at boarder scale — the skating lesson, part two
	## `AUTHORED_RUN_SPEED` alone matches the cycle to the ground the CAPTAIN
	## covers. A boarder is drawn smaller, its stride sweeps proportionally
	## less deck per beat, and the raw quotient hands a half-height scrapper
	## the old ice-skate straight back — understating the needed rate by
	## exactly the height ratio. The rate must scale by the figure's own drawn
	## height (`AUTHORED_RUN_HEIGHT`), and a full-height figure must notice
	## nothing.
	var stride_full := SkyGearRig3D.new()
	root.add_child(stride_full)
	var stride_half := SkyGearRig3D.new()
	root.add_child(stride_half)
	var stride_full_ok: bool = stride_full.setup(SkyGearView3D.CAPTAIN_SCENE,
		SkyGearView3D.CAPTAIN_HEIGHT * SkyGearView3D.WORLD_SCALE,
		SkyGearView3D.LAYER_FIGURES)
	var stride_half_ok: bool = stride_half.setup(SkyGearView3D.CAPTAIN_SCENE,
		SkyGearView3D.CAPTAIN_HEIGHT * 0.5 * SkyGearView3D.WORLD_SCALE,
		SkyGearView3D.LAYER_FIGURES)
	if stride_full_ok and stride_half_ok:
		stride_full.want("run", SkyGearRig3D.AUTHORED_RUN_SPEED)
		_check("rig", "a full-height figure at the authored speed plays the cycle one-to-one",
			absf(stride_full.anim.speed_scale - 1.0) < 0.01,
			"rate %.3f" % stride_full.anim.speed_scale)
		## The scrapper's own numbers: half the reference height, 150 simulated
		## ground units a second — the same ground speed has to drive the small
		## figure's cycle twice as hard, or its feet slide.
		stride_full.want("run", 150.0)
		stride_half.want("run", 150.0)
		_check("rig", "the same ground speed drives a half-height figure's cycle twice as hard — stride, not just speed",
			absf(stride_half.anim.speed_scale - stride_full.anim.speed_scale * 2.0) < 0.02
				and absf(stride_half.anim.speed_scale - 150.0 / (210.0 * 0.5)) < 0.02,
			"half %.3f vs full %.3f" % [stride_half.anim.speed_scale,
				stride_full.anim.speed_scale])
	stride_full.queue_free()
	stride_half.queue_free()

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
	## Heat set before the ending fires, so the row below is a Heat 2 row — the
	## exact shape POST-PARITY-PLAN item 3 said could not reproduce its own run.
	game.heat = 2
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
	## What REPRODUCES the run: the seed replays the waves, but only against the
	## same class and the same Heat (same waves, different enemy health). Both
	## were in the row already — this pins them so they cannot quietly leave
	## (board SG-53; the `ship: [ids]` half waits on fittings existing).
	_check("log", "and the row carries the class and the heat that reproduce the run",
		str(row.get("class_id", "")) == "captain" and int(row.get("heat", -1)) == 2,
		"class %s, heat %s" % [str(row.get("class_id", "?")), str(row.get("heat", "?"))])
	_check("log", "and a Heat run's report line names its Heat",
		str(row.get("report", "")).contains("Heat 2"))
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

	## An old-format row — written before `heat` and `class_id` existed — still
	## loads, still counts, and reads as Heat 0: per-key fallback, the layout-
	## file pattern, never a migration step. And `best_heat` is the BEST ROW'S
	## heat, not a max across the log: this legacy wave 12 outranks the Heat 2
	## wave 6 above, so the readout must say Heat 0 (silence), not Heat 2.
	SkyGearRunLog.record({"won": true, "wave": 12, "time": "09:59"})
	var mixed: Dictionary = SkyGearRunLog.summary()
	_check("log", "an old-format row without heat or class still loads and counts",
		int(mixed.runs) == 3 and int(mixed.best_wave) == 12
			and int(mixed.get("best_heat", -1)) == 0,
		"%d runs, best %d at heat %s" % [int(mixed.runs), int(mixed.best_wave),
			str(mixed.get("best_heat", "?"))])

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

	## And the anchor invariant holds one level down: re-anchoring an ITEM leaves
	## it exactly where it was, the same promise the plates already keep.
	var re := SkyGearHudLayout.new()
	var re_plate: Rect2 = re.rect("captain", Vector2(1366, 768))
	var re_before: Rect2 = re.item("captain", "health", re_plate)
	re.set_anchor("captain", "health", "bottom_right", Vector2(1366, 768), re_plate)
	_check("layout", "re-anchoring an element leaves it where it was",
		re.item("captain", "health", re_plate).is_equal_approx(re_before),
		"%s -> %s" % [re_before, re.item("captain", "health", re_plate)])

	## THE SCREEN-ELEMENT LEVEL (SG-42). Same discipline as the plates: the file
	## round-trips, a malformed entry costs itself and nothing else, a typed
	## entry is parsed strictly, and one Ctrl+Z restores the pre-nudge value.
	var sc := SkyGearHudLayout.new()
	sc.nudge_screen("title", "begin_run", Vector2(12, -3))
	sc.nudge_screen("draft", "card_emblem", Vector2(-0.5, 4.5))
	_check("layout", "screen offsets survive a save and a load",
		sc.save()
			and SkyGearHudLayout.load_layout().screen_offset("title", "begin_run")
				.is_equal_approx(Vector2(12, -3))
			and SkyGearHudLayout.load_layout().screen_offset("draft", "card_emblem")
				.is_equal_approx(Vector2(-0.5, 4.5)))
	var junk_screens := SkyGearHudLayout._sanitise_screens({
		"title": {"begin_run": [4, 5], "settings": "sideways", "quit": [1, 2, 3]},
		"draft": "not even a dictionary",
	})
	_check("layout", "a malformed screen entry falls back alone",
		(junk_screens.get("title", {}) as Dictionary).has("begin_run")
			and not (junk_screens.get("title", {}) as Dictionary).has("settings")
			and not (junk_screens.get("title", {}) as Dictionary).has("quit")
			and not junk_screens.has("draft"),
		str(junk_screens))
	var accept: bool = bool(SkyGearHudLayout.parse_offset("  12, -3 ").ok) \
		and bool(SkyGearHudLayout.parse_offset("+4 0.5").ok)
	var refuse: bool = not bool(SkyGearHudLayout.parse_offset("12").ok) \
		and not bool(SkyGearHudLayout.parse_offset("a, b").ok) \
		and not bool(SkyGearHudLayout.parse_offset("1, 2, 3").ok) \
		and not bool(SkyGearHudLayout.parse_offset("").ok) \
		and not bool(SkyGearHudLayout.parse_offset("12deg, 4").ok)
	_check("layout", "a typed offset takes a pair and refuses everything else",
		accept and refuse)
	## The element key is what the element SAYS, minus its numbers — so a readout
	## keeps its key while its value ticks, and its saved offset stays attached.
	_check("layout", "a readout's number is not part of its key",
		SkyGearHudLayout.element_slug("WAVE 7 / 12") == SkyGearHudLayout.element_slug("WAVE 9 / 12")
			and SkyGearHudLayout.element_slug("THE WORKSHOP  ·  240")
				== SkyGearHudLayout.element_slug("THE WORKSHOP  ·  0")
			and SkyGearHudLayout.element_slug("BEGIN RUN") == "begin_run")
	## Single-level undo, the SG-39 convention: snapshot, nudge, restore, and the
	## pre-nudge value is back — plates and screens both.
	var un := SkyGearHudLayout.new()
	un.nudge_screen("title", "begin_run", Vector2(3, 3))
	var pre := un.snapshot()
	un.nudge_screen("title", "begin_run", Vector2(50, 0))
	un.nudge("captain", "", Vector2(80, 0))
	un.restore(pre)
	_check("layout", "undo restores the pre-nudge value",
		un.screen_offset("title", "begin_run").is_equal_approx(Vector2(3, 3))
			and un.rect("captain", Vector2(1366, 768))
				.is_equal_approx(SkyGearHudLayout.new().rect("captain", Vector2(1366, 768))))

	## Leave no editor state behind for the next run of the harness.
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SkyGearHudLayout.USER_PATH))

	## The floor is a decision. Below this the three clusters cannot share a
	## baseline without overlapping, and the export presets say 1152x648.
	var narrow: Dictionary = SkyGearHUD.hud_plates(Vector2(1152, 648))
	_check("layout", "the captain's plate clears the skill slots at the floor size",
		not (narrow.captain as Rect2).intersects(narrow.slot0 as Rect2),
		"gap %.0f px" % ((narrow.slot0 as Rect2).position.x
			- (narrow.captain as Rect2).end.x))


## --- the screen editor (SG-42) -------------------------------------------------
## The F4 editor reaches every screen now, and its element registry is built by
## the REAL draw code as it draws. So the checks drive the real draw: pose a
## screen, redraw, and read what the editor captured. `_draw` runs headless (the
## READBACK is what hangs, SG-29 — nothing here reads a pixel back).
func _screen_editor() -> void:
	## Shipped defaults only — a leftover user file would make this a test of
	## whatever the last editing session left behind.
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SkyGearHudLayout.USER_PATH))
	SkyGearHUD.layout = null
	var game := _new_game()
	await process_frame
	var hud: SkyGearHUD = game.hud
	hud.size = Vector2(1600, 900)
	game.layout_edit = true
	hud.queue_redraw()
	await process_frame

	## The title, first and hardest-working: widgets, free text, a banner.
	_check("editor", "the screen you are on is the screen you edit",
		hud.edit_screen == "title", hud.edit_screen)
	_check("editor", "the editor sees the title screen's elements",
		hud.edit_elements.size() >= 8, "%d elements" % hud.edit_elements.size())
	_check("editor", "a widget's key is its label",
		hud.edit_elements.has("begin_run") and hud.edit_elements.has("settings"),
		", ".join(hud.edit_elements.keys()))

	## An offset is relative to the element's COMPUTED HOME. Save one, redraw:
	## the element moves by exactly that much...
	var home0: Vector2 = Vector2.ZERO
	var moved_ok := false
	var followed := false
	if hud.edit_elements.has("begin_run"):
		home0 = hud.edit_elements["begin_run"].home
		var before: Rect2 = hud.edit_elements["begin_run"].box
		SkyGearHUD.layout.set_screen_offset("title", "begin_run", Vector2(14, -6))
		hud.queue_redraw()
		await process_frame
		var after: Rect2 = hud.edit_elements["begin_run"].box
		moved_ok = after.position.is_equal_approx(before.position + Vector2(14, -6))
		## ...and when the HOME moves (a wider window recentres the column), the
		## offset follows the home rather than pinning the old pixels.
		hud.size = Vector2(1920, 1080)
		hud.queue_redraw()
		await process_frame
		var entry: Dictionary = hud.edit_elements.get("begin_run", {})
		followed = not entry.is_empty() \
			and (entry.box as Rect2).position.is_equal_approx(
				(entry.home as Vector2) + Vector2(14, -6)) \
			and not (entry.home as Vector2).is_equal_approx(home0)
		SkyGearHUD.layout.set_screen_offset("title", "begin_run", Vector2.ZERO)
		hud.size = Vector2(1600, 900)
	_check("editor", "a saved offset moves the element by exactly that much", moved_ok)
	_check("editor", "the offset is measured from the home — move the home and it follows",
		followed)

	## Every screen family reachable, and every capture non-empty. The poses are
	## the game's own flags — the same doors the player walks through.
	var captured := {}
	captured["title"] = hud.edit_elements.keys()
	var families := [
		["settings", func() -> void: game.settings_open = true],
		["keys", func() -> void:
			game.settings_open = false
			game.keys_open = true],
		["how", func() -> void:
			game.keys_open = false
			game.how_open = true],
		["compare", func() -> void:
			game.how_open = false
			game.compare_open = true],
		["workshop", func() -> void:
			game.compare_open = false
			game.workshop_open = true],
		["draft", func() -> void:
			game.workshop_open = false
			game.begin_run()
			game.open_draft()],
		["pause", func() -> void: game._set_state(SkyGearGame.State.PAUSE)],
		["results", func() -> void:
			game.end_reason = "the Boiler went cold on wave 7"
			game._set_state(SkyGearGame.State.GAMEOVER)],
	]
	var wrong := ""
	for family in families:
		(family[1] as Callable).call()
		hud.queue_redraw()
		await process_frame
		var want := str(family[0])
		captured[want] = hud.edit_elements.keys()
		if hud.edit_screen != want:
			wrong += "%s drew as %s; " % [want, hud.edit_screen]
		elif hud.edit_elements.is_empty():
			wrong += "%s captured nothing; " % want
	_check("editor", "every screen family is reachable and captures its elements",
		wrong == "", wrong)
	## The draft's two-level story: cards register as panels, the emblem as a
	## grabbable non-text element.
	_check("editor", "the draft's cards are panels and the emblem is an element",
		"card_emblem" in (captured.get("draft", []) as Array),
		", ".join(captured.get("draft", []) as Array))

	## DATA WITH NO READER is failure mode one: every key in the SHIPPED file
	## must resolve to something the game actually draws. Plates and items are
	## checked against the tables; screen keys against the capture above. Today
	## the shipped file carries no screen offsets — this is the check that makes
	## a future one that resolves to nothing a red build, not a mystery.
	var shipped_raw: Variant = JSON.parse_string(
		FileAccess.get_file_as_string(SkyGearHudLayout.SHIPPED_PATH))
	_check("editor", "the shipped layout file parses", shipped_raw is Dictionary)
	var dead: Array[String] = []
	if shipped_raw is Dictionary:
		for plate_name in (shipped_raw.get("plates", {}) as Dictionary).keys():
			if not SkyGearHudLayout.DEFAULT.has(plate_name):
				dead.append("plates/%s" % plate_name)
				continue
			var items: Dictionary = (shipped_raw.plates[plate_name] as Dictionary) \
				.get("items", {})
			for item_name in items.keys():
				if not (SkyGearHudLayout.DEFAULT[plate_name] as Dictionary) \
						.get("items", {}).has(item_name):
					dead.append("plates/%s/%s" % [plate_name, item_name])
		for item_name in (shipped_raw.get("slot_items", {}) as Dictionary).keys():
			if not SkyGearHudLayout.SLOT_ITEMS.has(item_name):
				dead.append("slot_items/%s" % item_name)
		for screen in (shipped_raw.get("screens", {}) as Dictionary).keys():
			if not captured.has(screen):
				dead.append("screens/%s (no such screen)" % screen)
				continue
			for key in (shipped_raw.screens[screen] as Dictionary).keys():
				if not key in (captured[screen] as Array):
					dead.append("screens/%s/%s" % [screen, key])
	_check("editor", "every key in the shipped file resolves to something drawn",
		dead.is_empty(), ", ".join(dead))

	game.layout_edit = false
	hud.audit = null
	hud.ink = null
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SkyGearHudLayout.USER_PATH))
	SkyGearHUD.layout = null
	game.queue_free()
	await process_frame


## --- the screen picker and the posed sandbox (SG-44) ----------------------------
## Round two of the alignment ask: the editor can now POSE any screen the audit
## shoots — on a sandbox game, never on the live run — and hand the run back
## exactly. These checks drive the real path end to end: `pose_screen` builds
## the sandbox `main.tscn`, the SHARED poser (`scripts/screen_poser.gd`, the
## same one the audit and the batch camera call) dresses it, `end_pose` frees
## it. Headless is fine — nothing here reads a pixel back (SG-29).
func _screen_poser() -> void:
	var screens_tool := preload("res://tools/screens.gd")
	var poser := preload("res://scripts/screen_poser.gd")
	## ONE LIST. The tool's door and the shared poser must enumerate the same
	## screens, or the picker covers less than the batch page and failure mode
	## two has its second copy back.
	_check("editor", "the picker poses the batch tool's own screens — one list",
		screens_tool.SCREENS == poser.SCREENS and screens_tool.SIZES == poser.SIZES,
		"%d tool vs %d poser screens" % [screens_tool.SCREENS.size(), poser.SCREENS.size()])

	DirAccess.remove_absolute(ProjectSettings.globalize_path(SkyGearHudLayout.USER_PATH))
	SkyGearHUD.layout = null
	var game := _new_game()
	await process_frame
	var hud: SkyGearHUD = game.hud
	hud.size = Vector2(1600, 900)
	## A run in flight, mid-wave — the exact state the owner poses GAMEOVER from.
	_begin(game)
	game.start_wave(3)
	for i in 3:
		game.spawn_enemy("SCRAPPER", i)
	_advance(game, 2.0)
	## One settled frame BEFORE the fingerprint: `start_wave` restows the deck
	## by queue_free, and a freed-but-not-yet-dead prop would be counted here
	## and gone by the comparison — a lie about the pose, told by the shutter.
	await process_frame
	var before := _run_fingerprint(game)
	var runs_on_disk: int = SkyGearRunLog.load_all().size()

	game.layout_edit = true
	await game.pose_screen("deck lost")
	_check("editor", "the picker poses GAMEOVER on a sandbox, not on the run",
		game.pose_game != null and game.state_name == "PLAY"
		and game.pose_game.hud.screen_id() == "results"
		and game.pose_game.state_name == "GAMEOVER",
		"sandbox %s, live %s" % [
			game.pose_game.hud.screen_id() if game.pose_game != null else "(none)",
			game.state_name])
	_check("editor", "and the pose freezes the run while the glass is up",
		not game.is_playing() and not game.is_processing()
		and not game.player.controls_enabled
		and not game.player.is_physics_processing())
	## A POSED ENDING IS A PICTURE (board SG-49): nothing reaches the run log on
	## disk, and the screen still shows the healthy "saved to the run log" line.
	_check("editor", "a posed ending writes no fake row to the run log",
		SkyGearRunLog.load_all().size() == runs_on_disk
		and game.pose_game != null and game.pose_game.run_logged,
		"%d rows before, %d after" % [runs_on_disk, SkyGearRunLog.load_all().size()])

	## THE SAVED-BY-ID CONTRACT: the posed screen registers its elements under
	## the same screen id the naturally-reached screen uses — one id, one entry.
	game.pose_game.hud.queue_redraw()
	await process_frame
	var sandbox_keys: Array = game.pose_game.hud.edit_elements.keys()
	_check("editor", "a posed screen captures its elements for the editor",
		sandbox_keys.size() >= 8, "%d elements" % sandbox_keys.size())
	var posed_id: String = game.pose_game.hud.edit_screen
	## A WIDGET key, because a widget's box sits exactly at home+offset (a text
	## row's box is its ink, whose top rides above the baseline the code asked
	## for — true on both sides, but not the arithmetic being asserted here).
	var probe_key := "play_again"
	_check("editor", "and the posed results screen carries its own buttons",
		probe_key in sandbox_keys, ", ".join(sandbox_keys))
	SkyGearHUD.layout.set_screen_offset(posed_id, probe_key, Vector2(9, 4))

	## LEAVING HANDS THE RUN BACK EXACTLY — the cutscene player's contract,
	## applied to the editor's glass. Fingerprinted the same frame the pose
	## drops: the run must come back the moment the glass does, not after a
	## frame of catch-up.
	game.end_pose()
	var after := _run_fingerprint(game)
	_check("editor", "and leaving the pose hands the run back exactly",
		before == after and game.pose_game == null and game.is_playing()
		and hud.visible and game.player.controls_enabled,
		"" if before == after else "before %s, after %s" % [before, after])
	await process_frame

	## ...and the NATURALLY-reached results screen reads the offset that was
	## saved while posed: same id, same key, same pixels.
	game.log_runs = false          ## the harness's ending is not a run either
	game.end_reason = "the Boiler went cold on wave 3"
	game._set_state(SkyGearGame.State.GAMEOVER)
	hud.queue_redraw()
	await process_frame
	var natural: Dictionary = hud.edit_elements.get(probe_key, {})
	_check("editor", "an offset saved on a posed screen moves the real screen",
		hud.edit_screen == posed_id and not natural.is_empty()
		and (natural.box as Rect2).position.is_equal_approx(
			(natural.home as Vector2) + Vector2(9, 4)),
		"screen %s, key %s" % [hud.edit_screen, probe_key])
	SkyGearHUD.layout.set_screen_offset(posed_id, probe_key, Vector2.ZERO)

	## EVERY audit screen is posable from the picker — the sandbox is reused
	## across picks the way the audit reuses one game across its matrix — and
	## between them the poses land on all ten screen families.
	game.go_to_title()
	var families := {}
	var failed := ""
	for screen in poser.SCREENS:
		await game.pose_screen(str(screen.name))
		if game.pose_game == null:
			failed += "%s did not pose; " % str(screen.name)
			continue
		var id: String = game.pose_game.hud.screen_id()
		if id == "":
			failed += "%s posed as no screen; " % str(screen.name)
		families[id] = true
	_check("editor", "every audit screen is posable from the picker",
		failed == "", failed)
	var missing := ""
	for fam in ["title", "keys", "settings", "how", "compare", "workshop",
			"draft", "pause", "results", "hud"]:
		if not families.has(fam):
			missing += fam + " "
	_check("editor", "and the poses land on all ten screen families",
		missing == "", "unreached: " + missing)
	game.end_pose()
	await process_frame

	## TWO GAMES IN ONE TREE STAY APART (board SG-50). The groups are tree-wide,
	## and `go_to_title`/`restow_props` used to sweep them tree-wide — a posed
	## sandbox would have freed the live run's boarders and props on arrival.
	var second := _new_game()
	_begin(second, "PARITY2")
	second.start_wave(2)
	for i in 2:
		second.spawn_enemy("SCRAPPER", i)
	await process_frame
	var held_enemies: int = second.enemies().size()
	var held_props: int = second.props().size()
	game.go_to_title()
	game.restow_props()
	await process_frame
	_check("editor", "two games in one tree keep their boarders and props apart",
		held_enemies > 0 and held_props > 0
		and second.enemies().size() == held_enemies
		and second.props().size() == held_props,
		"second held %d/%d, now %d/%d" % [held_enemies, held_props,
			second.enemies().size(), second.props().size()])

	game.layout_edit = false
	hud.audit = null
	hud.ink = null
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SkyGearHudLayout.USER_PATH))
	SkyGearHUD.layout = null
	game.queue_free()
	second.queue_free()
	await process_frame


## Everything "exactly" means for a frozen run, in one comparable value.
func _run_fingerprint(game: SkyGearGame) -> Dictionary:
	return {
		"run_time": game.run_time, "wave": game.wave, "state": game.state_name,
		"boiler": game.boiler_hp, "pressure": game.pressure,
		"player": game.player.global_position,
		"dashes": game.player.dash_charges,
		"enemies": game.enemies().size(), "props": game.props().size(),
		"rng": game.rng.state,
	}


func _views_resolve() -> bool:
	return _missing_views() == ""


func _missing_views() -> String:
	var out: Array[String] = []
	for kind in SkyGearSprites.VIEWS.keys():
		for view in (SkyGearSprites.VIEWS[kind] as Dictionary).keys():
			if SkyGearSprites.still(kind, view) == null:
				out.append("%s/%s" % [kind, view])
	return ", ".join(out)


## The SG-41 palette read: mean warmth (R/B) and the steel-navy fraction of a
## texture's opaque pixels. "Navy" is a SATURATED blue — hue 180..260 degrees at
## s > 0.15 — because that is the band the misattributed cargo chest actually
## lived in; a neutral dark shadow does not count, so a texture cannot fail for
## being dark, only for being blue. Sampled on a stride so a 2K albedo costs
## the harness milliseconds, not seconds.
func _albedo_stats(img: Image) -> Dictionary:
	if img == null:
		return {"warmth": 0.0, "navy": 1.0}
	if img.is_compressed():
		img.decompress()
	var r_sum := 0.0
	var b_sum := 0.0
	var navy := 0
	var n := 0
	var step: int = maxi(1, img.get_width() / 256)
	for y in range(0, img.get_height(), step):
		for x in range(0, img.get_width(), step):
			var c := img.get_pixel(x, y)
			if c.a < 0.5:
				continue
			r_sum += c.r
			b_sum += c.b
			n += 1
			if c.h > 0.5 and c.h < 0.72 and c.s > 0.15 and c.v > 0.1:
				navy += 1
	return {"warmth": r_sum / maxf(0.000001, b_sum), "navy": float(navy) / maxf(1.0, float(n))}


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

	## AND THE FLOOR SURVIVES THE WINDOW.
	##
	## MIN_PT is a size in the 1920 design canvas; what the player SEES is
	## `MIN_PT * window_w / BASE_W` physical pixels, because `canvas_items` scales
	## the whole layout to the window rather than reflowing it. The window can be as
	## narrow as MIN_WINDOW_W. Every check above only knows design-space points, so
	## all of them stay green while the smallest text falls to 8 physical pixels in
	## a too-narrow window — which is exactly what the legibility probe measured
	## before this item. This is the arithmetic that ties the point-size floor, the
	## physical floor and the minimum window together so lowering any one of the
	## three fails the build.
	_check("ink", "the point-size floor clears the physical floor at the min window",
		SkyGearInk.physical_pt(SkyGearInk.MIN_PT, SkyGearInk.MIN_WINDOW_W)
			>= SkyGearInk.MIN_PHYS_PX,
		"%.1f px at %d wide, floor %.1f" % [
			SkyGearInk.physical_pt(SkyGearInk.MIN_PT, SkyGearInk.MIN_WINDOW_W),
			SkyGearInk.MIN_WINDOW_W, SkyGearInk.MIN_PHYS_PX])
	## The downscale denominator has to be the canvas the project actually renders,
	## or `physical_pt` measures against a fiction. If someone re-bases the viewport
	## width, BASE_W must follow, and this is what says so.
	_check("ink", "the downscale base matches the project's design canvas",
		absf(SkyGearInk.BASE_W - float(ProjectSettings.get_setting(
			"display/window/size/viewport_width"))) < 0.5,
		"BASE_W %.0f vs viewport_width %s" % [SkyGearInk.BASE_W,
			str(ProjectSettings.get_setting("display/window/size/viewport_width"))])

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

	## THE CENTRAL EMBLEM (SG-35). The browser draws a gauge ring with a glyph on
	## EVERY card; the port drew it only on a weapon card with an empty preview, so
	## every upgrade card had a hole in its middle. `emblem_of` is the rule the
	## face reads, and this pins it: every card resolves a non-empty emblem, every
	## SLOT upgrade resolves the SHAPE of the weapon it lands on (with a glyph the
	## HUD can actually draw), and a weapon card resolves its own shape.
	card_game.skills.clear()
	for pair in [["CLOSEHIT", "EMBER"], ["RANGED_AOE", "FROST"], ["CONE", "ARC"],
			["CHAIN", "STEAM"]]:
		card_game.skills.append(SkyGearData.make_skill(str(pair[0]), str(pair[1])))
	var emblem_ok := true
	var emblem_shaped := 0
	var emblem_why := ""
	for entry in SkyGearCards.catalogue():
		if not (entry.get("can") as Callable).call(card_game):
			continue
		var made: Dictionary = (entry.get("make") as Callable).call(card_game, first)
		made["id"] = str(entry.id)
		made["kind"] = "card"
		made["scope"] = str(entry.scope)
		var em: Dictionary = SkyGearCards.emblem_of(card_game, made)
		if not em.has("kind"):
			emblem_ok = false
			emblem_why = "%s resolves no emblem" % str(entry.id)
		elif str(em.kind) == "shape":
			emblem_shaped += 1
			if not SkyGearHUD.SLOT_ICONS.has(str(em.shape)):
				emblem_ok = false
				emblem_why = "%s shape %s has no glyph" % [str(entry.id), str(em.shape)]
		## A slot upgrade lands on a weapon, so it MUST show that weapon's shape —
		## the exact case the port left blank.
		if str(entry.scope) == SkyGearCards.SCOPE_SKILL and str(em.get("kind", "")) != "shape":
			emblem_ok = false
			emblem_why = "slot card %s drew no shape" % str(entry.id)
	var weapon_card := {"kind": "skill", "scope": SkyGearCards.SCOPE_NEW,
		"skill": SkyGearData.make_skill("CONE", "EMBER")}
	var wem: Dictionary = SkyGearCards.emblem_of(card_game, weapon_card)
	_check("card", "every shaped card draws its emblem",
		emblem_ok and emblem_shaped > 0 and str(wem.get("kind", "")) == "shape"
			and str(wem.get("shape", "")) == "CONE",
		emblem_why if emblem_why != "" else "%d shaped cards resolve a glyph" % emblem_shaped)

	## THE HEADING NAMES THE DRAFT (SG-35). It said the generic "CHOOSE ONE" for
	## all three drafts where the browser names each one.
	card_game.opening_draft = true
	var h_open: String = SkyGearHUD.draft_heading(card_game)
	card_game.opening_draft = false
	var h_up: String = SkyGearHUD.draft_heading(card_game)
	card_game.skills.resize(2)
	var h_new: String = SkyGearHUD.draft_heading(card_game)
	_check("card", "the draft heading names the draft, not CHOOSE ONE",
		h_open != "CHOOSE ONE" and h_up != "CHOOSE ONE" and h_new != "CHOOSE ONE"
			and h_open == "CHOOSE YOUR OPENING WEAPON" and h_up == "DRAFT AN UPGRADE"
			and h_new == "ARM A NEW SLOT",
		"%s / %s / %s" % [h_open, h_new, h_up])

	## PROPORTION PIN (SG-35). The card was near-square (368×404 = 0.91), a
	## landscape plate; it is an unambiguous portrait now and this stops it
	## drifting back — the browser's tall card was the reference, not the target.
	_check("card", "the draft card is portrait, not the old near-square plate",
		SkyGearHUD.CARD_W < SkyGearHUD.CARD_H
			and SkyGearHUD.CARD_W / SkyGearHUD.CARD_H <= SkyGearHUD.CARD_ASPECT_MAX,
		"%.3f (ceiling %.2f)" % [SkyGearHUD.CARD_W / SkyGearHUD.CARD_H,
			SkyGearHUD.CARD_ASPECT_MAX])
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

	## AND THEY STAY OUT OF THE POSED-SHOT TOOLS. `sky_shot`, `parity_shot` and the
	## `screens` poser each begin a fresh run, and `begin_run` owes a `run_open`
	## crane that `_watch_cues` spends the first PLAY frame — so a tool that leaves
	## cutscenes live photographs the crane, not the pose it exists to make. The sky
	## was judged from cutscene frames from SG-8 until SG-33; the screens poser hid
	## the HUD on its GAMEOVER/VICTORY screens and the audit called them clean.
	##
	## READ BACK OUT OF THE SOURCE, because a behavioural check cannot catch this:
	## headless, the crane's own 2.5s burns through before a frame is saved, so an
	## "is a cutscene active" assertion passes on the BROKEN tool and proves nothing
	## — the exact "check that cannot fail" this round set out to end. A deleted
	## suppression line, by contrast, is a source diff this cannot miss.
	##
	## `telegraph_shot` and `vfx_shot` are deliberately NOT required here: each steps
	## to wave 3 with no `await` between `choose_draft` and `start_wave`, so
	## `_watch_cues` never observes wave 1 (no `run_open`) and `wave_start` does not
	## fire on wave 3 — measured inactive at the locked 41.25°/0° solve, not exposed.
	var unsuppressed := ""
	## The screens poser moved to `scripts/screen_poser.gd` (SG-44) — the shared
	## code the audit, the batch camera AND the F4 picker now pose through — so
	## the suppression line is required THERE, where the posing actually is.
	for path in ["res://tools/sky_shot.gd", "res://tools/parity_shot.gd",
			"res://scripts/screen_poser.gd"]:
		if not FileAccess.get_file_as_string(path).contains("cutscenes_enabled = false"):
			unsuppressed += " " + str(path)
	_check("cutscene", "the posed-shot tools suppress cutscenes so no cue poses their camera",
		unsuppressed == "", "still exposed:%s" % unsuppressed)

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

	## ─── SG-8: THE OTHER FOUR CUES, FILLED. ───────────────────────────────────
	## The Colossus was the one authored shot; `wave_start`, `victory`, `defeat`
	## and the new `run_open` were wired and EMPTY. An empty wired cue reads as
	## done and plays nothing — failure mode one — so every cue must resolve to a
	## shot with real movement, and the shots that play EVERY run are held under a
	## duration budget so a slow one cannot creep in later and be hated 60 times.
	var cue_budget := {"run_open": 2.6, "victory": 6.0, "defeat": 4.2}
	for cue_name in cue_budget:
		var cid := SkyGearCutscene.for_cue(cue_name)
		var csc := SkyGearCutscene.load_scene(cid)
		var ckeys: Array = csc.get("keys", [])
		var clen := SkyGearCutscene.length(csc)
		_check("cutscene", "the %s cue carries a playable shot" % cue_name,
			cid != "" and ckeys.size() >= 2 and clen > 0.0,
			"%s · %d keys · %.2fs" % [cid, ckeys.size(), clen])
		_check("cutscene", "and the %s shot stays inside its duration budget" % cue_name,
			clen <= float(cue_budget[cue_name]),
			"%.2fs ≤ %.2fs" % [clen, float(cue_budget[cue_name])])

	## `wave_start` is a milestone flourish, narrowed by its `wave` field to the
	## non-boss event waves (4 grapple, 8 blackout). It must NEVER claim wave 12 —
	## that wave belongs to the Colossus (`boss_arrival`), and a `wave_start` shot
	## running there would still be active when the boss spawns and SUPPRESS the
	## arrival. And it must stay off the ordinary waves, so it is a punctuation, not
	## a thing seen every wave sixty times.
	_check("cutscene", "wave_start fires on the event waves 4 and 8, never the boss wave or an ordinary one",
		SkyGearCutscene.for_cue("wave_start", 4) != ""
			and SkyGearCutscene.for_cue("wave_start", 8) != ""
			and SkyGearCutscene.for_cue("wave_start", 12) == ""
			and SkyGearCutscene.for_cue("wave_start", 2) == ""
			and SkyGearCutscene.for_cue("wave_start", 1) == "",
		"4=%s 8=%s 12=%s 2=%s" % [SkyGearCutscene.for_cue("wave_start", 4),
			SkyGearCutscene.for_cue("wave_start", 8),
			SkyGearCutscene.for_cue("wave_start", 12),
			SkyGearCutscene.for_cue("wave_start", 2)])
	var ws := SkyGearCutscene.load_scene(SkyGearCutscene.for_cue("wave_start", 4))
	_check("cutscene", "and a wave_start flourish is short — under a second and a half",
		SkyGearCutscene.length(ws) <= 1.5 and (ws.get("keys", []) as Array).size() >= 2,
		"%.2fs" % SkyGearCutscene.length(ws))

	## EACH ONE ACTUALLY PLAYS, on the real renderer, and hands the gameplay camera
	## back EXACTLY — the same demand the Colossus is held to, made of all five.
	## `game.state_name` is still "PLAY" here (from `_begin`), so `advance` runs
	## each shot to its end rather than stopping it as a menu.
	var play_home: Transform3D = view.camera.global_transform
	var play_home_fov: float = view.camera.fov
	for pid in ["run_open", "victory", "defeat", "wave_start_grapple", "wave_start_blackout"]:
		var started := view.play_cutscene(pid)
		var entered := view.cutscene_active()
		view._process(0.3)
		for _j in 16:
			view._process(0.5)
		view._process(0.1)
		var back := view.camera.global_transform.origin.distance_to(play_home.origin) \
			/ SkyGearView3D.WORLD_SCALE
		_check("cutscene", "the %s shot plays and hands the gameplay camera back exactly" % pid,
			started and entered and not view.cutscene_active()
				and back < 0.01 and absf(view.camera.fov - play_home_fov) < 0.0001,
			"%.5f gu off, lens %.4f" % [back, view.camera.fov])

	## THE ONE CODE LINE OUTSIDE DATA: `run_open` has no natural call site, because
	## `begin_run` settles into the opening DRAFT where a cutscene is not allowed.
	## So `begin_run` raises a flag and `_watch_cues` spends it the first frame the
	## deck reaches PLAY. Both halves are pinned here.
	game.begin_run()
	_check("cutscene", "begin_run flags the run as owing an establishing shot",
		bool(game.run_opening))
	view._cue_state = int(SkyGearGame.State.PLAY)
	view._cue_wave = 0
	game.state = SkyGearGame.State.PLAY
	game.wave = 1
	view._watch_cues()
	_check("cutscene", "and _watch_cues spends it on the first wave, opening the run once",
		view.cutscene_active() and not game.run_opening)
	view.stop_cutscene()

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


## SG-39: the model lab's weapon-mount fix and typed-input parser, tested through
## `LabMath` (tools/lab_math.gd) because the lab itself is windowed and its
## readback hangs under --headless on this machine (SG-29). The tool wires these
## functions; the harness pins the arithmetic they turn on.
func _lab() -> void:
	## The order Node3D.rotation uses, which is what SkyGearRig3D.hold applies a
	## fit's stored Euler in. Every basis<->euler round trip below depends on it —
	## pin it, so a future engine default cannot silently break every saved fit.
	var probe := Node3D.new()
	_check("lab", "the fit Euler order is Node3D's own default, so hold() reproduces the basis",
		LabMath.FIT_EULER_ORDER == probe.rotation_order,
		"LabMath %d vs Node3D %d" % [LabMath.FIT_EULER_ORDER, probe.rotation_order])
	probe.free()

	## THE FIT-COMPATIBILITY GUARANTEE. The refactor moved the mount's live
	## rotation to a Basis, but a saved fit must still load to the exact pose it
	## saved at. The shipped cutlass fit sits on the pitch -90 singularity, the
	## worst case: build the basis the OLD lab built by passing its Euler straight
	## through, then the basis the NEW lab rebuilds after a load->extract->reload
	## round trip, and assert they are the same orientation.
	var fit := SkyGearRig3D.weapon_fit("captain")
	var stored := Vector3(-96.0, -96.0, 0.0)
	if fit.has("rotation") and fit.rotation is Array and (fit.rotation as Array).size() >= 3:
		stored = Vector3(float(fit.rotation[0]), float(fit.rotation[1]), float(fit.rotation[2]))
	var old_basis := LabMath.fit_basis(stored)
	var reloaded := LabMath.fit_basis(LabMath.fit_euler_deg(old_basis))
	var fit_drift := LabMath.basis_drift(old_basis, reloaded)
	_check("lab", "the shipped weapons.json fit loads to the same basis after the local-axis refactor",
		fit_drift < 0.0001, "drift %.7f at rot %s" % [fit_drift, str(stored)])

	## THE GIMBAL COLLAPSE the owner reported: at pitch -90, incrementing the
	## stored Euler yaw and incrementing the stored Euler roll build the SAME
	## basis — the two rows "do the same thing".
	var at_lock := LabMath.fit_basis(Vector3(-90.0, 0.0, 0.0))
	var euler_yaw := LabMath.fit_basis(Vector3(-90.0, 10.0, 0.0))
	var euler_roll := LabMath.fit_basis(Vector3(-90.0, 0.0, 10.0))
	_check("lab", "at pitch -90 the Euler yaw and roll rows collapse to one pose — the reported bug",
		LabMath.basis_drift(euler_yaw, euler_roll) < 0.0001,
		"euler yaw-vs-roll drift %.8f" % LabMath.basis_drift(euler_yaw, euler_roll))

	## THE FIX: rotating about the weapon's live LOCAL axes stays distinct there.
	var lx := LabMath.rotate_local(at_lock, 0, 10.0)
	var ly := LabMath.rotate_local(at_lock, 1, 10.0)
	var lz := LabMath.rotate_local(at_lock, 2, 10.0)
	var min_split: float = min(LabMath.basis_drift(lx, ly),
		min(LabMath.basis_drift(ly, lz), LabMath.basis_drift(lx, lz)))
	_check("lab", "but a local-axis nudge about pitch, yaw and roll stays distinct at that singularity",
		min_split > 0.1, "closest pair %.4f apart" % min_split)
	## And each nudge actually moves the pose it is applied to.
	_check("lab", "a local-axis rotation nudge changes the pose",
		LabMath.basis_drift(at_lock, lx) > 0.01, "%.4f" % LabMath.basis_drift(at_lock, lx))

	## THE TYPED-INPUT PARSER: accepts well-formed numbers with the right value.
	var accepts := {"0.303": 0.303, " -96 ": -96.0, "+.5": 0.5, "3": 3.0, "-0.02": -0.02}
	var accept_ok := true
	var accept_detail := ""
	for text in accepts:
		var p := LabMath.parse_number(text)
		if not bool(p.ok) or not is_equal_approx(float(p.value), float(accepts[text])):
			accept_ok = false
			accept_detail = "'%s' -> %s" % [text, str(p)]
	_check("lab", "the typed-input parser accepts a well-formed number and reads its value",
		accept_ok, accept_detail)

	## And refuses malformed input, so a bad entry keeps the old value.
	var refuses := ["12deg", "1,5", "", "  ", "abc", "--3", "1.2.3"]
	var refuse_ok := true
	var refuse_detail := ""
	for text in refuses:
		if bool(LabMath.parse_number(text).ok):
			refuse_ok = false
			refuse_detail = "accepted '%s'" % text
	_check("lab", "and refuses malformed input so the old value is kept",
		refuse_ok, refuse_detail)


## SG-47: the clip tool's plan arithmetic and scenario table, tested through
## `ClipMath` (tools/clip_math.gd) — the LabMath split, for the same reason: the
## tool itself is windowed (the readback hangs headless, SG-29), so everything
## it must get right BEFORE a window opens is pulled out where the harness can
## load it. The stitcher's zero-frame refusal runs here too, because that half
## is Python and needs no framebuffer. The windowed halves — a real clip end to
## end, file on disk, frame count matching — are the tool's own smoke, which
## `hub -- all` runs (bare `tools/clip.gd` is the smoke).
func _clip() -> void:
	## The default ask: 4 seconds at 20 fps is every-3-ticks, 80 frames, 50 ms a
	## frame — and the GIF's own clock (frames x delay) is the sim's clock.
	var plan := ClipMath.plan(4.0, 20.0)
	_check("clip", "a plan's frames follow from seconds and fps",
		int(plan.every) == 3 and int(plan.frames) == 80
		and int(plan.ticks) == 240 and int(plan.delay_ms) == 50
		and is_equal_approx(float(plan.seconds), 4.0), str(plan))
	## Degenerate asks still produce a clip: zero seconds is one frame, and an
	## fps above the sim rate clamps to one tick per frame rather than skipping.
	var tiny := ClipMath.plan(0.0, 999.0)
	_check("clip", "a degenerate ask still yields one whole frame",
		int(tiny.frames) == 1 and int(tiny.every) == 1, str(tiny))
	## Duration never comes back silently short: a fractional ask rounds UP to
	## whole frames, so 1.01 s at 12 fps is 13 frames, not 12.
	var up := ClipMath.plan(1.01, 12.0)
	_check("clip", "a fractional ask rounds up to whole frames",
		int(up.every) == 5 and int(up.frames) == 13
		and float(up.seconds) >= 1.01, str(up))

	## THE TABLE IS COMPLETE: every name the tool advertises resolves to a spec
	## with a stageable kind and a positive default length. A scenario that is
	## listed and does not resolve is a tool that fails at the exact moment
	## somebody reaches for evidence.
	var kinds := ["fight", "dash", "projectiles", "scrapper", "cutscene"]
	var unresolved := ""
	for id in ClipMath.ids():
		var spec := ClipMath.find(str(id))
		if spec.is_empty() or not kinds.has(str(spec.get("kind", ""))) \
				or float(spec.get("seconds", 0.0)) <= 0.0:
			unresolved = str(id)
	_check("clip", "every named scenario resolves", unresolved == "", unresolved)

	## SG-32'S CLOSURE: every shipped cutscene is a clip scenario, derived from
	## the same `list_ids()` the game plays from — a scene authored tomorrow has
	## a motion-evidence path the same day, with nobody remembering to add it.
	var missing := ""
	var cut_short := ""
	for id in SkyGearCutscene.list_ids():
		if not ClipMath.ids().has(str(id)):
			missing = str(id)
			continue
		var spec := ClipMath.find(str(id))
		var scene := SkyGearCutscene.load_scene(str(id))
		if float(spec.seconds) < SkyGearCutscene.length(scene) \
				+ ClipMath.CUTSCENE_TAIL - 0.001:
			cut_short = str(id)
	_check("clip", "the scenario set covers every shipped cutscene",
		missing == "", missing)
	## And a cutscene clip's default length films the whole authored scene PLUS
	## the tail that shows the camera handed back — the half of the player's
	## contract a still can never witness.
	_check("clip", "a cutscene clip's default length films the whole scene plus the hand-back",
		cut_short == "", cut_short)

	## THE STITCHER REFUSES ZERO FRAMES. An empty clip must fail loudly at the
	## stitch, not become a 0-byte file somebody opens three days later. The
	## refusal is exercised for real — the actual script, an actually empty
	## directory — because a refusal asserted from reading the source is the
	## claims-from-memory failure mode with extra steps.
	var empty_dir := ProjectSettings.globalize_path("user://clip_zero_frames")
	DirAccess.make_dir_recursive_absolute(empty_dir)
	for stale in DirAccess.get_files_at(empty_dir):
		DirAccess.remove_absolute("%s/%s" % [empty_dir, str(stale)])
	var refused_gif := "%s/refused.gif" % empty_dir
	var lines: Array = []
	var code := OS.execute("python", [
		ProjectSettings.globalize_path("res://tools/clip_stitch.py"),
		empty_dir, refused_gif], lines, true)
	_check("clip", "the stitcher refuses zero frames",
		code != 0 and not FileAccess.file_exists(refused_gif), "exit %d" % code)
