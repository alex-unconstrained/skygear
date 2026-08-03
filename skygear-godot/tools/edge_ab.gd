extends SceneTree
## THE OWNER'S A/B: the bow, the stern and the mast IN PLACE against the deck
## that ships without them. One process, one freeze, one pose per pair.
##
##   godot --path . --resolution 1600x900 --script tools/edge_ab.gd -- all
##   godot --path . --resolution 1600x900 --script tools/edge_ab.gd -- mast
##   godot --path . --resolution 1600x900 --script tools/edge_ab.gd -- bow
##   godot --path . --resolution 1600x900 --script tools/edge_ab.gd -- stern
##
## WHY THIS EXISTS BESIDE `tools/edge_place.gd` RATHER THAN INSIDE IT.
## `edge_place` photographs ONE state per invocation and writes each frame to its
## own file, which is what the SG-157 trials needed. The owner asked a different
## question — *"the difference between using those instead of the procedural
## shadow casters"* — and the answer to that is a PAIR that differs by the piece
## and by nothing else. Two invocations of `edge_place` cannot supply it: the
## brazier flicker, the GPU particle clock and the cloud drift never arrive at
## the shutter in the same place twice (SG-108, and DECK-IDENTITY §7.5 recorded
## the same scene reporting 0.72% and 13.55% across two runs).
##
## So both plates of every pair are taken INSIDE ONE `SkyGearStill.freeze`, with
## the piece toggled between them and nothing else touched, and the tool prints
## its own noise floor first — two plates with NOTHING changed. Zero, or every
## picture below it is weather.
##
## NOTHING IN `scripts/` IS EDITED. The mast pair drives the existing
## `view.rig_model_masts` switch (default OFF, and it is left OFF); the stern
## pair drives the existing `view.edge_stern_trial`; the bow is instantiated into
## `view._edge_kit` from here, because `_build_edge_kit()` deliberately does not
## build one and this tool is not the place to change that.
##
## The placements are the ones the SG-157 verdicts in `view3d.gd` name, so these
## frames are the same trials the refusals rest on, now with their control.
##
## Writes `.shots/owner-review/_raw/<pair>-<A|B>.png` and a `manifest.json` that
## `tools/ab_sheet.py` turns into the labelled side-by-sides.
##
## NOT `--headless`: every frame is a framebuffer readback and headless has no
## GPU (SG-29).

const W := 0.01                     ## WORLD_SCALE
const DECK := Rect2(-840, -1160, 1680, 2320)
const OUT_DIR := "res://.shots/owner-review/_raw"

const SPOTS := {
	"mid":       Vector2(0.50, 0.50),
	"port":      Vector2(0.06, 0.46),
	"stem":      Vector2(0.50, 0.00),
	"transom":   Vector2(0.50, 1.00),
}

## The three trials the `view3d.gd` verdicts name, verbatim, so the control frame
## belongs to the same argument. z in ground units, `s` a uniform scale.
const BOW_TRIALS := [
	{"tag": "bow-1-apron-tip", "spot": "stem", "zoom": 1.0,
		"z": -1655.0, "s": 1.75,
		"note": "seated at the apron's tip, sized to the 344-unit stem"},
	{"tag": "bow-2-at-bow-line", "spot": "stem", "zoom": 1.55,
		"z": -1350.0, "s": 2.0,
		"note": "brought aft into the last of the lit deck"},
	{"tag": "bow-3-enlarged", "spot": "stem", "zoom": 1.55,
		"z": -1560.0, "s": 3.0,
		"note": "big enough that it cannot be missed"},
]

## THREE, not two, and the third is the one the SG-157 write-up could not be
## reproduced from: its frame is named for the SCALE only, and at the tool's
## default z = 1380 the piece does NOT stand in front of the captain. z = 1280
## brings it forward into the band the verdict describes, where it does.
const STERN_TRIALS := [
	{"tag": "stern-1-own-size", "spot": "transom", "zoom": 1.0,
		"z": 1380.0, "s": 1.0, "note": "its own authored size, at the aft limit"},
	{"tag": "stern-2-brought-forward", "spot": "transom", "zoom": 1.0,
		"z": 1280.0, "s": 1.0,
		"note": "same size, 100 units forward — far enough on screen to be seen whole"},
	{"tag": "stern-3-toward-transom", "spot": "transom", "zoom": 1.0,
		"z": 1380.0, "s": 2.5, "note": "sized toward the 874-unit transom"},
]

const MAST_POSES := [
	{"tag": "mast-mid", "spot": "mid", "zoom": 1.0},
	{"tag": "mast-mid-close", "spot": "mid", "zoom": 1.55},
	{"tag": "mast-port", "spot": "port", "zoom": 1.0},
]

var view
var game
var manifest: Array = []


func _initialize() -> void: call_deferred("_run")


func _run() -> void:
	if not SkyGearRendererCheck.can_capture():
		print(SkyGearRendererCheck.capture_refusal())
		quit(2)
		return
	var argv := OS.get_cmdline_user_args()
	var mode := str(argv[0]) if argv.size() > 0 else "all"

	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1600, 900))
	root.size = Vector2i(1600, 900)
	await process_frame
	await _boot()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))

	if mode == "all" or mode == "mast":
		for pose in MAST_POSES:
			await _pair(str(pose.tag), str(pose.spot), float(pose.zoom),
				"THE MAST", "SHIPPED: procedural shadow casters",
				"OWNER'S MODEL: mast_crowned as the caster",
				"three masts at x +/-280, 1500 units tall, shadows only",
				_mast_on, _mast_off)
	if mode == "all" or mode == "bow":
		for t in BOW_TRIALS:
			var trial: Dictionary = t
			await _pair(str(trial.tag), str(trial.spot), float(trial.zoom),
				"THE BOW", "SHIPPED: no bow model (the hull apron alone)",
				"WITH bow_ram at z %.0f, scale %.2f" % [float(trial.z), float(trial.s)],
				str(trial.note),
				func(): return _bow_on(float(trial.z), float(trial.s)),
				_piece_off)
	if mode == "all" or mode == "stern":
		for t in STERN_TRIALS:
			var trial: Dictionary = t
			await _pair(str(trial.tag), str(trial.spot), float(trial.zoom),
				"THE STERN", "SHIPPED: no stern model (the hull counter alone)",
				"WITH stern_counter at z %.0f, scale %.2f" % [float(trial.z), float(trial.s)],
				str(trial.note),
				func(): return _stern_on(float(trial.z), float(trial.s)),
				_stern_off)

	var f := FileAccess.open("%s/manifest.json" % OUT_DIR, FileAccess.WRITE)
	f.store_string(JSON.stringify(manifest, "  "))
	f.close()
	print("manifest: %s/manifest.json  (%d pairs)" % [OUT_DIR, manifest.size()])
	quit(0)


## --- the pair ------------------------------------------------------------------
##
## Pose, FREEZE, plate A, toggle the one thing, plate B, untoggle, thaw. The
## toggle happens inside the freeze on purpose: that is the only arrangement in
## which the two plates share a brazier phase, a particle clock and a cloud
## position, and it is the arrangement SG-108 was paid for.
func _pair(tag: String, spot: String, zoom: float, title: String,
		label_a: String, label_b: String, note: String,
		turn_on: Callable, turn_off: Callable) -> void:
	await _pose(spot, zoom)
	await SkyGearStill.freeze(self, view, game)

	## THE FLOOR, FIRST, THROUGH THE SAME DOOR. `_flush()` is exactly what this
	## function does between its two real plates, so a floor measured without it
	## would be a floor for a different tool.
	if manifest.is_empty():
		var box := Rect2i(200, 150, 1200, 600)
		var floor_pct: float = await SkyGearStill.floor_pct(self, box,
			func(): view._process(0.0))
		print("NOISE FLOOR (nothing changed between two plates): %.2f%%  "
			% floor_pct + "(0.00 is the pass condition)")

	var a_path := "%s/%s-A.png" % [OUT_DIR, tag]
	var b_path := "%s/%s-B.png" % [OUT_DIR, tag]
	await _grab(a_path)
	var built = turn_on.call()
	await _flush()
	await _grab(b_path)
	if built is Node3D and is_instance_valid(built):
		_report_box(tag, built)
	turn_off.call(built)
	await _flush()
	await SkyGearStill.thaw(self, view, game)

	manifest.append({"tag": tag, "title": title, "note": note,
		"spot": spot, "zoom": zoom,
		"a": a_path.replace("res://", ""), "b": b_path.replace("res://", ""),
		"label_a": label_a, "label_b": label_b})
	print("  %s  %s vs %s" % [tag, label_a, label_b])


func _flush() -> void:
	for _i in 3:
		view._process(0.0)
		await process_frame
	await process_frame


func _grab(path: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)


## --- the pieces ----------------------------------------------------------------

func _mast_on():
	view.rig_model_masts = true
	view._rigging.queue_free()
	view.remove_child(view._rigging)
	view._build_rigging()
	return null


func _mast_off(_built) -> void:
	view.rig_model_masts = false
	view._rigging.queue_free()
	view.remove_child(view._rigging)
	view._build_rigging()


## `bow_ram`, seated on the sheer at `z`, its POINT toward the bow.
##
## The heading is measured rather than assumed: `edge_place.gd -- measure`
## reports the model's smaller cross-section at its -X end, so the point is -X,
## and `Basis(UP, -PI/2)` carries -X to -Z. That is the same basis the shipped
## rail is placed with, from the same measurement.
##
## The `.tscn` wrapper lifts the mesh by half its height, so the node's own
## origin is the piece's BASE and seating it on `sheer_lift(z)` stands it on the
## apron rather than burying it.
func _bow_on(z: float, s: float) -> Node3D:
	var scene: PackedScene = load("res://assets/models/bow_ram/bow_ram.tscn")
	if scene == null:
		push_warning("no bow_ram scene")
		return null
	var node: Node3D = scene.instantiate()
	var basis := Basis(Vector3.UP, -PI * 0.5).scaled(Vector3(s, s, s))
	node.transform = Transform3D(basis,
		Vector3(0.0, SkyGearView3D.sheer_lift(z), z) * W)
	node.name = "BowRamTrial"
	view._edge_kit.add_child(node)
	return node


## THE STERN GOES THROUGH THE RENDERER'S OWN TRIAL PATH (`edge_stern_trial`),
## never through a second copy of the placement in this file — failure mode two,
## and the stern is where it would have bitten: the shipped verdict's frame is
## named `stern-trial-s1.0/transom-z1.00.png` and the file name records the
## SCALE but not the Z, so there is no way to reproduce that exact frame from
## its name. Driving the renderer's own switch at least guarantees this tool and
## the game agree about where the piece stands for a given z.
func _stern_on(z: float, s: float) -> Node3D:
	view.edge_stern_trial = s
	view.edge_stern_z = z
	view.rebuild_edge_kit(view.edge_rail_tiles)
	for child in view._edge_kit.get_children():
		if not str(child.name).begins_with("RailModule"):
			return child as Node3D
	return null


func _stern_off(_built) -> void:
	view.edge_stern_trial = 0.0
	view.rebuild_edge_kit(view.edge_rail_tiles)


func _piece_off(built) -> void:
	if built is Node3D and is_instance_valid(built):
		view._edge_kit.remove_child(built)
		built.queue_free()


## WHERE THE PIECE ACTUALLY LANDS, in pixels of the frame — `edge_place.gd`'s own
## `_where`, kept because of the near-miss it records: a dark mass in a
## screenshot is not evidence about the piece you just placed unless you know
## where that piece projects.
func _report_box(tag: String, node: Node3D) -> void:
	var cam: Camera3D = view.camera
	var frame: Vector2 = cam.get_viewport().get_visible_rect().size
	var box: AABB = _world_aabb(node)
	var lo := Vector2(1e9, 1e9)
	var hi := Vector2(-1e9, -1e9)
	var behind := 0
	for i in 8:
		var c: Vector3 = box.get_endpoint(i)
		if cam.is_position_behind(c):
			behind += 1
			continue
		var sp: Vector2 = cam.unproject_position(c)
		lo = Vector2(minf(lo.x, sp.x), minf(lo.y, sp.y))
		hi = Vector2(maxf(hi.x, sp.x), maxf(hi.y, sp.y))
	if behind == 8:
		print("      %s: entirely behind the camera" % tag)
		return
	print("      %s: on screen at x %.0f..%.0f  y %.0f..%.0f  (frame %d x %d)"
		% [tag, lo.x, hi.x, lo.y, hi.y, int(frame.x), int(frame.y)])
	if game.player != null:
		var p: Vector2 = game.player.global_position
		var head: Vector2 = cam.unproject_position(Vector3(p.x, 176.0, p.y) * W)
		var foot: Vector2 = cam.unproject_position(Vector3(p.x, 0.0, p.y) * W)
		print("      %s: captain head %s foot %s" % [tag, str(head.round()), str(foot.round())])


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


## --- the deck, posed exactly as `edge_place.gd` poses it -------------------------

func _boot() -> void:
	var world = load("res://scenes/main3d.tscn").instantiate()
	root.add_child(world)
	await process_frame
	view = world
	game = world.get_node("SkyGear")
	## NO CUTSCENE — it hides the HUD, locks the controls and TAKES THE CAMERA, so
	## a tool that skips this photographs the opening reveal's camera instead of
	## the gameplay one (edge_place.gd found this; the note is there).
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
	## Snap past the easing rather than photographing the tail of a 0.155 s lerp.
	view._focus_set = false
	view._zoom = zoom
	view._zoom_target = zoom
	for _i in 4:
		game._process(1.0 / 60.0)
		await process_frame
