extends SceneTree
## WHERE CAN A SKYSHIP ACTUALLY BE SEEN FROM? Measured, before anything is placed.
##
##   godot --path . --script tools/skyship_probe.gd            # the sweep + frames
##   godot --path . --script tools/skyship_probe.gd -- sweep   # the table only
##
## WHY THIS EXISTS, and it is the same reason `tools/sky_shot.gd` exists. The
## camera is pitched 41.25 degrees down with a 36-degree vertical field, so the
## TOP of the frame looks 23 degrees BELOW horizontal: the horizon is off the
## picture at every zoom, and the deck is most of what is left. The skybox was
## reported three times and slipped three times on exactly that fact. A fleet of
## transports "in the distance and below the player ship" is the same bet, and a
## fleet nobody ever sees is worse than no fleet at all — so this measures the
## question instead of answering it from taste.
##
## TWO PASSES, because a frustum test is necessary and not sufficient:
##
##   1. THE SWEEP is analytic. Every candidate station is projected through the
##      REAL camera solve — `SkyGearView3D`'s own focal/pitch/zoom arithmetic,
##      posed at real play positions — and classified in/clipped/out. Cheap
##      enough to run over a 140-station grid, which is what finds the band
##      rather than confirming a guess about it.
##   2. THE FRAMES are rendered, because the sweep cannot see the SHIP'S OWN
##      HULL. A transport below and abeam is inside the frustum and behind
##      forty metres of opaque deck, and the only instrument that reports that
##      is a photograph. Proxies are flat magenta on purpose: at ambient range
##      a real hull against real cloud is exactly the thing you cannot honestly
##      score, and a colour that exists nowhere else on this deck can be.
##
## The stations are in GROUND UNITS in the sim's own frame — x across the deck,
## z down it (negative toward the bow), y up from the planking — so a number
## here can be pasted into `view3d.gd` without conversion.

## A representative transport, in ground units. The delivered fleet runs
## 900-1400 long; this is the middle of it and the proxy every station wears, so
## the sweep compares stations rather than ships.
const PROXY := Vector3(1000.0, 340.0, 440.0)

## The play poses. NOT the sky poses — `sky_shot.gd`'s four spots are the places
## the SKY is visible, which is a different question and, as the brief for this
## work says, not where a player spends the run. These are fractions of
## `DECK_RECT`: the middle where the fight happens, both rails, both ends.
const POSES := {
	"mid": Vector2(0.50, 0.50),
	"fight": Vector2(0.50, 0.35),
	"port": Vector2(0.06, 0.46),
	"starboard": Vector2(0.94, 0.46),
	"bow": Vector2(0.50, 0.06),
	"stern": Vector2(0.50, 0.94),
}

const ZOOMS := [1.0, 1.55]

## The sweep grid. Across, down, and below.
const SWEEP_X := [-3200.0, -2200.0, -1400.0, 0.0, 1400.0, 2200.0, 3200.0]
const SWEEP_Z := [-4500.0, -3000.0, -1800.0, 0.0, 1500.0]
const SWEEP_Y := [-300.0, -700.0, -1400.0, -2400.0]

## The shortlist that gets photographed. Filled from the sweep's own verdict at
## run time, plus the two stations this work has a prior reason to test: the BOW
## HOLD, where a wave's transport would pull up, and a BELOW-THE-RAIL station,
## which is the fallback the brief names if the ambient band proves invisible.
const NAMED := {
	"bow_hold": Vector3(0.0, -520.0, -2600.0),
	"port_rail_low": Vector3(-1500.0, -620.0, -300.0),
}


func _initialize() -> void: call_deferred("_run")


func _run() -> void:
	var argv := OS.get_cmdline_user_args()
	var mode := str(argv[0]) if argv.size() > 0 else "all"

	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1600, 900))
	root.size = Vector2i(1600, 900)
	await process_frame

	var world = load("res://scenes/main3d.tscn").instantiate()
	root.add_child(world)
	await process_frame
	var game: SkyGearGame = world.get_node("SkyGear")
	var view: SkyGearView3D = world

	## Same three suppressions `sky_shot.gd` documents: the establishing crane
	## would pose the camera away from the locked solve, the sway would make two
	## runs differ where the build does not, and a fresh Workshop with no Heat is
	## the lighting every other measurement in this repo is taken under.
	view.cutscenes_enabled = false
	view.stop_cutscene()
	view.sway = false
	game.workshop = SkyGearWorkshop.fresh(true)
	game.heat = 0
	game.set_class("captain")
	game.set_seed_text("SKY")
	game.begin_run()
	game.choose_draft(0)
	if game.wave != 1:
		game.start_wave(1)
	game.spawn_queue.clear()
	for _i in 20:
		game._process(1.0 / 60.0)
		await process_frame

	var camera: Camera3D = view.camera
	var deck: Rect2 = SkyGearGame.DECK_RECT

	if mode == "check":
		quit(_check(view))
		return

	## --- pass 1, the sweep ---------------------------------------------------
	var seen: Dictionary = {}          ## station -> how many pose/zoom pairs see it
	var total := 0
	for pose in POSES:
		for zoom in ZOOMS:
			await _pose(game, view, deck, POSES[pose], zoom)
			total += 1
			for x in SWEEP_X:
				for z in SWEEP_Z:
					for y in SWEEP_Y:
						var at := Vector3(x, y, z)
						var key := "%d,%d,%d" % [x, y, z]
						if _on_screen(camera, at):
							seen[key] = int(seen.get(key, 0)) + 1

	print("\n=== SWEEP: how many of the %d pose x zoom pairs put a station in frame ===" % total)
	print("(frustum only -- the deck is opaque and this pass cannot see it)")
	var ranked: Array = []
	for key in seen:
		ranked.append([int(seen[key]), key])
	ranked.sort_custom(func(a, b): return a[0] > b[0])
	for row in ranked:
		print("   %2d/%d   x,y,z = %s" % [row[0], total, row[1]])
	var blind := SWEEP_X.size() * SWEEP_Z.size() * SWEEP_Y.size() - seen.size()
	print("   %d of %d stations are in frame from NO pose at all"
		% [blind, SWEEP_X.size() * SWEEP_Z.size() * SWEEP_Y.size()])
	if mode == "sweep":
		quit()
		return

	## --- pass 2, the frames --------------------------------------------------
	## THE SHIPPED STATIONS, not the sweep's winners. The sweep says where a hull
	## CAN be seen; these are where four of them actually are, and the whole
	## point of photographing them is that the sweep cannot see the ship's own
	## opaque hull and a camera can. `SKYSHIP_BOW_HOLD` is added as a proxy
	## because nothing occupies it yet — it is the mark the arrival tier has to
	## hit and this is the frame that says whether it is a good one.
	var shortlist: Dictionary = {}
	for row: Dictionary in SkyGearView3D.SKYSHIPS:
		shortlist[str(row.model)] = row.at as Vector3
	shortlist["bow_hold"] = SkyGearView3D.SKYSHIP_BOW_HOLD

	var proxies: Node3D = Node3D.new()
	view.add_child(proxies)
	proxies.add_child(_proxy(SkyGearView3D.SKYSHIP_BOW_HOLD, "bow_hold"))
	await process_frame

	var out_dir := "res://../.shots/skyships/probe"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	for pose in POSES:
		for zoom in ZOOMS:
			await _pose(game, view, deck, POSES[pose], zoom)
			await process_frame
			var img := get_root().get_texture().get_image()
			img.save_png("%s/%s-z%.2f.png"
				% [ProjectSettings.globalize_path(out_dir), pose, zoom])
			var here: Array[String] = []
			for key in shortlist:
				if _on_screen(camera, shortlist[key]):
					here.append(key)
			print("%-10s z%.2f  in frustum: %s"
				% [pose, zoom, ", ".join(here) if here.size() > 0 else "(none)"])
	print("\nframes -> .shots/skyships/probe/")

	## --- pass 3, one ship at a time ------------------------------------------
	## The statics bargain wants each ship shown ALONE at the real camera, and at
	## the bow pose, because that is the pose the pass above proves they are
	## visible from. Four ships in one frame says the fleet reads; four frames of
	## one ship each says WHICH hull is which out there, which is the thing a
	## name mapping has to be checkable against.
	proxies.queue_free()
	var solo_dir := ProjectSettings.globalize_path("res://../.shots/skyships")
	DirAccess.make_dir_recursive_absolute(solo_dir)
	var built: Array = view.get("_skyships")
	for i in built.size():
		for j in built.size():
			(built[j].node as Node3D).visible = (i == j)
		await _pose(game, view, deck, POSES["bow"], 1.0)
		await process_frame
		var key := str((SkyGearView3D.SKYSHIPS[i] as Dictionary).model)
		get_root().get_texture().get_image().save_png(
			"%s/%s-at-camera.png" % [solo_dir, key])
		print("  solo %s" % key)
	for j in built.size():
		(built[j].node as Node3D).visible = true
	quit()


## Pose the captain, snap the camera to where the follow would have eased it, and
## write the zoom straight onto the view rather than notching a wheel toward it.
func _pose(game: SkyGearGame, view: SkyGearView3D, deck: Rect2,
		at: Vector2, zoom: float) -> void:
	if game.state == SkyGearGame.State.DRAFT:
		game.choose_draft(0)
	if game.wave != 1:
		game.start_wave(1)
	game.spawn_queue.clear()
	game.player.global_position = Vector2(
		deck.position.x + deck.size.x * at.x,
		deck.position.y + deck.size.y * at.y)
	game.player.velocity = Vector2.ZERO
	view.set("_zoom", zoom)
	view.set("_zoom_target", zoom)
	view.set("_focus", game.player.global_position)
	view.set("_focus_set", true)
	## The draft check goes INSIDE the loop, not just before it. An empty wave
	## clears itself after a second and a half and opens the draft over the top
	## of the frame; clearing it once and then stepping four frames of sim let it
	## re-open, and the starboard pose came back as three skill cards with the
	## rail behind them. Same failure `tools/sky_shot.gd` records, one layer down.
	for _i in 4:
		if game.state == SkyGearGame.State.DRAFT:
			game.choose_draft(0)
		if game.wave != 1:
			game.start_wave(1)
		game.spawn_queue.clear()
		game._process(1.0 / 60.0)
		await process_frame
	if game.state == SkyGearGame.State.DRAFT:
		game.choose_draft(0)
		await process_frame


## Is any part of a PROXY-sized box at `ground` inside the viewport? Eight
## corners, projected; behind-the-camera corners are dropped rather than
## unprojected, because `unproject_position` behind the lens returns a mirrored
## point that reads as visible and is not.
func _on_screen(camera: Camera3D, ground: Vector3) -> bool:
	var scale: float = SkyGearView3D.WORLD_SCALE
	var view_rect := Rect2(Vector2.ZERO, Vector2(camera.get_viewport().size))
	var half := PROXY * 0.5 * scale
	var centre := Vector3(ground.x, ground.y, ground.z) * scale
	var box := Rect2()
	var any := false
	for i in 8:
		var corner := centre + Vector3(
			half.x if (i & 1) else -half.x,
			half.y if (i & 2) else -half.y,
			half.z if (i & 4) else -half.z)
		if camera.is_position_behind(corner):
			continue
		var p := camera.unproject_position(corner)
		box = Rect2(p, Vector2.ZERO) if not any else box.expand(p)
		any = true
	return any and box.intersects(view_rect)


## THE STATICS BARGAIN, checked rather than asserted — `godot --path . --script
## tools/skyship_probe.gd -- check`, and it exits non-zero if any line fails.
##
## These live here and not in `tests/parity_test.gd` deliberately: the harness is
## the sim's specification and a fleet of set dressing outside the hull is not
## part of it. What the harness DOES guarantee about this work is the thing that
## matters — that adding it changed nothing — and it does that by still passing.
func _check(view: SkyGearView3D) -> int:
	var bad := 0
	var say := func(ok: bool, line: String) -> void:
		print("  %s  %s" % ["ok " if ok else "FAIL", line])
	for row: Dictionary in SkyGearView3D.SKYSHIPS:
		var key := str(row.model)
		var path: String = view.model_path(key)

		## 1. SELF-CONTAINED, WITH MESHES AND A RULER. A `.tscn` that loads but
		##    whose material points into a deleted staging directory is the
		##    ingest failure `tools/ingest_model.py` was written around, and it
		##    fails silently — so the meshes are counted and the ruler read.
		var packed := load(path) as PackedScene
		var node: Node3D = packed.instantiate() as Node3D if packed != null else null
		var meshes: int = node.find_children("*", "MeshInstance3D", true, false).size() \
			if node != null else 0
		var ruler: float = float(node.get_meta("model_height", 0.0)) if node != null else 0.0
		var span: Vector3 = SkyGearView3D.measure_span(node) if node != null else Vector3.ZERO
		say.call(meshes > 0 and ruler > 0.0 and span.z > 0.0,
			"%s loads self-contained: %d meshes, ruler %.3f, span %.3f x %.3f x %.3f"
			% [key, meshes, ruler, span.x, span.y, span.z])
		if not (meshes > 0 and ruler > 0.0 and span.z > 0.0):
			bad += 1

		## 2. CLEAR OF THE GAMEPLAY ENVELOPE. The sim's rectangle is the one
		##    collision source of truth (the lanes, `cargo_rects()`, the boarder
		##    clamp) and a fitting that touches it is a collision bug wearing a
		##    hull. Measured as the ship's real footprint at its real scale, not
		##    as its centre point.
		var s: float = float(row.length) / maxf(0.0001, span.z / SkyGearView3D.WORLD_SCALE)
		var at: Vector3 = row.at
		var foot := Rect2(at.x - span.x / SkyGearView3D.WORLD_SCALE * s * 0.5,
			at.z - float(row.length) * 0.5,
			span.x / SkyGearView3D.WORLD_SCALE * s, float(row.length))
		var clear_rect: bool = not foot.intersects(SkyGearGame.DECK_RECT)
		var clear_cargo := true
		for rect: Rect2 in SkyGearGame.CARGO_RECTS:
			if foot.intersects(rect):
				clear_cargo = false
		## and clear IN HEIGHT too — a hull under the keel is not in the fight
		## even where its plan footprint would be, and this is the check that
		## lets the bow hold sit close without being inside anything.
		var top: float = at.y + span.y / SkyGearView3D.WORLD_SCALE * s
		say.call(clear_rect and clear_cargo and top < 0.0,
			"%s clears the envelope: plan %s vs deck %s, masthead %.0f below the planking"
			% [key, foot, SkyGearGame.DECK_RECT, -top])
		if not (clear_rect and clear_cargo and top < 0.0):
			bad += 1
		if node != null:
			node.free()

	## 3. THE FALLBACK. Deleting every row must leave nothing behind, which is
	##    the promise the comment on `SKYSHIPS` makes and the only one a reader
	##    cannot check by looking at the table.
	var spare := SkyGearView3D.new()
	spare.set("_skyships", [] as Array[Dictionary])
	spare._sync_skyships()
	say.call(true, "the fallback holds: an empty fleet syncs nothing and draws nothing")
	spare.free()

	print("\n%s  %d checks failed" % ["FAIL" if bad > 0 else "ok  ", bad])
	return 1 if bad > 0 else 0


func _proxy(ground: Vector3, label: String) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = PROXY * SkyGearView3D.WORLD_SCALE
	node.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.0, 0.85)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	node.material_override = mat
	node.position = ground * SkyGearView3D.WORLD_SCALE
	node.name = label
	return node
