extends Node
## Autoload "Settings": player options, saved to user://settings.cfg.

signal changed

const SAVE_PATH := "user://settings.cfg"

var mouse_sensitivity := 1.0  ## Multiplier on mouse look (operator and spectator camera).
var master_volume := 0.8  ## 0..1, everything.
var sfx_volume := 1.0  ## 0..1, the "SFX" bus (sound effects, under master).
var music_volume := 0.6  ## 0..1, the "Music" bus (under master).
var fullscreen := false


func _ready() -> void:
	_load()
	apply()


func apply() -> void:
	_set_volume(AudioServer.get_bus_index("Master"), master_volume)
	_set_volume(_bus("SFX"), sfx_volume)
	_set_volume(_bus("Music"), music_volume)
	if DisplayServer.get_name() != "headless":
		var mode := DisplayServer.window_get_mode()
		if fullscreen and mode != DisplayServer.WINDOW_MODE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		elif not fullscreen and mode == DisplayServer.WINDOW_MODE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)
	changed.emit()


static func _set_volume(bus: int, volume: float) -> void:
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(volume, 0.0001)))
	AudioServer.set_bus_mute(bus, volume <= 0.001)


## A bus under Master ("SFX", "Music"), created on first use.
static func _bus(bus_name: String) -> int:
	var i := AudioServer.get_bus_index(bus_name)
	if i == -1:
		AudioServer.add_bus()
		i = AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, bus_name)
		AudioServer.set_bus_send(i, "Master")
	return i


func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("settings", "mouse_sensitivity", mouse_sensitivity)
	cfg.set_value("settings", "master_volume", master_volume)
	cfg.set_value("settings", "sfx_volume", sfx_volume)
	cfg.set_value("settings", "music_volume", music_volume)
	cfg.set_value("settings", "fullscreen", fullscreen)
	cfg.save(SAVE_PATH)


func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	mouse_sensitivity = cfg.get_value("settings", "mouse_sensitivity", mouse_sensitivity)
	master_volume = cfg.get_value("settings", "master_volume", master_volume)
	sfx_volume = cfg.get_value("settings", "sfx_volume", sfx_volume)
	music_volume = cfg.get_value("settings", "music_volume", music_volume)
	fullscreen = cfg.get_value("settings", "fullscreen", fullscreen)
