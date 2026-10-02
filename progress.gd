extends Node
## Autoload "Progress": the level list, which level is being played, and best stars (saved to disk).
##
## Levels are found automatically: every res://levels/level_*.tscn, in file-name order, named by
## the `level_name` set on its root. To add a level, see docs/LEVEL_DESIGN.md (or run tools/new_level.gd).

const LEVEL_DIR := "res://levels/"
const SAVE_PATH := "user://progress.cfg"
const GAME_SCENE := "res://game.tscn"
const MENU_SCENE := "res://level_select.tscn"

var LEVELS: Array[Dictionary] = []  ## [{name, path}], filled by _discover_levels().
var current := 0  ## Index into LEVELS.
var level_override := ""  ## Set when a level scene is launched directly (F6) and isn't in LEVELS.
var best_stars := {}  ## "level_01" -> best total stars over the 3 rounds, out of 15 (0 = never finished)


func _ready() -> void:
	_discover_levels()
	_load()


func _discover_levels() -> void:
	LEVELS.clear()
	var files: PackedStringArray = []
	for f in ResourceLoader.list_directory(LEVEL_DIR):  # Also works in exported builds.
		if f.begins_with("level_") and f.ends_with(".tscn"):
			files.append(f)
	files.sort()
	for f in files:
		var path := LEVEL_DIR + f
		LEVELS.append({name = _read_level_name(path), path = path})


## Reads `level_name` from the level's root without instancing the whole scene.
static func _read_level_name(path: String) -> String:
	var packed := load(path) as PackedScene
	if packed:
		var state := packed.get_state()
		for i in state.get_node_property_count(0):
			if state.get_node_property_name(0, i) == "level_name":
				return state.get_node_property_value(0, i)
	return path.get_file().get_basename()


func current_path() -> String:
	if level_override != "":
		return level_override
	if LEVELS.is_empty():
		return ""
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


## `stars` = the level's total (3 rounds, out of 15). Returns true if this is a new best.
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
	# "best_total" (out of 15, 3 testers per level). The old "best_stars" section (out of 5) is ignored.
	for key in cfg.get_section_keys("best_total") if cfg.has_section("best_total") else []:
		best_stars[key] = cfg.get_value("best_total", key, 0)


func _save() -> void:
	var cfg := ConfigFile.new()
	for key in best_stars:
		cfg.set_value("best_total", key, best_stars[key])
	cfg.save(SAVE_PATH)
