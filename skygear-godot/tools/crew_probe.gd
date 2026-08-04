extends SceneTree
## DO ENEMIES FIGHT AND KILL CREW MEMBERS? (board SG-193)
##
## The owner, after build 62: *"Do enemies fight and kill crew members? Furnace
## knights dont seem to do any damage to me or attack crew members."*
##
## WHY A WHOLE TOOL AND NOT A COLUMN ON `tools/balance.gd`. The rig already
## prints `crew 6%` — the share of the run's damage the sailors DEAL. Nothing in
## this repository has ever recorded a single point of damage they TAKE. So the
## owner's question was, up to now, unanswerable from any instrument we own, and
## the honest first move is to build the ledger rather than to reason from the
## code and tune. `hurt_crew` is the only place crew damage lands and it writes
## to nothing but the crewman's own `hp`, which is deleted from `game.crew` on
## the tick after he dies — a dead sailor leaves no trace at all, which is why a
## death count cannot be taken at the end of a run and has to be watched for.
##
## WHAT IT RECORDS, AND THE SWING LEDGER IS THE POINT. "How much damage did the
## crew take" answers how much and hides who was even aiming at them. Every
## melee swing every boarder RESOLVES is filed twice — by what it was AIMED at
## and by what it LANDED on — off `enemy.last_swing`, which the simulation writes
## at the moment of the strike:
##
##   aimed     `enemy.victim()`'s answer on the frame the swing resolved
##   landed    the branch of the victim chain that actually paid out, or
##             SWALLOWED when the aimed swing connected with nothing
##
## `victim()` IS CALLED, NOT REIMPLEMENTED. That is SG-119's rule and the whole
## reason the chain was given a name in `enemy.gd` for this row: a probe holding
## its own copy of the priority order is a second derivation, and the copy is
## always the one that lies. Everything this file prints about who was targeted
## comes out of the simulation's own answer.
##
## AND THE STOMP IS COUNTED SEPARATELY, because it is not in the chain. Since
## SG-185 the Colossus's stomp asks `stomp_hits` of every body on the deck —
## captain, cannons, CREW and Boiler — with no priority order at all. It is the
## one attack in the game that reaches a crewman without asking the chain's
## permission, so folding it into the swing ledger would credit the chain with
## work the chain refused to do.
##
## THE TWO ARMS, AND THE SECOND ONE IS THE HYPOTHESIS UNDER TEST.
##
##   SHIPPED       the deck as it is played.
##   GUNS DOWN     the three lane cannons are destroyed at the first frame of
##                 every wave and stay destroyed.
##
## The reading this row was dispatched to confirm or refute is that the CANNON
## OUTRANKS THE CREW: a boarder only ever picks a crewman when the captain is
## beyond `CAPTAIN_NOTICE`, no live cannon is still ahead of it in its lane, and
## a hand is inside `CREW_NOTICE`. If that is right then GUNS DOWN is the arm in
## which crew targeting switches on, and the difference between the two arms is
## the size of the effect. If it is wrong the two arms read alike.
##
##   godot --path . --headless --script tools/crew_probe.gd
##   godot --path . --headless --script tools/crew_probe.gd -- 6 0
##                                                             ^ ^ heat
##                                                       seeds -'
##
## ---------------------------------------------------------------------------
## THE RIG REPORTS ITS OWN FLOOR FIRST, AND THAT FLOOR IS ZERO — STATUS's rule
## for the fifth failure mode, and `tools/lane_probe.gd`'s implementation of it.
##
## `CharacterBody2D.move_and_slide()` does not integrate against the delta handed
## to `_physics_process`; it asks `Engine.is_in_physics_frame()` and takes the
## IDLE frame's wall-clock duration if the answer is no (board SG-190, which is
## why every melee measurement taken before 2026-08-04 is suspect). So this file
## never awaits an idle frame, takes `DT` FROM the engine rather than declaring
## it at the engine, and — because a comment is not a check — verifies the walk
## it just measured: it accumulates ground covered and `|velocity| * DT` over
## every boarder frame that began and ended in the move state, and prints the
## quotient above the result. If those two clocks are not one clock it says
## REFUSED and exits 1 rather than printing a number.

const BotScript := preload("res://tools/bot.gd")

## TWELVE, NOT SIX. `tools/balance.gd` shipped with six for years and SG-128 is
## the row that costed it: at n=6 a held-count is worth +-40 points. The effects
## this file measures are enormous — a share that goes from a tenth of a percent
## to forty — so six would in fact have been enough for the headline, and that is
## exactly the reasoning SG-128 exists to refuse. The per-seed lines below are
## printed for the same reason: a mean with no spread under it is the shape of
## every number this repository has had to withdraw.
const SEEDS := ["CRW1", "CRW2", "CRW3", "CRW4", "CRW5", "CRW6",
	"CRW7", "CRW8", "CRW9", "CRW10", "CRW11", "CRW12"]
const ARMS := ["shipped", "gunsdown"]
const SPEED_TOLERANCE := 0.02

var bot := BotScript.new()
var DT := 0.05


func _initialize() -> void: call_deferred("_run")


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var count: int = clampi(int(args[0]) if args.size() > 0 else 6, 1, SEEDS.size())
	var heat: int = int(args[1]) if args.size() > 1 else 0
	## THE SG-190 LINE, AND THE TICK RATE IS DELIBERATELY LEFT ALONE — which is
	## `tools/lane_probe.gd`'s discipline and NOT `tools/balance.gd`'s, and this
	## file cost a result finding out why the difference matters.
	##
	## Every other hand-stepping rig in this repository opens with
	## `Engine.physics_ticks_per_second = 20` and then steps at a hard 0.05. That
	## works only while those two numbers agree, and getting them to agree is not
	## reliable: measured HERE, after `Engine.physics_ticks_per_second = 20` and
	## two `await physics_frame`s, with `Engine.is_in_physics_frame()` TRUE and
	## `Engine.physics_ticks_per_second` reading back 20, this tree still reported
	## `get_physics_process_delta_time()` as **0.01667** while `move_and_slide` —
	## which asks the engine afresh on every call — integrated **0.05**. The walk
	## identity below is what caught it: ground covered came back at **2.87x**
	## what this loop's own `|v| * DT` predicted, and 0.05 / 0.01667 is 3.00.
	##
	## That is the SG-190 fault with the arms swapped: not a loop stepping outside
	## a physics frame, but a loop that ASKED for a clock, was told it had one, and
	## did not have it. So this file asks for nothing. It takes the rate the engine
	## is already running at, steps at exactly that, and proves the identity rather
	## than asserting the setting — there is nothing to argue with if the step IS
	## the delta. The cost is three times as many steps per run, and it is worth it.
	await physics_frame
	DT = root.get_physics_process_delta_time()
	print("  CREW PROBE · %d seeds · HEAT %d · step %.4f s (the engine's own, not one this rig asked for)"
		% [count, heat, DT])
	print("  CHAIN captain inside %.0f, then the lane cannon while the boarder is"
		% SkyGearEnemy.CAPTAIN_NOTICE)
	print("        ahead of it by %.0f, then the nearest crewman inside %.0f,"
		% [SkyGearEnemy.TURRET_GATE_SLACK, SkyGearEnemy.CREW_NOTICE])
	print("        otherwise the Boiler.  A crewman has %.0f HP."
		% float(SkyGearLanes.CREW.hp))
	print("")

	var bad := false
	var arms: Dictionary = {}
	for arm in ARMS:
		var pool: Array = []
		for i in count:
			pool.append(await _one(SEEDS[i], heat, arm))
		arms[arm] = pool
		bad = _report(arm, pool) or bad
	print("")
	_compare(arms)
	quit(1 if bad else 0)


## One full run, bot-driven, on `tools/balance.gd`'s step loop — deliberately the
## same loop, because a crew number that is not comparable to the rig every other
## balance sentence in this repository was written on is a number in its own
## private units.
func _one(seed_text: String, heat: int, arm: String) -> Dictionary:
	var scene: PackedScene = load("res://scenes/main.tscn")
	var game: SkyGearGame = scene.instantiate()
	root.add_child(game)
	game.workshop = SkyGearWorkshop.fresh(true)
	game.refresh_berthed()
	## THE RUNG HAS TO BE UNLOCKED OR IT IS NOT SELECTED — `lane_probe.gd`'s note.
	game.workshop.unlocked = true
	game.workshop.best_heat = SkyGearWorkshop.HEAT.size() - 1
	game.heat = heat
	if game.impact != null:
		game.impact.enabled = false
	game.set_process(false)
	game.set_physics_process(false)
	game.player.set_process(false)
	game.player.set_physics_process(false)
	game.set_seed_text(seed_text)
	game.begin_run()
	game.choose_draft(bot.draft_pick(game.draft_options))

	## THE LEDGER. `aimed` and `landed` are keyed by `victim()`'s own four names
	## plus SWALLOWED, so a name this file does not know about would show up as a
	## missing bucket rather than be silently folded into a bucket it is not.
	var aimed := {"player": 0, "turret": 0, "crew": 0, "boiler": 0}
	var landed := {"player": 0, "turret": 0, "crew": 0, "boiler": 0, "": 0}
	var stomps := 0
	## CREW CASUALTIES, watched rather than counted at the end: a dead crewman is
	## removed from `game.crew` on the following tick and leaves nothing behind.
	## Each hand is stamped with a serial the first time it is seen, which is a
	## probe-side key on a probe-side process and reaches no shipped reader.
	var seen := {}
	var next_serial := 0
	var mustered := 0
	var crew_damage := 0.0
	var crew_deaths := 0
	var crew_hurt := {}
	## WHERE A CREWMAN WAS STANDING WHEN HE TOOK IT (SG-187 asks this half): a
	## hand who has left his lane to help next door is a hand the 220 radius sees
	## differently, so the distance from his own station is recorded on the frame
	## he is hurt rather than inferred from an average.
	var hurt_from_post := 0.0
	var hurt_events := 0
	## THE FLOOR'S OWN SAMPLE — lane_probe's identity, over every boarder.
	var move_ground := 0.0
	var move_expect := 0.0
	var was := {}
	var steps := 0
	var wave_seen := 0

	while game.state_name == "PLAY" or game.state_name == "DRAFT":
		if game.state_name == "DRAFT":
			game.choose_draft(bot.draft_pick(game.draft_options))
		## GUNS DOWN, RE-ASSERTED EVERY STEP rather than once at `begin_run`.
		## `game.begin_run` is not the only thing that stands a cannon up — the
		## SPARE GUN fitting adds a fourth berth and a wave can repair one — so an
		## arm that killed them once would quietly become the shipped arm partway
		## through a run, which is the arm-contamination failure SG-130 paid for.
		if arm == "gunsdown":
			for t in game.turrets:
				if not bool(t.dead):
					t.dead = true
					t.hp = 0.0
		bot.steer(game)
		game._process(DT)
		for e in game.get_tree().get_nodes_in_group("enemies"):
			if not is_instance_valid(e):
				continue
			e.set_physics_process(false)
			var id: int = e.get_instance_id()
			var s0: String = e.state
			var p0: Vector2 = e.global_position
			e._physics_process(DT)
			if not is_instance_valid(e):
				continue
			if s0 == "move" and e.state == "move":
				move_ground += p0.distance_to(e.global_position)
				move_expect += e.velocity.length() * DT
			## A BEAT IS COUNTED AT THE TRANSITION OUT OF THE STATE THAT RESOLVES
			## IT — the only frame at which the damage call has already been made,
			## and therefore the only frame at which `last_swing` is this swing's.
			var prev: String = str(was.get(id, ""))
			if prev == "windup" and e.state == "recover" and not e.last_swing.is_empty():
				var a: String = str(e.last_swing.aimed)
				var l: String = str(e.last_swing.landed)
				aimed[a] = int(aimed.get(a, 0)) + 1
				landed[l] = int(landed.get(l, 0)) + 1
			elif prev == "stomp" and e.state == "recover":
				stomps += 1
			was[id] = e.state
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

		## THE CENSUS, AFTER THE STEP. Read here rather than inside `hurt_crew`
		## because the simulation is not going to grow a probe hook: every point
		## of crew damage in the game arrives as a drop in `c.hp` between two
		## frames, whatever swung it, so watching `hp` catches the stomp, the
		## swing and anything added later without this file having to be told.
		for c in game.crew:
			if not c.has("_probe"):
				c["_probe"] = next_serial
				next_serial += 1
				mustered += 1
				seen[c["_probe"]] = float(c.hp)
			var serial: int = int(c["_probe"])
			var before: float = float(seen.get(serial, float(c.hp)))
			var now: float = float(c.hp)
			if now < before:
				crew_damage += before - now
				crew_hurt[serial] = true
				hurt_from_post += Vector2(c.position).distance_to(
					SkyGearLanes.station(SkyGearGame.LANE_CENTERS, int(c.lane), SkyGearGame.BOW_Y))
				hurt_events += 1
			if bool(c.dead) and not seen.has(-serial - 1):
				seen[-serial - 1] = 1.0
				crew_deaths += 1
			seen[serial] = now
		wave_seen = maxi(wave_seen, int(game.wave))
		steps += 1
		if steps % 200 == 0:
			## `physics_frame`, NOT `process_frame` — board SG-190. This is the line.
			await physics_frame
		if steps > 40000:
			break

	var tel: Dictionary = game.tel
	var out := {
		"seed": seed_text, "arm": arm, "wave": wave_seen,
		"won": game.state_name == "VICTORY",
		"aimed": aimed, "landed": landed,
		"stomps": stomps,
		"mustered": mustered, "crew_damage": crew_damage,
		"crew_deaths": crew_deaths, "crew_hurt": crew_hurt.size(),
		"post": hurt_from_post / maxf(1.0, float(hurt_events)),
		"taken": float(tel.taken),
		"clock": move_ground / maxf(0.001, move_expect),
	}
	game.queue_free()
	await physics_frame
	return out


func _report(arm: String, pool: Array) -> bool:
	var n := maxf(1.0, float(pool.size()))
	var aimed := {"player": 0, "turret": 0, "crew": 0, "boiler": 0}
	var landed := {"player": 0, "turret": 0, "crew": 0, "boiler": 0, "": 0}
	var mustered := 0
	var hurt := 0
	var deaths := 0
	var damage := 0.0
	var post := 0.0
	var stomps := 0
	var clock := 0.0
	var deaths_all := PackedFloat32Array()
	var share_all := PackedFloat32Array()
	for r in pool:
		for k in aimed:
			aimed[k] += int((r.aimed as Dictionary).get(k, 0))
		for k in landed:
			landed[k] += int((r.landed as Dictionary).get(k, 0))
		mustered += int(r.mustered)
		hurt += int(r.crew_hurt)
		deaths += int(r.crew_deaths)
		damage += float(r.crew_damage)
		post += float(r.post)
		stomps += int(r.stomps)
		clock += float(r.clock)
		deaths_all.append(float(r.crew_deaths))
		var mine := 0
		for k in (r.aimed as Dictionary):
			mine += int((r.aimed as Dictionary)[k])
		share_all.append(100.0 * float((r.aimed as Dictionary).get("crew", 0))
			/ maxf(1.0, float(mine)))
	var swings := 0
	for k in aimed:
		swings += int(aimed[k])
	var total := maxf(1.0, float(swings))

	print("  --- %s -------------------------------------------------" % arm.to_upper())
	var q := clock / n
	var ok: bool = absf(q - 1.0) <= SPEED_TOLERANCE
	print("      [rig] ground covered / (|v| x step) = %.4f — %s" % [q,
		"the two clocks are one clock" if ok
		else "REFUSED, move_and_slide is integrating a delta this loop does not control"])
	print("      swings resolved  %5d over %d runs" % [swings, int(n)])
	print("      AIMED AT         captain %5.1f%%   cannon %5.1f%%   CREWMAN %5.1f%%   boiler %5.1f%%"
		% [100.0 * aimed.player / total, 100.0 * aimed.turret / total,
			100.0 * aimed.crew / total, 100.0 * aimed.boiler / total])
	print("      LANDED ON        captain %5.1f%%   cannon %5.1f%%   CREWMAN %5.1f%%   boiler %5.1f%%   swallowed %5.1f%%"
		% [100.0 * landed.player / total, 100.0 * landed.turret / total,
			100.0 * landed.crew / total, 100.0 * landed.boiler / total,
			100.0 * landed[""] / total])
	print("      crew             %5.1f mustered per run, %5.1f of them hurt, %5.2f KILLED"
		% [mustered / n, hurt / n, deaths / n])
	print("      crew HP lost     %7.1f per run  (a hand is %.0f HP, so %.1f hands' worth)"
		% [damage / n, float(SkyGearLanes.CREW.hp), damage / n / float(SkyGearLanes.CREW.hp)])
	print("      when hurt he was %5.0f units from his own station   (the assist's reach is %.0f)"
		% [post / n, SkyGearLanes.ASSIST_LEASH])
	print("      stomps resolved  %5.1f per run  (the one attack that reaches a crewman"
		% (stomps / n))
	print("                              without asking the chain — SG-185)")
	## THE SPREAD, UNDER THE MEAN, ALWAYS (SG-128). Two headline numbers carry an
	## interval and the per-seed values are printed under them, because a mean of
	## twelve runs with no spread is the shape of the sentence this repository has
	## had to withdraw more than once.
	print("      per seed · crew killed      %s" % _spread(deaths_all))
	print("      per seed · %% swings at crew %s" % _spread(share_all))
	print("")
	return not ok


## Mean, sd and the ordinary 95% interval, with every value behind it — the
## convention `tools/balance.gd`'s crew line is written in.
func _spread(v: PackedFloat32Array) -> String:
	var n := maxf(1.0, float(v.size()))
	var mean := 0.0
	for x in v:
		mean += x
	mean /= n
	var var_ := 0.0
	for x in v:
		var_ += pow(x - mean, 2.0)
	var sd := sqrt(var_ / maxf(1.0, n - 1.0))
	var parts: PackedStringArray = []
	for x in v:
		parts.append("%.0f" % x)
	return "mean %6.1f  sd %5.1f  95%% %6.1f..%-6.1f  [%s]" % [mean, sd,
		mean - 1.96 * sd / sqrt(n), mean + 1.96 * sd / sqrt(n), " ".join(parts)]


## THE ONE COMPARISON THE ROW WAS DISPATCHED TO MAKE, printed with what this n
## can resolve beside it rather than as a bare pair of numbers (SG-128).
func _compare(arms: Dictionary) -> void:
	print("  --- the reading under test ------------------------------------")
	print("  \"the cannon outranks the crew, so crew are only targeted once the")
	print("   lane guns are down\".  If that is right, GUNS DOWN is the arm in")
	print("   which crew targeting switches on.")
	print("")
	for arm in ARMS:
		var pool: Array = arms.get(arm, [])
		if pool.is_empty():
			continue
		var swings := 0
		var crew_aimed := 0
		var deaths := 0.0
		for r in pool:
			for k in (r.aimed as Dictionary):
				swings += int((r.aimed as Dictionary)[k])
			crew_aimed += int((r.aimed as Dictionary).get("crew", 0))
			deaths += float(r.crew_deaths)
		print("  %-9s  %5.2f%% of all boarder swings were aimed at a crewman;  %.2f crew killed per run"
			% [arm, 100.0 * float(crew_aimed) / maxf(1.0, float(swings)),
				deaths / maxf(1.0, float(pool.size()))])
	print("")
	print("  %s" % SkyGearBalStat.verdict(int(arms.get(ARMS[0], []).size())))
