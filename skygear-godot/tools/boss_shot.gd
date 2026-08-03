extends SceneTree
## The Colossus, standing at melee reach of the captain, at the real camera —
## board SG-94, and the frame the owner asked for.
##
##   godot --path . --resolution 1600x900 --script tools/boss_shot.gd -- <outdir> [energy ...]
##
## WHY THIS IS ITS OWN TOOL. `tools/clip.gd -- boss` films the fight and is the
## right thing for the walk, the turn and the death; what it cannot give is ONE
## repeatable frame with the machine and the captain in it at a fixed pose. The
## owner reported "Collosus is way too easy - he needs to be scary the player.
## Not sure what's going on with his texture" against a single screenshot, and a
## single screenshot is what answers it — the same staging his had, so the two
## can be laid side by side.
##
## THE STAGING IS THE SIMULATION'S OWN. The boss arrives through `spawn_enemy`
## and is walked down the deck by its own AI until it is inside `attack_range` of
## the captain, who holds her ground. Nothing here poses a limb or moves a
## camera: the camera is wherever the shipped deck camera puts it with her under
## it, which is the whole point of shooting at the real camera. The captain is in
## frame because she is the SCALE — a 3.3 m machine means nothing next to
## nothing.
##
## THE ENERGY SWEEP, and why this tool owns it. `assets/models/lights.json` gives
## the Colossus a furnace lamp because the part-segmentation export had no
## emission map to give it a grate. The textured twin now shipping DOES carry an
## emission map — and it is almost entirely black (mean 0.2/255, 0.17% of pixels
## lit: a few small vents, not a furnace), so the lamp stays. What changed is
## what it is shining ON: a painted, riveted surface instead of a flat fill. An
## omni sitting inside the chest at 1.28 blows the plates nearest it to white and
## takes the texture off exactly the part of the machine a player looks at.
##
## Pass extra arguments and each is photographed at that energy, with the blown
## fraction of the machine printed per frame, so the number is chosen off a
## measurement instead of an opinion:
##
##   godot --path . --resolution 1600x900 --script tools/boss_shot.gd -- .shots/boss 1.28 0.9 0.7
##
## NOT `--headless`. There is no framebuffer to read back without a GPU (SG-29),
## and a tool whose whole output is a PNG cannot run on the flag that makes PNGs
## empty.
func _initialize() -> void: call_deferred("_run")

## Ticks held once the machine is on its mark, for the stride to settle and the
## contact shadows to land under it.
const WINDUP_HOLD := 8
## Where it is photographed, in ground units from the captain. See `_shoot`.
const STAND_OFF := 420.0
## Ticks the simulation is driven for, at most, waiting for it to close.
const WALK_TICKS := 900
const DT := 1.0 / 60.0


func _run() -> void:
	var argv := OS.get_cmdline_user_args()
	var out_dir: String = str(argv[0]) if argv.size() > 0 else "../.shots/boss"
	var energies: Array = []
	for i in range(1, argv.size()):
		energies.append(float(argv[i]))
	## `SG_BOSS_STANDOFF` overrides the mark, for finding it again if the deck
	## camera or the figure height ever moves.
	var stand_off := STAND_OFF
	if OS.has_environment("SG_BOSS_STANDOFF"):
		stand_off = float(OS.get_environment("SG_BOSS_STANDOFF"))
	DirAccess.make_dir_recursive_absolute(out_dir)

	for pass_i in maxi(1, energies.size()):
		var energy: float = float(energies[pass_i]) if pass_i < energies.size() else -1.0
		var tag: String = "e%s" % String.num(energy, 2) if energy >= 0.0 else "boss"
		var ok := await _shoot(out_dir, tag, energy, stand_off)
		if not ok:
			quit(1)
			return
	print("boss shot ok")
	quit(0)


func _shoot(out_dir: String, tag: String, energy: float,
		stand_off: float) -> bool:
	var world = load("res://scenes/main3d.tscn").instantiate()
	root.add_child(world)
	await process_frame
	var game: SkyGearGame = world.get_node("SkyGear")
	## Both clocks are OURS — the double-stepping rule every shot tool here
	## follows, and the reason vfx_shot's first run photographed an empty deck.
	game.set_process(false)
	world.set_process(false)
	game.log_runs = false
	world.cutscenes_enabled = false
	world.stop_cutscene()
	## A still is a picture, not a run: the camera must be where it settles, not
	## somewhere along its own sway.
	world.sway = false
	game.workshop = SkyGearWorkshop.fresh(true)
	game.heat = 0
	game.set_class("captain")
	game.set_seed_text("COLOSSUS")
	game.begin_run()
	game.choose_draft(0)

	## THE LAMP, overridden before the boss is built so it wears it from its
	## first frame. This reaches the renderer's OWN loaded table rather than the
	## file — `lights.json` is parsed once into `_model_light_rows` at build —
	## so a sweep costs nothing on disk and nothing in production code.
	if energy >= 0.0:
		var rows: Array = world._model_light_rows.get("boss", [])
		if rows.is_empty():
			push_error("no boss row in lights.json to sweep")
			return false
		(rows[0] as Dictionary)["energy"] = energy
		## AND THE FLICKER IS HELD STILL FOR A SWEEP. The lamp's shipped shape
		## is a 3.4 Hz flicker 18% deep, so two energies photographed through it
		## differ by up to a fifth for no reason but phase — which is exactly
		## what a first sweep measured, and why it read as noise. A comparison
		## needs one variable.
		(rows[0] as Dictionary)["depth"] = 0.0

	game.skills.clear()
	game.skills.append(SkyGearData.make_skill("CLOSEHIT", "EMBER"))
	game.start_wave(1)
	## Hold the wave open the way clip.gd does — a wave that completes while the
	## boss is walking ends the staging out from under it.
	game.spawn_queue.clear()
	game.spawn_queue.append({"time": 99999.0, "kind": "SCRAPPER", "lane": 1})
	game.spawn_enemy("BOSS", 1)
	var arrivals := game.get_tree().get_nodes_in_group("enemies")
	if arrivals.is_empty():
		push_error("no Colossus spawned")
		return false
	var colossus = arrivals[arrivals.size() - 1]
	colossus.lane = 1
	colossus.global_position = Vector2(-10.0, 215.0)
	colossus.state = "move"

	## WALK IT IN, on its own AI, until it plants itself and swings. Driven
	## rather than teleported, and the stop condition is the SIMULATION's own:
	## `state == "windup"` is the machine deciding it is in reach, which is a
	## fact about the fight rather than a distance typed here. It plants at
	## about 353 ground units — well outside the 120 in the config, because
	## `enemy.gd` adds the target's radius and a swing reach on top — so a
	## threshold computed from the table alone waits forever, measured.
	var gap := 0.0
	var closed := false
	for tick in WALK_TICKS:
		if not is_instance_valid(colossus) or colossus.dead:
			break
		game._process(DT)
		world._process(DT)
		await process_frame
		gap = colossus.global_position.distance_to(game.player.global_position)
		## STOP WHERE THE MACHINE FITS THE FRAME, not where it stops walking.
		## Its fighting reach is about 353 ground units and at 353 the deck
		## camera — which rides the CAPTAIN, not the fight — crops its head off
		## against the top of the screen. The still has to show the whole thing
		## beside her or it is not a scale reference, so the shutter falls on
		## the walk at `stand_off`; the fighting stance is what clip.gd films.
		if gap <= stand_off:
			closed = true
			break
	if not closed:
		push_error("the Colossus never closed to %.0f (stalled at %.0f)"
			% [stand_off, gap])
		return false
	## A few ticks for the stride to settle and the contact shadows to land.
	for _i in WINDUP_HOLD:
		game._process(DT)
		world._process(DT)
		await process_frame

	var path := "%s/%s.png" % [out_dir, tag]
	var img := root.get_texture().get_image()
	img.save_png(path.replace("\\", "/"))
	print("  %-8s %s   gap %.0f   %s" % [tag, path, gap, _blown(img)])
	world.queue_free()
	await process_frame
	return true


## What fraction of the frame the machine has burned to white. A contact print
## of the fault an over-bright interior lamp makes: the plates nearest it stop
## being brass and start being paper, and the texture the whole marriage bought
## is the thing that goes first.
##
## Read over the window the machine stands in at STAND_OFF — the upper third of
## the frame, middle half across. Not the whole frame: the captain's own lit
## hull, her ring and the HUD's brass are all brighter than anything on the
## Colossus and would swamp every number here.
##
## Reported together because they answer opposite questions. `lit` is whether
## the machine is out of the dark at all — the failure the flat palette had, a
## black silhouette on a lamp-lit deck. `blown` is whether the lamp has burned
## the paint off the plates nearest it, which is the failure that only became
## possible once there was paint to burn.
func _blown(img: Image) -> String:
	var w := img.get_width()
	var h := img.get_height()
	var hot := 0
	var seen := 0
	var sum := 0.0
	for y in range(int(h * 0.04), int(h * 0.34), 2):
		for x in range(int(w * 0.25), int(w * 0.75), 2):
			var c := img.get_pixel(x, y)
			seen += 1
			sum += c.get_luminance()
			if c.r > 0.96 and c.g > 0.92 and c.b > 0.80:
				hot += 1
	return "lit %.4f  blown %.3f%%" % [sum / maxf(1.0, float(seen)),
		100.0 * float(hot) / maxf(1.0, float(seen))]
