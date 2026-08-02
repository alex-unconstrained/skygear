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
		"what": "the whole simulation, 532 checks",
		"why": "the one thing that must be green before anything ships"},
	{"id": "text", "kind": "check", "script": "tools/text_audit.gd", "window": true,
		"what": "every string on 21 screens at 4 resolutions — fit, size, contrast, overlap and drift",
		"why": "text over the frame, clipped, too small, or the same colour as the brass"},
	{"id": "balance", "kind": "check", "script": "tools/balance.gd",
		"what": "simulated runs, wave by wave",
		"why": "whether twelve waves is still a curve rather than a wall"},
	{"id": "stow", "kind": "check", "script": "tools/stow.gd",
		"what": "the seeded stowage, 40 seeds x 12 waves: a vent per lane, kegs 200 apart, crossings passable, cover in its band",
		"why": "what stops a rolled deck from dealing SHIP-AND-MAPS §7.3's keg chain before a playtest finds it"},
	{"id": "timing", "kind": "check", "script": "tools/anim_timing.gd",
		"what": "every clip against the skill that plays it",
		"why": "an attack whose animation does not fit its cooldown"},
	{"id": "motion", "kind": "check", "script": "tools/anim_motion.gd",
		"what": "root drift per clip, in GROUND units",
		"why": "a clip that walks the mesh off the position the simulation gave her"},
	{"id": "model", "kind": "check", "script": "tools/verify_model.gd",
		"what": "an ingested rig: height, bones, clips, materials",
		"why": "whether a model will actually stand on the deck"},

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
		"what": "THE BATCH-EVIDENCE MODE: photograph all 21 screens at all 4 widths and open them as one page",
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

	for tool in TOOLS:
		if str(tool.id) == want:
			quit(_launch(tool))
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
func _launch(tool: Dictionary) -> int:
	var args: PackedStringArray = ["--path", ".", "--script", str(tool.script)]
	## Some checkers rasterise. `--headless` is faster where it is allowed and
	## fatal where it is not, so the tool says which it is.
	if not bool(tool.get("window", false)) and str(tool.kind) == "check":
		args.append("--headless")
	else:
		args.append_array(["--resolution", "1600x900"])
	var out: Array = []
	var code := OS.execute(_godot_path(), args, out, true)
	for line in out:
		print(str(line).strip_edges(false, true))
	return code


## The running executable, so the hub launches the same build it is running in
## rather than whatever `godot` happens to mean on this machine.
func _godot_path() -> String:
	var exe := OS.get_executable_path()
	return exe if exe != "" else GODOT
