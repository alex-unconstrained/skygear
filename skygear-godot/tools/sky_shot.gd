extends SceneTree
## Photograph the sky, from the only places it is actually visible.
##
## WHY THIS EXISTS. The skybox was reported three times and slipped three times,
## and the reason it kept slipping is written into the geometry: the camera is
## pitched 41 degrees down and its vertical field is 36 degrees, so the top of
## the frame looks 23 degrees BELOW horizontal and the horizon is never in shot
## at any zoom. Every screenshot taken from the middle of the deck is therefore
## a screenshot of planking, and judging the sky from one is judging a thing that
## is not in the picture. The sky shows in exactly two situations — the camera
## following the captain toward a rail, so the deck edge cuts across the frame
## and there is open air beyond it, and zoomed out, where the deck no longer
## fills the width — and both have to be posed deliberately.
##
##   godot --path . --script tools/sky_shot.gd
##   godot --path . --script tools/sky_shot.gd -- port 1.55
##   godot --path . --script tools/sky_shot.gd -- port 1.55 2560x1080
##
## Writes `.shots/sky/<spot>-z<zoom>.png` for every spot unless one is named.
## Deterministic: the sway is switched off and the camera is snapped rather than
## eased, so two runs of this tool differ only where the build differs.

## Where the captain is put, as a fraction of the deck rectangle, and what each
## one is for. `port` is the shot the request was actually about — it is the one
## where you are looking over the side of the ship.
const SPOTS := {
	"mid": {"x": 0.50, "y": 0.50,
		"what": "the shipped composition; sky only in the top corners"},
	"port": {"x": 0.06, "y": 0.46,
		"what": "over the port rail — the shot the skybox request is about"},
	"starboard": {"x": 0.94, "y": 0.46,
		"what": "and the other side, because the two are lit differently"},
	"bow": {"x": 0.50, "y": 0.06,
		"what": "the far end, where the envelope and the prow crowd the top"},
}


func _initialize() -> void: call_deferred("_run")


func _run() -> void:
	var argv := OS.get_cmdline_user_args()
	var only := str(argv[0]) if argv.size() > 0 else ""
	var zooms: Array = [1.0, 1.55]
	if argv.size() > 1:
		zooms = [float(argv[1])]
	## Third argument is a window size, because the one thing about this sky that
	## is worth re-checking after a change is what it does off 16:9 — the shader
	## holds its content at fixed ANGLES and clamps at the edges, so a wider
	## window shows more sky and an ultrawide one shows the painting's edge.
	var size := Vector2i(1600, 900)
	if argv.size() > 2 and str(argv[2]).contains("x"):
		var parts := str(argv[2]).split("x")
		size = Vector2i(int(parts[0]), int(parts[1]))
	if only != "" and not SPOTS.has(only):
		print("no spot called %r. one of: %s" % [only, ", ".join(SPOTS.keys())])
		quit(1)
		return

	## The project ships fullscreen, so `--resolution` is ignored and the shots
	## come out at whatever monitor is attached — which means two people running
	## this tool cannot compare their output. Forced to 16:9 at a size that fits
	## any modern display, and 16:9 on purpose: the sky shader reproduces the
	## browser's framing exactly at that aspect and clamps at the edges beyond it.
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(size)
	root.size = size
	await process_frame

	var out_dir := "res://../.shots/sky"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))

	var world = load("res://scenes/main3d.tscn").instantiate()
	root.add_child(world)
	await process_frame
	var game: SkyGearGame = world.get_node("SkyGear")
	var view: SkyGearView3D = world

	## The browser build has neither Workshop nor Heat, and a lighting comparison
	## against a run with either turned on is a comparison of two different games.
	game.workshop = SkyGearWorkshop.fresh(true)
	game.heat = 0
	game.set_class("captain")
	game.set_seed_text("SKY")
	game.begin_run()
	game.choose_draft(0)
	game.start_wave(1)
	game.spawn_queue.clear()

	## A camera that is deliberately never still cannot also be the thing a
	## framing check measures against — the same reason the harness turns it off.
	view.sway = false

	## Let the shader warm-up run and the deck settle before anything is posed.
	for _i in 20:
		game._process(1.0 / 60.0)
		await process_frame

	var deck: Rect2 = SkyGearGame.DECK_RECT
	var made := 0
	for spot in SPOTS:
		if only != "" and spot != only:
			continue
		for zoom in zooms:
			## An empty wave clears itself after a second and a half and opens the
			## draft over the top of the frame — which is how the first run of this
			## tool photographed three cards instead of the starboard rail. The
			## wave is put back before every pose rather than held open with
			## boarders: a boarder walks, and the point of this tool is that two
			## runs differ only where the build differs.
			if game.state == SkyGearGame.State.DRAFT:
				game.choose_draft(0)
			game.start_wave(1)
			game.spawn_queue.clear()
			var at: Dictionary = SPOTS[spot]
			game.player.global_position = Vector2(
				deck.position.x + deck.size.x * float(at.x),
				deck.position.y + deck.size.y * float(at.y))
			game.player.velocity = Vector2.ZERO
			## Snap rather than ease. The follow has a 0.155 s time constant and
			## the zoom 0.11 s, so a tool that stepped frames would be
			## photographing the tail of a lerp and calling it a position.
			view._focus_set = false
			view._zoom = float(zoom)
			view._zoom_target = float(zoom)
			for _i in 4:
				game._process(1.0 / 60.0)
				await process_frame
			var path := "%s/%s-z%.2f.png" % [out_dir, spot, zoom]
			root.get_texture().get_image().save_png(path)
			print("  %-10s zoom %.2f  ->  %s" % [spot, zoom, path.replace("res://../", "")])
			print("             %s" % str(at.what))
			made += 1
	print("\n%d shot(s). Look at them." % made)
	quit(0)
