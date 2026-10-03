extends Node3D
## The Game scene: loads the current Level (see Progress), then adds the playtester,
## the operator, paint, HUD and scoring around it.
##
## A level is 3 rounds, one focus tester each (Level.rounds()). Paint carries over between rounds;
## each round has its own minimum (that tester's), so its own optimal and can size.
## The level result is the 3 round scores added up, out of 15.
##
## Round scoring: start at 5 stars, subtract paint, coin and hotfix penalties (minimum 1 star).
##   Paint (optimal = round minimum + optimal_margin):  <= optimal: 0 | 1-5 over: -1 | 6-10 over: -2 | more: -3
##   Coins:  all: 0 | more than half: -1 | half or fewer: -2 | none: -3
##   Hotfixes (splats painted DURING the playtest, outside the can, removed on R):  0: 0 | 1-3: -1 | 4+: -2
## The can holds optimal + limit_margin splats. Scraping refunds paint.

const RUNNER_SCENE := preload("res://runner.tscn")
const OPERATOR_SCENE := preload("res://character.tscn")
const PAUSE_MENU := preload("res://pause_menu.gd")
const SPECTATOR_CAMERA := preload("res://spectator_camera.gd")
const ROUND_INTRO := preload("res://round_intro.gd")
const SPEECH_FEED := preload("res://speech_feed.gd")
const RESULTS_CARD := preload("res://results_card.gd")

@export_group("Scoring")
@export var optimal_margin := 5  ## Optimal = round minimum + this. Enough slack to also grab the coins.
@export var limit_margin := 10  ## Can size = optimal + this.
@export var retry_hold_time := 2.0  ## Seconds R must be held to retry (avoids accidental resets).

var level: Level
var runner: Runner
var operator: CharacterBody3D
var coins_collected := 0
var _finished := false
var _playtest_running := false  ## From Enter until R: scraping is locked so paint can't be recycled mid-run.
var hotfixes := 0  ## Splats painted during this playtest run.
var _out_of_paint_timer := 0.0
var spectator: Camera3D
var spectating := false
var round_index := 0  ## 0-2: which focus tester is playing.
var round_stars: Array[int] = [0, 0, 0]  ## Stars per round (0 = not finished yet).
var round_times: Array = [null, null, null]  ## {tester, session, lost} per finished round (logged, not scored).
var _retry_hold := 0.0
var _attempt_open := false  ## A playtest is running and its stats haven't been logged yet.
var _round_tested := false  ## This round's tester has been started at least once (retries count after that).
var _retry_lock := false  ## R must be released before another retry can start.
var _retry_bar: Control  ## "Hold R to retry" progress, bottom centre.
var _retry_fill: ColorRect
var round_intro: Control  ## Level intro banner + sliding tester card (round_intro.gd).
var speech_feed: Control  ## The tester's last 3 lines, top right (speech_feed.gd).
var results_card: Control  ## End-of-round results / tester lost (results_card.gd).

@onready var paint: PaintManager = $PaintManager
@onready var paint_label: Label = $HUD/PaintLabel
@onready var paint_gauge: PaintGauge = $HUD/PaintGauge
@onready var coin_label: Label = $HUD/CoinLabel
@onready var status_label: Label = $HUD/StatusLabel
@onready var message_label: Label = $HUD/MessageLabel
@onready var level_label: Label = $HUD/LevelLabel
@onready var crosshair: Label = $HUD/Crosshair


func _ready() -> void:
	_load_level()
	speech_feed = SPEECH_FEED.new()
	$HUD.add_child(speech_feed)
	runner.said.connect(func(text): speech_feed.push(runner.tester_name, text))
	runner.reached_goal.connect(_on_goal)
	runner.died.connect(_on_died)
	paint.paint_changed.connect(_update_paint_label)
	paint.paint_denied.connect(_on_out_of_paint)
	paint.scrape_denied.connect(_on_scrape_denied)
	paint.splat_added.connect(_on_splat_added)
	paint.hotfix_mode_changed.connect(func(_on): _update_paint_label())
	for coin in get_tree().get_nodes_in_group("coin"):
		coin.collected.connect(_on_coin_collected)
	round_intro = ROUND_INTRO.new()
	$HUD.add_child(round_intro)
	results_card = RESULTS_CARD.new()
	$HUD.add_child(results_card)
	_build_retry_bar()
	_start_round(0)
	add_child(PAUSE_MENU.new())


func _exit_tree() -> void:
	_close_attempt("quit")  # Left mid-playtest (Tab, pause menu): it still counts as a test.


func _load_level() -> void:
	var scene := load(Progress.current_path()) as PackedScene
	level = scene.instantiate() as Level
	add_child(level)
	Music.play(level.music if level.music != "" else "game", "game")

	# Playtester and operator come after the level, so they can find its goal, coins, etc.
	runner = RUNNER_SCENE.instantiate()
	runner.death_height = level.death_height
	runner.transform = level.runner_spawn()
	add_child(runner)

	operator = OPERATOR_SCENE.instantiate()
	operator.name = "Operator"
	operator.transform = level.operator_spawn()
	add_child(operator)

	spectator = SPECTATOR_CAMERA.new()
	spectator.name = "SpectatorCamera"
	spectator.target = runner
	add_child(spectator)


func current_round() -> Dictionary:
	return level.rounds()[round_index]


## Bring in the next focus tester. The level resets, the paint stays.
func _start_round(index: int) -> void:
	round_index = index
	_round_tested = false
	var r := current_round()
	runner.apply_profile(r.tester, FocusGroup.profile(r.tester))
	paint.paint_limit = paint_limit()
	paint_gauge.setup(r.minimum, optimal_paint(), paint_limit())
	_reset_run()
	level_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN  # Right-aligned in the corner: grow leftwards.
	level_label.text = "%s%s" % [
		"" if Progress.level_override != "" else "Level %d: " % (Progress.current + 1), level.level_name]
	status_label.text = "Focus tester: %s" % r.tester
	speech_feed.clear()
	message_label.text = ""
	round_intro.play(level.intro_text if index == 0 else "", index, Level.ROUNDS, r.tester,
		"Your paint from the last round is still there. Adapt it, then press Enter." if index > 0 else "")


## Swap between the operator's eyes and a camera following the playtester.
func _toggle_spectator() -> void:
	spectating = not spectating
	if spectating:
		spectator.yaw = operator.rotation.y  # Start looking the same way as the operator.
		spectator.pitch = -0.35
	spectator.active = spectating
	operator.active = not spectating
	if not spectating:
		operator.camera.current = true
	$HUD/Crosshair.visible = not spectating
	$HUD/SpectatorLabel.visible = spectating
	speech_feed.visible = not spectating  # The bubble above the tester says it all while watching.
	$HUD/SpectatorLabel.text = "Watching %s  (A to go back, mouse to orbit, wheel to zoom)" % runner.tester_name


func optimal_paint() -> int:
	return current_round().minimum + optimal_margin


func paint_limit() -> int:
	return optimal_paint() + limit_margin


func _process(delta: float) -> void:
	_process_retry_hold(delta)
	if _out_of_paint_timer > 0.0:
		_out_of_paint_timer -= delta
		if _out_of_paint_timer <= 0.0:
			_update_paint_label()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("start_test"):
		message_label.text = ""
		round_intro.dismiss()
		_playtest_running = true
		paint.scrape_locked = true
		paint.hotfix_mode = true
		if not _attempt_open and not _finished and runner.state != Runner.State.DEAD:
			_attempt_open = true
			_round_tested = true
		runner.start()
	elif event.is_action_pressed("clear_paint"):
		paint.clear_all()
	elif event.is_action_pressed("toggle_tester_card"):
		round_intro.toggle()
	elif event.is_action_pressed("toggle_ai_debug"):
		runner.debug_view = not runner.debug_view
	elif event.is_action_pressed("toggle_spectator"):
		_toggle_spectator()
	elif event.is_action_pressed("next_level") and _finished and round_index + 1 < Level.ROUNDS:
		_start_round(round_index + 1)  # After the 3rd tester it's back to the computer (Tab).
	elif event.is_action_pressed("back_to_menu"):
		Progress.to_menu()


## Hold R for `retry_hold_time` seconds to retry; a bar fills at the bottom of the screen.
func _process_retry_hold(delta: float) -> void:
	if not Input.is_action_pressed("reset_runner"):
		_retry_lock = false
		if _retry_hold > 0.0:
			_retry_hold = 0.0
			_retry_bar.visible = false
		return
	if _retry_lock:
		return
	_retry_hold += delta
	_retry_bar.visible = true
	_retry_fill.size.x = _retry_bar.size.x * clampf(_retry_hold / retry_hold_time, 0.0, 1.0)
	if _retry_hold >= retry_hold_time:
		_retry_hold = 0.0
		_retry_lock = true
		_retry_bar.visible = false
		_retry()


func _build_retry_bar() -> void:
	_retry_bar = Panel.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.07, 0.09, 0.85)
	style.set_corner_radius_all(6)
	_retry_bar.add_theme_stylebox_override("panel", style)
	_retry_bar.anchor_left = 0.5
	_retry_bar.anchor_right = 0.5
	_retry_bar.anchor_top = 1.0
	_retry_bar.anchor_bottom = 1.0
	_retry_bar.offset_left = -180
	_retry_bar.offset_right = 180
	_retry_bar.offset_top = -120
	_retry_bar.offset_bottom = -84
	_retry_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_retry_bar.visible = false
	_retry_fill = ColorRect.new()
	_retry_fill.color = Color(1, 0.82, 0.05, 0.85)
	_retry_fill.size = Vector2(0, 36)
	_retry_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_retry_bar.add_child(_retry_fill)
	var label := Label.new()
	label.text = "Hold R to retry this tester"
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("outline_size", 6)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_retry_bar.add_child(label)
	$HUD.add_child(_retry_bar)


## Hold R: same tester, same round, try again (hotfixes are removed, your paint stays).
func _retry() -> void:
	if _round_tested:
		_close_attempt("retry")
		Progress.log_tester(runner.tester_name, {retries = 1})
	_reset_run()
	status_label.text = "Focus tester: %s" % runner.tester_name
	speech_feed.clear()


func _reset_run() -> void:
	_close_attempt("reset")
	_out_of_paint_timer = 0.0  # Drop any timed HUD message (e.g. "HOTFIX #n").
	_finished = false
	_playtest_running = false
	paint.scrape_locked = false
	paint.hotfix_mode = false
	hotfixes = 0
	paint.remove_hotfixes()  # Back to the route as it was before the playtest.
	message_label.text = ""
	results_card.hide_card()
	get_tree().call_group("resettable", "reset_state")  # Coins, doors, buttons, breakables.
	coins_collected = 0
	_update_coin_label()
	runner.reset_to_spawn()
	_update_paint_label()


func _update_paint_label() -> void:
	paint_gauge.used = paint.splats_used
	if _out_of_paint_timer > 0.0:
		return  # A timed message (out of paint, hotfix...) is showing; _process restores the label after.
	var hotfix := paint.hotfix_mode
	var color := paint.hotfix_color.lightened(0.25) if hotfix else Color(1, 0.85, 0.1)
	crosshair.add_theme_color_override("font_color", color)
	paint_label.remove_theme_color_override("font_color")
	paint_label.add_theme_color_override("font_color", color)
	paint_label.text = "Paint: %d / %d   (optimal: %d or less)" % [paint.splats_used, paint_limit(), optimal_paint()]
	if hotfix:
		paint_label.text = "HOTFIX MODE: new paint is a hotfix (free, but costs stars)   " + paint_label.text


func _on_out_of_paint() -> void:
	if _out_of_paint_timer > 0.0:
		return
	_out_of_paint_timer = 1.5
	Sfx.play("out_of_paint", 0.0)
	paint_gauge.flash = 1.0
	paint_label.add_theme_color_override("font_color", Color(1, 0.25, 0.2))
	paint_label.text = "OUT OF PAINT! Scrape some (right click) to reuse it."


func _on_scrape_denied() -> void:
	if _out_of_paint_timer > 0.0:
		return
	_out_of_paint_timer = 1.5
	Sfx.play("out_of_paint", 0.0)
	paint_label.add_theme_color_override("font_color", Color(1, 0.25, 0.2))
	paint_label.text = "Can't scrape during a playtest. Hold R to reset the playtester first."


func _on_coin_collected(_coin: Coin) -> void:
	coins_collected += 1
	_update_coin_label()


func _coin_total() -> int:
	return get_tree().get_nodes_in_group("coin").size()


func _update_coin_label() -> void:
	coin_label.text = "Coins: %d / %d" % [coins_collected, _coin_total()]
	if hotfixes > 0:
		coin_label.text += "      Hotfixes: %d" % hotfixes


## Painting during a playtest is allowed, but it's a "hotfix": counted and called out.
func _on_splat_added(mark: PaintMark) -> void:
	if not mark.hotfix:
		return
	hotfixes += 1
	_update_coin_label()
	_out_of_paint_timer = 1.5  # Reuses the timed paint-label message.
	paint_label.add_theme_color_override("font_color", Color(1, 0.55, 0.1))
	paint_label.text = "HOTFIX #%d applied mid-playtest%s" % [hotfixes,
		"" if hotfixes < 4 else "  (the focus group is starting to notice)"]


## Returns {stars, paint_penalty, coin_penalty, hotfix_penalty}.
static func score(paint_used: int, optimal: int, coins: int, coin_total: int, hotfix_count := 0) -> Dictionary:
	var over := paint_used - optimal
	var paint_penalty := 0
	if over > 10:
		paint_penalty = 3
	elif over > 5:
		paint_penalty = 2
	elif over > 0:
		paint_penalty = 1
	var coin_penalty := 0
	if coin_total > 0 and coins < coin_total:
		if coins == 0:
			coin_penalty = 3
		elif coins * 2 <= coin_total:
			coin_penalty = 2
		else:
			coin_penalty = 1
	var hotfix_penalty := 0
	if hotfix_count >= 4:
		hotfix_penalty = 2
	elif hotfix_count >= 1:
		hotfix_penalty = 1
	return {
		stars = clampi(5 - paint_penalty - coin_penalty - hotfix_penalty, 1, 5),
		paint_penalty = paint_penalty,
		coin_penalty = coin_penalty,
		hotfix_penalty = hotfix_penalty,
	}


## Key hints shown at the bottom of the results card: [[key, text], ...]
func _nav_keys() -> Array:
	var keys := []
	if round_index + 1 < Level.ROUNDS:
		keys.append(["N", "next tester"])
	keys.append(["Hold R", "retry this tester"])
	keys.append(["Tab", "back to your desk" if round_index + 1 == Level.ROUNDS else "level select"])
	return keys


## Log the attempt that just ended in the tester's record (Progress.playtest_stats, for the patch notes).
func _close_attempt(outcome: String) -> void:
	if not _attempt_open:
		return
	_attempt_open = false
	Progress.log_tester(runner.tester_name, {
		tests = 1, finishes = 1 if outcome == "finish" else 0, deaths = 1 if outcome == "death" else 0,
		failed_jumps = runner.failed_jumps, lost = runner.time_lost, played = runner.session_time,
		hotfixes_seen = runner.hotfixes_seen, hotfixes = hotfixes,
	})


func _on_goal() -> void:
	_close_attempt("finish")
	_finished = true
	var result := score(paint.splats_used, optimal_paint(), coins_collected, _coin_total(), hotfixes)
	round_stars[round_index] = result.stars
	Sfx.play("goal", 0.0)
	# Times are logged (best per round, to beat later) but never affect the stars.
	var session := runner.session_time
	var lost := runner.time_lost
	round_times[round_index] = {tester = runner.tester_name, session = session, lost = lost}
	var prev_best := Progress.record_time(Progress.current_path(), round_index, session, lost) \
		if Progress.level_override == "" else -1.0
	var data := {
		round_index = round_index, round_count = Level.ROUNDS, tester = runner.tester_name, result = result,
		paint_used = paint.splats_used, optimal = optimal_paint(), coins = coins_collected,
		coin_total = _coin_total(), hotfixes = hotfixes,
		quote = FocusGroup.quote_for(result, lost / session if session > 0.0 else 0.0),
		session = session, lost = lost, prev_best = prev_best,
	}
	if round_index + 1 == Level.ROUNDS:
		var total := 0
		var rounds := []
		for i in Level.ROUNDS:
			total += round_stars[i]
			rounds.append({tester = level.rounds()[i].tester, stars = round_stars[i],
				session = round_times[i].session if round_times[i] != null else -1.0})
		var new_best := Progress.record(Progress.current_path(), total)
		var unlocked := Progress.level_finished(total, round_times.filter(func(r): return r != null))
		var hint := ""
		var good_note := ""
		if Progress.level_override != "" or Progress.ship_state != "":
			pass  # Testing a scene, or the game already shipped: nothing is at stake.
		elif Progress.current == Progress.final_level():
			if Progress.ready_to_ship():
				good_note = "Every playtest is done. Chad needs your greenlight to ship. Check your Inlook."
			else:
				hint = _on_hold_hint("The launch", Progress.missing_for(Progress.current + 1))
		elif unlocked == "" and not Progress.has_next() and Progress.current + 1 < Progress.LEVELS.size():
			hint = _on_hold_hint("The next playtest", Progress.missing_for(Progress.current + 1))
		data.level = {rounds = rounds, total = total, max = Level.ROUNDS * 5, new_best = new_best,
			unlocked = unlocked, locked_hint = hint, good_note = good_note}
	data.nav = _nav_keys()
	message_label.text = ""
	results_card.show_round(data)


func _on_hold_hint(what: String, missing: PackedStringArray) -> String:
	return "%s is on hold until %s %s %d/15 or better." % [
		what, " and ".join(missing), "scores" if missing.size() == 1 else "score", Progress.UNLOCK_STARS]


func _on_died() -> void:
	_close_attempt("death")
	results_card.show_death(runner.tester_name, [["Hold R", "retry"], ["Tab", "level select"]])
