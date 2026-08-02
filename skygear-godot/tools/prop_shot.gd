extends SceneTree
## The prop-purge judging lens (board SG-64): the deck through the REAL game
## camera, with the captain stood wherever the prop under judgement is best
## seen. `tools/parity_shot.gd` poses the browser's fixed scenes and must stay
## symmetric with the browser half, so it cannot grow a "move the captain"
## field — this tool exists for the one question parity does not answer:
## does a generated prop beat its painting AT THE DISTANCE THE PLAYER GETS?
##
##   godot --path . --resolution 1600x900 --script tools/prop_shot.gd -- \
##       '{"wave": 4, "player": [0, -500], "steps": 40, "out": "C:/.../shot.png"}'
##
##   wave     poses that wave (4 grapples the boarding hulk at the bow)
##   player   [x, y] the captain is stood at before the settle; the gameplay
##            camera follows her there, which is how the bow comes into frame
##   steps    hand-stepped ticks at 1/60 after the teleport (camera settle)
##   hulk     "sealed" | "open" | "destroyed" — poses the boarding hulk in that
##            state (SG-76). Written AFTER the settle and without stepping the
##            simulation again, because "destroyed" satisfies the push and a
##            stepped frame would photograph the WAVE CLEAR banner instead of
##            the wreck.
##   painted  true forces the painted billboard for the hulk — the BEFORE frame
##            of any mesh-against-art judgement. It does it through
##            `_no_prop_model`, the renderer's own "this key has no scene"
##            shelf, so the fallback under test is the real one rather than a
##            second path that only the tool can reach.
##   out      absolute PNG path
##
## Windowed only — SG-29: there is no rendering device under --headless.
func _initialize() -> void: call_deferred("_run")


func _run() -> void:
	if not SkyGearRendererCheck.can_capture():
		print(SkyGearRendererCheck.capture_refusal())
		quit(2)
		return
	## The deck_probe.gd hunk verbatim (SG-46): --resolution is ignored for tool
	## scripts, so force the frame before anything renders.
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1600, 900))
	root.size = Vector2i(1600, 900)
	await process_frame

	var argv := OS.get_cmdline_user_args()
	if argv.is_empty():
		print("no scene given")
		quit(1)
		return
	var scene = JSON.parse_string(str(argv[0]))
	if scene is not Dictionary:
		print("scene is not json")
		quit(1)
		return

	var world = load("res://scenes/main3d.tscn").instantiate()
	root.add_child(world)
	await process_frame
	var game: SkyGearGame = world.get_node("SkyGear")
	var view := world as SkyGearView3D

	## The parity_shot suppressions, for the parity_shot reasons: no cutscene
	## camera in a judging frame, no double-stepped sim, no Workshop, no Heat,
	## and no fake row in the player's own run log (SG-49).
	if view != null:
		view.cutscenes_enabled = false
		view.stop_cutscene()
	game.set_process(false)
	game.log_runs = false
	game.workshop = SkyGearWorkshop.fresh(true)
	game.heat = 0
	game.set_class("captain")
	game.set_seed_text(str(scene.get("seed", "PARITY")))
	game.begin_run()
	game.choose_draft(0)

	var want_wave: int = int(scene.get("wave", 1))
	if game.wave != want_wave:
		game.start_wave(want_wave)
	## An empty deck, held open — the SG-36 idiom, one spawn parked in the far
	## future so the WAVE CLEAR banner cannot photobomb the judging frame.
	game.spawn_queue.clear()
	game.spawn_queue.append({"time": 99999.0, "type": "SCRAPPER", "lane": 1})

	## Stand the captain where the scene asks, THEN settle: the gameplay camera
	## follows her, so this is how a prop at the bow is judged from mid-deck
	## instead of from the spawn point 900 units astern of it.
	var at: Array = scene.get("player", [])
	if at.size() == 2:
		game.player.global_position = Vector2(float(at[0]), float(at[1]))
	var steps: int = int(scene.get("steps", 40))
	for _i in steps:
		game._process(1.0 / 60.0)
		await process_frame

	## The hulk's face, posed rather than played (SG-76). `hulk_state()` reads
	## these two flags and nothing else, so setting them here is setting the
	## state — there is no third place that could disagree.
	var want_hulk := str(scene.get("hulk", ""))
	if want_hulk != "" and not game.hulk.is_empty():
		game.hulk.vulnerable = want_hulk != "sealed"
		game.hulk.dead = want_hulk == "destroyed"
		game.hulk.grapple = 999.0 if want_hulk == "sealed" else 0.0
		## And no banner over the object being judged. `start_wave` announces the
		## push — the event card, the wave title and the voice line all fire on
		## the frame the hulk grapples — so a frame taken to look at the hulk is
		## a frame of the card that says a hulk arrived. The SG-36 idiom (park
		## the spawn, hold the deck open) applied to the announcement layer.
		game.event_banner_left = 0.0
		game.effects.clear()
	if bool(scene.get("painted", false)) and view != null:
		for key in SkyGearView3D.HULK_MODELS.values():
			view._no_prop_model[str(key)] = true
	## Frames, not ticks: the renderer syncs on its own _process while the
	## simulation stays exactly where the settle left it.
	for _i in 4:
		await process_frame

	var out := str(scene.get("out", ""))
	if out == "":
		print("no output path")
		quit(1)
		return
	var img := root.get_texture().get_image()
	img.save_png(out.replace("\\", "/"))
	print("shot ok")
	quit(0)
