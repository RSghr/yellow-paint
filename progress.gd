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

var LEVELS: Array[Dictionary] = []  ## [{name, path, post_launch}], filled by _discover_levels().
var current := 0  ## Index into LEVELS.
var level_override := ""  ## Set when a level scene is launched directly (F6) and isn't in LEVELS.
var resignations := 0  ## Times the player resigned (save reset via HR). Survives the reset: the new hire's number.
var seen_intro := false  ## The boss's welcome email has been read (Inlook opens on it at first launch).
var read_mails: Array = []  ## Ids of Inlook emails already opened (see inbox.gd).
var delivered_mails: Array = []  ## Emails received during play (mail_writer.gd), oldest first.
var new_mail_ping := false  ## New mail since the desktop was last shown (it plays a sound).
var open_levels_on_menu := false  ## Coming back from a level: the desktop reopens the Level Select window.
var desktop_fade_in := false  ## Back from the credits: the desktop fades in from black.
var best_times := {}  ## "level_01" -> [round 0..2] = {session, lost} of the fastest finish (logged, not scored).
var best_stars := {}  ## "level_01" -> best total stars over the 3 rounds, out of 15 (0 = never finished)
## Every focus tester's record, per level, across all their playtests (for the day-one patch notes).
## "level_04" -> {"Rhea Spawn" -> {tests, finishes, deaths, retries, failed_jumps, lost, played, hotfixes_seen, hotfixes}}
## (key "" = stats from before they were split per level). tester_totals() adds the levels up per tester.
var playtest_stats := {}
## Release: "" = in development, "credits" = greenlit (ending + patch notes mails sent, credits not seen yet),
## "shipped" = Patch 1.1 (replay everything, no stakes, post-launch levels open).
var ship_state := ""
var ending := ""  ## "investors" / "goty" / "decent", decided when the game is greenlit.

const STAT_KEYS := ["tests", "finishes", "deaths", "retries", "failed_jumps", "lost", "played", "hotfixes_seen", "hotfixes"]


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
		LEVELS.append({name = _read_root_prop(path, "level_name", path.get_file().get_basename()), path = path,
			post_launch = bool(_read_root_prop(path, "post_launch", false))})


## Reads a property set on the level's root without instancing the whole scene.
static func _read_root_prop(path: String, prop: String, default: Variant) -> Variant:
	var packed := load(path) as PackedScene
	if packed:
		var state := packed.get_state()
		for i in state.get_node_property_count(0):
			if state.get_node_property_name(0, i) == prop:
				return state.get_node_property_value(0, i)
	return default


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
## Post-launch levels open when the game has shipped.
func is_unlocked(index: int) -> bool:
	if index < 0 or index >= LEVELS.size():
		return false
	if LEVELS[index].post_launch:
		return unlock_all() or shipped()
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
		if LEVELS[i].post_launch:
			continue  # Bonus content never holds anything up.
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
	if level_override != "" or ship_state != "":
		return ""  # After the greenlight there are no stakes: no more mails from Chad about scores.
	var lost_note := MAIL_WRITER.lost_note(rounds)
	# Every playtest is good enough: Chad needs the last greenlight (once). Comes first: any unlock
	# announcement still unsent at this point (debug unlock) is old news.
	if ready_to_ship() and not _has_mail("greenlight"):
		_deliver(MAIL_WRITER.greenlight(lost_note), "greenlight")
		_save()
		return ""
	# Did this result open a new level? (The first one earned whose mail hasn't been sent.)
	for i in range(TUTORIAL_COUNT, LEVELS.size()):
		var info: Dictionary = LEVELS[i]
		if info.post_launch:
			continue
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
	if best(current_path()) < UNLOCK_STARS and not LEVELS[current].post_launch:
		var bracket := "15" if total >= 15 else ("10" if total >= 10 else ("5" if total >= 5 else "0"))
		var perf_id := "perf_%s_%s" % [_key(current_path()), bracket]
		if not _has_mail(perf_id):
			_deliver(MAIL_WRITER.performance(LEVELS[current].name, total, UNLOCK_STARS, lost_note,
				current == final_level()), perf_id)
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


# --- Release (greenlight, endings, Patch 1.1) ---------------------------------

func shipped() -> bool:
	return ship_state == "shipped"


## Index of the last level of the main game (post-launch levels don't count). -1 if none.
func final_level() -> int:
	for i in range(LEVELS.size() - 1, -1, -1):
		if not LEVELS[i].post_launch:
			return i
	return -1


## Indices of the levels that decide the ending: the main game after the tutorials.
func ending_levels() -> Array[int]:
	var out: Array[int] = []
	for i in range(TUTORIAL_COUNT, LEVELS.size()):
		if not LEVELS[i].post_launch:
			out.append(i)
	return out


## Every main level has a best of UNLOCK_STARS or more: the game can ship.
func ready_to_ship() -> bool:
	var last := final_level()
	return last >= 0 and missing_for(last + 1).is_empty()


## Investors: 15 everywhere. GOTY (for gamers): exactly UNLOCK_STARS everywhere. Anything else: decent.
func compute_ending() -> String:
	var levels := ending_levels()
	if levels.is_empty():
		return "decent"
	if levels.all(func(i): return best(LEVELS[i].path) >= 15):
		return "investors"
	if levels.all(func(i): return best(LEVELS[i].path) == UNLOCK_STARS):
		return "goty"
	return "decent"


## The greenlight button: the ending is decided by the current bests, Chad's ending mail and the
## day-one patch notes arrive. The credits roll once the player closes Inlook (ship_state "credits").
func greenlight() -> void:
	if ship_state != "" or not ready_to_ship():
		return
	ending = compute_ending()
	ship_state = "credits"
	_deliver(MAIL_WRITER.ending_mail(ending, _ending_scores()), "ending")
	_deliver(MAIL_WRITER.patch_notes(ending, tester_totals(patch_note_keys()), level_stats()), "patch_notes")
	_save()


## The credits are over: Patch 1.1. Chad's early access mail; post-launch levels open.
func finish_credits() -> void:
	if ship_state != "credits":
		return
	ship_state = "shipped"
	var extra := ""
	for info in LEVELS:
		if info.post_launch:
			extra = info.name
			break
	_deliver(MAIL_WRITER.patch_mail(ending, extra), "patch_1_1")
	_save()


## [{name, stars}] of the levels that decided the ending.
func _ending_scores() -> Array:
	return ending_levels().map(func(i): return {name = LEVELS[i].name, stars = best(LEVELS[i].path)})


## Add one attempt's numbers to a tester's record. `data` uses STAT_KEYS (missing keys = 0).
func log_tester(tester: String, data: Dictionary) -> void:
	if level_override != "" or tester == "":
		return  # F6 test runs don't count.
	var key := _key(current_path())
	var level: Dictionary = playtest_stats.get(key, {})
	var s: Dictionary = level.get(tester, {})
	for k in STAT_KEYS:
		s[k] = s.get(k, 0) + data.get(k, 0)
	level[tester] = s
	playtest_stats[key] = level
	_save()


## Each tester's record, levels added up: {"Rhea Spawn": {tests, deaths...}}.
## `keys` limits it to some levels (level keys like "level_04"); empty = every level.
func tester_totals(keys: Array = []) -> Dictionary:
	var out := {}
	for key in playtest_stats:
		if not keys.is_empty() and key not in keys:
			continue
		for tester in playtest_stats[key]:
			var t: Dictionary = out.get(tester, {})
			for k in STAT_KEYS:
				t[k] = t.get(k, 0) + playtest_stats[key][tester].get(k, 0)
			out[tester] = t
	return out


## Keys of the levels the patch notes talk about: the ones that decide the ending (no tutorials,
## no post-launch). Stats from old saves (key "", level unknown) are left out too.
func patch_note_keys() -> Array:
	return ending_levels().map(func(i): return _key(LEVELS[i].path))


## [{name, testers: {tester: stats}}] of the patch-note levels, in level order.
func level_stats() -> Array:
	var out := []
	for key in patch_note_keys():
		if playtest_stats.has(key):
			for info in LEVELS:
				if _key(info.path) == key:
					out.append({name = info.name, testers = playtest_stats[key]})
	return out


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


## The player's contractor number (#4471, then #4472 after a resignation...).
func contractor_id() -> int:
	return 4471 + resignations


## HR exit interview: wipe all progress (stars, times, mails, read state). Settings live in their own file and stay.
func resign() -> void:
	resignations += 1
	seen_intro = false
	read_mails = []
	delivered_mails = []
	best_stars = {}
	best_times = {}
	playtest_stats = {}
	ship_state = ""
	ending = ""
	new_mail_ping = false
	open_levels_on_menu = false
	current = 0
	_save()


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
	resignations = cfg.get_value("employee", "resignations", 0)
	# "best_total" (out of 15, 3 testers per level). The old "best_stars" section (out of 5) is ignored.
	seen_intro = cfg.get_value("story", "seen_intro", false)
	read_mails = cfg.get_value("story", "read_mails", [])
	delivered_mails = cfg.get_value("story", "delivered_mails", [])
	best_times = cfg.get_value("times", "best", {})
	playtest_stats = cfg.get_value("stats", "per_level", {})
	if playtest_stats.is_empty() and cfg.has_section_key("stats", "testers"):
		playtest_stats = {"": cfg.get_value("stats", "testers", {})}  # Older save: no level info.
	ship_state = cfg.get_value("release", "state", "")
	ending = cfg.get_value("release", "ending", "")
	for key in cfg.get_section_keys("best_total") if cfg.has_section("best_total") else []:
		best_stars[key] = cfg.get_value("best_total", key, 0)


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("employee", "resignations", resignations)
	cfg.set_value("story", "seen_intro", seen_intro)
	cfg.set_value("story", "read_mails", read_mails)
	cfg.set_value("story", "delivered_mails", delivered_mails)
	cfg.set_value("times", "best", best_times)
	cfg.set_value("stats", "per_level", playtest_stats)
	cfg.set_value("release", "state", ship_state)
	cfg.set_value("release", "ending", ending)
	for key in best_stars:
		cfg.set_value("best_total", key, best_stars[key])
	cfg.save(SAVE_PATH)
