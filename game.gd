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

@export_group("Scoring")
@export var optimal_margin := 5  ## Optimal = round minimum + this. Enough slack to also grab the coins.
@export var limit_margin := 10  ## Can size = optimal + this.

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
	runner.said.connect(func(text): status_label.text = "%s: \"%s\"" % [runner.tester_name, text])
	runner.reached_goal.connect(_on_goal)
	runner.died.connect(_on_died)
	paint.paint_changed.connect(_update_paint_label)
	paint.paint_denied.connect(_on_out_of_paint)
	paint.scrape_denied.connect(_on_scrape_denied)
	paint.splat_added.connect(_on_splat_added)
	paint.hotfix_mode_changed.connect(func(_on): _update_paint_label())
	for coin in get_tree().get_nodes_in_group("coin"):
		coin.collected.connect(_on_coin_collected)
	_start_round(0)
	message_label.text = "%s\n\n%s" % [level.intro_text, message_label.text]
	add_child(PAUSE_MENU.new())


func _load_level() -> void:
	var scene := load(Progress.current_path()) as PackedScene
	level = scene.instantiate() as Level
	add_child(level)

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
	var r := current_round()
	runner.apply_profile(r.tester, FocusGroup.profile(r.tester))
	paint.paint_limit = paint_limit()
	paint_gauge.setup(r.minimum, optimal_paint(), paint_limit())
	_reset_run()
	level_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN  # Right-aligned in the corner: grow leftwards.
	level_label.text = "%s%s\nRound %d/%d: %s\n%s" % [
		"" if Progress.level_override != "" else "Level %d: " % (Progress.current + 1), level.level_name,
		index + 1, Level.ROUNDS, r.tester, FocusGroup.trait_line(r.tester)]
	status_label.text = "Focus tester: %s" % r.tester
	message_label.text = "ROUND %d/%d   Today's focus tester: %s\n%s%s" % [index + 1, Level.ROUNDS, r.tester,
		FocusGroup.trait_line(r.tester),
		"\nYour paint from the last round is still there. Adapt it, then press Enter." if index > 0 else ""]


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
	$HUD/SpectatorLabel.text = "Watching %s  (A to go back, mouse to orbit, wheel to zoom)" % runner.tester_name


func optimal_paint() -> int:
	return current_round().minimum + optimal_margin


func paint_limit() -> int:
	return optimal_paint() + limit_margin


func _process(delta: float) -> void:
	if _out_of_paint_timer > 0.0:
		_out_of_paint_timer -= delta
		if _out_of_paint_timer <= 0.0:
			_update_paint_label()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("start_test"):
		message_label.text = ""
		_playtest_running = true
		paint.scrape_locked = true
		paint.hotfix_mode = true
		runner.start()
	elif event.is_action_pressed("reset_runner"):
		_retry()
	elif event.is_action_pressed("clear_paint"):
		paint.clear_all()
	elif event.is_action_pressed("toggle_ai_debug"):
		runner.debug_view = not runner.debug_view
	elif event.is_action_pressed("toggle_spectator"):
		_toggle_spectator()
	elif event.is_action_pressed("next_level") and _finished:
		if round_index + 1 < Level.ROUNDS:
			_start_round(round_index + 1)
		else:
			Progress.play_next()
	elif event.is_action_pressed("back_to_menu"):
		Progress.to_menu()


## R: same tester, same round, try again (hotfixes are removed, your paint stays).
func _retry() -> void:
	_reset_run()
	status_label.text = "Focus tester: %s" % runner.tester_name


func _reset_run() -> void:
	_out_of_paint_timer = 0.0  # Drop any timed HUD message (e.g. "HOTFIX #n").
	_finished = false
	_playtest_running = false
	paint.scrape_locked = false
	paint.hotfix_mode = false
	hotfixes = 0
	paint.remove_hotfixes()  # Back to the route as it was before the playtest.
	message_label.text = ""
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
	paint_label.text = "Can't scrape during a playtest. Press R to reset the playtester first."


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


func _nav_hint() -> String:
	if round_index + 1 < Level.ROUNDS:
		return "N: next tester   R: retry this tester   Tab: level select"
	return "%sR: retry this tester   Tab: level select" % ("N: next level   " if Progress.has_next() else "")


func _on_goal() -> void:
	_finished = true
	var result := score(paint.splats_used, optimal_paint(), coins_collected, _coin_total(), hotfixes)
	var stars: int = result.stars
	round_stars[round_index] = stars
	var paint_line := "Paint: %d  (optimal: %d or less)   %s" % [
		paint.splats_used, optimal_paint(), "✓" if result.paint_penalty == 0 else "-%d★ immersion broken" % result.paint_penalty]
	var coin_line := "Coins: %d / %d   %s" % [
		coins_collected, _coin_total(), "✓" if result.coin_penalty == 0 else "-%d★" % result.coin_penalty]
	var hotfix_line := "Hotfixes: %d   %s" % [hotfixes,
		"✓" if result.hotfix_penalty == 0 else "-%d★ patched mid-playtest" % result.hotfix_penalty]
	var review := "\"%s\"\n— %s, focus tester" % [FocusGroup.quote_for(result), runner.tester_name]
	Sfx.play("goal", 0.0)
	var header := "ROUND %d/%d COMPLETE   %s" % [round_index + 1, Level.ROUNDS, "★".repeat(stars) + "☆".repeat(5 - stars)]
	var footer := ""
	if round_index + 1 == Level.ROUNDS:
		var total := 0
		var parts: PackedStringArray = []
		for i in Level.ROUNDS:
			total += round_stars[i]
			parts.append("%s %d★" % [level.rounds()[i].tester, round_stars[i]])
		var new_best := Progress.record(Progress.current_path(), total)
		footer = "\nLEVEL COMPLETE   %d / %d★%s\n%s\n" % [total, Level.ROUNDS * 5, "   NEW BEST!" if new_best else "",
			"   ".join(parts)]
	message_label.text = "%s\n%s\n%s\n%s\n%s\n%s\n%s" % [header, paint_line, coin_line, hotfix_line, review, footer, _nav_hint()]


func _on_died() -> void:
	message_label.text = "%s is no longer with the focus group. Scores plummeting.\nR: retry   Tab: level select" % runner.tester_name
