extends Node
## Autoload "Progress": the level list, which level is being played, and best stars (saved to disk).
##
## To add a level: create levels/level_XX.tscn (duplicate an existing one) and add a line to LEVELS.

const LEVELS: Array[Dictionary] = [
	{name = "Onboarding", path = "res://levels/level_01.tscn"},
	{name = "Breakables", path = "res://levels/level_02.tscn"},
	{name = "Buttons", path = "res://levels/level_03.tscn"},
	{name = "The Gauntlet", path = "res://levels/level_04.tscn"},
]
const SAVE_PATH := "user://progress.cfg"
const GAME_SCENE := "res://game.tscn"
const MENU_SCENE := "res://level_select.tscn"

var current := 0  ## Index into LEVELS.
var level_override := ""  ## Set when a level scene is launched directly (F6) and isn't in LEVELS.
var best_stars := {}  ## "level_01" -> best stars (0 = never finished)


func _ready() -> void:
	_load()


func current_path() -> String:
	if level_override != "":
		return level_override
	return LEVELS[current].path


func play(index: int) -> void:
	current = clampi(index, 0, LEVELS.size() - 1)
	level_override = ""
	get_tree().change_scene_to_file(GAME_SCENE)


func play_path(path: String) -> void:
	for i in LEVELS.size():
		if LEVELS[i].path == path:
			play(i)
			return
	level_override = path
	get_tree().change_scene_to_file(GAME_SCENE)


func has_next() -> bool:
	return level_override == "" and current + 1 < LEVELS.size()


func play_next() -> void:
	if has_next():
		play(current + 1)
	else:
		to_menu()


func to_menu() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().change_scene_to_file(MENU_SCENE)


func best(path: String) -> int:
	return best_stars.get(_key(path), 0)


## Returns true if this is a new best.
func record(path: String, stars: int) -> bool:
	if stars <= best(path):
		return false
	best_stars[_key(path)] = stars
	_save()
	return true


func _key(path: String) -> String:
	return path.get_file().get_basename()  # "level_01"


func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	for key in cfg.get_section_keys("best_stars") if cfg.has_section("best_stars") else []:
		best_stars[key] = cfg.get_value("best_stars", key, 0)


func _save() -> void:
	var cfg := ConfigFile.new()
	for key in best_stars:
		cfg.set_value("best_stars", key, best_stars[key])
	cfg.save(SAVE_PATH)
