extends SceneTree
## DOES THE RUNE MASK SELECT RUNES? The SG-116 check, in the only place it can
## honestly be run.
##
##   godot --path . --resolution 1600x900 --script tools/rune_probe.gd
##
## NOT `--headless`: the whole check is a framebuffer readback and headless has
## no GPU (SG-29). It is registered in the hub as a WINDOWED check so `all` picks
## it up, the same way `still` is.
##
##
## WHY THIS EXISTS
##
## `tools/rune_read.gd` decides two shipped questions — what the shadow rigging
## costs a telegraph's legibility (SG-107 item 1) and what the deck marks cost it
## (SG-101) — and both are measured against the same 3% relative gate. Until
## SG-116 it found the rune by COLOUR: any pixel with `s >= 0.55, v >= 0.42` and
## hue within 0.11 of red.
##
## **That test had no frame on which it was required to select nothing, so
## nothing about it could ever fail.** It is the fifth recurring failure mode in
## STATUS.md — a measuring rig nobody measured — in its purest form: not a rig
## that moved when it should have been still, but a rig whose output nobody ever
## checked against a case with a known answer. On the wave-6 pose it returned
## 26,095 pixels and a large share of them were brazier fire and an ARMORED
## boarder's lit plating.
##
## THE FRAME WITH A KNOWN ANSWER IS THE POINT OF THIS TOOL. Pose the deck with
## the braziers lit, the vents glowing and four boarders standing on it — every
## warm thing this deck owns — and put NO enemy into a windup. There is no
## telegraph in that frame. A mask that selects a telegraph must return EXACTLY
## ZERO pixels on it.
##
##   rune · a lit brazier with no telegraph up selects zero pixels
##
## **The old mask fails that check and this tool proves it does**, by running the
## retired colour window on the same plate and printing what it finds. A check
## that passes both before and after a fix is not evidence of a fix, so the
## before-number is measured here rather than remembered.
##
## Zero, not "few" — the same reasoning `still_probe.gd` records about its own
## floor. A mask allowed to pick up 500 stray pixels of fire is a mask that can
## hide a 500-pixel rune, and the whole history of DECK-IDENTITY §7.5 is answers
## that turned out to be the instrument.
const DECK_BOX := Rect2i(240, 200, 1160, 620)
const FRAME_BOX := Rect2i(0, 0, 1600, 900)

## The four kinds, so the ARMORED boarder's lit plating is in frame for the
## no-telegraph pose. Its omni is `ff7a30` in `assets/models/lights.json`, which
## the retired colour window could not tell from a rune and this one need not.
const KINDS := ["SCRAPPER", "ARMORED", "SWARM", "GUNNER"]
const TELEGRAPHS := [
	{"kind": "SCRAPPER", "at": Vector2(-150.0, 470.0)},
	{"kind": "ARMORED", "at": Vector2(150.0, 470.0)},
	{"kind": "SWARM", "at": Vector2(-360.0, 560.0)},
	{"kind": "GUNNER", "at": Vector2(360.0, 300.0)},
]
const TELEGRAPH_FRAC := 0.55

var _out_dir := "../.shots/rune"
var _failures := 0


func _init() -> void:
	await process_frame
	var argv := OS.get_cmdline_user_args()
	if argv.size() > 0:
		_out_dir = str(argv[0])
	var out_dir := "res://%s" % _out_dir
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))

	var win := get_root()
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
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
	game.set_seed_text("RUNE")
	game.begin_run()
	game.choose_draft(0)
	if game.wave != 6:
		game.start_wave(6)
	game.spawn_queue.clear()
	view.sway = false
	var overlay = game.get_node_or_null("HUD")
	if overlay != null:
		overlay.visible = false

	## The shipped composition rig_probe measures at: amidships, zoom 1.0.
	game.player.global_position = Vector2(0.0, 200.0)
	game.player.velocity = Vector2.ZERO
	view._focus_set = false
	view._zoom = 1.0
	view._zoom_target = 1.0
	for t in TELEGRAPHS:
		game.spawn_enemy(str(t.kind), 1)
	var live: Array = game.get_tree().get_nodes_in_group("enemies")
	for i in mini(live.size(), TELEGRAPHS.size()):
		live[i].global_position = TELEGRAPHS[i].at
		live[i].state = "move"
	for _i in 26:
		game._process(1.0 / 60.0)
		await process_frame

	## HOLDING THEM OUT OF WINDUP, WHICH TAKES MORE THAN SETTING THE STATE. These
	## four are posed within reach of the captain, so the AI walks them straight
	## into an attack: the first version of this settled for 26 frames and arrived
	## at the "quiet" plate with TWO telegraph decals already up. The mask found
	## them, correctly, and the check failed — on the pose, not on the instrument.
	##
	## Putting the state back after each `game._process` was not enough either,
	## and the reason is worth writing down: a boarder runs its OWN `_process`, so
	## it re-entered `windup` during the `await` — after the fix-up, before the
	## view synced. The figure itself is stopped instead. It stays lit, rigged and
	## in frame, which is the whole point of posing it here; it simply no longer
	## decides to attack between two of this tool's frames.
	_hold_still(live)
	## And then the view is allowed to catch up with nothing running under it, so
	## `_sync_effects` reaps the decals of any windup entered on the last step: a
	## decal is shelved by the first frame that does not re-use its key.
	for _i in 3:
		await process_frame

	print("")
	print("  DOES THE RUNE MASK SELECT RUNES?")
	print("  the wave-6 pose rig_probe.gd measures at, amidships, zoom 1.00")
	print("")

	## THE NOISE FLOOR FIRST, because a tool that reports a difference must first
	## report its own, and it must be exactly zero (STATUS.md failure mode 5).
	## Measured through the same door this tool's real pairs go through: the mask
	## is a diff of two plates taken either side of a `visible` toggle, so the
	## control is two plates taken either side of nothing.
	var stopped := await SkyGearStill.freeze(self, view, game)
	print("  stopped: %d AnimationPlayers · %d GPUParticles3D · debanding · fog reprojection"
		% [int(stopped.animation_players), int(stopped.particles)])
	var noise := await SkyGearStill.floor_pct(self, FRAME_BOX)
	_say("still · two plates of a frozen scene differ by exactly zero", noise == 0.0,
		"%.2f%%" % noise)
	if noise != 0.0:
		push_error("the scene is not still (%.2f%%) — nothing here to measure" % noise)
		quit(9)
		return

	## ------------------------------------------------------------------
	## 1. THE FRAME WITH A KNOWN ANSWER: every warm thing lit, no telegraph.
	## ------------------------------------------------------------------
	var quiet := await SkyGearRune.mask_of(view,
		func(which: String) -> Image:
			return await _plate("%s/quiet-%s.png" % [_out_dir, which]))
	var quiet_pixels: int = int(quiet.mask.size() / 2)
	var quiet_fire := _colour_window(quiet.plate)

	print("")
	print("  A DECK WITH ITS BRAZIERS LIT AND NOTHING IN WINDUP")
	print("    telegraph decals in frame       %d" % int(quiet.decals))
	print("    pixels the mask selects         %d" % quiet_pixels)
	print("    pixels the RETIRED colour window selects  %d" % quiet_fire)

	## IS THE CONTROL ACTUALLY A CONTROL? Asked first and separately, because a
	## zero from a frame that quietly had a telegraph in it after all would be the
	## wrong answer arrived at for the wrong reason — and a zero from a frame with
	## a telegraph in it is not even possible, so a silent failure here would show
	## up as the NEXT check failing and send the reader after the mask. This is
	## the same reason `rig_probe.gd` prints how much of the ring the lattice
	## darkens: a gate that never met the thing it threatened proves nothing.
	_say("rune · and the frame that answer is measured on really has no telegraph in it",
		int(quiet.decals) == 0, "%d telegraph decals in frame" % int(quiet.decals))

	_say("rune · a lit brazier with no telegraph up selects zero pixels",
		quiet_pixels == 0, "%d pixels" % quiet_pixels)

	## AND THE CHECK ABOVE DISCRIMINATES. If the retired window found nothing here
	## either, then passing it would prove nothing about the fix — the pose would
	## simply have no fire in it. This is the line that makes the zero mean
	## something, and it is why the before-number is measured rather than quoted.
	_say("rune · and the colour window it replaced selects thousands on that very frame",
		quiet_fire >= 1000, "%d pixels of fire and lit plating" % quiet_fire)

	## ------------------------------------------------------------------
	## 2. AND IT STILL FINDS A REAL TELEGRAPH. A mask that selects nothing on
	##    every frame would pass check 1 and be useless.
	## ------------------------------------------------------------------
	await SkyGearStill.thaw(self, view, game)
	for i in mini(live.size(), TELEGRAPHS.size()):
		var e = live[i]
		if not is_instance_valid(e):
			continue
		var to_cap: Vector2 = game.player.global_position - e.global_position
		e.state = "windup"
		e.attack_direction = to_cap.normalized() if to_cap.length() > 0.001 \
			else Vector2.DOWN
		e.state_time = float(e.config.windup) * TELEGRAPH_FRAC
	for _i in 2:
		game._process(1.0 / 60.0)
		await process_frame
	await SkyGearStill.freeze(self, view, game)

	var up := await SkyGearRune.mask_of(view,
		func(which: String) -> Image:
			return await _plate("%s/windup-%s.png" % [_out_dir, which]))
	var up_pixels: int = int(up.mask.size() / 2)
	var up_fire := _colour_window(up.plate)
	## The same colour window run on the plate with EVERY TELEGRAPH HIDDEN. What
	## it still finds there was never telegraph — it is the contamination, named
	## and counted rather than asserted.
	var residue := _colour_window(up.dark)

	print("")
	print("  THE SAME DECK WITH FOUR WINDUPS UP")
	print("    telegraph decals hidden to find them     %d" % int(up.decals))
	print("    pixels the mask selects                  %d" % up_pixels)
	print("    pixels the RETIRED colour window selects  %d" % up_fire)
	print("    of those, still there with EVERY telegraph hidden  %d" % residue)
	if up_fire > 0:
		print("      -> %.0f%% of what the old mask called rune was not rune"
			% (100.0 * float(residue) / float(up_fire)))

	SkyGearRune.save_mask(up.mask, up.plate.get_width(), up.plate.get_height(),
		"%s/windup-mask.png" % _out_dir)

	_say("rune · four windups up, the mask finds the decals the renderer drew",
		int(up.decals) > 0 and up_pixels >= 200,
		"%d decals, %d pixels" % [int(up.decals), up_pixels])

	_say("rune · the fire the old mask counted is still in frame with every telegraph hidden",
		residue >= 1000, "%d pixels that were never telegraph" % residue)

	## ------------------------------------------------------------------
	## 3. AND THE MASK IS THE SAME MASK TWICE. `rune_read.gd`'s second recorded
	##    scar is two independently-derived masks being compared to each other;
	##    this asserts the derivation itself is not a source of difference.
	## ------------------------------------------------------------------
	var again := await SkyGearRune.mask_of(view,
		func(which: String) -> Image:
			return await _plate("%s/again-%s.png" % [_out_dir, which]))
	var identical: bool = again.mask == up.mask
	print("")
	print("    derived a second time                    %d pixels"
		% int(again.mask.size() / 2))
	_say("rune · deriving it twice on a frozen scene gives the identical pixel set",
		identical, "identical" if identical
			else "%d vs %d pixels" % [up_pixels, int(again.mask.size() / 2)])

	print("")
	print("  %d plate(s) in .shots/rune/. Look at the -notele ones: they are the"
		% 8)
	print("  same frame with every telegraph gone, and everything still glowing")
	print("  in them is what the old mask was measuring.")
	print("")
	if _failures == 0:
		print("  ALL CHECKS PASSED. The mask reads the decal's own pixels.")
	else:
		print("  %d CHECK(S) FAILED." % _failures)
	print("")
	quit(_failures)


## THE RETIRED COLOUR WINDOW, KEPT ONLY AS THE THING UNDER TEST.
##
## RUNE: COLOUR WINDOW IS THE THING UNDER TEST — this is not a way to measure a
## rune and no tool may call it to measure one. It is here so this probe can show
## what the old mask did on a frame where the right answer is known, because a
## check that passes both before and after a fix is not evidence of a fix. The
## harness check `rune · nothing derives a rune from a colour window but the
## probe that exists to fail it` is what keeps this copy from spreading.
const OLD_SAT := 0.55
const OLD_VAL := 0.42
const OLD_HUE := 0.11


func _colour_window(img: Image) -> int:
	var n := 0
	var w := img.get_width()
	var h := img.get_height()
	var y := 0
	while y < h:
		var x := 0
		while x < w:
			var c := img.get_pixel(x, y)
			if c.s >= OLD_SAT and c.v >= OLD_VAL \
					and (c.h <= OLD_HUE or c.h >= 1.0 - OLD_HUE):
				n += 1
			x += SkyGearRune.STEP
		y += SkyGearRune.STEP
	return n


## `frame_post_draw`, not `process_frame` — SG-29's idiom, and SG-108's reason:
## `process_frame` fires when the TREE finished its frame, not when the RENDERER
## finished drawing it, and the resulting bad readback is INTERMITTENT.
func _plate(path: String) -> Image:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png(path)
	return img


## Put every boarder back on its feet and take its clock away. The AI re-enters
## `windup` the moment one is in reach of the captain, which is exactly the pose
## this tool needs them in and exactly the state it needs them out of.
func _hold_still(live: Array) -> void:
	for e in live:
		if not is_instance_valid(e):
			continue
		e.set_process(false)
		e.set_physics_process(false)
		e.state = "move"
		e.state_time = 0.0
	## They are NOT given back afterwards, and that is deliberate: the windup pose
	## below sets `state` by hand and wants it to stay set. A boarder still
	## running its own clock would walk out of the windup this tool just put it
	## in, which is `rig_probe.gd`'s first recorded scar wearing a different hat.


func _say(name: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("    %s  %s   %s" % ["ok  " if ok else "FAIL", name, detail])
