extends SceneTree
## THE WAVE-12 SEGMENT, MEASURED DIRECTLY (SG-146).
##
## WHY THIS EXISTS AND WHY `tools/balance.gd` COULD NOT DO IT. `balance.gd`
## reports a WHOLE-RUN mean. The Colossus is one wave in twelve, and SG-119
## already paid for that mistake: the Colossus arc change came back -1.0% on
## whole-run damage-taken at n=120, and `bal_stat.gd`'s own price list says
## resolving 1% on that spread costs ~20,000 runs per arm — about 61 hours. The
## row's durable argument was not "below the floor", it was **a whole-run mean is
## the wrong instrument for a change that touches one twelfth of the run**.
##
## So this tool measures the twelfth directly. Everything it reports is scoped to
## wave 12 and to the Colossus himself:
##
##   ttk      seconds of SIM time between the frame the BOSS node is instantiated
##            and the frame it reports `dead` — the fight length, which is the
##            statistic an HP change is aimed at
##   taken    `tel.taken_by_wave[12]` — damage the captain took during wave 12
##            alone, not across the run
##   boiler   Boiler HP lost between the start of wave 12 and its end — the
##            direct test of "ignoring him has a price", which is ~0 today
##   dur      wall of wave 12 in sim seconds, boss or no boss
##
## AND IT REPORTS n TWICE, WHICH IS THE POINT. A run that dies on wave 9 has no
## wave 12 in it, so the denominator for every statistic above is REACHED, not
## RUNS. Reporting a wave-12 mean over runs that never reached wave 12 would be
## the SG-125 error with a division sign in front of it. Both counts print.
##
## The stepping discipline is `balance.gd`'s, line for line, and deliberately so
## — the hand-stepped game, the hand-stepped captain, the hand-stepped enemies,
## the hand-stepped props, `Engine.physics_ticks_per_second = 20`, and the bot
## from `tools/bot.gd` rather than a second policy written here. A probe that
## played a different game from the rig it sits beside would be a third answer to
## a question that already has two.
##
## IT IS NOT DETERMINISTIC EITHER, for exactly the reason `balance.gd` documents:
## `move_and_slide()` queries a physics space the server syncs on its own tick.
## So this prints a DISTRIBUTION, with the spread it just measured and the
## smallest effect that spread could have established at the n in front of it
## (`SkyGearBalStat.resolvable_at`). Read that line before writing a number down.
##
##   godot --path . --headless --script tools/boss_probe.gd
##   godot --path . --headless --script tools/boss_probe.gd -- 6 0 10
##                                                             ^ ^ ^
##                                                     seeds --' | '-- reps
##                                                            heat
##   godot --path . --headless --script tools/boss_probe.gd -- 6 0 10 BOSSB
##                                                                     ^ seed salt,
##   so several processes can be run in parallel on distinct seed families and
##   their `SAMPLES` lines pooled.

const BotScript := preload("res://tools/bot.gd")
var bot := BotScript.new()

const SEEDS := ["BAL1", "BAL2", "BAL3", "BAL4", "BAL5", "BAL6"]

## The wave the Colossus is on. Read from the table rather than typed, so this
## tool cannot outlive a change to `WAVES` the way a hardcoded 12 would.
static func boss_wave() -> int:
	for i in SkyGearData.WAVES.size():
		if bool(SkyGearData.WAVES[i].get("boss", false)):
			return i + 1
	return -1


func _initialize() -> void: call_deferred("_run")


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var count: int = int(args[0]) if args.size() > 0 else 6
	var heat: int = int(args[1]) if args.size() > 1 else 0
	var reps: int = maxi(1, int(args[2])) if args.size() > 2 else 1
	var salt: String = str(args[3]) if args.size() > 3 else ""
	var bw := boss_wave()
	if bw < 0:
		print("  no wave in SkyGearData.WAVES carries `boss` — nothing to probe")
		quit(1)
		return
	Engine.physics_ticks_per_second = 20
	print("  BOSS PROBE · wave %d · HEAT %d · %d seeds x %d reps%s"
		% [bw, heat, mini(count, SEEDS.size()), reps,
			"  · salt %s" % salt if salt != "" else ""])
	print("  BOT   steers to a %.0f-unit band, strafes in it, leaves fire, dashes under %.0f"
		% [BotScript.BAND, BotScript.DASH_AT])
	print("  BOSS  hp %.0f base, x%.2f at wave %d = %.0f effective"
		% [float(SkyGearData.ENEMIES.BOSS.hp), 1.0 + 0.06 * float(bw - 1), bw,
			float(SkyGearData.ENEMIES.BOSS.hp) * (1.0 + 0.06 * float(bw - 1))])

	var rows: Array = []
	for rep in reps:
		for i in mini(count, SEEDS.size()):
			var r := await _one(salt + SEEDS[i], heat, bw)
			rows.append(r)
			print("  %-10s%-5s %s"
				% [salt + SEEDS[i], "" if reps == 1 else "#%d" % (rep + 1),
					("wave %2d — never reached %d" % [int(r.wave), bw])
						if not bool(r.reached) else
					("ttk %5.1fs  taken %4.0f (boss %3.0f)  boiler -%3.0f  dur %5.1fs  %s"
						% [float(r.ttk), float(r.taken), float(r.taken_boss),
							float(r.boiler),
							float(r.dur), "HELD" if bool(r.won) else "lost"])])

	var runs := rows.size()
	var reached: Array = []
	for r in rows:
		if bool(r.reached):
			reached.append(r)
	print("")
	print("  %d runs, %d reached wave %d (%.0f%%)"
		% [runs, reached.size(), bw, 100.0 * float(reached.size()) / maxf(1.0, float(runs))])
	if reached.is_empty():
		print("  NOTHING TO REPORT — no run reached the boss. This is not a null result.")
		quit(0)
		return
	_report("ttk (boss time-to-kill, s)", reached, "ttk")
	_report("taken during wave %d" % bw, reached, "taken")
	_report("  ...of that, BY THE BOSS", reached, "taken_boss")
	_report("  ...of that, by everything else", reached, "taken_other")
	_report("taken per second of wave %d" % bw, reached, "rate")
	_report("boiler HP lost in wave %d" % bw, reached, "boiler")
	_report("wave %d duration, s" % bw, reached, "dur")
	## Boss killed at all? A run can reach wave 12, lose, and never resolve him —
	## in which case its ttk is censored and the mean is biased DOWN by however
	## many of those there are. Print the count rather than hide it.
	var killed := 0
	for r in reached:
		if bool(r.boss_killed):
			killed += 1
	print("  the Colossus was killed in %d of %d wave-%d runs%s"
		% [killed, reached.size(), bw,
			"" if killed == reached.size()
			else "  <- ttk is CENSORED in the rest; read it as a lower bound"])
	## One machine-readable line per statistic, so a pooled analysis across
	## parallel processes never has to retype a number off the prose.
	for key in ["ttk", "taken", "taken_boss", "taken_other", "rate", "boiler", "dur"]:
		var vals := PackedStringArray()
		for r in reached:
			vals.append("%.2f" % float(r[key]))
		print("SAMPLES key=%s n=%d runs=%d reached=%d killed=%d v=%s"
			% [key, reached.size(), runs, reached.size(), killed, ",".join(vals)])
	quit(0)


## Mean, sd, and — always, per SG-128 — what this n could have established on
## the spread it just produced. A mean with no resolution beside it is the number
## that put "5/6" in one board row and "3/6" in another.
func _report(label: String, rows: Array, key: String) -> void:
	var n := rows.size()
	var sum := 0.0
	for r in rows:
		sum += float(r[key])
	var mean := sum / float(n)
	var var_ := 0.0
	for r in rows:
		var_ += pow(float(r[key]) - mean, 2.0)
	var sd := sqrt(var_ / maxf(1.0, float(n - 1)))
	var cv: float = sd / maxf(0.001, absf(mean))
	print("  %-28s mean %7.1f   sd %6.1f   CV %3.0f%%   THIS n RESOLVES %.0f%% OR LARGER"
		% [label, mean, sd, cv * 100.0,
			SkyGearBalStat.resolvable_at(n, cv) * 100.0])


func _one(seed_text: String, heat: int, bw: int) -> Dictionary:
	var game: SkyGearGame = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	game.workshop = SkyGearWorkshop.fresh(true)
	game.workshop.unlocked = true
	game.workshop.best_heat = SkyGearWorkshop.HEAT.size() - 1
	game.heat = heat
	game.set_process(false)
	game.set_physics_process(false)
	game.player.set_physics_process(false)
	game.player.set_process(false)
	if game.impact != null:
		game.impact.enabled = false
	game.set_seed_text(seed_text)
	game.begin_run()
	game.choose_draft(bot.draft_pick(game.draft_options))

	var steps := 0
	const DT := 0.05
	## Wave-12 bookkeeping. `-1` means "has not happened", which is why these are
	## ints of steps rather than floats of seconds: a float sentinel invites a
	## comparison against 0.0 that a real zero would satisfy.
	var in_wave := -1
	var wave12_start := -1
	var wave12_end := -1
	var boiler_at_12 := 0.0
	var boiler_low := 0.0
	var boss: SkyGearEnemy = null
	var boss_spawn := -1
	var boss_dead := -1
	while game.state_name == "PLAY" or game.state_name == "DRAFT":
		if game.state_name == "DRAFT":
			game.choose_draft(bot.draft_pick(game.draft_options))
		bot.steer(game)
		game._process(DT)
		for e in game.get_tree().get_nodes_in_group("enemies"):
			if is_instance_valid(e):
				e.set_physics_process(false)
				e._physics_process(DT)
		for p in game.get_tree().get_nodes_in_group("props"):
			if is_instance_valid(p):
				p.set_process(false)
				p._process(DT)
		if is_instance_valid(game.player):
			game.player._physics_process(DT)
		if steps % 4 == 0:
			var target: SkyGearEnemy = game.nearest_enemy(game.player.global_position, 900.0)
			if target != null:
				for slot in game.skills.size():
					if float(game.skills[slot].cooldown_left) <= 0.0:
						game.cast_skill(slot, target.global_position)
						break
		## --- the segment ---------------------------------------------------
		if game.wave != in_wave:
			if in_wave == bw and wave12_end < 0:
				wave12_end = steps
			in_wave = game.wave
			if in_wave == bw:
				wave12_start = steps
				boiler_at_12 = game.boiler_hp
				boiler_low = game.boiler_hp
		if in_wave == bw:
			boiler_low = minf(boiler_low, game.boiler_hp)
			if boss == null:
				for e in game.get_tree().get_nodes_in_group("enemies"):
					if is_instance_valid(e) and str(e.kind) == "BOSS":
						boss = e
						boss_spawn = steps
						break
			elif boss_dead < 0 and (not is_instance_valid(boss) or bool(boss.dead)):
				boss_dead = steps
		steps += 1
		if steps % 200 == 0:
			await process_frame
		if steps > 40000:
			break
	if in_wave == bw and wave12_end < 0:
		wave12_end = steps

	var tel: Dictionary = game.tel
	var reached := wave12_start >= 0
	## TTK IS CENSORED, NOT ZERO, when the run ends with him alive. Reported as
	## the time he was actually engaged for, with `boss_killed` false beside it,
	## so a mean can be read for the bias it carries rather than silently
	## containing a fabricated short fight.
	var ttk := 0.0
	if boss_spawn >= 0:
		ttk = float((boss_dead if boss_dead >= 0 else steps) - boss_spawn) * DT
	## WHOSE DAMAGE IT WAS (SG-146). This is the statistic the whole probe is for:
	## a longer fight raises damage-taken all on its own, so "she took three times
	## as much" says nothing about whether the COLOSSUS became dangerous. Split by
	## the source string `damage_player` receives — his swings are tagged with his
	## `kind`, so "BOSS" is exactly his hand and nothing else's.
	var by_source: Dictionary = tel.taken_by_source.get(bw, {})
	var taken_total: float = float(tel.taken_by_wave.get(bw, 0.0))
	var taken_boss: float = float(by_source.get("BOSS", 0.0))
	var dur: float = float((wave12_end if wave12_end >= 0 else steps)
		- maxi(0, wave12_start)) * DT if reached else 0.0
	var out := {
		"wave": game.wave,
		"won": game.state_name == "VICTORY",
		"reached": reached,
		"boss_killed": boss_dead >= 0,
		"ttk": ttk,
		"taken": taken_total,
		"taken_boss": taken_boss,
		"taken_other": taken_total - taken_boss,
		"rate": taken_total / maxf(0.001, dur),
		"boiler": maxf(0.0, boiler_at_12 - boiler_low),
		"dur": dur,
	}
	bot.release()
	game.queue_free()
	await process_frame
	return out
