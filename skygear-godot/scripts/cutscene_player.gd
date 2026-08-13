class_name SkyGearCutscenePlayer
extends Node

## Plays a cutscene on the REAL camera, and gives it back exactly as it was.
##
## THE SECOND HALF OF THAT SENTENCE IS THE WHOLE JOB. The gameplay camera is
## four constants and one solve (`SkyGearView3D.camera_back`), and three other
## systems are calibrated against the projection it produces: every attack
## telegraph is drawn on the deck at a size that assumes it, every billboard's
## height was chosen against it, and every sprite in `assets/` was PAINTED for
## it. A cutscene that returns a camera one degree or one millimetre off leaves
## the rest of the run subtly wrong, and nothing on screen says so.
##
## So the rule this file is built around: **a cutscene may write the camera's
## transform and its lens, and nothing else.** It never touches `_focus`,
## `_zoom`, `_roll`, `_yaw` or any other piece of camera STATE, so the frame
## after it ends, `_track_camera` recomputes the same transform it would have
## computed had the cutscene never run. The two things that are not recomputed
## every frame — `fov`, and the near/far planes — are saved on the way in and
## written back on the way out.
##
## The harness pins it: `cutscene · the gameplay camera comes back exactly` and
## the two checks under it. That check compares the full transform and the lens
## against a snapshot taken before the scene, and it fails if a cutscene that
## moved the camera 900 units and changed the field of view leaves either.
##
## Everything else it borrows — the HUD's visibility, the captain's controls —
## is saved and restored the same way, and out of the same `stop()`.

## Bars in and out. Long enough to read as a deliberate framing change, short
## enough that a 2-second shot is not half bars sliding.
const BAR_TIME := 0.32
## Over the HUD, which is layer 10 in `main.tscn`. The bars are the outermost
## thing on the screen while a shot runs.
const BAR_LAYER := 60

## UNTYPED, AND THAT IS DELIBERATE. `SkyGearView3D` holds one of these, and the
## renderer in turn reaches `SkyGearGame`, which reaches `SkyGearHUD`, which
## reaches back to the renderer. Naming either class here closes that ring and
## GDScript refuses the whole graph with "could not resolve external class
## member" — which it did, on the first run of the lab, and the message names a
## file that has nothing to do with the cycle.
##
## So this file names neither. It reads `view.camera`, `view.game`, `game.hud`
## and `game.player` dynamically, and the one piece of game state it needs is
## compared as a STRING (`state_name`) rather than through the enum. The
## renderer hands it the two sway numbers rather than being asked for them.
var view
var scene: Dictionary = {}
var time := 0.0
var playing := false
## This frame's ship motion, in degrees, written by the renderer before
## `advance` because the renderer is the one that owns `SWAY_ROLL`.
var sway_roll := 0.0
var sway_yaw := 0.0
## Set when the player skipped. Read by nothing yet except the log line; kept
## because "did anyone ever watch this" is the question you want to be able to
## ask of a cutscene later, and the hook has to exist before the telemetry can.
var skipped := false

## What was here before. Every one of these is written back in `stop()`.
var _saved_fov := 0.0
var _saved_near := 0.0
var _saved_far := 0.0
var _saved_hud := true
var _saved_controls := true
var _had_save := false

var _bars: CanvasLayer
var _top: ColorRect
var _bottom: ColorRect
var _caption: Label
var _skip_hint: Label


func _init() -> void:
	## Input is only wanted while a shot is running, and a node that eats clicks
	## the rest of the time would be a very quiet way to break the whole game.
	set_process_unhandled_input(false)


func active() -> bool:
	return playing


## Fire a named moment. Lives here rather than on the renderer because the
## renderer must not name `SkyGearCutscene` either — same cycle, see above.
## Returns whether a shot actually started, so a call site can tell "nothing is
## wired to this moment" apart from "it is running".
func cue(name: String, wave_number: int = 0) -> bool:
	if playing:
		return false
	var id := SkyGearCutscene.for_cue(name, wave_number)
	if id == "":
		return false
	return play(id)


func play(id: String) -> bool:
	var next := SkyGearCutscene.load_scene(id)
	if next.is_empty():
		return false
	return begin(next)


func camera() -> Camera3D:
	return view.camera if view != null else null


## Start one. Returns false and changes nothing when the scene has no keys —
## a malformed file must never be able to take the camera away from the player.
func begin(next: Dictionary) -> bool:
	if view == null or view.camera == null:
		return false
	if next.is_empty() or (next.get("keys", []) as Array).is_empty():
		return false
	if SkyGearCutscene.length(next) <= 0.0:
		return false
	## Already running: stop the old one properly first, so its restore lands
	## before the new one takes its own snapshot. Without this a second cutscene
	## overwrites the saved lens with the FIRST cutscene's lens and the game gets
	## a cutscene camera back permanently.
	if playing:
		stop()
	## Pins resolved ONCE, here, against where the gameplay camera is at this
	## instant. Not per frame: `_focus` keeps easing toward the captain while the
	## shot runs, and a pinned key that moved underneath the interpolation would
	## make the last second of every cutscene drift.
	scene = SkyGearCutscene.bind(next, view._focus)
	time = 0.0
	skipped = false
	playing = true
	_snapshot()
	_build_bars()
	pose_at(0.0)
	set_process_unhandled_input(true)
	return true


## Everything borrowed, written down. Nothing below here is allowed to run twice
## without a `stop()` between — see the guard in `begin`.
func _snapshot() -> void:
	var cam := camera()
	_saved_fov = cam.fov
	_saved_near = cam.near
	_saved_far = cam.far
	_saved_hud = true
	_saved_controls = true
	var game = view.game
	if game != null:
		if game.hud != null:
			_saved_hud = game.hud.visible
			if bool(scene.get("hide_hud", true)):
				game.hud.visible = false
		if game.player != null:
			_saved_controls = game.player.controls_enabled
			if bool(scene.get("hold", true)):
				## She stops rather than freezes: `_physics_process` still brakes
				## her to a halt when controls are off, which reads as the captain
				## stopping to look rather than as the game hanging.
				game.player.controls_enabled = false
	_had_save = true


## Give it all back. Idempotent, and safe to call when nothing is running —
## every abort path in the renderer funnels through here rather than each
## working out its own undo.
func stop() -> void:
	playing = false
	set_process_unhandled_input(false)
	if _had_save and view != null and view.camera != null:
		var cam: Camera3D = view.camera
		cam.fov = _saved_fov
		cam.near = _saved_near
		cam.far = _saved_far
		var game = view.game
		if game != null:
			if game.hud != null:
				game.hud.visible = _saved_hud
			if game.player != null:
				## Recomputed from the state rather than played back, because the
				## state may have MOVED while the shot ran — a run that ended
				## during a victory cutscene must not hand the controls back. The
				## expression is `_set_state`'s own, spelled through `state_name`
				## for the reason at the top of this file.
				game.player.controls_enabled = _saved_controls \
					and str(game.state_name) == "PLAY"
	_had_save = false
	scene = {}
	time = 0.0
	_drop_bars()


## One frame. Called from `SkyGearView3D._process` AFTER `_track_camera`, so the
## gameplay solve runs first and this overwrites its result — which is what
## makes "stop overriding" a complete restore.
func advance(delta: float) -> void:
	if not playing:
		return
	## A cutscene is a camera, and a camera has no business running while the
	## player is in a menu. Anything that is not the fight or an ending ends the
	## shot — a pause, a draft, or a drop back to the title.
	var game = view.game if view != null else null
	if game != null and not ["PLAY", "VICTORY", "GAMEOVER"].has(str(game.state_name)):
		stop()
		return
	time += delta
	var total := SkyGearCutscene.length(scene)
	if time >= total:
		## Hold the last frame for nothing: pose it exactly, then hand back. A
		## cutscene that ends one frame short of its final keyframe never shows
		## the pose it was authored to end on.
		pose_at(total)
		stop()
		return
	pose_at(time)
	_fade_bars(delta)


## Put the camera at a time. The one place playback, the lab's scrub bar and the
## headless shot all go through, so a frame verified in the tool is the frame
## the game plays.
func pose_at(at: float) -> void:
	var cam := camera()
	if cam == null or scene.is_empty():
		return
	var shot := SkyGearCutscene.sample(scene, at)
	## The ship's own motion, handed over by the renderer rather than recomputed
	## here. Both numbers are already this frame's, because `_track_camera` ran
	## first — and a second copy of the sway would be a second copy of a number
	## three other systems read, which is this project's most expensive habit.
	var on := bool(scene.get("sway", true))
	SkyGearCutscene.aim(cam, shot, sway_roll if on else 0.0, sway_yaw if on else 0.0)


# ------------------------------------------------------------------- the bars --

## WHAT THE CARD SAYS, and why it is not always what the file says (board SG-283).
##
## `view3d._watch_cues` fires `cue("defeat")` on ANY transition into GAMEOVER, and
## the simulation reaches that state from two different places: the hero falling
## (`game.gd`, `player.hp <= 0.0`) and the Boiler being destroyed. There is one
## defeat scene, and its `caption` was the constant string "THE BOILER IS LOST" —
## so a player killed by a furnace knight on wave 7, with the Boiler untouched,
## was told full-screen that the Boiler was lost, and then read the truth on the
## results sheet immediately behind it. One fact, known in two places, disagreeing
## — the sixth recurring failure mode, on a screen nobody can look away from.
##
## THE FIX IS ONE MORE READER, NOT ONE MORE FILE. A second `defeat_hero.json`
## would put the wording of a defeat in two files and invite exactly the drift
## that caused this. A scene may instead declare `"caption_from": "end_reason"`,
## and then the card says whatever the SIMULATION already decided to call this
## ending — the same string `hud.gd` prints under the verdict, written once at
## `game.gd`'s two `_set_state` sites and pinned by
## `runs · the defeat line names the class that actually fell`.
##
## The literal `caption` stays in the file and stays the fallback, so a scene with
## no reason to offer — a posed shot, a cutscene played out of the lab — still has
## a card, and a malformed key can only ever cost the sentence its specificity.
const CAPTION_FROM_REASON := "end_reason"


func _caption_text() -> String:
	var written := str(scene.get("caption", ""))
	if str(scene.get("caption_from", "")) != CAPTION_FROM_REASON:
		return written
	var game = view.game if view != null else null
	if game == null:
		return written
	var reason := str(game.end_reason).strip_edges()
	if reason == "":
		return written
	## Upper case because every other card in the set is, and without the full
	## stop: `end_reason` is a SENTENCE ("The Boilerwright fell on wave 7.")
	## because it is printed as one, and a caption is a title.
	return reason.trim_suffix(".").to_upper()


## Letterbox, a caption and a line saying how to leave. Built in code and thrown
## away with the shot rather than living in the HUD, for two reasons: `hud.gd`
## is one file with every screen in it and this is not a screen, and a cutscene
## that hides the HUD cannot then draw its caption inside it.
func _build_bars() -> void:
	_drop_bars()
	var height := clampf(float(scene.get("letterbox", 0.12)), 0.0, 0.3)
	_bars = CanvasLayer.new()
	_bars.layer = BAR_LAYER
	add_child(_bars)
	for top in [true, false]:
		var bar := ColorRect.new()
		bar.color = Color(0.0, 0.0, 0.0, 1.0)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.set_anchors_preset(Control.PRESET_TOP_WIDE if top
			else Control.PRESET_BOTTOM_WIDE)
		bar.anchor_bottom = height if top else 1.0
		bar.anchor_top = 0.0 if top else 1.0 - height
		bar.offset_bottom = 0.0
		bar.offset_top = 0.0
		_bars.add_child(bar)
		if top:
			_top = bar
		else:
			_bottom = bar
	## Scaled in from nothing, so the frame closes rather than appearing closed.
	_top.scale.y = 0.0
	_bottom.scale.y = 0.0

	_caption = Label.new()
	_caption.text = _caption_text()
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_caption.anchor_top = 1.0 - height
	_caption.offset_top = 10.0
	_caption.offset_bottom = 0.0
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	## Bone on black inside the bar, so contrast is never the question — but the
	## SIZE still goes through the one floor this project has, because a caption
	## is text and every other piece of text in the build is held to it.
	_caption.add_theme_font_size_override("font_size", int(SkyGearInk.MIN_PT * 2.2))
	_caption.add_theme_color_override("font_color", Color("#efe6d8"))
	_caption.add_theme_color_override("font_outline_color", SkyGearInk.INK)
	_caption.add_theme_constant_override("outline_size", int(SkyGearInk.OUTLINE * 2.0))
	_bars.add_child(_caption)

	_skip_hint = Label.new()
	_skip_hint.text = "CLICK TO SKIP"
	_skip_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_skip_hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_skip_hint.anchor_top = 1.0 - height * 0.5
	_skip_hint.offset_right = -26.0
	_skip_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_skip_hint.add_theme_font_size_override("font_size", SkyGearInk.MIN_PT)
	_skip_hint.add_theme_color_override("font_color", Color("#8f8697"))
	_bars.add_child(_skip_hint)


func _fade_bars(delta: float) -> void:
	if _top == null:
		return
	var total := SkyGearCutscene.length(scene)
	## In at the head, out at the tail, and fully open in between. Driven off the
	## scene clock rather than a tween so that SCRUBBING in the lab shows the
	## bars where they will actually be at that instant.
	var open: float = clampf(time / maxf(0.0001, BAR_TIME), 0.0, 1.0)
	var close: float = clampf((total - time) / maxf(0.0001, BAR_TIME), 0.0, 1.0)
	var amount: float = minf(open, close)
	_top.scale.y = amount
	_bottom.scale.y = amount
	## The bottom bar grows upward from the screen edge rather than down off it.
	_bottom.pivot_offset = Vector2(0.0, _bottom.size.y)
	if _caption != null:
		_caption.modulate.a = amount
	if _skip_hint != null:
		_skip_hint.modulate.a = amount * 0.85


func _drop_bars() -> void:
	if _bars != null:
		_bars.queue_free()
		_bars = null
	_top = null
	_bottom = null
	_caption = null
	_skip_hint = null


# ------------------------------------------------------------------- the skip --

## ANY CLICK, or the spacebar. Deliberately not ESC — ESC is pause everywhere
## else in this game and a key that means two things is a key that does the
## wrong one. And deliberately a MOUSE button first: the machine this is
## authored on has no page keys and no numpad, and a skip you have to find on
## the keyboard is a skip nobody finds.
##
## This node is added to the renderer AFTER the game scene, so unhandled input
## reaches it first (Godot walks the tree in reverse). It only consumes while a
## shot is actually running.
func _unhandled_input(event: InputEvent) -> void:
	if not playing:
		return
	var wants := false
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		var button := (event as InputEventMouseButton).button_index
		wants = button == MOUSE_BUTTON_LEFT or button == MOUSE_BUTTON_RIGHT
	elif event is InputEventKey and (event as InputEventKey).pressed \
			and not (event as InputEventKey).echo:
		wants = (event as InputEventKey).keycode == KEY_SPACE
	if not wants:
		return
	skipped = true
	get_viewport().set_input_as_handled()
	stop()
