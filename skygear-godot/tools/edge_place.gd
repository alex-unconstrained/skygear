extends SceneTree
## THE SHIP'S EDGE KIT, ON THE DECK — measured, and photographed at the shipped
## camera. SG-157.
##
##   godot --path . --script tools/edge_place.gd -- measure
##   godot --path . --script tools/edge_place.gd -- shots <tag> [spot] [zoom]
##   godot --path . --script tools/edge_place.gd -- scales [spot] [zoom]
##   godot --path . --script tools/edge_place.gd -- occlude
##
## `measure` is the only place the kit's numbers come from — the stanchion pitch,
## the rail heights and which way the bow's point faces are all read off the mesh
## rather than off a filename or a board row, which is how every other fact about
## these four pieces has been wrong at least once.
##
## `scales` photographs the RAIL SCALE CANDIDATES through the shipped renderer by
## calling `view.rebuild_edge_kit(n)`. It deliberately does NOT mock up its own
## rail: the whole question is which scale Alex wants shipped, and a comparison
## of something other than the shipped geometry answers a different question.
## That is failure mode two, and `deck_probe.gd`'s own rail mock-up is exactly
## the thing this avoids re-becoming.
##
## `occlude` is the kill-test DECK-IDENTITY item 4 pre-committed and it is
## measured through `unproject_position`, never eyeballed: a figure at one rail,
## the camera at the other, at both zooms.
##
## Writes `.shots/sg157/<tag>/<spot>-z<zoom>.png`.
##
## NOT `--headless`: every picture here is a framebuffer readback and headless
## has no GPU (SG-29). The freeze is `SkyGearStill` and the grab waits on
## `RenderingServer.frame_post_draw` (SG-108).

const W := 0.01                     ## WORLD_SCALE
const DECK := Rect2(-840, -1160, 1680, 2320)

const SPOTS := {
	"mid":       Vector2(0.50, 0.50),
	"port":      Vector2(0.06, 0.46),
	"starboard": Vector2(0.94, 0.46),
	"bow":       Vector2(0.50, 0.20),
	"stern":     Vector2(0.50, 0.86),
	## TWO SPOTS `deck_probe` DOES NOT HAVE, and the bow piece cannot be judged
	## without them: its `bow` is at z = -696, which is 464 units short of the bow
	## line and puts the whole stem off the top of the frame. `stem` and `transom`
	## stand her ON the boundary, which is as far as the sim will let her go and
	## therefore the only pose from which the ends are ever seen in play.
	"stem":      Vector2(0.50, 0.00),
	"transom":   Vector2(0.50, 1.00),
}

## The candidates. Whole tile counts only — see `view3d.gd:edge_rail_tiles` for
## why the scale is quantised rather than continuous.
const SCALE_CANDIDATES := [8, 10, 12]

var view                              ## SkyGearView3D
var game                              ## SkyGearGame


func _initialize() -> void: call_deferred("_run")


func _run() -> void:
	var argv := OS.get_cmdline_user_args()
	var mode := str(argv[0]) if argv.size() > 0 else "measure"

	if mode == "measure":
		_measure()
		quit(0)
		return

	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1600, 900))
	root.size = Vector2i(1600, 900)
	await process_frame
	await _boot()

	if mode == "occlude":
		await _occlude()
		quit(0)
		return

	if mode == "stern":
		view.edge_stern_trial = float(argv[1]) if argv.size() > 1 else 2.5
		view.edge_stern_z = float(argv[2]) if argv.size() > 2 else 1380.0
		view.rebuild_edge_kit(view.edge_rail_tiles)
		await process_frame
		await _sweep("stern-trial-s%.1f" % view.edge_stern_trial,
			["transom", "stern"], [1.0, 1.55])
		quit(0)
		return

	## SG-174. THE SEAT SWEEP FOR THE SECOND PAIR, and it exists for the same
	## reason `scales` exists: the question is which seat ships, and a comparison
	## of anything other than the shipped placement answers a different question.
	## Both drive `view3d.gd`'s own switches and rebuild the kit, so nothing here
	## carries a second copy of the placement.
	##
	##   ... -- prow -1550,-1650,-1700,-1740        aft-edge candidates, in z
	##   ... -- sternv2 1540,1440,1340              transom-face candidates, in z
	if mode == "prow":
		var seats: PackedStringArray = (str(argv[1]) if argv.size() > 1
			else "-1550,-1650,-1700,-1740").split(",")
		var tops: PackedStringArray = (str(argv[2]) if argv.size() > 2
			else "3").split(",")
		view.edge_stern_v2 = false
		for seat in seats:
			for top in tops:
				view.edge_prow_aft_z = float(seat)
				view.edge_prow_top = float(top)
				view.rebuild_edge_kit(view.edge_rail_tiles)
				await process_frame
				print("  aft edge z %.0f  top %+.0f  ->  %.0f across, %.0f deep, %.0f tall"
					% [view.edge_prow_aft_z, view.edge_prow_top,
						SkyGearView3D.PROW_NATIVE.x * view.edge_prow_scale(),
						SkyGearView3D.PROW_NATIVE.z * view.edge_prow_scale(),
						SkyGearView3D.PROW_NATIVE.y * view.edge_prow_scale()])
				await _sweep("sg174-prow-z%.0f-t%.0f"
					% [view.edge_prow_aft_z, view.edge_prow_top],
					["stem"], [1.0])
		quit(0)
		return

	if mode == "sternv2":
		var seats: PackedStringArray = (str(argv[1]) if argv.size() > 1
			else "1540,1440,1340").split(",")
		var tops: PackedStringArray = (str(argv[2]) if argv.size() > 2
			else "0").split(",")
		var yaws: PackedStringArray = (str(argv[3]) if argv.size() > 3
			else "-90").split(",")
		view.edge_prow = false
		for seat in seats:
			for top in tops:
				for yaw in yaws:
					view.edge_stern_v2_aft_z = float(seat)
					view.edge_stern_v2_top = float(top)
					view.edge_stern_v2_yaw = float(yaw)
					view.rebuild_edge_kit(view.edge_rail_tiles)
					await process_frame
					print("  transom z %.0f  top %+.0f  yaw %+.0f"
						% [seat.to_float(), top.to_float(), yaw.to_float()])
					await _sweep("sg174-stern-z%.0f-t%.0f-y%.0f"
						% [view.edge_stern_v2_aft_z, view.edge_stern_v2_top,
							view.edge_stern_v2_yaw],
						["transom"], [1.0])
		quit(0)
		return

	## SG-180. THE DECK EDGE, ONE STATE PER INVOCATION.
	##
	##   ... -- capping shipped              <spot> <zoom>
	##   ... -- capping legacy               <spot> <zoom>
	##   ... -- capping low[,div[,height]]   <spot> <zoom>
	##   ... -- capping gone                 <spot> <zoom>
	##   ... -- capping ends                 <spot> <zoom>   (breast rails only)
	##   ... -- capping both[,div]          <spot> <zoom>   (strake AND breast)
	##
	## `low` and `ends` are kept apart on purpose: the strake capping and the two
	## breast rails are different objects doing different jobs (the second draws
	## the play boundary, DECK-IDENTITY 6), and a sheet that changed both at once
	## could not say which one the owner is reacting to.
	##
	## It drives `view3d.gd`'s own switches through `rebuild_deck_edge()` and
	## carries no copy of the placement — the whole question is which of the three
	## the owner wants SHIPPED, and a comparison of anything but the shipped
	## builder answers a different question (failure mode two, and `scales` and
	## `prow` above exist under the same rule).
	if mode == "capping":
		var spec: PackedStringArray = (str(argv[1]) if argv.size() > 1
			else "shipped").split(",")
		var state := str(spec[0])
		if spec.size() > 1: view.strake_cap_rail_div = int(spec[1])
		if spec.size() > 2: view.strake_cap_rail_height = float(spec[2])
		view.strake_cap_mode = {"shipped": 2, "legacy": 0, "low": 1, "gone": 2,
			"ends": 0, "both": 1}.get(state, 2)
		view.end_cap_mode = 1 if state in ["shipped", "ends", "both"] else 0
		view.rebuild_deck_edge()
		await process_frame
		var cap_spots: Array = SPOTS.keys()
		var cap_zooms: Array = [1.0, 1.55]
		## Comma-separated, because the three poses SG-179 judged the deck edge at
		## belong in ONE freeze: three invocations of a shot tool never land their
		## flicker, particles and cloud drift at the same point twice (SG-108).
		if argv.size() > 2:
			cap_spots = []
			for one in str(argv[2]).split(","):
				if SPOTS.has(str(one)): cap_spots.append(str(one))
		if argv.size() > 3: cap_zooms = [float(argv[3])]
		print("  capping %s  div %d  height %.2f"
			% [state, view.strake_cap_rail_div, view.strake_cap_rail_height])
		await _sweep("sg180-%s" % str(argv[1]).replace(",", "-"), cap_spots, cap_zooms)
		quit(0)
		return

	if mode == "mast":
		## The rig is built in `_ready`, so this rebuilds it rather than setting a
		## flag nobody will read again.
		view.rig_model_masts = true
		view._rigging.queue_free()
		view.remove_child(view._rigging)
		view._build_rigging()
		await process_frame
		await _sweep("mast-trial", ["mid", "port"], [1.0, 1.55])
		quit(0)
		return

	if mode == "where":
		if argv.size() > 3:
			view.edge_stern_trial = float(argv[3])
			view.edge_stern_z = float(argv[4]) if argv.size() > 4 else 1380.0
			view.rebuild_edge_kit(view.edge_rail_tiles)
			await process_frame
		await _where(str(argv[1]) if argv.size() > 1 else "stem",
			float(argv[2]) if argv.size() > 2 else 1.55)
		quit(0)
		return

	var spots: Array = SPOTS.keys()
	var zooms: Array = [1.0, 1.55]
	if mode == "scales":
		if argv.size() > 1 and SPOTS.has(str(argv[1])): spots = [str(argv[1])]
		if argv.size() > 2: zooms = [float(argv[2])]
		for n in SCALE_CANDIDATES:
			view.rebuild_edge_kit(int(n))
			await process_frame
			await _sweep("scale-%d" % int(n), spots, zooms)
		quit(0)
		return

	if mode == "before":
		view.edge_rail_legacy = true
		view.rebuild_edge_kit(view.edge_rail_tiles)
		await process_frame
		if argv.size() > 1 and SPOTS.has(str(argv[1])): spots = [str(argv[1])]
		if argv.size() > 2: zooms = [float(argv[2])]
		await _sweep("before", spots, zooms)
		quit(0)
		return

	var tag := str(argv[1]) if argv.size() > 1 else "after"
	if argv.size() > 2 and SPOTS.has(str(argv[2])): spots = [str(argv[2])]
	if argv.size() > 3: zooms = [float(argv[3])]
	await _sweep(tag, spots, zooms)
	quit(0)


func _boot() -> void:
	var world = load("res://scenes/main3d.tscn").instantiate()
	root.add_child(world)
	await process_frame
	view = world
	game = world.get_node("SkyGear")
	## NO CUTSCENE. `begin_run` fires the run-opening reveal, which HIDES THE HUD,
	## LOCKS THE CONTROLS AND TAKES THE CAMERA — so a tool that poses the captain
	## and photographs "the shipped camera" without turning this off photographs
	## the cutscene's camera instead, with CLICK TO SKIP across the corner.
	##
	## Found here, and it is not confined to this file: `tools/deck_probe.gd`
	## does not do this either, so its frames — and the pictures DECK-DESIGN.md
	## draws its camera claims from — are opening-cutscene frames. Measured: with
	## the reveal running the camera sat at z = 1423 for BOTH a mid pose and a
	## transom pose, when the gameplay camera is `focus.y + 460` and those two
	## poses differ by a thousand units. Filed on the board.
	view.cutscenes_enabled = false
	game.workshop = SkyGearWorkshop.fresh(true)
	game.heat = 0
	game.set_class("captain")
	game.set_seed_text("DECK")
	game.begin_run()
	game.choose_draft(0)
	game.start_wave(1)
	game.spawn_queue.clear()
	## The sway is off for the same reason `deck_probe` turns it off: a roll
	## between two plates is a difference that is not the thing being compared.
	view.sway = false
	view.stop_cutscene()
	for _i in 20:
		game._process(1.0 / 60.0)
		await process_frame
	## THE HUD IS OFF. This photographs the LEVEL; a wave banner across the
	## middle of the frame is why the first pass at these shots was unreadable.
	var overlay = game.get_node_or_null("HUD")
	if overlay != null:
		overlay.visible = false


func _pose(spot: String, zoom: float) -> void:
	if game.state == SkyGearGame.State.DRAFT:
		game.choose_draft(0)
	game.start_wave(1)
	game.spawn_queue.clear()
	var at: Vector2 = SPOTS[spot]
	game.player.global_position = Vector2(
		DECK.position.x + DECK.size.x * at.x,
		DECK.position.y + DECK.size.y * at.y)
	game.player.velocity = Vector2.ZERO
	## Snap past the easing rather than setting the target and photographing the
	## tail of a lerp — the follow has a 0.155 s time constant.
	view._focus_set = false
	view._zoom = zoom
	view._zoom_target = zoom
	for _i in 4:
		game._process(1.0 / 60.0)
		await process_frame


func _sweep(tag: String, spots: Array, zooms: Array) -> void:
	var out_dir := "res://.shots/sg157/%s" % tag
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	for spot in spots:
		for zoom in zooms:
			await _pose(str(spot), float(zoom))
			await SkyGearStill.freeze(self, view, game)
			var path := "%s/%s-z%.2f.png" % [out_dir, str(spot), float(zoom)]
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(path)
			await SkyGearStill.thaw(self, view, game)
			print("  %s" % path.replace("res://", ""))


## --- the kill-test, measured -------------------------------------------------
##
## DECK-IDENTITY item 4 pre-committed this and it is the reason the rail is
## allowed to exist: *a figure at one rail, the camera at the other, at every
## zoom. Any occlusion and the item is cut.* `_occluded()` tests `CARGO_RECTS`
## only, so a rail that DID hide a boarder would fail silently and nobody would
## learn it from the game.
##
## Measured rather than reasoned: put the captain hard against one rail, walk a
## probe point up her body, and ask whether the segment from the camera to that
## point passes through any rail module's world AABB.
func _occlude() -> void:
	var worst := 0
	for zoom in [1.0, 1.55]:
		for side in [-1.0, 1.0]:
			await _pose("port" if side < 0.0 else "starboard", zoom)
			## Hard against the rail — further outboard than a figure can go.
			game.player.global_position = Vector2(side * 750.0, 0.0)
			for _i in 4:
				game._process(1.0 / 60.0)
				await process_frame
			var cam: Camera3D = view.camera
			var eye: Vector3 = cam.global_position
			var hits := 0
			for f in 11:
				var h: float = 176.0 * float(f) / 10.0
				var tgt := Vector3(side * 750.0, h, 0.0) * W
				for node in view._edge_kit.get_children():
					var box: AABB = _world_aabb(node)
					if box.intersects_segment(eye, tgt):
						hits += 1
			print("  zoom %.2f  %s rail  segments blocked: %d"
				% [zoom, "port" if side < 0.0 else "starboard", hits])
			worst = maxi(worst, hits)
	print("WORST %d  (0 is the pass condition)" % worst)


## WHERE A PIECE ACTUALLY LANDS ON SCREEN, in pixels of the 1600x900 frame.
##
## This exists because of a near-miss worth recording: at the stem pose there is
## a dark drum-shaped mass just above the captain's head, and it was about to be
## written up as `bow_ram` reading badly. It is in the BEFORE frames too. A shape
## in a screenshot is not evidence about the piece you just placed unless you
## know where that piece projects, so this prints it rather than inferring it.
func _where(spot: String, zoom: float) -> void:
	await _pose(spot, zoom)
	var cam: Camera3D = view.camera
	## The VIEWPORT's own size, never a hard-coded 1600 x 900 — they differ here,
	## and a screen-space overlap measured against the wrong width is a number
	## that looks fine and means nothing.
	var frame: Vector2 = cam.get_viewport().get_visible_rect().size
	print("screen-space at spot=%s zoom=%.2f  (frame is %d x %d)"
		% [spot, zoom, int(frame.x), int(frame.y)])
	print("  camera at z %.0f   focus %s" % [cam.global_position.z / W, str(view._focus)])
	## WHERE THE FRAME'S EDGES LAND ON THE DECK. The stern verdict rests on the
	## BOTTOM edge and nothing else had ever printed it: `deck_probe -- measure`
	## reports the top edge only, so "the aft half is off screen" had been an
	## assertion since DECK-IDENTITY was written.
	for edge in [["top", 0.0], ["bottom", frame.y]]:
		var o: Vector3 = cam.project_ray_origin(Vector2(frame.x * 0.5, float(edge[1])))
		var d: Vector3 = cam.project_ray_normal(Vector2(frame.x * 0.5, float(edge[1])))
		if absf(d.y) > 0.0001:
			var t: float = -o.y / d.y
			if t > 0.0:
				print("  frame %-6s edge meets the deck at z %.0f"
					% [str(edge[0]), (o + d * t).z / W])
			else:
				print("  frame %-6s edge never meets the deck (points at the sky)"
					% str(edge[0]))
	if game.player != null:
		var p: Vector2 = game.player.global_position
		print("  captain stands at %s" % str(p.round()))
		var head: Vector2 = cam.unproject_position(Vector3(p.x, 176.0, p.y) * W)
		var foot: Vector2 = cam.unproject_position(Vector3(p.x, 0.0, p.y) * W)
		print("  captain      head %s  foot %s" % [str(head.round()), str(foot.round())])
	for node in view._edge_kit.get_children():
		var box: AABB = _world_aabb(node)
		var lo := Vector2(1e9, 1e9)
		var hi := Vector2(-1e9, -1e9)
		var behind := 0
		for i in 8:
			var c: Vector3 = box.get_endpoint(i)
			if cam.is_position_behind(c):
				behind += 1
				continue
			var s: Vector2 = cam.unproject_position(c)
			lo = Vector2(minf(lo.x, s.x), minf(lo.y, s.y))
			hi = Vector2(maxf(hi.x, s.x), maxf(hi.y, s.y))
		var label: String = str(node.name)
		if behind == 8:
			print("  %-22s entirely behind the camera" % label)
			continue
		print("  %-22s x %5.0f..%5.0f  y %5.0f..%5.0f%s"
			% [label, lo.x, hi.x, lo.y, hi.y,
				("  (%d corners behind)" % behind) if behind > 0 else ""])


func _world_aabb(node: Node3D) -> AABB:
	var out := AABB()
	var first := true
	var stack: Array = [node]
	while not stack.is_empty():
		var n = stack.pop_back()
		for c in n.get_children(): stack.append(c)
		if n is MeshInstance3D and n.mesh != null:
			var a: AABB = n.global_transform * n.get_aabb()
			if first: out = a; first = false
			else: out = out.merge(a)
	return out


## --- the numbers, off the mesh ------------------------------------------------
func _measure() -> void:
	print("EDGE KIT — measured off the meshes, in GROUND UNITS (1 m = 100)")
	for key in ["rail_stanchion", "bow_ram", "stern_counter", "mast_crowned"]:
		var path := "res://assets/models/%s/%s.tscn" % [key, key]
		var scene: PackedScene = load(path)
		if scene == null:
			print("  %-15s NO SCENE" % key)
			continue
		var inst: Node3D = scene.instantiate()
		root.add_child(inst)
		var v := _verts(inst)
		var box := _world_aabb(inst)
		var tris := _tris(inst)
		print("  %-15s %6.1f x %6.1f x %6.1f   %5d tris"
			% [key, box.size.x / W, box.size.y / W, box.size.z / W, tris])
		if key == "rail_stanchion":
			_rail_detail(v)
		if key == "bow_ram":
			_taper(v)
		inst.free()
	print("")
	print("RAIL SCALE CANDIDATES — N tiles across the 2320-unit deck")
	print("  N   spacing   pitch   scale    rail top   %% of a 176-unit captain")
	for n in SCALE_CANDIDATES:
		var spacing: float = DECK.size.y / float(n)
		var s: float = spacing / (2.0 * 83.45)
		var top: float = 90.17 * s
		print("  %2d   %7.1f  %6.1f   %.4f   %7.1f   %5.0f%%"
			% [n, spacing, spacing * 0.5, s, top, top / 176.0 * 100.0])


func _rail_detail(v: PackedVector3Array) -> void:
	## The two rail BANDS, found as the gaps in the y profile — the open gaps are
	## the whole cue and they are where the sky shows through.
	var bins := 45
	var occupied: Array[bool] = []
	for b in bins:
		var y0: float = 0.901667 * float(b) / bins
		var y1: float = 0.901667 * float(b + 1) / bins
		var n := 0
		for p in v:
			if p.y >= y0 and p.y < y1: n += 1
		occupied.append(n > 0)
	var runs: Array = []
	var start := -1
	for b in bins:
		if occupied[b] and start < 0: start = b
		if (not occupied[b] or b == bins - 1) and start >= 0:
			runs.append([start, b])
			start = -1
	print("      solid bands in y (ground units at scale 1), gaps between them")
	for r in runs:
		print("        %5.1f .. %5.1f"
			% [0.901667 * float(r[0]) / bins * 100.0, 0.901667 * float(r[1]) / bins * 100.0])
	for n in SCALE_CANDIDATES:
		var s: float = (DECK.size.y / float(n)) / (2.0 * 83.45)
		var line := "      N=%2d bands at " % n
		for r in runs:
			var mid: float = 0.901667 * (float(r[0]) + float(r[1])) * 0.5 / bins * 100.0
			line += "%.1f  " % (mid * s)
		print(line + " (spec wants 66 and 118)")


func _taper(v: PackedVector3Array) -> void:
	## Which end is the point. Reported because the placement basis depends on it
	## and "the files do not say what they are" is the standing lesson here.
	var lo := 9.0
	var hi := -9.0
	for p in v:
		lo = minf(lo, p.x); hi = maxf(hi, p.x)
	for end in [-1.0, 1.0]:
		var edge: float = lo if end < 0.0 else hi
		var span := 0.0
		var vmin := Vector2(9, 9)
		var vmax := Vector2(-9, -9)
		for p in v:
			if absf(p.x - edge) < 0.10:
				vmin = Vector2(minf(vmin.x, p.y), minf(vmin.y, p.z))
				vmax = Vector2(maxf(vmax.x, p.y), maxf(vmax.y, p.z))
		span = maxf(vmax.x - vmin.x, vmax.y - vmin.y)
		print("      %s end cross-section %5.1f ground units"
			% ["-X" if end < 0.0 else "+X", span * 100.0])
	print("      -> the SMALLER end is the point; the placement maps it to -Z")


func _verts(node: Node3D) -> PackedVector3Array:
	var out := PackedVector3Array()
	var stack: Array = [node]
	while not stack.is_empty():
		var n = stack.pop_back()
		for c in n.get_children(): stack.append(c)
		if n is MeshInstance3D and n.mesh != null:
			for s in n.mesh.get_surface_count():
				var a: PackedVector3Array = n.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
				for p in a: out.append(n.global_transform * p)
	return out


func _tris(node: Node3D) -> int:
	var total := 0
	var stack: Array = [node]
	while not stack.is_empty():
		var n = stack.pop_back()
		for c in n.get_children(): stack.append(c)
		if n is MeshInstance3D and n.mesh != null:
			for s in n.mesh.get_surface_count():
				var arr: Array = n.mesh.surface_get_arrays(s)
				var idx = arr[Mesh.ARRAY_INDEX]
				if idx != null:
					total += idx.size() / 3
				else:
					total += (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	return total
