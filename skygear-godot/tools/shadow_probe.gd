extends SceneTree
## ONE SHADOW AUTHORITY, UNDER ITS OWN KILL-TEST.
##
## DECK-IDENTITY item 2 pre-committed this before a line was written, and it
## pre-committed an outcome most features do not get offered:
##
##   *"renders the bench pose three ways: today's ellipse, the corrected pool,
##   and the batch switched off entirely. If OFF is not measurably worse than
##   today, THE BLOB LAYER IS DELETED and the moon does the whole job — that
##   outcome is allowed to win. If corrected differs from today by under 3% of
##   deck-region pixels at zoom 1.0, only the height falloff ships."*
##
## So this tool has to be able to lose the feature, and it is written to.
##
##   godot --path . --resolution 1600x900 --script tools/shadow_probe.gd -- <outdir>
##
## TWO PASSES, ONE PROCESS (SG-108). The item's question has two halves and they
## are not the same measurement:
##
##   QUIET  — a deck with people on it and nothing in the air. This is the pass
##            that answers "is the blob under a boarder doing any work", and it
##            is also the pass whose plates a person can actually LOOK at. The
##            first version of this tool had one pass and it waited for ordnance,
##            which meant it caught the captain mid-swing: `.shots/sg107`'s first
##            set is dominated by a fire arc across the middle of the frame and
##            the contact cores under the figures cannot be judged in it at all.
##   ORDNANCE — the same deck with bolts in flight, which is the only pass that
##            can witness §13c's height falloff, because a projectile's mark is
##            the thing the falloff is about.
##
## EVERYTHING IS FROZEN THROUGH `tools/still.gd` AND NOWHERE ELSE. This tool used
## to carry its own copy of the freeze and it was the fourth in a chain of tools
## each rediscovering one more clock the last one had missed. The chain ends at
## one helper; see SG-108 and `still.gd`'s header.
##
## THE NOISE FLOOR IS NOT A PRINT-OUT ANY MORE, IT IS A REFUSAL. Two plates with
## nothing changed between them must differ by EXACTLY zero. Anything else and
## every number below it is the renderer moving, not the feature — this tool read
## 53% before the AnimationPlayers were found, and it reported three confident
## wrong answers against that floor first.
const DECK_BOX := Rect2i(240, 200, 1160, 620)
## The item's own number.
const PIXEL_GATE := 3.0

var _out_dir := "../.shots/sg107"


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
	game.set_seed_text("SHADOW")
	game.begin_run()
	game.choose_draft(0)
	if game.wave != 8:
		game.start_wave(8)
	game.spawn_queue.clear()
	view.sway = false
	var overlay = game.get_node_or_null("HUD")
	if overlay != null:
		overlay.visible = false

	## THE BENCH POSE: a deck with people on it. A shadow item measured on an
	## empty deck measures nothing at all.
	game.player.global_position = Vector2(0.0, 240.0)
	game.player.velocity = Vector2.ZERO
	var kinds := ["SCRAPPER", "ARMORED", "SWARM", "GUNNER"]
	for i in 16:
		game.spawn_enemy(kinds[i % kinds.size()], 1)
	var live: Array = game.get_tree().get_nodes_in_group("enemies")
	for i in live.size():
		var col: int = i % 4
		var row: int = i / 4
		live[i].global_position = Vector2(-540.0 + float(col) * 360.0,
			-260.0 + float(row) * 300.0)
		live[i].state = "move"
	view._focus_set = false
	view._zoom = 1.0
	view._zoom_target = 1.0
	for _i in 30:
		game._process(1.0 / 60.0)
		await process_frame

	print("")
	print("  ONE SHADOW AUTHORITY — THE PRE-COMMITTED KILL-TEST")
	print("  a wave-8 deck, sixteen boarders and the captain, zoom 1.00")
	print("  deck region %s" % str(DECK_BOX))
	print("")

	var quiet := await _pass(view, game, out_dir, "shadow", false)
	if int(quiet.get("bad", 0)) != 0:
		quit(6)
		return
	await SkyGearStill.thaw(self, view, game)
	var loud := await _pass(view, game, out_dir, "shadow-ord", true)
	if int(loud.get("bad", 0)) != 0:
		quit(6)
		return

	print("  marks in the flush %d, of which contact cores %d — that many figures"
		% [view.multimesh_shadow_count(), view._shadow_cores_last])
	print("  on this deck the moon is already drawing for itself")
	print("")

	var off_vs_today: float = float(loud.off_vs_today)
	var fixed_vs_today: float = float(loud.fixed_vs_today)
	var fixed_vs_off: float = float(loud.fixed_vs_off)

	## THE OUTCOMES, IN THE ORDER THE DESIGN PUT THEM — AND THE ONE THING THE
	## DESIGN DID NOT NOTICE ABOUT ITS OWN FIRST BRANCH.
	if off_vs_today < PIXEL_GATE:
		print("  THE DELETE GATE HAS FIRED, and it is reported rather than obeyed.")
		print("")
		print("  Switching the batch off moves %.2f%% of deck pixels against today,"
			% off_vs_today)
		print("  under the 3%% the item set. On a deck where every figure is now a")
		print("  MESH, the moon already draws them, and a 41-degree camera puts each")
		print("  figure in front of most of its own blob — so the sticker really is")
		print("  nearly invisible under a boarder. That half of the finding is real")
		print("  and it is why the mesh figures here drop to contact cores.")
		print("")
		print("  BUT THE GATE CONTRADICTS §13c, WHICH THE SAME DOCUMENT CALLS")
		print("  NON-NEGOTIABLE. 'Delete the blob layer and let the moon do the")
		print("  whole job' cannot be right for the two cases the moon CANNOT do:")
		print("    · a projectile's mark, which must sit directly under the bolt")
		print("      because it is what tells you where it will cross you — the")
		print("      moon's shadow of a bolt lands 0.44 of its height to port,")
		print("      which is an answer to a question nobody asked;")
		print("    · a painted BILLBOARD, which casts nothing at all, so its blob")
		print("      is the only thing holding it to the planking.")
		print("")
		print("  This measurement is over FIGURES. It is not evidence about either")
		print("  of those, and the layer is not deleted on it. The owner's call,")
		print("  with these numbers, is in NEEDS_ALEX.")
		print("")
		quit(4)
		return
	if fixed_vs_today < PIXEL_GATE:
		print("  NOTE: corrected differs from today by %.2f%%, under the item's 3%%."
			% fixed_vs_today)
		print("  The item says only the height falloff ships in that case. Recorded.")
		quit(5)
		return
	print("  VERDICT: THE AUTHORITY SHIPS WHOLE. The blob layer is doing real work")
	print("           (%.2f%% of deck pixels against OFF) and the correction is" % fixed_vs_off)
	print("           visible against today at %.2f%%." % fixed_vs_today)
	print("")
	quit(0)


## ONE PASS: settle, freeze, four plates, three numbers.
##
## `want_ordnance` decides which of the item's two halves this is. The quiet pass
## additionally CLEARS THE EFFECT LIST at the last live frame, which is the whole
## reason it is legible: a wave-8 captain swings on her own clock and a fire arc
## across the middle of the frame is not a picture anybody can judge a contact
## core in.
func _pass(view: SkyGearView3D, game: SkyGearGame, out_dir: String,
		slug: String, want_ordnance: bool) -> Dictionary:
	var waited := 0
	if want_ordnance:
		## WAIT FOR SOMETHING TO BE IN THE AIR. The height half of this item is
		## about projectiles, so a plate with no projectile in it cannot witness
		## it. The gunners fire on their own clock; the loop stops on the first
		## frame that has ordnance in flight rather than at a fixed count, because
		## "run for four seconds and hope" is how a tool ends up photographing an
		## empty sky half the time.
		game.projectiles.clear()
		while game.projectiles.size() < 2 and waited < 900:
			game._process(1.0 / 60.0)
			await process_frame
			waited += 1
	else:
		## A QUIET TICK. Nothing in the air, nothing swinging, no fire arc. The
		## effects list is cleared on the last live frame and the freeze below
		## means nothing re-authors it.
		for _i in 4:
			game._process(1.0 / 60.0)
			await process_frame
		game.effects.clear()
		game.projectiles.clear()
		for e in game.get_tree().get_nodes_in_group("enemies"):
			if is_instance_valid(e):
				e.state = "move"
		game._process(1.0 / 60.0)
		await process_frame

	var stopped := await SkyGearStill.freeze(self, view, game)
	print("  %s pass — %d rigs and %d particle systems stopped, ordnance in flight %d"
		% [slug, int(stopped.animation_players), int(stopped.particles),
			game.projectiles.size()])

	## THE PRE-COMMITTED CHECK, AND IT IS A REFUSAL RATHER THAN A PRINT-OUT.
	## Two plates, nothing changed between them. If this is not exactly zero the
	## renderer is not still and every number below it is that, not shadows.
	## Through the SAME re-flush the three real comparisons below go through,
	## because a control that skips it is not a control for them.
	var noise := await SkyGearStill.floor_pct(self, DECK_BOX,
		func() -> void: view._process(0.0))
	print("  still · two plates of a frozen scene differ by exactly zero   %.2f%%"
		% noise)
	if noise != 0.0:
		var m1 := await SkyGearStill.plate(self, DECK_BOX)
		view._process(0.0)
		var m2 := await SkyGearStill.plate(self, DECK_BOX)
		SkyGearStill.save_mask(m1, m2, DECK_BOX,
			"%s/%s-notstill.png" % [out_dir, slug])
		print("  WHAT MOVED is in %s-notstill.png — white is a pixel that changed."
			% slug)
		print("")
		print("  REFUSED. The scene is not still, so there is nothing here to")
		print("  measure. This tool read 53%% before SG-108 found the cause and it")
		print("  gave three confident wrong answers against that floor first.")
		print("")
		return {"bad": 1}

	view.shadow_legacy = true
	view._process(0.0)
	var today := await SkyGearStill.plate(self, DECK_BOX,
		"%s/%s-today.png" % [out_dir, slug])
	view.shadow_legacy = false
	view._process(0.0)
	var fixed := await SkyGearStill.plate(self, DECK_BOX,
		"%s/%s-corrected.png" % [out_dir, slug])
	view._shadow_batch.visible = false
	view._process(0.0)
	var off := await SkyGearStill.plate(self, DECK_BOX,
		"%s/%s-off.png" % [out_dir, slug])
	view._shadow_batch.visible = true

	var out := {
		"fixed_vs_today": SkyGearStill.moved_pct(today, fixed),
		"off_vs_today": SkyGearStill.moved_pct(today, off),
		"fixed_vs_off": SkyGearStill.moved_pct(off, fixed),
		"bad": 0,
	}
	print("    corrected vs today    %5.2f%% of deck pixels moved" % out.fixed_vs_today)
	print("    OFF vs today          %5.2f%% of deck pixels moved" % out.off_vs_today)
	print("    corrected vs OFF      %5.2f%% of deck pixels moved" % out.fixed_vs_off)
	print("    mean deck luminance   today %.3f · corrected %.3f · off %.3f"
		% [SkyGearStill.lum(today), SkyGearStill.lum(fixed), SkyGearStill.lum(off)])
	print("")
	return out
