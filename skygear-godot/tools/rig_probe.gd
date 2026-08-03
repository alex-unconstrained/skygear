extends SceneTree
## THE RIG'S KILL-TEST. Does the shadow lattice overhead cost a telegraph its
## legibility on the planking it is drawn on?
##
## DECK-IDENTITY-DESIGN item 1 pre-committed this gate before a line of the rig
## was written, and it outranks the feature: *"Any rune's measured edge contrast
## against planking below `ink.gd`'s floor where the lattice crosses it — and the
## rig is cut to the envelope alone."* Pillar 6 outranks atmosphere. A lattice
## that hides a telegraph is a bug wearing a mast.
##
##   godot --path . --resolution 1600x900 --script tools/rig_probe.gd -- <outdir>
##
## NOT --headless: the whole measurement is a framebuffer readback.
##
##
## WHICH FLOOR, AND WHY IT IS NOT THE ONE THE ITEM NAMED
##
## The item says "below `ink.gd`'s floor". `CONTRAST_FLOOR` is 4.5 and it is a
## floor for TEXT — a letter stroke against the surface it is painted on.
## DECK-IDENTITY §7.5 measured what a telegraph rune against planking actually
## scores in the SHIPPED build and got **1.91**. A gate nothing has ever passed
## cannot decide anything, and §7.5 says exactly that after SG-101 spent a
## session finding it out. So this tool prints the absolute number against 4.5
## for the record and DECIDES on the relative gate §7.5 established, which items
## 2 and 5 also use: **the rig may not cost a rune more than 3% of the contrast
## it has with the rig hidden.**
##
##
## HOW IT IS MEASURED, AND THE THREE WAYS THAT FAILED FIRST
##
## Two plates, one toggle, and NOTHING else happens between them — no simulation
## step, no effects cleared, no windup re-armed, no renderer tick. The rig's
## `visible` flag is the only difference between the two exposures.
##
## Getting to that took three wrong turns and each one is worth writing down,
## because each produced a confident wrong number:
##
##   1. **Re-arming the windups for a second exposure.** A windup's decal is
##      authored when the state is ENTERED, so re-entering it inside a stopped
##      simulation brought back one telegraph out of four. The second plate was
##      mostly bare planking and the tool read that as a rune that had lost its
##      contrast.
##   2. **Two independently-derived masks.** Deriving the rune pixels separately
##      from each pair compares two different sets of pixels and calls the
##      difference a result. The sets differed by a third.
##   3. **Diffing against `effects.clear()`.** A ranged windup's aim band is
##      drawn off the ENEMY'S OWN state, not out of the effects list, so the
##      "bare" plate came back still carrying the band —
##      `.shots/sg107/rig-bare-full-light.png` is that plate, with the band
##      plainly in it. The mask was then sensor noise, and the tool reported the
##      rig IMPROVING legibility by 60%.
##
## All three are §7.5's lesson arriving again: on this deck the measuring rig is
## reliably the least trustworthy thing in the experiment. What survives is the
## version that needs no second exposure at all — the rune is found by its own
## colour, and the planking it is read against is the ring of pixels immediately
## around it in the SAME plate. That is what "edge contrast against planking"
## means, and both plates are measured over the identical two pixel sets.
const TELEGRAPHS := [
	{"kind": "SCRAPPER", "at": Vector2(-150.0, 470.0)},
	{"kind": "ARMORED", "at": Vector2(150.0, 470.0)},
	{"kind": "SWARM", "at": Vector2(-360.0, 560.0)},
	{"kind": "GUNNER", "at": Vector2(360.0, 300.0)},
]
const TELEGRAPH_FRAC := 0.55
## Full light, and the wave-8 darkness floor the item named. `set_darkness(0.22)`
## is the worst light a telegraph is ever read in.
const LIGHTS := [{"name": "full light", "darkness": 0.0},
	{"name": "wave-8 floor", "darkness": 0.22}]
## THE RUNE, BY ITS OWN COLOUR. Every telegraph on this deck is a saturated
## red-to-amber warning drawn over grey-brown planking — the oxblood melee wedge
## and the ranged aim band both. Hue is taken in Godot's 0-1 turn, so the window
## below is roughly 0-40 degrees plus the wrap above 340.
const RUNE_SAT := 0.55
const RUNE_VAL := 0.42
const RUNE_HUE := 0.11
## The planking a rune is read against: the ring just outside it. 12 px at
## 1600x900 is about the width of the band itself, which is the distance an eye
## actually uses to find an edge.
const RING_PX := 12
## Every other pixel. A band is tens of thousands of pixels and the median of
## half of them is the same median.
const STEP := 2
## §7.5's relative gate.
const COST_GATE := 3.0

var _out_dir := "../.shots/sg107"


func _init() -> void:
	await process_frame
	var argv := OS.get_cmdline_user_args()
	if argv.size() > 0:
		_out_dir = str(argv[0])
	var out_dir := "res://%s" % _out_dir
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))

	var win := get_root()
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1600, 900))
	root.size = Vector2i(1600, 900)
	await process_frame

	var world: Node3D = load("res://scenes/main3d.tscn").instantiate()
	root.add_child(world)
	await process_frame
	var view: SkyGearView3D = world as SkyGearView3D
	var game: SkyGearGame = world.get_node("SkyGear")
	## The same three scars `marks_shot.gd` records: no cutscene to sit through,
	## no rows left in the player's run log, no impact shake inside a still.
	view.cutscenes_enabled = false
	view.stop_cutscene()
	game.log_runs = false
	if game.impact != null:
		game.impact.enabled = false
	game.workshop = SkyGearWorkshop.fresh(true)
	game.refresh_berthed()
	game.set_seed_text("RIG")
	game.begin_run()
	game.choose_draft(0)
	## THE WAVE-6 SET, which is what the item asked to be posed under the lattice.
	if game.wave != 6:
		game.start_wave(6)
	game.spawn_queue.clear()
	view.sway = false
	var overlay = game.get_node_or_null("HUD")
	if overlay != null:
		overlay.visible = false
	for _i in 20:
		game._process(1.0 / 60.0)
		await process_frame

	if view._rigging == null:
		push_error("no rigging in this build — nothing to measure")
		quit(1)
		return

	## The shipped composition: amidships, zoom 1.0, the 94% that is planking.
	game.player.global_position = Vector2(0.0, 200.0)
	game.player.velocity = Vector2.ZERO
	view._focus_set = false
	view._zoom = 1.0
	view._zoom_target = 1.0
	for t in TELEGRAPHS:
		game.spawn_enemy(str(t.kind), 1)
	var live: Array = game.get_tree().get_nodes_in_group("enemies")
	for i in mini(live.size(), TELEGRAPHS.size()):
		live[i].global_position = TELEGRAPHS[i].at
		live[i].state = "move"
	for _i in 6:
		game._process(1.0 / 60.0)
		await process_frame

	print("")
	print("  THE RIG UNDER ITS OWN KILL-TEST")
	print("  wave-6 windups at the shipped pose, amidships, zoom 1.00")
	print("  %d rig pieces overhead · shroud radius %.1f · shadow blur %.1f"
		% [view._rigging.get_child_count(), SkyGearView3D.RIG_SHROUD_RADIUS,
			view._moon.shadow_blur])
	print("")

	var verdict_ok := true
	var measured_any := false
	for light in LIGHTS:
		var rows := await _measure(view, game, live, float(light.darkness),
			str(light.name), out_dir)
		var with_rig: float = float(rows.with_rig)
		var without: float = float(rows.without)
		var cost: float = 0.0 if without <= 0.0 else (without - with_rig) / without * 100.0
		print("  %s  (darkness %.2f)" % [str(light.name), float(light.darkness)])
		print("    rune pixels found                %d" % int(rows.pixels))
		print("    planking ring around them        %d px" % int(rows.ring))
		print("    edge contrast, rig overhead      %.3f" % with_rig)
		print("    edge contrast, rig hidden        %.3f" % without)
		print("    what the lattice costs the rune  %+.2f%%   (gate: %.2f%%)"
			% [cost, COST_GATE])
		print("    of that ring, the lattice darkens %.1f%%" % float(rows.crossed))
		if int(rows.pixels) < 200:
			print("    NOT ENOUGH RUNE TO JUDGE — this pose drew no telegraph.")
			verdict_ok = false
		else:
			measured_any = true
			if cost > COST_GATE:
				verdict_ok = false
		print("")

	print("  ink.gd's CONTRAST_FLOOR is %.1f and it is a floor for TEXT."
		% SkyGearInk.CONTRAST_FLOOR)
	print("  DECK-IDENTITY §7.5 measured the SHIPPED rune-against-planking figure")
	print("  at 1.91, so the absolute floor decides nothing here and the relative")
	print("  gate is the one that can. Both numbers are printed above.")
	print("")
	if verdict_ok and measured_any:
		print("  VERDICT: the rig SURVIVES. No light level costs a rune more than")
		print("           %.2f%% of the contrast it has with the rig hidden." % COST_GATE)
	else:
		print("  VERDICT: CUT THE RIG BACK. A rune loses more than %.2f%% of its"
			% COST_GATE)
		print("           contrast under the lattice, or no rune was drawn to judge.")
	print("")
	quit(0 if (verdict_ok and measured_any) else 3)


## One light level. Two plates, one toggle, nothing else.
func _measure(view: SkyGearView3D, game: SkyGearGame, live: Array,
		darkness: float, tag: String, out_dir: String) -> Dictionary:
	game.set_process(true)
	view.set_process(true)
	view.set_darkness(darkness)
	## `_sync_darkness` eases on a time constant, so a tool that took the shot
	## straight after the call would photograph the tail of a lerp — the same
	## mistake `marks_shot.gd` records about the camera follow.
	for _i in 90:
		view._process(1.0 / 30.0)
		await process_frame

	## Re-arm the windups: the frames above advanced the state clocks. This is
	## done BEFORE either plate, never between them.
	for i in mini(live.size(), TELEGRAPHS.size()):
		var e = live[i]
		if not is_instance_valid(e):
			continue
		var to_cap: Vector2 = game.player.global_position - e.global_position
		e.state = "windup"
		e.attack_direction = to_cap.normalized() if to_cap.length() > 0.001 \
			else Vector2.DOWN
		e.state_time = float(e.config.windup) * TELEGRAPH_FRAC
	for _i in 2:
		game._process(1.0 / 60.0)
		await process_frame
	game.set_process(false)
	## PIN THE FLICKER, then STOP THE RENDERER, then HIDE THE PARTICLES — all
	## three of SG-101's fixes, all three of which were real.
	view._flicker = 12.0
	for _i in 3:
		view._process(0.0)
		await process_frame
	view.set_process(false)
	for node in view.find_children("*", "GPUParticles3D", true, false):
		(node as GPUParticles3D).emitting = false
		(node as GPUParticles3D).visible = false
	await process_frame

	var slug := tag.replace(" ", "-").replace("wave-8", "w8")
	var plate_rig := await _plate("%s/rig-tele-%s.png" % [out_dir, slug])
	view._rigging.visible = false
	var plate_off := await _plate("%s/norig-tele-%s.png" % [out_dir, slug])
	view._rigging.visible = true
	await process_frame

	var rune := _rune_mask(plate_rig)
	var ring := _ring_mask(rune, plate_rig.get_width(), plate_rig.get_height())
	return {"with_rig": _edge(plate_rig, rune, ring),
		"without": _edge(plate_off, rune, ring),
		"pixels": rune.size() / 2, "ring": ring.size() / 2,
		"crossed": _darkened(plate_rig, plate_off, ring)}


func _plate(path: String) -> Image:
	await process_frame
	await process_frame
	var img := root.get_texture().get_image()
	img.save_png(path)
	return img


## The rune: saturated warning colour, found by hue rather than by a diff.
func _rune_mask(img: Image) -> PackedInt32Array:
	var out := PackedInt32Array()
	var w := img.get_width()
	var h := img.get_height()
	var y := 0
	while y < h:
		var x := 0
		while x < w:
			var c := img.get_pixel(x, y)
			if c.s >= RUNE_SAT and c.v >= RUNE_VAL \
					and (c.h <= RUNE_HUE or c.h >= 1.0 - RUNE_HUE):
				out.append(x)
				out.append(y)
			x += STEP
		y += STEP
	return out


## The planking a rune is read against: a ring `RING_PX` out from it that is not
## itself rune. Built on a coarse occupancy grid so the dilation is a lookup
## rather than a search.
func _ring_mask(rune: PackedInt32Array, w: int, h: int) -> PackedInt32Array:
	var gw := w / STEP + 2
	var gh := h / STEP + 2
	var grid := PackedByteArray()
	grid.resize(gw * gh)
	var i := 0
	while i < rune.size():
		grid[(rune[i + 1] / STEP) * gw + rune[i] / STEP] = 1
		i += 2
	var reach := RING_PX / STEP
	var out := PackedInt32Array()
	var gy := 0
	while gy < gh:
		var gx := 0
		while gx < gw:
			if grid[gy * gw + gx] == 0:
				var near := false
				var dy := -reach
				while dy <= reach and not near:
					var dx := -reach
					while dx <= reach:
						var ax := gx + dx
						var ay := gy + dy
						if ax >= 0 and ay >= 0 and ax < gw and ay < gh \
								and grid[ay * gw + ax] == 1:
							near = true
							break
						dx += 1
					dy += 1
				## The grid is padded by two cells so the dilation never has to
				## test a bound; those pad cells are not pixels, so they are
				## dropped here rather than sampled off the end of the image.
				if near and gx * STEP < w and gy * STEP < h:
					out.append(gx * STEP)
					out.append(gy * STEP)
			gx += 1
		gy += 1
	return out


## `ink.gd`'s own contrast formula, so this number means what every other
## contrast number in the project means. Medians, not means — §7.5's yardstick,
## and a mean is hostage to the few pixels at a rune's antialiased rim.
func _edge(img: Image, rune: PackedInt32Array, ring: PackedInt32Array) -> float:
	if rune.is_empty() or ring.is_empty():
		return 0.0
	return SkyGearInk.contrast(_median(img, rune), _median(img, ring))


func _median(img: Image, pts: PackedInt32Array) -> Color:
	var ls: Array[float] = []
	var i := 0
	while i < pts.size():
		ls.append(SkyGearInk.luminance(img.get_pixel(pts[i], pts[i + 1])))
		i += 2
	ls.sort()
	var m: float = ls[ls.size() / 2]
	## A grey of the same relative luminance: `contrast()` only reads luminance,
	## and a median COLOUR is not a thing that exists.
	var v: float = pow((m + 0.055) / 1.055, 1.0 / 2.4) if m > 0.0031308 \
		else m * 12.92
	return Color(v, v, v)


## How much of the planking ring the lattice actually darkens. Reported because a
## gate that passes because the thing under test never touched the thing it
## threatened is a coincidence, not a gate.
func _darkened(with_rig: Image, without: Image, ring: PackedInt32Array) -> float:
	if ring.is_empty():
		return 0.0
	var hit := 0
	var i := 0
	while i < ring.size():
		if SkyGearInk.luminance(without.get_pixel(ring[i], ring[i + 1])) \
				- SkyGearInk.luminance(with_rig.get_pixel(ring[i], ring[i + 1])) >= 0.004:
			hit += 1
		i += 2
	return 200.0 * float(hit) / float(ring.size())
