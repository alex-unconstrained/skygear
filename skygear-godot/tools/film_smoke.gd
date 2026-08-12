extends SceneTree
## STILL: NOT APPLICABLE — this tool photographs a MOVING PICTURE on purpose.
##
## `tools/still.gd`'s freeze exists so two runs of a deck photograph produce the
## same pixels: it stops the simulation, the engine clock, every AnimationPlayer,
## the GPU particle clock, the debanding dither and the brazier phase. Every one
## of those would also stop the film, and a frozen frame of a video player is a
## photograph of nothing. This tool's whole question is whether the decoder is
## ADVANCING, so it must not freeze anything — and it makes no pixel-ratio claim
## that a moving frame could invalidate. It asserts `stream_position > 0`, which
## is only true of an unfrozen clock.
##
## Does the film actually DECODE and PLAY in a real window? The harness runs
## headless and `_maybe_play_opening` correctly refuses there, so nothing in it
## has ever touched the video path. This is the one thing that would embarrass
## the demo on a stranger's machine.
func _init() -> void:
	SkyGearAudio.store = "user://settings.smoke.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SkyGearAudio.store))
	var g: SkyGearGame = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(g)
	for i in 12:
		await process_frame
	var film := g.get_node_or_null("Opening")
	if film == null:
		print("SMOKE FAIL: no Opening node")
		quit(1); return
	var vp: VideoStreamPlayer = null
	for c in film.find_children("*", "VideoStreamPlayer", true, false):
		vp = c as VideoStreamPlayer
	if vp == null:
		print("SMOKE FAIL: no VideoStreamPlayer")
		quit(1); return
	var t := 0.0
	while t < 2.5:
		await process_frame
		t += 0.016
	print("playing=%s  stream=%s  pos=%.2f  seen=%s"
		% [str(vp.is_playing()), str(vp.stream != null), vp.stream_position,
			str(SkyGearOpening.seen())])
	if not vp.is_playing() or vp.stream_position <= 0.05:
		print("SMOKE FAIL: the film did not advance")
		quit(1); return
	## And a photograph of it, because "playing" and "looks right in the window
	## the game actually opens" are two different claims.
	## The frame the player would see, grabbed AFTER the renderer has finished
	## with it. `get_texture().get_image()` on the frame the tree happens to be
	## on reads whatever was in the buffer, which on this project has produced
	## a photograph of the frame before.
	await RenderingServer.frame_post_draw
	var shot := get_root().get_texture().get_image()
	shot.save_png("res://.shots/cutscene/in_game_frame.png")
	print("SMOKE OK — frame at .shots/cutscene/in_game_frame.png")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SkyGearAudio.store))
	quit(0)
