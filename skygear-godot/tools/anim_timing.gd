extends SceneTree
## Do the animations fit the actions they are animating?
##
## Reported: "the animation speed does not match the skills, weapon swings are
## not synced." That is a measurable claim, so it gets measured — and it stays
## measured, because every animation pack is authored for a game with different
## timings than yours and this will be true again for the boarders.
##
## This does not compare clip lengths to cooldowns; that comparison is always
## going to fail and tells you nothing. It asks the RIG what it would actually
## play for each skill and at what rate, then reports what the player will see.
##
##   godot --path . --headless --script tools/anim_timing.gd
##   ... -- --model boilerwright         the second class, same clips, same clock
func _initialize() -> void: call_deferred("_run")

## Anything faster than this stops reading as a swing. Anything slower than a
## third of the window leaves her posing after the hit has landed.
const TOO_FAST := 4.01
const TOO_SLOW_FRACTION := 0.34

func _run() -> void:
	var which := "captain"
	var uargs := OS.get_cmdline_user_args()
	for i in uargs.size():
		if uargs[i] == "--model" and i + 1 < uargs.size():
			which = uargs[i + 1]
	var model := "res://assets/models/%s/%s.tscn" % [which, which]
	print("MODEL ", which)
	## A boarder is set up at the height `_sync_all` will actually draw it —
	## `boarder_height()`, the renderer's one copy of that arithmetic — because
	## the stride scaling (SG-55) makes the rate a function of height, and a
	## scrapper measured at the captain's 1.76 m would report the captain's
	## numbers. Enemy kinds are upper-case in the table, model dirs lower.
	var ekind := which.to_upper()
	var is_boarder: bool = SkyGearData.ENEMIES.has(ekind)
	var fit_m: float = SkyGearView3D.boarder_height(ekind) * SkyGearView3D.WORLD_SCALE \
		if is_boarder else 1.76
	var rig := SkyGearRig3D.new()
	root.add_child(rig)
	if not rig.setup(model, fit_m, 2):
		print("FAIL no model")
		quit(1)
		return

	print("\nCLIPS")
	for name in rig.anim.get_animation_list():
		var a: Animation = rig.anim.get_animation(name)
		print("  %-10s %5.2fs  %s" % [name, a.length,
			"loop" if a.loop_mode != Animation.LOOP_NONE else "once"])

	## A boarder's attack window is not a skill cooldown: `_sync_rig` calls
	## `want("swing", …)` for as long as the boarder is attacking, and the number
	## it passes is the ATTACK'S OWN LENGTH — the windup plus the recovery, which
	## is `SkyGearEnemy.attack_beat()`. Extended for the first enemy rig (board
	## SG-65); waiting for one was SG-55's call — a tool nothing can exercise is
	## data with no reader.
	##
	## THIS PARAGRAPH USED TO SAY `state_time`, AND SAYING IT IS WHAT HID SG-188
	## FOR A DAY. The renderer did pass `state_time` — a COUNTDOWN — so the window
	## this tool measured was only the value on the FIRST frame of the windup, and
	## the tool reported 3.93x while the shipping game accelerated to the 4.00x
	## clamp and dealt the clip 2.50 times per attack. A tool that samples the
	## opening frame of a window that moves is not measuring the window. The
	## number comes off the simulation now, so this cannot drift again: if the
	## renderer's window and the enemy's beat ever disagree, they disagree in one
	## place and `figure · a boarder's swing is fitted to the whole attack…`
	## fails.
	if is_boarder:
		var config: Dictionary = SkyGearData.ENEMIES[ekind]
		var probe := SkyGearEnemy.new()
		probe.kind = ekind
		probe.config = config
		probe.state = "windup"
		var ewindow: float = probe.attack_beat()
		probe.free()
		rig.state = "idle"
		rig.want("swing", 0.0, ewindow)
		var eclip: String = rig._clip
		var erate: float = rig.anim.speed_scale
		var eshown: float = ewindow * erate / rig.anim.get_animation(eclip).length
		print("\nWHAT THE PLAYER ACTUALLY SEES")
		print("  %-12s %8s %10s %7s %8s  %s"
			% ["attack", "windup", "beat", "clip", "rate", "shown"])
		var enote := "ok"
		if erate >= TOO_FAST:
			enote = "TOO FAST"
		elif eshown < TOO_SLOW_FRACTION:
			enote = "only %.0f%% of the clip" % (eshown * 100.0)
		print("  %-12s %7.2fs %9.2fs %6s %7.2fx  %s"
			% [which, float(config.get("windup", 0.4)), ewindow, eclip, erate,
				enote])
		## EVERY VARIANT THE ROTATION CAN LAND ON, not only the one that came up
		## (board SG-188). One sample says what this cast looked like; the spread
		## says whether the NEXT one will look like it, which is the half of "it
		## looks too fast" that a single row cannot carry. The knight rotates six
		## swings between 1.27 s and 3.53 s, and at the pre-SG-188 window those
		## played at 1.41x to 3.93x — a beat that changed shot to shot by 2.8x.
		var lo := 99.0
		var hi := 0.0
		var rotated: Array[String] = []
		for name in SkyGearRig3D.VARIANTS["swing"]:
			if not rig.has_clip(str(name)):
				continue
			rig.state = "idle"
			rig.want("swing", 0.0, ewindow)
			if not rotated.has(rig._clip):
				rotated.append(rig._clip)
		for name in rotated:
			var vlen: float = rig.anim.get_animation(name).length
			var vrate: float = clampf(vlen / ewindow,
				SkyGearRig3D.ATTACK_RATE_MIN, SkyGearRig3D.ATTACK_RATE_MAX)
			lo = minf(lo, vrate)
			hi = maxf(hi, vrate)
		print("  %-12s %7s %9s %6s %7s  %d variants in the rotation, %.2fx..%.2fx"
			% ["  rotation", "-", "-", "-", "-", rotated.size(), lo, hi])
		if hi >= TOO_FAST:
			enote = "TOO FAST"
		## THE GAIT AND THE DEATH (board SG-85). Two more windows a boarder now
		## has, and both are functions of the kind's own numbers rather than of
		## a skill: the walk/run choice comes from the simulated speed, and the
		## death gets `DEATH_WINDOW` whatever the clip's own length is.
		var espeed: float = float(config.get("speed", 120.0))
		rig.state = "idle"
		rig.want(SkyGearRig3D.gait(espeed), espeed)
		print("  %-12s %7.0fu %9s %6s %7.2fx  %s"
			% ["locomotion", espeed, "-", rig._clip, rig.anim.speed_scale,
				"cycle against a %.0f-unit stride"
					% (SkyGearView3D.boarder_height(ekind))])
		if rig.has_clip("die"):
			rig.state = "idle"
			rig.want("die", 0.0, SkyGearView3D.DEATH_WINDOW)
			var drate: float = rig.anim.speed_scale
			var dshown: float = SkyGearView3D.DEATH_WINDOW * drate \
				/ rig.anim.get_animation(rig._clip).length
			print("  %-12s %7.2fs %9.2fs %6s %7.2fx  %s"
				% ["death", rig.anim.get_animation(rig._clip).length,
					SkyGearView3D.DEATH_WINDOW, rig._clip, drate,
					"%.0f%% of the death shown" % (dshown * 100.0)])
		else:
			print("  %-12s %7s %9s %6s %7s  %s"
				% ["death", "-", "-", "-", "-",
					"no death clip: this kind despawns"])
		print("\nVERDICT")
		if enote == "ok":
			print("  the swing lands inside its windup at a readable rate.")
		else:
			print("  the swing does not read: %s." % enote)
		quit(0 if enote == "ok" else 1)
		return

	var game := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	game.set_seed_text("TIMING")
	game.begin_run()
	game.choose_draft(0)

	print("\nWHAT THE PLAYER ACTUALLY SEES")
	print("  %-12s %8s %10s %7s %8s  %s"
		% ["skill", "cooldown", "window", "clip", "rate", "shown"])
	var bad := 0
	var rows := 0
	for shape in SkyGearData.SHAPES.keys():
		if bool(SkyGearData.SHAPES[shape].get("passive", false)):
			continue
		var st: Dictionary = game.skill_stats(SkyGearData.make_skill(shape, "EMBER"))
		var window: float = clampf(float(st.cooldown) * 0.85, 0.24, 0.62)
		## Ask the rig, rather than reimplementing its choice here — a tool that
		## models the system instead of driving it drifts from it.
		rig.state = "idle"
		rig.want("swing", 0.0, window)
		var clip: String = rig._clip
		var rate: float = rig.anim.speed_scale
		var clip_len: float = rig.anim.get_animation(clip).length
		var shown: float = window * rate / clip_len       ## fraction of the clip
		rows += 1
		var note := "ok"
		if rate >= TOO_FAST:
			note = "TOO FAST"
			bad += 1
		elif shown < TOO_SLOW_FRACTION:
			note = "only %.0f%% of the clip" % (shown * 100.0)
			bad += 1
		print("  %-12s %7.2fs %9.2fs %6s %7.2fx  %s"
			% [shape, float(st.cooldown), window, clip, rate, note])

	## Tap Main's plant (SG-74): the kneel is a one-shot fitted to its own
	## window exactly like the swings — `PLANT_WINDOW`, the same number the
	## renderer passes — so it is measured by the same yardstick. Skipped for
	## a rig that has no kneel (the captain's pack ships none), because a row
	## about a clip that cannot play is data with no reader.
	if rig.has_clip("plant"):
		var pwindow: float = SkyGearRig3D.PLANT_WINDOW
		rig.state = "idle"
		rig.want("plant", 0.0, pwindow)
		var pclip: String = rig._clip
		var prate: float = rig.anim.speed_scale
		var pshown: float = pwindow * prate / rig.anim.get_animation(pclip).length
		rows += 1
		var pnote := "ok"
		if prate >= TOO_FAST:
			pnote = "TOO FAST"
			bad += 1
		elif pshown < TOO_SLOW_FRACTION:
			pnote = "only %.0f%% of the clip" % (pshown * 100.0)
			bad += 1
		print("  %-12s %7s %9.2fs %6s %7.2fx  %s"
			% ["TAP MAIN", "-", pwindow, pclip, prate, pnote])

	print("\nVERDICT")
	if bad == 0:
		print("  %d of %d attacks land inside their window at a readable rate." % [rows, rows])
	else:
		print("  %d of %d attacks do not read: too fast to see, or cut off early."
			% [bad, rows])
	quit(0 if bad == 0 else 1)
