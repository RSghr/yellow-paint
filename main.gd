extends Node3D
## Playtest flow, HUD and scoring.
##
## Scoring: start at 5 stars, subtract a paint penalty and a coin penalty (minimum 1 star).
##   Paint (optimal = minimum + optimal_margin):  <= optimal: 0 | 1-5 over: -1 | 6-10 over: -2 | more: -3
##   Coins:  all: 0 | more than half: -1 | half or fewer: -2 | none: -3
## The can holds optimal + limit_margin splats. Scraping refunds paint.

@export_group("Scoring")
@export var minimum_paint := 10  ## Fewest splats that reliably get the playtester to the flag (measured: 7 for the test level).
@export var optimal_margin := 5  ## Optimal = minimum + this. Enough slack to also grab the coins.
@export var limit_margin := 10  ## Can size = optimal + this. Past it you'd be at the bottom anyway.

var coins_collected := 0
var _out_of_paint_timer := 0.0

@onready var runner: Runner = $Runner
@onready var paint: PaintManager = $PaintManager
@onready var paint_label: Label = $HUD/PaintLabel
@onready var paint_gauge: PaintGauge = $HUD/PaintGauge
@onready var coin_label: Label = $HUD/CoinLabel
@onready var status_label: Label = $HUD/StatusLabel
@onready var message_label: Label = $HUD/MessageLabel


func optimal_paint() -> int:
	return minimum_paint + optimal_margin


func paint_limit() -> int:
	return optimal_paint() + limit_margin


func _ready() -> void:
	paint.paint_limit = paint_limit()
	paint_gauge.setup(minimum_paint, optimal_paint(), paint_limit())
	runner.said.connect(func(text): status_label.text = "Playtester: \"%s\"" % text)
	runner.reached_goal.connect(_on_goal)
	runner.died.connect(_on_died)
	paint.paint_changed.connect(_update_paint_label)
	paint.paint_denied.connect(_on_out_of_paint)
	for coin in get_tree().get_nodes_in_group("coin"):
		coin.collected.connect(_on_coin_collected)
	_update_paint_label()
	_update_coin_label()
	message_label.text = "Paint a route, then press Enter to start the playtest."


func _process(delta: float) -> void:
	if _out_of_paint_timer > 0.0:
		_out_of_paint_timer -= delta
		if _out_of_paint_timer <= 0.0:
			_update_paint_label()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("start_test"):
		message_label.text = ""
		runner.start()
	elif event.is_action_pressed("reset_runner"):
		message_label.text = ""
		get_tree().call_group("resettable", "reset_state")  # Coins, doors, buttons, breakables.
		coins_collected = 0
		_update_coin_label()
		runner.reset_to_spawn()
	elif event.is_action_pressed("clear_paint"):
		paint.clear_all()
	elif event.is_action_pressed("toggle_ai_debug"):
		runner.debug_view = not runner.debug_view


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


func _on_goal() -> void:
	var result := score(paint.splats_used, optimal_paint(), coins_collected, _coin_total())
	var stars: int = result.stars
	var paint_line := "Paint: %d  (optimal: %d or less)   %s" % [
		paint.splats_used, optimal_paint(), "✓" if result.paint_penalty == 0 else "-%d★ immersion broken" % result.paint_penalty]
	var coin_line := "Coins: %d / %d   %s" % [
		coins_collected, _coin_total(), "✓" if result.coin_penalty == 0 else "-%d★" % result.coin_penalty]
	message_label.text = "LEVEL COMPLETE   %s\n%s\n%s\nR to reset the level" % [
		"★".repeat(stars) + "☆".repeat(5 - stars), paint_line, coin_line]


func _on_died() -> void:
	message_label.text = "Playtester lost. Focus test scores plummeting.\nR to reset the level"
