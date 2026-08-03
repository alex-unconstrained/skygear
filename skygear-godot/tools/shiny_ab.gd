extends SceneTree
## THE METALLIC CEILING, AS A PICTURE. `tools/lamplit.py` measures it and refuses
## to rewrite anything; this stands the model on the real deck under the real
## lamps and photographs it BOTH WAYS in one frozen scene.
##
##   godot --path . --resolution 1600x900 --script tools/shiny_ab.gd -- \
##       '{"models": {"lantern_post": 0.372, ...}, "out": "res://.shots/..."}'
##
## Normally driven by `tools/shiny_ab.py`, which computes the clamped factors
## from the .glb itself so this tool and `lamplit.clamp_glb` cannot disagree
## about the arithmetic — the factor per model is `0.34 / peak texel of the
## metallic map`, which is `clamp_metallic`'s own guarantee: no texel on this
## surface exceeds the ceiling.
##
## WHY THE CLAMP IS APPLIED IN MEMORY AND NOTHING ON DISK IS TOUCHED. The
## question in front of the owner is whether fourteen-odd models SHOULD be
## clamped. Rewriting the .glbs to photograph them would answer it by doing it.
## Godot's glTF importer already reproduces the trap faithfully — an absent
## `metallicFactor` imports as `metallic = 1.0` — so plate A is the shipped
## material untouched and plate B is the same material with one float moved.
##
## AND THE PLATES SHARE A SCENE. Both are taken inside one `SkyGearStill.freeze`
## with only that float changed between them, because two runs of a shot tool
## never land the brazier flicker, the particle clock and the cloud drift in the
## same place twice (SG-108). The tool prints its own noise floor first.
##
## ONE SIDE EFFECT, ON PURPOSE: a mesh surface's material is a SHARED resource,
## so clamping `lantern_post` also clamps the lantern posts the renderer already
## has standing on this deck. That is not a leak, it is the honest picture — the
## deck's own furniture is made of these same materials. Every original value is
## recorded and restored before the next model, so pairs cannot contaminate each
## other.
##
## NOT `--headless` (SG-29).

const W := 0.01

## Where the specimen stands and where the captain stands to light the frame,
## in ground units. She is IN the picture on purpose: she is the one figure on
## this deck whose material was authored by hand rather than imported at 1.0,
## so she is the control — if the specimen reads as a hole and she does not,
## the hole is the material and not the lamps.
const SPECIMEN_AT := Vector2(90.0, 140.0)
const CAPTAIN_AT := Vector2(-190.0, 140.0)
## Ground units. Every specimen is stood at one height so the pairs are
## comparable with each other; this is a display convention, not the size the
## thing is in play.
const DISPLAY_HEIGHT := 265.0

var view
var game
var out_dir := "res://.shots/owner-review/_raw-shiny"
var manifest: Array = []


func _initialize() -> void: call_deferred("_run")


func _run() -> void:
	if not SkyGearRendererCheck.can_capture():
		print(SkyGearRendererCheck.capture_refusal())
		quit(2)
		return
	var argv := OS.get_cmdline_user_args()
	var spec = JSON.parse_string(str(argv[0])) if argv.size() > 0 else null
	if spec is not Dictionary:
		print("shiny_ab: expects one JSON argument — see tools/shiny_ab.py")
		quit(1)
		return
	var models: Dictionary = spec.get("models", {})
	out_dir = str(spec.get("out", out_dir))

	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1600, 900))
	root.size = Vector2i(1600, 900)
	await process_frame
	await _boot()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))

	await _pose(float(spec.get("zoom", 1.3)))
	for key in models.keys():
		await _pair(str(key), float(models[key]), str(spec.get("note_%s" % key, "")))

	var f := FileAccess.open("%s/manifest.json" % out_dir, FileAccess.WRITE)
	f.store_string(JSON.stringify(manifest, "  "))
	f.close()
	print("manifest: %s/manifest.json  (%d pairs)" % [out_dir, manifest.size()])
	quit(0)


func _pair(key: String, clamped: float, note: String) -> void:
	var node := _stand(key)
	if node == null:
		print("  %-18s NO SCENE — skipped" % key)
		return
	await _flush()
	await SkyGearStill.freeze(self, view, game)

	if manifest.is_empty():
		var floor_pct: float = await SkyGearStill.floor_pct(self,
			Rect2i(200, 150, 1200, 600), func(): view._process(0.0))
		print("NOISE FLOOR (nothing changed between two plates): %.2f%%  "
			% floor_pct + "(0.00 is the pass condition)")

	var crop := _crop_over(node)
	var a_path := "%s/%s-A.png" % [out_dir, key]
	var b_path := "%s/%s-B.png" % [out_dir, key]
	await _grab(a_path)
	var was := _set_metallic(_materials_of(node), clamped)
	await _flush()
	await _grab(b_path)
	_restore(was)
	await _flush()
	await SkyGearStill.thaw(self, view, game)
	_unstand(node)
	await _flush()

	print("  %-18s metallic %.3f -> %.4f   (%d materials)"
		% [key, was.values()[0] if not was.is_empty() else -1.0, clamped, was.size()])
	manifest.append({"tag": key, "title": key.to_upper().replace("_", " "),
		"note": note, "spot": "beside the captain, mid deck",
		"zoom": view._zoom, "crop": crop,
		"a": a_path.replace("res://", ""), "b": b_path.replace("res://", ""),
		"label_a": "AS IT SHIPS: metallic 1.0 (glTF default, unset)",
		"label_b": "CLAMPED: metallic %.3f (lamplit ceiling 0.34)" % clamped,
		"short_a": "shipped-fully-metallic", "short_b": "clamped-to-0.34"})


## --- the specimen ---------------------------------------------------------------

func _stand(key: String) -> Node3D:
	## The `.tscn` wrapper where `tools/static_model.gd` made one, the raw `.glb`
	## where it did not — the WEAPONS are the second case, and they are the half
	## of this question most likely to want to stay shiny, so silently skipping
	## them would have quietly dropped the interesting side of the argument.
	var path := SkyGearView3D.model_path(key)
	if not ResourceLoader.exists(path):
		path = "res://assets/models/%s/%s.glb" % [key.to_lower(), key.to_lower()]
	if not ResourceLoader.exists(path):
		return null
	var packed := load(path) as PackedScene
	if packed == null:
		return null
	var node: Node3D = packed.instantiate() as Node3D
	view.add_child(node)
	## Height from the scene's own `model_height` where `tools/static_model.gd`
	## wrote one, MEASURED off the meshes where it did not (the rigged figures).
	## Never guessed: a specimen at the wrong size is a specimen photographed at
	## a distance the lamps do not reach the same way.
	var h := float(node.get_meta("model_height", 0.0))
	if h <= 0.0:
		h = SkyGearView3D.measure_span(node).y
	var s: float = (DISPLAY_HEIGHT * W) / maxf(0.0001, h)
	node.transform = Transform3D(Basis().scaled(Vector3(s, s, s)),
		Vector3(SPECIMEN_AT.x, 0.0, SPECIMEN_AT.y) * W)
	for child in node.find_children("*", "MeshInstance3D", true, false):
		(child as MeshInstance3D).layers = SkyGearView3D.LAYER_FIGURES
	## Its own row in `assets/models/lights.json`, if it has one — a brazier or a
	## lantern judged without the light it carries in play is judged in a scene
	## that does not exist.
	view._model_light_statics.append({"key": key, "node": node})
	return node


## THE CROP THE SHEET IS CUT TO: the specimen AND the captain beside it, padded.
##
## Measured through `unproject_position`, never eyeballed — and converted out of
## the VIEWPORT's own pixels into the PNG's. Those are not the same number here
## (the viewport runs 1920x1080 while the window and the saved frame are
## 1600x900), and a crop computed in the wrong one is off by 20% and looks
## almost right, which is the worst way for it to be wrong.
func _crop_over(node: Node3D) -> Array:
	var cam: Camera3D = view.camera
	var frame: Vector2 = cam.get_viewport().get_visible_rect().size
	var png := Vector2(1600.0, 900.0)
	var k: Vector2 = png / frame
	var lo := Vector2(1e9, 1e9)
	var hi := Vector2(-1e9, -1e9)
	var box := AABB()
	var first := true
	for child in node.find_children("*", "MeshInstance3D", true, false):
		var mi := child as MeshInstance3D
		if mi.mesh == null:
			continue
		var a: AABB = mi.global_transform * mi.get_aabb()
		if first: box = a; first = false
		else: box = box.merge(a)
	for i in 8:
		if cam.is_position_behind(box.get_endpoint(i)):
			continue
		var s: Vector2 = cam.unproject_position(box.get_endpoint(i)) * k
		lo = Vector2(minf(lo.x, s.x), minf(lo.y, s.y))
		hi = Vector2(maxf(hi.x, s.x), maxf(hi.y, s.y))
	if game.player != null:
		var p: Vector2 = game.player.global_position
		for y in [0.0, 176.0]:
			var s2: Vector2 = cam.unproject_position(Vector3(p.x, y, p.y) * W) * k
			lo = Vector2(minf(lo.x, s2.x), minf(lo.y, s2.y))
			hi = Vector2(maxf(hi.x, s2.x), maxf(hi.y, s2.y))
	var pad := 70.0
	lo -= Vector2(pad, pad)
	hi += Vector2(pad, pad)
	lo = Vector2(clampf(lo.x, 0.0, png.x), clampf(lo.y, 0.0, png.y))
	hi = Vector2(clampf(hi.x, 0.0, png.x), clampf(hi.y, 0.0, png.y))
	return [int(lo.x), int(lo.y), int(hi.x - lo.x), int(hi.y - lo.y)]


func _unstand(node: Node3D) -> void:
	for i in range(view._model_light_statics.size() - 1, -1, -1):
		if (view._model_light_statics[i] as Dictionary).node == node:
			view._model_light_statics.remove_at(i)
	view.remove_child(node)
	node.queue_free()


## Every BaseMaterial3D the specimen actually renders with — surface materials
## AND per-instance overrides, because either can be the one on screen.
func _materials_of(node: Node3D) -> Array:
	var out: Array = []
	for child in node.find_children("*", "GeometryInstance3D", true, false):
		var gi := child as GeometryInstance3D
		if gi.material_override is BaseMaterial3D:
			out.append(gi.material_override)
		var mi := child as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var over := mi.get_surface_override_material(i)
			if over is BaseMaterial3D:
				out.append(over)
			var surf := mi.mesh.surface_get_material(i)
			if surf is BaseMaterial3D:
				out.append(surf)
	return out


func _set_metallic(mats: Array, value: float) -> Dictionary:
	var was := {}
	for m in mats:
		var mat := m as BaseMaterial3D
		if was.has(mat):
			continue
		was[mat] = mat.metallic
		mat.metallic = value
	return was


func _restore(was: Dictionary) -> void:
	for mat in was.keys():
		(mat as BaseMaterial3D).metallic = float(was[mat])


## --- plumbing, the `edge_ab.gd` idiom ---------------------------------------------

func _flush() -> void:
	for _i in 3:
		view._process(0.0)
		await process_frame
	await process_frame


func _grab(path: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)


func _boot() -> void:
	var world = load("res://scenes/main3d.tscn").instantiate()
	root.add_child(world)
	await process_frame
	view = world
	game = world.get_node("SkyGear")
	view.cutscenes_enabled = false
	game.workshop = SkyGearWorkshop.fresh(true)
	game.heat = 0
	game.set_class("captain")
	game.set_seed_text("DECK")
	game.begin_run()
	game.choose_draft(0)
	game.start_wave(1)
	game.spawn_queue.clear()
	view.sway = false
	view.stop_cutscene()
	for _i in 20:
		game._process(1.0 / 60.0)
		await process_frame
	var overlay = game.get_node_or_null("HUD")
	if overlay != null:
		overlay.visible = false


func _pose(zoom: float) -> void:
	if game.state == SkyGearGame.State.DRAFT:
		game.choose_draft(0)
	game.start_wave(1)
	game.spawn_queue.clear()
	game.player.global_position = CAPTAIN_AT
	game.player.velocity = Vector2.ZERO
	view._focus_set = false
	view._zoom = zoom
	view._zoom_target = zoom
	for _i in 4:
		game._process(1.0 / 60.0)
		await process_frame
