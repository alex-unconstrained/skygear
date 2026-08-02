extends SceneTree
## Who is actually killing things?
##
## A real run came back with crew and cannons on 46% of all damage — nearly half
## the fight, done by allies the player does not control. The reading was that
## they should soak and hold rather than kill. That is a tuning question, and a
## tuning question answered by playing three runs is answered by noise.
##
## This plays the whole twelve waves headless, several times, on fixed seeds, and
## reports the damage split. Same numbers as the run report, so a change here can
## be checked against a real run afterwards.
##
##   godot --path . --headless --script tools/balance.gd
##   godot --path . --headless --script tools/balance.gd -- 5     (runs)
##   godot --path . --headless --script tools/balance.gd -- 6 5   (runs, HEAT)
##   godot --path . --headless --script tools/balance.gd -- 6 0 opening_bid
##
## The second argument is a HEAT level (SG-14). It opens the whole ladder on an
## ephemeral workshop and starts every run at that rung, so the difficulty claim
## — a Heat 5 run is clearly harder than a Heat 0 one — can be measured across
## seeds rather than felt. Read the wave-reached and held columns as the
## difficulty signal; per the caveats below, read them as a DISTRIBUTION.
##
## The third argument is an ARTICLE id (SG-26), signed on the same ephemeral
## workshop before every run — so a vow's measured effect on a whole run can be
## put beside the baseline instead of asserted. An Article that comes back
## strictly better with no visible cost is a bonus wearing a vow's name.
func _initialize() -> void: call_deferred("_run")

const SEEDS := ["BAL1", "BAL2", "BAL3", "BAL4", "BAL5", "BAL6"]

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var count: int = int(args[0]) if args.size() > 0 else 3
	var heat: int = int(args[1]) if args.size() > 1 else 0
	var vow: String = str(args[2]) if args.size() > 2 else ""
	if vow != "" and not SkyGearWorkshop.ARTICLES.has(vow):
		print("  no such article: %s — the seals are %s" % [vow,
			", ".join(SkyGearWorkshop.ARTICLES.keys())])
		quit(1)
		return
	print("  HEAT %d · %s%s" % [heat, str(SkyGearWorkshop.HEAT[
		clampi(heat, 0, SkyGearWorkshop.HEAT.size() - 1)].name),
		"  ·  ARTICLE %s" % vow if vow != "" else ""])
	var ally_share := 0.0
	var player_share := 0.0
	var waves_reached := 0.0
	var wins := 0
	var results: Array = []
	for i in mini(count, SEEDS.size()):
		var r := await _one(SEEDS[i], heat, vow)
		results.append(r)
		ally_share += float(r.ally)
		player_share += float(r.player)
		waves_reached += float(r.wave)
		wins += 1 if bool(r.won) else 0
		print("  %-6s wave %2d %-10s  player %3.0f%%  allies %3.0f%%  passive %2.0f%%  vents %2d  close %2.0f%%  far %2.0f%%"
			% [SEEDS[i], int(r.wave), "HELD" if bool(r.won) else "lost",
				float(r.player), float(r.ally), float(r.passive), int(r.vents),
				float(r.close), float(r.far)])
	var n := float(mini(count, SEEDS.size()))
	print("")
	print("  across %d runs: %d held, average wave %.1f" % [int(n), wins, waves_reached / n])
	print("  player %.0f%%   allies %.0f%%" % [player_share / n, ally_share / n])
	print("")
	## The target the balance pass is aiming at, stated so a later run can be
	## judged against it rather than against a feeling.
	var allies: float = ally_share / n
	if allies > 30.0:
		print("  OVER TARGET — allies should hold lanes, not clear them. Want under 30%.")
	else:
		print("  allies at %.0f%%: holding rather than clearing." % allies)

	## THREE MORE THINGS, ALL OF THEM FROM REAL RUNS RATHER THAN A FEELING.
	##
	## A tool that watches one number tells you about one number. Two winning
	## playthroughs came back and every problem in them was invisible here.
	print("")
	var vented: float = 0.0
	var passives: float = 0.0
	var far: float = 0.0
	var ventless := 0
	for r in results:
		vented += float(r.vents)
		passives += float(r.passive)
		far += float(r.far)
		if bool(r.won) and int(r.vents) == 0:
			ventless += 1

	## 1. DID SHE EVER USE THE CLASS? The captain fills PRESSURE from damage
	## inside 210 units and vents at the cap for damage and health. A run that is
	## WON without venting once is a run where the class was decoration — and a
	## real one came back exactly that way, `vents 0 · healed 0`, holding the deck
	## through all twelve waves.
	if ventless > 0:
		print("  %d of %d runs were WON WITHOUT VENTING ONCE. The captain's gauge is"
			% [ventless, int(n)])
		print("  optional, which is the range-kiting problem v11 deleted coming back.")
	else:
		print("  every run that held used the gauge (%.1f vents average)." % (vented / n))

	## 2. IS THE BACK HALF OF THE DECK WHERE THE GAME IS PLAYED? Far is beyond
	## 2.6x close range — outside the gauge entirely.
	print("  %.0f%% of the fight was spent at long range%s"
		% [far / n, " — the gauge fills at none of it." if far / n > 35.0 else "."])

	## 3. ARE PASSIVES WORTH A DRAFT SLOT? Both real runs drafted one and it
	## returned 1% of damage. A card that cannot compete with the cards beside it
	## is a card the draft should not be offering.
	if passives / n < 5.0:
		print("  passives returned %.1f%% of damage — a drafted slot doing nothing."
			% (passives / n))
	else:
		print("  passives returned %.1f%% of damage." % (passives / n))
	print("")
	quit(0)


func _one(seed_text: String, heat: int = 0, vow: String = "") -> Dictionary:
	var game: SkyGearGame = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	## The whole ladder opened on a throwaway workshop, so the run can START at any
	## rung — `begin_run` clamps `heat` to what is available, so without this a
	## Heat 5 request would quietly play as Heat 0 (there is no clear on disk).
	game.workshop = SkyGearWorkshop.fresh(true)
	game.workshop.unlocked = true
	game.workshop.best_heat = SkyGearWorkshop.HEAT.size() - 1
	## The vow under measurement (SG-26), signed before `begin_run` resolves it.
	if vow != "":
		game.workshop.sigils = 9
		SkyGearWorkshop.take(game.workshop, vow)
	game.heat = heat
	## HAND-STEPPED, so the engine must not step it too.
	##
	## The loop below calls `game._process(0.05)` and awaits a real frame every two
	## hundred steps — and the game node is in the tree, so the engine called
	## `_process` as well, with whatever delta the machine happened to produce.
	## Fixed seeds, non-deterministic result: BAL1 returned 7 vents and 73% far on
	## one run and 26 vents and 54% far on the next, same seed, no change between.
	##
	## So every number this tool has printed was noise — in the one file whose
	## opening comment is that a tuning question answered by three runs is
	## answered by noise. Third place in this project an in-tree node was stepped
	## twice; the VFX agent found the same thing in `parity_shot.gd`.
	game.set_process(false)
	game.set_physics_process(false)
	## AND IT IS STILL NOT DETERMINISTIC, which is worth saying plainly rather
	## than leaving for the next person to rediscover. With the double-step gone
	## the same seed still returns different runs — the captain, the boarders,
	## the crew and the cannons are separate nodes and the engine keeps ticking
	## them on the frames this loop awaits.
	##
	## `game.process_mode = PROCESS_MODE_DISABLED` is the obvious fix and it does
	## NOT work: it is inherited by the whole subtree, which stops the timers the
	## wave loop waits on, and the run never terminates. I tried it and killed it
	## after ten minutes.
	##
	## The real fix is to stop awaiting real frames at all, which means finding
	## another way to keep the process responsive across a twelve-wave sim.
	## Until then, read these numbers as a DISTRIBUTION across seeds and not as
	## a measurement of one — and run more seeds than you think you need.
	if game.impact != null:
		game.impact.enabled = false
	game.set_seed_text(seed_text)
	game.begin_run()
	game.choose_draft(0)
	## A competent-but-not-optimal player: casts what is off cooldown at whatever
	## is nearest, keeps moving, never kites to max range.
	var steps := 0
	while game.state_name == "PLAY" or game.state_name == "DRAFT":
		if game.state_name == "DRAFT":
			## Card 0 every time meant the bot could finish a run having never
			## taken a passive, so "passives did 0%" was a fact about the bot.
			## It now PREFERS one when offered, which is the pessimistic read the
			## question needs: if a player who deliberately drafts them still
			## gets nothing back, they are not worth a slot.
			var pick := 0
			## THE OPENING BID's matrix: more than four options is the grid, and
			## "prefers a passive" there would open every run with a Field — a
			## fact about this bot, not about the Article. Cell 0 is the first
			## unheld shape in EMBER, which is the plain competent bid.
			if game.draft_options.size() <= 4:
				for card_index in game.draft_options.size():
					var shape := str((game.draft_options[card_index] as Dictionary)
						.get("skill", {}).get("shape", ""))
					if shape != "" and bool(SkyGearData.SHAPES.get(shape, {}).get(
							"passive", false)):
						pick = card_index
						break
			game.choose_draft(pick)
		game._process(0.05)
		for e in game.get_tree().get_nodes_in_group("enemies"):
			if is_instance_valid(e):
				## Hand-stepped, so the engine must not step them too.
				e.set_physics_process(false)
				e._physics_process(0.05)
		if steps % 4 == 0:
			var target: SkyGearEnemy = game.nearest_enemy(game.player.global_position, 900.0)
			if target != null:
				for slot in game.skills.size():
					if float(game.skills[slot].cooldown_left) <= 0.0:
						game.cast_skill(slot, target.global_position)
						break
		steps += 1
		if steps % 200 == 0:
			await process_frame
		if steps > 40000:
			break

	var tel: Dictionary = game.tel
	var total: float = float(tel.basic.damage) + float(tel.deck.damage) + float(tel.allies.damage)
	for row in tel.per:
		total += float(row.damage)
	total = maxf(1.0, total)
	var player_dmg: float = float(tel.basic.damage)
	for row in tel.per:
		player_dmg += float(row.damage)
	## WHERE SHE SPENT THE FIGHT, and whether she ever used the class at all.
	## Added after two real winning runs came back with `vents 0 · healed 0` and
	## 47% of the time at long range — the captain's whole premise is "how long
	## can you stand in it?", and both runs answered "you do not have to".
	var seconds: Dictionary = tel.range_time
	var lived: float = maxf(0.001, float(seconds.close) + float(seconds.mid)
		+ float(seconds.far) + float(seconds.none))
	## And what the PASSIVE slots contributed, because the same two runs put a
	## drafted passive on 1% of damage and 2 kills across twelve waves.
	## Read off the SHAPE, which is what `_slot_skill` uses to decide a passive
	## keeps off the mouse buttons. The first version asked the row for a
	## "passive" key — `tel.per` rows carry `shape` and `element` and no such
	## field — so it answered false every time and could only ever print 0.0%.
	## A number that cannot come out non-zero is not a measurement, and this file
	## exists because tuning by feel is not evidence.
	var passive_dmg := 0.0
	for row in tel.per:
		var shape := str(row.get("shape", ""))
		if shape != "" and bool(SkyGearData.SHAPES.get(shape, {}).get("passive", false)):
			passive_dmg += float(row.damage)
	var out := {
		"wave": game.wave,
		"won": game.state_name == "VICTORY",
		"player": player_dmg / total * 100.0,
		"ally": float(tel.allies.damage) / total * 100.0,
		"deck": float(tel.deck.damage) / total * 100.0,
		"vents": int(tel.vents),
		"close": float(seconds.close) / lived * 100.0,
		"far": float(seconds.far) / lived * 100.0,
		"passive": passive_dmg / total * 100.0,
	}
	game.queue_free()
	await process_frame
	return out
