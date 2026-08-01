extends SceneTree
## SG-27 — measure the Boiler. How tall/wide/deep does the shipped mesh actually
## render, in ground units, and how many screen pixels does it occupy at the
## parity framing — against the browser's `boilerH`-derived flat block.
##
##   godot --path . --headless --resolution 1600x900 --script tools/boiler_measure.gd
##
## The Godot side is ground truth: the REAL boiler subtree in `main3d.tscn`,
## posed like `tools/parity_shot.gd`'s deck scene, measured as a world AABB and
## unprojected through the actual camera. The browser side is its own
## `CAM.project()` math (verbatim from cam_measure.gd / _render_head.js) at the
## same pose — SG-2 proved the two projections agree to the pixel, so the boiler
## at the same ground point differs only by its rendered height and footprint.
##
## Writes nothing; prints the table.

const WORLD_SCALE := 0.01
var OUT_W := 1600.0
var OUT_H := 900.0

# Browser CAM constants, verbatim from reference/web-source/_render_head.js
const B_H := 760.0
const B_NEAR := 460.0
const B_F := 1320.0
const B_PITCH := 0.72

# Browser tuned values (reference/web-source/, LIVE build storm-dusk-v11).
const BROWSER_BOILER_H := 150.0   # PRESET.boilerH, v11 "a flat engine block"
const BROWSER_HERO_H := 128.0     # BILLBOARD_H.hero, the captain's crown
const FIG := 0.86                 # fraction of sprite height the figure occupies


func _initialize() -> void: call_deferred("_run")


func browser_project(x: float, y: float, focusX: float, focusY: float) -> Vector2:
	var unit := clampf(minf(OUT_W / 1400.0, OUT_H / 860.0), 0.55, 1.6)
	var _f := B_F * unit
	var cx := OUT_W * 0.5
	var cy := OUT_H * 0.5
	var s := sin(B_PITCH)
	var c := cos(B_PITCH)
	var dy := 0.0 - B_H
	var dz := B_NEAR + (focusY - y)
	var Yc := dy * c + dz * s
	var Zc := -dy * s + dz * c
	var z := Zc if Zc > 1.0 else 1.0
	var k := _f / z
	return Vector2(cx + (x - focusX) * k, cy - Yc * k)


# The browser draws the boiler as a billboard of worldH = boilerH, so its top
# projects at height boilerH over its ground point. Screen height in px = base
# pixel y minus top pixel y, at the boiler's ground position.
func browser_billboard_screen_h(gx: float, gy: float, world_h: float,
		focusX: float, focusY: float) -> float:
	# CAM.project(x, y, hgt): height raises the point by hgt in world Y.
	var base := browser_project_h(gx, gy, 0.0, focusX, focusY)
	var top := browser_project_h(gx, gy, world_h, focusX, focusY)
	return absf(base.y - top.y)


func browser_project_h(x: float, y: float, hgt: float, focusX: float, focusY: float) -> Vector2:
	var unit := clampf(minf(OUT_W / 1400.0, OUT_H / 860.0), 0.55, 1.6)
	var _f := B_F * unit
	var cx := OUT_W * 0.5
	var cy := OUT_H * 0.5
	var s := sin(B_PITCH)
	var c := cos(B_PITCH)
	var dy := hgt - B_H
	var dz := B_NEAR + (focusY - y)
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
	for _i in 40:
		game._process(1.0 / 60.0)
		await process_frame

	var cam: Camera3D = view.camera
	var focus: Vector2 = view._focus
	var vp := cam.get_viewport().get_visible_rect().size
	OUT_W = vp.x
	OUT_H = vp.y

	# --- find the real boiler subtree: view3d child at BOILER_POSITION * WS ----
	var want := Vector3(SkyGearGame.BOILER_POSITION.x * WORLD_SCALE, 0.0,
		SkyGearGame.BOILER_POSITION.y * WORLD_SCALE)
	var boiler_node: Node3D = null
	for child in view.get_children():
		if child is Node3D and (child as Node3D).position.distance_to(want) < 0.001:
			boiler_node = child
			break
	if boiler_node == null:
		print("could not find the boiler node")
		quit(1)
		return

	# world AABB of every MeshInstance3D under the boiler
	var box := AABB()
	var first := true
	for mi_any in boiler_node.find_children("*", "MeshInstance3D", true, false):
		var mi := mi_any as MeshInstance3D
		if mi.mesh == null:
			continue
		var here := mi.global_transform * mi.get_aabb()
		box = here if first else box.merge(here)
		first = false
	if first:
		print("boiler has no meshes")
		quit(1)
		return

	var is_mesh := ResourceLoader.exists("res://assets/models/boiler/boiler.tscn")
	var h_gu := box.size.y / WORLD_SCALE
	var w_gu := box.size.x / WORLD_SCALE
	var d_gu := box.size.z / WORLD_SCALE
	var bpos: Vector2 = SkyGearGame.BOILER_POSITION

	print("=== SG-27 BOILER MEASUREMENT ===")
	print("output resolution   %d x %d" % [int(vp.x), int(vp.y)])
	print("boiler path         %s" % ("generated MESH (boiler.tscn)" if is_mesh else "primitive FLAT block (_build_boiler)"))
	print("boiler ground pos   (%.0f, %.0f)" % [bpos.x, bpos.y])
	print("")
	print("RENDERED BOUNDS (ground units)")
	print("  height   %7.1f   (browser boilerH %.0f, captain crown %.0f)" % [h_gu, BROWSER_BOILER_H, BROWSER_HERO_H])
	print("  width    %7.1f" % w_gu)
	print("  depth    %7.1f   <- a flat billboard has ~0 here" % d_gu)
	print("  top world-Y %.1f gu above deck" % (box.position.y / WORLD_SCALE + h_gu))
	print("")

	# Screen height/width in px, from the real camera, at 1600x900 and 1920x1080.
	var gpx := func(wx: float, wy: float, wz: float) -> Vector2:
		return cam.unproject_position(Vector3(wx, wy, wz))
	var cx := box.position.x + box.size.x * 0.5
	var cz := box.position.z + box.size.z * 0.5
	var base_px: Vector2 = gpx.call(cx, 0.0, cz)
	var top_px: Vector2 = gpx.call(cx, box.position.y + box.size.y, cz)
	var left_px: Vector2 = gpx.call(box.position.x, box.position.y, cz)
	var right_px: Vector2 = gpx.call(box.position.x + box.size.x, box.position.y, cz)
	var g_screen_h := absf(base_px.y - top_px.y)
	var g_screen_w := absf(right_px.x - left_px.x)

	# The browser flat block at the same ground point (SG-2: same projection).
	var b_screen_h := browser_billboard_screen_h(bpos.x, bpos.y, BROWSER_BOILER_H, focus.x, focus.y)

	print("SCREEN FOOTPRINT at parity framing (px @ %dx%d)" % [int(OUT_W), int(OUT_H)])
	print("%-28s %10s %10s %8s" % ["", "browser", "godot", "ratio"])
	print("%-28s %10.1f %10.1f %8.3f" % ["boiler screen HEIGHT", b_screen_h, g_screen_h, g_screen_h / b_screen_h])
	print("  godot screen WIDTH        %10.1f px" % g_screen_w)
	var scale_1080 := 1080.0 / OUT_H
	print("")
	print("Scaled to 1920x1080 (x%.3f):" % scale_1080)
	print("  browser boiler height  %7.1f px" % (b_screen_h * scale_1080))
	print("  godot   boiler height  %7.1f px   (%.0f%% of the browser's)" % [
		g_screen_h * scale_1080, 100.0 * g_screen_h / b_screen_h])
	print("  frame lower third is    360.0 px")
	quit(0)
