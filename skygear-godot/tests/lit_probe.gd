extends SceneTree
## DOES THE BOARDER READ AGAINST THE DECK HE STANDS ON? The SG-86 check.
##
##   godot --path . --resolution 1600x900 --script tests/lit_probe.gd
##
## NOT `--headless`: the whole check is a framebuffer readback and headless has
## no GPU (SG-29).
##
## IT LIVES IN `tests/` AND NOT IN `tools/`, WHICH IS NOT WHERE IT BELONGS. It
## is a windowed probe exactly like `still_probe.gd` and `rune_probe.gd` and it
## should sit beside them and be registered in `tools/hub.gd` so `all` picks it
## up. It is here because `tools/` was being edited by another agent on the
## night it was written and a second writer in that directory is how two hours
## of work gets lost. Moving it is a rename and one hub row; see the SG-86 row.
##
##
## WHY THIS EXISTS
##
## SG-86 measured the furnace knight's mesh against his painting and published
## three numbers: mean luminance 34.1 against 45.4, peak 161 against 192, and
## 149 hot-orange pixels against 636. Those numbers were taken off frame 20 of
## `tools/clip.gd -- knight`, over the crop `Rect2i(690, 60, 210, 280)`, and
## both of those facts are recoverable from `.shots/clips/knight-vs-sprite-mid.png`
## by template match — the panels are 2x upscales of that rect.
##
## **`clip.gd` cannot measure this, and it says so itself.** Its second line is
## `## STILL: NOT APPLICABLE — this tool photographs MOTION on purpose (SG-108)`.
## It is exempt from the freeze, so its animation and particle phase land
## wherever the frame pacing puts them. Shooting the SAME BUILD twice and
## measuring the SAME crop of the SAME frame index gives:
##
##     mean 33.34 / peak 229.8 / hot 575
##     mean 32.86 / peak 211.6 / hot 409
##
## Mean is worth about half a point. Peak is worth eight percent. **The
## hot-orange count is worth forty.** So SG-86's 149-against-636 is not a
## measurement of the knight, it is a measurement of which frame the embers
## happened to be on, and any fix judged against it would be judged against
## noise. That is STATUS.md's fifth recurring failure mode — a measuring rig
## nobody measured — and it is why this tool freezes before it reads.
##
##
## AND IT MEASURES THE KNIGHT, NOT THE WEATHER AROUND HIM
##
## The published crop is 210x280 of deck with a boarder standing in it, so most
## of its pixels are planking. A change that washes the whole deck raises that
## mean without making the boarder one bit easier to see — and raising it is
## precisely what a careless rim light does. SG-116 is the same lesson in the
## next room: the retired rune mask counted an ARMORED boarder's lit plating as
## telegraph because a colour window cannot tell a figure from the fire near it.
##
## So the figure is separated the way SG-116 separates a decal — by hiding it
## and diffing the two plates. What changed when the rig went away is the
## boarder. Everything else in the crop is the control, and both are reported,
## because the only honest form of "he got brighter" is one that also says what
## the deck did.
const CROP := Rect2i(690, 60, 210, 280)
const FRAME_BOX := Rect2i(0, 0, 1600, 900)

## The `knight` scenario's own three lanes, so this reads the composition SG-86
## photographed rather than a pose invented for the tool.
const LANES := [Vector2(-280.0, 210.0), Vector2(-10.0, 60.0), Vector2(250.0, 170.0)]
const SETTLE := 90
## Where every clip is parked before the plates are taken. Any fixed time does;
## 0.40s is inside the shortest walk cycle on this rig and is far enough from
## zero that the pose is a stride rather than a bind.
const POSE_T := 0.40

## THE PAINTING, over the same crop of the same frame of the pre-mesh build.
## Measured, not remembered: `.shots/clips/knight-before/frame_0020.png` gives
## 45.37 / 191.5 / 638 against the row's published 45.4 / 192 / 636.
const PAINTING_MEAN := 45.37
const PAINTING_DECK := 55.03

## AND THE THIRD PUBLISHED NUMBER — WHICH SG-131 HAD TO THROW AWAY.
##
## SG-86's row is `149 hot-orange pixels against 636`, over a window of
## saturation >= 0.50, value >= 0.58, hue within 0.15 of red. That window
## reproduces the painting's 638 off `.shots/clips/knight-before/frame_0020.png`
## exactly, so it is faithfully recorded. **It is still the wrong instrument for
## a furnace grille, and painting the window onto the sprite shows it in one
## look:** it lights up the chest furnace AND the visor AND every brass rivet,
## every polished trim edge, and the haft of the axe. Roughly half of the 638 is
## trim. It is a warm-saturated-highlight detector, not a grille detector, and
## SG-116's lesson — a colour window cannot tell a figure from the fire near it
## — applies to it in a second form: it cannot tell a furnace from the brass
## around the furnace.
##
## **AND SG-86'S CROP CANNOT SEE THIS KNIGHT'S CHEST.** `Rect2i(690, 60, 210,
## 280)` was chosen for the composition of frame 20 of `clip.gd -- knight`,
## where it lands on one sprite knight facing the camera and filling the frame.
## This tool poses its own three lanes, and in THAT composition the same rect
## holds a mast, a barrel, a crate, and one knight's shoulder in the bottom
## corner, seen from behind. The comment above already refuses to gate the crop
## MEAN for this reason; the same refusal has to cover any grille count taken
## there. Over that crop HEAD scores 1378 hot-orange pixels against the
## painting's 638 — a number that says the mesh out-glows the painting twice
## over, and it is an artefact of two crops containing different subjects.
##
##
## THE WINDOW THIS TOOL GATES ON INSTEAD
##
## Molten metal, and nothing else: red at or above 0.90 with blue at or below
## 0.30. Painted onto the sprite it takes the furnace slats and the visor slits
## and leaves every piece of brass alone. It is a narrower claim than SG-86's
## window and it is the claim SG-131 is actually about.
const MOLTEN_R := 0.90
const MOLTEN_B := 0.30

## MEASURED AS A FRACTION OF THE FIGURE'S OWN PIXELS, over the WHOLE FRAME and
## not over a crop, because that is the only form of this number that survives
## the pose changing. The reference is the painting itself, read straight off
## the sprite sheets with the alpha channel as the figure mask:
##
##     furnace_knight_front_idle     1325 molten of 118328   1.12%
##     furnace_knight_front_attack    937 molten of  75227   1.25%
##     furnace_knight_back_idle       463 molten of  96411   0.48%
##
## The deck poses three boarders in mixed facings, so the honest band is bounded
## below by the back view and above by the most-lit front view.
const PAINTING_MOLTEN_BACK := 0.48
const PAINTING_MOLTEN_FRONT := 1.25

## THE FLOOR IS NOT ZERO ONLY BECAUSE THE ALBEDO HAS ORANGE PAINTED INTO IT.
## With Meshy's empty map in place this deck scores 0.15%, 0.15%, 0.13% over
## three runs — that is paint catching SG-81's warm omni, and no emitter at all.
## With the authored map it scores 0.22%, 0.24%, 0.24%. The floor is set between
## the two bands and clear of both, so it fails if the emission map is ever
## reverted, re-ingested from the Meshy source, or overwritten by a remesh.
const MOLTEN_FLOOR := 0.18

var _out_dir := "../.shots/sg86"
var _failures := 0


func _init() -> void:
	await process_frame
	var argv := OS.get_cmdline_user_args()
	if argv.size() > 0:
		_out_dir = str(argv[0])
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path("res://%s" % _out_dir))

	get_root().content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
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
	game.set_seed_text("KNIGHT")
	game.begin_run()
	game.choose_draft(0)
	game.spawn_queue.clear()
	view.sway = false
	var overlay = game.get_node_or_null("HUD")
	if overlay != null:
		overlay.visible = false

	game.player.global_position = Vector2(0.0, 200.0)
	game.player.velocity = Vector2.ZERO
	view._focus_set = false
	view._zoom = 1.0
	view._zoom_target = 1.0
	for _l in LANES:
		game.spawn_enemy("ARMORED", 1)
	var live: Array = game.get_tree().get_nodes_in_group("enemies")
	for i in mini(live.size(), LANES.size()):
		live[i].global_position = LANES[i]
		live[i].state = "move"
	for _i in SETTLE:
		game._process(1.0 / 60.0)
		await process_frame
	## Same reason `rune_probe.gd` does it: a boarder runs its own `_process` and
	## will walk into a windup between two of this tool's frames.
	for e in live:
		if is_instance_valid(e):
			e.set_process(false)
			e.set_physics_process(false)
			e.state = "move"
			e.state_time = 0.0
	for _i in 3:
		await process_frame

	print("")
	print("  DOES THE FURNACE KNIGHT READ AGAINST THE DECK HE STANDS ON?")
	print("  the knight scenario's three lanes, amidships, zoom 1.00, frozen")
	print("")

	var stopped := await SkyGearStill.freeze(self, view, game)
	print("  stopped: %d AnimationPlayers · %d GPUParticles3D" % [
		int(stopped.animation_players), int(stopped.particles)])

	## AND THEN PINNED, WHICH THE FREEZE ALONE DOES NOT DO (board SG-133).
	##
	## `SkyGearStill.freeze` sets `speed_scale = 0`, which stops the clock but
	## leaves the hands wherever they were. The 90 settle frames above advance
	## `game._process` on a fixed 1/60 but they advance the TREE on `await
	## process_frame`, which is the wall clock — so an `AnimationPlayer` lands on
	## a different phase every run, and the boarders strike a different pose.
	##
	## That is not a theory. Three runs of this tool on one unmodified build gave
	## the knight 14066, 14222 and 14384 pixels, figure/deck 0.993, 1.013 and
	## 1.045 — straddling both this tool's own 0.95 gate and the 1.0 the check
	## below asks for, so `lit · the furnace knight reads brighter than the deck`
	## passed twice and failed once on the same bytes. SG-86's shipped 1.041 is
	## one sample at the top of that spread.
	##
	## The freeze is what makes two plates in ONE run identical, and it does that
	## perfectly — the 0.00% floor above is real. This is the other half: what
	## makes two RUNS comparable, which is what an A/B of a texture change needs.
	var posed := 0
	for node in root.find_children("*", "AnimationPlayer", true, false):
		var ap := node as AnimationPlayer
		if ap.current_animation == "":
			continue
		ap.seek(POSE_T, true)
		posed += 1
	for _i in 3:
		await process_frame
	_say("lit · and the boarders' pose is pinned, so two runs are the same picture",
		posed > 0, "%d AnimationPlayers seeked to %.2fs" % [posed, POSE_T])

	## THE NOISE FLOOR FIRST, and it is the whole reason this tool exists rather
	## than a crop of a clip frame. `clip.gd` cannot pass this line.
	var noise := await SkyGearStill.floor_pct(self, FRAME_BOX)
	_say("lit · two plates of the frozen deck differ by exactly zero", noise == 0.0,
		"%.2f%%" % noise)
	if noise != 0.0:
		push_error("the scene is not still (%.2f%%) — nothing here to measure" % noise)
		quit(9)
		return

	## THE FIGURE, BY HIDING IT. What changes when the rigs go away is boarder;
	## what does not is deck.
	var lit := await _plate("%s/lit.png" % _out_dir)
	var hidden := _hide_rigs(view)
	var bare := await _plate("%s/bare.png" % _out_dir)
	_show(hidden)

	_say("lit · and hiding the boarders actually removes something from the crop",
		hidden.size() > 0, "%d rigs hidden" % hidden.size())

	var figure := _figure_mean(lit, bare)
	var deck := _deck_mean(lit, bare)
	var whole := _crop_mean(lit)
	var grille := _molten(lit, bare)

	print("")
	print("  OVER Rect2i(690, 60, 210, 280) — SG-86'S OWN CROP")
	print("    the knight's own pixels      %8.2f mean   (%d px)"
		% [figure.mean, figure.n])
	print("    his peak                     %8.1f" % figure.peak)
	print("    the planking, same crop      %8.2f mean   (painting %.2f)"
		% [deck, PAINTING_DECK])
	## Printed, NOT checked. The painting's 45.37 was measured over this crop of
	## the CLIP's pose, and this tool poses the lanes itself, so the two crops do
	## not contain the same amount of boarder. It is here as a scale reference and
	## it would be dishonest as a gate.
	print("    crop mean, figure and all    %8.2f          (clip pose, painting %.2f)"
		% [whole, PAINTING_MEAN])
	print("    figure over deck             %8.3f" % (figure.mean / maxf(deck, 0.01)))
	print("")
	print("  THE GRILLE, OVER THE WHOLE FRAME — SG-131")
	print("    the three boarders' pixels   %8d" % grille.figure)
	print("    molten of those              %8d" % grille.molten)
	print("    molten as a fraction         %8.2f%%         (painting %.2f%% front, %.2f%% back)"
		% [grille.pct, PAINTING_MOLTEN_FRONT, PAINTING_MOLTEN_BACK])
	print("")

	## THE ONE THAT MATTERS. Not "is he brighter" — brightness is free, the
	## exposure dial gives it away — but "is he brighter THAN THE PLANKING", which
	## is the only form of it a player can see. Pillar 6 outranks atmosphere.
	_say("lit · the furnace knight reads brighter than the deck he stands on",
		figure.mean > deck,
		"figure %.2f vs deck %.2f" % [figure.mean, deck])

	## AND THE DECK IS NOT WHERE THE LIGHT WENT. A rim aimed carelessly washes
	## the planking and the crop mean rises without the boarder gaining anything;
	## the painting's own planking is the ceiling this may not pass.
	_say("lit · and the planking is not brighter than it is in the painting",
		deck <= PAINTING_DECK,
		"deck %.2f, painting %.2f" % [deck, PAINTING_DECK])

	## AND THE LIGHT LANDED ON HIM RATHER THAN ON THE DECK, which is the check
	## that would have caught the first attempt at this fix. A rim pitched at -16
	## raised the boarder 7.3 and the planking 8.0 and moved this ratio from 0.853
	## to 0.861 — a measured improvement in every published SG-86 number that was
	## not an improvement at all, because both sides of the contrast moved
	## together. A gate on the boarder's brightness alone cannot tell those two
	## apart; a gate on the RATIO can, and HEAD fails it at 0.853.
	_say("lit · and the rim went onto the boarder and not onto the planking",
		figure.mean / maxf(deck, 0.01) >= 0.95,
		"figure/deck %.3f" % (figure.mean / maxf(deck, 0.01)))

	## SG-131, THE GRILLE. Counted on the boarders' own pixels — separated by the
	## same hide-and-diff the luminance uses — and NOT over a crop, because the
	## crop contains braziers, embers and a lit mast, and a colour window cannot
	## tell those from a furnace.
	_say("lit · the furnace knight's grille is an emitter and not just paint",
		grille.pct > MOLTEN_FLOOR,
		"%.2f%% molten, floor %.2f%%" % [grille.pct, MOLTEN_FLOOR])

	## AND THE CEILING, which is the half that a brightness dial fails and the
	## half that matters more. Three boarders in mixed facings cannot average more
	## molten than the painting's most-lit FRONT view without the emission having
	## been turned up past what the art asks for, and a boarder who out-glows his
	## own wind-up telegraph is a Pillar 6 loss. Pillar 6 outranks atmosphere —
	## the same argument that left the rim's headroom unspent above.
	_say("lit · and it does not out-glow the painting it is copied from",
		grille.pct <= PAINTING_MOLTEN_FRONT,
		"%.2f%% molten, painting's front view %.2f%%"
			% [grille.pct, PAINTING_MOLTEN_FRONT])

	print("")
	if _failures == 0:
		print("  ALL CHECKS PASSED.")
	else:
		print("  %d CHECK(S) FAILED." % _failures)
	print("")
	quit(_failures)


func _hide_rigs(view) -> Array:
	var hidden: Array = []
	for key in view._rigs.keys():
		var rig = view._rigs[key]
		if rig != null and is_instance_valid(rig) and rig.visible:
			rig.visible = false
			hidden.append(rig)
	return hidden


func _show(hidden: Array) -> void:
	for n in hidden:
		if is_instance_valid(n):
			n.visible = true


## Rec709 on 0-255, which is what SG-86's published numbers are in: the row's
## 45.4 reproduces as 45.37 under this and under nothing else tried.
func _lum(c: Color) -> float:
	return (c.r * 0.2126 + c.g * 0.7152 + c.b * 0.0722) * 255.0


func _figure_mean(lit: Image, bare: Image) -> Dictionary:
	var sum := 0.0
	var peak := 0.0
	var n := 0
	for y in range(CROP.position.y, CROP.end.y):
		for x in range(CROP.position.x, CROP.end.x):
			var a := lit.get_pixel(x, y)
			var b := bare.get_pixel(x, y)
			if maxf(absf(a.r - b.r), maxf(absf(a.g - b.g), absf(a.b - b.b))) \
					< SkyGearStill.MOVED:
				continue
			var l := _lum(a)
			sum += l
			peak = maxf(peak, l)
			n += 1
	return {"mean": sum / maxf(1.0, float(n)), "peak": peak, "n": n}


func _deck_mean(lit: Image, bare: Image) -> float:
	var sum := 0.0
	var n := 0
	for y in range(CROP.position.y, CROP.end.y):
		for x in range(CROP.position.x, CROP.end.x):
			var a := lit.get_pixel(x, y)
			var b := bare.get_pixel(x, y)
			if maxf(absf(a.r - b.r), maxf(absf(a.g - b.g), absf(a.b - b.b))) \
					>= SkyGearStill.MOVED:
				continue
			sum += _lum(a)
			n += 1
	return sum / maxf(1.0, float(n))


## THE GRILLE, over the WHOLE FRAME rather than SG-86's crop. Every pixel that
## changed when the rigs were hidden is boarder; of those, the ones inside the
## molten window are furnace. Reported as a fraction so it can be held against
## the sprite sheets, which are read the same way with alpha as the figure mask.
func _molten(lit: Image, bare: Image) -> Dictionary:
	var figure := 0
	var molten := 0
	for y in range(FRAME_BOX.position.y, FRAME_BOX.end.y):
		for x in range(FRAME_BOX.position.x, FRAME_BOX.end.x):
			var a := lit.get_pixel(x, y)
			var b := bare.get_pixel(x, y)
			if maxf(absf(a.r - b.r), maxf(absf(a.g - b.g), absf(a.b - b.b))) \
					< SkyGearStill.MOVED:
				continue
			figure += 1
			if a.r >= MOLTEN_R and a.b <= MOLTEN_B:
				molten += 1
	return {
		"figure": figure,
		"molten": molten,
		"pct": 100.0 * float(molten) / maxf(1.0, float(figure)),
	}


func _crop_mean(lit: Image) -> float:
	var sum := 0.0
	var n := 0
	for y in range(CROP.position.y, CROP.end.y):
		for x in range(CROP.position.x, CROP.end.x):
			sum += _lum(lit.get_pixel(x, y))
			n += 1
	return sum / maxf(1.0, float(n))


## `frame_post_draw`, not `process_frame` — SG-29's idiom and SG-108's reason.
func _plate(path: String) -> Image:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png(path)
	return img


func _say(name: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("    %s  %s   %s" % ["ok  " if ok else "FAIL", name, detail])
