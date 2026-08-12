extends SceneTree
## MEASURE FIRST. What physical pixel height does each HUD string actually get on
## the player's screen?
##
## `tools/text_audit.gd` reports the CANVAS point size — the number handed to
## `draw_string` in the 1920x1080 design space, floored at `SkyGearInk.MIN_PT`.
## But the game ships `window/stretch/mode="canvas_items"` with the HUD a
## full-rect Control in a CanvasLayer, so that 1920 layout is NEVER reflowed — it
## is scaled whole to the window. A `pt` glyph is therefore
## `SkyGearInk.physical_pt(pt, window_w)` physical pixels tall, and MIN_PT was
## chosen to survive only the 0.83 downscale of a 1600 window: at 1280 every 12pt
## string is 8 physical pixels, the sub-pixel-stem smudge MIN_PT exists to avoid.
##
## This probe poses every screen at the REAL 1920 layout (not a reflow the game
## never renders), reads the size each string is actually drawn at, and projects
## it to physical pixels at each width a player might run — so the number it
## prints is the number on screen. It shares the poses with the audit via
## `tools/screens.gd`. The floor and the downscale arithmetic are read from
## `scripts/ink.gd`, the one place they are written down.
##
##   godot --path . --headless --script tools/legibility_probe.gd
const Screens := preload("res://tools/screens.gd")

const SCREENS := Screens.SCREENS
## The widths the audit poses, plus the 1280 the game NO LONGER opens at, kept
## here so the report shows what the minimum window is protecting against.
const WIDTHS := [1280.0, 1600.0, 1920.0, 2560.0]
## The layout the real game always draws — the 1920 canvas. The probe poses THIS
## and scales it, rather than reflowing, because reflow never happens in play.
const REAL_LAYOUT := Vector2(1920, 1080)

## THE MISSING MODE. Every other caller in this file (and every UI tool —
## `tools/screen_shot.gd:70-76`, `scripts/screen_poser.gd:102-103`) deliberately
## disables content scale to measure the design-space layout directly; that is
## correct for measurement and none of those ten sites are wrong. But it also
## means NOTHING has ever posed with the shipped scaling engaged and NOTHING has
## ever posed fullscreen — the two things the real player's window actually does.
## `--shipped` is that missing mode: content scale stays on (whatever
## `project.godot` says — canvas_items, keep-aspect, as of build-72 task 16), and
## the window goes REAL fullscreen (`WINDOW_MODE_FULLSCREEN`, matching the
## project's own `window/size/mode=3`) rather than a windowed size this probe
## invents. The requested size is the declared floor, but fullscreen borderless
## snaps to the real display's own resolution the instant it engages — that is
## the honest shipped behaviour, not a bug in the probe, and the report prints
## the OBSERVED window size for exactly this reason rather than assuming the
## request was honoured. Its own constant, deliberately NOT
## `scripts/screen_poser.gd`'s `SIZES` — `parity_test.gd:14350` asserts that
## array equals the screens tool's own copy, so editing it for a probe-only mode
## would break tool-parity first.
const SHIPPED_WIDTHS := [SkyGearInk.MIN_SUPPORTED_W]

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	var shipped: bool = OS.get_cmdline_user_args().has("--shipped")
	if shipped:
		## Leave `root.content_scale_mode` exactly as `project.godot` set it at
		## boot — that is the entire point of this mode — and go fullscreen at
		## the declared floor rather than force a windowed size.
		DisplayServer.window_set_size(Vector2i(SHIPPED_WIDTHS[0], SHIPPED_WIDTHS[0] * 9 / 16))
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
		root.content_scale_size = Vector2i.ZERO
		DisplayServer.window_set_size(Vector2i(1600, 900))
	await process_frame
	await process_frame

	var world = load("res://scenes/main3d.tscn").instantiate()
	root.add_child(world)
	await process_frame
	var game = world.get_node("SkyGear")
	var hud = game.hud

	## Keyed by "screen|text": the design-space size the real 1920 layout draws it
	## at (the smallest across screens where the same string recurs).
	var drawn := {}
	for screen in SCREENS:
		await Screens.pose(self, game, hud, screen, REAL_LAYOUT)
		hud.ink = []
		hud.audit = null
		hud.queue_redraw()
		await process_frame
		for s in hud.ink:
			var key: String = "%s|%s" % [str(screen.name), str(s.text)]
			if not drawn.has(key) or int(s.pt) < int(drawn[key].pt):
				drawn[key] = {"screen": str(screen.name), "text": str(s.text),
					"pt": int(s.pt)}
		hud.ink = null

	var rows: Array = drawn.values()
	## Physical size is monotonic in the design-space point size (same downscale),
	## so smallest-first by `pt` is smallest-first on the player's screen.
	rows.sort_custom(func(a, b): return int(a.pt) < int(b.pt))

	var floor_px := SkyGearInk.MIN_PHYS_PX

	if shipped:
		## THE FIRST TIME THE SHIPPED PATH HAS BEEN MEASURED. `root.content_scale_mode`
		## was never touched above, so Godot itself — not this probe's arithmetic — is
		## doing the canvas_items/keep-aspect downscale, in a real WINDOW_MODE_FULLSCREEN
		## window at the declared floor. The observed window size is read back rather
		## than assumed, so a stretch setting that silently changed (the exact drift
		## `window/stretch/aspect="keep"` now pins) would show up here as a size that
		## does not match SHIPPED_WIDTHS.
		var win_size := DisplayServer.window_get_size()
		var under := 0
		for r in rows:
			if SkyGearInk.physical_pt(int(r.pt), float(win_size.x)) < floor_px:
				under += 1
		print("")
		print("LEGIBILITY PROBE --shipped  ·  content scale ON, real fullscreen window")
		print("  declared floor %d wide · observed window %d x %d · mode %d"
			% [SHIPPED_WIDTHS[0], win_size.x, win_size.y, DisplayServer.window_get_mode()])
		print("  floor %.0f physical px" % floor_px)
		print("")
		print("  at the shipped path : %d of %d strings under %.0f px"
			% [under, rows.size(), floor_px])
		print("")
		print("     PT   PHYS   SCREEN                 STRING")
		var show_s: int = mini(28, rows.size())
		for i in show_s:
			var r: Dictionary = rows[i]
			var phys := SkyGearInk.physical_pt(int(r.pt), float(win_size.x))
			var mark := " " if phys >= floor_px else "s"
			var quoted: String = str(r.text).replace("\n", " ")
			if quoted.length() > 24:
				quoted = quoted.substr(0, 21) + "..."
			print("   %s %3d  %5.1f   %-22s %s" % [mark, int(r.pt), phys,
				str(r.screen).substr(0, 22), quoted])
		print("")
		## Exit code is the count under the floor on the actual shipped path.
		quit(under)
		return

	var min_w := float(SkyGearInk.MIN_WINDOW_W)
	var under := 0
	var under_1280 := 0
	for r in rows:
		if SkyGearInk.physical_pt(int(r.pt), min_w) < floor_px:
			under += 1
		if SkyGearInk.physical_pt(int(r.pt), 1280.0) < floor_px:
			under_1280 += 1

	print("")
	print("LEGIBILITY PROBE  ·  physical height of every HUD string on the real screen")
	print("  1920 canvas · stretch=canvas_items (no reflow) · phys = pt * window/%.0f"
		% SkyGearInk.BASE_W)
	print("  floor %.0f physical px · min window %.0f wide (%.2fx)"
		% [floor_px, min_w, min_w / SkyGearInk.BASE_W])
	print("")
	print("  at the %.0f min window : %d of %d strings under %.0f px"
		% [min_w, under, rows.size(), floor_px])
	print("  at a 1280 window       : %d of %d strings under %.0f px  <- what the"
		% [under_1280, rows.size(), floor_px])
	print("                           minimum window now prevents")
	print("")
	print("     PT   @1280  @1600  @1920   SCREEN                 STRING")
	var show: int = mini(28, rows.size())
	for i in show:
		var r: Dictionary = rows[i]
		var p1280 := SkyGearInk.physical_pt(int(r.pt), 1280.0)
		var p1600 := SkyGearInk.physical_pt(int(r.pt), 1600.0)
		var p1920 := SkyGearInk.physical_pt(int(r.pt), 1920.0)
		var mark := " " if p1600 >= floor_px else "s"
		var quoted: String = str(r.text).replace("\n", " ")
		if quoted.length() > 24:
			quoted = quoted.substr(0, 21) + "..."
		print("   %s %3d  %5.1f  %5.1f  %5.1f   %-22s %s" % [mark, int(r.pt),
			p1280, p1600, p1920, str(r.screen).substr(0, 22), quoted])
	print("")
	print("  the middle column (@1600) is the floor case: %.0f px, the edge MIN_PT"
		% SkyGearInk.physical_pt(SkyGearInk.MIN_PT, min_w))
	print("  was calibrated for. 's' marks a string that would fall under it.")
	print("")
	## Exit code is the count under the floor at the min window — zero once the
	## window minimum holds, so this gates a build too.
	quit(under)
