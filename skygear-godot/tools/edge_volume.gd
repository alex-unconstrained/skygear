extends SceneTree
## THE VISIBLE ENVELOPE BEYOND THE PLAY RECTANGLE — what a piece standing off
## the bow or off the stern can actually put on screen. SG-176.
##
##   godot --path . --resolution 1600x900 --script tools/edge_volume.gd -- fore
##   godot --path . --resolution 1600x900 --script tools/edge_volume.gd -- aft
##   godot --path . --resolution 1600x900 --script tools/edge_volume.gd -- both
##   godot --path . --resolution 1600x900 --script tools/edge_volume.gd -- frame
##
## WHY THIS EXISTS, AND WHY IT IS NOT A SCREENSHOT.
##
## SG-157 refused a hand-made stern and SG-174 refused a second one of completely
## different proportion, and the second refusal came with the number that makes
## this tool necessary: seated correctly against the deck edge, `stern_counter_v2`
## changed **0.000% of the frame's pixels** at a 2/255 threshold. Two pieces, two
## proportions, one cause — at this 41-degree camera you never see the outside of
## the hull. The prow succeeded in the same session because it stands ABOVE the
## deck plane at the bow, where the frame genuinely shows sky.
##
## Alex now wants a KIT for an upper level at the ends. "Above the deck plane at
## the bow is visible" is the hypothesis that follows from SG-174, and it is a
## HYPOTHESIS: nobody has measured where that band starts, where the frame top
## crops it, how far fore and aft it reaches, or how wide it is. Writing modelling
## prompts before measuring it is how this repo bought two sterns.
##
## SO IT IS MEASURED THE WAY SG-174 MEASURED THE STERN, and deliberately not by a
## different method that could disagree with it: a probe is placed, and TWO PLATES
## ARE TAKEN INSIDE ONE `SkyGearStill.freeze` with the probe as the only
## difference between them. What the tool reports is the percentage of that
## probe's OWN projected rectangle whose pixels moved. That answers occlusion and
## lighting at once, which a frustum test cannot: a probe under the opaque apron
## and a probe in a part of the frame no lamp reaches both come back at zero, and
## both of those are why the stern died.
##
## The frustum test is taken as well and reported beside it, because the two
## disagreeing is itself the finding — IN FRAME but 0% moved is "the hull is in
## front of it, or nothing lights it", and that distinction is what tells Alex
## whether a piece is impossible or merely unlit.
##
## THE PROBE LATTICE, in ground units, per end:
##   x   -1050 .. +1050    (the deck is 1680 wide, so +/-1050 is outboard of it)
##   y   -180 .. +600      (the deck plane is 0; the captain is 176; the rail 125)
##   z   the two slices INBOARD of the boundary, then out to 1440 units beyond
##
## ONE Z SLICE PER RENDER, and that is not timidity: probes at different z along
## one screen ray hide each other, and a probe hidden by another probe would be
## reported invisible. Within a slice the screen rectangles are checked for
## overlap and the tool says so if any two touch.
##
## `frame` draws the annotated picture from `envelope.json` — it plants NO
## geometry, so what is behind the annotation is the deck exactly as it ships.
##
## Writes `.shots/sg176/envelope.json` and `.shots/sg176/*.png`.
##
## NOT `--headless`: every plate is a framebuffer readback and headless has no
## GPU (SG-29). The freeze is `SkyGearStill` (SG-108) — this tool photographs the
## deck and it FREEZES it.

const W := 0.01                     ## WORLD_SCALE
const DECK := Rect2(-840, -1160, 1680, 2320)
const OUT_DIR := "res://.shots/sg176"

const SPOTS := {
	"mid":     Vector2(0.50, 0.50),
	"stem":    Vector2(0.50, 0.00),
	"transom": Vector2(0.50, 1.00),
}

## The probe cube's edge, ground units. Big enough to survive the 2-pixel
## sampling stride at the far end of the sweep, small enough that neighbours 60
## apart in y do not touch on screen.
const PROBE := 45.0

const XS: Array[float] = [-1050.0, -840.0, -420.0, 0.0, 420.0, 840.0, 1050.0]
const YS: Array[float] = [-180.0, -120.0, -60.0, 0.0, 60.0, 120.0, 180.0,
	240.0, 300.0, 360.0, 420.0, 480.0, 540.0, 600.0]

## Two slices INBOARD of the boundary and eight beyond it. The inboard pair is
## here for one question only — how far a raised platform may overhang toward the
## deck she walks — and the tool flags them rather than recommending them.
const FORE_Z: Array[float] = [-820.0, -1000.0, -1160.0, -1340.0, -1520.0,
	-1700.0, -1880.0, -2060.0, -2240.0, -2420.0, -2600.0]
const AFT_Z: Array[float] = [820.0, 1000.0, 1160.0, 1340.0, 1520.0,
	1700.0, 1880.0, 2060.0, 2240.0, 2420.0, 2600.0]

## Pose and zoom pairs. The zoom question is explicit in the brief — the player
## zooms out on the mousewheel and a piece that only reads at one zoom is a trap
## — so every slice is taken at both, and `mid` is here because it is the pose
## the player is in for almost the whole run.
const FORE_VIEWS := [
	{"spot": "stem", "zoom": 1.0}, {"spot": "stem", "zoom": 1.55},
	{"spot": "mid", "zoom": 1.0}, {"spot": "mid", "zoom": 1.55},
]
const AFT_VIEWS := [
	{"spot": "transom", "zoom": 1.0}, {"spot": "transom", "zoom": 1.55},
	{"spot": "mid", "zoom": 1.0}, {"spot": "mid", "zoom": 1.55},
]

## A pixel counts as moved at the same step `SkyGearStill` uses, so this tool and
## every A/B in the repo mean the same thing by "changed".
const SAMPLE := 2

## What the verdicts mean, as a share of the probe's own projected rectangle.
const CLEAR := 25.0
const TRACE := 4.0

var view
var game
var _probes: Node3D
var _rows: Array = []
var _floor_done := false


func _scaled(r: Rect2, k: Vector2) -> Rect2:
	return Rect2(r.position * k, r.size * k)


func _initialize() -> void: call_deferred("_run")


func _run() -> void:
	if not SkyGearRendererCheck.can_capture():
		print(SkyGearRendererCheck.capture_refusal())
		quit(2)
		return
	var argv := OS.get_cmdline_user_args()
	var mode := str(argv[0]) if argv.size() > 0 else "both"

	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1600, 900))
	root.size = Vector2i(1600, 900)
	await process_frame
	await _boot()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))

	if mode == "kit":
		await _kit()
		quit(0)
		return

	if mode == "frame":
		await _annotate(str(argv[1]) if argv.size() > 1 else "stem",
			float(argv[2]) if argv.size() > 2 else 1.0)
		quit(0)
		return

	## A single pose can be named on the command line — the full matrix is eight
	## pose/zoom pairs across twenty-two slices and that is a ten-minute run, so
	## the sweep is splittable rather than all-or-nothing.
	var only := str(argv[1]) if argv.size() > 1 else ""
	var only_zoom := float(argv[2]) if argv.size() > 2 else 0.0
	if mode == "fore" or mode == "both":
		await _end("fore", FORE_Z, _pick(FORE_VIEWS, only, only_zoom))
	if mode == "aft" or mode == "both":
		await _end("aft", AFT_Z, _pick(AFT_VIEWS, only, only_zoom))

	var f := FileAccess.open("%s/envelope.json" % OUT_DIR, FileAccess.WRITE)
	f.store_string(JSON.stringify(_rows, "  "))
	f.close()
	print("")
	print("wrote %s/envelope.json  (%d probe readings)" % [OUT_DIR, _rows.size()])
	_summary()
	quit(0)


func _pick(views: Array, spot: String, zoom: float) -> Array:
	if spot == "":
		return views
	var out: Array = []
	for v in views:
		var pose: Dictionary = v
		if str(pose.spot) != spot: continue
		if zoom > 0.0 and absf(float(pose.zoom) - zoom) > 0.01: continue
		out.append(pose)
	return out


## --- one end -------------------------------------------------------------------
func _end(tag: String, zs: Array, views: Array) -> void:
	print("")
	print("=== %s — %d z slices x %d x %d probes, at %d poses ==="
		% [tag.to_upper(), zs.size(), XS.size(), YS.size(), views.size()])
	for v in views:
		var pose: Dictionary = v
		var spot := str(pose.spot)
		var zoom := float(pose.zoom)
		print("")
		print("-- pose %s, zoom %.2f --" % [spot, zoom])
		_floor_done = false
		await _pose(spot, zoom)
		_where()
		for z in zs:
			await _slice(tag, spot, zoom, float(z))


## WHERE THE FRAME'S OWN EDGES LAND, per pose. The stern verdict of SG-174 rests
## on the bottom edge and the prow's on the top, so a sweep that reports probe
## readings without them leaves the next reader unable to explain either.
func _where() -> void:
	var cam: Camera3D = view.camera
	var frame: Vector2 = cam.get_viewport().get_visible_rect().size
	var line := "  camera at z %+.0f, y %+.0f;  " % [
		cam.global_position.z / W, cam.global_position.y / W]
	for edge in [["top", 0.0], ["bottom", frame.y]]:
		var o: Vector3 = cam.project_ray_origin(Vector2(frame.x * 0.5, float(edge[1])))
		var d: Vector3 = cam.project_ray_normal(Vector2(frame.x * 0.5, float(edge[1])))
		if absf(d.y) > 0.0001:
			var t: float = -o.y / d.y
			if t > 0.0:
				line += "frame %s meets the deck plane at z %+.0f;  " % [
					str(edge[0]), (o + d * t).z / W]
			else:
				line += "frame %s never meets the deck plane (it is sky);  " % str(edge[0])
	print(line)


## ONE Z SLICE: pose, freeze, plate without the probes, show them, plate with
## them, hide, thaw. The probes are the only thing that differs between the two
## plates and they are toggled INSIDE the freeze, which is the arrangement SG-108
## was paid for and the only one in which the brazier flicker, the particle clock
## and the cloud drift are the same in both.
func _slice(tag: String, spot: String, zoom: float, z: float) -> void:
	var t0 := Time.get_ticks_msec()
	_build_probes(z)
	_probes.visible = false
	await _pose(spot, zoom)
	await SkyGearStill.freeze(self, view, game)

	var a := await _plate()

	## THE FLOOR, PER PROBE AND PER POSE, THROUGH THE SAME DOOR. A whole-frame
	## floor is not the control this tool needs: what is read here is the share of
	## ONE SMALL RECTANGLE that moved, and SG-175 measured this family's floor at
	## up to 0.17% of a frame that is mostly sky — a floor of 0.17% spread over
	## the whole picture could still be 30% of a forty-pixel rectangle. So the
	## first slice of every pose takes a THIRD plate with the probes still hidden
	## and runs the identical per-rectangle measurement on it. Every verdict below
	## is read against the worst number that comes back.
	if not _floor_done:
		_floor_done = true
		await _flush()
		var a2 := await _plate()
		var cam0: Camera3D = view.camera
		var frame0: Vector2 = cam0.get_viewport().get_visible_rect().size
		var shot0 := Vector2(float(a.get_width()), float(a.get_height()))
		var to_px0 := Vector2(shot0.x / frame0.x, shot0.y / frame0.y)
		var worst := 0.0
		var sum := 0.0
		var n := 0
		for node0 in _probes.get_children():
			var p0: Vector3 = (node0 as Node3D).get_meta("gu")
			var c0: Rect2i = _clip(_scaled(_screen_rect(cam0, p0, frame0), to_px0), shot0)
			if c0.size.x <= 0: continue
			var f0 := _moved_pct(a, a2, c0)
			worst = maxf(worst, f0)
			sum += f0
			n += 1
		print("  PER-PROBE NOISE FLOOR at this pose: worst %.2f%%, mean %.2f%% "
			% [worst, sum / maxf(1.0, float(n))]
			+ "over %d rectangles  (a reading is called a trace at %.0f%%)"
				% [n, TRACE])
		a = await _plate()
	_probes.visible = true
	await _flush()
	var b := await _plate()
	_probes.visible = false
	await _flush()
	await SkyGearStill.thaw(self, view, game)

	var cam: Camera3D = view.camera
	var frame: Vector2 = cam.get_viewport().get_visible_rect().size
	## THE VIEWPORT AND THE PICTURE ARE NOT THE SAME SIZE, and a whole first run
	## of this tool reported "nothing is visible anywhere" because of it. The
	## project renders at a 1920x1080 base and `canvas_items` stretch puts it in a
	## 1600x900 window, so `unproject_position` speaks in 1920 while the readback
	## image is 1600 — every probe was sampled 167 pixels away from itself and
	## every reading came back zero. `edge_place.gd` has a note saying these two
	## differ; it prints the viewport size and never converts. This does.
	var shot := Vector2(float(a.get_width()), float(a.get_height()))
	var to_px := Vector2(shot.x / frame.x, shot.y / frame.y)
	var rects: Array = []
	for node in _probes.get_children():
		var m := node as Node3D
		var p: Vector3 = m.get_meta("gu")
		var r := _screen_rect(cam, p, frame)
		rects.append(r)
		var clipped: Rect2i = _clip(_scaled(r, to_px), shot)
		var moved: float = -1.0
		if clipped.size.x > 0 and clipped.size.y > 0:
			moved = _moved_pct(a, b, clipped)
		_rows.append({
			"end": tag, "spot": spot, "zoom": zoom,
			"x": p.x, "y": p.y, "z": p.z,
			"frustum": _frustum_word(r, frame),
			"moved": moved,
			"sx": r.position.x + r.size.x * 0.5,
			"sy": r.position.y + r.size.y * 0.5,
			## What share of the frame this probe's own rectangle covers. A probe
			## a few hundred units in front of the lens projects to most of the
			## picture, and "it was visible" is a worthless sentence about it: a
			## piece there does not dress the ship, it blindfolds the player.
			"cover": 100.0 * (r.size.x * r.size.y) / (frame.x * frame.y),
		})
	_warn_overlap(z, rects)
	_print_slice(tag, spot, zoom, z, Time.get_ticks_msec() - t0)
	_probes.queue_free()
	view.remove_child(_probes)
	_probes = null


func _print_slice(tag: String, spot: String, zoom: float, z: float, ms: int) -> void:
	## One line per height at the CENTRELINE, plus the widest x that still reads.
	## The full lattice goes to the JSON; a table nobody can scan is a table
	## nobody reads.
	var line := "  z %+5.0f  " % z
	var best_lo := 9999.0
	var best_hi := -9999.0
	for y in YS:
		var v := _at(tag, spot, zoom, z, 0.0, float(y))
		var ch := "."
		if v >= CLEAR: ch = "#"
		elif v >= TRACE: ch = "+"
		if v >= TRACE:
			best_lo = minf(best_lo, float(y))
			best_hi = maxf(best_hi, float(y))
		line += ch
	var width_lo := 9999.0
	var width_hi := -9999.0
	var lens := 0
	for r in _rows:
		var row: Dictionary = r
		if str(row.end) != tag or float(row.z) != z: continue
		if str(row.spot) != spot or absf(float(row.zoom) - zoom) > 0.01: continue
		if float(row.moved) >= TRACE:
			width_lo = minf(width_lo, float(row.x))
			width_hi = maxf(width_hi, float(row.x))
			if float(row.cover) >= 15.0:
				lens += 1
	var note := ""
	if lens > 0:
		note = "   ON THE LENS: %d of them cover >15%% of the frame" % lens
	if best_hi < best_lo:
		print(line + "   nothing on the centreline reads at any height   [%d ms]%s"
			% [ms, note])
	else:
		print(line + "   y %+.0f..%+.0f   x %+.0f..%+.0f   [%d ms]%s"
			% [best_lo, best_hi, width_lo, width_hi, ms, note])


## FILTERED BY POSE AND ZOOM, AND IT WAS NOT ON THE FIRST RUN. Every slice line
## after the first pose re-printed the FIRST pose's readings, because this lookup
## matched on the lattice coordinates alone and `_rows` holds every pose. The
## summary was right and the table beside it was a copy of somebody else's
## camera — this repo's second failure mode in miniature, and it was caught by
## four different cameras printing an identical picture.
func _at(tag: String, spot: String, zoom: float, z: float, x: float, y: float) -> float:
	for r in _rows:
		var row: Dictionary = r
		if str(row.end) != tag or str(row.spot) != spot: continue
		if absf(float(row.zoom) - zoom) > 0.01: continue
		if float(row.z) == z and float(row.x) == x and float(row.y) == y:
			return float(row.moved)
	return -1.0


## --- the probes ----------------------------------------------------------------
##
## A probe wears the material a kit piece wears — flat warm timber at the
## metalness the ingest clamps to — rather than an unshaded marker colour. That
## is the whole point of measuring by pixels: an emissive marker would be visible
## in places a real piece is not, which is precisely the mistake that would have
## kept the stern alive.
func _build_probes(z: float) -> void:
	_probes = Node3D.new()
	_probes.name = "EdgeVolumeProbes"
	view.add_child(_probes)
	var mesh := BoxMesh.new()
	mesh.size = Vector3(PROBE, PROBE, PROBE) * W
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("#6b5a44")
	mat.roughness = 0.85
	mat.metallic = 0.34
	mesh.material = mat
	for x in XS:
		for y in YS:
			var mi := MeshInstance3D.new()
			mi.mesh = mesh
			## SHADOWS OFF, and it is not a detail. The reading is "what share of
			## this probe's own rectangle changed", and a probe that threw a shadow
			## onto the planking under it could move pixels inside that rectangle
			## without any part of the probe itself being visible — which is the
			## measurement answering a different question than the one asked.
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.position = Vector3(float(x), float(y), z) * W
			mi.set_meta("gu", Vector3(float(x), float(y), z))
			_probes.add_child(mi)


func _screen_rect(cam: Camera3D, gu: Vector3, frame: Vector2) -> Rect2:
	var h := PROBE * 0.5
	var lo := Vector2(1e9, 1e9)
	var hi := Vector2(-1e9, -1e9)
	for i in 8:
		var c := gu + Vector3(
			h if (i & 1) else -h, h if (i & 2) else -h, h if (i & 4) else -h)
		if cam.is_position_behind(c * W):
			return Rect2(-1e6, -1e6, 0, 0)
		var s: Vector2 = cam.unproject_position(c * W)
		lo = Vector2(minf(lo.x, s.x), minf(lo.y, s.y))
		hi = Vector2(maxf(hi.x, s.x), maxf(hi.y, s.y))
	return Rect2(lo, hi - lo)


func _frustum_word(r: Rect2, frame: Vector2) -> String:
	if r.size.x <= 0.0 and r.size.y <= 0.0:
		return "behind"
	var f := Rect2(Vector2.ZERO, frame)
	if not f.intersects(r):
		return "out"
	if f.encloses(r):
		return "in"
	return "cropped"


func _clip(r: Rect2, frame: Vector2) -> Rect2i:
	var f := Rect2(Vector2.ZERO, frame)
	if r.size.x <= 0.0 or not f.intersects(r):
		return Rect2i(0, 0, 0, 0)
	var c := f.intersection(r)
	## Clamped by construction rather than by trusting the intersection's
	## rounding: a probe close to the camera projects to a rectangle far wider
	## than the frame, and one pixel past the edge is an out-of-bounds read.
	var x0 := clampi(int(floor(c.position.x)), 0, int(frame.x) - 1)
	var y0 := clampi(int(floor(c.position.y)), 0, int(frame.y) - 1)
	var x1 := clampi(int(ceil(c.end.x)), x0 + 1, int(frame.x))
	var y1 := clampi(int(ceil(c.end.y)), y0 + 1, int(frame.y))
	return Rect2i(x0, y0, x1 - x0, y1 - y0)


## Two probes whose screen rectangles touch can hide each other, and a probe
## hidden by another probe would be written down as invisible. Reported rather
## than assumed away.
func _warn_overlap(z: float, rects: Array) -> void:
	var hits := 0
	for i in rects.size():
		var a: Rect2 = rects[i]
		if a.size.x <= 0.0: continue
		for j in range(i + 1, rects.size()):
			var b: Rect2 = rects[j]
			if b.size.x <= 0.0: continue
			if a.intersects(b): hits += 1
	if hits > 0:
		print("  z %+.0f  WARNING: %d probe pairs overlap on screen — "
			% [z, hits] + "readings in this slice may under-report")


## --- plates --------------------------------------------------------------------
func _plate() -> Image:
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()


func _moved_pct(a: Image, b: Image, box: Rect2i) -> float:
	var moved := 0
	var total := 0
	## The stride opens up on a big rectangle. A probe a metre from the lens
	## projects to most of the frame and a two-pixel walk over it is a million
	## `get_pixel` calls in GDScript; sixty samples across is the same fraction.
	var step: int = maxi(SAMPLE, maxi(box.size.x, box.size.y) / 60)
	var y := box.position.y
	while y < box.position.y + box.size.y:
		var x := box.position.x
		while x < box.position.x + box.size.x:
			var ca := a.get_pixel(x, y)
			var cb := b.get_pixel(x, y)
			total += 1
			if maxf(absf(ca.r - cb.r), maxf(absf(ca.g - cb.g),
					absf(ca.b - cb.b))) >= SkyGearStill.MOVED:
				moved += 1
			x += step
		y += step
	return 0.0 if total == 0 else 100.0 * float(moved) / float(total)


func _flush() -> void:
	for _i in 3:
		view._process(0.0)
		await process_frame
	await process_frame


## --- the annotated frame -------------------------------------------------------
##
## ORIENTATION, not a dimension drawing. It plants no geometry: the picture under
## the annotation is the deck exactly as it ships, and the overlay is drawn from
## `envelope.json` at the same pose and zoom the readings were taken at, so what
## is coloured in is what was measured rather than what was hoped.
## --- the kit, mocked, before anybody models anything --------------------------
##
## THE PROBE LATTICE SAYS WHERE A PIECE COULD BE SEEN. It does not say whether the
## ARRANGEMENT reads, and that is a different question — the prow was refused once
## at a seat that the frustum was perfectly happy with. So this stands the
## proposed upper level up out of primitives and out of the OWNER'S OWN RAIL, at
## the heights the lattice says are in the band, and takes the same A/B pair the
## bow and the stern were judged on.
##
## It is a MOCK and it is not shipped: nothing here is added to `_build_edge_kit`,
## and the whole point is to buy the answer before he spends an evening modelling.
## The one thing in it that is not a primitive is `rail_stanchion` — the module he
## already made and that already ships at N = 10 — because "can his existing rail
## be reused up there" is a question this can answer with the real asset instead
## of with arithmetic about it.
const MOCK_TOP := 250.0        ## the platform's floor: twice the shipped rail's top
const MOCK_AFT := -1160.0      ## its aft edge, on the bow line
const MOCK_RUN := 360.0        ## how far forward it reaches
const MOCK_BEAM := 1680.0      ## the deck's own beam


func _kit() -> void:
	for v in [{"spot": "stem", "zoom": 1.0}, {"spot": "stem", "zoom": 1.55},
			{"spot": "mid", "zoom": 1.0}, {"spot": "mid", "zoom": 1.55}]:
		var pose: Dictionary = v
		var spot := str(pose.spot)
		var zoom := float(pose.zoom)
		await _pose(spot, zoom)
		await SkyGearStill.freeze(self, view, game)
		var a := await _plate()
		var mock := _build_mock()
		await _flush()
		var b := await _plate()
		var path := "%s/kit-%s-z%.2f.png" % [OUT_DIR, spot, zoom]
		b.save_png(path)
		var pct := _moved_pct(a, b, Rect2i(0, 0, a.get_width(), a.get_height()))
		mock.queue_free()
		view.remove_child(mock)
		await _flush()
		await SkyGearStill.thaw(self, view, game)
		print("  %-5s zoom %.2f   the mocked upper level changes %.2f%% of the frame"
			% [spot, zoom, pct] + "   -> %s" % path.replace("res://", ""))


func _build_mock() -> Node3D:
	var holder := Node3D.new()
	holder.name = "UpperDeckMock"
	view.add_child(holder)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("#6b5a44")
	mat.roughness = 0.85
	mat.metallic = 0.34

	## The platform, a slab the width of the deck standing on the bow line.
	_slab(holder, mat, Vector3(0.0, MOCK_TOP - 20.0, MOCK_AFT - MOCK_RUN * 0.5),
		Vector3(MOCK_BEAM, 40.0, MOCK_RUN))
	## What holds it up: five posts down to the deck plane.
	for x in [-780.0, -390.0, 0.0, 390.0, 780.0]:
		_slab(holder, mat, Vector3(x, MOCK_TOP * 0.5 - 20.0, MOCK_AFT - 60.0),
			Vector3(70.0, MOCK_TOP - 40.0, 70.0))
	## The stair, as a run of risers — one flight, deck plane to platform.
	##
	## AND IT GOES AFT OF THE PLATFORM'S EDGE, WHICH THE FIRST VERSION OF THIS MOCK
	## GOT WRONG AND THE PICTURE CAUGHT. Run forward UNDER the platform and the
	## platform is directly between the stair and the lens: `kit-stem-z1.00` had a
	## twelve-riser flight in it that cannot be found in the frame. A stair at this
	## camera has to climb TOWARD the piece it lands on, out on the open deck, or
	## the one asset in the kit whose whole job is to read as a stair reads as
	## nothing.
	var steps := 12
	for i in steps:
		var h: float = MOCK_TOP * float(i + 1) / float(steps)
		_slab(holder, mat,
			Vector3(-560.0, h * 0.5, MOCK_AFT + 330.0 - 30.0 * float(i)),
			Vector3(300.0, h, 30.0))

	## AND THE RAIL IS HIS, NOT A BOX. Same scene, same scale the deck ships it at,
	## laid ACROSS the beam instead of along the side — the module is symmetric
	## about its long axis, so the only change is which way its length points.
	var scene: PackedScene = load(SkyGearView3D.EDGE_RAIL_SCENE)
	if scene != null:
		var s: float = view.edge_rail_scale()
		var pitch: float = SkyGearView3D.RAIL_PITCH_NATIVE * s
		var i := -3
		while i <= 3:
			var node: Node3D = scene.instantiate()
			node.transform = Transform3D(Basis().scaled(Vector3(s, s, s)),
				Vector3(float(i) * pitch * 2.0, MOCK_TOP, MOCK_AFT - 40.0) * W)
			node.name = "MockRail%d" % (i + 3)
			holder.add_child(node)
			i += 1
	return holder


func _slab(holder: Node3D, mat: StandardMaterial3D, at: Vector3, size: Vector3) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size * W
	mesh.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = at * W
	holder.add_child(mi)


## ORIENTATION, not a dimension drawing, and the first version of this was not
## orientation either. It drew every probe in the lattice as a coloured square and
## the result was eight hundred dots of confetti over a photograph — true, and
## unreadable. What a person needs to see is THE BAND: one shaded wedge over the
## real frame, bounded above by the highest reading at each distance and below by
## the lowest, so the shape of the space is the thing the picture is of.
##
## It plants NO geometry. What is under the annotation is the deck exactly as it
## ships, at the pose and zoom the readings were taken at.
func _annotate(spot: String, zoom: float) -> void:
	var txt := FileAccess.get_file_as_string("%s/envelope.json" % OUT_DIR)
	if txt == "":
		print("no envelope.json — run `-- both` first")
		return
	var rows: Array = JSON.parse_string(txt)
	var end := "aft" if spot == "transom" else "fore"
	await _pose(spot, zoom)
	var cam: Camera3D = view.camera

	## The band on the CENTRELINE, slice by slice: the top and the bottom of what
	## read clearly. Probes covering more than a sixth of the frame are dropped —
	## those are on the lens rather than on the ship, and including them would
	## draw the wedge wrapping round the camera.
	var zs: Array = []
	var tops := {}
	var bots := {}
	for r in rows:
		var row: Dictionary = r
		if str(row.end) != end or str(row.spot) != spot: continue
		if absf(float(row.zoom) - zoom) > 0.01: continue
		if float(row.x) != 0.0: continue
		if float(row.moved) < CLEAR or float(row.cover) >= 16.0: continue
		## Only the near band is drawn. Beyond about seven hundred units past the
		## boundary the readings are a one-probe-high sliver on the horizon, and a
		## wedge stretched out to it is a picture of the horizon rather than of the
		## space a kit would stand in.
		if absf(float(row.z)) > 1900.0: continue
		## And only what is OUTSIDE the rectangle she walks. The two inboard
		## slices are in the sweep to answer the overhang question and they are
		## not part of the space a kit stands in; drawing them sprawls the wedge
		## down past the lens and hides the shape of the thing.
		if absf(float(row.z)) < 1150.0: continue
		var z := float(row.z)
		var y := float(row.y)
		if not tops.has(z):
			zs.append(z)
			tops[z] = y
			bots[z] = y
		tops[z] = maxf(float(tops[z]), y)
		bots[z] = minf(float(bots[z]), y)
	zs.sort()

	var layer := CanvasLayer.new()
	layer.layer = 100
	root.add_child(layer)

	## DRAWN AT THE TWO DECK EDGES AND NOT ON THE CENTRELINE, and the first
	## attempt at this was drawn on the centreline and came out as a vertical
	## yellow stripe. The camera sits on the centreline, so a centreline elevation
	## projects to a LINE — the one place in the frame where a wedge cannot be
	## seen. At the port and starboard edges the same band opens out to left and
	## right of the captain and reads as the volume it is.
	for edge in [-560.0, 560.0]:
		var poly := PackedVector2Array()
		for z in zs:
			poly.append(cam.unproject_position(
				Vector3(edge, float(tops[z]), float(z)) * W))
		for k in range(zs.size() - 1, -1, -1):
			var z2: float = zs[k]
			poly.append(cam.unproject_position(
				Vector3(edge, float(bots[z2]), float(z2)) * W))
		if poly.size() < 3:
			continue
		var fill := Polygon2D.new()
		fill.polygon = poly
		fill.color = Color(0.30, 0.95, 0.45, 0.20)
		layer.add_child(fill)
		var line := Line2D.new()
		var closed := poly.duplicate()
		closed.append(poly[0])
		line.points = closed
		line.width = 3.0
		line.default_color = Color(0.35, 1.0, 0.5, 0.95)
		layer.add_child(line)

		## THE DECK PLANE ITSELF, along the same edge, because "the floor of
		## everything visible is the deck plane" is the single finding this whole
		## sweep produced and a wedge alone does not say it.
		var plane := Line2D.new()
		var pts := PackedVector2Array()
		for z in zs:
			pts.append(cam.unproject_position(Vector3(edge, 0.0, float(z)) * W))
		plane.points = pts
		plane.width = 2.0
		plane.default_color = Color(1.0, 0.85, 0.30, 0.9)
		layer.add_child(plane)

	var cap := Label.new()
	## The lines are joined with an ESCAPED newline. Typing one — a quote, the
	## Enter key, a quote — makes the literal CRLF in a CRLF file and LF in an
	## LF file, which is the trap `report · no script spells a newline by
	## pressing Enter inside a string` exists to catch, and it caught this file.
	cap.text = ("SG-176 — THE BAND THE CAMERA CAN SEE BEYOND THE DECK\n"
		+ "%s end, captain at the %s, zoom %.2f\n\n" % [end, spot, zoom]
		+ "GREEN WEDGE   where a piece put itself on the picture\n"
		+ "YELLOW LINE   the deck plane — nothing below it was ever seen\n\n"
		+ "measured, not drawn: %d probe cubes, two plates each,\n" % rows.size()
		+ "one freeze, the share of each probe's own rectangle that moved")
	cap.position = Vector2(28, 24)
	cap.add_theme_color_override("font_color", Color(1, 1, 1))
	cap.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	cap.add_theme_constant_override("outline_size", 8)
	layer.add_child(cap)

	await SkyGearStill.freeze(self, view, game)
	await _flush()
	await RenderingServer.frame_post_draw
	var path := "%s/band-%s-z%.2f.png" % [OUT_DIR, spot, zoom]
	root.get_texture().get_image().save_png(path)
	await SkyGearStill.thaw(self, view, game)
	layer.queue_free()
	print("  %s  (%d slices in the band)" % [path.replace("res://", ""), zs.size()])


## --- summary -------------------------------------------------------------------
func _summary() -> void:
	print("")
	print("THE ENVELOPE, in ground units — the band in which a probe READ")
	for tag in ["fore", "aft"]:
		for v in (FORE_VIEWS if tag == "fore" else AFT_VIEWS):
			var pose: Dictionary = v
			var spot := str(pose.spot)
			var zoom := float(pose.zoom)
			var ylo := 9999.0
			var yhi := -9999.0
			var zlo := 9999.0
			var zhi := -9999.0
			var xlo := 9999.0
			var xhi := -9999.0
			var n := 0
			for r in _rows:
				var row: Dictionary = r
				if str(row.end) != tag or str(row.spot) != spot: continue
				if absf(float(row.zoom) - zoom) > 0.01: continue
				if float(row.moved) < TRACE: continue
				n += 1
				ylo = minf(ylo, float(row.y)); yhi = maxf(yhi, float(row.y))
				zlo = minf(zlo, float(row.z)); zhi = maxf(zhi, float(row.z))
				xlo = minf(xlo, float(row.x)); xhi = maxf(xhi, float(row.x))
			## THE DISAGREEMENT, WHICH IS THE WHOLE REASON BOTH TESTS ARE TAKEN.
			## A probe the frustum calls IN FRAME and the pixels call absent is
			## behind something opaque or in a part of the picture nothing lights
			## — and that is exactly and only what killed both sterns. A tool that
			## measured the frustum alone would have said the stern was visible.
			var blind := 0
			var seen_in := 0
			for r in _rows:
				var row: Dictionary = r
				if str(row.end) != tag or str(row.spot) != spot: continue
				if absf(float(row.zoom) - zoom) > 0.01: continue
				var word := str(row.frustum)
				if word != "in" and word != "cropped": continue
				seen_in += 1
				if float(row.moved) < TRACE: blind += 1
			if n == 0:
				print("  %-4s %-8s z%.2f   NOTHING READ ANYWHERE   "
					% [tag, spot, zoom]
					+ "(%d of %d probes were IN FRAME and still put nothing on it)"
						% [blind, seen_in])
			else:
				print("  %-4s %-8s z%.2f   %d of %d probes were IN FRAME and still "
					% [tag, spot, zoom, blind, seen_in]
					+ "put nothing on it — occluded, or nothing lights them")
			if n == 0:
				pass
			else:
				print("  %-4s %-8s z%.2f   %3d probes   y %+5.0f..%+5.0f   z %+6.0f..%+6.0f   x %+5.0f..%+5.0f"
					% [tag, spot, zoom, n, ylo, yhi, zlo, zhi, xlo, xhi])


## --- boot and pose -------------------------------------------------------------
func _boot() -> void:
	var world = load("res://scenes/main3d.tscn").instantiate()
	root.add_child(world)
	await process_frame
	view = world
	game = world.get_node("SkyGear")
	## NO CUTSCENE — it hides the HUD, locks the controls and TAKES THE CAMERA, so
	## a tool that skips this photographs the opening reveal's camera instead of
	## the gameplay one (`edge_place.gd` found this; the note is there).
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
