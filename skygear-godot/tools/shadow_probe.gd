extends SceneTree
## ONE SHADOW AUTHORITY, UNDER ITS OWN KILL-TEST.
##
## DECK-IDENTITY item 2 pre-committed this before a line was written, and it
## pre-committed an outcome most features do not get offered:
##
##   *"renders the bench pose three ways: today's ellipse, the corrected pool,
##   and the batch switched off entirely. If OFF is not measurably worse than
##   today, THE BLOB LAYER IS DELETED and the moon does the whole job — that
##   outcome is allowed to win. If corrected differs from today by under 3% of
##   deck-region pixels at zoom 1.0, only the height falloff ships."*
##
## So this tool has to be able to lose the feature, and it is written to.
##
##   godot --path . --resolution 1600x900 --script tools/shadow_probe.gd -- <outdir>
##
## THREE PLATES, ONE PROCESS. `view.shadow_legacy` exists so the old behaviour is
## reachable at runtime, because DECK-IDENTITY §7.5 records the same build
## measuring 0.72% and 13.55% on consecutive runs of a two-process comparison —
## the braziers, the particle systems and the GPU's own clock do not arrive at
## the shutter in the same place twice. Everything below happens one frame apart
## with the simulation stopped, the flicker pinned and the particles hidden.
const DECK_BOX := Rect2i(240, 200, 1160, 620)
## A pixel has to move by this much before it counts as changed rather than as
## the renderer's own dither. In sRGB channel units, so 0.012 is about 3/255 —
## the usual "a person could see that" step.
##
## NOT in `ink.luminance`, which is LINEARISED: the deck's mean linear luminance
## is 0.030, so a 0.008 threshold there is a quarter of the whole signal and the
## first run of this tool duly reported a third of the deck moving when the batch
## was switched off. Sixteen blobs do not cover a third of a deck.
const MOVED := 0.012
## The item's own number.
const PIXEL_GATE := 3.0

var _out_dir := "../.shots/sg107"


func _init() -> void:
	await process_frame
	var argv := OS.get_cmdline_user_args()
	if argv.size() > 0:
		_out_dir = str(argv[0])
	var out_dir := "res://%s" % _out_dir
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))

	var win := get_root()
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	## AND TURN OFF THE DITHER. `rendering/anti_aliasing/quality/use_debanding` is
	## true in `project.godot`, and debanding is a per-frame RANDOM dither: it
	## moves a little of every pixel on every frame whether anything in the scene
	## changed or not. With it on, two identical plates differed across 53% of the
	## deck region — so the first three answers this tool gave were a measurement
	## of the dither pattern and nothing else. The noise floor below is printed
	## every run precisely so this can never be assumed again.
	win.use_debanding = false
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1600, 900))
	root.size = Vector2i(1600, 900)
	await process_frame

	var world: Node3D = load("res://scenes/main3d.tscn").instantiate()
	root.add_child(world)
	await process_frame
	var view: SkyGearView3D = world as SkyGearView3D
	var game: SkyGearGame = world.get_node("SkyGear")
	view.cutscenes_enabled = false
	view.stop_cutscene()
	game.log_runs = false
	if game.impact != null:
		game.impact.enabled = false
	game.workshop = SkyGearWorkshop.fresh(true)
	game.refresh_berthed()
	game.set_seed_text("SHADOW")
	game.begin_run()
	game.choose_draft(0)
	if game.wave != 8:
		game.start_wave(8)
	game.spawn_queue.clear()
	view.sway = false
	var overlay = game.get_node_or_null("HUD")
	if overlay != null:
		overlay.visible = false

	## THE BENCH POSE: a deck with people on it. A shadow item measured on an
	## empty deck measures nothing at all.
	game.player.global_position = Vector2(0.0, 240.0)
	game.player.velocity = Vector2.ZERO
	var kinds := ["SCRAPPER", "ARMORED", "SWARM", "GUNNER"]
	for i in 16:
		game.spawn_enemy(kinds[i % kinds.size()], 1)
	var live: Array = game.get_tree().get_nodes_in_group("enemies")
	for i in live.size():
		var col: int = i % 4
		var row: int = i / 4
		live[i].global_position = Vector2(-540.0 + float(col) * 360.0,
			-260.0 + float(row) * 300.0)
		live[i].state = "move"
	view._focus_set = false
	view._zoom = 1.0
	view._zoom_target = 1.0
	for _i in 30:
		game._process(1.0 / 60.0)
		await process_frame
	## AND WAIT FOR SOMETHING TO BE IN THE AIR. The height half of this item is
	## about projectiles, so a plate with no projectile in it cannot witness it.
	## The gunners in the pose above fire on their own clock; the loop stops on
	## the first frame that has ordnance in flight rather than at a fixed count,
	## because "run for four seconds and hope" is how a tool ends up photographing
	## an empty sky half the time.
	var waited := 0
	while game.projectiles.size() == 0 and waited < 900:
		game._process(1.0 / 60.0)
		await process_frame
		waited += 1
	print("  ordnance in flight at the shutter: %d (after %d frames)"
		% [game.projectiles.size(), waited])

	## AND STOP THE RENDERER'S OWN ACCUMULATORS. `view3d.gd:692` enables
	## `volumetric_fog_temporal_reprojection`, which blends each frame into the
	## last few with a per-frame offset — a scene that is completely frozen still
	## produces a different image every frame, and it does not settle. That is why
	## two identical plates differed across half the deck region, and why
	## AVERAGING EIGHT EXPOSURES MADE IT WORSE rather than better: the term is not
	## zero-mean noise, it is a drift.
	if view._environment != null:
		view._environment.volumetric_fog_temporal_reprojection_enabled = false
		view._environment.volumetric_fog_enabled = false
	await process_frame
	game.set_process(false)
	## AND FREEZE THE FIGURES THEMSELVES. `game.set_process(false)` holds the
	## simulation and `view.set_process(false)` holds the renderer, but every
	## rigged figure on this deck owns an `AnimationPlayer` that advances on the
	## engine's own clock and answers to neither. Seventeen boarders breathing
	## through a walk cycle move their limbs, their weapons and — the part that
	## matters here — their CAST SHADOWS, on every frame. That is the drift, and
	## it is why the noise floor sat near 77% no matter what was switched off.
	## `marks_shot.gd` never found this because it shot its two plates one frame
	## apart; it is the fourth confound in that family and the largest.
	Engine.time_scale = 0.0
	for node in view.find_children("*", "AnimationPlayer", true, false):
		(node as AnimationPlayer).speed_scale = 0.0
	view._flicker = 12.0
	for _i in 3:
		view._process(0.0)
		await process_frame
	for node in view.find_children("*", "GPUParticles3D", true, false):
		(node as GPUParticles3D).emitting = false
		(node as GPUParticles3D).visible = false
	await process_frame

	## Three plates. `_process(0.0)` re-flushes the batch without advancing one
	## tick of anything else — the whole point of a zero delta.
	view.shadow_legacy = true
	view._process(0.0)
	var today := await _plate(view, "%s/shadow-today.png" % out_dir)
	## THE RIG'S OWN NOISE FLOOR, MEASURED BEFORE ANY OF ITS ANSWERS ARE BELIEVED.
	## A second plate with NOTHING changed between them. If this is not near zero
	## then the renderer is not still — temporal antialiasing, a dithered
	## transparency, a particle system on the GPU's own clock — and every number
	## below it is that, not shadows. This tool's first two runs reported a third
	## and then seven eighths of the deck "moving" when the batch was switched
	## off, which sixteen blobs cannot do, and this line is how that was found.
	view._process(0.0)
	var control := await _plate(view, "%s/shadow-control.png" % out_dir)
	view.shadow_legacy = false
	view._process(0.0)
	var fixed := await _plate(view, "%s/shadow-corrected.png" % out_dir)
	view._shadow_batch.visible = false
	view._process(0.0)
	var off := await _plate(view, "%s/shadow-off.png" % out_dir)
	view._shadow_batch.visible = true

	var fixed_vs_today := _moved(today, fixed)
	var off_vs_today := _moved(today, off)
	var fixed_vs_off := _moved(off, fixed)

	print("")
	print("  ONE SHADOW AUTHORITY — THE PRE-COMMITTED KILL-TEST")
	print("  a wave-8 deck, sixteen boarders and the captain, zoom 1.00")
	print("  deck region %s" % str(DECK_BOX))
	print("  marks in the flush %d, of which contact cores %d — that many figures"
		% [view.multimesh_shadow_count(), view._shadow_cores_last])
	print("  on this deck the moon is already drawing for itself")
	print("")
	print("  NOISE FLOOR           %5.2f%% — two plates, nothing changed"
		% _moved(today, control))
	print("")
	print("  corrected vs today    %5.2f%% of deck pixels moved" % fixed_vs_today)
	print("  OFF vs today          %5.2f%% of deck pixels moved" % off_vs_today)
	print("  corrected vs OFF      %5.2f%% of deck pixels moved" % fixed_vs_off)
	print("")
	print("  mean deck luminance   today %.3f · corrected %.3f · off %.3f"
		% [_lum(today), _lum(fixed), _lum(off)])
	print("")

	## THE OUTCOMES, IN THE ORDER THE DESIGN PUT THEM — AND THE ONE THING THE
	## DESIGN DID NOT NOTICE ABOUT ITS OWN FIRST BRANCH.
	if off_vs_today < PIXEL_GATE:
		print("  THE DELETE GATE HAS FIRED, and it is reported rather than obeyed.")
		print("")
		print("  Switching the batch off moves %.2f%% of deck pixels against today,"
			% off_vs_today)
		print("  under the 3%% the item set. On a deck where every figure is now a")
		print("  MESH, the moon already draws them, and a 41-degree camera puts each")
		print("  figure in front of most of its own blob — so the sticker really is")
		print("  nearly invisible under a boarder. That half of the finding is real")
		print("  and it is why the mesh figures here drop to contact cores.")
		print("")
		print("  BUT THE GATE CONTRADICTS §13c, WHICH THE SAME DOCUMENT CALLS")
		print("  NON-NEGOTIABLE. 'Delete the blob layer and let the moon do the")
		print("  whole job' cannot be right for the two cases the moon CANNOT do:")
		print("    · a projectile's mark, which must sit directly under the bolt")
		print("      because it is what tells you where it will cross you — the")
		print("      moon's shadow of a bolt lands 0.44 of its height to port,")
		print("      which is an answer to a question nobody asked;")
		print("    · a painted BILLBOARD, which casts nothing at all, so its blob")
		print("      is the only thing holding it to the planking.")
		print("")
		print("  This measurement is over FIGURES. It is not evidence about either")
		print("  of those, and the layer is not deleted on it. The owner's call,")
		print("  with these numbers, is in NEEDS_ALEX.")
		print("")
		quit(4)
		return
	if fixed_vs_today < PIXEL_GATE:
		print("  NOTE: corrected differs from today by %.2f%%, under the item's 3%%."
			% fixed_vs_today)
		print("  The item says only the height falloff ships in that case. Recorded.")
		quit(5)
		return
	print("  VERDICT: THE AUTHORITY SHIPS WHOLE. The blob layer is doing real work")
	print("           (%.2f%% of deck pixels against OFF) and the correction is" % fixed_vs_off)
	print("           visible against today at %.2f%%." % fixed_vs_today)
	print("")
	quit(0)


## A PLATE IS AN AVERAGE OF `PLATE_FRAMES` EXPOSURES, not one.
##
## With the simulation stopped, the renderer stopped, the flicker pinned and the
## particles hidden, two consecutive readbacks of the SAME scene still differed
## across half the deck region. Turning off debanding did not fix it, so whatever
## the stochastic term is — the volumetric fog's temporal reprojection is the
## likeliest — it is not a switch this tool is going to find. It does not have
## to: the scene is genuinely frozen, so the variation is zero-mean, and eight
## exposures averaged put the noise floor where a real measurement can be read
## against it. The floor is printed every run rather than assumed, which is the
## only reason any of the numbers below can be trusted.
##
## Sampled over the deck region only, at `STEP`, because the alternative is
## fourteen million `get_pixel` calls a plate.
const PLATE_FRAMES := 8
const STEP := 2


func _plate(view: SkyGearView3D, path: String) -> PackedFloat32Array:
	var w: int = (DECK_BOX.size.x + STEP - 1) / STEP
	var h: int = (DECK_BOX.size.y + STEP - 1) / STEP
	var acc := PackedFloat32Array()
	acc.resize(w * h * 3)
	for f in PLATE_FRAMES:
		await process_frame
		await process_frame
		var img := root.get_texture().get_image()
		if f == 0:
			img.save_png(path)
		var i := 0
		var gy := 0
		while gy < h:
			var gx := 0
			while gx < w:
				var c := img.get_pixel(DECK_BOX.position.x + gx * STEP,
					DECK_BOX.position.y + gy * STEP)
				acc[i] += c.r
				acc[i + 1] += c.g
				acc[i + 2] += c.b
				i += 3
				gx += 1
			gy += 1
	for i in acc.size():
		acc[i] /= float(PLATE_FRAMES)
	return acc


## What fraction of the deck region actually changed. Pixels, not opinions.
func _moved(a: PackedFloat32Array, b: PackedFloat32Array) -> float:
	var moved := 0
	var total := 0
	var i := 0
	while i < a.size():
		total += 1
		if maxf(absf(a[i] - b[i]), maxf(absf(a[i + 1] - b[i + 1]),
				absf(a[i + 2] - b[i + 2]))) >= MOVED:
			moved += 1
		i += 3
	return 0.0 if total == 0 else 100.0 * float(moved) / float(total)


func _lum(a: PackedFloat32Array) -> float:
	var sum := 0.0
	var n := 0
	var i := 0
	while i < a.size():
		sum += SkyGearInk.luminance(Color(a[i], a[i + 1], a[i + 2]))
		n += 1
		i += 3
	return 0.0 if n == 0 else sum / float(n)
