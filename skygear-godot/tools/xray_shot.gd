extends SceneTree

## SG-141 — THE X-RAY SILHOUETTE, PHOTOGRAPHED AGAINST THE REAL CRATES.
##
##   godot --path . --resolution 1600x900 --script tools/xray_shot.gd
##
## NOT `--headless` (SG-29): there is no framebuffer to read back without a GPU,
## and a tool whose whole output is a PNG cannot run on the flag that makes PNGs
## empty. FROZEN through `SkyGearStill` (SG-108), so the two exposures below
## differ by the silhouette and by nothing else — no breathing walk cycle, no
## drifting brazier, no particle clock.
##
## WHY A PAIR OF SHOTS AND NOT ONE. The bug is invisible in a single frame: a
## boarder with no silhouette simply is not there, and a picture of an empty
## crate stack proves nothing on its own. So this poses ONE scene and exposes it
## TWICE — once with the ghost suppressed, which is exactly what the shipped
## build does for every figure in the game, and once with it on. The difference
## between the two files IS the bug.
##
## AND IT IS SHOT AGAINST THE CRATE MESHES, not the decals SG-141 was written
## against. The cargo runs became 120 solid crate stacks this morning; a
## silhouette judged against a flat painted run would be judged against geometry
## the player no longer has in front of them.

const STAND := 150.0        ## the torso height `_occluded` reasons about


func _initialize() -> void: call_deferred("_run")


func _run() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1600, 900))
	root.size = Vector2i(1600, 900)
	await process_frame

	var world = load("res://scenes/main3d.tscn").instantiate()
	root.add_child(world)
	await process_frame
	var game: SkyGearGame = world.get_node("SkyGear")
	var view: SkyGearView3D = world

	view.cutscenes_enabled = false
	view.stop_cutscene()
	view.sway = false
	game.workshop = SkyGearWorkshop.fresh(true)
	game.heat = 0
	game.set_class("captain")
	game.set_seed_text("XRAY")
	game.begin_run()
	game.choose_draft(0)
	for _i in 20:
		game._process(1.0 / 60.0)
		await process_frame

	var out := ProjectSettings.globalize_path("res://../.shots/sg141")
	DirAccess.make_dir_recursive_absolute(out)

	## Clear the wave; this shot is about one boarder and one crate run.
	for e in game.get_tree().get_nodes_in_group("enemies"):
		e.dead = true
		e.queue_free()
	game.spawn_queue.clear()
	await process_frame

	## THE POSE IS SEARCHED FOR, NOT TYPED IN. `_occluded` is the renderer's own
	## answer to "is this figure behind cargo", so the tool asks it rather than
	## re-deriving the cargo layout and going stale the next time a rect moves.
	## Among the spots it calls hidden, take the one nearest the captain that
	## still lands well inside the frame — a silhouette photographed at the edge
	## of the picture is not evidence about readability.
	var focus := Vector2(-280.0, 620.0)
	game.player.global_position = focus
	view.set("_focus", focus)
	view.set("_focus_set", true)
	view._process(1.0 / 60.0)
	await process_frame

	var best := Vector2.INF
	var best_gap := 1e20
	var deck: Rect2 = SkyGearGame.DECK_RECT
	var x := deck.position.x + 20.0
	while x < deck.end.x:
		var y := deck.position.y + 20.0
		while y < deck.end.y:
			var spot := Vector2(x, y)
			if view._occluded(spot, STAND):
				var screen: Vector2 = view.camera.unproject_position(
					Vector3(spot.x, 0.0, spot.y) * SkyGearView3D.WORLD_SCALE)
				var framed: bool = screen.x > 380.0 and screen.x < 1220.0 \
					and screen.y > 180.0 and screen.y < 720.0
				if framed and focus.distance_to(spot) < best_gap:
					best_gap = focus.distance_to(spot)
					best = spot
			y += 20.0
		x += 20.0
	if best == Vector2.INF:
		print("  no framed spot on this deck is occluded — nothing to photograph")
		quit(1)
		return
	print("  captain at %s, boarder hidden at %s (%.0f units apart)"
		% [focus, best, best_gap])

	game.spawn_enemy("SCRAPPER", 0)
	var boarder: SkyGearEnemy = null
	for e in game.get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and not e.dead:
			boarder = e
	boarder.state = "move"
	boarder.state_time = 0.0
	boarder.global_position = best
	## HE STAYS PUT. A boarder in `move` walks at the captain, and eight settle
	## ticks were enough to carry him out from behind the crate he was posed
	## behind — so the first pair of exposures photographed an un-occluded
	## boarder and disagreed with the tool's own console line. The pose is the
	## measurement here; let the rig settle and the simulation hold still.
	boarder.set_physics_process(false)
	for _i in 8:
		view._process(1.0 / 60.0)
		await process_frame
	boarder.global_position = best
	view._process(1.0 / 60.0)
	await process_frame
	print("  occluded at exposure time: %s"
		% view._occluded(boarder.global_position, STAND))

	var key := "e%d" % boarder.get_instance_id()
	var rig: SkyGearRig3D = view._rigs.get(key)
	if rig == null:
		print("  the boarder has no rig — nothing to photograph")
		quit(1)
		return

	## EXPOSURE ONE: the shipped build, where `_xray` returns on its first line
	## for every mesh figure and the ghost is never set at all.
	## EXPOSURE TWO: the same frozen frame, with the silhouette the fix draws.
	## The tint is the one the enemy sync passes.
	## The full frame for context, and a crop at the boarder for the judgement —
	## the pairing every visual row in this repo is judged on, because a figure
	## 500 units up the deck is forty pixels tall in a 1600-wide plate.
	var at: Vector2 = view.camera.unproject_position(
		Vector3(best.x, 0.0, best.y) * SkyGearView3D.WORLD_SCALE)
	await _shoot(view, game, rig, false, "%s/behind-cargo-before.png" % out, at)
	await _shoot(view, game, rig, true, "%s/behind-cargo-after.png" % out, at)

	print("\n  wrote %s" % out)
	quit(0)


## Freeze, wait for the RENDERER rather than the tree, grab, thaw. `process_frame`
## fires when the TREE has finished its frame, which is not when the renderer has
## finished drawing it, and the difference is an intermittent black plate.
##
## THE GHOST IS SET AFTER THE FREEZE, ON PURPOSE. `SkyGearStill.freeze` runs its
## own zero-delta `_process` ticks to settle the scene, and those ticks re-enter
## `_xray` and re-decide the silhouette — so a state set BEFORE the freeze is
## simply overwritten by it, which is what made the first run of this tool print
## a confident line and save two identical pictures. Nothing ticks between the
## freeze and the readback, so setting it here is what actually reaches the film.
func _shoot(view: SkyGearView3D, game: SkyGearGame, rig: SkyGearRig3D,
		ghost: bool, path: String, at: Vector2) -> void:
	await SkyGearStill.freeze(self, view, game)
	rig.silhouette(ghost, Color(0.95, 0.30, 0.22, 0.55))
	var on := 0
	for child in rig.model.find_children("*", "MeshInstance3D", true, false):
		if (child as MeshInstance3D).material_overlay != null:
			on += 1
	await RenderingServer.frame_post_draw
	var img := get_root().get_texture().get_image()
	img.save_png(path)
	## Same box in both exposures, clamped to the plate, so the pair can be
	## flicked between without the subject moving.
	const CROP := Vector2i(560, 420)
	var origin := Vector2i(clampi(int(at.x) - CROP.x / 2, 0, img.get_width() - CROP.x),
		clampi(int(at.y) - CROP.y / 2 - 40, 0, img.get_height() - CROP.y))
	img.get_region(Rect2i(origin, CROP)).save_png(
		path.replace(".png", "-crop.png"))
	await SkyGearStill.thaw(self, view, game)
	print("  %-28s %d mesh parts ghosted" % [path.get_file(), on])
