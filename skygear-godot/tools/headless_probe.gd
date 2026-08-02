extends SceneTree
## SG-29 scratch: where exactly does headless capture stall, and does any
## workaround unstick it?
##
##   godot --path . [--headless] --script tools/headless_probe.gd -- <mode>
##
## Modes: plain (get_image straight away), force (force_draw first),
## forceawait (force_draw + await frame_post_draw), await (the tools' current
## pattern: await frame_post_draw then get_image), sub (readback from a
## SubViewport with UPDATE_ALWAYS instead of the root).
##
## Every step prints a marker, so an external timeout tells us the exact line
## that never returns. Run each variant under `timeout` — a blocked main
## thread cannot rescue itself.

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var mode: String = args[0] if args.size() > 0 else "plain"
	print("PROBE mode=%s display=%s driver=%s method=%s" % [mode,
		DisplayServer.get_name(),
		RenderingServer.get_current_rendering_driver_name(),
		RenderingServer.get_current_rendering_method()])
	var rect := ColorRect.new()
	rect.color = Color(0.2, 0.6, 0.9)
	rect.size = Vector2(320, 180)
	root.add_child(rect)
	await process_frame
	await process_frame
	print("MARK-A two frames pumped")
	var target: Viewport = root
	match mode:
		"force":
			RenderingServer.force_draw()
			print("MARK-B force_draw returned")
		"forceawait":
			RenderingServer.force_draw()
			print("MARK-B force_draw returned")
			await RenderingServer.frame_post_draw
			print("MARK-C frame_post_draw fired")
		"await":
			await RenderingServer.frame_post_draw
			print("MARK-C frame_post_draw fired")
		"sub":
			var sub := SubViewport.new()
			sub.size = Vector2i(320, 180)
			sub.render_target_update_mode = SubViewport.UPDATE_ALWAYS
			var sub_rect := ColorRect.new()
			sub_rect.color = Color(0.9, 0.3, 0.2)
			sub_rect.size = Vector2(320, 180)
			sub.add_child(sub_rect)
			root.add_child(sub)
			await process_frame
			await process_frame
			print("MARK-B subviewport pumped")
			target = sub
		"subforce":
			var sv := SubViewport.new()
			sv.size = Vector2i(320, 180)
			sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
			var sv_rect := ColorRect.new()
			sv_rect.color = Color(0.9, 0.3, 0.2)
			sv_rect.size = Vector2(320, 180)
			sv.add_child(sv_rect)
			root.add_child(sv)
			await process_frame
			RenderingServer.force_draw()
			print("MARK-B sub pumped + force_draw returned")
			target = sv
		"device":
			var rd := RenderingServer.get_rendering_device()
			print("MARK-B rendering_device=%s adapter='%s' api='%s'" % [
				"null" if rd == null else "REAL",
				RenderingServer.get_video_adapter_name(),
				RenderingServer.get_video_adapter_api_version()])
			## A CPU-side texture created through the server: if even this reads
			## back null, the texture storage backend is a stub.
			var img_up := Image.create(4, 4, false, Image.FORMAT_RGBA8)
			img_up.fill(Color.RED)
			var rid := RenderingServer.texture_2d_create(img_up)
			var back := RenderingServer.texture_2d_get(rid)
			print("MARK-C uploaded 4x4 reads back %s" % (
				"null" if back == null else str(back.get_size())))
			RenderingServer.free_rid(rid)
		"deferredforce":
			## force_draw emits frame_post_draw SYNCHRONOUSLY, so awaiting after
			## calling it waits for a next draw that never comes. Defer the call,
			## then start listening before it runs.
			RenderingServer.call_deferred("force_draw")
			await RenderingServer.frame_post_draw
			print("MARK-C frame_post_draw fired after deferred force_draw")
		"connect":
			RenderingServer.frame_post_draw.connect(
				func() -> void: print("MARK-SIGNAL frame_post_draw emitted"))
			RenderingServer.frame_pre_draw.connect(
				func() -> void: print("MARK-SIGNAL frame_pre_draw emitted"))
			RenderingServer.force_draw()
			print("MARK-B force_draw returned (signals connected)")
			for _i in 3:
				await process_frame
			print("MARK-C three more frames pumped")
		_:
			pass
	print("MARK-D before get_texture")
	var tex := target.get_texture()
	print("MARK-E got texture %s, before get_image" % ("null" if tex == null else str(tex.get_size())))
	var img: Image = tex.get_image() if tex != null else null
	if img == null:
		print("MARK-F get_image returned NULL")
	else:
		var px := Color.BLACK
		if img.get_width() > 16 and img.get_height() > 16:
			px = img.get_pixel(8, 8)
		print("MARK-F get_image returned %s px(8,8)=%s" % [img.get_size(), px])
	quit(0)
