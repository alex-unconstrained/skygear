extends SceneTree

## Take the HUD layout you just dragged into place and make it the one that ships.
##
##     SkyGear Tools.bat layout            what you have, and whether it holds up
##     SkyGear Tools.bat layout -- write   promote it into the repo
##
## WHY THIS EXISTS. F4 in-game opens the layout editor, and Ctrl+S there writes
## `user://hud_layout.json` — which on Windows is
## `%APPDATA%\Godot\app_userdata\SkyGear\`, nowhere near this repository. So a
## careful hand-alignment pass lives on one machine, is invisible to git, and is
## lost the moment the user data folder is cleared. `load_layout` prefers the
## user file over the shipped one, so it LOOKS permanent to the person who made
## it and does not exist for anybody else. That gap is the whole reason a manual
## pass has never landed before.
##
## And it VALIDATES before promoting. `problems()` is the same check the harness
## runs — off screen, in the top half where boarders arrive, overlapping another
## plate, an item outside its own plate. A hand-placed layout is placed at one
## window size, and the point of failure is every other one, so the check runs
## at four widths rather than the one the author happened to be using.

const SIZES := [Vector2(1280, 720), Vector2(1600, 900), Vector2(1920, 1080),
	Vector2(2560, 1080)]


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var write := "write" in args or "--write" in args

	var user_path: String = SkyGearHudLayout.USER_PATH
	var shipped: String = SkyGearHudLayout.SHIPPED_PATH
	print("")
	if not FileAccess.file_exists(user_path):
		print("  NOTHING TO PROMOTE.")
		print("  No layout at %s" % ProjectSettings.globalize_path(user_path))
		print("")
		print("  Run the game, press F4, drag the plates, Ctrl+S. Then come back.")
		print("")
		quit(0)
		return

	## Read the USER file specifically, not `load_layout()` — that one falls back
	## to the shipped file when the user file is unreadable, and promoting the
	## shipped file over itself while reporting success is exactly the sort of
	## quiet no-op this project has shipped before.
	var raw := FileAccess.get_file_as_string(user_path)
	var parsed = JSON.parse_string(raw)
	if parsed is not Dictionary or not (parsed as Dictionary).has("plates"):
		print("  UNREADABLE. %s is not a layout." % user_path)
		print("")
		quit(1)
		return

	var layout := SkyGearHudLayout.new()
	layout.plates = parsed.get("plates", {})
	layout.slot_items = parsed.get("slot_items", {})
	## The screen-element offsets (SG-42), SANITISED on the way through — a
	## malformed entry is dropped here exactly as the loader would drop it, so
	## what gets promoted is what the game will actually read.
	layout.screens = SkyGearHudLayout._sanitise_screens(parsed.get("screens", {}))

	print("  YOUR LAYOUT   %s" % ProjectSettings.globalize_path(user_path))
	print("  SHIPS AS      %s" % ProjectSettings.globalize_path(shipped))
	print("")
	if not layout.screens.is_empty():
		var parts: Array[String] = []
		for screen in layout.screens.keys():
			parts.append("%s %d" % [str(screen), (layout.screens[screen] as Dictionary).size()])
		print("  SCREEN OFFSETS  %s" % " · ".join(parts))
		print("")

	## Every width, because a layout is authored at one and has to survive the
	## rest. This is the check that catches "it looked perfect on my monitor".
	var total := 0
	for view in SIZES:
		var problems: Array = layout.problems(view)
		total += problems.size()
		if problems.is_empty():
			print("  %dx%-6d  holds" % [int(view.x), int(view.y)])
			continue
		print("  %dx%-6d  %d problem(s)" % [int(view.x), int(view.y), problems.size()])
		for line in problems:
			print("       %s" % str(line))
	print("")

	if total > 0:
		## Refused rather than warned. A layout with a plate off the edge of an
		## ultrawide is a layout that ships a broken HUD to anyone who does not
		## own the monitor it was made on.
		print("  NOT PROMOTED — fix the above in F4 first, or pass `force`.")
		if not ("force" in args or "--force" in args):
			print("")
			quit(1)
			return
		print("  ...forced anyway.")

	if not write:
		print("  Looks good. Run `SkyGear Tools.bat layout -- write` to promote it.")
		print("")
		quit(0)
		return

	var out := FileAccess.open(shipped, FileAccess.WRITE)
	if out == null:
		print("  COULD NOT WRITE %s" % shipped)
		print("")
		quit(1)
		return
	out.store_string(JSON.stringify(
		{"version": 3, "plates": layout.plates, "slot_items": layout.slot_items,
			"screens": layout.screens},
		"  "))
	out.close()
	print("  PROMOTED. `git diff assets/hud_layout.json` to see what moved.")
	print("")
	## And a reminder, because the user file still WINS on load — so the person
	## who did the pass keeps seeing their own copy either way and cannot tell
	## from playing whether the promotion worked.
	print("  Note: your user file still overrides this locally. Delete it to")
	print("  see what everyone else will get.")
	print("")
	quit(0)
