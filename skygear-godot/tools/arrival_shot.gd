extends SceneTree
## A SHIP PULLS UP TO THE FRONT — photographed, because this one is judged by eye.
##
##   godot --path . --script tools/arrival_shot.gd
##
## Board SG-134 stage one. The harness checks the arithmetic — that a hull is
## named for every wave but the boss's, that it starts at its station and
## finishes on the hold, that it parks by its DECK rather than its keel, and that
## its footprint there clears the deck and the cargo — and none of that says
## whether the picture reads. Only a frame does, and only the owner can score it.
##
## WHAT IT SHOOTS. Two plates for each pose and zoom, FROM ONE CAMERA: the hull
## AT ITS AMBIENT STATION (`u = 0`, the frame the wave begins) and the hull ON
## THE BOW HOLD (`u = 1`, the fight). Read as a pair they carry the whole of
## stage one — a ship has come forward, and the gap it left in the wedge is the
## second reading the design asks for and costs nothing, because the ship on the
## bow and the gap in the wedge are the same node.
##
## THE POSES ARE `skyship_probe.gd`'s, not a fresh set: those are the places a
## run is actually spent, they are the poses the ambient fleet was measured from,
## and a second table of play positions in a second file is the failure this
## project keeps having. `mid` is included even though SG-102 measured the deck
## as 100% of the frame there — the point of shooting it is to SHOW the owner the
## half of the runtime where no hull is visible at all, which §6 of the design
## says out loud and which he should see rather than be told.
##
## WINDOWED (SG-29): headless has no GPU and every readback comes back black.
## FROZEN (SG-108): through `SkyGearStill`, so two runs of this tool agree.

const POSES := {
	"bow": Vector2(0.50, 0.06),
	"fight": Vector2(0.50, 0.35),
	"mid": Vector2(0.50, 0.50),
	"port": Vector2(0.06, 0.46),
}
const ZOOMS := [1.0, 1.55]

## Which wave to photograph. Wave 1 brings the cutter forward — the nearest hull
## and the largest on screen, which is why `ARRIVAL_HULL_ORDER` starts with it.
const WAVE := 1


## THE CANDIDATE HOLDS, for `-- holds`. The mark this tier was handed
## (`SKYSHIP_BOW_HOLD`, x = 0) is FIRST and in the sweep on purpose: it is the
## one the design specifies, and it is in here to be photographed rather than
## argued about. Everything else is a bearing off the port bow, because all four
## ambient stations that read are well off the centreline.
const HOLDS := {
	"dead-ahead-2600": Vector2(0.0, -2600.0),
	"dead-ahead-3400": Vector2(0.0, -3400.0),
	"port-1250-2200": Vector2(-1250.0, -2200.0),
	"port-1250-3000": Vector2(-1250.0, -3000.0),
	"port-1900-3400": Vector2(-1900.0, -3400.0),
	"port-2000-2400": Vector2(-2000.0, -2400.0),
}


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

	## The same three suppressions every measurement in this repo is taken under.
	view.cutscenes_enabled = false
	view.stop_cutscene()
	view.sway = false
	game.workshop = SkyGearWorkshop.fresh(true)
	game.heat = 0
	game.set_class("captain")
	game.set_seed_text("SKY")
	game.begin_run()
	game.choose_draft(0)
	if game.wave != WAVE:
		game.start_wave(WAVE)
	for _i in 20:
		game._process(1.0 / 60.0)
		await process_frame

	var hull := SkyGearView3D.arrival_hull_for_wave(WAVE)
	print("\nwave %d brings %s forward" % [WAVE, hull])

	var out := ProjectSettings.globalize_path("res://../.shots/sg134")
	DirAccess.make_dir_recursive_absolute(out)
	var deck: Rect2 = SkyGearGame.DECK_RECT

	## --- `-- holds`: WHERE CAN THE ARRIVING HULL ACTUALLY BE SEEN FROM? -------
	##
	## Photographic, and it has to be. `skyship_probe.gd`'s analytic sweep placed
	## `SKYSHIP_BOW_HOLD` dead ahead because the bow is in the frustum from every
	## pose — and its own header says the sweep cannot see this ship's opaque
	## hull, which dead ahead and below is exactly what is in the way. A frustum
	## test cannot answer this question and a frame can.
	if OS.get_cmdline_user_args().size() > 0 \
			and str(OS.get_cmdline_user_args()[0]) == "holds":
		var holds_dir := out + "/holds"
		DirAccess.make_dir_recursive_absolute(holds_dir)
		for name in HOLDS:
			var xz: Vector2 = HOLDS[name]
			for pose in ["bow", "mid"]:
				await _pose(game, view, deck, POSES[pose], 1.0)
				game.set_process(false)
				game.wave_time = SkyGearView3D.ARRIVAL_APPROACH
				game.wave_clear_time = -1.0
				view.set("_zoom", 1.0)
				view.set("_zoom_target", 1.0)
				view.set("_focus", game.player.global_position)
				view.set("_focus_set", true)
				view._process(1.0 / 60.0)
				## AFTER the freeze, not before it. `freeze` awaits, the engine
				## draws frames while it does, and `view._process` runs on every
				## one of them — so a position written before it is overwritten
				## by the real `_sync_arrival` and all six candidates come back as
				## six photographs of the shipped hold.
				await SkyGearStill.freeze(self, view, game)
				_force_hold(view, hull, xz)
				await RenderingServer.frame_post_draw
				get_root().get_texture().get_image().save_png(
					"%s/%s-%s.png" % [holds_dir, name, pose])
				await SkyGearStill.thaw(self, view, game)
				for s2: Dictionary in view.get("_skyships"):
					(s2.node as Node3D).visible = true
				game.set_process(true)
			print("  %-16s %s" % [name, xz])
		print("\nframes -> .shots/sg134/holds/")
		quit()
		return
	## --- `-- ring`: THE LANDING RING, ACROSS ITS CLOSE ------------------------
	##
	## Stage two, and the channel that has to work from mid-deck because stage
	## one demonstrably does not (`.shots/sg134/mid-z1.00-hold.png`). Three
	## boarders held at three points of the same arrival window, in one frame, so
	## the CLOSE is visible in a still: a ring at one radius is a photograph of a
	## circle, and the thing being judged is a countdown.
	if OS.get_cmdline_user_args().size() > 0 \
			and str(OS.get_cmdline_user_args()[0]) == "ring":
		for pose in ["mid", "fight"]:
			await _pose(game, view, deck, POSES[pose], 1.0)
			game.set_process(false)
			## Tight enough that all three fit one frame: the point of the plate
			## is the PROGRESSION, and a stage that falls off the edge is a stage
			## the owner has to take on trust.
			var lane_x := [-330.0, 0.0, 330.0]
			var held: Array[SkyGearEnemy] = []
			for enemy in game.enemies():
				if is_instance_valid(enemy) and not enemy.dead:
					held.append(enemy)
			for i in held.size():
				held[i].queue_free()
			await process_frame
			for i in 3:
				game.spawn_enemy("SCRAPPER", i)
			await process_frame
			var n := 0
			for enemy in game.enemies():
				if not is_instance_valid(enemy) or enemy.dead:
					continue
				## Opening, half shut, and the frame before contact.
				enemy.state = "climb"
				enemy.state_time = SkyGearEnemy.ARRIVAL_TIME * [0.98, 0.5, 0.06][n % 3]
				enemy.global_position = Vector2(lane_x[n % 3],
					game.player.global_position.y - 300.0)
				n += 1
			view.set("_zoom", 1.0)
			view.set("_zoom_target", 1.0)
			view.set("_focus", game.player.global_position)
			view.set("_focus_set", true)
			view._process(1.0 / 60.0)
			await SkyGearStill.freeze(self, view, game)
			await RenderingServer.frame_post_draw
			get_root().get_texture().get_image().save_png(
				"%s/ring-%s.png" % [out, pose])
			await SkyGearStill.thaw(self, view, game)
			game.set_process(true)
			print("  ring %-6s  three boarders at 98%%, 50%% and 6%% of the window" % pose)
		print("\nframes -> .shots/sg134/ring-*.png")
		quit()
		return

	for pose in POSES:
		for zoom in ZOOMS:
			await _pose(game, view, deck, POSES[pose], zoom)
			for stage in ["station", "hold"]:
				## THE WHOLE OF THE ARRIVAL'S STATE IS TWO NUMBERS THE SIM
				## ALREADY KEEPS, which is what makes it freezable and
				## repeatable — so posing it is writing them, not driving a timer
				## for two and a half seconds and hoping the shutter lands.
				##
				## The sim is stopped FIRST and the renderer stepped by hand
				## afterwards. Left running, `_update_wave` re-derives
				## `wave_clear_time` from an empty deck before the next frame
				## draws and the second plate comes back mid-departure; and
				## posing the camera between the two plates would give the pair
				## two cameras, which is the one comparison this tool exists for.
				game.set_process(false)
				game.wave_time = 0.0 if stage == "station" \
					else SkyGearView3D.ARRIVAL_APPROACH
				game.wave_clear_time = -1.0
				## The camera is re-pinned before EVERY plate, not once per pose.
				## `view._process` eases the focus toward its target, so stepping
				## it twice from one pose walks the camera between the two plates
				## and hands the pair two cameras.
				view.set("_zoom", zoom)
				view.set("_zoom_target", zoom)
				view.set("_focus", game.player.global_position)
				view.set("_focus_set", true)
				view._process(1.0 / 60.0)
				print("      %-7s u=%.2f  %s at %s" % [stage,
					SkyGearView3D.arrival_u(game.wave_time, game.wave_clear_time),
					hull, _hull_at(view, hull)])
				await SkyGearStill.freeze(self, view, game)
				await RenderingServer.frame_post_draw
				get_root().get_texture().get_image().save_png(
					"%s/%s-z%.2f-%s.png" % [out, pose, zoom, stage])
				await SkyGearStill.thaw(self, view, game)
				game.set_process(true)
			print("  %-6s z%.2f  station + hold" % [pose, zoom])
	print("\nframes -> .shots/sg134/   (compare each -station against its -hold)")
	quit()


## Put the named hull on a candidate bearing for one frame, keeping the deck line
## the tier actually uses. Only `-- holds` calls this; the shipped path never
## writes a position the renderer did not derive.
## …and hides every OTHER hull while it does, which is `skyship_probe.gd`'s own
## pass-3 idiom and here it is the difference between an experiment and a
## guess: four transports in one frame at the same bearings means the thing you
## are trying to see is exactly the thing you cannot pick out.
func _force_hold(view: SkyGearView3D, hull: String, xz: Vector2) -> void:
	for s: Dictionary in view.get("_skyships"):
		var node: Node3D = s.node
		var mine: bool = str(s.get("model", "")) == hull
		node.visible = mine
		if mine:
			node.position = Vector3(xz.x,
				SkyGearView3D.ARRIVAL_DECK_Y - float(s.get("tall", 0.0)), xz.y) \
				* SkyGearView3D.WORLD_SCALE


## Where the named hull actually is this frame, in GROUND units, and whether the
## camera can see its centre. Printed rather than asserted: the assertion lives
## in the harness, and what this is for is telling a person reading the log which
## of "it did not move" and "it moved and is behind our own bow" they are looking
## at in the frame.
func _hull_at(view: SkyGearView3D, hull: String) -> String:
	for s: Dictionary in view.get("_skyships"):
		if str(s.get("model", "")) != hull:
			continue
		var node: Node3D = s.node
		var ground: Vector3 = node.position / SkyGearView3D.WORLD_SCALE
		var camera: Camera3D = view.camera
		var on := not camera.is_position_behind(node.position)
		var where := ""
		if on:
			var p := camera.unproject_position(node.position)
			on = Rect2(Vector2.ZERO, Vector2(camera.get_viewport().size)).has_point(p)
			where = " screen %.0f,%.0f" % [p.x, p.y]
		return "x %.0f y %.0f z %.0f  centre %s%s" % [ground.x, ground.y, ground.z,
			"IN FRAME" if on else "off frame", where]
	return "(not built)"


## `skyship_probe.gd`'s poser, and deliberately its exact shape — including the
## draft check INSIDE the loop, because an empty wave clears itself after a
## second and a half and opens three skill cards over the top of the frame.
##
## ONE DEPARTURE: the spawn queue is left ALONE rather than cleared. An empty
## deck raises the WAVE CLEAR banner across the middle of every plate, and a
## banner is the one thing that would make these frames unreadable — so the wave
## is allowed to put its own boarders on the planking, which is also the
## condition the picture is actually seen under.
func _pose(game: SkyGearGame, view: SkyGearView3D, deck: Rect2,
		at: Vector2, zoom: float) -> void:
	if game.state == SkyGearGame.State.DRAFT:
		game.choose_draft(0)
	if game.wave != WAVE:
		game.start_wave(WAVE)
	game.player.global_position = Vector2(
		deck.position.x + deck.size.x * at.x,
		deck.position.y + deck.size.y * at.y)
	game.player.velocity = Vector2.ZERO
	view.set("_zoom", zoom)
	view.set("_zoom_target", zoom)
	view.set("_focus", game.player.global_position)
	view.set("_focus_set", true)
	for _i in 4:
		if game.state == SkyGearGame.State.DRAFT:
			game.choose_draft(0)
		if game.wave != WAVE:
			game.start_wave(WAVE)
		game._process(1.0 / 60.0)
		await process_frame
	if game.state == SkyGearGame.State.DRAFT:
		game.choose_draft(0)
		await process_frame
