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
func _initialize() -> void: call_deferred("_run")

## Anything faster than this stops reading as a swing. Anything slower than a
## third of the window leaves her posing after the hit has landed.
const TOO_FAST := 4.01
const TOO_SLOW_FRACTION := 0.34

func _run() -> void:
	var rig := SkyGearRig3D.new()
	root.add_child(rig)
	if not rig.setup("res://assets/models/captain/captain.tscn", 1.76, 2):
		print("FAIL no model")
		quit(1)
		return

	print("\nCLIPS")
	for name in rig.anim.get_animation_list():
		var a: Animation = rig.anim.get_animation(name)
		print("  %-10s %5.2fs  %s" % [name, a.length,
			"loop" if a.loop_mode != Animation.LOOP_NONE else "once"])

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

	print("\nVERDICT")
	if bad == 0:
		print("  %d of %d attacks land inside their window at a readable rate." % [rows, rows])
	else:
		print("  %d of %d attacks do not read: too fast to see, or cut off early."
			% [bad, rows])
	quit(0 if bad == 0 else 1)
