extends SceneTree
## SG-2 — measure the framing gap. Put a known ground length on screen in BOTH
## builds at the same output resolution and compare pixels.
##
## The Godot side is ground truth: `Camera3D.unproject_position` on known deck
## points, in the real `main3d.tscn`, posed exactly like `tools/parity_shot.gd`.
## The browser side is its own `CAM.project()` math (reference/web-source/
## _render_head.js), computed analytically at the SAME pose and resolution — no
## browser needed. Same focus point fed to both, so this compares the two
## projections and nothing else.
##
##   godot --path . --headless --resolution 1600x900 --script tools/cam_measure.gd
##
## Writes nothing; prints the table.

const WORLD_SCALE := 0.01
# Filled from the ACTUAL rendered viewport, so the browser math and the Godot
# camera are compared at one and the same output resolution.
var OUT_W := 1600.0
var OUT_H := 900.0

# Browser CAM constants, verbatim from reference/web-source/_render_head.js
const B_H := 760.0
const B_NEAR := 460.0
const B_F := 1320.0
const B_PITCH := 0.72


func _initialize() -> void: call_deferred("_run")


# Browser CAM.project(x, y, hgt=0) -> screen pixel, at the given focus + resolution.
func browser_project(x: float, y: float, focusX: float, focusY: float) -> Vector2:
	# View.unit = clamp(min(w/1400, h/860), 0.55, 1.6);  _f = f * unit
	var unit := clampf(minf(OUT_W / 1400.0, OUT_H / 860.0), 0.55, 1.6)
	var _f := B_F * unit
	var cx := OUT_W * 0.5
	var cy := OUT_H * 0.5            # follow: cy = View.h * 0.50
	var s := sin(B_PITCH)
	var c := cos(B_PITCH)
	var dy := 0.0 - B_H
	var dz := B_NEAR + (focusY - y)  # CAM.depth(y)
	var Yc := dy * c + dz * s
	var Zc := -dy * s + dz * c
	var z := Zc if Zc > 1.0 else 1.0
	var k := _f / z
	return Vector2(cx + (x - focusX) * k, cy - Yc * k)


func _run() -> void:
	DisplayServer.window_set_size(Vector2i(int(OUT_W), int(OUT_H)))
	root.size = Vector2i(int(OUT_W), int(OUT_H))
	await process_frame

	var world = load("res://scenes/main3d.tscn").instantiate()
	root.add_child(world)
	await process_frame
	var view = world
	var game: SkyGearGame = world.get_node("SkyGear")
	game.set_process(false)
	game.workshop = SkyGearWorkshop.fresh(true)
	game.heat = 0
	game.set_class("captain")
	game.set_seed_text("PARITY")
	game.begin_run()
	game.choose_draft(0)
	game.spawn_queue.clear()
	view.sway = false
	view._zoom = 1.0
	view._zoom_target = 1.0
	for _i in 30:
		game._process(1.0 / 60.0)
		await process_frame

	var cam: Camera3D = view.camera
	var focus: Vector2 = view._focus
	var vp := cam.get_viewport().get_visible_rect().size
	OUT_W = vp.x
	OUT_H = vp.y

	print("=== SG-2 FRAMING MEASUREMENT ===")
	print("output resolution   %d x %d  (aspect %.4f)" % [int(vp.x), int(vp.y), vp.x / vp.y])
	print("keep_aspect         %s   (0=KEEP_WIDTH, 1=KEEP_HEIGHT)" % str(cam.keep_aspect))
	print("camera.fov          %.3f deg" % cam.fov)
	print("focus (deck units)  (%.1f, %.1f)" % [focus.x, focus.y])
	print("captain pos         (%.1f, %.1f)" % [game.player.global_position.x, game.player.global_position.y])
	print("browser View.unit   %.4f   -> _f = %.1f px" % [
		clampf(minf(OUT_W / 1400.0, OUT_H / 860.0), 0.55, 1.6),
		B_F * clampf(minf(OUT_W / 1400.0, OUT_H / 860.0), 0.55, 1.6)])
	print("")

	# Godot: unproject a ground point (deck coords -> world -> screen px).
	# Ground (x, y) maps to world (x*WS, 0, y*WS) — see view3d entity placement.
	var godot_px := func(gx: float, gy: float) -> Vector2:
		return cam.unproject_position(Vector3(gx * WORLD_SCALE, 0.0, gy * WORLD_SCALE))

	print("KNOWN LENGTHS — pixel span at the SAME pose (browser math vs Godot camera)")
	print("%-42s %10s %10s %8s" % ["length", "browser", "godot", "ratio"])

	var cases := [
		["deck full width 1680 @ focus depth", -840.0, focus.y, 840.0, focus.y],
		["deck full width 1680 @ bow (y=-1160)", -840.0, -1160.0, 840.0, -1160.0],
		["deck full width 1680 @ stern (y=+1160)", -840.0, 1160.0, 840.0, 1160.0],
		["one lane width 560 @ focus depth", -280.0, focus.y, 280.0, focus.y],
		["one lane width 560 @ bow", -280.0, -1160.0, 280.0, -1160.0],
	]
	for cse in cases:
		var name: String = cse[0]
		var b0 := browser_project(cse[1], cse[2], focus.x, focus.y)
		var b1 := browser_project(cse[3], cse[4], focus.x, focus.y)
		var g0: Vector2 = godot_px.call(cse[1], cse[2])
		var g1: Vector2 = godot_px.call(cse[3], cse[4])
		var b_span := absf(b1.x - b0.x)
		var g_span := absf(g1.x - g0.x)
		print("%-42s %10.1f %10.1f %8.3f" % [name, b_span, g_span, g_span / b_span])

	print("")
	print("VERTICAL — deck depth span in pixels (keel x=0)")
	print("%-42s %10s %10s %8s" % ["length", "browser", "godot", "ratio"])
	var vcases := [
		["bow->stern (y -1160..+1160) @ keel", 0.0, -1160.0, 0.0, 1160.0],
		["focus->bow (y focus..-1160) @ keel", 0.0, focus.y, 0.0, -1160.0],
	]
	for cse in vcases:
		var b0 := browser_project(cse[1], cse[2], focus.x, focus.y)
		var b1 := browser_project(cse[3], cse[4], focus.x, focus.y)
		var g0: Vector2 = godot_px.call(cse[1], cse[2])
		var g1: Vector2 = godot_px.call(cse[3], cse[4])
		var b_span := absf(b1.y - b0.y)
		var g_span := absf(g1.y - g0.y)
		print("%-42s %10.1f %10.1f %8.3f" % [cse[0], b_span, g_span, g_span / b_span])

	print("")
	print("SINGLE POINT CHECK — captain's own ground point on screen")
	var cp: Vector2 = game.player.global_position
	var bcp := browser_project(cp.x, cp.y, focus.x, focus.y)
	var gcp: Vector2 = godot_px.call(cp.x, cp.y)
	print("  browser  (%.1f, %.1f)   frac-height %.4f" % [bcp.x, bcp.y, bcp.y / OUT_H])
	print("  godot    (%.1f, %.1f)   frac-height %.4f" % [gcp.x, gcp.y, gcp.y / OUT_H])
	quit(0)
