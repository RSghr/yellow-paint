extends Node
## Autoload "Sfx": plays named sound effects. Drop audio files into res://audio/ named after the
## keys below (e.g. audio/spray.ogg, .wav or .mp3). Missing files are simply silent.
## See audio/README.md for the full list.

const AUDIO_DIR := "res://audio/"
const EXTENSIONS := ["ogg", "wav", "mp3"]

## name -> what it's for (also the expected file name)
const SOUNDS := {
	"spray": "Paint splat sprayed (plays every splat while holding the button)",
	"scrape": "Paint scraped off",
	"out_of_paint": "Tried to paint with an empty can / scraping locked",
	"jump": "Playtester jumps",
	"land": "Playtester lands",
	"fall": "Playtester falls to its doom",
	"voice": "Playtester says something (short blip, pitch is randomised)",
	"desperate": "Playtester winds up a desperate unpainted jump",
	"coin": "Coin collected",
	"button": "Button pressed",
	"smash": "Breakable smashed",
	"door": "Door opens",
	"goal": "Level complete",
	"ui_click": "Menu button clicked",
	"mail": "New email in Inlook (desktop notification)",
	"power_off": "Computer switches off (resignation)",
}
const PLAYER_COUNT := 10

var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # Menu clicks still play while paused.
	for sound in SOUNDS:
		for ext in EXTENSIONS:
			var path: String = AUDIO_DIR + sound + "." + ext
			if ResourceLoader.exists(path):
				_streams[sound] = load(path)
				break
	for i in PLAYER_COUNT:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_players.append(p)


## Play a sound by name. pitch_jitter randomises pitch a bit so repeats don't sound robotic.
func play(sound: String, pitch_jitter := 0.06, volume_db := 0.0) -> void:
	var stream: AudioStream = _streams.get(sound)
	if stream == null:
		return  # No file yet: silent placeholder.
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = randf_range(1.0 - pitch_jitter, 1.0 + pitch_jitter)
	p.play()


func has_sound(sound: String) -> bool:
	return _streams.has(sound)
