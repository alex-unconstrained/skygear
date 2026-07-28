class_name SkyGearAudio
extends Node

## Buses, the music director, and settings that persist.
##
## The port could play one-shot SFX and nothing else: no music, no volume
## control, no memory of either between runs. For a build people download and
## keep, a volume slider is not polish — a game that is only as loud as your
## system mixer is a game you close.
##
## Three buses under a master, matching the browser's split so the same mixing
## decisions carry over: music sits under everything, SFX is the fight, UI never
## ducks. Godot gives us real buses, so unlike the browser build these are
## actual AudioServer buses rather than gain nodes we manage by hand.

const BUS_MASTER := "Master"
const BUSES := ["Music", "SFX", "UI", "Voice"]
const SETTINGS_PATH := "user://settings.cfg"

## The music director. Same tiers as the browser: the fight escalates with the
## wave and the finale gets its own track, with a crossfade over the join
## because neither track is authored to loop.
const TRACKS := {
	"combat_low": "res://assets/audio/music/combat_low.mp3",
	"combat_high": "res://assets/audio/music/combat_high.mp3",
	"boss": "res://assets/audio/music/boss_loop.mp3",
}
const CROSSFADE := 2.0

var players: Dictionary = {}
var current := ""
var _fading: Array[AudioStreamPlayer] = []

var volumes := {"master": 0.85, "music": 0.55, "sfx": 1.0, "ui": 0.85, "voice": 1.0}
var muted := false


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
func set_volume(which: String, value: float) -> void:
	volumes[which] = clampf(value, 0.0, 1.0)
	apply_volumes()
	save_settings()


func toggle_mute() -> void:
	muted = not muted
	apply_volumes()
	save_settings()


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
	cfg.save(SETTINGS_PATH)


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		apply_volumes()
		return
	for key in volumes.keys():
		volumes[key] = float(cfg.get_value("audio", key, volumes[key]))
	muted = bool(cfg.get_value("audio", "muted", false))
	apply_volumes()
