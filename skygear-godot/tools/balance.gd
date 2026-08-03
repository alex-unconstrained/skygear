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
##
## ---------------------------------------------------------------------------
## WHAT THE BOT DOES (SG-118). Read this before you measure anything against it.
##
## Until 2026-08-03 the bot did not move. The comment below the draft block said
## it "keeps moving" and the loop issued no movement input at all, so every
## balance verdict this rig ever produced — including SG-57's tempo half — was
## measured against a captain standing on the spawn point. She moves now, and
## because the next person will measure something against her, the policy is a
## published fact rather than an implementation detail:
##
## She STEERS, analog, through the real input map (`Input.action_press` with a
## strength, read by `Input.get_vector` inside `player._physics_process` — the
## same path a keyboard takes; `input_direction` is a local and cannot be set).
## Her policy is one preferred band: she holds `BAND` = 210 units from the
## NEAREST enemy, which is `SkyGearData.CLOSE.range`, the radius the captain's
## PRESSURE gauge fills inside. Beyond `BAND` she closes; inside 0.55·BAND she
## backs off; in the band she CIRCLE-STRAFES rather than standing, so she is
## moving whenever there is anything to fight. She steers off a deck wall she is
## within 140 units of, and she steps OUT of a fire field she is standing in
## (weighted 2x) — but she does not path around fire she is not standing in.
## That asymmetry is deliberate and it is the honest read of "competent, not
## optimal": a real player leaves a pool they are caught in and does not plan a
## route around one they are clear of. She DASHES only defensively — when
## something is inside 90 units and a charge is up — through `_try_dash`, not
## through a synthesized keypress, because `is_action_just_pressed` is keyed to
## engine frames this loop does not run. Dash i-frames are therefore rare and
## reactive rather than a constant background immunity, which matters for
## anything measuring how often she is hittable (SG-117).
##
## She still never repairs, never shoves a crate and never retreats from a wave
## she is losing. Those are the remaining bot facts and they are the first thing
## to suspect when a result surprises you.
##
## AND SHE IS STEPPED BY THIS LOOP ALONE NOW, which is the other half of SG-118.
## `game.set_process(false)` never reached the captain — she is a separate node
## and the engine went on calling her `_physics_process` on every real frame the
## loop awaited, with whatever delta the machine produced. She is disabled and
## hand-stepped like the enemies, and `Engine.physics_ticks_per_second` is
## pinned to 20 so that `move_and_slide()`'s internal
## `get_physics_process_delta_time()` is exactly the 0.05 this loop hands out —
## otherwise she would integrate velocity on 0.05 and commit ground on 1/60 and
## travel at a third of her own speed. The old note below claiming "the crew and
## the cannons are separate nodes" was wrong on inspection: `enemy.gd` and
## `player.gd` are the only two scripts in `scripts/` that define
## `_physics_process`, and the crew and cannons are stepped inside
## `game._process`. The PROPS were leaking the same way and are hand-stepped too
## — see the note at that loop; a lit keg's fuse was burning on the engine clock
## and a keg is 26 damage.
##
## IT IS STILL NOT DETERMINISTIC, AND THIS FILE WILL NOT CLAIM OTHERWISE. Two
## real contamination sources are gone and the same seed still comes back
## different: BAL1's damage-taken over three invocations of the repaired rig was
## 180 / 170 / 221. The remaining source is one level below the scene tree — the
## captain is a `CharacterBody2D` and `move_and_slide()` queries the PHYSICS
## SPACE, whose body transforms are synced by the physics server on ITS tick,
## not on this loop's hand-step, so what she collides with depends on how the
## awaited frames fell. Chasing that means driving `PhysicsServer2D` by hand and
## it is a project rather than a fix.
##
## SO: THIS RIG REPORTS A DISTRIBUTION, NEVER A RUN. Per STATUS's fifth failure
## mode, a tool that reports a difference must first report its own noise floor.
## This one's floor is NOT zero, so it is not entitled to call a small
## difference a result: run `tools/balance_ab.gd`, which runs both arms many
## times over and prints the floor beside the effect, and disbelieve anything
## that does not clear it.
## ---------------------------------------------------------------------------
func _initialize() -> void: call_deferred("_run")

## THE BOT (SG-118) — its policy, its band and its dash rule live in
## `tools/bot.gd`, which the harness drives directly, so the thing under test
## and the thing that produces these numbers are the same code.
const BotScript := preload("res://tools/bot.gd")
var bot := BotScript.new()

const SEEDS := ["BAL1", "BAL2", "BAL3", "BAL4", "BAL5", "BAL6"]

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var count: int = int(args[0]) if args.size() > 0 else 3
	var heat: int = int(args[1]) if args.size() > 1 else 0
	var vow: String = str(args[2]) if args.size() > 2 else ""
	## REPS (SG-118, fourth argument): play the whole seed list this many times.
	## The rig is not deterministic — see the header — so the seed list is a
	## sample, not a measurement, and a comparison needs the sample to be big
	## enough that the floor is smaller than the effect. Repeating fixed seeds is
	## the right way to grow it: the seeds stay comparable between arms while the
	## residual engine noise averages down.
	var reps: int = maxi(1, int(args[3])) if args.size() > 3 else 1
	if vow != "" and not SkyGearWorkshop.ARTICLES.has(vow):
		print("  no such article: %s — the seals are %s" % [vow,
			", ".join(SkyGearWorkshop.ARTICLES.keys())])
		quit(1)
		return
	print("  HEAT %d · %s%s" % [heat, str(SkyGearWorkshop.HEAT[
		clampi(heat, 0, SkyGearWorkshop.HEAT.size() - 1)].name),
		"  ·  ARTICLE %s" % vow if vow != "" else ""])
	## The tempo lever (SG-57): set SKYGEAR_TEMPO_FLAT in the environment and
	## every wave deals STEADY — today's rhythm exactly. Printed so a recorded
	## number can never be ambiguous about which rhythm produced it.
	print("  TEMPO %s" % ("FLAT (pinned STEADY)"
		if OS.get_environment("SKYGEAR_TEMPO_FLAT") != "" else "live"))
	## SG-118: the hand-step and the physics step must be the same number, or the
	## captain integrates velocity on one clock and commits ground on another.
	Engine.physics_ticks_per_second = 20
	print("  BOT   steers to a %.0f-unit band, strafes in it, leaves fire, dashes under %.0f"
		% [BotScript.BAND, BotScript.DASH_AT])
	var ally_share := 0.0
	var player_share := 0.0
	var waves_reached := 0.0
	var wins := 0
	var results: Array = []
	for rep in reps:
		for i in mini(count, SEEDS.size()):
			var r := await _one(SEEDS[i], heat, vow)
			results.append(r)
			ally_share += float(r.ally)
			player_share += float(r.player)
			waves_reached += float(r.wave)
			wins += 1 if bool(r.won) else 0
			print("  %-6s%-4s wave %2d %-10s  player %3.0f%%  allies %3.0f%%  passive %2.0f%%  vents %2d  close %2.0f%%  far %2.0f%%  taken %4.0f  wave-sd %5.1f"
				% [SEEDS[i], "" if reps == 1 else "#%d" % (rep + 1),
					int(r.wave), "HELD" if bool(r.won) else "lost",
					float(r.player), float(r.ally), float(r.passive), int(r.vents),
					float(r.close), float(r.far), float(r.taken), float(r.taken_sd)])
	var n := float(results.size())
	print("")
	print("  across %d runs: %d held, average wave %.1f" % [int(n), wins, waves_reached / n])
	print("  player %.0f%%   allies %.0f%%" % [player_share / n, ally_share / n])
	## Damage-taken, for the tempo kill-test (SG-57): the mean, the across-run
	## spread, and the mean WITHIN-run per-wave spread — §2.2 asks whether
	## variance within waves shifts between rhythms, so all three are printed.
	var taken_sum := 0.0
	var wave_sd_sum := 0.0
	for r in results:
		taken_sum += float(r.taken)
		wave_sd_sum += float(r.taken_sd)
	var taken_mean := taken_sum / n
	var taken_var := 0.0
	for r in results:
		taken_var += pow(float(r.taken) - taken_mean, 2.0)
	var taken_sd := sqrt(taken_var / maxf(1.0, n - 1.0))
	print("  damage taken: mean %.0f  across-run sd %.0f  mean within-run wave-sd %.1f"
		% [taken_mean, taken_sd, wave_sd_sum / n])
	## ONE MACHINE-READABLE LINE (SG-118), so an A/B across two builds does not
	## have to scrape the prose above it — and, more to the point, so the numbers
	## that reach NEEDS_ALEX are the numbers the rig printed rather than numbers
	## somebody retyped. `taken` values are emitted individually because a mean
	## with no sample behind it cannot be re-tested by the next person.
	var taken_list := PackedStringArray()
	for r in results:
		taken_list.append("%.1f" % float(r.taken))
	print("SAMPLES n=%d held=%d wave_mean=%.3f taken_mean=%.3f taken_sd=%.3f taken=%s"
		% [int(n), wins, waves_reached / n, taken_mean, taken_sd,
			",".join(taken_list)])
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
	## AND THE CAPTAIN, which the two lines above never reached (SG-118). She is
	## her own node; `set_process(false)` on the game does not descend. So the
	## engine called her `_physics_process` on every real frame this loop awaited,
	## on top of the hand-steps, with a machine-dependent delta — which is most of
	## what the "still not deterministic" note below was describing. Enemies were
	## already handled this way inside the loop; she was not.
	game.player.set_physics_process(false)
	game.player.set_process(false)
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
	## is nearest, holds the 210-unit pressure band and strafes inside it, leaves
	## a fire pool she is standing in, dashes only to break contact. The full
	## policy — and what she still does NOT do — is documented at the top of this
	## file, because things get measured against it (SG-118).
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
		## STEER FIRST, so the input she acts on this tick is the one that matches
		## the deck she is about to be stepped through.
		bot.steer(game)
		game._process(0.05)
		for e in game.get_tree().get_nodes_in_group("enemies"):
			if is_instance_valid(e):
				## Hand-stepped, so the engine must not step them too.
				e.set_physics_process(false)
				e._physics_process(0.05)
		## AND THE PROPS (SG-118). `prop.gd:_process` counts down `fuse_left` — a
		## lit keg's 0.45 s fuse — and nothing here had ever disabled or stepped
		## it, so the fuse burned on the ENGINE's clock while everything around it
		## burned on this loop's 0.05. Whether a keg detonated, and how far the
		## captain had walked when it did, was therefore a function of how long
		## the awaited frames happened to take. A keg is 26 damage inside 192
		## units — comparable to a whole run's damage-taken total — which is most
		## of why the same seed came back with wildly different numbers.
		for p in game.get_tree().get_nodes_in_group("props"):
			if is_instance_valid(p):
				p.set_process(false)
				p._process(0.05)
		## AND THE CAPTAIN, hand-stepped like the enemies (SG-118). Without this
		## she never reads the input above at all: movement lives in
		## `_physics_process`, which this loop had disabled on nothing and called
		## on nothing, leaving her on the spawn point for the whole run.
		if is_instance_valid(game.player):
			game.player._physics_process(0.05)
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
	## Damage taken, total and the within-run spread ACROSS waves — what the
	## tempo kill-test (SG-57, ENEMY-VARIETY-DESIGN §2.2) reads: does the rhythm
	## move how the punishment clusters, wave to wave?
	var taken_values: Array = []
	for w in range(1, game.wave + 1):
		taken_values.append(float(tel.taken_by_wave.get(w, 0.0)))
	var taken_mean := 0.0
	for v in taken_values:
		taken_mean += float(v)
	taken_mean /= maxf(1.0, float(taken_values.size()))
	var taken_spread := 0.0
	for v in taken_values:
		taken_spread += pow(float(v) - taken_mean, 2.0)
	taken_spread = sqrt(taken_spread / maxf(1.0, float(taken_values.size() - 1)))
	var out := {
		"wave": game.wave,
		"won": game.state_name == "VICTORY",
		"taken": float(tel.taken),
		"taken_sd": taken_spread,
		"player": player_dmg / total * 100.0,
		"ally": float(tel.allies.damage) / total * 100.0,
		"deck": float(tel.deck.damage) / total * 100.0,
		"vents": int(tel.vents),
		"close": float(seconds.close) / lived * 100.0,
		"far": float(seconds.far) / lived * 100.0,
		"passive": passive_dmg / total * 100.0,
	}
	## Held keys do not belong to the next seed. `Input` is a singleton and a
	## press left down here would open the following run mid-stride.
	bot.release()
	game.queue_free()
	await process_frame
	return out
