extends Node3D
## The Game scene: loads the current Level (see Progress), then adds the playtester,
## the operator, paint, HUD and scoring around it.
##
## A level is 3 rounds, one focus tester each (Level.rounds()). Paint carries over between rounds;
## each round has its own minimum (that tester's), so its own optimal and can size.
## The level result is the 3 round scores added up, out of 15.
##
## Round scoring: start at 5 stars, subtract paint, coin and hotfix penalties (minimum 1 star).
##   Paint, relative to the round minimum m (paint_steps()): each step is a % of m, at least 1 splat more than
##   the step before:  under m + 20%: 0 | m + 20%: -1 | m + 40%: -2 | m + 50%: -3   (so 5★ = "optimal" = step 1 - 1)
##   Coins:  all: 0 | more than half: -1 | half or fewer: -2 | none: -3
##   Hotfixes (splats painted DURING the playtest, outside the can, removed on R): the level has
##   free_hotfixes (2) shared by its 3 rounds, used up in order. The rest cost:  1-3: -1 | 4+: -2
## The can holds the -3 step + max(5, step 1) splats. Scraping refunds paint.

const RUNNER_SCENE := preload("res://runner.tscn")
const OPERATOR_SCENE := preload("res://character.tscn")
const PAUSE_MENU := preload("res://pause_menu.gd")
const SPECTATOR_CAMERA := preload("res://spectator_camera.gd")
const ROUND_INTRO := preload("res://round_intro.gd")
const OVERHEAT := preload("res://overheat.gd")
const SPEECH_FEED := preload("res://speech_feed.gd")
const RESULTS_CARD := preload("res://results_card.gd")

@export_group("Scoring")
## Paint penalty steps, as a fraction of the round minimum: reaching minimum * (1 + step) costs 1, 2, 3 stars.
## Each step is at least one splat more than the one before (so the first one is at least minimum + 1).
@export var paint_step_ratios: Array[float] = [0.2, 0.4, 0.5]
@export var free_hotfixes := 2  ## Hotfixes per level (all 3 rounds together) that don't cost stars. Chad's mails use MailWriter.HOTFIX_BUDGET.
@export var retry_hold_time := 1.0  ## Seconds R must be held to retry (avoids accidental resets).
## T during a playtest cycles through these speeds. Physics ticks scale with it, so the AI plays exactly the same.
@export var fast_forward_speeds: Array[float] = [1.0, 2.0, 4.0]

var level: Level
var runner: Runner
var operator: CharacterBody3D
var coins_collected := 0
var _finished := false
var _playtest_running := false  ## From Enter until R: scraping is locked so paint can't be recycled mid-run.
var hotfixes := 0  ## Splats painted during this playtest run.
var round_hotfixes: Array[int] = [0, 0, 0]  ## Hotfixes of each round's finishing run (they use up free_hotfixes in order).
var _out_of_paint_timer := 0.0
var spectator: Camera3D
var spectating := false
var round_index := 0  ## 0-2: which focus tester is playing.
var round_stars: Array[int] = [0, 0, 0]  ## Stars per round (0 = not finished yet).
var round_times: Array = [null, null, null]  ## {tester, session, lost} per finished round (logged, not scored).
var round_runs: Array = [null, null, null]  ## {tester, stats} of each round's finishing attempt (saved if the level total is a new best).
var _retry_hold := 0.0
var _speed_index := 0
var _base_ticks := 60
var _speed_label: Label
var _reach_anchor := Vector3.INF  ## Last floor the operator aimed at (the reach gizmo stays there when aiming at a wall).
var _attempt_open := false  ## A playtest is running and its stats haven't been logged yet.
var _round_tested := false  ## This round's tester has been started at least once (retries count after that).
var _retry_lock := false  ## R must be released before another retry can start.
var _retry_bar: Control  ## "Hold R to retry" progress, bottom centre.
var _retry_fill: ColorRect
var round_intro: Control  ## Level intro banner + sliding tester card (round_intro.gd).
var _cursor_was_captured := false  ## Before the tester card was brought up with C.
@export var bounds_margin := 20.0  ## Room past the level's edges before the ThinkBox starts to struggle (overheat.gd).
@export var bounds_headroom := 25.0  ## Same, above the level's highest point.
var overheat: Node  ## Pixelation + fan past the comfort zone (overheat.gd).
## The sky (art/thinkbox_sky.gdshader), rolled each time a level loads: midday, sunset or night, and the
## missing-texture checker once in a while.
const SKY_NAMES := ["midday", "sunset", "night", "missing texture"]
@export var missing_texture_chance := 0.005
@export var force_sky := -1  ## DEBUG: 0-3 always uses that sky (see SKY_NAMES), -1 = random.
var sky_variant := 0
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
	_roll_sky()
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
	round_intro.inspecting_changed.connect(_on_card_inspecting)
	results_card = RESULTS_CARD.new()
	$HUD.add_child(results_card)
	_build_retry_bar()
	_build_speed_label()
	_base_ticks = Engine.physics_ticks_per_second
	_start_round(0)
	add_child(PAUSE_MENU.new())


## C brought the tester card up: free the cursor to hover its traits, and grab it back when the card goes away
## (only if it was grabbed before).
func _on_card_inspecting(on: bool) -> void:
	if on:
		_cursor_was_captured = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
		operator._set_mouse_locked(false)
	elif _cursor_was_captured and not get_tree().paused:
		operator._set_mouse_locked(true)



## The comfort zone: everything visible in the level, plus `bounds_margin` on each side and `bounds_headroom` above,
## so the whole level fits in a wide shot. Past it the ThinkBox struggles (overheat.gd), then there's a wall.
func _operator_bounds() -> AABB:
	var box := AABB(level.operator_spawn().origin, Vector3.ZERO)
	box = box.expand(level.runner_spawn().origin)
	for node in level.find_children("*", "VisualInstance3D", true, false):
		var v := node as VisualInstance3D
		if v.is_visible_in_tree():
			box = box.merge(v.global_transform * v.get_aabb())
	box = box.grow(bounds_margin)
	box.size.y += bounds_headroom - bounds_margin
	return box



func _roll_sky() -> void:
	if force_sky >= 0:
		sky_variant = force_sky
	elif randf() < missing_texture_chance:
		sky_variant = 3
	else:
		sky_variant = randi() % 3
	var env: Environment = $WorldEnvironment.environment
	(env.sky.sky_material as ShaderMaterial).set_shader_parameter("variant", sky_variant)


func _exit_tree() -> void:
	_set_speed(0)  # Never leave the desktop/credits running fast.
	_close_attempt("quit")  # Left mid-playtest (pause menu): it still counts as a test.


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
	overheat = OVERHEAT.new()
	overheat.comfort = _operator_bounds()
	add_child(overheat)
	operator.bounds = overheat.comfort.grow(overheat.strain_distance)  # The wall: full pixel mess there.

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
	paint_gauge.setup(r.minimum, paint_steps(), paint_limit())
	_reset_run()
	level_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN  # Right-aligned in the corner: grow leftwards.
	level_label.text = "%s%s" % [
		"" if Progress.level_override != "" else "%s: " % Progress.level_label(Progress.current), level.level_name]
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


## Splat counts where the paint penalty goes to -1, -2, -3 stars for this round (see paint_step_ratios).
func paint_steps() -> Array[int]:
	return steps_for(current_round().minimum, paint_step_ratios)


static func steps_for(minimum: int, ratios: Array[float]) -> Array[int]:
	var steps: Array[int] = []
	var prev := minimum
	for ratio in ratios:
		prev = maxi(prev + 1, minimum + ceili(minimum * ratio - 0.0001))
		steps.append(prev)
	return steps


## The most paint that still costs nothing (5★ territory).
func optimal_paint() -> int:
	return paint_steps()[0] - 1


## The can: twice the 5★ amount, so the bar shows the penalty zones and some room beyond (at least one splat
## past the -3★ step).
func paint_limit() -> int:
	return maxi(optimal_paint() * 2, paint_steps()[-1] + 1)


## Free hotfixes still available to this round (the earlier rounds' finishing runs used theirs first).
func free_hotfixes_left() -> int:
	return maxi(0, free_hotfixes - _earlier_hotfixes())


## Hotfixes of the earlier rounds' finishing runs.
func _earlier_hotfixes() -> int:
	var used := 0
	for i in round_index:
		used += round_hotfixes[i]
	return used


## "3/2": hotfixes used on this level so far (earlier rounds + this run) / the level's free budget.
func hotfix_tally() -> String:
	return "%d/%d" % [_earlier_hotfixes() + hotfixes, free_hotfixes]


func _process(delta: float) -> void:
	delta /= Engine.time_scale  # HUD timers run in real time, even at fast-forward.
	_process_retry_hold(delta)
	_update_reach_gizmo()
	if _out_of_paint_timer > 0.0:
		_out_of_paint_timer -= delta
		if _out_of_paint_timer <= 0.0:
			_update_paint_label()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_CAPSLOCK:
		_caps_lock_joke()
		return
	if OS.is_debug_build() and event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode == KEY_F10:
		_toggle_recording_view()  # DEBUG only (not in release builds): hide every bit of UI for recording.
		return
	if event.is_action_pressed("start_test"):
		message_label.text = ""
		round_intro.dismiss()
		_playtest_running = true
		paint.scrape_locked = true
		paint.hotfix_mode = true
		_update_coin_label()  # Shows the free hotfixes left while the playtest runs.
		if not _attempt_open and not _finished and runner.state != Runner.State.DEAD:
			_attempt_open = true
			_round_tested = true
		runner.start()
	elif event.is_action_pressed("fast_forward"):
		if _playtest_running and not _finished and runner.state != Runner.State.DEAD:
			_set_speed((_speed_index + 1) % fast_forward_speeds.size())
	elif event.is_action_pressed("clear_paint"):
		paint.clear_all()
	elif event.is_action_pressed("toggle_tester_card"):
		round_intro.toggle()
	elif event.is_action_pressed("toggle_ai_debug"):
		runner.debug_view = not runner.debug_view
	elif event.is_action_pressed("toggle_spectator"):
		_toggle_spectator()
	elif event.is_action_pressed("next_level") and _finished and round_index + 1 < Level.ROUNDS:
		_start_round(round_index + 1)  # After the 3rd tester it's back to the computer (Esc > Level select).


## V (AI debug view): the tester's jump reach, centred where you aim (on a floor), or on the tester while spectating.
## Only while painting (not from Enter until R).
func _update_reach_gizmo() -> void:
	if not runner.debug_view:
		return
	if _playtest_running:
		runner.draw_reach(Vector3.INF)  # A painting tool: hidden during the playtest so the vision view stays clean.
		return
	if spectating:
		runner.draw_reach(runner.feet())
		return
	var hit: Dictionary = operator._aim_ray()
	if not hit.is_empty() and hit.normal.y > 0.7:
		_reach_anchor = hit.position
	runner.draw_reach(_reach_anchor if _reach_anchor != Vector3.INF else runner.feet())


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


## Fast-forward: index into fast_forward_speeds (0 = normal speed).
func _set_speed(index: int) -> void:
	_speed_index = index
	var s: float = fast_forward_speeds[index] if index < fast_forward_speeds.size() else 1.0
	Engine.time_scale = s
	Engine.physics_ticks_per_second = roundi(_base_ticks * s)  # Same physics step: same jumps, same AI.
	Engine.max_physics_steps_per_frame = maxi(8, ceili(8 * s))
	if _speed_label:
		_speed_label.visible = s > 1.0
		_speed_label.text = "▶▶ %dx" % roundi(s)


func _build_speed_label() -> void:
	_speed_label = Label.new()
	_speed_label.anchor_left = 0.5
	_speed_label.anchor_right = 0.5
	_speed_label.offset_left = -100
	_speed_label.offset_right = 100
	_speed_label.offset_top = 16
	_speed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_speed_label.add_theme_font_size_override("font_size", 30)
	_speed_label.add_theme_color_override("font_color", Color(1, 0.82, 0.05))
	_speed_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_speed_label.add_theme_constant_override("outline_size", 8)
	_speed_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_speed_label.visible = false
	$HUD.add_child(_speed_label)


func _reset_run() -> void:
	_set_speed(0)
	_close_attempt("reset")
	_out_of_paint_timer = 0.0  # Drop any timed HUD message (e.g. "HOTFIX #n").
	_finished = false
	_playtest_running = false
	paint.scrape_locked = false
	paint.hotfix_mode = false
	hotfixes = 0
	paint.remove_hotfixes()  # Back to the route as it was before the playtest.
	paint.restore_stashed()  # Paint on planks/doors broken or opened during the run comes back with them.
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


## Caps Lock: would toggle green paint, but that's a ThinkBox 2009 Pro+ feature (see the IT quick start mail).
## DEBUG (F10, debug builds only, not in the Input Map or the controls list): hides the whole HUD and the tester's
## speech bubble so the game can be recorded clean. F10 again brings them back.
func _toggle_recording_view() -> void:
	$HUD.visible = not $HUD.visible
	runner.get_node("Speech").visible = $HUD.visible



func _caps_lock_joke() -> void:
	if _out_of_paint_timer > 0.0:
		return
	_out_of_paint_timer = 2.5
	Sfx.play("out_of_paint", 0.0)
	paint_label.add_theme_color_override("font_color", Color(1, 0.25, 0.2))
	paint_label.text = ["Green paint requires ThinkBox 2009 Pro+.", "Green paint is a ThinkBox 2009 Pro+ feature. It was out of budget.",
		"Nice try. Green paint is ThinkBox 2009 Pro+ only."].pick_random()


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
	if hotfixes > 0 or _playtest_running or _earlier_hotfixes() > 0:
		coin_label.text += "      Hotfixes: %s" % hotfix_tally()


## Painting during a playtest is allowed, but it's a "hotfix": counted and called out.
func _on_splat_added(mark: PaintMark) -> void:
	if not mark.hotfix:
		return
	hotfixes += 1
	_update_coin_label()
	_out_of_paint_timer = 1.5  # Reuses the timed paint-label message.
	paint_label.add_theme_color_override("font_color", Color(1, 0.55, 0.1))
	var free := free_hotfixes_left()
	var note := ""
	if hotfixes <= free:
		note = "  (within budget: %s)" % hotfix_tally()
	elif hotfixes - free >= 4:
		note = "  (%s: the focus group is starting to notice)" % hotfix_tally()
	else:
		note = "  (%s: over budget, costs stars)" % hotfix_tally()
	paint_label.text = "HOTFIX #%d applied mid-playtest%s" % [hotfixes, note]


## steps: splat counts where the paint penalty becomes 1, 2, 3 (steps_for()). free: hotfixes that cost nothing.
## Returns {stars, paint_penalty, coin_penalty, hotfix_penalty, free_hotfixes}.
static func score(paint_used: int, steps: Array[int], coins: int, coin_total: int, hotfix_count := 0,
		free := 0) -> Dictionary:
	var paint_penalty := 0
	for step in steps:
		if paint_used >= step:
			paint_penalty += 1
	var coin_penalty := 0
	if coin_total > 0 and coins < coin_total:
		if coins == 0:
			coin_penalty = 3
		elif coins * 2 <= coin_total:
			coin_penalty = 2
		else:
			coin_penalty = 1
	var paid := maxi(0, hotfix_count - free)
	var hotfix_penalty := 0
	if paid >= 4:
		hotfix_penalty = 2
	elif paid >= 1:
		hotfix_penalty = 1
	return {
		stars = clampi(5 - paint_penalty - coin_penalty - hotfix_penalty, 1, 5),
		paint_penalty = paint_penalty,
		coin_penalty = coin_penalty,
		hotfix_penalty = hotfix_penalty,
		free_hotfixes = mini(hotfix_count, free),
	}


## Key hints shown at the bottom of the results card: [[key, text], ...]
func _nav_keys() -> Array:
	var keys := []
	if round_index + 1 < Level.ROUNDS:
		keys.append(["N", "next tester"])
	keys.append(["Hold R", "retry this tester"])
	if round_index + 1 == Level.ROUNDS:
		keys.append(["Esc", "back to your desk"])  # No Tab shortcut: one stray key press used to throw a level away.
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
	_set_speed(0)  # Results at normal speed.
	_close_attempt("finish")
	_finished = true
	var result := score(paint.splats_used, paint_steps(), coins_collected, _coin_total(), hotfixes,
		free_hotfixes_left())
	round_stars[round_index] = result.stars
	round_hotfixes[round_index] = hotfixes
	Sfx.play("goal", 0.0)
	# Times are logged (best per round, to beat later) but never affect the stars.
	var session := runner.session_time
	var lost := runner.time_lost
	round_times[round_index] = {tester = runner.tester_name, session = session, lost = lost, hotfixes = hotfixes,
		hotfix_budget = free_hotfixes}
	round_runs[round_index] = {tester = runner.tester_name, stats = {
		tests = 1, finishes = 1, failed_jumps = runner.failed_jumps, lost = lost, played = session,
		hotfixes_seen = runner.hotfixes_seen, hotfixes = hotfixes}}
	var prev_best := Progress.record_time(Progress.current_path(), round_index, session, lost) \
		if Progress.level_override == "" else -1.0
	var data := {
		round_index = round_index, round_count = Level.ROUNDS, tester = runner.tester_name, result = result,
		paint_used = paint.splats_used, optimal = optimal_paint(), coins = coins_collected,
		coin_total = _coin_total(), hotfixes = hotfixes, hotfix_tally = hotfix_tally(),
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
		var new_best := Progress.record(Progress.current_path(), total, round_runs.filter(func(r): return r != null))
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
	_set_speed(0)  # Results at normal speed.
	_close_attempt("death")
	results_card.show_death(runner.tester_name, [["Hold R", "retry"], ["Esc", "menu"]])
