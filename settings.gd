extends Node
## Autoload "Settings": player options, saved to user://settings.cfg.

signal changed

const SAVE_PATH := "user://settings.cfg"

var mouse_sensitivity := 1.0  ## Multiplier on mouse look (operator and spectator camera).
var master_volume := 0.8  ## 0..1
var fullscreen := false


func _ready() -> void:
	_load()
	apply()


func apply() -> void:
	var bus := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(master_volume, 0.0001)))
	AudioServer.set_bus_mute(bus, master_volume <= 0.001)
	if DisplayServer.get_name() != "headless":
		var mode := DisplayServer.window_get_mode()
		if fullscreen and mode != DisplayServer.WINDOW_MODE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		elif not fullscreen and mode == DisplayServer.WINDOW_MODE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)
	changed.emit()


func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("settings", "mouse_sensitivity", mouse_sensitivity)
	cfg.set_value("settings", "master_volume", master_volume)
	cfg.set_value("settings", "fullscreen", fullscreen)
	cfg.save(SAVE_PATH)


func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	mouse_sensitivity = cfg.get_value("settings", "mouse_sensitivity", mouse_sensitivity)
	master_volume = cfg.get_value("settings", "master_volume", master_volume)
	fullscreen = cfg.get_value("settings", "fullscreen", fullscreen)
