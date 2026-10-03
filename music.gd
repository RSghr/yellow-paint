extends Node
## Autoload "Music": looping background music with a crossfade between tracks.
## Drop files into res://audio/ named music_<track>.ogg / .mp3 / .wav. Missing files are silent.
##   desk     - the company desktop (main menu)
##   game     - inside a level (a level can ask for its own track: Level.music)
##   credits  - launch-day credits (falls back to "desk")
## Plays on the "Music" bus (volume in Company Settings > Music). Survives scene changes.

const AUDIO_DIR := "res://audio/"
const EXTENSIONS := ["ogg", "mp3", "wav"]
const TRACKS := {
	"desk": "Company desktop (main menu): office ambience, elevator music...",
	"game": "Playing a level (default for every level)",
	"credits": "Launch-day credits (uses the desk track if missing)",
	"credits_investors": "Optional: credits of the Investors' Cut ending (else credits)",
	"credits_goty": "Optional: credits of the GOTY (by gamers) ending (else credits)",
	"credits_decent": "Optional: credits of the Mostly Fine ending (else credits)",
}
const FALLBACK := {"credits": "desk"}  ## A missing track plays this one instead ("" = silence).
const FADE_TIME := 1.2

var current := ""  ## The track that was asked for (even if it's silent).
var _players: Array[AudioStreamPlayer] = []
var _active := 0
var _tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # Keeps playing in the pause menu.
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.bus = "Music"
		p.volume_db = -80.0
		p.finished.connect(_on_finished.bind(p))
		add_child(p)
		_players.append(p)


## Crossfade to `track` (no-op if it's already playing). Unknown/missing tracks fade to silence,
## unless FALLBACK names one, or `fallback` is given.
func play(track: String, fallback := "") -> void:
	var stream := _stream_for(track)
	if stream == null and fallback != "":
		stream = _stream_for(fallback)
	if stream == null and FALLBACK.has(track):
		stream = _stream_for(FALLBACK[track])
	var now := _players[_active]
	if stream != null and now.playing and now.stream == stream:
		current = track
		return
	current = track
	if _tween:
		_tween.kill()
	# Both fades at once, on a linear volume (a dB fade sounds silent for most of its length).
	_tween = create_tween().set_parallel()
	_tween.tween_method(_set_volume.bind(now), db_to_linear(now.volume_db), 0.0, FADE_TIME)
	if stream != null:
		_active = 1 - _active
		var next := _players[_active]
		next.stream = stream
		next.volume_db = -80.0
		next.play()
		_tween.tween_method(_set_volume.bind(next), 0.0, 1.0, FADE_TIME)
	_tween.chain().tween_callback(now.stop)


func _set_volume(v: float, p: AudioStreamPlayer) -> void:
	p.volume_db = linear_to_db(maxf(v, 0.0001))


## True if audio/music_<track> exists.
func has_track(track: String) -> bool:
	return _stream_for(track) != null


## The stream of the track currently playing (or fading in), null if silent.
func playing_stream() -> AudioStream:
	var p := _players[_active]
	return p.stream if p.playing else null


func stop() -> void:
	play("")


func _stream_for(track: String) -> AudioStream:
	if track == "":
		return null
	for ext in EXTENSIONS:
		var path: String = AUDIO_DIR + "music_" + track + "." + ext
		if ResourceLoader.exists(path):
			return load(path)
	return null


func _on_finished(p: AudioStreamPlayer) -> void:
	p.play()  # Loop, whatever the file's import settings (stop() doesn't emit "finished").
