extends SceneTree
## THE OWNER'S SITUATION, MEASURED — a captain who STANDS STILL next to a melee
## boarder and swings (SG-156).
##
## WHY THIS EXISTS AND WHY `tools/boss_probe.gd` COULD NOT ANSWER IT. boss_probe
## reports what `tools/bot.gd` experiences, and the bot is a KITER: it steers to
## a 210-unit band (`BotScript.BAND`), strafes inside it, and dashes out under 90.
## The owner, on build 53, did the opposite — *"I just stood next to them as the
## captain and they died"* — and reported taking nothing from either heavy while
## the same wave-12 segment measured the Colossus dealing 123.4 damage. Two
## instruments, one game, opposite answers. They are not in conflict: they are
## measuring two different players, and only one of them is a person.
##
## So this probe pins the captain in place and reads the swing ledger directly.
##
## WHAT IT REPORTS, AND THE LEDGER IS THE POINT. A damage total answers "how
## much" and hides "why". Every swing the subject RESOLVES is recorded with the
## geometry it resolved on:
##
##   started    move -> windup transitions: swings the enemy COMMITTED to
##   resolved   windup -> recover transitions: swings that reached their strike
##   aimed      of those, the ones that were aimed at the captain at all
##   landed     of those, the ones `damage_player` actually credited
##   dist       centre-to-centre at the frame of the strike
##   off-axis   degrees between `attack_direction` and the captain's bearing
##
## `hits` is asked by CALLING `enemy._swing_hits()` rather than by re-deriving
## the wedge here. That is deliberate and it is the SG-119 lesson: two files
## computing one shape from one table is how the Colossus got a hitbox that
## disagreed with his own telegraph. A probe with its own copy of the geometry
## would be a third derivation and the first one to lie.
##
## ISOLATION. One subject, no wave. `spawn_queue` is cleared every step and every
## boarder that is not the subject is retired before it can act, so the number is
## the subject's hand and nothing else's. The subject is held alive so the window
## is a fixed wall-clock rather than a race between its health and the captain's
## damage — the question here is whether a swing CONNECTS, not who wins. Because
## it never dies and never leaves, the wave can never complete, so the run cannot
## advance out from under the measurement.
##
##   godot --path . --headless --script tools/melee_probe.gd
##   godot --path . --headless --script tools/melee_probe.gd -- 30 4 0
##                                                              ^  ^ ^
##                                                        seconds  | heat
##                                                              reps
##
## IT IS NOT DETERMINISTIC, for `tools/balance.gd`'s reason: `move_and_slide()`
## queries a physics space the server ticks on its own. Reps are pooled and the
## spread is printed beside every mean.

const BotScript := preload("res://tools/bot.gd")

## The two the owner named, and they are exactly the two that carry an arc gate.
const SUBJECTS := ["BOSS", "ARMORED"]

## STAND is the owner in a DUEL. ORBIT is `tools/bot.gd`'s band, reproduced here
## so the two readings sit in one table instead of in two tools that cannot be
## compared. CROWD is the owner in the game he actually played.
##
## CROWD EXISTS BECAUSE THE DUEL IS NOT HIS SITUATION. `player.gd::take_damage`
## grants 0.55 s of invulnerability on EVERY landed hit, whatever its size, and
## wave 12 puts gremlins (6 damage) and scrappers (12) on the deck beside the
## heavy. A cheap nibble therefore opens an i-frame window that the heavy's 26-
## or 34-damage swing can land inside and be thrown away by. In a duel there is
## nobody to open that window, so STAND cannot see the effect at all — which is
## exactly why measuring the duel alone would have answered the wrong question.
##
## LETHAL is the one that turned out to matter, and it is the only arm in which
## the subject can DIE. The three above hold it alive on purpose, to ask whether
## a swing CONNECTS; every one of them answers yes, 45 of 45, so nothing about
## the hitbox, the arc gate, the immunity rule or the i-frame economy is broken.
## But the owner did not say the heavies missed him. He said *"I just stood next
## to them as the captain and THEY DIED"* — and a swing that never resolves
## cannot miss, because it never happens. LETHAL gives the subject its real
## health at its real wave, against a deck drafted over eleven real waves, and
## counts the swings it lands in its entire life.
const MODES := ["stand", "crowd", "orbit", "lethal"]

const DT := 0.05


func _initialize() -> void: call_deferred("_run")


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var seconds: float = float(args[0]) if args.size() > 0 else 30.0
	var reps: int = maxi(1, int(args[1])) if args.size() > 1 else 4
	var heat: int = int(args[2]) if args.size() > 2 else 0
	Engine.physics_ticks_per_second = 20
	## AND INTO A PHYSICS FRAME BEFORE ANYTHING IS STEPPED (board SG-190). This
	## line is not housekeeping; without it every number this tool has ever
	## printed was taken with the boarders walking at a speed nobody chose.
	##
	## `CharacterBody2D.move_and_slide()` does not integrate against the delta you
	## hand `_physics_process`. It asks `Engine.is_in_physics_frame()` and takes
	## `get_physics_process_delta_time()` if the answer is yes and
	## `get_process_delta_time()` — THE IDLE FRAME'S WALL-CLOCK DURATION — if it is
	## no. A `_run` reached by `call_deferred` from `_initialize` has never been
	## inside a physics frame: measured, `get_physics_process_delta_time()` returns
	## 0.0000 there and `is_in_physics_frame()` is false. So the line above set a
	## clock that nothing was reading, and every boarder moved by the wall clock —
	## 0.0069 s on the machine this was found on, against the 0.05 the loop counts,
	## and DIFFERENT on a busier one. That is the "still not deterministic"
	## residual this file's own header blames on the physics server, most of it,
	## and it is a rig measuring a game nobody plays.
	await physics_frame
	print("  MELEE PROBE · %.0fs window · %d reps · HEAT %d" % [seconds, reps, heat])
	print("  STAND: the captain is pinned and never moves. She still swings —")
	print("         `_process_basic_attack` needs no input, which is the owner's")
	print("         Ember Cleave at 40%% share with 141 kills and no casts.")
	print("  ORBIT: `tools/bot.gd` steers, at its %.0f-unit band." % BotScript.BAND)
	print("")

	var rows: Array = []
	for kind in SUBJECTS:
		for mode in MODES:
			for rep in reps:
				var r := await _one(kind, mode, seconds, heat, "MEL%d" % rep)
				r["kind"] = kind
				r["mode"] = mode
				rows.append(r)
			_summarise(kind, mode, rows)
	print("")
	_lethal_report(rows)
	print("")
	_verdict(rows)
	quit(0)


func _summarise(kind: String, mode: String, rows: Array) -> void:
	var mine: Array = []
	for r in rows:
		if str(r.get("kind", "")) == kind and str(r.get("mode", "")) == mode:
			mine.append(r)
	var started := 0
	var resolved := 0
	var aimed := 0
	var landed := 0
	var swallowed := 0
	var elsewhere := 0
	var taken := 0.0
	var dists := 0.0
	var offaxis := 0.0
	## READ THROUGH `.get()`, EVERY FIELD. A row that is missing a key must cost
	## this reader that row's contribution and nothing more; reading it as a
	## property raises, and a raise here aborts the whole summary — see the SG-166
	## note in `_one`.
	for r in mine:
		started += int(r.get("started", 0))
		resolved += int(r.get("resolved", 0))
		aimed += int(r.get("aimed", 0))
		landed += int(r.get("landed", 0))
		swallowed += int(r.get("swallowed", 0))
		elsewhere += int(r.get("elsewhere", 0))
		taken += float(r.get("taken", 0.0))
		dists += float(r.get("dist_sum", 0.0))
		offaxis += float(r.get("offaxis_sum", 0.0))
	var n := maxf(1.0, float(resolved))
	print("  %-8s %-6s  resolved %3d  aimed %3d  LANDED %3d  swallowed %3d  elsewhere %3d   taken %6.1f   dist %5.1f  off-axis %5.1f deg"
		% [kind, mode, resolved, aimed, landed, swallowed, elsewhere, taken, dists / n, offaxis / n])
	## THE WALK, UNDER THE SWING (SG-194). Printed for every arm and not only the
	## one with zeroes in it, because "he closed and missed" and "he never closed"
	## are the two explanations of the same empty ledger and they want opposite
	## fixes — the first is a hitbox or an arc, the second is a speed.
	var near := 1.0e9
	var dmean := 0.0
	var in_trip := 0.0
	var trip := 0.0
	var clock := 0.0
	for r in mine:
		near = minf(near, float(r.get("near", 1.0e9)))
		dmean += float(r.get("dist_mean", 0.0))
		in_trip += float(r.get("t_in_trip", 0.0))
		trip = float(r.get("trip", 0.0))
		clock += float(r.get("clock", 0.0))
	var runs := maxf(1.0, float(mine.size()))
	var window := 0.0
	for r in mine:
		window += float(r.get("seconds", 0.0))
	## `no sample` RATHER THAN `0.0000`, because they mean opposite things. The
	## identity is only sampled on frames where the subject was walking with room
	## around it, and in STAND and CROWD it is pressed against the captain for the
	## whole window — so those arms legitimately contribute no frames, and a
	## printed 0.0000 reads as the loudest possible failure of a check that was
	## never run. The arms that DO walk read 1.00.
	var q := clock / runs
	print("           %-6s  CLOSED to %5.0f at best (a swing trips at %.0f), mean gap %5.0f, %4.1f%% of the window inside it   [rig clock %s]"
		% ["", near, trip, dmean / runs, 100.0 * in_trip / maxf(0.001, window),
			"no sample — it never walked in the clear" if q <= 0.0001
			else ("%.4f" % q if absf(q - 1.0) <= 0.02
				else "%.4f REFUSED" % q)])
	for r in mine:
		if not str(r.get("note", "")).is_empty():
			print("        %s" % str(r.get("note", "")))


## THE LINE THE WHOLE PROBE IS FOR. Not "how much damage" — how many swings the
## enemy got to take AT ALL before it fell. An enemy that lands one swing in its
## entire life is not a difficulty problem with its hitbox; it is an enemy the
## player never has to engage with, which is what the owner described.
func _lethal_report(rows: Array) -> void:
	print("  --- LETHAL: what the enemy got to do before it died ---------------")
	for kind in SUBJECTS:
		var lives := 0
		var secs := 0.0
		var res := 0
		var land := 0
		var hurt := 0.0
		var pool := 0.0
		var subj := 0.0
		var wave := 0
		var secs_all := PackedFloat32Array()
		var hurt_all := PackedFloat32Array()
		for r in rows:
			if str(r.get("kind", "")) != kind or str(r.get("mode", "")) != "lethal" \
					or float(r.get("subject_hp", 0.0)) <= 0.0:
				continue
			lives += 1
			secs += float(r.get("seconds", 0.0))
			res += int(r.get("resolved", 0))
			land += int(r.get("landed", 0))
			## MEASURED, NOT DERIVED (SG-166). This line used to multiply the landed
			## swing count by a HARDCODED 26 or 34 — the two rows' `damage` fields,
			## typed here. That was the project's second failure mode in miniature:
			## two places holding one number, and the moment the Colossus gained a
			## damage source that is not a swing (the stomp), the derived total
			## silently reported only the half it knew the arithmetic for. It reads
			## `taken` now, which IS `tel.taken_by_source[wave][kind]` — every point
			## of damage credited to this boarder's hand by whatever means, summed by
			## the simulation itself.
			hurt += float(r.get("taken", 0.0))
			secs_all.append(float(r.get("seconds", 0.0)))
			hurt_all.append(float(r.get("taken", 0.0)))
			pool = float(r.get("pool", 0.0))
			subj = float(r.get("subject_hp", 0.0))
			wave = int(r.get("wave", 0))
		if lives == 0:
			print("  %-8s  no life measured" % kind)
			continue
		print("  %-8s  wave %2d · %.0f effective HP · against a captain with %.0f HP"
			% [kind, wave, subj, pool])
		print("  %-8s  LIVED %5.2fs (sd %4.2f, n=%d) on average, and in that whole life"
			% ["", secs / float(lives), _sd(secs_all), lives])
		print("  %-8s  it resolved %.1f swings and LANDED %.1f — and dealt %.0f damage"
			% ["", float(res) / float(lives), float(land) / float(lives),
				hurt / float(lives)])
		print("  %-8s  (sd %5.1f) BY ITS OWN HAND, %.0f%% of that captain's pool."
			% ["", _sd(hurt_all), hurt / float(lives) / maxf(1.0, pool) * 100.0])
		print("LETHAL kind=%s n=%d wave=%d subject_hp=%.0f pool=%.0f secs=%s taken=%s"
			% [kind, lives, wave, subj, pool,
				",".join(_fmt(secs_all)), ",".join(_fmt(hurt_all))])


func _sd(v: PackedFloat32Array) -> float:
	if v.size() < 2:
		return 0.0
	var m := 0.0
	for x in v:
		m += x
	m /= float(v.size())
	var s := 0.0
	for x in v:
		s += pow(x - m, 2.0)
	return sqrt(s / float(v.size() - 1))


## One machine-readable list per arm, for the same reason `boss_probe.gd` prints
## `SAMPLES`: a pooled analysis across parallel processes must never have to
## retype a number off the prose.
func _fmt(v: PackedFloat32Array) -> PackedStringArray:
	var out := PackedStringArray()
	for x in v:
		out.append("%.2f" % x)
	return out


func _verdict(rows: Array) -> void:
	print("  --- the comparison the owner's report turns on -------------------")
	print("  The owner stood still next to both of these and reported taking")
	print("  nothing. `seconds to kill` below is that claim's direct test: it is")
	print("  100 captain HP divided by the damage per second this arm measured.")
	for kind in SUBJECTS:
		for mode in MODES:
			var taken := 0.0
			var secs := 0.0
			var land := 0
			var res := 0
			for r in rows:
				if str(r.get("kind", "")) != kind or str(r.get("mode", "")) != mode:
					continue
				taken += float(r.get("taken", 0.0))
				secs += float(r.get("seconds", 0.0))
				land += int(r.get("landed", 0))
				res += int(r.get("resolved", 0))
			var dps: float = taken / maxf(0.001, secs)
			print("  %-8s %-6s  took %6.1f in %5.1fs = %5.2f dps  ->  a full captain falls in %5.1fs   (%d of %d resolved swings landed)"
				% [kind, mode, taken, secs, dps,
					100.0 / maxf(0.001, dps), land, res])


## The LAST wave this boarder appears on, read off `SkyGearData.WAVES`. Typing
## the number here would be a second copy of the schedule and the first to rot.
##
## LAST, NOT FIRST, and the difference decides whether the answer is the owner's.
## He met the furnace knight across a whole run and reported on it at the end;
## its FIRST appearance is wave 4, against a four-wave deck, and measuring there
## would flatter the enemy — it is the wave where its health is closest to the
## captain's output. The last appearance is the hardest version of the enemy AND
## the strongest version of the deck, which is the matchup the report is about.
func _home_wave(kind: String) -> int:
	var found := 1
	for i in SkyGearData.WAVES.size():
		for batch in SkyGearData.WAVES[i].batches:
			if str(batch[1]) == kind:
				found = i + 1
	return found


func _blank(note: String) -> Dictionary:
	return {"started": 0, "resolved": 0, "aimed": 0, "landed": 0, "swallowed": 0,
		"elsewhere": 0, "taken": 0.0, "seconds": 0.0, "dist_sum": 0.0,
		"pool": 0.0, "subject_hp": 0.0, "wave": 0,
		"offaxis_sum": 0.0, "note": note}


## The boss wave's non-boss roster, off the table. A typed list here would be a
## second copy of `SkyGearData.WAVES` and the first one to go stale.
func _company() -> Array:
	var out: Array = []
	for w in SkyGearData.WAVES:
		if not bool(w.get("boss", false)):
			continue
		for batch in w.batches:
			if str(batch[1]) == "BOSS":
				continue
			out.append([str(batch[1]), int(batch[2])])
	return out


## Damage this ONE boarder kind dealt the captain, summed over every wave the
## window touched. Keyed by wave and by source, so it is read back the same way.
func _by_hand(game: SkyGearGame, kind: String) -> float:
	var total := 0.0
	for wave_key in game.tel.taken_by_source:
		var by: Dictionary = game.tel.taken_by_source[wave_key]
		total += float(by.get(kind, 0.0))
	return total


func _one(kind: String, mode: String, seconds: float, heat: int, seed_text: String) -> Dictionary:
	var bot := BotScript.new()
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

	## LETHAL WARMS UP THROUGH THE REAL RUN FIRST. The other arms measure geometry,
	## which a wave-1 deck answers as well as a wave-12 one. Lifetime does not: it
	## is a race between the subject's health and the captain's damage, and BOTH
	## sides of that race are twelve waves of scaling and drafting away from where
	## `begin_run` leaves them. So this arm plays the game — the bot steering, the
	## drafts taken, the waves cleared — up to the wave the subject actually
	## belongs to, and only then pins the captain. A lifetime measured against a
	## starting deck would be the flattering number, not the owner's.
	if mode == "lethal":
		var target_wave := _home_wave(kind)
		var guard := 0
		while game.wave < target_wave and (game.state_name == "PLAY" or game.state_name == "DRAFT") and guard < 40000:
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
			if guard % 4 == 0:
				var t: SkyGearEnemy = game.nearest_enemy(game.player.global_position, 900.0)
				if t != null:
					for slot in game.skills.size():
						if float(game.skills[slot].cooldown_left) <= 0.0:
							game.cast_skill(slot, t.global_position)
							break
			guard += 1
			if guard % 200 == 0:
				await physics_frame
		if game.state_name != "PLAY" and game.state_name != "DRAFT":
			## READ BEFORE THE FREE (SG-166). This line used to format `game.wave`
			## AFTER `queue_free()` and an awaited frame, so the run that failed to
			## reach the subject's wave — which is ~13% of them at Heat 0 — raised
			## `Invalid access to property or key 'wave' on a base object of type
			## 'previously freed'`, `_blank()` was never constructed, and the row
			## appended to `rows` was malformed. **One such row silenced three whole
			## reports**: `_summarise`, `_lethal_report` and `_verdict` all iterate
			## every row, a raise aborts the function it is in, and the LETHAL report
			## — the one this probe exists for — printed nothing at all for EITHER
			## subject. That is STATUS's "a check that RAISES instead of failing takes
			## the rest of its function's checks with it", in a measuring tool rather
			## than in the harness, and it is why the readers below use `.get()`.
			var died_on := int(game.wave)
			bot.release()
			game.queue_free()
			await physics_frame
			return _blank("died on wave %d before reaching wave %d" % [died_on, target_wave])

	## THE CAPTAIN'S SPOT: lane 1's centre line, mid-deck, well clear of the rail
	## and of the Boiler, so nothing about the position is special.
	var anchor := Vector2(0.0, 200.0)
	game.player.global_position = anchor
	game.player.velocity = Vector2.ZERO

	## THE SUBJECT, placed where the owner was: next to her. 100 units is inside
	## every melee row's trip range and outside every body radius, so the enemy
	## begins already committed rather than walking in.
	game.spawn_queue.clear()
	game.spawn_enemy(kind, 1)
	var subject: SkyGearEnemy = null
	for e in game.get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and str(e.kind) == kind:
			subject = e
	if subject == null:
		bot.release()
		game.queue_free()
		await physics_frame
		return {"started": 0, "resolved": 0, "aimed": 0, "landed": 0, "taken": 0.0,
			"swallowed": 0, "elsewhere": 0, "seconds": 0.0,
			"pool": 0.0, "subject_hp": 0.0, "wave": 0,
			"dist_sum": 0.0, "offaxis_sum": 0.0, "note": "no subject spawned"}
	subject.global_position = anchor + Vector2(0.0, -100.0)
	## HELD ALIVE — EXCEPT IN LETHAL, where the race is the measurement. Not
	## invulnerable even here: `can_be_hit()` stays exactly as shipped, so the
	## captain's swings land, stagger and burn as they always do. Only the pool is
	## bottomless, so the window is a clock rather than a race.
	if mode != "lethal":
		subject.max_hp = 1.0e9
		subject.hp = 1.0e9

	var subject_pool := float(subject.max_hp)
	var wave_at := int(game.wave)
	var started := 0
	var resolved := 0
	var aimed := 0
	var landed := 0
	var swallowed := 0
	var elsewhere := 0
	var dist_sum := 0.0
	var offaxis_sum := 0.0
	## THE CLOSING CENSUS (SG-194) and the rig's own floor. `trip` is the distance
	## at which this subject's `move` state flips to `windup` — `attack_range` plus
	## the captain's 17-unit body, read off the same table the simulation reads,
	## because a swing that never trips is the outcome under investigation and a
	## typed constant here would be the third derivation of it.
	var trip: float = float(SkyGearData.ENEMIES[kind].attack_range) + 17.0
	var near := 1.0e9
	var dist_all := 0.0
	var dist_frames := 0
	var t_in_trip := 0.0
	var move_ground := 0.0
	var move_expect := 0.0
	var steps := 0
	var total := int(seconds / DT)

	while steps < total and game.state_name == "PLAY":
		## ISOLATION, re-established every step: no queue, no company. CROWD keeps
		## a company instead, and it is WAVE 12'S OWN — `SkyGearData.WAVES`' boss
		## row is the Colossus plus 4 SWARM and 3 SCRAPPER, read off the table
		## rather than typed, and held topped up as the captain kills them so the
		## pressure is sustained rather than a single opening volley. That is the
		## deck the owner was standing on when he said the heavies felt harmless.
		## LETHAL KEEPS THE COMPANY TOO, and that is the conservative choice: the
		## adds soak part of the captain's output, so the heavy lives LONGER here
		## than it would in a clean duel. A lifetime measured with the deck cleared
		## would exaggerate the very finding this arm exists to establish.
		game.spawn_queue.clear()
		if mode == "crowd" or mode == "lethal":
			for entry in _company():
				var live := 0
				for e in game.get_tree().get_nodes_in_group("enemies"):
					if is_instance_valid(e) and not bool(e.dead) and str(e.kind) == str(entry[0]):
						live += 1
				for i in maxi(0, int(entry[1]) - live):
					game.spawn_enemy(str(entry[0]), i % 3)
		else:
			for e in game.get_tree().get_nodes_in_group("enemies"):
				if is_instance_valid(e) and e != subject and not bool(e.dead):
					e.dead = true
					e.queue_free()
		if mode != "lethal":
			subject.hp = 1.0e9
		## THE CAPTAIN IS TOPPED UP AT THE TOP OF EVERY STEP, AND ONLY HER POOL
		## IS. `invulnerability_left` is never touched, so the 0.55 s window every
		## landed hit grants is exactly the shipped one and the ledger below stays
		## honest. No melee row deals a full captain's health in one swing (26 and
		## 34 against 100), so refilling BEFORE the enemy acts means she cannot
		## reach zero and the window is a fixed clock rather than a race — the
		## same reason the subject is held alive. Lethality is not lost by this,
		## it is DERIVED, in the seconds-to-kill line of the verdict.
		game.player.hp = game.player.max_hp

		## ORBIT is the only arm that moves. STAND and CROWD are both the owner —
		## pinned, swinging, differing ONLY in whether he has company — because a
		## crowd arm that also steered would change two variables at once and was
		## the first draft's mistake: it reproduced ORBIT's numbers exactly.
		if mode == "orbit":
			bot.steer(game)
		else:
			bot.release()
			game.player.global_position = anchor
			game.player.velocity = Vector2.ZERO

		## SAMPLED BEFORE THE STEP, because the strike resolves at the top of the
		## enemy's own `_physics_process` — against the position and the
		## `attack_direction` standing at this instant, before `move_and_slide`
		## touches either. Reading them afterwards would report the recovery frame.
		var pre_state := str(subject.state)
		var pre_pos: Vector2 = subject.global_position
		var to_player: Vector2 = game.player.global_position - subject.global_position
		var pre_dist := to_player.length()
		var pre_reach: float = subject.swing_wedge_reach() + 17.0
		var pre_hits: bool = subject._swing_hits(game.player.global_position, pre_reach, 17.0)
		var pre_off := rad_to_deg(absf(subject.attack_direction.angle_to(to_player))) if pre_dist > 0.001 else 0.0
		## BY HIS HAND, NOT BY THE RUN'S. `tel.taken` is every source there is —
		## the first draft of this probe read it and reported an ARMORED arm that
		## took 52 damage across ZERO resolved swings, which is the fire fields and
		## the retiring boarders, not the knight. `taken_by_source` is keyed by the
		## string `enemy.gd` passes, which is the boarder's `kind`, so this is the
		## subject's hand and nothing else's (the same split SG-146 added).
		var pre_taken := _by_hand(game, kind)
		var pre_invuln := float(game.player.invulnerability_left)

		game._process(DT)
		## THE SUBJECT SWINGS FIRST, and in CROWD that is the CONSERVATIVE order:
		## it gives his swing the best possible chance at a clean i-frame window
		## before the company gets to open one this step. Any swallowing measured
		## under this order is a floor, not an artefact of stepping him last.
		if is_instance_valid(subject):
			subject.set_physics_process(false)
			subject._physics_process(DT)
		if mode == "crowd" or mode == "lethal":
			for e in game.get_tree().get_nodes_in_group("enemies"):
				if is_instance_valid(e) and e != subject and not bool(e.dead):
					e.set_physics_process(false)
					e._physics_process(DT)
		for p in game.get_tree().get_nodes_in_group("props"):
			if is_instance_valid(p):
				p.set_process(false)
				p._process(DT)
		if is_instance_valid(game.player):
			game.player._physics_process(DT)
		if not is_instance_valid(subject) or bool(subject.dead):
			break

		var post_state := str(subject.state)
		## --- THE CLOSING CENSUS (board SG-194) ------------------------------
		## The owner: *"Furnace knights dont seem to do any damage to me."* The
		## ledger above can only describe swings that HAPPENED, and against a
		## captain who moves the knight's answer turned out to be that none do —
		## a column of zeroes that says nothing about why. These four numbers are
		## the why, and they are about the WALK rather than the swing: how close
		## he ever got, how close he was on average, and how much of the window he
		## spent inside the distance at which a swing would trip at all.
		near = minf(near, pre_dist)
		dist_all += pre_dist
		dist_frames += 1
		if pre_dist <= trip:
			t_in_trip += DT
		## AND THE RIG'S OWN FLOOR, WHICH THIS FILE DID NOT HAVE (SG-190, and one
		## frame deeper — see `tools/crew_probe.gd`). SG-190 put an
		## `await physics_frame` at the top of every hand-stepping rig so that
		## `move_and_slide` would integrate the PHYSICS delta rather than an idle
		## one. What it did not do is check that the physics delta is the `DT` this
		## loop counts: measured in `crew_probe`, a tree can report
		## `physics_ticks_per_second` 20 and `is_in_physics_frame()` true while
		## `get_physics_process_delta_time()` still returns 1/60. A rig that asks
		## for a clock and is told it has one is not a rig that has one. So the
		## identity is measured here and printed above the result: after
		## `move_and_slide`, the boarder's `velocity` is back to the `walk` it was
		## moved with (the SG-62 line), so the ground it covered this step must be
		## exactly `|velocity| * DT`.
		##
		## AND THE SAMPLE IS RESTRICTED TO A BOARDER WITH ROOM TO WALK, which the
		## first draft of this line was not and which made it unreadable. In STAND
		## the subject is pressed against the captain's body: `move_and_slide`
		## slides it along her collider, so it covers less ground than `|v| * DT`
		## for a reason that has nothing to do with any clock, and the quotient
		## came back **0.33** — which is exactly the ratio a genuine clock fault
		## would produce, and would have been read as one. `trip + 40` is clear of
		## every body in the fixture. In the arms where the subject actually walks
		## the identity reads **1.00**, so `melee_probe`'s 0.05 step and the delta
		## `move_and_slide` integrates ARE one clock — which is the thing SG-190
		## fixed the first half of and nothing had ever checked the second half of.
		if pre_state == "move" and post_state == "move" and pre_dist > trip + 40.0:
			move_ground += pre_pos.distance_to(subject.global_position)
			move_expect += subject.velocity.length() * DT
		if pre_state == "move" and post_state == "windup":
			started += 1
		if pre_state == "windup" and post_state == "recover":
			resolved += 1
			dist_sum += pre_dist
			offaxis_sum += pre_off
			## WAS IT EVEN POINTED AT HER? `enemy.gd`'s victim chain is if/elif and
			## only the captain branch tests her, so a swing aimed at a cannon or a
			## crewman can never hit her however close she stands. Counting that as
			## a MISS would blame the wedge for a decision made three lines earlier.
			##
			## THIS LINE USED TO BE `chases_captain() and pre_dist < 280.0` — the
			## victim chain's first branch, re-derived here off a literal 280 typed
			## in a second file (board SG-193). It agreed with the simulation right
			## up until the day somebody moved the radius, which is the whole of
			## STATUS's second failure mode. `enemy.last_swing` is written BY the
			## resolve, at the resolve, out of the answer the resolve used — so it
			## is not a better copy of the rule, it is the rule's own record.
			if not subject.last_swing.is_empty() and str(subject.last_swing.aimed) == "player":
				aimed += 1
			if _by_hand(game, kind) > pre_taken:
				landed += 1
			elif pre_hits and pre_invuln > 0.0:
				## THE SWING CONNECTED AND THE GAME THREW IT AWAY. Geometry said
				## hit — `_swing_hits`, the shipped function, asked at the frame it
				## resolved — and no damage was credited, because an i-frame opened
				## by some other hit was still running. This is the one outcome a
				## damage total cannot distinguish from a miss, and the two want
				## opposite fixes: a miss is a hitbox question, this is an economy
				## question about what a 6-damage nibble is allowed to buy.
				swallowed += 1
			elif pre_hits:
				## Connected, not swallowed, still no damage: the victim chain took
				## it (if/elif — a swing aimed at a cannon cannot also hit her).
				elsewhere += 1
		steps += 1
		if steps % 200 == 0:
			await physics_frame

	var note := ""
	if steps < total:
		note = "window ended early at %.1fs — state %s" % [float(steps) * DT, game.state_name]
	var out := {
		"pool": float(game.player.max_hp), "subject_hp": subject_pool, "wave": wave_at,
		"started": started, "resolved": resolved, "aimed": aimed, "landed": landed,
		"swallowed": swallowed, "elsewhere": elsewhere,
		"taken": _by_hand(game, kind), "dist_sum": dist_sum, "offaxis_sum": offaxis_sum,
		"seconds": float(steps) * DT, "note": note,
		"trip": trip, "near": near, "dist_mean": dist_all / maxf(1.0, float(dist_frames)),
		"t_in_trip": t_in_trip, "clock": move_ground / maxf(0.001, move_expect),
		"move_secs": move_expect,
	}
	bot.release()
	game.queue_free()
	await physics_frame
	return out
