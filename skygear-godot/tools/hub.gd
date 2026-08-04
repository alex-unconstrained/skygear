extends SceneTree
## One door to every tool.
##
## Fifteen tools have accumulated in `tools/`, each with its own invocation, its
## own flags and its own habit of writing somewhere you have to remember. Nobody
## can hold that, which means in practice they get used once by whoever wrote
## them and never again — the exact opposite of the point of building them.
##
## This lists them, says what each is FOR rather than what it does, runs them,
## and puts the output where you are already looking.
##
##   godot --path . --script tools/hub.gd            list everything
##   godot --path . --script tools/hub.gd -- text    run the text audit
##   godot --path . --script tools/hub.gd -- all     run every checker
##
## Or double-click `SkyGear Tools.bat` at the repo root.
##
## The interactive ones (`fit`, `layout`) open a window; the rest print and exit.
## Exit code is the failure count of whatever ran, so `hub -- all` can gate a
## build on its own.
func _initialize() -> void: call_deferred("_run")

## `kind` decides how it is run and whether `all` includes it:
##   check   headless, prints, exit code is a failure count — `all` runs these
##   window  needs a window; opens something you look at or click
##   make    changes files or spends money; never in `all`
const TOOLS := [
	{"id": "harness", "kind": "check", "script": "tests/parity_test.gd",
		## NO COUNT HERE ON PURPOSE. This line read "867 checks" while the harness
		## reported 970 — a number duplicated out of the one place that can know
		## it goes stale the moment anybody adds a check, which is STATUS.md's
		## sixth failure mode in its smallest possible form. The harness prints
		## its own total; this menu does not need to guess at it.
		"what": "the whole simulation, every check in tests/parity_test.gd",
		"why": "the one thing that must be green before anything ships"},
	{"id": "text", "kind": "check", "script": "tools/text_audit.gd", "window": true,
		"what": "every string on 25 screens at 4 resolutions — fit, size, contrast, overlap and drift",
		"why": "text over the frame, clipped, too small, or the same colour as the brass"},
	{"id": "balance", "kind": "check", "script": "tools/balance.gd",
		"what": "simulated runs, wave by wave",
		"why": "whether twelve waves is still a curve rather than a wall"},
	{"id": "drift", "kind": "check", "script": "tools/bal_drift.gd",
		"what": "damage-taken against run index in saved balance.gd logs, one OLS slope",
		"why": "whether two arms run back to back in ONE invocation are confounded by run order"},
	{"id": "timing", "kind": "check", "script": "tools/anim_timing.gd",
		"what": "every clip against the skill that plays it",
		"why": "an attack whose animation does not fit its cooldown"},
	{"id": "motion", "kind": "check", "script": "tools/anim_motion.gd",
		"what": "root drift per clip, in GROUND units",
		"why": "a clip that walks the mesh off the position the simulation gave her"},
	{"id": "model", "kind": "check", "script": "tools/verify_model.gd",
		"what": "an ingested rig: height, bones, clips, materials",
		"why": "whether a model will actually stand on the deck"},
	## A check that needs a window, like `text`: the readback hangs headless
	## (SG-29), so `all` runs it windowed. Bare invocation is the SMOKE — one
	## short clip end to end, frame count asserted against the plan. Scenarios
	## take arguments the hub cannot pass, so run those directly:
	##   godot --path . --resolution 1600x900 --script tools/clip.gd -- <scenario>
	## `-- list` names them: fight, dash, projectiles, and every shipped cutscene.
	{"id": "clip", "kind": "check", "script": "tools/clip.gd", "window": true,
		"what": "MOTION evidence: pose a scenario, run real seconds of sim+render, stitch to .shots/clips/<name>.gif",
		"why": "every figure claim ahead is a claim about motion, and a still cannot witness a walk, a dash crack, or a cutscene's hand-back"},

	## A check that needs a window for the same reason `text` does: the whole
	## assertion is a framebuffer readback and headless has no GPU (SG-29). It is
	## the runtime half of SG-108 — the harness guards the SOURCE of every
	## photographing tool, and this proves the freeze those tools call actually
	## freezes. Either half alone is a check that cannot fail.
	{"id": "still", "kind": "check", "script": "tools/still_probe.gd", "window": true,
		"what": "two plates of a frozen wave-8 deck, and the fraction of pixels that moved between them",
		"why": "`set_process(false)` does not stop an AnimationPlayer, and four tools each believed it did — one of them measured its own noise floor at 53% and published three A/B answers against it. This number must be exactly zero"},

	## The runtime half of SG-116, windowed for the same reason `still` is: the
	## whole assertion is a framebuffer readback and headless has no GPU (SG-29).
	## The harness guards the SOURCE of the mask; this is the half that can
	## actually fail, and the mask it replaced fails it.
	{"id": "rune", "kind": "check", "script": "tools/rune_probe.gd", "window": true,
		"what": "a deck with its braziers lit and nothing in windup, and how many pixels the rune mask calls telegraph",
		"why": "the mask that decides what the shadow rigging and the deck marks cost a telegraph's legibility used to select any saturated red-amber pixel — brazier fire and an ARMORED boarder's lit plating included, 26,095 of them on the wave-6 pose. It had no frame on which it was required to select nothing, so nothing about it could ever fail. This is that frame: the answer must be zero"},

	## Not a "check": it has no pass/fail on purpose — it records a baseline and
	## takes no opinion (SG-25). Needs a real window; headless has no GPU (SG-29).
	{"id": "profile", "kind": "window", "script": "tools/profile_fight.gd",
		"what": "the frame's cost in a saturated wave-11 fight: p50/p95/p99 for frame, script, physics, render CPU and GPU, plus what was on the deck",
		"why": "the port was never profiled before SG-25; the baseline lives on that board row, and the next \"it feels slow\" gets re-measured here — same load, same buckets"},

	{"id": "sky", "kind": "window", "script": "tools/sky_shot.gd",
		"what": "the sky, from the four places on the deck it is actually visible",
		"why": "at 41 degrees the horizon is off the top of the frame, so a shot from mid-deck cannot show you the sky is empty — and three times it did not"},

	## A `make` rather than a `check`: it writes PNGs and it needs a real window,
	## so `all` must not pick it up. It is here because a VFX tool nobody can find
	## is a VFX judgement made from memory, which is how a beam stayed a scratch on
	## the planking for eleven builds.
	{"id": "vfx", "kind": "make", "script": "tools/vfx_shot.gd",
		"what": "one posed frame per skill into .shots/vfx — arc, cone, line, aoe, chain, ray, pulse, aura, cannons",
		"why": "the only way to judge an effect without three others on screen; run it before AND after"},

	{"id": "pool", "kind": "make", "script": "tools/pool_shot.gd",
		"what": "a fire pool photographed with its TRUE burn footprint marked — the captain is walked around it and the boundary is measured from the damage path, not read off a constant",
		"why": "a hazard drawn smaller than it burns is invisible to every other tool in this list, and this one burned you from 70% outside its own picture until SG-163 — the shape of question it answers is 'does the picture agree with the hitbox', which no screenshot can answer alone"},

	{"id": "lab", "kind": "window", "script": "tools/model_lab.gd",
		"what": "every model: view it, RUN its animations, mount a weapon, run the effects, save",
		"why": "the one place to answer \"is this the right size, does the grip hold through the swing, and what does that effect actually look like\" — and MOUNT/SAVE writes assets/models/weapons.json, which the game reads"},
	{"id": "fit", "kind": "window", "script": "tools/weapon_fit.gd",
		"what": "just the captain and her weapon, six fixed poses",
		"why": "narrower than `lab` and kept for that: six poses side by side rather than a timeline to scrub"},

	{"id": "cutscene", "kind": "window", "script": "tools/cutscene_lab.gd",
		"what": "author a camera move on the real deck: keyframes, easing, a timeline to scrub, and SAVE writes assets/cutscenes/<id>.json",
		"why": "for framing a moment the fight cannot frame for itself — and the file is READ: a `cue` on the shot names one of four moments in the game, and the Colossus arriving at wave 12 already plays one"},

	{"id": "layout", "kind": "check", "script": "tools/layout_promote.gd",
		"what": "the alignment you made with F4 — plates, items AND per-screen element offsets — validate it, and `-- write` promotes it into the repo",
		"why": "F4 and Ctrl+S save to user:// under AppData, and `load_layout` PREFERS that file — so a hand-alignment pass looks permanent to whoever made it and does not exist for anybody else. This is the step that makes it real, and it REFUSES a layout that breaks at any of the four widths"},

	{"id": "captain", "kind": "make", "script": "tools/build_captain.gd",
		"what": "rebuild the captain scene from the imported FBX",
		"why": "after a new animation pack lands"},
	{"id": "static", "kind": "make", "script": "tools/static_model.gd",
		"what": "wrap a generated GLB into a placeable scene",
		"why": "how a Meshy boarder becomes something the renderer can use"},
]

## Not Godot scripts. Listed so the hub is the whole inventory rather than most
## of it — a launcher you still have to remember things outside of is a launcher
## nobody trusts.
const SCRIPTS := [
	{"id": "parity", "run": "python tools/parity.py --open",
		"what": "browser against Godot, same moment, side by side",
		"why": "the only evidence for a parity claim that is not my memory"},
	{"id": "screens", "run": "python tools/screen_review.py",
		"what": "THE BATCH-EVIDENCE MODE: photograph all 25 screens at all 4 widths and open them as one page",
		"why": "for auditing everything at once, not for fixing anything — FIXING is F4 in the game, on the screen that is wrong (docs/HUD-LAYOUT.md; F12 in the editor photographs the one screen you are fixing). `--tag before` then `--tag after` gives two pages to read against each other"},
	{"id": "pack", "run": "python tools/pack_itch.py",
		"what": "export the Windows build and zip it",
		"why": "what goes to itch"},
	{"id": "meshy", "run": "python tools/meshy.py list",
		"what": "generate 3D assets, and what has been generated",
		"why": "SPENDS CREDITS — `run <batch> --dry` first, always"},
	{"id": "ingest", "run": "python tools/ingest_model.py",
		"what": "bring an external model into the project",
		"why": "handles the FBX unit-scale trap that cost us an afternoon"},
	{"id": "ui", "run": "python tools/ingest_ui.py",
		"what": "bring UI art in at the right slice margins",
		"why": ""},
	{"id": "pose", "run": "python tools/pose_captain.py",
		"what": "render the captain in a set of poses",
		"why": ""},
]

const GODOT := "godot"


func _run() -> void:
	var argv := OS.get_cmdline_user_args()
	var want: String = str(argv[0]) if argv.size() > 0 else ""

	if want == "" or want == "list" or want == "help":
		_list()
		quit(0)
		return

	## The open list, in front of me whenever I reach for a tool. The skybox was
	## reported twice and slipped twice because there was nowhere for it to sit
	## between being said and being done.
	if want == "todo":
		_todo()
		quit(0)
		return

	if want == "all":
		quit(_run_all())
		return

	## Everything after the tool's own name belongs to the tool.
	var extra := PackedStringArray()
	for i in range(1, argv.size()):
		extra.append(str(argv[i]))
	for tool in TOOLS:
		if str(tool.id) == want:
			quit(_launch(tool, extra))
			return
	for tool in SCRIPTS:
		if str(tool.id) == want:
			print("\n  %s is not a Godot script. Run it yourself:\n\n      %s\n"
				% [want, str(tool.run)])
			quit(0)
			return

	print("no tool called '%s'. `hub` on its own lists them." % want)
	quit(1)


## Prints the Open half of `docs/OUTSTANDING.md`. Deliberately the file rather
## than a copy in here: two lists disagree within a week, and the file is the one
## a human edits.
func _todo() -> void:
	var text := FileAccess.get_file_as_string("res://docs/OUTSTANDING.md")
	if text == "":
		print("docs/OUTSTANDING.md is missing")
		return
	var open_at := text.find("## Open")
	var done_at := text.find("## Done")
	if open_at < 0:
		print(text)
		return
	print("")
	print(text.substr(open_at, (done_at - open_at) if done_at > open_at else -1))


func _list() -> void:
	print("")
	print("SKYGEAR TOOLS      godot --path . --script tools/hub.gd -- <name>")
	print("")
	var groups := [["check", "CHECKERS — safe, read-only, `-- all` runs every one"],
		["window", "INTERACTIVE — opens a window"],
		["make", "BUILDERS — these change files"]]
	for group in groups:
		print("  %s" % str(group[1]))
		for tool in TOOLS:
			if str(tool.kind) != str(group[0]):
				continue
			print("    %-10s %s" % [str(tool.id), str(tool.what)])
			if str(tool.why) != "":
				print("               %s" % str(tool.why))
		print("")
	print("  THE LIST")
	print("    todo       what has been asked for and is not done")
	print("               read from docs/OUTSTANDING.md, which is the real one")
	print("")
	print("  NOT GODOT — run these yourself")
	for tool in SCRIPTS:
		print("    %-10s %s" % [str(tool.id), str(tool.what)])
		if str(tool.why) != "":
			print("               %s" % str(tool.why))
	print("")


## Every checker, in order, with a verdict at the end. The point of `all` is that
## it is one command before a push rather than six you have to remember.
func _run_all() -> int:
	var failed := 0
	var report: Array[String] = []
	for tool in TOOLS:
		if str(tool.kind) != "check":
			continue
		print("\n─── %s ─────────────────────────────────────" % str(tool.id).to_upper())
		var code := _launch(tool)
		if code != 0:
			failed += 1
			report.append("%s (%d)" % [str(tool.id), code])
	print("")
	print("══════════════════════════════════════════════")
	if failed == 0:
		print("  all clear")
	else:
		print("  %d of the checkers are unhappy: %s" % [failed, ", ".join(report)])
	print("")
	return failed


## Godot cannot run a second SceneTree script inside this one, so each tool is a
## child process. Blocking on purpose — `all` is a sequence, and interleaved
## output from six tools would be unreadable.
func _launch(tool: Dictionary, extra: PackedStringArray = []) -> int:
	var args: PackedStringArray = ["--path", ".", "--script", str(tool.script)]
	## Some checkers rasterise. `--headless` is faster where it is allowed and
	## fatal where it is not, so the tool says which it is.
	if not bool(tool.get("window", false)) and str(tool.kind) == "check":
		args.append("--headless")
	else:
		args.append_array(["--resolution", "1600x900"])
	## AND ANYTHING THE CALLER TYPED AFTER THE TOOL'S NAME GOES THROUGH.
	##
	## This file's whole claim is that it is ONE DOOR to every tool, and it was
	## not: `_launch` built a fixed argument list and silently dropped the rest,
	## so `SkyGear Tools.bat lab --mount --fit crew` opened the lab on nothing in
	## particular and the owner could not reach a tool through the front door
	## that the tool's own header documents. A dispatcher that quietly discards
	## half of what you typed is worse than one that refuses it.
	##
	## `OS.get_cmdline_user_args()` is what the tool reads, and the engine fills
	## it from everything after a bare `--`, so that separator has to be here.
	if not extra.is_empty():
		args.append("--")
		args.append_array(extra)
	var out: Array = []
	var code := OS.execute(_godot_path(), args, out, true)
	var raised := 0
	for line in out:
		var text := str(line).strip_edges(false, true)
		print(text)
		raised += text.count("SCRIPT ERROR")
	## A TOOL THAT RAISES CANNOT REPORT GREEN (SG-149).
	##
	## The harness printed fifteen `SCRIPT ERROR` lines and exited 0, and `all`
	## called that a clear run — for a long time, because the only thing read
	## here was the exit code, and a GDScript runtime error does not touch the
	## exit code. It is not an exception: it prints, abandons the rest of the
	## function it was raised in, and returns to the caller as though the call
	## had completed. So the checks after it in that function never ran and the
	## verdict was still "all clear".
	##
	## The harness now watches its own errors from the inside, which is the
	## better half — but only the harness has a `_check` to hang that on, and
	## `text`, `balance`, `timing`, `motion`, `model`, `clip`, `still`, `rune`
	## and `layout` do not. This is the half that covers them: we are already
	## holding every line each one printed, so the gate costs a substring count.
	##
	## Deliberately does NOT override a nonzero code — a tool that already failed
	## keeps its own failure count, which is what the report prints.
	if raised > 0 and code == 0:
		print("\n  %s exited 0 with %d raised SCRIPT ERROR — counting that as a failure (SG-149)."
			% [str(tool.id), raised])
		return raised
	return code


## The running executable, so the hub launches the same build it is running in
## rather than whatever `godot` happens to mean on this machine.
func _godot_path() -> String:
	var exe := OS.get_executable_path()
	return exe if exe != "" else GODOT
