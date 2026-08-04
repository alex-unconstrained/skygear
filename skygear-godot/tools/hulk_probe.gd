extends SceneTree
## HOW LONG DOES THE BOARDING HULK ACTUALLY TAKE TO BREAK? (board SG-186)
##
## The owner's 12-wave run: *"Boarding hulk took a long time to kill."* Before
## anything is changed, this times it — from the frame the door OPENS
## (`hulk_state() == "open"`, the first frame `damage_hulk` will accept a hit) to
## the frame it reports `destroyed` — and reports WHERE the damage came from, so
## the answer is a cause and not a duration.
##
## THE FIXTURE IS A CAPTAIN WHO IS ALREADY DOING EVERYTHING RIGHT. She is parked
## at the hulk's edge, inside her auto's reach and inside the splash band, and
## every skill she holds is cast at the hulk the instant it comes off cooldown.
## Boarders spawn and are left alone. So this is a LOWER BOUND on the wall clock:
## a real player also has to survive, and cannot be attacking the hulk every
## frame she is alive. If the lower bound is already long, the complaint is
## structural rather than a matter of play.
##
## WHAT IT SEPARATES, AND WHY THAT IS THE POINT. Three ledgers:
##
##   auto      the class's basic attack — `_process_basic_attack`
##   skills    everything cast from a slot — `_resolve_cast` -> `hulk_splash`
##   crew      `SkyGearLanes.CREW.siege`, sailors marching on the hull
##
## They are read off the hulk's own HP rather than inferred, by taking the drop
## across each call site with the other paths idle.
##
##   godot --path . --headless --script tools/hulk_probe.gd
##   godot --path . --headless --script tools/hulk_probe.gd -- 2 boilerwright
##                                                             ^ heat  ^ class
##
## THE CLOCK DISCIPLINE IS `tools/lane_probe.gd`'s, and it is not optional —
## board SG-190. This file never awaits inside a measurement, awaits
## `physics_frame` and not `process_frame` between arms, and takes its hand-step
## FROM the engine's physics delta rather than declaring one at it.

var DT := 1.0 / 60.0


func _initialize() -> void: call_deferred("_run")


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var heat: int = int(args[0]) if args.size() > 0 else 2
	var only: String = str(args[1]) if args.size() > 1 else ""
	await physics_frame
	DT = root.get_physics_process_delta_time()
	print("  HULK PROBE · HEAT %d · step %.4f s" % [heat, DT])
	print("  HULK  hp %.0f base, radius %.0f, splash band %.0f, grapple %.1f s sealed"
		% [float(SkyGearLanes.HULK.hp), float(SkyGearLanes.HULK.radius),
			float(SkyGearLanes.HULK.radius) + 150.0, SkyGearGame.HULK_GRAPPLE_TIME])
	print("  CREW  siege %.0f a hit" % float(SkyGearLanes.CREW.siege))
	print("")
	for cls in ["captain", "boilerwright"]:
		if only != "" and cls != only:
			continue
		var auto: Dictionary = SkyGearData.CLASSES[cls].auto
		print("  --- %s · auto %s, %.0f dmg every %.2f s = %.0f dps, reach %.0f"
			% [cls.to_upper(), str(auto.name), float(auto.damage), float(auto.period),
				float(auto.damage) / float(auto.period), float(auto.range)])
		var r := await _one(heat, cls)
		if r.is_empty():
			print("      no hulk grappled — nothing to time")
			continue
		print("      [rig] ground/(|v| x step) = %.4f on the boarders it stepped" % float(r.clock))
		print("      TIME TO BREAK   %6.2f s from the door opening%s"
			% [float(r.secs), "" if bool(r.broke)
				else "   <- NOT BROKEN; it stopped because %s, so read this as a LOWER BOUND" % str(r.why)])
		print("      hulk hp         %.0f, %.0f still on it at the buzzer"
			% [float(r.hp_max), float(r.hp_left)])
		print("      damage by path  skills %.0f · everything else (crew, cannons, the auto) %.0f"
			% [float(r.d_skill), float(r.d_other)])
		print("      swings          %d skill casts bit it, and she swung her auto %d times"
			% [int(r.casts), int(r.autos)])
		print("")
	quit(0)


func _one(heat: int, cls: String) -> Dictionary:
	var scene: PackedScene = load("res://scenes/main.tscn")
	var game: SkyGearGame = scene.instantiate()
	root.add_child(game)
	game.workshop = SkyGearWorkshop.fresh(true)
	game.workshop.unlocked = true
	game.workshop.best_heat = SkyGearWorkshop.HEAT.size() - 1
	game.refresh_berthed()
	game.heat = heat
	game.class_id = cls
	if game.impact != null:
		game.impact.enabled = false
	game.set_process(false)
	game.set_physics_process(false)
	game.player.set_process(false)
	game.player.set_physics_process(false)
	game.set_seed_text("SG186")
	game.begin_run()
	game.choose_draft(0)

	## Straight to a push. `_begin_push` is the shipped entry point, so the hulk
	## this times is the hulk the game builds — toughness, grapple clock and all.
	game._begin_push(4)
	if game.hulk.is_empty():
		game.queue_free()
		await physics_frame
		return {}
	var hull: Vector2 = game.hulk.position
	var stand := hull + Vector2(0.0, float(game.hulk.radius) + 60.0)

	var hp_max: float = float(game.hulk.hp)
	var d_skill := 0.0
	var d_other := 0.0
	var casts := 0
	var autos := 0
	var secs := 0.0
	var opened := false
	var why := "the %.0f s window ran out" % 120.0
	var ground := 0.0
	var expect := 0.0
	for _i in int(120.0 / DT):
		game.player.global_position = stand
		## She is never the reason the fight ends.
		game.player.hp = game.player.max_hp
		var before: float = float(game.hulk.hp)
		var cool: float = game.basic_cooldown

		game._process(DT)
		if game.hulk.is_empty():
			break
		## A CLOCK THAT RUNS WHILE THE SIMULATION IS PAUSED IS NOT A CLOCK. The
		## first draft of this file counted every step of its own window, so the
		## captain arm reported 117.5 s for the same 1484 damage the Boilerwright
		## arm did in 28.4 — the difference was entirely time spent in a state
		## where nothing on the deck was moving at all.
		if not game.is_playing():
			why = "the simulation left PLAY (%s) — the run ended under her" % game.state_name
			break
		## Every boarder stepped once and only once — `set_process(false)` on the
		## game does not reach them (SG-118's lesson, SG-190's clock).
		for e in game.get_tree().get_nodes_in_group("enemies"):
			if is_instance_valid(e):
				e.set_physics_process(false)
				var p0: Vector2 = e.global_position
				var v0: float = e.velocity.length()
				e._physics_process(DT)
				if is_instance_valid(e) and e.state == "move":
					ground += p0.distance_to(e.global_position)
					expect += v0 * DT
		## EVERYTHING `_process` TOOK OFF IT — the auto, the crew's siege, and the
		## cannons if they ever bit. Attribution between them is NOT guessed at: the
		## auto's swings are counted separately by its cooldown resetting, and the
		## report puts the two side by side so a reader can see a swing count next
		## to a damage total and draw the only conclusion available.
		var after_auto: float = float(game.hulk.hp)
		if game.basic_cooldown > cool:
			autos += 1
		d_other += maxf(0.0, before - after_auto)

		if not opened and game.hulk_state() == "open":
			opened = true
		if opened and not bool(game.hulk.get("dead", false)):
			secs += DT
		## EVERY SKILL AT THE HULL THE MOMENT IT IS READY. A cast that is on
		## cooldown is a cast a real player also does not have.
		if opened:
			for slot in game.skills.size():
				if float(game.skills[slot].cooldown_left) <= 0.0:
					var pre: float = float(game.hulk.hp)
					game.cast_skill(slot, hull)
					var post: float = float(game.hulk.hp)
					if post < pre:
						casts += 1
						d_skill += pre - post
					break
		if bool(game.hulk.get("dead", false)):
			break

	var broke: bool = not game.hulk.is_empty() and bool(game.hulk.get("dead", false))
	var out := {
		"secs": secs, "broke": broke, "hp_max": hp_max,
		"hp_left": float(game.hulk.hp) if not game.hulk.is_empty() else 0.0,
		"d_skill": d_skill, "d_other": d_other,
		"casts": casts, "autos": autos, "why": why,
		"clock": ground / maxf(0.001, expect),
	}
	game.queue_free()
	await physics_frame
	return out
