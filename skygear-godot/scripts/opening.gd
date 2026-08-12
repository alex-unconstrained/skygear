class_name SkyGearOpening
extends CanvasLayer

## THE OPENING CINEMATIC — the ~54 seconds before the title screen.
##
## Not to be confused with `scripts/cutscene.gd`, which is a completely
## different thing that happens to share the word: that plays a CAMERA move over
## the live deck at four named moments in a run. This plays a rendered film,
## once, at boot, and then gets out of the way for ever.
##
## WHAT IT PLAYS. `assets/video/opening.ogv` — nine shots generated on the local
## MiniMax H3 from the game's own hand-authored art, cut and mixed by
## `tools/cutscene_stitch.py` against the storyboard in `docs/cutscene/`. Ogg
## Theora because Godot's `VideoStreamPlayer` plays Theora and nothing else; an
## .mp4 in `assets/` is a file the engine cannot open.
##
## THREE RULES, and each of them is a way a first-time player gets annoyed:
##
##   1. **It is skippable from the first frame.** Any key, any click. A trailer
##      you cannot escape is the first thing a demo player will hold against
##      the game, and the second launch is the one that matters.
##   2. **It plays once.** The flag lives in `settings.cfg` beside fullscreen
##      and the volumes (`SkyGearAudio`), because that file is already the one
##      the game persists preferences to and a second settings file for one
##      boolean is a second settings file. A player who wants it again has
##      REPLAY THE OPENING on the title.
##   3. **A missing film is not a failure.** No `opening.ogv` on disk — a source
##      checkout that has never run the renderer, or an export that dropped the
##      folder — and this frees itself on the first frame and the game boots
##      exactly as it did before. The film is content, not a dependency.
##
## IT DOES NOT TOUCH THE MIXER. The video's own audio rides Godot's video bus at
## the master volume the player set; the game's music director is not started
## until the title, and `SkyGearAudio`'s ambience beds come up under it, which is
## the join the film was mixed to expect (`combat_low` under shot 2 is the same
## track the title screen's bed sits beside).

const FILM := "res://assets/video/opening.ogv"

signal finished

var _player: VideoStreamPlayer
var _prompt: Label
var _shown := 0.0


func _ready() -> void:
	## Above the HUD's own CanvasLayer, which is 0.
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not ResourceLoader.exists(FILM):
		call_deferred("_finish")
		return

	## Black behind it, so a film that does not fill an unusual aspect ratio
	## letterboxes onto the game's own dark rather than onto the deck.
	var back := ColorRect.new()
	back.color = Color(0.02, 0.015, 0.028)
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(back)

	## THE ASPECT IS HELD BY THE CONTAINER, NOT THE PLAYER.
	##
	## `VideoStreamPlayer` has no `stretch_mode` — it is not a `TextureRect`, and
	## its only sizing lever is `expand`, which fills its rect and distorts. The
	## film is 1344x768 (7:4) and the game ships 16:9, so `expand` alone would
	## stretch a painted face horizontally, which is the one thing that would
	## undo the identity work the whole shoot was for.
	##
	## An `AspectRatioContainer` at ASPECT_FIT gives the player a correctly
	## proportioned rect and letterboxes the rest onto the black behind it.
	## (Caught by `tools/film_smoke.gd`, which boots the real scene in a real
	## window — the harness is headless and this path is correctly invisible to
	## it, so nothing else in the project could have seen this.)
	var fit := AspectRatioContainer.new()
	fit.set_anchors_preset(Control.PRESET_FULL_RECT)
	fit.ratio = 1344.0 / 768.0
	fit.stretch_mode = AspectRatioContainer.STRETCH_FIT
	fit.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fit)

	_player = VideoStreamPlayer.new()
	_player.stream = load(FILM)
	_player.expand = true
	_player.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_player.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_player.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fit.add_child(_player)

	_prompt = Label.new()
	_prompt.text = "press any key to skip"
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_prompt.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_prompt.offset_top = -46.0
	_prompt.offset_right = -28.0
	_prompt.add_theme_color_override("font_color", Color(0.73, 0.69, 0.66, 0.85))
	_prompt.add_theme_font_size_override("font_size", 15)
	var face := load("res://assets/fonts/Lato-Regular.ttf")
	if face is Font:
		_prompt.add_theme_font_override("font", face as Font)
	_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_prompt)

	_player.finished.connect(_finish)
	_player.play()


func _process(delta: float) -> void:
	_shown += delta
	if _prompt != null:
		## Up for the first six seconds, then out of the way of the film it is
		## offering to skip. It comes back on any input that is not the skip
		## itself — a player reaching for the mouse is a player looking for it.
		_prompt.modulate.a = clampf(1.0 - (_shown - 6.0) / 1.5, 0.0, 1.0)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		_finish()
	elif event is InputEventMouseButton and event.pressed:
		_finish()


## Once, however it ends — skipped, finished, or never started. `finished` is
## what the boot sequence waits on, and a signal emitted twice would start the
## title twice.
func _finish() -> void:
	if is_queued_for_deletion():
		return
	if _player != null and _player.is_playing():
		_player.stop()
	finished.emit()
	queue_free()


## Has this player seen it? Read and written through `SkyGearAudio.store`, so a
## harness run diverts it with everything else (board SG-182 / SG-222).
static func seen() -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(SkyGearAudio.store) != OK:
		return false
	return bool(cfg.get_value("game", "opening_seen", false))


static func mark_seen() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SkyGearAudio.store)          ## an absent file is a new player
	cfg.set_value("game", "opening_seen", true)
	cfg.save(SkyGearAudio.store)
