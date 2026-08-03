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
## reliably the least trustworthy thing in the experiment.
##
## What survives finds the rune by asking the RENDERER which pixels are
## telegraph: the telegraph decals are hidden, the same frozen frame is
## photographed again, and the pixels that changed are the rune. The planking it
## is read against is the ring of pixels immediately around that in the SAME
## plate. Both plates are then measured over the identical two pixel sets. That
## is what "edge contrast against planking" means.
##
## THAT MASK WAS A COLOUR WINDOW UNTIL SG-116 AND THE NUMBER BELOW MOVED WHEN IT
## STOPPED BEING ONE. `s >= 0.55, v >= 0.42, hue within 0.11 of red` selected
## 26,095 pixels on this pose, and the brazier bowls and an ARMORED boarder's lit
## plating were a large share of them. Those pixels sat in BOTH plates unchanged,
## so they diluted the cost toward zero: the figure this tool published was an
## understatement, not an invention. `tools/rune_read.gd` carries the full
## account and `tools/rune_probe.gd` is the check the old mask fails.
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
## THE RUNE MASK, THE PLANKING RING AND THE CONTRAST FORMULA all live in
## `tools/rune_read.gd` now (SG-108), because `marks_shot.gd` needs the identical
## measurement and two separately-written rune masks would not be comparable to
## each other — STATUS.md's second recurring failure mode, exactly.
const COST_GATE := SkyGearRune.COST_GATE

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
		print("    telegraph decals hidden to find them %d" % int(rows.decals))
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
	await SkyGearStill.thaw(self, view, game)
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
	## FREEZE THROUGH THE ONE HELPER (SG-108). This block used to be a hand-copy
	## of three of SG-101's four fixes and it was MISSING the fourth and largest:
	## `Engine.time_scale` and every `AnimationPlayer.speed_scale`. Four rigged
	## boarders were breathing through their windups between the two plates below,
	## which is exactly the motion this tool then attributed to the lattice.
	var stopped := await SkyGearStill.freeze(self, view, game)

	## AND THE PRE-COMMITTED CHECK BEFORE ANY ANSWER IS BELIEVED: two plates with
	## nothing changed between them, over the whole frame, through the same
	## re-flush the real pair goes through. Exactly zero, or this tool is
	## measuring the boarders' walk cycles and calling it the rig.
	var noise := await SkyGearStill.floor_pct(self, FRAME_BOX,
		func() -> void: view._process(0.0))
	print("    still · two plates of a frozen scene differ by exactly zero   %.2f%%"
		% noise)
	print("    (%d rigs and %d particle systems stopped)"
		% [int(stopped.animation_players), int(stopped.particles)])
	if noise != 0.0:
		push_error("the scene is not still (%.2f%%) — nothing here to measure" % noise)
		return {"with_rig": 0.0, "without": 0.0, "pixels": 0, "ring": 0,
			"decals": 0, "crossed": 0.0}

	var slug := tag.replace(" ", "-").replace("wave-8", "w8")

	## THE RUNE PIXELS FIRST, AND THEY ARE ASKED OF THE RENDERER (SG-116). This
	## used to be `SkyGearRune.mask(plate_rig)` — a colour window that selected
	## any saturated red-amber pixel, which on this exact pose meant the brazier
	## bowls and an ARMORED boarder's lit plating as much as it meant a rune.
	## `mask_of` takes its own pair (telegraph decals shown, then hidden) and
	## keeps the shown one, which is the plate this tool wanted anyway. The rig is
	## overhead for both, so the mask is derived under the shipped condition
	## exactly as before.
	var got := await SkyGearRune.mask_of(view,
		func(which: String) -> Image:
			return await _plate("%s/rig-%s-%s.png" % [out_dir, which, slug]))
	var plate_rig: Image = got.plate
	var rune: PackedInt32Array = got.mask
	## The pixel set the figure below is a median over, as a picture. SG-116 was
	## only ever findable by looking at a plate and asking what the mask had
	## actually selected; that should not need re-discovering.
	SkyGearRune.save_mask(rune, plate_rig.get_width(), plate_rig.get_height(),
		"%s/rig-mask-%s.png" % [out_dir, slug])

	view._rigging.visible = false
	var plate_off := await _plate("%s/norig-tele-%s.png" % [out_dir, slug])
	view._rigging.visible = true
	await process_frame

	var ring := SkyGearRune.ring(rune, plate_rig.get_width(), plate_rig.get_height())
	return {"with_rig": SkyGearRune.edge(plate_rig, rune, ring),
		"without": SkyGearRune.edge(plate_off, rune, ring),
		"pixels": rune.size() / 2, "ring": ring.size() / 2,
		"decals": int(got.decals),
		"crossed": SkyGearRune.darkened(plate_rig, plate_off, ring)}


## The whole frame, for the stillness control. A rune mask is scattered across
## the frame rather than confined to a rectangle, so the control has to be too.
const FRAME_BOX := Rect2i(0, 0, 1600, 900)


## `frame_post_draw`, not `process_frame` — SG-29's idiom, and SG-108's reason:
## `process_frame` fires when the TREE finished its frame, not when the RENDERER
## finished drawing it, and the resulting bad readback is INTERMITTENT.
func _plate(path: String) -> Image:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png(path)
	return img
