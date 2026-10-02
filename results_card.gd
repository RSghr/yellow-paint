extends Control
## End-of-round results, same look as the tester card (round_intro.gd). Added to the HUD by game.gd.
##   show_round(data)  - round score: stars popping in, paint/coins/hotfixes breakdown, the tester's
##                       review, and after round 3 the level total (out of 15) + any unlocked level.
##   show_death(...)   - the tester fell out of the level.
##   hide_card()       - gone (R / next round).
## All sizes and colours are constants below, so it's easy to restyle.

const YELLOW := Color(1, 0.82, 0.05)
const GOOD := Color(0.45, 0.9, 0.5)
const BAD := Color(1, 0.45, 0.4)
const MUTED := Color(1, 1, 1, 0.55)
const PANEL_BG := Color(0.07, 0.07, 0.09, 0.94)
const WIDTH := 720.0
const STAR_SIZE := 54
const CARD_SCALE := 1.2  ## Overall size of the card on screen.

var _center: CenterContainer
var _card: PanelContainer
var _tween: Tween


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_center = CenterContainer.new()
	_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_center)


func hide_card() -> void:
	if _tween:
		_tween.kill()
	if _card:
		_card.queue_free()
		_card = null


## data keys: round_index, round_count, tester, result (from game.score()), paint_used, optimal,
## coins, coin_total, hotfixes, quote, nav ([[key, text], ...]), and for the last round `level`:
## {rounds: [{tester, stars}], total, max, new_best, unlocked} ("unlocked" = new level name or "").
func show_round(data: Dictionary) -> void:
	var col := _new_card()
	var result: Dictionary = data.result
	col.add_child(_label("ROUND %d/%d  ·  RESULTS" % [data.round_index + 1, data.round_count], 15, YELLOW))
	col.add_child(_label(FocusGroup.byline(data.tester), 18, MUTED))

	# Stars, popping in one by one.
	var stars_row := HBoxContainer.new()
	stars_row.alignment = BoxContainer.ALIGNMENT_CENTER
	stars_row.add_theme_constant_override("separation", 6)
	stars_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(stars_row)
	var star_labels: Array[Label] = []
	for i in 5:
		var earned: bool = i < result.stars
		var s := _label("★" if earned else "☆", STAR_SIZE, YELLOW if earned else Color(1, 1, 1, 0.25))
		s.modulate.a = 0.0
		s.custom_minimum_size = Vector2(STAR_SIZE, STAR_SIZE * 1.2)
		s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stars_row.add_child(s)
		star_labels.append(s)

	col.add_child(_divider())
	var rows: Array[Control] = []
	rows.append(_row("Paint", "%d  (optimal %d or less)" % [data.paint_used, data.optimal], result.paint_penalty,
		"immersion broken"))
	rows.append(_row("Coins", "%d / %d" % [data.coins, data.coin_total], result.coin_penalty, "missed"))
	rows.append(_row("Hotfixes", str(data.hotfixes), result.hotfix_penalty, "patched mid-playtest"))
	for r in rows:
		col.add_child(r)

	col.add_child(_divider())
	var quote := _label("“%s”" % data.quote, 22, Color.WHITE)
	quote.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	quote.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	quote.custom_minimum_size = Vector2(WIDTH - 60, 0)
	col.add_child(quote)
	var byline := _label("— %s" % FocusGroup.byline(data.tester), 16, MUTED)
	byline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(byline)
	rows.append(quote)
	rows.append(byline)

	if data.has("level"):
		var lv: Dictionary = data.level
		var section := VBoxContainer.new()
		section.add_theme_constant_override("separation", 4)
		section.mouse_filter = Control.MOUSE_FILTER_IGNORE
		section.add_child(_divider())
		var head := HBoxContainer.new()
		head.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var title := _label("LEVEL COMPLETE", 15, YELLOW)
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(title)
		if lv.new_best:
			head.add_child(_label("NEW BEST!", 15, GOOD))
		section.add_child(head)
		for r in lv.rounds:
			var line := HBoxContainer.new()
			line.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var who := _label(r.tester, 18, Color.WHITE)
			who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			line.add_child(who)
			line.add_child(_label("★".repeat(r.stars) + "☆".repeat(5 - r.stars), 20, YELLOW))
			section.add_child(line)
		var total := _label("%d / %d ★" % [lv.total, lv.max], 40, YELLOW)
		total.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		section.add_child(total)
		if lv.get("unlocked", "") != "":
			var note := _label("New playtest scheduled: %s. Check your Inlook." % lv.unlocked, 17, GOOD)
			note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			note.custom_minimum_size = Vector2(WIDTH - 60, 0)
			section.add_child(note)
		elif lv.get("locked_hint", "") != "":
			var hint := _label(lv.locked_hint, 16, MUTED)
			hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			hint.custom_minimum_size = Vector2(WIDTH - 60, 0)
			section.add_child(hint)
		col.add_child(section)
		rows.append(section)

	var nav := _nav(data.nav)
	col.add_child(nav)
	rows.append(nav)
	_animate(star_labels, rows)


func show_death(tester: String, nav: Array) -> void:
	var col := _new_card(BAD)
	col.add_child(_label("FOCUS TESTER LOST", 15, BAD))
	col.add_child(_label(FocusGroup.byline(tester), 18, MUTED))
	col.add_child(_divider())
	var text := _label("%s is no longer with the focus group.\nScores plummeting." % tester, 24, Color.WHITE)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size = Vector2(WIDTH - 60, 0)
	col.add_child(text)
	var n := _nav(nav)
	col.add_child(n)
	_animate([], [text, n])


# --- Building blocks ---------------------------------------------------------

func _new_card(accent := YELLOW) -> VBoxContainer:
	hide_card()
	_card = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_BG
	style.border_width_top = 6
	style.border_color = accent
	style.set_corner_radius_all(10)
	style.content_margin_left = 30
	style.content_margin_right = 30
	style.content_margin_top = 22
	style.content_margin_bottom = 22
	style.shadow_color = Color(0, 0, 0, 0.4)
	style.shadow_size = 20
	_card.add_theme_stylebox_override("panel", style)
	_card.custom_minimum_size = Vector2(WIDTH, 0)
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_center.add_child(_card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(col)
	return col


## "Paint   6 (optimal 8 or less)          ✓"  or  "-1★ immersion broken"
func _row(title: String, value: String, penalty: int, why: String) -> Control:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t := _label(title, 20, Color.WHITE)
	t.custom_minimum_size = Vector2(130, 0)
	row.add_child(t)
	var v := _label(value, 20, Color(1, 1, 1, 0.8))
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(v)
	if penalty == 0:
		row.add_child(_label("✓", 22, GOOD))
	else:
		row.add_child(_label("-%d★ %s" % [penalty, why], 18, BAD))
	return row


func _nav(items: Array) -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 22)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_top", 10)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.add_child(row)
	for item in items:
		var pair := HBoxContainer.new()
		pair.add_theme_constant_override("separation", 8)
		pair.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var key := _label(item[0], 16, Color(0.07, 0.07, 0.09))
		var chip := StyleBoxFlat.new()
		chip.bg_color = YELLOW
		chip.set_corner_radius_all(4)
		chip.content_margin_left = 8
		chip.content_margin_right = 8
		chip.content_margin_top = 1
		chip.content_margin_bottom = 2
		key.add_theme_stylebox_override("normal", chip)
		key.remove_theme_constant_override("outline_size")
		pair.add_child(key)
		pair.add_child(_label(item[1], 17, Color(1, 1, 1, 0.85)))
		row.add_child(pair)
	return pad


func _divider() -> Control:
	var line := ColorRect.new()
	line.color = Color(1, 1, 1, 0.12)
	line.custom_minimum_size = Vector2(0, 2)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line


func _animate(stars: Array[Label], rows: Array) -> void:
	_card.modulate.a = 0.0
	for r in rows:
		r.modulate.a = 0.0
	# Wait one frame so the card knows its size (for the pop-in pivot).
	await get_tree().process_frame
	if not is_instance_valid(_card):
		return
	_card.pivot_offset = _card.size / 2.0
	_card.scale = Vector2.ONE * CARD_SCALE * 0.92
	_tween = create_tween()
	_tween.tween_property(_card, "modulate:a", 1.0, 0.2)
	_tween.parallel().tween_property(_card, "scale", Vector2.ONE * CARD_SCALE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for s in stars:
		s.pivot_offset = s.size / 2.0
		_tween.tween_property(s, "modulate:a", 1.0, 0.08)
		_tween.parallel().tween_property(s, "scale", Vector2.ONE, 0.22).from(Vector2(1.8, 1.8)) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_tween.tween_interval(0.05)
	for r in rows:
		_tween.tween_property(r, "modulate:a", 1.0, 0.12)


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	l.add_theme_constant_override("outline_size", 3)
	return l
