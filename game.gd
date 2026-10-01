extends Node3D
## The Game scene: loads the current Level (see Progress), then adds the playtester,
## the operator, paint, HUD and scoring around it.
##
## Scoring: start at 5 stars, subtract a paint penalty and a coin penalty (minimum 1 star).
##   Paint (optimal = level minimum + optimal_margin):  <= optimal: 0 | 1-5 over: -1 | 6-10 over: -2 | more: -3
##   Coins:  all: 0 | more than half: -1 | half or fewer: -2 | none: -3
## The can holds optimal + limit_margin splats. Scraping refunds paint.

const RUNNER_SCENE := preload("res://runner.tscn")
const OPERATOR_SCENE := preload("res://character.tscn")

@export_group("Scoring")
@export var optimal_margin := 5  ## Optimal = level minimum + this. Enough slack to also grab the coins.
@export var limit_margin := 10  ## Can size = optimal + this.

var level: Level
var runner: Runner
var operator: CharacterBody3D
var coins_collected := 0
var _finished := false
var _playtest_running := false  ## From Enter until R: scraping is locked so paint can't be recycled mid-run.
var _out_of_paint_timer := 0.0

@onready var paint: PaintManager = $PaintManager
@onready var paint_label: Label = $HUD/PaintLabel
@onready var paint_gauge: PaintGauge = $HUD/PaintGauge
@onready var coin_label: Label = $HUD/CoinLabel
@onready var status_label: Label = $HUD/StatusLabel
@onready var message_label: Label = $HUD/MessageLabel
@onready var level_label: Label = $HUD/LevelLabel


func _ready() -> void:
	_load_level()
	paint.paint_limit = paint_limit()
	paint_gauge.setup(level.minimum_paint, optimal_paint(), paint_limit())
	runner.said.connect(func(text): status_label.text = "Playtester: \"%s\"" % text)
	runner.reached_goal.connect(_on_goal)
	runner.died.connect(_on_died)
	paint.paint_changed.connect(_update_paint_label)
	paint.paint_denied.connect(_on_out_of_paint)
	paint.scrape_denied.connect(_on_scrape_denied)
	for coin in get_tree().get_nodes_in_group("coin"):
		coin.collected.connect(_on_coin_collected)
	_update_paint_label()
	_update_coin_label()
	level_label.text = "%s%s" % ["" if Progress.level_override != "" else "Level %d: " % (Progress.current + 1), level.level_name]
	message_label.text = level.intro_text


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


func optimal_paint() -> int:
	return level.minimum_paint + optimal_margin


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
		runner.start()
	elif event.is_action_pressed("reset_runner"):
		_retry()
	elif event.is_action_pressed("clear_paint"):
		paint.clear_all()
	elif event.is_action_pressed("toggle_ai_debug"):
		runner.debug_view = not runner.debug_view
	elif event.is_action_pressed("next_level") and _finished:
		Progress.play_next()
	elif event.is_action_pressed("back_to_menu"):
		Progress.to_menu()


func _retry() -> void:
	_finished = false
	_playtest_running = false
	paint.scrape_locked = false
	message_label.text = ""
	get_tree().call_group("resettable", "reset_state")  # Coins, doors, buttons, breakables.
	coins_collected = 0
	_update_coin_label()
	runner.reset_to_spawn()


func _update_paint_label() -> void:
	paint_gauge.used = paint.splats_used
	paint_label.remove_theme_color_override("font_color")
	paint_label.add_theme_color_override("font_color", Color(1, 0.85, 0.1))
	paint_label.text = "Paint: %d / %d   (optimal: %d or less)" % [paint.splats_used, paint_limit(), optimal_paint()]


func _on_out_of_paint() -> void:
	if _out_of_paint_timer > 0.0:
		return
	_out_of_paint_timer = 1.5
	paint_gauge.flash = 1.0
	paint_label.add_theme_color_override("font_color", Color(1, 0.25, 0.2))
	paint_label.text = "OUT OF PAINT! Scrape some (right click) to reuse it."


func _on_scrape_denied() -> void:
	if _out_of_paint_timer > 0.0:
		return
	_out_of_paint_timer = 1.5
	paint_label.add_theme_color_override("font_color", Color(1, 0.25, 0.2))
	paint_label.text = "Can't scrape during a playtest. Press R to reset the playtester first."


func _on_coin_collected(_coin: Coin) -> void:
	coins_collected += 1
	_update_coin_label()


func _coin_total() -> int:
	return get_tree().get_nodes_in_group("coin").size()


func _update_coin_label() -> void:
	coin_label.text = "Coins: %d / %d" % [coins_collected, _coin_total()]


## Returns {stars, paint_penalty, coin_penalty}.
static func score(paint_used: int, optimal: int, coins: int, coin_total: int) -> Dictionary:
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
	return {
		stars = clampi(5 - paint_penalty - coin_penalty, 1, 5),
		paint_penalty = paint_penalty,
		coin_penalty = coin_penalty,
	}


func _nav_hint() -> String:
	return "%sR: retry   Tab: level select" % ("N: next level   " if Progress.has_next() else "")


func _on_goal() -> void:
	_finished = true
	var result := score(paint.splats_used, optimal_paint(), coins_collected, _coin_total())
	var stars: int = result.stars
	var new_best := Progress.record(Progress.current_path(), stars)
	var paint_line := "Paint: %d  (optimal: %d or less)   %s" % [
		paint.splats_used, optimal_paint(), "✓" if result.paint_penalty == 0 else "-%d★ immersion broken" % result.paint_penalty]
	var coin_line := "Coins: %d / %d   %s" % [
		coins_collected, _coin_total(), "✓" if result.coin_penalty == 0 else "-%d★" % result.coin_penalty]
	message_label.text = "LEVEL COMPLETE   %s%s\n%s\n%s\n%s" % [
		"★".repeat(stars) + "☆".repeat(5 - stars), "   NEW BEST!" if new_best else "",
		paint_line, coin_line, _nav_hint()]


func _on_died() -> void:
	message_label.text = "Playtester lost. Focus test scores plummeting.\nR: retry   Tab: level select"
