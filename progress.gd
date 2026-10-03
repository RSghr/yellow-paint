extends Node
## Autoload "Progress": the level list, which level is being played, and best stars (saved to disk).
##
## Levels are found automatically: every res://levels/level_*.tscn, in file-name order, named by
## the `level_name` set on its root. To add a level, see docs/LEVEL_DESIGN.md (or run tools/new_level.gd).

const LEVEL_DIR := "res://levels/"
const SAVE_PATH := "user://progress.cfg"
const GAME_SCENE := "res://game.tscn"
const MENU_SCENE := "res://level_select.tscn"
const MAIL_WRITER := preload("res://mail_writer.gd")

const TUTORIAL_COUNT := 3  ## Levels 1-3 are always available.
const UNLOCK_STARS := 10  ## A level after the tutorials appears once EVERY level before it scored this much (out of 15).
## Testing: Project Settings > Yellow Paint > Debug > Unlock All Levels shows every level (debug builds only).
const UNLOCK_ALL_SETTING := "yellow_paint/debug/unlock_all_levels"

var LEVELS: Array[Dictionary] = []  ## [{name, path}], filled by _discover_levels().
var current := 0  ## Index into LEVELS.
var level_override := ""  ## Set when a level scene is launched directly (F6) and isn't in LEVELS.
var seen_intro := false  ## The boss's welcome email has been read (Inlook opens on it at first launch).
var read_mails: Array = []  ## Ids of Inlook emails already opened (see inbox.gd).
var delivered_mails: Array = []  ## Emails received during play (mail_writer.gd), oldest first.
var new_mail_ping := false  ## New mail since the desktop was last shown (it plays a sound).
var open_levels_on_menu := false  ## Coming back from a level: the desktop reopens the Level Select window.
var best_times := {}  ## "level_01" -> [round 0..2] = {session, lost} of the fastest finish (logged, not scored).
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
	return level_override == "" and current + 1 < LEVELS.size() and is_unlocked(current + 1)


## Tutorials are always open; a later level shows up once every level before it scored UNLOCK_STARS.
func is_unlocked(index: int) -> bool:
	if index < 0 or index >= LEVELS.size():
		return false
	return unlock_all() or earned(index)


## Unlocked by playing (ignores the debug toggle). Used for the emails.
func earned(index: int) -> bool:
	if index < TUTORIAL_COUNT:
		return true
	return missing_for(index).is_empty()


## Names of the earlier levels that still need UNLOCK_STARS before `index` opens.
func missing_for(index: int) -> PackedStringArray:
	var missing: PackedStringArray = []
	for i in mini(index, LEVELS.size()):
		if best(LEVELS[i].path) < UNLOCK_STARS:
			missing.append(LEVELS[i].name)
	return missing


## The editor toggle to see every level while testing (never active in release exports).
func unlock_all() -> bool:
	return OS.is_debug_build() and bool(ProjectSettings.get_setting(UNLOCK_ALL_SETTING, false))


## Called by the game when the 3 rounds of the current level are done (after record()).
## Sends Chad's mails and returns the name of a level that just got unlocked ("" if none).
## `rounds`: [{tester, session, lost}] of this run, for Chad's comments about lost testers.
func level_finished(total: int, rounds: Array = []) -> String:
	if level_override != "":
		return ""
	var lost_note := MAIL_WRITER.lost_note(rounds)
	# Did this result open a new level? (The first one earned whose mail hasn't been sent.)
	for i in range(TUTORIAL_COUNT, LEVELS.size()):
		var info: Dictionary = LEVELS[i]
		var unlock_id := "unlock_" + _key(info.path)
		if not earned(i):
			break
		if _has_mail(unlock_id):
			continue
		var testers := level_testers(info.path)
		_deliver(MAIL_WRITER.announcement(info.name, total, testers, lost_note), unlock_id)
		var used: Array = delivered_mails.map(func(m): return m.get("template", ""))
		var flavors: Array = MAIL_WRITER.flavor_for(testers, used)
		for f in flavors.size():
			_deliver(flavors[f], "%s_flavor_%d" % [unlock_id, f])
		_save()
		return info.name
	# This level is still holding things up: one review per score bracket.
	if best(current_path()) < UNLOCK_STARS and current + 1 < LEVELS.size():
		var bracket := "15" if total >= 15 else ("10" if total >= 10 else ("5" if total >= 5 else "0"))
		var perf_id := "perf_%s_%s" % [_key(current_path()), bracket]
		if not _has_mail(perf_id):
			_deliver(MAIL_WRITER.performance(LEVELS[current].name, total, UNLOCK_STARS, lost_note), perf_id)
			_save()
			return ""
	# Nothing else to say, but a tester was lost for half the session or more: Chad noticed (once per level).
	if lost_note != "":
		var lost_id := "lost_" + _key(current_path())
		if not _has_mail(lost_id):
			_deliver(MAIL_WRITER.lost_mail(LEVELS[current].name, lost_note), lost_id)
			_save()
	return ""


func _deliver(mail: Dictionary, id: String) -> void:
	mail.id = id
	delivered_mails.append(mail)
	new_mail_ping = true


func _has_mail(id: String) -> bool:
	for m in delivered_mails:
		if m.id == id:
			return true
	return false


func play_next() -> void:
	if has_next():
		play(current + 1)
	else:
		to_menu()


func to_menu() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	open_levels_on_menu = true
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


## Log a finished round's time. Returns the previous best session time (-1 if none).
func record_time(path: String, round_index: int, session: float, lost: float) -> float:
	var key := _key(path)
	var rounds: Array = best_times.get(key, [null, null, null])
	while rounds.size() <= round_index:
		rounds.append(null)
	var prev: float = rounds[round_index].session if rounds[round_index] != null else -1.0
	if prev < 0.0 or session < prev:
		rounds[round_index] = {session = session, lost = lost}
		best_times[key] = rounds
		_save()
	return prev


## Sum of the best session times of all 3 rounds (-1 until every round has been finished).
func best_total_time(path: String) -> float:
	var rounds: Array = best_times.get(_key(path), [])
	if rounds.size() < 3:
		return -1.0
	var total := 0.0
	for r in rounds:
		if r == null:
			return -1.0
		total += r.session
	return total


static func format_time(seconds: float) -> String:
	var s := roundi(seconds)
	return "%d:%02d" % [s / 60, s % 60]


func mark_intro_seen() -> void:
	if not seen_intro:
		seen_intro = true
		_save()


func mark_mail_read(id: String) -> void:
	if id not in read_mails:
		read_mails.append(id)
		if id == "welcome":
			seen_intro = true
		_save()


## The 3 testers of a level (read from the scene file without instancing it).
static func level_testers(path: String) -> PackedStringArray:
	var names: PackedStringArray = []
	var packed := load(path) as PackedScene
	if packed:
		var state := packed.get_state()
		for key in ["tester_1", "tester_2", "tester_3"]:
			for i in state.get_node_property_count(0):
				if state.get_node_property_name(0, i) == key:
					names.append(state.get_node_property_value(0, i))
	return names


func _key(path: String) -> String:
	return path.get_file().get_basename()  # "level_01"


func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	# "best_total" (out of 15, 3 testers per level). The old "best_stars" section (out of 5) is ignored.
	seen_intro = cfg.get_value("story", "seen_intro", false)
	read_mails = cfg.get_value("story", "read_mails", [])
	delivered_mails = cfg.get_value("story", "delivered_mails", [])
	best_times = cfg.get_value("times", "best", {})
	for key in cfg.get_section_keys("best_total") if cfg.has_section("best_total") else []:
		best_stars[key] = cfg.get_value("best_total", key, 0)


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("story", "seen_intro", seen_intro)
	cfg.set_value("story", "read_mails", read_mails)
	cfg.set_value("story", "delivered_mails", delivered_mails)
	cfg.set_value("times", "best", best_times)
	for key in best_stars:
		cfg.set_value("best_total", key, best_stars[key])
	cfg.save(SAVE_PATH)
