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

	## SUPPRESS THE SHIPPED CUTSCENES, the way `tools/cutscene_lab.gd` does — and
	## the reason this tool exists as a posed shot at all (board SG-33). `begin_run`
	## owes an establishing `run_open` crane and `view3d.gd::_watch_cues` spends it
	## the first PLAY frame; left enabled it poses the camera for its whole 2.5s, so
	## every sky pose below would be a frame of the crane (pitch −30.8°/yaw −16°),
	## NOT the locked 41.25°/0° gameplay solve the sky was meant to be judged from.
	## Whether the crane has finished by the time a frame is saved is a matter of how
	## fast this machine warmed up — a timing accident, not a guarantee — so the cue
	## is turned off outright rather than waited out. `_assert_locked` below refuses
	## to save any frame if a future cue slips past this anyway.
	view.cutscenes_enabled = false
	view.stop_cutscene()

	## The browser build has neither Workshop nor Heat, and a lighting comparison
	## against a run with either turned on is a comparison of two different games.
	game.workshop = SkyGearWorkshop.fresh(true)
	game.heat = 0
	game.set_class("captain")
	game.set_seed_text("SKY")
	game.begin_run()
	## `choose_draft` ON THE OPENING DRAFT ALREADY STARTS WAVE ONE. Calling it
	## again here began the wave twice — two spawn schedules, two banners, and a
	## `wave_time` reset partway through the first. Invisible until banners
	## stopped printing pixel-on-pixel and a posed shot came back with "WAVE 1"
	## three times down the middle of the screen.
	game.choose_draft(0)
	if game.wave != 1:
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
			if game.wave != 1:
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
			## The frame is only worth saving if it IS the locked gameplay solve. A
			## cutscene poses the camera and nothing else on screen says it did — so
			## rather than trust that the suppression above held, the pose is measured
			## before the shutter and the tool refuses a contaminated frame outright.
			if not _assert_locked(view, spot, zoom):
				quit(1)
				return
			var path := "%s/%s-z%.2f.png" % [out_dir, spot, zoom]
			root.get_texture().get_image().save_png(path)
			print("  %-10s zoom %.2f  ->  %s" % [spot, zoom, path.replace("res://../", "")])
			print("             %s" % str(at.what))
			made += 1
	print("\n%d shot(s). Look at them." % made)
	quit(0)


## The camera IS the locked solve, or the shot does not get taken. The gameplay
## camera is pitched `SkyGearView3D.PITCH` (0.72 rad = 41.25° below horizontal)
## and does not yaw — the sky is made visible by MOVING the captain toward a rail,
## never by turning the lens. So a frame worth saving reads 41.25°/0° with no
## cutscene active; anything else is a cue that slipped past the suppression, and
## the whole point of SG-33 is that such a cue must not contaminate a sky frame
## silently.
func _assert_locked(view: SkyGearView3D, spot: String, zoom: float) -> bool:
	var cam := view.camera
	if cam == null:
		push_error("sky_shot: no camera to measure")
		return false
	var fwd: Vector3 = -cam.global_transform.basis.z
	var pitch := rad_to_deg(-asin(clampf(fwd.y, -1.0, 1.0)))
	var yaw := rad_to_deg(atan2(fwd.x, -fwd.z))
	var locked_pitch := rad_to_deg(SkyGearView3D.PITCH)
	var off := absf(pitch - locked_pitch) > 0.5 or absf(yaw) > 0.5 \
		or view.cutscene_active()
	if off:
		var msg := "sky_shot REFUSED %s z%.2f: camera is pitch %.2f / yaw %.2f (locked is %.2f / 0.00), cutscene active=%s — a cue posed the lens; the frame is NOT the gameplay solve" % [spot, zoom, pitch, yaw, locked_pitch, str(view.cutscene_active())]
		push_error(msg)
		print("  !! ", msg)
		return false
	return true
