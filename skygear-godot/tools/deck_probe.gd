extends SceneTree
## Measure and mock up the deck, without touching the renderer.
##
## WHY THIS EXISTS. `docs/DECK-DESIGN.md` makes claims about what a 41-degree
## camera can and cannot show, and this project has repeatedly shipped visual
## claims that were not checked. Every number and every picture in that document
## comes out of this file.
##
## It never edits `scripts/view3d.gd`. It instantiates `main3d.tscn` and adds
## nodes to the World at runtime, which is enough to try any geometry proposal
## and is guaranteed not to fight whoever else is in the renderer today.
##
##   godot --path . --script tools/deck_probe.gd -- measure
##   godot --path . --script tools/deck_probe.gd -- headroom
##   godot --path . --script tools/deck_probe.gd -- <variant> [spot] [zoom]
##
## Variants:  base rail hull rig sheer combo
## Spots:     mid port starboard bow stern
##
## Writes `.shots/deck/<variant>-<spot>-z<zoom>.png`.

const W := 0.01                     ## WORLD_SCALE
const DECK := Rect2(-840, -1160, 1680, 2320)

const SPOTS := {
	"mid":       Vector2(0.50, 0.50),
	"port":      Vector2(0.06, 0.46),
	"starboard": Vector2(0.94, 0.46),
	"bow":       Vector2(0.50, 0.20),
	"stern":     Vector2(0.50, 0.86),
}

var view                              ## SkyGearView3D
var game                              ## SkyGearGame


func _initialize() -> void: call_deferred("_run")


func _run() -> void:
	var argv := OS.get_cmdline_user_args()
	var variant := str(argv[0]) if argv.size() > 0 else "base"

	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1600, 900))
	root.size = Vector2i(1600, 900)
	await process_frame

	if variant == "measure":
		_measure()
		quit(0)
		return

	var out_dir := "res://.shots/deck"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))

	var world = load("res://scenes/main3d.tscn").instantiate()
	root.add_child(world)
	await process_frame
	view = world
	game = world.get_node("SkyGear")

	game.workshop = SkyGearWorkshop.fresh(true)
	game.heat = 0
	game.set_class("captain")
	game.set_seed_text("DECK")
	game.begin_run()
	game.choose_draft(0)
	game.start_wave(1)
	game.spawn_queue.clear()
	view.sway = false
	for _i in 20:
		game._process(1.0 / 60.0)
		await process_frame

	## THE HUD IS OFF for every one of these. This tool photographs the LEVEL, and
	## a wave banner across the middle of the frame is the reason the first pass at
	## these shots could not be read.
	var overlay = game.get_node_or_null("HUD")
	if overlay != null:
		overlay.visible = false

	match variant:
		"base": pass
		"noair": _hide_airstream()
		"airfix": _fix_airstream()
		"airsize":
			_report_airstream()
			quit(0)
			return
		"rig2": _build_rig2(false)
		"rigshadow": _build_rig2(true)
		"catwalk": _build_catwalk()
		"best":
			_build_rail()
			_build_sheer()
			_build_rig2(true)
			_fix_airstream()
		"headroom": _build_headroom()
		"rail": _build_rail()
		"hull": _build_hull()
		"rig": _build_rig()
		"sheer": _build_sheer()
		"combo":
			_build_hull()
			_build_rail()
			_build_rig()
			_build_sheer()
		_:
			print("no variant %r" % variant)
			quit(1)
			return
	await process_frame

	var spots: Array = SPOTS.keys()
	if argv.size() > 1 and SPOTS.has(str(argv[1])):
		spots = [str(argv[1])]
	var zooms: Array = [1.0, 1.55]
	if argv.size() > 2:
		zooms = [float(argv[2])]

	for spot in spots:
		for zoom in zooms:
			if game.state == SkyGearGame.State.DRAFT:
				game.choose_draft(0)
			game.start_wave(1)
			game.spawn_queue.clear()
			var at: Vector2 = SPOTS[spot]
			game.player.global_position = Vector2(
				DECK.position.x + DECK.size.x * at.x,
				DECK.position.y + DECK.size.y * at.y)
			game.player.velocity = Vector2.ZERO
			view._focus_set = false
			view._zoom = float(zoom)
			view._zoom_target = float(zoom)
			for _i in 4:
				game._process(1.0 / 60.0)
				await process_frame
			## FROZEN (SG-108). deck_probe had NO freeze at all, and this is the
			## tool DECK-DESIGN.md's pictures come out of — each variant is a
			## SEPARATE PROCESS invocation, so two runs never land their rigs,
			## particles or flicker phase at the same point twice and a variant
			## comparison was partly comparing the weather.
			await SkyGearStill.freeze(self, view, game)
			var path := "%s/%s-%s-z%.2f.png" % [out_dir, variant, spot, zoom]
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(path)
			await SkyGearStill.thaw(self, view, game)
			print("  %s" % path.replace("res://", ""))
	quit(0)


## --- the airstream, measured -------------------------------------------------
##
## `_build_airstream` intends a hairline ribbon: "a flat ribbon lying in the air,
## long axis along the keel; a camera pitched 41 degrees projects that to a
## near-vertical line". This prints what the transform ACTUALLY produces, because
## the shots show broad horizontal bands crossing the deck instead.
func _report_airstream() -> void:
	view._sync_airstream(0.0)
	for i in [0, 1, 2]:
		var node: MeshInstance3D = view._stream[i]
		var b: Basis = node.transform.basis
		## QuadMesh lies in local XY; local Z is its normal.
		var ax: Vector3 = b.x
		var ay: Vector3 = b.y
		print("streak %d" % i)
		print("  wanted   %.1f x %.2f ground units (len x width)"
			% [view._stream_len[i * 2], view._stream_len[i * 2 + 1]])
		print("  got      %.1f x %.1f ground units" % [ax.length() / W, ay.length() / W])
		print("  long axis in world  %s" % str(ax.normalized()))
		print("  short axis in world %s" % str(ay.normalized()))
		print("  normal              %s" % str(b.z.normalized()))
		print("  height above deck   %.0f ground units" % (node.position.y / W))


## Undo the swap WITHOUT touching the renderer, by pre-compensating the mesh.
##
## `_sync_airstream` rewrites `node.transform` every frame, so the basis cannot be
## corrected from out here — but it never touches `node.mesh`. The quad is 1x1 and
## the basis then stretches local X by exactly 1 metre and local Y by `len * W`
## metres, so sizing the quad to (L*W, w/L) lands the intended L by w ribbon.
func _fix_airstream() -> void:
	for i in view._stream.size():
		var node: MeshInstance3D = view._stream[i]
		var length: float = view._stream_len[i * 2]
		var width: float = view._stream_len[i * 2 + 1]
		var q := QuadMesh.new()
		q.size = Vector2(length * W, width / length)
		node.mesh = q


func _hide_airstream() -> void:
	for node in view._stream:
		node.visible = false


## --- the measurement ---------------------------------------------------------
##
## Everything the design document asserts about framing, computed from the four
## camera constants rather than eyeballed off a screenshot.
func _measure() -> void:
	var PITCH := 0.72
	var CAM_H := 760.0
	var CAM_NEAR := 460.0
	var FOCAL := 1320.0
	var REF_H := 860.0
	var half_v := atan((REF_H * 0.5) / FOCAL)
	var tan_v := (REF_H * 0.5) / FOCAL
	var tan_h := tan_v * 16.0 / 9.0
	var half_h := atan(tan_h)

	print("CAMERA")
	print("  pitch              %.2f deg below horizontal" % rad_to_deg(PITCH))
	print("  half vertical fov  %.2f deg" % rad_to_deg(half_v))
	print("  half horiz fov     %.2f deg" % rad_to_deg(half_h))
	print("  top ray elevation  %.2f deg  (negative = still looking DOWN)"
		% -rad_to_deg(PITCH - half_v))
	print("  bottom ray         %.2f deg" % -rad_to_deg(PITCH + half_v))
	print("  -> the horizon is above the top of the frame at every zoom, because")
	print("     zoom moves the camera along its axis and never changes the lens.")
	print("     A pitch of %.2f deg or less would be needed to see it."
		% rad_to_deg(half_v))
	print("")

	for zoom in [1.0, 1.55]:
		var h: float = CAM_H * zoom
		var cz: float = CAM_NEAR * zoom          ## camera z, relative to the focus
		var slope_top: float = tan(PITCH - half_v)
		print("ZOOM %.2f   camera %.0f above deck, %.0f astern of the focus" % [zoom, h, cz])
		## Where the top of the frame crosses the deck plane, relative to focus.
		var top_hits: float = cz - h / slope_top
		print("  top of frame crosses the deck at focus%+.0f" % top_hits)
		print("  VERTICAL BUDGET — how tall a thing at depth d astern of the")
		print("  frame's top edge can be before its head leaves the frame:")
		for dz in [0.0, -200.0, -400.0, -600.0, -800.0, -1000.0, -1160.0]:
			var d: float = cz - dz              ## horizontal distance from camera
			var cap: float = h - d * slope_top
			var flag := "   " if cap > 0.0 else "  CUT"
			print("    z = focus%+6.0f   d = %6.0f   max height %7.1f%s" % [dz, d, cap, flag])
		print("  LATERAL BUDGET — half the frame width, in ground units, at deck depth:")
		for dz in [0.0, -400.0, -800.0, -1160.0]:
			## Depth along the camera's own forward axis to that ground point.
			var rel := Vector3(0.0, -h, dz - cz)
			var fwd := Vector3(0.0, -sin(PITCH), -cos(PITCH))
			var along: float = rel.dot(fwd)
			var half_w: float = along * tan_h
			var edge := "deck edge OFF SCREEN" if half_w < 840.0 else "deck edge in frame"
			print("    z = focus%+6.0f   half-width %6.0f   (%s)" % [dz, half_w, edge])
		print("")

	## How much of the frame is deck, and how much is anything else. Pure
	## geometry: the fraction of the vertical frame above the deck's bow edge.
	print("HOW MUCH OF THE FRAME IS PLANKING (captain amidships)")
	for zoom in [1.0, 1.55]:
		var h: float = CAM_H * zoom
		var cz: float = CAM_NEAR * zoom
		## The bow edge of the deck is at z = -1160 world; focus is at z = 0.
		var rel := Vector3(0.0, -h, -1160.0 - cz)
		var fwd := Vector3(0.0, -sin(PITCH), -cos(PITCH))
		var upv := Vector3(0.0, cos(PITCH), -sin(PITCH))
		var along: float = rel.dot(fwd)
		var up: float = rel.dot(upv)
		var ndc: float = (up / along) / tan_v      ## -1 bottom, +1 top
		var frac: float = clampf((ndc + 1.0) * 0.5, 0.0, 1.0)
		print("  zoom %.2f: the bow edge sits at %.0f%% of frame height."
			% [zoom, frac * 100.0])
		print("            %.0f%% of the frame is deck; %.0f%% is everything else."
			% [frac * 100.0, (1.0 - frac) * 100.0])


## --- variant: a ruler, to check the budget against a picture -----------------
func _build_headroom() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.15, 0.65)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var alt := StandardMaterial3D.new()
	alt.albedo_color = Color(0.2, 1.0, 0.4)
	alt.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	## A pole every 200 units down the centreline and at both quarters, banded
	## every 100 ground units, so the shot reads off directly as "at this depth,
	## this is the height the frame stops".
	for x in [-620.0, 0.0, 620.0]:
		for z in range(-1100, 900, 200):
			for band in range(0, 12):
				var seg := MeshInstance3D.new()
				var bm := BoxMesh.new()
				bm.size = Vector3(16.0, 96.0, 16.0) * W
				seg.mesh = bm
				seg.material_override = mat if band % 2 == 0 else alt
				seg.position = Vector3(x * W, (band * 100.0 + 50.0) * W, float(z) * W)
				seg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				view.add_child(seg)


## --- variant: a rail you can see the sky through -----------------------------
##
## PROPOSAL R. The shipped gunwale is a 40x14 bar with no gaps in it, which at
## this camera is a painted gold stripe on the edge of a plank. A rail reads as a
## rail because you see PAST it: stanchions with air between them, and the deck
## edge visible under the bottom rail.
func _build_rail() -> void:
	var brass := StandardMaterial3D.new()
	brass.albedo_color = Color("#c08f45")
	brass.metallic = 0.65
	brass.roughness = 0.42
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color("#3a3038")
	iron.metallic = 0.5
	iron.roughness = 0.6
	for side in [-1.0, 1.0]:
		var x: float = DECK.position.x + (0.0 if side < 0.0 else DECK.size.x)
		## Stanchions every 145 units, 120 tall. Three times the shipped rail's
		## height and about a third of the captain's, so it never hides a boarder
		## and always cuts the sky.
		var z := DECK.position.y + 60.0
		while z < DECK.end.y - 60.0:
			var post := MeshInstance3D.new()
			var pm := BoxMesh.new()
			pm.size = Vector3(15.0, 120.0, 15.0) * W
			post.mesh = pm
			post.material_override = iron
			post.position = Vector3(x * W, 60.0 * W, z * W)
			view.add_child(post)
			z += 145.0
		## Two horizontal rails, top and middle, with the gap between them open.
		for hy in [118.0, 66.0]:
			var bar := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(13.0, 11.0, DECK.size.y) * W
			bar.mesh = bm
			bar.material_override = brass
			bar.position = Vector3(x * W, hy * W,
				(DECK.position.y + DECK.size.y * 0.5) * W)
			view.add_child(bar)


## --- variant: a hull you can actually see ------------------------------------
##
## PROPOSAL H. The shipped hull is a box 3% narrower than the deck sitting under
## it, which from inboard is occluded by the deck's own edge at every camera
## position — so the ship has no underside in any frame. Flaring it OUTBOARD puts
## it back in shot, and the flare is what a hull does anyway.
func _build_hull() -> void:
	var timber := StandardMaterial3D.new()
	timber.albedo_color = Color("#2b2028")
	timber.roughness = 0.9
	var trim := StandardMaterial3D.new()
	trim.albedo_color = Color("#7a5a2c")
	trim.metallic = 0.4
	trim.roughness = 0.6
	## Three courses, each wider than the deck and each stepping back in, so the
	## side reads as tumblehome rather than as a slab: a wale you can see from
	## inboard, then the hull falling away out of sight.
	var courses := [
		{"out": 46.0, "top": -6.0, "h": 34.0, "mat": trim, "narrow": 0.0},
		{"out": 30.0, "top": -40.0, "h": 90.0, "mat": timber, "narrow": 0.0},
		{"out": -40.0, "top": -130.0, "h": 260.0, "mat": timber, "narrow": 0.0},
	]
	for c in courses:
		var box := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(DECK.size.x + float(c.out) * 2.0, float(c.h),
			DECK.size.y + float(c.out) * 1.2) * W
		box.mesh = bm
		box.material_override = c.mat
		box.position = Vector3(
			(DECK.position.x + DECK.size.x * 0.5) * W,
			(float(c.top) - float(c.h) * 0.5) * W,
			(DECK.position.y + DECK.size.y * 0.5) * W)
		view.add_child(box)
	## Ribs, standing proud of the top wale — the thing that makes a side read as
	## built rather than extruded, and the only part of a hull this camera can see.
	var z := DECK.position.y + 90.0
	while z < DECK.end.y - 90.0:
		for side in [-1.0, 1.0]:
			var rib := MeshInstance3D.new()
			var rm := BoxMesh.new()
			rm.size = Vector3(22.0, 40.0, 34.0) * W
			rib.mesh = rm
			rib.material_override = trim
			rib.position = Vector3(
				(DECK.position.x + (0.0 if side < 0.0 else DECK.size.x) + side * 44.0) * W,
				-18.0 * W, z * W)
			view.add_child(rib)
		z += 230.0


## --- variant: rigging, and its shadow ----------------------------------------
##
## PROPOSAL G, and the one this whole document turns on. The near two thirds of
## the frame is bare planking at every camera position, so nothing added at the
## EDGES can reach it. A shadow can. Masts and shrouds live above the top of the
## frame where they cost no occlusion at all, and the moon prints them across the
## floor the player is actually looking at.
func _build_rig() -> void:
	var timber := StandardMaterial3D.new()
	timber.albedo_color = Color("#4a3520")
	timber.roughness = 0.85
	var rope := StandardMaterial3D.new()
	rope.albedo_color = Color("#6a5738")
	rope.roughness = 0.95
	## Two masts, on the lane dividers rather than in a lane, so neither of them
	## can ever stand between the player and a boarder in the lane they are
	## fighting. 1400 units: far above the top of the frame at every position.
	for mx in [-280.0, 280.0]:
		for mz in [-620.0, 500.0]:
			var mast := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 12.0 * W
			cm.bottom_radius = 22.0 * W
			cm.height = 1400.0 * W
			cm.radial_segments = 8
			mast.mesh = cm
			mast.material_override = timber
			mast.position = Vector3(mx * W, 700.0 * W, mz * W)
			view.add_child(mast)
			## Shrouds: four lines from the masthead down to the rail, and a yard
			## across. These are what actually print on the deck.
			for dx in [-1.0, 1.0]:
				for dz in [-1.0, 1.0]:
					var foot := Vector3((mx + dx * 520.0) * W, 60.0 * W,
						(mz + dz * 300.0) * W)
					var head := Vector3(mx * W, 1250.0 * W, mz * W)
					var line := MeshInstance3D.new()
					var lm := CylinderMesh.new()
					lm.top_radius = 5.0 * W
					lm.bottom_radius = 5.0 * W
					lm.height = foot.distance_to(head)
					lm.radial_segments = 5
					line.mesh = lm
					line.material_override = rope
					line.position = (foot + head) * 0.5
					line.look_at_from_position((foot + head) * 0.5, head, Vector3.RIGHT)
					line.rotate_object_local(Vector3.RIGHT, PI * 0.5)
					view.add_child(line)
			var yard := MeshInstance3D.new()
			var ym := CylinderMesh.new()
			ym.top_radius = 9.0 * W
			ym.bottom_radius = 9.0 * W
			ym.height = 900.0 * W
			ym.radial_segments = 6
			yard.mesh = ym
			yard.material_override = timber
			yard.rotation_degrees = Vector3(0.0, 0.0, 90.0)
			yard.position = Vector3(mx * W, 1080.0 * W, mz * W)
			view.add_child(yard)


## --- variant: a deck that is not a rectangle ---------------------------------
##
## PROPOSAL S. DECK_RECT is gameplay and must not move, so this adds geometry
## OUTSIDE it: a fore-and-aft sheer strip that rises toward the bow and the
## stern, and a bow that narrows. The walkable rectangle is untouched — what
## changes is the silhouette against the sky.
func _build_sheer() -> void:
	var timber := StandardMaterial3D.new()
	timber.albedo_color = Color("#3a2b22")
	timber.roughness = 0.88
	## The sheer strake: a strip outboard of DECK_RECT whose top edge lifts at
	## both ends. Twenty segments a side, cosine profile, peak 150 at the bow and
	## 90 at the stern. Purely outboard, so nothing walkable changes.
	var segs := 20
	for side in [-1.0, 1.0]:
		for i in segs:
			var t0: float = float(i) / float(segs)
			var t1: float = float(i + 1) / float(segs)
			var tm: float = (t0 + t1) * 0.5
			## 0 at midships, rising to both ends; steeper forward.
			var lift: float = 150.0 * pow(1.0 - tm, 2.2) + 90.0 * pow(tm, 2.6)
			var z0: float = DECK.position.y + DECK.size.y * t0
			var z1: float = DECK.position.y + DECK.size.y * t1
			var strip := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(58.0, 30.0 + lift, z1 - z0) * W
			strip.mesh = bm
			strip.material_override = timber
			strip.position = Vector3(
				(DECK.position.x + (0.0 if side < 0.0 else DECK.size.x) + side * 29.0) * W,
				(-8.0 + (30.0 + lift) * 0.5 - 30.0) * W,
				(z0 + z1) * 0.5 * W)
			view.add_child(strip)
	## And a bow that comes to a point, ahead of the play rectangle.
	var stem := MeshInstance3D.new()
	var pm := PrismMesh.new()
	pm.size = Vector3(DECK.size.x * 0.72, 210.0, 620.0) * W
	stem.mesh = pm
	stem.material_override = timber
	stem.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	stem.position = Vector3(0.0, -30.0 * W, (DECK.position.y - 300.0) * W)
	view.add_child(stem)


## --- variant: rigging that cannot occlude ------------------------------------
##
## PROPOSAL G, second attempt. The first (`_build_rig`) put masts and shrouds
## where a ship has them and they crossed the whole frame as 30-pixel bars — see
## `.shots/deck/rig-mid-z1.00.png`. The lesson is the lateral measurement: at the
## captain's own depth the frame is only 490 ground units wide, so a 10 cm rope
## four metres from the lens is a girder.
##
## `shadows_only` is the version that costs nothing: the geometry is in the
## shadow atlas and in no other pass, so the deck gets rigging printed across it
## and the player's view of the lane is untouched. Godot renders this for free —
## it is one enum on the MeshInstance3D.
func _build_rig2(shadows_only: bool) -> void:
	var timber := StandardMaterial3D.new()
	timber.albedo_color = Color("#41301d")
	timber.roughness = 0.86
	var rope := StandardMaterial3D.new()
	rope.albedo_color = Color("#6a5738")
	rope.roughness = 0.95
	var mode := (GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		if shadows_only else GeometryInstance3D.SHADOW_CASTING_SETTING_ON)

	## The moon is at rotation (-52, 34, 0), so its direction is
	## (-0.344, -0.788, -0.510): every shadow lands 0.44 of its height to PORT and
	## 0.65 of its height toward the BOW. A mast on the starboard divider prints
	## across the centre lane; one 1400 tall at z = +900 prints from there to
	## z = -6, which is the middle of the deck from a mast nobody can see.
	var masts := [
		{"x": 280.0, "z": 900.0, "h": 1500.0},
		{"x": -280.0, "z": 260.0, "h": 1500.0},
		{"x": 280.0, "z": -560.0, "h": 1500.0},
	]
	for m in masts:
		var mast := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 13.0 * W
		cm.bottom_radius = 26.0 * W
		cm.height = float(m.h) * W
		cm.radial_segments = 8
		mast.mesh = cm
		mast.material_override = timber
		mast.cast_shadow = mode
		mast.position = Vector3(float(m.x) * W, float(m.h) * 0.5 * W, float(m.z) * W)
		view.add_child(mast)
		## A yard across, and the shrouds. Thin: these are read as SHADOWS, and a
		## shadow keeps its width where the geometry has long since gone to a
		## hairline.
		var yard := MeshInstance3D.new()
		var ym := CylinderMesh.new()
		ym.top_radius = 10.0 * W
		ym.bottom_radius = 10.0 * W
		ym.height = 1150.0 * W
		ym.radial_segments = 6
		yard.mesh = ym
		yard.material_override = timber
		yard.rotation_degrees = Vector3(0.0, 0.0, 90.0)
		yard.cast_shadow = mode
		yard.position = Vector3(float(m.x) * W, float(m.h) * 0.74 * W, float(m.z) * W)
		view.add_child(yard)
		for dx in [-1.0, 1.0]:
			for i in 3:
				var spread: float = 300.0 + float(i) * 190.0
				var foot := Vector3((float(m.x) + dx * spread) * W, 40.0 * W,
					(float(m.z) + (float(i) - 1.0) * 150.0) * W)
				var head := Vector3(float(m.x) * W, float(m.h) * 0.82 * W, float(m.z) * W)
				var line := MeshInstance3D.new()
				var lm := CylinderMesh.new()
				lm.top_radius = 4.0 * W
				lm.bottom_radius = 4.0 * W
				lm.height = foot.distance_to(head)
				lm.radial_segments = 4
				line.mesh = lm
				line.material_override = rope
				line.cast_shadow = mode
				var mid := (foot + head) * 0.5
				line.position = mid
				line.look_at_from_position(mid, head, Vector3.RIGHT)
				line.rotate_object_local(Vector3.RIGHT, PI * 0.5)
				view.add_child(line)


## --- variant: a level change that costs no play area -------------------------
##
## PROPOSAL V. Verticality inside the three lanes is a readability regression by
## construction — anything tall enough to see is tall enough to hide a boarder.
## Outboard of the rail it is free: DECK_RECT is untouched, nothing walkable
## changes, and the deck stops being one plane from edge to edge.
func _build_catwalk() -> void:
	var plank := StandardMaterial3D.new()
	plank.albedo_color = Color("#4a3527")
	plank.roughness = 0.9
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color("#33292f")
	iron.metallic = 0.5
	iron.roughness = 0.6
	for side in [-1.0, 1.0]:
		var edge: float = DECK.position.x + (0.0 if side < 0.0 else DECK.size.x)
		## The walkway itself, 150 wide, dropped 70 below the deck so it reads as a
		## step DOWN to a lower gallery rather than as a wall beside the lane.
		var walk := MeshInstance3D.new()
		var wm := BoxMesh.new()
		wm.size = Vector3(150.0, 26.0, DECK.size.y * 0.62) * W
		walk.mesh = wm
		walk.material_override = plank
		walk.position = Vector3((edge + side * 100.0) * W, -70.0 * W,
			(DECK.position.y + DECK.size.y * 0.52) * W)
		view.add_child(walk)
		## Brackets under it, which is the whole reason a gallery reads as hung off
		## a hull rather than as a second floor.
		var z := DECK.position.y + DECK.size.y * 0.24
		while z < DECK.position.y + DECK.size.y * 0.80:
			var brace := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(170.0, 14.0, 20.0) * W
			brace.mesh = bm
			brace.material_override = iron
			brace.rotation_degrees = Vector3(0.0, 0.0, side * 24.0)
			brace.position = Vector3((edge + side * 95.0) * W, -120.0 * W, z * W)
			view.add_child(brace)
			z += 190.0
		## And a rail on the OUTER edge of the gallery, so the eye reads
		## deck / step down / gallery / rail / sky — four bands instead of one line.
		for hy in [96.0, 46.0]:
			var bar := MeshInstance3D.new()
			var bm2 := BoxMesh.new()
			bm2.size = Vector3(12.0, 10.0, DECK.size.y * 0.62) * W
			bar.mesh = bm2
			bar.material_override = iron
			bar.position = Vector3((edge + side * 172.0) * W, (hy - 57.0) * W,
				(DECK.position.y + DECK.size.y * 0.52) * W)
			view.add_child(bar)
