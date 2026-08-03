extends SceneTree
## DOES `tools/balance.gd` DRIFT ACROSS THE ORDER ITS RUNS WERE PLAYED IN?
## (SG-129 — the pre-specified test, and the tool that runs it.)
##
##   godot --path . --headless --script tools/bal_drift.gd -- primary.log
##   godot --path . --headless --script tools/bal_drift.gd -- a.log b.log c.log d.log
##
## Each argument is a file containing `balance.gd` output. The `taken=` list on
## its `SAMPLES` line is read in order, the files are concatenated IN THE ORDER
## GIVEN, and one OLS slope of damage-taken against the 0-based run index is
## computed over the whole concatenated series.
##
## THE POINT OF THE MULTI-FILE FORM. Passing four 120-run logs is the CONTROL
## arm: the same 480 runs, the same index, the same test, but with process
## boundaries at 120, 240 and 360. If a slope is a property of one process's
## accumulating state it appears in the single-file form and vanishes in the
## four-file form. If it appears in both it is not process state, and the honest
## reading is something the two arms share — the machine, the wall clock — which
## is a different finding and must not be reported as the first one.
##
## WHAT THIS TOOL WILL NOT DO, deliberately, because SG-129 was filed after its
## author withdrew a p=0.027 that came from choosing a split AFTER seeing the
## data: it computes ONE statistic (damage taken) and ONE test (the slope). It
## does not offer thirds, halves, block means, per-seed breakdowns, or a way to
## combine two pools. Those are all available to anyone who wants them and every
## one of them is a fresh chance to mine the same numbers until something clears
## 0.05. The absence of the options IS the feature.
func _initialize() -> void: call_deferred("_run")

const P_THRESHOLD := 0.05

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		print("  usage: bal_drift.gd -- <log> [<log> ...]")
		quit(1)
		return
	var ys := PackedFloat64Array()
	var bounds: Array[int] = []
	for path in args:
		var text := FileAccess.get_file_as_string(path)
		if text == "":
			print("  cannot read: %s" % path)
			quit(1)
			return
		var found := false
		for line in text.split("\n"):
			if not line.begins_with("SAMPLES "):
				continue
			for tok in line.split(" "):
				if not tok.begins_with("taken="):
					continue
				for v in tok.substr(6).split(","):
					if v.strip_edges() != "":
						ys.append(float(v))
				found = true
			break
		if not found:
			print("  no SAMPLES line in: %s" % path)
			quit(1)
			return
		bounds.append(ys.size())
	var res := SkyGearBalStat.ols_slope_t(ys)
	var slope: float = res[0]
	var t: float = res[1]
	var df: int = res[2]
	var p := SkyGearBalStat.t_p_two_sided(t, df)
	var mean := 0.0
	for y in ys:
		mean += y
	mean /= float(ys.size())
	print("")
	print("  SG-129 DRIFT TEST — damage taken against run index, OLS slope, two-sided")
	print("  %d file(s), boundaries after run %s"
		% [args.size(), ", ".join(bounds.map(func(b): return str(b)))])
	print("  n = %d   mean taken = %.1f" % [ys.size(), mean])
	print("  slope = %+.4f damage per run   t = %+.3f (df %d)   p = %.4f"
		% [slope, t, df, p])
	print("  end-to-end change implied by the fit: %+.1f damage = %+.1f%% of the mean"
		% [slope * float(ys.size() - 1),
			100.0 * slope * float(ys.size() - 1) / maxf(0.001, mean)])
	print("  %s at the pre-specified p < %.2f"
		% ["SLOPE PRESENT" if p < P_THRESHOLD else "NO SLOPE ESTABLISHED", P_THRESHOLD])
	print("DRIFT n=%d slope=%.6f t=%.4f df=%d p=%.6f" % [ys.size(), slope, t, df, p])
	print("")
	quit(0)
