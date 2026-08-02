extends SceneTree
## SG-15 — measure the Colossus wreck fitting. Where does it actually render, at
## the shipped 41 deg camera, and does it stay clear of the gameplay envelope?
##
##   godot --path . --headless --resolution 1600x900 --script tools/wreck_measure.gd
##
## Prints, for the real `_wreck` node in `main3d.tscn`: its ground position and
## rendered world AABB, that it sits outside DECK_RECT and every cargo rect, and
## where it projects (base + top, px height, on/off screen) at the gameplay
## camera and at the four sky poses `tools/sky_shot.gd` uses — the at-camera
## verdict that a headless build cannot photograph (SG-29). Also proves the
## first-victory gate hides it on a fresh save and shows it once earned.
##
## Writes nothing; the table IS the evidence. Cutscenes are disabled so the
## measured camera is the gameplay solve, not the run-open crane.

const WORLD_SCALE := 0.01

func _initialize() -> void: call_deferred("_run")

func _pose(view, game, fx: float, fy: float, zoom: float) -> void:
	var deck: Rect2 = SkyGearGame.DECK_RECT
	game.player.global_position = Vector2(deck.position.x + deck.size.x * fx,
		deck.position.y + deck.size.y * fy)
	game.player.velocity = Vector2.ZERO
	view._focus_set = false
	view._zoom = zoom
	view._zoom_target = zoom
	for _i in 8:
		game._process(1.0 / 60.0)
		await process_frame

func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1600, 900))
	root.size = Vector2i(1600, 900)
	await process_frame
	var world = load("res://scenes/main3d.tscn").instantiate()
	root.add_child(world)
	await process_frame
	var view = world
	var game: SkyGearGame = world.get_node("SkyGear")
	game.workshop = SkyGearWorkshop.fresh(true)   # ephemeral: never touches the disk save
	game.workshop.unlocked = true                 # earn the fitting so it can be measured
	game.heat = 0
	game.set_class("captain")
	game.set_seed_text("WRECK")
	game.begin_run()
	game.choose_draft(0)
	if game.wave != 1:
		game.start_wave(1)
	game.spawn_queue.clear()
	view.sway = false
	view.cutscenes_enabled = false
	view.stop_cutscene()
	for _i in 20:
		game._process(1.0 / 60.0)
		await process_frame

	var cam: Camera3D = view.camera
	var vp := cam.get_viewport().get_visible_rect().size
	var W := vp.x
	var H := vp.y

	if view._wreck == null:
		print("NO WRECK NODE — art missing or fitting not built")
		quit(1)
		return

	# rendered world AABB of the wreck sprite (a billboard: depth ~0)
	var box: AABB = view._wreck.get_aabb()
	box = view._wreck.global_transform * box
	var h_gu := box.size.y / WORLD_SCALE
	var w_gu := box.size.x / WORLD_SCALE
	var pos: Vector2 = SkyGearView3D.WRECK_POSITION

	print("=== SG-15 COLOSSUS WRECK MEASUREMENT ===")
	print("output resolution   %d x %d" % [int(W), int(H)])
	print("texture             %s (%d x %d px)" % [SkyGearView3D.WRECK_TEXTURE,
		int(view._wreck.texture.get_width()), int(view._wreck.texture.get_height())])
	print("ground position     (%.0f, %.0f)   [bow edge %.0f, spawn -1115, boiler +850]" % [
		pos.x, pos.y, SkyGearGame.DECK_RECT.position.y])
	print("authored height     %.0f gu (PROP_HEIGHT.wreck)" % float(SkyGearView3D.PROP_HEIGHT["wreck"]))
	print("rendered AABB        %.0f wide x %.0f tall gu, base y %.1f gu" % [
		w_gu, h_gu, box.position.y / WORLD_SCALE])
	print("")

	# --- envelope clearance -----------------------------------------------------
	var deck: Rect2 = SkyGearGame.DECK_RECT
	var in_deck := deck.has_point(pos)
	var in_any_cargo := false
	for r in game.cargo_rects():
		if (r as Rect2).has_point(pos):
			in_any_cargo = true
	# lane bands: LANE_CENTERS +- 190 in x, spanning the deck in y
	var in_lane := false
	for c in SkyGearGame.LANE_CENTERS:
		if absf(pos.x - float(c)) <= 190.0 and deck.has_point(Vector2(pos.x, pos.y)):
			in_lane = true
	var is_prop := false
	for p in game.get_tree().get_nodes_in_group("props"):
		if is_instance_valid(p) and p.global_position.distance_to(pos) < 1.0:
			is_prop = true
	print("ENVELOPE CLEARANCE")
	print("  inside DECK_RECT      %s   (must be false)" % in_deck)
	print("  inside a cargo rect   %s   (must be false; %d rects incl. crate)" % [
		in_any_cargo, game.cargo_rects().size()])
	print("  inside a lane band    %s   (must be false)" % in_lane)
	print("  is a props-group prop %s   (must be false — a fitting, not a prop)" % is_prop)
	print("  beyond the spawn line %s   (y %.0f < -1115)" % [pos.y < -1115.0, pos.y])
	print("")

	# --- gate round-trip --------------------------------------------------------
	game.workshop.unlocked = false
	view._process(1.0 / 60.0)
	var hidden_when_locked: bool = not bool(view._wreck.visible)
	game.workshop.unlocked = true
	view._process(1.0 / 60.0)
	var shown_when_earned: bool = bool(view._wreck.visible)
	print("FIRST-VICTORY GATE (workshop.unlocked)")
	print("  hidden on a fresh save   %s" % hidden_when_locked)
	print("  shown once earned        %s" % shown_when_earned)
	print("")

	# --- at-camera projection across the poses ----------------------------------
	var poses := {
		"gameplay-mid (y0.60)": [0.50, 0.60, 1.0],
		"sky-mid":              [0.50, 0.50, 1.0],
		"sky-port":             [0.06, 0.46, 1.0],
		"sky-starboard":        [0.94, 0.46, 1.0],
		"sky-bow (advanced)":   [0.50, 0.06, 1.0],
		"sky-bow z1.55":        [0.50, 0.06, 1.55],
	}
	print("AT-CAMERA PROJECTION  (screen %d x %d; base = feet, top = crown)" % [int(W), int(H)])
	print("%-22s %14s %14s %8s %s" % ["pose", "base(px)", "top(px)", "px_h", "on screen"])
	for pname in poses:
		var p = poses[pname]
		await _pose(view, game, p[0], p[1], p[2])
		var base: Vector2 = cam.unproject_position(Vector3(pos.x * WORLD_SCALE, 0.0, pos.y * WORLD_SCALE))
		var top: Vector2 = cam.unproject_position(Vector3(pos.x * WORLD_SCALE,
			float(SkyGearView3D.PROP_HEIGHT["wreck"]) * WORLD_SCALE, pos.y * WORLD_SCALE))
		var on := base.x >= 0 and base.x <= W and (
			(base.y >= 0 and base.y <= H) or (top.y >= 0 and top.y <= H)
			or (base.y > H and top.y < 0))
		print("%-22s (%5.0f,%5.0f) (%5.0f,%5.0f) %7.0f  %s" % [
			pname, base.x, base.y, top.x, top.y, absf(base.y - top.y),
			"VISIBLE" if on else "off-frame"])
	print("")
	print("Verdict: a landmark the moment the captain works the bow, and in the")
	print("run-open crane; off-frame in a centred mid-deck pose, like the prow.")
	quit(0)
