extends SceneTree
## DOES THE FIRE POOL'S PICTURE MATCH ITS BURN? (board SG-163, owner: *"For the
## fire hitbox, match the burn size. Fix the picture to match the damage."*)
##
##   godot --path . --resolution 1600x900 --script tools/pool_shot.gd -- .shots/sg160
##
## NOT `--headless`: the whole output is a PNG and headless makes PNGs empty.
##
##
## WHY THIS IS NOT A SCREENSHOT OF A POOL.
##
## A picture of a fire pool cannot tell you whether it is the right size, because
## the thing it would have to be compared against — the burn — has no pixels. So
## this tool gives the burn pixels, and it does NOT do it by drawing a ring at
## `fire_pool_radius()`: that would be a picture of the same number the pool is
## already drawn from, which proves only that the number equals itself. That is
## the fifth failure mode in STATUS.md, and it is exactly how a "fixed" version
## of this bug would photograph.
##
## THE BURN IS MEASURED INSTEAD. The captain is walked to a grid of positions
## around the pool, one tick of `_update_fire_fields` is run at each, and whether
## her HP moved is recorded. Every sample is then marked on the planking — RED
## where the simulation burned her, TEAL where it did not. The red patch is the
## hazard's true footprint, drawn by the damage path rather than by the renderer,
## and the question the owner asked is simply whether it lines up with the orange.
##
## `damage-*.png` is the deliverable. `gap-*.png` is the same frame with a second
## ring added at 46 — the radius the Sear trail's pool used to be DRAWN at while
## burning at 78 — so the band of deck that looked clear and was not is visible
## rather than described. That annotation is the tool's, not the game's, and it is
## labelled here so nobody mistakes it for something the renderer draws.

## The pool is put at deck centre and the captain is framed with it.
const POOL_AT := Vector2(0.0, 300.0)
## Out past any radius either side of this argument has ever claimed.
const PROBE_MAX := 130.0
const PROBE_STEP := 6.5
const PROBE_RAYS := 48
## What the picture used to be sized from: the Sear trail's `trail_radius`.
const OLD_DRAWN := 46.0


func _initialize() -> void: call_deferred("_run")


func _run() -> void:
	var argv := OS.get_cmdline_user_args()
	var out_dir: String = str(argv[0]) if argv.size() > 0 else ".shots/sg160"
	DirAccess.make_dir_recursive_absolute(out_dir)

	var world = load("res://scenes/main3d.tscn").instantiate()
	root.add_child(world)
	await process_frame
	var view: SkyGearView3D = world as SkyGearView3D
	var game: SkyGearGame = world.get_node("SkyGear")
	game.log_runs = false
	game.workshop = SkyGearWorkshop.fresh(true)
	game.heat = 0
	game.set_class("captain")
	game.set_seed_text("SG160")
	game.begin_run()
	game.choose_draft(0)
	game.start_wave(3)
	game.spawn_queue.clear()
	view.cutscenes_enabled = false
	view.stop_cutscene()
	view.sway = false
	var overlay = game.get_node_or_null("HUD")
	if overlay != null:
		overlay.visible = false

	## Settle the camera over the pool with the sim still running, then stop it.
	game.player.global_position = POOL_AT + Vector2(0.0, 40.0)
	for _i in 40:
		game._process(1.0 / 60.0)
		game.player.global_position = POOL_AT + Vector2(0.0, 40.0)
		await process_frame
	game.set_process(false)
	game.effects.clear()

	## ------------------------------------------------------------------
	## MEASURE THE BURN. Nothing about the renderer is consulted here.
	##
	## The EDGE is what is marked rather than every sample: on each of 48 rays out
	## from the pool, the last spot that burned and the first spot that did not.
	## Two dots per ray is a dotted ring standing exactly on the hazard's true
	## boundary, which is the comparison the owner asked for — a field of dots
	## would show the same fact and hide the orange line underneath it.
	## ------------------------------------------------------------------
	var burned: Array[Vector2] = []
	var clear_pts: Array[Vector2] = []
	var max_burn := 0.0
	var min_clear := 9999.0
	for k in PROBE_RAYS:
		var ang: float = TAU * float(k) / float(PROBE_RAYS)
		var dir := Vector2(cos(ang), sin(ang))
		var last_hot := -1.0
		var first_cold := -1.0
		var r := PROBE_STEP
		while r <= PROBE_MAX:
			if _burns_at(game, POOL_AT + dir * r):
				last_hot = r
			elif first_cold < 0.0:
				first_cold = r
			r += PROBE_STEP
		if last_hot > 0.0:
			burned.append(POOL_AT + dir * last_hot)
			max_burn = maxf(max_burn, last_hot)
		if first_cold > 0.0:
			clear_pts.append(POOL_AT + dir * first_cold)
			min_clear = minf(min_clear, first_cold)

	## ------------------------------------------------------------------
	## AND PUT THE POOL BACK, so the frame photographs a real live pool.
	## ------------------------------------------------------------------
	game.fire_fields.clear()
	## THE CAPTAIN LEAVES THE POOL AND THE CAMERA STAYS ON IT.
	##
	## She has to be walked all over this hazard to measure it and she has no
	## business standing in the photograph of it — a figure on top of the boundary
	## is the exact occlusion SG-158 measured for the wedge. But `set_process(false)`
	## does NOT park the camera, which is the SG-118 trap in this tool's own words:
	## the captain is her own node and the follow runs on the VIEW's clock, so the
	## first version of this walked her 900 units off, watched the camera chase her
	## to the bow, and photographed an empty rail with the pool in the top corner.
	## The focus is pinned on the POOL instead, which is the thing being measured.
	game.player.global_position = POOL_AT + Vector2(-230.0, 210.0)
	game.player.hp = game.player.max_hp
	game._field({"position": POOL_AT, "radius": OLD_DRAWN, "time": 999.0, "tick": 0.4})
	view._focus = POOL_AT
	view._focus_set = true
	view._zoom = 1.0
	view._zoom_target = 1.0
	for _i in 4:
		view._process(0.016)
		view._focus = POOL_AT
		await process_frame

	var burn_r: float = game.fire_pool_radius()
	var drawn_r := -1.0
	var fid: int = int(game.fire_fields[0].id)
	if view._decals.has("fire%d" % fid):
		drawn_r = (view._decals["fire%d" % fid].size.x * 0.5
			/ SkyGearView3D.WORLD_SCALE) * SkyGearView3D.RING_RIM_D

	print("")
	print("  DOES THE FIRE POOL'S PICTURE MATCH ITS BURN?")
	print("")
	print("    the pool was MADE with radius %.0f, the way the Sear trail makes one" % OLD_DRAWN)
	print("    the simulation's burn radius        %.1f" % burn_r)
	print("    the radius the renderer drew        %.1f" % drawn_r)
	print("")
	print("    MEASURED, by walking the captain and running one tick at each spot:")
	print("      furthest sample that BURNED       %.1f" % max_burn)
	print("      nearest sample that did NOT       %.1f" % min_clear)
	print("      %d burned · %d clear, %d samples total"
		% [burned.size(), clear_pts.size(), burned.size() + clear_pts.size()])
	print("")
	print("    the drawn line misses the measured burn by %.1f units (probe step %.1f)"
		% [absf(drawn_r - max_burn), PROBE_STEP])
	print("    before SG-163 this pool was drawn at %.0f and burned at %.0f — a %.0f%% gap"
		% [OLD_DRAWN * 1.1 * 0.82, burn_r,
			100.0 * (burn_r / maxf(1.0, OLD_DRAWN * 1.1 * 0.82) - 1.0)])
	print("")

	## FROZEN (SG-108), and the harness made this tool say so before it would go
	## green: `set_process(false)` does not stop an AnimationPlayer or a particle
	## clock, and three plates of the same pool taken across a running flame are
	## three different pools. The captain is in frame at the edge of this shot and
	## she was mid-stride in every draft before this line existed.
	await SkyGearStill.freeze(self, view, game)

	## The pool alone, as the player sees it.
	await _snap("%s/pool-as-drawn.png" % out_dir)

	## THE MEASURED BURN, ON TOP OF IT.
	##
	## The marks are the TOOL'S OWN GEOMETRY, not decals, and that is not fussiness:
	## the decal pool is budgeted at 40 DECOR slots and 96 markers would silently
	## evict the pool this tool exists to photograph — a rig destroying its own
	## subject, which is the fifth failure mode with a new hat on. They are plain
	## unshaded posts parented to the world.
	var marks := Node3D.new()
	world.add_child(marks)
	for p in burned:
		_post(marks, p, Color(0.62, 0.06, 0.05))
	for p in clear_pts:
		_post(marks, p, Color(0.08, 0.52, 0.43))
	view._process(0.016)
	view._focus = POOL_AT
	await _snap("%s/damage-over-picture.png" % out_dir)

	## AND THE GAP THAT USED TO BE THERE. A white ring of posts at 46, which is
	## where this pool's picture used to end while it went on burning to 78.
	## TOOL ANNOTATION, not a thing the renderer draws.
	for k in PROBE_RAYS:
		var a2: float = TAU * float(k) / float(PROBE_RAYS)
		_post(marks, POOL_AT + Vector2(cos(a2), sin(a2)) * OLD_DRAWN,
			Color(0.72, 0.72, 0.78))
	view._process(0.016)
	view._focus = POOL_AT
	await _snap("%s/gap-the-old-picture-left.png" % out_dir)

	print("  three plates in %s/" % out_dir)
	print("")
	quit(0)


## One tick of the real hazard at one spot. `damage_player` returns early outside
## PLAY, and a fire tick deliberately grants no i-frames (SG-117) — but the
## captain may still be holding a window from the previous sample, so it is
## cleared. Nothing here reads a radius from anywhere.
func _burns_at(game: SkyGearGame, at: Vector2) -> bool:
	game.fire_fields.clear()
	game._field({"position": POOL_AT, "time": 999.0, "tick": 0.0})
	game.state = SkyGearGame.State.PLAY
	game.player.global_position = at
	game.player.max_hp = 100000.0
	game.player.hp = 100000.0
	game.player.invulnerability_left = 0.0
	var before: float = game.player.hp
	game._update_fire_fields(0.0)
	return game.player.hp < before - 0.0001


## One sample marker: a short unshaded post standing on the planking, tall enough
## to be read at the shipped 41° camera and thin enough not to cover the line it
## is being compared against.
func _post(parent: Node3D, at: Vector2, colour: Color) -> void:
	var m := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 2.2 * SkyGearView3D.WORLD_SCALE
	cyl.bottom_radius = 2.2 * SkyGearView3D.WORLD_SCALE
	cyl.height = 15.0 * SkyGearView3D.WORLD_SCALE
	m.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	## KEPT UNDER THE BLOOM THRESHOLD. The first cut used full-saturation 1.0 red
	## and every marker came back WHITE: the deck's glow pass picks up anything
	## bright and the posts marking the boundary became a white smear across the
	## boundary. A rig that erases what it is pointing at is the fifth failure mode
	## again — these sit at about 0.6 so they stay the colour they mean.
	mat.albedo_color = colour
	mat.disable_receive_shadows = true
	m.material_override = mat
	m.position = Vector3(at.x * SkyGearView3D.WORLD_SCALE,
		7.5 * SkyGearView3D.WORLD_SCALE, at.y * SkyGearView3D.WORLD_SCALE)
	parent.add_child(m)


func _snap(path: String) -> void:
	for _i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png(path.replace("\\", "/"))
	print("  %s" % path)
