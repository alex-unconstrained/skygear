extends SceneTree

## THE DECK LATE IN A RUN, AND WHETHER YOU CAN STILL READ A TELEGRAPH ON IT.
##
## DECK-IDENTITY-DESIGN §7.5 pre-committed two kill-tests for accumulating deck
## marks, and both of them need the same thing the harness cannot give: a REAL
## FRAME of a heavily-marked deck. This is the rig that produces it.
##
##   godot --path . --resolution 1600x900 --script tools/marks_shot.gd
##   godot --path . --resolution 1600x900 --script tools/marks_shot.gd -- clean
##
## NOT `--headless` — the whole output is a PNG and headless makes them empty.
## `clean` renders the identical poses with the marks switched off, which is the
## A/B half; run both and the two sets are directly comparable pixel for pixel
## because every camera here is snapped, not eased, and the sway is off.
##
## Shots land in `.shots/marks/`. Also prints the coverage arithmetic §7.1 claims
## — what fraction of the deck rectangle the mark set actually paints — because
## "under 14% at full cap" is a number somebody should be able to check rather
## than believe.
##
## HOW THE DECK IS MARKED. Not randomly: a wave-12 deck is a record of where the
## fighting was, so the marks are laid down the three lanes with the density a
## twelve-wave run actually produces — heaviest in the centre lane where the
## boarders come, a scorch at each of the two forward crossings where kegs go
## off, and a scald aft where a Boilerwright works. The point of the picture is
## the worst honest case, not the prettiest one.

const POSES := [
	{"spot": "mid", "zoom": 1.0, "why": "the shipped composition — the 94% that is planking"},
	{"spot": "mid", "zoom": 1.55, "why": "and pulled back, where the marks are smallest"},
	{"spot": "port", "zoom": 1.0, "why": "in the port lane, 280 units off her own rail"},
	{"spot": "bow", "zoom": 1.0, "why": "forward, where the drawn bow is"},
]
## `telegraph_shot.gd`'s four, copied rather than re-chosen: a legibility
## judgement made against different poses than the tool everyone else uses is
## not comparable to anything.
const TELEGRAPHS := [
	{"kind": "SCRAPPER", "at": Vector2(-150.0, 470.0)},
	{"kind": "ARMORED", "at": Vector2(150.0, 470.0)},
	{"kind": "SWARM", "at": Vector2(-360.0, 560.0)},
	{"kind": "GUNNER", "at": Vector2(360.0, 300.0)},
]
const TELEGRAPH_FRAC := 0.55
const SPOTS := {
	"mid": Vector2(0.50, 0.50),
	"port": Vector2(0.08, 0.46),
	"bow": Vector2(0.50, 0.16),
}


func _init() -> void:
	await process_frame
	var argv := OS.get_cmdline_user_args()
	var clean := argv.size() > 0 and str(argv[0]) == "clean"

	var win := get_root()
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var out_dir := "res://../.shots/marks"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))

	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1600, 900))
	root.size = Vector2i(1600, 900)
	await process_frame

	var world: Node3D = load("res://scenes/main3d.tscn").instantiate()
	root.add_child(world)
	await process_frame
	var view: SkyGearView3D = world as SkyGearView3D
	var game: SkyGearGame = world.get_node("SkyGear")
	## FIRST, before a run is opened. `begin_run` owes an establishing crane and
	## a boss wave owes an intro; either of them poses the camera and waits, and
	## the first run of this tool sat on a "CLICK TO SKIP" until it was killed.
	view.cutscenes_enabled = false
	view.stop_cutscene()
	## AND THIS TOOL DOES NOT WRITE TO THE PLAYER'S RUN LOG. It opens a real run
	## on a real game to get a real deck, and the first version of it left rows in
	## `user://runs.json` — which the harness reads, and which promptly failed two
	## `log ·` checks that had nothing to do with any of this. A tool that changes
	## what the harness measures is a tool that has broken the harness.
	game.log_runs = false
	if game.impact != null:
		game.impact.enabled = false
	game.workshop = SkyGearWorkshop.fresh(true)
	game.refresh_berthed()
	game.set_seed_text("MARKS")
	game.begin_run()
	## `choose_draft` on the opening draft already starts wave one; calling
	## `start_wave` unconditionally after it begins the wave twice (sky_shot.gd
	## carries the same note and the same scar).
	game.choose_draft(0)
	## ELEVEN, not twelve. Twelve is the boss and the boss owes an intro pose;
	## the deck's mark load at the end of eleven is the same picture without a
	## camera argument in it.
	if game.wave != 11:
		game.start_wave(11)
	game.spawn_queue.clear()
	view.sway = false
	## The HUD is off: this photographs the DECK, and a wave banner across the
	## middle is the reason the first pass at these shots could not be read.
	var overlay = game.get_node_or_null("HUD")
	if overlay != null:
		overlay.visible = false
	for _i in 20:
		game._process(1.0 / 60.0)
		await process_frame

	var painted := 0.0
	if not clean:
		painted = _mark_the_deck(view)
	for _i in 4:
		game._process(1.0 / 60.0)
		await process_frame

	var rect: Rect2 = SkyGearGame.DECK_RECT
	print("")
	print("  a wave-12 deck, marked")
	print("    live marks       %d  (cap %d)" % [view.mark_count(),
		SkyGearView3D.MARK_CAP])
	print("    painted area     %.0f of %.0f deck units squared" % [painted,
		rect.size.x * rect.size.y])
	print("    coverage         %.1f%%   (DECK-IDENTITY §7.1 claims under 14%%)"
		% (100.0 * painted / (rect.size.x * rect.size.y)))
	print("    loudest mark     %.3f   (ceiling %.2f)" % [_loudest(view),
		SkyGearView3D.MARK_ALPHA_MAX])
	print("")

	for pose in POSES:
		var spot: Vector2 = SPOTS[str(pose.spot)]
		var at := Vector2(rect.position.x + rect.size.x * spot.x,
			rect.position.y + rect.size.y * spot.y)
		if game.state == SkyGearGame.State.DRAFT:
			game.choose_draft(0)
		if game.wave != 11:
			game.start_wave(11)
		game.spawn_queue.clear()
		game.player.global_position = at
		game.player.velocity = Vector2.ZERO
		## Snap rather than ease: the follow has a 0.155 s time constant, so a
		## tool that stepped frames would photograph the tail of a lerp.
		view._focus_set = false
		view._zoom = float(pose.zoom)
		view._zoom_target = float(pose.zoom)
		for _i in 4:
			game._process(1.0 / 60.0)
			await process_frame
		## The lens must not have moved. `sky_shot.gd`'s guard, copied, because a
		## legibility judgement made through a camera nobody checked is not a
		## judgement.
		var pitch := rad_to_deg(view.camera.rotation.x)
		if absf(pitch + rad_to_deg(SkyGearView3D.PITCH)) > 0.5:
			push_error("the camera moved: pitch %.2f" % pitch)
			quit(1)
			return
		var tag := "clean" if clean else "marked"
		var path := "%s/%s-%s-z%.2f.png" % [out_dir, tag, str(pose.spot),
			float(pose.zoom)]
		root.get_texture().get_image().save_png(path)
		print("  %-22s %s" % [str(pose.spot) + " z" + str(pose.zoom), str(pose.why)])

	## AND THE ONE THAT DECIDES IT. DECK-IDENTITY §7.5 kill-test 1: four boarders
	## frozen mid-windup over the marked deck, at `telegraph_shot.gd`'s own poses
	## and its own 0.55 windup fraction, so the runes here and the runes there are
	## the same runes. Run `clean` as well and the pair is a contrast measurement
	## rather than an opinion — the marks are the only thing that differs.
	if game.state == SkyGearGame.State.DRAFT:
		game.choose_draft(0)
	game.player.global_position = Vector2(0.0, 200.0)
	view._focus_set = false
	view._zoom = 1.0
	view._zoom_target = 1.0
	for t in TELEGRAPHS:
		game.spawn_enemy(str(t.kind), 1)
	var live: Array = game.get_tree().get_nodes_in_group("enemies")
	for i in mini(live.size(), TELEGRAPHS.size()):
		live[i].global_position = TELEGRAPHS[i].at
		live[i].state = "move"
	for _i in 6:
		game._process(1.0 / 60.0)
		await process_frame
	game.effects.clear()
	for i in mini(live.size(), TELEGRAPHS.size()):
		var e = live[i]
		var to_cap: Vector2 = game.player.global_position - e.global_position
		e.state = "windup"
		e.attack_direction = to_cap.normalized() if to_cap.length() > 0.001 			else Vector2.DOWN
		e.state_time = float(e.config.windup) * TELEGRAPH_FRAC
	game.set_process(false)
	## PIN THE FLICKER. `_flicker` advances on real frames, so the marked run and
	## the clean run reach the shutter with the braziers, the lantern and the vent
	## at different points in their cycles — and the first attempt at this
	## measurement reported the contrast getting WORSE when the marks got
	## fainter, which is the lighting phase talking and not the marks. Pinned, the
	## two plates differ in exactly one thing.
	view._flicker = 12.0
	for _i in 3:
		view._process(0.0)
		await process_frame
	## AND THEN STOP THE RENDERER TOO. `game.set_process(false)` above holds the
	## simulation, but `view._process` keeps advancing `_flicker`, and the two
	## plates below are two frames apart: the brass gunwale measurably brightened
	## between them and turned up in the contrast figures as if the marks had done
	## it. From here nothing moves and the mark layer is the only difference.
	view.set_process(false)
	## AND THE PARTICLES. `GPUParticles3D` runs on the GPU's own clock and does
	## not care that the tree stopped processing — embers and steam kept moving
	## between the two plates and turned up in the contrast figures as marks. They
	## are hidden for the measurement only; the poses above still have them.
	for node in view.find_children("*", "GPUParticles3D", true, false):
		(node as GPUParticles3D).emitting = false
		(node as GPUParticles3D).visible = false
	await process_frame
	await process_frame
	## BOTH PLATES FROM ONE RUN, one frame apart, with the simulation stopped and
	## the lighting phase pinned — the marks batch simply hidden between them.
	##
	## Two separate processes could not do this: sparks, embers and the vent
	## plumes are GPU particle systems with their own clocks, and across two runs
	## they land differently. Measured that way the same build reported the
	## contrast cost as 0.7% and as 6.6% on consecutive attempts, which is a
	## measurement of the weather. One process, one frame apart, and the mark
	## layer is the only thing that differs.
	root.get_texture().get_image().save_png("%s/marked-telegraphs.png" % out_dir)
	view._mark_batch.visible = false
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png("%s/clean-telegraphs.png" % out_dir)
	view._mark_batch.visible = true
	print("  telegraphs            four windups, marked and clean, one frame apart")

	print("")
	print("  %d shot(s) in .shots/marks/. Look at them." % (POSES.size() + 1))
	quit(0)


## A twelve-wave deck's worth of evidence, laid where the fighting is rather than
## scattered. Returns the painted area in square deck units.
func _mark_the_deck(view: SkyGearView3D) -> float:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12
	var painted := 0.0
	## Bodies down the lanes — the centre lane heaviest, because that is where
	## they walk. 90 kills is a full twelve waves.
	for i in 90:
		var lane: float = SkyGearGame.LANE_CENTERS[
			[1, 1, 1, 0, 2][i % 5]]
		var at := Vector2(lane + rng.randf_range(-120.0, 120.0),
			rng.randf_range(-1000.0, 900.0))
		var kind: int = SkyGearView3D.MarkKind.OIL if i % 7 == 0 \
			else SkyGearView3D.MarkKind.BLOOD
		if view.mark_count() < SkyGearView3D.MARK_CAP:
			painted += _area(view, kind)
		view._mark(kind, at, rng.randf_range(0.8, 1.3))
		view._age_marks(0.55)
	## Kegs, at the forward crossings.
	for i in 8:
		var at2 := Vector2(rng.randf_range(-620.0, 620.0),
			rng.randf_range(-900.0, -200.0))
		if view.mark_count() < SkyGearView3D.MARK_CAP:
			painted += _area(view, SkyGearView3D.MarkKind.SCORCH)
		view._mark(SkyGearView3D.MarkKind.SCORCH, at2, 1.3)
		view._age_marks(1.4)
	## And a Boilerwright's cracked mains aft.
	for i in 4:
		var at3 := Vector2(rng.randf_range(-500.0, 500.0),
			rng.randf_range(500.0, 1000.0))
		if view.mark_count() < SkyGearView3D.MARK_CAP:
			painted += _area(view, SkyGearView3D.MarkKind.SCALD)
		view._mark(SkyGearView3D.MarkKind.SCALD, at3, 1.0)
		view._age_marks(1.1)
	view._flush_marks()
	return painted


func _area(view: SkyGearView3D, kind: int) -> float:
	var look: Dictionary = SkyGearView3D.MARK_LOOK[kind]
	var r: float = float(look.width) * 0.5
	return PI * r * r * 0.78


func _loudest(view: SkyGearView3D) -> float:
	var m := 0.0
	for i in SkyGearView3D.MARK_CAP:
		m = maxf(m, view._mark_alpha(i))
	return m
