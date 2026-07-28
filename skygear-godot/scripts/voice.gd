class_name SkyGearVoice
extends Node

## The voice director.
##
## Ported from the browser build's `Voice`, rules and cooldowns intact, because
## the rules ARE the feature. Voice is the one layer where more is worse: a line
## that fires on every wave, every draft and every dash stops being character and
## becomes a notification sound with words in it, and there is no volume slider
## for "say less".
##
## Three rules, and they are the whole system:
##
##   1. **One line at a time.** A line in flight blocks anything of equal or
##      lower priority for its own length plus a gap. Higher priority cuts in.
##   2. **Every key has its own cooldown**, and the noisy ones have long ones.
##      `dash` is one-in-six with an eight second floor, so effort grunts stay
##      incidental rather than becoming the sound of moving.
##   3. **Nothing is ever announced only by voice.** Every call site sits on top
##      of a mechanical cue that already fires. Delete this whole layer and the
##      game loses flavour, not information.
##
## No procedural fallback, deliberately: an absent line is silence, not a synth
## impression of a human being. Line sheet in `docs/VOICE-BRIEF.md`.

const ROOT := "res://assets/audio/voice/"

## key -> folder/stem. Variants are `stem_1.ogg`, `stem_2.ogg`, … and are
## discovered at load, so delivering a fourth take of a line needs no code.
const LINES := {
	"wave_start": "captain/wave_start",
	"wave_clear": "captain/wave_clear",
	"first_board": "captain/first_board",
	"hurt_low": "captain/hurt_low",
	"vent": "captain/vent",
	"keg": "captain/keg",
	"dash": "captain/dash_effort",
	"draft": "captain/draft",
	"slot": "captain/slot_unlock",
	"boiler_low": "captain/boiler_low",
	"lane_critical": "captain/lane_critical",
	"push": "captain/push",
	"victory": "captain/victory",
	"defeat": "captain/defeat",
	"crew_muster": "crew/muster",
	"crew_down": "crew/down",
	"cannon_down": "crew/cannon_down",
	"boss_arrive": "boss/arrive",
	"boss_turn": "boss/turn",
}

## Seconds before the same key may fire again. 999 means once per run.
const COOLDOWN := {
	"wave_start": 20.0, "wave_clear": 20.0, "first_board": 999.0, "hurt_low": 26.0,
	"vent": 22.0, "keg": 30.0, "dash": 8.0, "draft": 30.0, "slot": 20.0,
	"boiler_low": 45.0, "lane_critical": 24.0, "push": 40.0,
	"crew_muster": 30.0, "crew_down": 22.0, "cannon_down": 18.0,
	"boss_arrive": 999.0, "boss_turn": 999.0, "victory": 999.0, "defeat": 999.0,
}

## Roughly how long each line holds the channel. Measured from the files where
## they exist; the browser carried the same table so the director behaved
## identically before any of them were delivered.
const HOLD := {
	"boss_arrive": 3.0, "boss_turn": 2.4, "victory": 3.0, "defeat": 3.0,
	"dash": 0.6, "hurt_low": 1.2,
}
const DEFAULT_HOLD := 1.6
const GAP := 0.35

var clips: Dictionary = {}          ## key -> Array[AudioStream]
var _busy_until := 0.0
var _priority := -1
var _last: Dictionary = {}
var _clock := 0.0
var _player: AudioStreamPlayer
## Set while a line is in flight, so the mixer can duck the fight under it. A
## playtest could not make the lines out against the other sounds, and the layer
## being quiet was never the problem — thirty simultaneous cues was.
var audio: SkyGearAudio
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_player = AudioStreamPlayer.new()
	_player.bus = "Voice" if AudioServer.get_bus_index("Voice") >= 0 else "SFX"
	## Above the fight rather than level with it. A line that is merely present
	## in the mix is a line nobody parses while three boarders are winding up.
	_player.volume_db = 4.0
	add_child(_player)
	for key in LINES.keys():
		var takes: Array[AudioStream] = []
		for n in range(1, 13):
			var path := "%s%s_%d.ogg" % [ROOT, LINES[key], n]
			if not ResourceLoader.exists(path):
				continue
			takes.append(load(path))
		if not takes.is_empty():
			clips[key] = takes


func _process(delta: float) -> void:
	_clock += delta
	if audio != null:
		audio.speaking = _player != null and _player.playing


## Say a line, or decline to. Returns whether it actually spoke, so a call site
## can tell the difference between "no file" and "not now" only if it cares —
## and none of them do, which is the point.
func say(key: String, priority: int = 0) -> bool:
	if not clips.has(key):
		return false                                  # nothing delivered yet
	if _clock < _busy_until and priority <= _priority:
		return false
	var cooldown: float = float(COOLDOWN.get(key, 12.0))
	if _last.has(key) and _clock - float(_last[key]) < cooldown:
		return false
	var takes: Array = clips[key]
	var stream: AudioStream = takes[_rng.randi() % takes.size()]
	_player.stream = stream
	_player.play()
	_last[key] = _clock
	var hold: float = float(HOLD.get(key, DEFAULT_HOLD))
	if stream is AudioStreamOggVorbis:
		hold = maxf(0.2, stream.get_length())
	_busy_until = _clock + hold + GAP
	_priority = priority
	return true


## A line that only fires some of the time. The dash grunt is one in six: the
## cooldown alone would still let it land on most dashes in a quiet stretch, and
## a captain who grunts every time she moves is a captain you mute.
func maybe(key: String, chance: float, priority: int = 0) -> bool:
	if _rng.randf() > chance:
		return false
	return say(key, priority)


func reset() -> void:
	_busy_until = 0.0
	_priority = -1
	_last.clear()


## How many lines are actually on disk, for the harness and the boot log.
func delivered() -> int:
	var n := 0
	for key in clips.keys():
		n += (clips[key] as Array).size()
	return n
