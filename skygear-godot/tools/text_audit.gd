extends SceneTree
## STILL: NOT APPLICABLE — this measures a 2D HUD SCREEN, not the deck (SG-108).
## Its two exposures differ only by `hud.hide_text`, both are of a posed static
## menu with no rig and no particle system in it, and it already waits on
## `RenderingServer.frame_post_draw` so the readback is of a finished frame.
## Does any text fall outside the frame it belongs to — and can you read it?
##
## Reported: "the text spacing on a lot of cards is off and the text begins
## outside of the frame and continues over onto the right so it's hard to read."
## That is not one card. It is a class of bug, and a class of bug wants a
## detector rather than a fix — otherwise the next panel added reintroduces it
## and nobody notices until someone plays.
##
## HOW IT WORKS. `SkyGearHUD` routes every string it draws through `_say`, which
## when an auditor is attached records the string, the box it was given, the
## width it actually measured, and the interior of the panel that was open at the
## time. Two failures are possible and they are different bugs:
##
##   OVERFLOW  the string is wider than the width it was handed, so `draw_string`
##             clips it. "Boiler gains 150 max HP and re".
##   OUTSIDE   the box is fine but it sits on or past the panel's brass rail, so
##             the text is drawn over the frame art. This is the reported one.
##
## Both are measured against the SAME rail the renderer draws, which is the whole
## point: the bug was that `interior()` believed the rail was thirty pixels while
## `_nine` drew forty-eight, so every panel laid its content out against a frame
## eighteen pixels narrower than the one on screen.
##
## AND THEN: CAN YOU ACTUALLY READ IT.
##
## The two checks above went green and the next report was "text on skills and
## cards and HUD elements is hard to read". They were never the same question.
## Containment is satisfied by shrinking a label until it fits, which is what
## `_fits` does, silently, down to 7pt — a containment PASS that is a legibility
## failure. And a string can sit dead centre of its frame in a colour three
## shades from the brass it is painted on.
##
##   SMALL     too small ON THE PLAYER'S SCREEN. The point-size floor is applied
##             at the funnel, so `pt` in design space is always >= MIN_PT and a
##             `pt`-vs-MIN_PT test can never fire — that is the check that let a
##             re-clamped 7pt label pass. But the 1920 canvas is scaled to the
##             window, so the physical height is `pt * window/1920`, and at the
##             narrowest window the game opens (SkyGearInk.MIN_WINDOW_W) that must
##             still clear SkyGearInk.MIN_PHYS_PX physical pixels.
##   FAINT     the WCAG contrast between the glyph and what is BEHIND it is
##             under the floor for that colour
##
## FAINT is measured, not assumed. The plates are painted brass with rivets and
## scratches in them, so "the panel colour" is a fiction — the pass renders each
## screen twice, once normally and once with `hud.hide_text` suppressing every
## glyph and nothing else, reads the second frame back off the GPU, and samples
## the real pixels under each string's box. What it reports is the tenth
## percentile: the contrast against the worst tenth of the background, because a
## word is unreadable if a tenth of it is, not if the average is fine.
##
##   godot --path . --script tools/text_audit.gd
##   godot --path . --script tools/text_audit.gd -- --verbose
##   godot --path . --script tools/text_audit.gd -- --ink      legibility only
##
## Exit code is the number of violations, so it can gate a build.
const Screens := preload("res://tools/screens.gd")

func _initialize() -> void: call_deferred("_run")

## The screens, and the poses that produce them, live in `tools/screens.gd` —
## shared with `tools/screen_shot.gd` so the frame you LOOK at is the same frame
## this measures. They were here, and a screenshot tool that posed its own
## Workshop would have been two answers to "what is on this screen".
const SCREENS := Screens.SCREENS
const SIZES := Screens.SIZES

## The one size the contrast pass runs at, because it is the only one where the
## numbers mean anything: contrast has to be read back off the GPU, and a
## readback only tells the truth when the window, the canvas and the HUD are all
## the same size. Point size is checked at all four — a narrow window is exactly
## where `_fits` shrinks a label the furthest.
const INK_AT := Vector2(1600, 900)


func _run() -> void:
	## Refuse headless up front. The contrast pass reads frames back off the
	## GPU, and there is no GPU under --headless — the readback would stall
	## forever at `await frame_post_draw` (SG-29).
	if not SkyGearRendererCheck.can_capture():
		print(SkyGearRendererCheck.capture_refusal())
		quit(2)
		return
	var args := OS.get_cmdline_user_args()
	var verbose := "--verbose" in args
	var ink_only := "--ink" in args

	## A DETERMINISTIC CANVAS, or the readback is meaningless.
	##
	## The project ships fullscreen with `canvas_items` stretch, so out of the box
	## a 1920x1080 canvas is rendered into a 2560x1600 window with a keep-aspect
	## letterbox — the frame that comes back off the GPU is neither the size of
	## the HUD nor a whole multiple of it. Windowed, unscaled, at INK_AT means one
	## HUD unit is one pixel and the box the renderer reported is the box we
	## sample. The containment pass does not care: it is arithmetic on rectangles
	## and never looks at the window.
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	DisplayServer.window_set_size(Vector2i(int(INK_AT.x), int(INK_AT.y)))
	await process_frame

	var world = load("res://scenes/main3d.tscn").instantiate()
	root.add_child(world)
	await process_frame
	var game = world.get_node("SkyGear")
	var hud = game.hud

	var findings: Array = []
	var strings: Array = []
	for size in SIZES:
		for screen in SCREENS:
			await _pose(game, hud, screen, size)
			var batches: Array = [null]
			if str(screen.state) == "DRAFT" and size == SIZES[1]:
				batches = _every_card(game)
			for batch in batches:
				if batch != null:
					game.draft_options.clear()
					for card in batch:
						game.draft_options.append(card)
				## SIZE, at every resolution. Free — it is whatever the renderer
				## passed to `draw_string` after every clamp and shrink, and the
				## funnel already knows it.
				hud.ink = []
				hud.audit = [] if not ink_only else null
				hud.queue_redraw()
				await process_frame
				var measured: Array = hud.ink
				hud.ink = null
				for s in measured:
					s["screen"] = str(screen.name)
					s["at"] = "%dx%d" % [int(size.x), int(size.y)]
					s["contrast"] = -1.0
					strings.append(s)
				## CONTRAST, at the one size the window agrees with.
				if size == INK_AT:
					await _shade(hud, measured)
				## AND NO TWO STRINGS ON THE SAME PIXELS.
				##
				## There is already a COLLIDE check and it could not see this. It
				## compares WIDGET rectangles out of `ui.declared()`, and the two things
				## that actually collided in the shipped build were free-drawn
				## announcements — "WAVE 1" and "WAVE CLEAR", both centred, both at the
				## same y, printed through each other into something nobody can read.
				## Neither is a widget, so neither was ever in the input set.
				##
				## The same shape of hole as the drift pass: the check existed, and the
				## thing it was meant to catch was not among what it was handed.
				##
				## HALF the smaller box, and the number was measured rather than
				## picked. A string's box is its LINE box, taller than the glyphs in it,
				## so two stacked labels one leading apart overlap by real area while
				## their ink never touches — BOILER over WAVE 1/12 on the objective
				## plate is 44% and is perfectly readable on screen. The banner printed
				## through a draft card is 51%. Between those two is the line, and it is
				## narrow enough to say out loud: this pass finds text laid ON text, and
				## a tight stack can still slip under it.
				## The same string at the same box twice is a DOUBLE DRAW, not a
				## collision — the end screens redraw once more inside the capture
				## window and every label came back paired with itself. Worth its own
				## check one day; it is not this one, and leaving it in here would
				## have buried the real finding under forty copies of "Esc".
				##
				## The math lives in `SkyGearHUD.overprints` now, SHARED with the F4
				## editor's live verdict — one function, so the editor and this audit
				## cannot disagree about what "printed through" means (SG-42).
				for hit in SkyGearHUD.overprints(measured):
					hit["screen"] = str(screen.name)
					hit["at"] = "%dx%d" % [int(size.x), int(size.y)]
					findings.append(hit)
				if hud.audit == null:
					continue
				for hit in hud.audit:
					hit["screen"] = str(screen.name)
					hit["at"] = "%dx%d" % [int(size.x), int(size.y)]
					findings.append(hit)
				## AND NO TWO WIDGETS ON THE SAME PIXELS, AND EVERY WIDGET INSIDE
				## THE PLATE IT WAS DECLARED ON. The string audit cannot see either:
				## it measures each label against the frame it is in, and two
				## overlapping buttons each contain their own label perfectly —
				## adding the Heat row put DIFFICULTY, CAPTAIN and THE WORKSHOP on
				## top of one another and every check passed. And a button positions
				## its own label, so a centred word in a 300-wide button is inside
				## that button wherever the button is — including a foot to the left
				## of the sheet it belongs to, where four pause buttons were.
				##
				## The math lives in `SkyGearUI.collisions` now, SHARED with the F4
				## editor's live verdict — one function, one meaning of "colliding"
				## (SG-42).
				for hit in SkyGearUI.collisions(hud.ui.declared()):
					hit["screen"] = str(screen.name)
					hit["at"] = "%dx%d" % [int(size.x), int(size.y)]
					findings.append(hit)
				## AND A STILL SCREEN HAS TO ACTUALLY BE STILL.
				##
				## Reported by the user as "the popup menus drifting right", and every
				## check above is blind to it BY CONSTRUCTION: each one poses a screen,
				## draws it ONCE, and measures that single frame. A menu that is laid
				## out correctly and then walks two pixels right on every redraw passes
				## all of them, at every resolution, forever.
				##
				## Nothing on a menu is animated, so the invariant is as strong as it
				## gets: hold the pose, redraw, and every rectangle must land on the
				## same pixels it did a second ago. PLAY is the one screen this cannot
				## be asked of — the simulation is running underneath it and its
				## readouts are supposed to move.
				## At EVERY width, not just the one the contrast pass needs. Drift is
				## arithmetic on the layout, and the layout is the one thing in the HUD
				## that changes shape with the window — a sheet that only walks on an
				## ultrawide is exactly the bug that would survive a single-size check.
				if batch == null and str(screen.state) != "PLAY":
					findings.append_array(await _drift(hud, str(screen.name), size))
				hud.audit = null

	## Grouped by what is broken rather than by where it was found: the same
	## string wrong at four resolutions is one bug, and a list that reports it
	## four times reads as four.
	var groups := {}
	for f in findings:
		var key := "%s|%s|%s" % [str(f.screen), str(f.kind), str(f.text)]
		if not groups.has(key):
			groups[key] = {"count": 0, "sample": f, "sizes": []}
		groups[key].count += 1
		var at := str(f.at)
		if at not in groups[key].sizes:
			groups[key].sizes.append(at)

	print("")
	print("TEXT AUDIT  ·  %d screens x %d sizes  ·  %d strings drawn"
		% [SCREENS.size(), SIZES.size(), strings.size()])
	print("")
	if groups.is_empty():
		print("  CONTAINMENT  every string fits the box it was given and sits inside")
		print("               its frame.")
		print("")
		quit(_ink_report(strings, verbose))
		return

	## By screen, so the report reads as a list of places to go and fix rather
	## than a shuffled pile.
	var order: Array = groups.keys()
	order.sort_custom(func(a, b):
		var fa: Dictionary = groups[a].sample
		var fb: Dictionary = groups[b].sample
		if str(fa.screen) != str(fb.screen):
			return str(fa.screen) < str(fb.screen)
		return str(fa.kind) < str(fb.kind))
	var outside := 0
	var overflow := 0
	var last_screen := ""
	for key in order:
		var g: Dictionary = groups[key]
		var f: Dictionary = g.sample
		if str(f.kind) in ["OUTSIDE", "COLLIDE", "WIDGET"]:
			outside += 1
		else:
			overflow += 1
		if str(f.screen) != last_screen:
			last_screen = str(f.screen)
			print("  %s" % last_screen.to_upper())
		var quoted: String = str(f.text)
		if quoted.length() > 34:
			quoted = quoted.substr(0, 31) + "..."
		print("    %-8s \"%s\"" % [str(f.kind), quoted])
		if str(f.kind) == "OVERFLOW":
			print("             needs %.0f, given %.0f" % [float(f.measured), float(f.given)])
		elif str(f.kind) == "COLLIDE":
			print("             %s overlaps %s" % [_r(f.box), _r(f.frame)])
		elif str(f.kind) == "WIDGET":
			print("             widget %s, plate interior %s" % [_r(f.box), _r(f.frame)])
		else:
			print("             box %s, frame interior %s" % [_r(f.box), _r(f.frame)])
		if verbose:
			print("             at %s" % ", ".join(g.sizes))

	print("")
	print("%d distinct problems — %d text drawn over the frame, %d text clipped."
		% [groups.size(), outside, overflow])
	print("")
	quit(groups.size() + _ink_report(strings, verbose))


## --- can you read it ---------------------------------------------------------
##
## Returns the number of distinct strings that fail. Distinct: the same label at
## four resolutions is one problem, and the worst of the four is the one worth
## printing.
func _ink_report(strings: Array, verbose: bool) -> int:
	if strings.is_empty():
		print("  LEGIBILITY   nothing was drawn — the pass did not run.")
		return 0

	## ONE ROW PER STRING PER SCREEN. The same label at four resolutions is one
	## problem, and the row that survives has to carry the WORST of each column
	## independently — the smallest it was ever drawn, and the contrast, which
	## exists at one size only.
	##
	## Merging them into a single "badness" as they arrive gets this wrong and got
	## it wrong: a string first seen at 1280 with no contrast figure scored 1.00,
	## the measured instance at 1600 scored 1.02, ties kept the first, and two
	## genuinely faint strings sorted into the middle of a list of passes. Take
	## the worst of each column first, score afterwards.
	## The pose whose point sizes the REAL game draws. The 1920 canvas does not
	## reflow — `canvas_items` scales the whole layout to the window — so a narrower
	## pose shrinks boxes the game never narrows, and `_fits` shrinks text the game
	## never shrinks. Physical legibility is judged against the 1920 layout scaled
	## down to the narrowest window, not against a reflow that never renders.
	var base_at := "%dx%d" % [int(SkyGearInk.BASE_W), 1080]
	var seen := {}
	for s in strings:
		var key := "%s|%s" % [str(s.screen), str(s.text)]
		if not seen.has(key):
			seen[key] = s.duplicate()
			seen[key]["pt_base"] = int(s.pt) if str(s.at) == base_at else -1
			continue
		var row: Dictionary = seen[key]
		row["pt"] = mini(int(row.pt), int(s.pt))
		if str(s.at) == base_at:
			row["pt_base"] = int(s.pt)
		if float(s.contrast) >= 0.0 and (float(row.contrast) < 0.0
				or float(s.contrast) < float(row.contrast)):
			row["contrast"] = float(s.contrast)
			row["plate"] = s.get("plate", -1.0)
			row["bg"] = s.get("bg", Color.BLACK)
			row["tint"] = s.tint

	var rows: Array = seen.values()
	for r in rows:
		## How far under the floor, as a single number, so a string that is too
		## small and a string that is too faint can be sorted against each other.
		## Above 1.0 is a failure in one of the two.
		r["need"] = SkyGearInk.floor_for(r.tint)
		## PHYSICAL size, not design-space points. The point-size floor is applied
		## at the funnel so `pt` is always >= MIN_PT and a `pt`-vs-MIN_PT test can
		## never fire — that was the check that let a 7pt label pass once it had been
		## re-clamped. What can still be too small is what the player SEES: the real
		## (1920) point size scaled down to the narrowest window the game will open.
		var pt_real: int = int(r.pt_base) if int(r.get("pt_base", -1)) > 0 else int(r.pt)
		r["phys"] = SkyGearInk.physical_pt(pt_real, SkyGearInk.MIN_WINDOW_W)
		var bad: float = SkyGearInk.MIN_PHYS_PX / maxf(0.01, float(r.phys))
		if float(r.contrast) >= 0.0:
			bad = maxf(bad, float(r.need) / maxf(0.01, float(r.contrast)))
		r["bad"] = bad
	rows.sort_custom(func(a, b): return float(a.bad) > float(b.bad))

	var faint := 0
	var small := 0
	var lowest := 99.0
	var total := 0.0
	var counted := 0
	for r in rows:
		if float(r.phys) < SkyGearInk.MIN_PHYS_PX:
			small += 1
		if float(r.contrast) >= 0.0:
			if float(r.contrast) < float(r.need):
				faint += 1
			lowest = minf(lowest, float(r.contrast))
			total += float(r.contrast)
			counted += 1

	print("  LEGIBILITY   %d distinct strings · %d of them sampled from the frame"
		% [rows.size(), counted])
	print("               rendered at %dx%d" % [int(INK_AT.x), int(INK_AT.y)])
	print("")
	print("               floor %.1f contrast (%.1f where the tint means dimmed), %dpt"
		% [SkyGearInk.CONTRAST_FLOOR, SkyGearInk.CONTRAST_FLOOR_MUTED, SkyGearInk.MIN_PT])
	print("               and %.0f physical px: the real (1920) size scaled to the"
		% SkyGearInk.MIN_PHYS_PX)
	print("               %d-wide window the game will open at (%.2fx downscale)."
		% [SkyGearInk.MIN_WINDOW_W, SkyGearInk.MIN_WINDOW_W / SkyGearInk.BASE_W])
	print("               RATIO is the stroke against what actually touches it;")
	print("               PLATE is the same stroke against the bare housing;")
	print("               PHYS is physical pixel height at the narrowest window.")
	print("               worst %.2f · mean %.2f · %d faint · %d small"
		% [lowest if counted > 0 else 0.0, total / maxf(1.0, float(counted)), faint, small])
	print("")

	var show: int = rows.size() if verbose else mini(22, rows.size())
	print("     RATIO  PLATE   PHYS  PT  SCREEN                 TINT    ON       STRING")
	for i in show:
		var r: Dictionary = rows[i]
		if float(r.bad) <= 1.0 and i >= 12:
			break
		var quoted: String = str(r.text).replace("\n", " ")
		if quoted.length() > 28:
			quoted = quoted.substr(0, 25) + "..."
		var mark := " "
		if float(r.phys) < SkyGearInk.MIN_PHYS_PX:
			mark = "s"
		if float(r.contrast) >= 0.0 and float(r.contrast) < float(r.need):
			mark = "F" if mark == " " else "*"
		print("   %s %5s  %5s  %5.1f %3d  %-22s %-7s %-8s %s" % [mark,
			("  --" if float(r.contrast) < 0.0 else "%.2f" % float(r.contrast)),
			("  --" if float(r.get("plate", -1.0)) < 0.0 else "%.2f" % float(r.plate)),
			float(r.phys), int(r.pt), str(r.screen).substr(0, 22),
			str(r.tint.to_html(false)),
			(str(r.get("bg", Color.BLACK).to_html(false)) if r.has("bg") else "--"),
			quoted])
	print("")
	if faint + small == 0:
		print("               every string clears both floors.")
	else:
		print("               F faint (under the contrast floor) · s small (under %.0f"
			% SkyGearInk.MIN_PHYS_PX)
		print("               physical px at the min window) · * both")
	print("")
	return faint + small


## What is actually behind each of those strings.
##
## Renders the same frame a second time with `hud.hide_text` on — every glyph
## suppressed, every plate, bar, icon, scrim and rivet exactly where it was —
## then reads the frame back off the GPU and samples the real pixels under each
## box. This is the whole reason the pass is not "look up the panel colour": the
## housings are painted brass with lit rivets in them, and the panel colour is
## nowhere on the plate.
func _shade(hud, measured: Array) -> void:
	if measured.is_empty():
		return
	hud.hide_text = true
	hud.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var frame: Image = root.get_texture().get_image()
	hud.hide_text = false
	hud.queue_redraw()
	if frame == null:
		return
	## One HUD unit should be one pixel, but the window manager gets a vote on
	## window size and a silently wrong mapping would sample the plate next door.
	var scale := Vector2(float(frame.get_width()) / maxf(1.0, hud.size.x),
		float(frame.get_height()) / maxf(1.0, hud.size.y))
	for s in measured:
		## AT FULL OPACITY, whatever alpha the frame happened to catch it at.
		##
		## The wave banner and the event card ramp their alpha in and out, and the
		## snapshot lands wherever it lands — which reported "WAVE 7" at 42pt and
		## 1.00, the ratio of a thing that is not being drawn yet. That is a frame
		## of an animation, not a legibility failure. What is worth knowing is
		## whether the banner is readable once it is UP, so the colour it is
		## heading for is the colour that gets measured. The alpha is still in the
		## record if a check ever wants it.
		var solid := Color(s.tint.r, s.tint.g, s.tint.b, 1.0)
		var got := _behind(frame, s.box, scale, solid)
		s["tint"] = solid
		s["plate"] = float(got.low)
		s["bg"] = got.bg
		## WHAT THE EYE IS ACTUALLY COMPARING THE STROKE AGAINST.
		##
		## For bare text that is the plate, and `plate` is the answer. For text
		## with a halo round it, every pixel touching the stroke is halo, and
		## scoring the glyph against brass two pixels further out would report a
		## fix that works as a fix that did nothing. So the surround is the halo
		## composited onto the worst plate pixel we found — which is a real
		## measurement of a real rendered background, not an assumption, because
		## the halo is translucent and what shows through it is that pixel.
		##
		## This is also why the report prints BOTH: a string whose plate figure is
		## 1.2 and whose surround figure is 13 is legible and still sitting on a
		## rivet, and that is a thing worth seeing before deciding a recess is
		## unnecessary.
		var surround: Color = got.bg
		if float(s.get("outline", 0.0)) > 0.0:
			surround = SkyGearInk.over(s.get("halo", Color.BLACK), got.bg)
		s["contrast"] = SkyGearInk.contrast(solid, surround)


## The contrast between a tint and the worst tenth of what is under it.
##
## Not the mean: a word is unreadable if a tenth of it disappears, and averaging
## the stroke that crosses a lit rivet with the dark channel either side reports
## the rivet as fine. Not the single worst pixel either — one specular highlight
## on one serif is not a legibility failure, and treating it as one turns the
## check into noise.
func _behind(frame: Image, box: Rect2, scale: Vector2, tint: Color) -> Dictionary:
	var x0: int = clampi(int(floor(box.position.x * scale.x)), 0, frame.get_width() - 1)
	var x1: int = clampi(int(ceil(box.end.x * scale.x)), 0, frame.get_width())
	var y0: int = clampi(int(floor(box.position.y * scale.y)), 0, frame.get_height() - 1)
	var y1: int = clampi(int(ceil(box.end.y * scale.y)), 0, frame.get_height())
	if x1 <= x0 or y1 <= y0:
		return {"low": -1.0, "bg": Color.BLACK}
	var step_x: int = maxi(1, (x1 - x0) / 40)
	var step_y: int = maxi(1, (y1 - y0) / 12)
	var ratios: Array[float] = []
	var worst := 99.0
	var worst_bg := Color.BLACK
	var x := x0
	while x < x1:
		var y := y0
		while y < y1:
			var bg: Color = frame.get_pixel(x, y)
			bg.a = 1.0
			## The tint composited onto that pixel, then measured against it. A
			## string at 30% alpha is 30% legible and a ratio that ignores alpha
			## says a banner that has faded to nothing is perfectly readable.
			var ratio: float = SkyGearInk.contrast(SkyGearInk.over(tint, bg), bg)
			ratios.append(ratio)
			if ratio < worst:
				worst = ratio
				worst_bg = bg
			y += step_y
		x += step_x
	if ratios.is_empty():
		return {"low": -1.0, "bg": Color.BLACK}
	ratios.sort()
	return {"low": ratios[mini(ratios.size() - 1,
		int(float(ratios.size()) * 0.10))], "bg": worst_bg}


## Every card the catalogue can offer, in threes. A draft screen is only ever
## three cards wide, but there are forty-one of them and the long titles are the
## ones that break the layout.
func _every_card(game) -> Array:
	var first := func(list: Array) -> int:
		return int(list[0]) if not list.is_empty() else 0
	var made: Array = []
	for entry in SkyGearCards.catalogue():
		if not (entry.get("can") as Callable).call(game):
			continue
		var card: Dictionary = (entry.get("make") as Callable).call(game, first)
		card["class_label"] = SkyGearCards.SCOPE_LABEL.get(str(entry.scope), "UPGRADE")
		card["scope"] = str(entry.scope)
		card["rarity"] = str(entry.rarity)
		made.append(card)
	var batches: Array = []
	for i in range(0, made.size(), 3):
		batches.append(made.slice(i, mini(i + 3, made.size())))
	return batches


func _r(v) -> String:
	var rect: Rect2 = v
	return "%.0f,%.0f %.0fx%.0f" % [rect.position.x, rect.position.y,
		rect.size.x, rect.size.y]


## Put the game into the state a screen needs. One line, because the poses moved
## to `tools/screens.gd` where the screenshot tool can reach them too.
func _pose(game, hud, screen: Dictionary, size: Vector2) -> void:
	await Screens.pose(self, game, hud, screen, size)

## HOLD A SCREEN AND SEE IF IT MOVES.
##
## Sixty redraws, which is a second at the rate the game runs. A drift slow
## enough to survive that is slow enough that nobody sees it either.
##
## Compared by index rather than by position, because position is the thing
## under test — matching rectangles up by where they are would quietly pair a
## drifted widget with whatever else had wandered into its place. The count
## changing is itself a finding: a still screen that grows a widget while you
## watch it is as wrong as one that slides.
const DRIFT_FRAMES := 60

func _drift(hud, screen: String, size: Vector2) -> Array:
	var out: Array = []
	var shot := func() -> Array:
		hud.queue_redraw()
		await process_frame
		var copy: Array = []
		for item in hud.ui.declared():
			copy.append(item.rect as Rect2)
		return copy

	var first: Array = await shot.call()
	for _i in DRIFT_FRAMES:
		hud.queue_redraw()
		await process_frame
	var last: Array = await shot.call()

	var tag := "%dx%d" % [int(size.x), int(size.y)]
	if first.size() != last.size():
		out.append({"kind": "DRIFT",
			"text": "widget count went %d -> %d while the screen sat still"
				% [first.size(), last.size()],
			"box": Rect2(), "frame": Rect2(), "measured": 0.0, "given": 0.0,
			"screen": screen, "at": tag})
		return out

	## One finding for the whole screen, naming the worst offender. Every widget
	## on a drifting sheet drifts, and sixteen identical lines would bury the one
	## fact that matters: this screen moves, and it moves THIS far in a second.
	var worst := 0.0
	var worst_at := -1
	var moved := 0
	var shove := Vector2.ZERO
	for i in first.size():
		var a: Rect2 = first[i]
		var b: Rect2 = last[i]
		var step: float = maxf(a.position.distance_to(b.position),
			(a.size - b.size).length())
		if step <= 0.5:
			continue
		moved += 1
		if step > worst:
			worst = step
			worst_at = i
			shove = b.position - a.position
	if moved == 0:
		return out

	## Say which way. "Drifting right" was the whole of the bug report, and a
	## direction is what turns a number into somewhere to look.
	var way := "right" if shove.x > 0.5 else ("left" if shove.x < -0.5 else "")
	if absf(shove.y) > absf(shove.x):
		way = "down" if shove.y > 0.5 else "up"
	out.append({"kind": "DRIFT",
		## Front-loaded, because the report truncates a long line and the
		## direction is the whole of what the reader needs.
		"text": "slides%s %.1fpx a second (%d of %d widgets)"
			% [(" " + way) if way != "" else "", worst, moved, first.size()],
		"box": last[worst_at], "frame": first[worst_at],
		"measured": 0.0, "given": 0.0, "screen": screen, "at": tag})
	return out
