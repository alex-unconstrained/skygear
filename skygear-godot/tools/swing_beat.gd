extends SceneTree
## WHAT A BOARDER'S SWING CLIP ACTUALLY DOES ACROSS THE WHOLE ATTACK, FRAME BY
## FRAME (board SG-188, owner: *"Slow down the attack animations on furnace
## knights it looks too fast now."*).
##
## WHY `tools/anim_timing.gd` COULD NOT ANSWER IT ON ITS OWN. That tool asks the
## rig ONE question — `want("swing", 0, windup)` — and prints the rate that comes
## back. That is the right question about the frame the swing STARTS on and it is
## the whole question for the captain, whose skills are one window long. A
## boarder's attack is not one window: `view3d.gd` holds the rig in the `swing`
## state for `windup` AND `recover`, so the clip is fitted to 0.90 s and then left
## running for 1.90 s. Nothing that samples a single frame can see what happens in
## the second half of that, and the second half is where the owner's complaint
## lives.
##
## So this drives the REAL thing: a real boarder, in a real run, attacking a real
## captain on the engine's own clock, with the rig's `animation_finished` signal
## counted rather than inferred. It reports, per attack:
##
##   clip + length      which variant `_variant_of` rotated up, and how long it is
##   rate               `anim.speed_scale` — the number nobody chose
##   plays              HOW MANY TIMES the clip ran start to finish in one attack
##   clip-seconds       authored seconds of motion shown per real second
##
## `plays` is the number this tool was built for. A one-shot that finishes inside
## its own state does not stop: `want`'s `elif not anim.is_playing()` arm replays
## it, because that arm exists to recover a clip the blend tree dropped. So an
## attack whose clip is fitted to less than the attack's own length does not end
## with a held pose, it LOOPS — and a swing played twice in one attack is read as
## one swing at twice the speed.
##
##   godot --path . --headless --script tools/swing_beat.gd
##   ... -- --kind SCRAPPER        any melee boarder with a rig
##   ... -- --attacks 4            how many complete attacks to sit through
##
## NOT a picture: this is the number, and `tools/clip.gd` is the tempo. Both, per
## the board rule that a still cannot witness a speed.
func _initialize() -> void: call_deferred("_run")


## The default subject is the one the owner named.
const DEFAULT_KIND := "ARMORED"
const DEFAULT_ATTACKS := 4


func _run() -> void:
	var kind := DEFAULT_KIND
	var attacks := DEFAULT_ATTACKS
	var uargs := OS.get_cmdline_user_args()
	for i in uargs.size():
		if uargs[i] == "--kind" and i + 1 < uargs.size():
			kind = str(uargs[i + 1]).to_upper()
		if uargs[i] == "--attacks" and i + 1 < uargs.size():
			attacks = maxi(1, int(uargs[i + 1]))
	if not SkyGearData.ENEMIES.has(kind):
		print("FAIL no such enemy kind: ", kind)
		quit(1)
		return
	var config: Dictionary = SkyGearData.ENEMIES[kind]
	var windup: float = float(config.get("windup", 0.4))
	var recover: float = float(config.get("recover", 0.4))
	print("KIND %s   windup %.2fs + recover %.2fs = a %.2fs attack"
		% [kind, windup, recover, windup + recover])

	var world = load("res://scenes/main3d.tscn").instantiate()
	root.add_child(world)
	await process_frame
	var game: SkyGearGame = world.get_node("SkyGear")
	world.sway = false
	## SG-101: a tool that opens a real run must not write rows into the player's
	## own log, which the harness then reads back as history.
	game.log_runs = false
	game.workshop = SkyGearWorkshop.fresh(true)
	game.heat = 0
	game.set_class("captain")
	game.set_seed_text("SG188")
	game.begin_run()
	game.choose_draft(0)
	## Wave 3 with no `await` in front of it keeps `_watch_cues` from ever seeing
	## wave 1 and craning the camera off the shipped solve (SG-33).
	game.start_wave(3)
	game.spawn_queue.clear()
	if game.view != null:
		game.view.cutscenes_enabled = false
		game.view.stop_cutscene()
	game.spawn_enemy(kind, 1)
	var subject: SkyGearEnemy = null
	for e in game.get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and str(e.kind) == kind:
			subject = e
	if subject == null:
		print("FAIL nothing spawned")
		quit(1)
		return

	## THE SIM AND THE ANIMATION HAVE TO SHARE ONE CLOCK HERE, which is the exact
	## opposite of what a SHOT tool wants. `tools/still.gd` freezes the
	## AnimationPlayer because a photograph of a moving limb is not evidence; this
	## tool is measuring the moving limb, so the game keeps its own `_process` and
	## the engine drives both. Everything below therefore reads the engine's real
	## delta rather than a fixed step it has invented.
	var cap := Vector2(0.0, 60.0)
	game.player.global_position = cap
	game.player.velocity = Vector2.ZERO
	subject.global_position = cap + Vector2(0.0, -float(config.attack_range) + 6.0)
	subject.state = "move"

	var rig: SkyGearRig3D = null
	## A DICTIONARY RATHER THAN AN INT, and the reason is a real trap: **GDScript
	## lambdas capture locals BY VALUE**, so a `func(): plays += 1` bound to
	## `animation_finished` increments a copy and the counter outside stays zero
	## forever. The first run of this tool reported "0 clip plays" against clips
	## that were demonstrably finishing twice per attack, which is the fifth
	## failure mode — a measuring rig nobody measured — in one line.
	var tally := {"plays": 0}
	var rows: Array = []
	var seen := 0
	var prev_state := ""
	var cur := {}
	var clock := 0.0
	var guard := 0
	while seen < attacks and guard < 4000:
		guard += 1
		var d: float = get_root().get_process_delta_time()
		clock += d
		## BOTH FIGURES ARE PINNED ALIVE, and the boarder's half of that is not
		## housekeeping — it is the reason this tool exists. The captain's auto
		## attack resolves a 360-hp knight in about six seconds, which is SG-165's
		## own number and is 2.49 attacks: exactly the sample the owner has been
		## looking at and far too few to characterise a rotation of six variants.
		## Holding his hp up is what buys enough attacks to see the rotation.
		game.player.global_position = cap
		game.player.velocity = Vector2.ZERO
		game.player.hp = game.player.max_hp
		if not is_instance_valid(subject) or subject.dead:
			print("FAIL the subject was freed after %d attacks" % seen)
			break
		subject.hp = 1.0e9
		await process_frame
		if not is_instance_valid(subject):
			print("FAIL the subject was freed after %d attacks" % seen)
			break
		if rig == null:
			rig = game.view._rigs.get("e%d" % subject.get_instance_id(), null)
			if rig != null and rig.anim != null:
				rig.anim.animation_finished.connect(func(_n: String) -> void:
					tally["plays"] = int(tally["plays"]) + 1)
			continue
		var st := str(subject.state)
		if st != prev_state:
			if st == "windup":
				## A fresh attack begins. Everything gathered about the previous
				## one is closed out here rather than at the end, because the
				## boarder walks back into range between attacks and the walk is
				## not part of what is being measured.
				if not cur.is_empty():
					rows.append(cur)
					seen += 1
				tally["plays"] = 0
				cur = {"clip": "", "len": 0.0, "rate": 0.0, "began": clock,
					"lo": 99.0, "hi": 0.0, "picks": 0}
			elif st != "recover" and not cur.is_empty():
				## Left the attack by any door other than the recovery — a stun,
				## a death, the target walking out of reach.
				cur["ended"] = clock
			prev_state = st
		if (st == "windup" or st == "recover") and not cur.is_empty():
			if rig.state == "swing" and rig._clip != "":
				## EVERY re-pick inside one attack, not only the first. The window
				## `want` is handed is `state_time` AT THE TRANSITION FRAME, so a
				## swing that is interrupted and re-entered mid-attack is refitted
				## to whatever is LEFT of the beat — which accelerates it. A tool
				## that recorded only the opening rate would report the honest
				## number for a swing nobody interrupted and miss the fast ones.
				if str(cur["clip"]) != rig._clip:
					cur["clip"] = rig._clip
					cur["len"] = rig.anim.get_animation(rig._clip).length
					cur["picks"] = int(cur["picks"]) + 1
				cur["rate"] = rig.anim.speed_scale
				cur["lo"] = minf(float(cur["lo"]), rig.anim.speed_scale)
				cur["hi"] = maxf(float(cur["hi"]), rig.anim.speed_scale)
			cur["ended"] = clock
			cur["plays"] = tally["plays"]
	if not cur.is_empty() and seen < attacks:
		rows.append(cur)
	if rig == null or rows.is_empty():
		print("FAIL no rig, or no complete attack in %d frames" % guard)
		quit(1)
		return

	print("\nWHAT THE PLAYER ACTUALLY SEES, ONE ROW PER ATTACK")
	print("  %-3s %-8s %7s %14s %7s %6s %6s"
		% ["#", "clip", "len", "rate lo..hi", "held", "picks", "plays"])
	var worst := 0.0
	var total_plays := 0
	for i in rows.size():
		var r: Dictionary = rows[i]
		var held: float = float(r.get("ended", 0.0)) - float(r.get("began", 0.0))
		var n: int = int(r.get("plays", 0))
		total_plays += n
		worst = maxf(worst, float(r["hi"]))
		print("  %-3d %-8s %6.2fs %6.2fx..%5.2fx %6.2fs %6d %6d"
			% [i + 1, r["clip"], float(r["len"]), float(r["lo"]), float(r["hi"]),
				held, int(r["picks"]), n])

	print("\nEVERY VARIANT THIS RIG CAN ROTATE UP, AT THIS ATTACK'S WINDOW")
	## Asked of the rig rather than of a list typed here — the SG-119 lesson about
	## hand-written rosters exempting the row that matters.
	var lo := 99.0
	var hi := 0.0
	for name in SkyGearRig3D.VARIANTS["swing"]:
		if not rig.has_clip(str(name)):
			continue
		var alen: float = rig.anim.get_animation(str(name)).length
		var rate: float = clampf(alen / (windup + recover),
			SkyGearRig3D.ATTACK_RATE_MIN, SkyGearRig3D.ATTACK_RATE_MAX)
		var old: float = clampf(alen / windup,
			SkyGearRig3D.ATTACK_RATE_MIN, SkyGearRig3D.ATTACK_RATE_MAX)
		lo = minf(lo, rate)
		hi = maxf(hi, rate)
		print("  %-8s %6.2fs   at the windup %5.2fx   at the whole attack %5.2fx"
			% [name, alen, old, rate])
	print("  spread across the variants at the whole attack: %.2fx .. %.2fx (%.1fx)"
		% [lo, hi, hi / maxf(lo, 0.001)])

	print("\nVERDICT")
	print("  worst rate seen %.2fx, %d clip plays across %d attacks (%.2f each)"
		% [worst, total_plays, rows.size(), float(total_plays) / maxf(1.0, rows.size())])
	quit(0)
