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
		"what": "the whole simulation, 338 checks",
		"why": "the one thing that must be green before anything ships"},
	{"id": "text", "kind": "check", "script": "tools/text_audit.gd", "window": true,
		"what": "every string on 16 screens at 4 resolutions",
		"why": "catches text drawn over the frame, clipped, or two widgets sharing pixels"},
	{"id": "balance", "kind": "check", "script": "tools/balance.gd",
		"what": "simulated runs, wave by wave",
		"why": "whether twelve waves is still a curve rather than a wall"},
	{"id": "timing", "kind": "check", "script": "tools/anim_timing.gd",
		"what": "every clip against the skill that plays it",
		"why": "an attack whose animation does not fit its cooldown"},
	{"id": "motion", "kind": "check", "script": "tools/anim_motion.gd",
		"what": "root drift per clip, in GROUND units",
		"why": "a clip that walks the mesh off the position the simulation gave her"},
	{"id": "model", "kind": "check", "script": "tools/verify_model.gd",
		"what": "an ingested rig: height, bones, clips, materials",
		"why": "whether a model will actually stand on the deck"},

	{"id": "fit", "kind": "window", "script": "tools/weapon_fit.gd",
		"what": "the captain holding her weapon, six poses, live",
		"why": "arrow keys nudge, S saves — the grip is a dozen small numbers"},

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
