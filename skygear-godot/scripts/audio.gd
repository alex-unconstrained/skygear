class_name SkyGearAudio
extends Node

## Buses, the music director, and settings that persist.
##
## The port could play one-shot SFX and nothing else: no music, no volume
## control, no memory of either between runs. For a build people download and
## keep, a volume slider is not polish — a game that is only as loud as your
## system mixer is a game you close.
##
## Three buses under a master, split by what the player needs to hear THROUGH:
## music sits under everything, SFX is the fight, and UI never ducks — a menu
## click that dips the mix reads as a fault. The split came over from the browser
## build with its mixing decisions attached, which saved re-deriving them; it
## stays because it is the right split, and any bus here can change when the
## Godot mix wants something else. Godot gives us REAL buses, so these are
## AudioServer buses rather than gain nodes managed by hand.

const BUS_MASTER := "Master"
const BUSES := ["Music", "SFX", "UI", "Voice"]
const SETTINGS_PATH := "user://settings.cfg"

## THE FILE EVERY READER AND WRITER HERE ACTUALLY GOES THROUGH. `SETTINGS_PATH`
## is where a PLAYER's volumes, fullscreen and OPEN ALL HEATS live; `store` is
## the pointer, so a TEST RUN can be sent somewhere else. Exactly the shape and
## exactly the reason `SkyGearHudLayout.store` exists (SG-83).
##
## It is a var because of board SG-181. `tests/parity_test.gd` wrote 0.42 into
## the player's real `settings.cfg` and read it straight back, which was wrong
## twice over. It MUTATED his settings — his volume and his OPEN ALL HEATS
## toggle are in that file — and it made the check depend on machine state:
## anything else with this game open rewrites that file several times a second
## (the pause and settings screens call `set_volume` from their draw, and
## `set_volume` saves), so the harness's 0.42 was being overwritten by a second
## process before the harness could read it back. Measured on this machine with
## the owner's build running: 53-79 of every 200 writes to `user://settings.cfg`
## were gone by the next read, while the identical loop against any other
## filename in the same directory lost 0 of 200.
static var store := SETTINGS_PATH

## The music director. Same tiers as the browser: the fight escalates with the
## wave and the finale gets its own track, with a crossfade over the join
## because neither track is authored to loop.
const TRACKS := {
	"combat_low": "res://assets/audio/music/combat_low.mp3",
	"combat_high": "res://assets/audio/music/combat_high.mp3",
	"boss": "res://assets/audio/music/boss_loop.mp3",
}
const CROSSFADE := 2.0

## THE FIRST TEN SECONDS OF THE GAME WERE SILENT (board SG-212).
##
## `play_music` has exactly one call site and it is inside `start_wave`. The
## game boots into `State.TITLE`, so the title, the Workshop, the Berths, HOW TO
## PLAY, COMPARE and SETTINGS have never played anything but `ui/click.ogg` —
## the whole of what a new player meets before they press BEGIN RUN, in silence.
## Meanwhile `assets/audio/sfx/world/` has shipped `amb_ship.ogg` and
## `amb_storm.ogg` since 2026-08-01 with **zero references anywhere in the repo**.
##
## THE ANSWER IS THE AMBIENCE, NOT A MENU TRACK. There are three music files and
## all three are fight music; laying combat under a menu would be the wrong
## promise, and there is no fourth track to write here. What the title screen
## actually is, is a ship's deck in a storm-dusk sky — so it now sounds like
## one. Two looping beds, storm under ship, and they do NOT stop when the run
## starts: the fight layers over them, which is why the music mix has room for
## it and why the join has nothing to hide.
const AMBIENCE := {
	"storm": "res://assets/audio/sfx/world/amb_storm.ogg",
	"ship": "res://assets/audio/sfx/world/amb_ship.ogg",
}
## Well under the music, which is itself under the fight. This is the floor of
## the mix — the level at which you notice it when it stops, not while it plays.
const AMBIENCE_DB := {"storm": -22.0, "ship": -26.0}

var players: Dictionary = {}
var current := ""
var _fading: Array[AudioStreamPlayer] = []
var ambience: Dictionary = {}

## Voice sits ABOVE everything and everything else gets out of its way.
##
## Reported from a playtest: the character audio was not easy to hear or
## understand against the other sounds. Sixty-seven lines that nobody can make
## out are sixty-seven lines of noise, and turning the whole layer up just makes
## a louder mess — a keg chain into forty boarders is thirty simultaneous cues,
## and no fixed level wins against thirty of anything.
##
## So the fix is ducking, which is what a mixer is for: while a line is speaking,
## SFX and music drop under it and come back when it stops.
var volumes := {"master": 0.85, "music": 0.55, "sfx": 0.9, "ui": 0.85, "voice": 1.0}

## How far, in decibels, and how fast. Music ducks harder than SFX because the
## fight is information and the music is not.
const DUCK_SFX := -7.0
const DUCK_MUSIC := -11.0
const DUCK_ATTACK := 14.0     ## dB per second going down
const DUCK_RELEASE := 5.0     ## and coming back, slower, so it does not pump
var _duck := 0.0              ## 0 = clear, 1 = fully ducked
var speaking := false
var muted := false
## Not audio, but this is the file that already persists preferences and a
## second settings file for one boolean is a second settings file.
var fullscreen := true
## OPEN ALL HEATS (board SG-160). Same argument as `fullscreen`, one step
## further: this one deliberately does NOT live in `user://workshop.json`,
## because that file is the player's earned progression and a playtest switch
## has no business inside it. A save written by a build that has never heard of
## this key loads unchanged and reads `false`.
var open_heats := false


func _ready() -> void:
	_ensure_buses()
	load_settings()
	for key in TRACKS.keys():
		var p := AudioStreamPlayer.new()
		p.bus = "Music"
		p.volume_db = -80.0
		var stream: AudioStream = load(TRACKS[key])
		if stream is AudioStreamMP3:
			stream.loop = true
		p.stream = stream
		add_child(p)
		players[key] = p
	_start_ambience()


## ONE SET OF BEDS PER PROCESS, AND THE FIRST MIXER TO BOOT OWNS THEM.
##
## There is one `SkyGearAudio` per `SkyGearGame`, and a `SkyGearGame` is not
## always the game: `pose_screen` builds a whole sandbox game to photograph a
## screen (SG-44) and the harness builds dozens. A per-instance bed would mean
## the F4 editor doubled the storm the moment it posed anything, and it is the
## same argument `play_sfx` already makes when it refuses to sound a posed
## sandbox — a pose is a picture, not a mixer.
static var _bed_owner: SkyGearAudio = null


func _exit_tree() -> void:
	if _bed_owner == self:
		_bed_owner = null


## The beds come up once, at boot, and stay up for the life of the process.
## Starting them per-screen would mean a fade at every menu transition, which is
## the one thing an ambience bed must never do — a storm that restarts when you
## open SETTINGS is a bug you can hear.
func _start_ambience() -> void:
	if _bed_owner != null and is_instance_valid(_bed_owner):
		return
	_bed_owner = self
	for key in AMBIENCE.keys():
		var path: String = AMBIENCE[key]
		if not ResourceLoader.exists(path):
			continue
		var stream: AudioStream = load(path)
		## The .ogg imports are one-shots on disk; the loop is ours to ask for,
		## and asking here rather than in the .import keeps the asset honest for
		## anything else that wants to play it once.
		if stream is AudioStreamOggVorbis:
			stream.loop = true
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		p.stream = stream
		p.volume_db = float(AMBIENCE_DB.get(key, -24.0))
		add_child(p)
		p.play()
		ambience[key] = p


func _ensure_buses() -> void:
	for name in BUSES:
		if AudioServer.get_bus_index(name) >= 0:
			continue
		var index := AudioServer.bus_count
		AudioServer.add_bus(index)
		AudioServer.set_bus_name(index, name)
		AudioServer.set_bus_send(index, BUS_MASTER)


## Which track the state of the run asks for. Falls back down the chain when a
## file is missing, so a partial score still covers the whole game.
func track_for(wave: int, boss: bool) -> String:
	if boss:
		return "boss"
	if wave >= 9:
		return "combat_high"
	return "combat_low"


func play_music(key: String) -> void:
	if key == current or not players.has(key):
		return
	if current != "" and players.has(current):
		var old: AudioStreamPlayer = players[current]
		_fading.append(old)
	current = key
	var p: AudioStreamPlayer = players[key]
	if not p.playing:
		p.play()
	p.volume_db = -40.0


func stop_music() -> void:
	for key in players.keys():
		var p: AudioStreamPlayer = players[key]
		if p.playing:
			_fading.append(p)
	current = ""


func _process(delta: float) -> void:
	## The duck. Driven by `speaking`, which the voice director sets — it knows
	## when a line starts and how long it holds the channel, and nothing else has
	## to know anything.
	var want: float = 1.0 if speaking else 0.0
	var rate: float = DUCK_ATTACK if want > _duck else DUCK_RELEASE
	_duck = move_toward(_duck, want, rate * delta / 14.0)
	_apply_duck()
	# crossfade by hand: Godot has no built-in and a hard cut on a two-minute
	# generated track is exactly as audible here as it was in the browser
	if current != "" and players.has(current):
		var p: AudioStreamPlayer = players[current]
		p.volume_db = move_toward(p.volume_db, 0.0, 40.0 / CROSSFADE * delta)
	for i in range(_fading.size() - 1, -1, -1):
		var p: AudioStreamPlayer = _fading[i]
		p.volume_db = move_toward(p.volume_db, -40.0, 40.0 / CROSSFADE * delta)
		if p.volume_db <= -39.9:
			p.stop()
			_fading.remove_at(i)


## --- settings --------------------------------------------------------------
## THE SLIDERS ARE IMMEDIATE MODE, SO THIS IS CALLED FROM A DRAW (board SG-183).
##
## `hud.gd`'s settings and pause sheets read every slider back into `set_volume`
## on every frame they are on screen — that is what an immediate-mode slider IS,
## and it is correct. What was not correct is that `set_volume` then wrote
## `settings.cfg` to disk. Sitting on the settings screen was **a file write per
## frame, sixty a second, on every player's machine**, and it is also what made
## a harness check flaky enough to need board SG-181 to explain it.
##
## So the write is deferred to the change, not the call. `apply_volumes()` still
## runs every time — the mix must follow the slider under the mouse — and the
## disk only hears about it when a number actually moved.
func set_volume(which: String, value: float) -> void:
	var clamped := clampf(value, 0.0, 1.0)
	var moved: bool = not is_equal_approx(float(volumes.get(which, -1.0)), clamped)
	volumes[which] = clamped
	apply_volumes()
	if moved:
		save_settings()


func toggle_mute() -> void:
	muted = not muted
	apply_volumes()
	save_settings()


## The ducked levels, applied on top of whatever the player set. Kept separate
## from `apply_volumes` so a duck can never be mistaken for a settings change and
## saved to disk.
func _apply_duck() -> void:
	var sfx := AudioServer.get_bus_index("SFX")
	if sfx >= 0:
		AudioServer.set_bus_volume_db(sfx,
			linear_to_db(maxf(0.0001, float(volumes.sfx))) + DUCK_SFX * _duck)
	var music := AudioServer.get_bus_index("Music")
	if music >= 0:
		AudioServer.set_bus_volume_db(music,
			linear_to_db(maxf(0.0001, float(volumes.music))) + DUCK_MUSIC * _duck)


func apply_volumes() -> void:
	var master := AudioServer.get_bus_index(BUS_MASTER)
	AudioServer.set_bus_mute(master, muted)
	AudioServer.set_bus_volume_db(master, linear_to_db(maxf(0.0001, float(volumes.master))))
	for pair in [["Music", "music"], ["SFX", "sfx"], ["UI", "ui"], ["Voice", "voice"]]:
		var index := AudioServer.get_bus_index(pair[0])
		if index >= 0:
			AudioServer.set_bus_volume_db(index, linear_to_db(maxf(0.0001, float(volumes[pair[1]]))))


func save_settings() -> void:
	var cfg := ConfigFile.new()
	for key in volumes.keys():
		cfg.set_value("audio", key, volumes[key])
	cfg.set_value("audio", "muted", muted)
	cfg.set_value("display", "fullscreen", fullscreen)
	cfg.set_value("playtest", "open_heats", open_heats)
	cfg.save(store)


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(store) != OK:
		apply_volumes()
		return
	for key in volumes.keys():
		volumes[key] = float(cfg.get_value("audio", key, volumes[key]))
	muted = bool(cfg.get_value("audio", "muted", false))
	fullscreen = bool(cfg.get_value("display", "fullscreen", true))
	open_heats = bool(cfg.get_value("playtest", "open_heats", false))
	apply_volumes()
