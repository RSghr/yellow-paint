extends Control
## Start-of-round presentation (added to the HUD by game.gd):
##   - the level's intro text at the top (first round only),
##   - the focus tester's card sliding in from the bottom left: round, name, outlet, intro line,
##     then the three trait stars popping in one by one.
## Both fade out after `hold_time` seconds, or right away when the playtest starts (dismiss()).
## C (toggle_tester_card) brings the card back at any time and keeps it up until C is pressed again.

const YELLOW := Color(1, 0.82, 0.05)

@export var hold_time := 7.0  ## Seconds before everything fades away.

var _banner: Label
var _card: PanelContainer
var _stat_rows: Array[Control] = []
var _tween: Tween
var _showing := false  ## The card is on screen (or sliding in).


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_banner = Label.new()
	_banner.anchor_left = 0.5
	_banner.anchor_right = 0.5
	_banner.offset_left = -640
	_banner.offset_right = 640
	_banner.offset_top = 140
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_banner.add_theme_font_size_override("font_size", 28)
	_banner.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_banner.add_theme_constant_override("outline_size", 8)
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.modulate.a = 0.0
	add_child(_banner)


## Show the card for this round. `intro` = level intro text ("" to skip the banner).
func play(intro: String, round_index: int, round_count: int, tester: String, note := "") -> void:
	if _tween:
		_tween.kill()
	if _card:
		_card.queue_free()
	_stat_rows.clear()
	_banner.text = intro
	_banner.modulate.a = 0.0
	_card = _build_card(round_index, round_count, tester, note)
	add_child(_card)
	_card.modulate.a = 1.0
	_card.position.x = -_card.size.x - 40  # Off screen to the left; slides in once laid out.
	_animate.call_deferred(true)


## C: show the card again (it stays until C is pressed again), or hide it.
func toggle() -> void:
	if not _card:
		return
	if _showing:
		dismiss()
		return
	if _tween:
		_tween.kill()
	_banner.modulate.a = 0.0
	_banner.text = ""  # Only the card comes back; the level intro was a one-time thing.
	_card.modulate.a = 1.0
	for row in _stat_rows:
		row.modulate.a = 0.0
	_animate(false)


func dismiss() -> void:
	if not _card or not _showing:
		return
	_showing = false
	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel()
	_tween.tween_property(_card, "modulate:a", 0.0, 0.3)
	_tween.tween_property(_banner, "modulate:a", 0.0, 0.3)


func _animate(auto_fade: bool) -> void:
	if not _card:
		return
	_showing = true
	_card.position.x = -_card.size.x - 40
	_tween = create_tween()
	if _banner.text != "":
		_tween.tween_property(_banner, "modulate:a", 1.0, 0.4)
	_tween.tween_property(_card, "position:x", 24.0, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for row in _stat_rows:
		_tween.tween_property(row, "modulate:a", 1.0, 0.18)
		_tween.parallel().tween_property(row, "position:x", 0.0, 0.18).from(-30.0)
		_tween.tween_interval(0.08)
	if not auto_fade:
		return
	_tween.tween_interval(hold_time)
	_tween.tween_callback(func(): _showing = false)
	_tween.tween_property(_card, "modulate:a", 0.0, 0.8)
	_tween.parallel().tween_property(_banner, "modulate:a", 0.0, 0.8)


func _build_card(round_index: int, round_count: int, tester: String, note: String) -> PanelContainer:
	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.07, 0.09, 0.9)
	style.border_width_left = 6
	style.border_color = YELLOW
	style.set_corner_radius_all(8)
	style.content_margin_left = 22
	style.content_margin_right = 22
	style.content_margin_top = 16
	style.content_margin_bottom = 18
	card.add_theme_stylebox_override("panel", style)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.custom_minimum_size = Vector2(520, 0)
	# Pinned to the bottom left, growing upwards.
	card.anchor_top = 1.0
	card.anchor_bottom = 1.0
	card.grow_vertical = Control.GROW_DIRECTION_BEGIN
	card.offset_bottom = -64
	card.offset_top = -64

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(col)
	col.add_child(_label("ROUND %d/%d  ·  FOCUS TESTER" % [round_index + 1, round_count], 15, YELLOW))
	col.add_child(_label(tester, 36, Color.WHITE))
	col.add_child(_label(FocusGroup.profile(tester).get("outlet", "Freelance"), 18, Color(1, 1, 1, 0.55)))
	var intro := _label("\"%s\"" % FocusGroup.intro(tester), 17, Color(1, 1, 1, 0.85))
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.custom_minimum_size = Vector2(476, 0)
	col.add_child(intro)

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 8)
	col.add_child(gap)
	var p := FocusGroup.profile(tester)
	for t in ["jump", "trust", "patience"]:
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var trait_label := _label(FocusGroup.TRAIT_LABELS[t], 20, Color.WHITE)
		trait_label.custom_minimum_size = Vector2(200, 0)
		row.add_child(trait_label)
		row.add_child(_label(FocusGroup.stars(p[t]), 26, YELLOW))
		row.modulate.a = 0.0
		col.add_child(row)
		_stat_rows.append(row)
	if note != "":
		var n := _label(note, 15, Color(1, 1, 1, 0.55))
		n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		n.custom_minimum_size = Vector2(476, 0)
		col.add_child(n)
	return card


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	l.add_theme_constant_override("outline_size", 3)
	return l
