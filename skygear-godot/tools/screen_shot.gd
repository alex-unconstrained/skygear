extends SceneTree
## STILL: NOT APPLICABLE — this photographs a 2D HUD SCREEN, not the deck
## (SG-108). There is no rig, no particle system and no brazier phase in a posed
## menu; what it does need is for the renderer to have finished drawing, and it
## already waits on `RenderingServer.frame_post_draw` for exactly that reason.
## PHOTOGRAPH A MENU. The half of the verification loop no checker can do.
##
## WHY THIS EXISTS. `tools/text_audit.gd` poses seventeen screens at four
## resolutions and proves five things about each: text inside its frame, no two
## widgets on the same pixels, nothing on the brass, nothing printed through
## anything else, nothing that drifts. It has never once had an opinion about
## whether a screen looks good, and it cannot: a dull screen and a beautiful one
## produce identical rectangles. Screens in this project have repeatedly been
## declared finished while visibly broken, and the only defence that has ever
## worked is somebody opening the PNG.
##
## Doing that used to mean writing a throwaway poser each time, which is how you
## end up looking at a Workshop with different scrip and different nodes bought
## than the one the audit measures. Both tools now pose through
## `tools/screens.gd`, so this photographs exactly what that measures.
##
##   godot --path . --script tools/screen_shot.gd
##   godot --path . --script tools/screen_shot.gd -- workshop
##   godot --path . --script tools/screen_shot.gd -- workshop 1280x720
##   godot --path . --script tools/screen_shot.gd -- workshop all
##   godot --path . --script tools/screen_shot.gd -- workshop all before
##
## The name is matched loosely against the screen list, so `workshop` finds "the
## workshop" and `draft` finds both drafts. `all` means every resolution the
## audit runs at — 1280x720 and the 2560x1080 ultrawide are where a dense layout
## breaks, and they are the two nobody thinks to check. A third argument is a
## subfolder, which is how you keep a before next to an after.
##
## Writes `.shots/screens[/<tag>]/<screen>-<w>x<h>.png`.

const Screens := preload("res://tools/screens.gd")

func _initialize() -> void: call_deferred("_run")


func _run() -> void:
	## Refuse headless up front. There is no GPU under --headless, so the
	## capture below would stall forever at `await frame_post_draw` (SG-29).
	if not SkyGearRendererCheck.can_capture():
		print(SkyGearRendererCheck.capture_refusal())
		quit(2)
		return
	var argv := OS.get_cmdline_user_args()
	var want := str(argv[0]).to_lower() if argv.size() > 0 else ""
	var sizes: Array = [Screens.SIZES[1]]
	if argv.size() > 1:
		if str(argv[1]).to_lower() == "all":
			sizes = Screens.SIZES.duplicate()
		elif str(argv[1]).contains("x"):
			var parts := str(argv[1]).split("x")
			sizes = [Vector2(float(parts[0]), float(parts[1]))]
	var tag := str(argv[2]) if argv.size() > 2 else ""

	var chosen: Array = []
	for screen in Screens.SCREENS:
		if want == "" or str(screen.name).to_lower().contains(want):
			chosen.append(screen)
	if chosen.is_empty():
		print("no screen matching %r. one of:" % want)
		for screen in Screens.SCREENS:
			print("    %s" % str(screen.name))
		quit(1)
		return

	## WINDOWED AND UNSCALED, the same reason the audit does it: the project ships
	## fullscreen with `canvas_items` stretch, so out of the box a 1920x1080 canvas
	## is letterboxed into whatever monitor is attached and the PNG is neither the
	## size of the HUD nor a whole multiple of it. A screenshot you cannot measure
	## against the layout is a screenshot you cannot act on.
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	await process_frame

	var world = load("res://scenes/main3d.tscn").instantiate()
	root.add_child(world)
	await process_frame
	var game = world.get_node("SkyGear")
	var hud = game.hud

	var out_dir := "res://../.shots/screens"
	if tag != "":
		out_dir += "/" + tag
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))

	var made := 0
	for size in sizes:
		DisplayServer.window_set_size(Vector2i(int(size.x), int(size.y)))
		root.size = Vector2i(int(size.x), int(size.y))
		await process_frame
		for screen in chosen:
			await Screens.pose(self, game, hud, screen, size)
			## Two settled frames before the shutter. One is not enough: the pose
			## touches the simulation and the HUD redraws on `_process`, so the
			## first frame after a pose can carry the previous screen's plate.
			for _i in 2:
				hud.queue_redraw()
				await process_frame
			await RenderingServer.frame_post_draw
			var path := "%s/%s-%dx%d.png" % [out_dir,
				Screens.slug(str(screen.name)), int(size.x), int(size.y)]
			var frame: Image = root.get_texture().get_image()
			if frame == null:
				print("  !! no frame came back for %s" % str(screen.name))
				continue
			frame.save_png(path)
			print("  %-28s %5dx%-5d ->  %s"
				% [str(screen.name), int(size.x), int(size.y),
					path.replace("res://../", "")])
			made += 1

	print("\n%d shot(s). LOOK AT THEM — this tool has no opinion." % made)
	quit(0)
