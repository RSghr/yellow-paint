extends Control
## Launch day: the credits after the greenlight (opened by level_select.gd once the patch notes are read
## and Inlook is closed). Built in code, one timeline:
##   title card > scrolling credits > what the investors said > what the focus group said
##   > the scores (critics first, then gamers) > the ending's name > back to the desktop (Patch 1.1).
## Hold Space / Enter / left click to fast-forward. Texts per ending live in endings.gd.

const ENDINGS := preload("res://endings.gd")
const YELLOW := Color(1, 0.82, 0.05)
const SOFT := Color(1, 1, 1, 0.55)
const SCROLL_SPEED := 95.0  ## Pixels per second for the credits roll.
const FAST := 6.0  ## Fast-forward speed while held.

var _seq: Tween
var _ending: Dictionary
var _hint: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_ending = ENDINGS.info(Progress.ending)
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_hint = _label("Hold Space to fast-forward", 15, Color(1, 1, 1, 0.3))
	_hint.anchor_left = 1.0
	_hint.anchor_right = 1.0
	_hint.anchor_top = 1.0
	_hint.anchor_bottom = 1.0
	_hint.offset_left = -320
	_hint.offset_right = -24
	_hint.offset_top = -44
	_hint.offset_bottom = -16
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_hint)
	_build.call_deferred()  # Needs the viewport size.


func _process(_delta: float) -> void:
	var held := Input.is_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_ENTER) \
		or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	if _seq and _seq.is_valid():
		_seq.set_speed_scale(FAST if held else 1.0)


func _build() -> void:
	var screen := get_viewport_rect().size
	_seq = create_tween()

	# --- Title card ---
	var presents := _centered(_label("SYNERGEX INTERACTIVE presents", 26, SOFT, true))
	_fade(presents, 0.8, 1.6, 0.8)
	var title := VBoxContainer.new()
	title.add_child(_label("HYPERION LEGENDS", 84, YELLOW, true))
	title.add_child(_label("ETERNAL DAWN", 40, Color.WHITE, true))
	title.add_child(_label("v1.0.0  ·  Launch day", 20, SOFT, true))
	_centered(title)
	_fade(title, 1.0, 2.6, 1.0)
	_seq.tween_interval(0.6)

	# --- Credits roll ---
	var roll := VBoxContainer.new()
	roll.add_theme_constant_override("separation", 10)
	roll.custom_minimum_size = Vector2(1000, 0)
	for entry in _credit_lines():
		if entry.size() == 1:
			var head := _label(entry[0], 22, YELLOW, true)
			head.custom_minimum_size = Vector2(1000, 64)
			head.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
			roll.add_child(head)
		else:
			roll.add_child(_credit_row(entry[0], entry[1]))
	add_child(roll)
	roll.reset_size()
	var h := roll.get_combined_minimum_size().y
	roll.position = Vector2((screen.x - 1000) / 2.0, screen.y + 20)
	_seq.tween_property(roll, "position:y", -h - 20, (h + screen.y + 40) / SCROLL_SPEED)
	_seq.tween_callback(roll.queue_free)
	_seq.tween_interval(0.8)

	# --- What the investors said ---
	var inv: Array = []
	for q in _ending.investors:
		inv.append([q[0], q[1]])
	_quote_page("WHAT THE INVESTORS SAID", inv)

	# --- What the focus group said ---
	_quote_page("WHAT THE FOCUS GROUP SAID", _tester_quotes())

	# --- The scores ---
	_scores(screen)

	# --- Back to the desk ---
	_seq.tween_interval(0.8)
	_seq.tween_callback(_finish)


## [[role, name], ...] and [header] entries.
func _credit_lines() -> Array:
	var lines := [
		["A SYNERGEX INTERACTIVE PRODUCTION"],
		["VP of Player Engagement & Synergy", "Chad Bossworth"],
		["Level Readability (yellow paint)", "Contractor #%d" % Progress.contractor_id()],
		["Level Readability (previous yellow paint)", "Contractors #4471 to #%d" % (Progress.contractor_id() - 1)] \
			if Progress.resignations > 0 else [],
		["Art Direction", "Grey, Slightly Different Grey"],
		["The Art Department", "Both of them"],
		["Legal", "Legal"],
		["Snacks", "Legal"],
		["IT Helpdesk", "Have you tried turning it off and on again"],
		["People & Culture", "Mandatory, Optional"],
		["Coffee", "SynergyBrew+ (9.99/month)"],
		["FOCUS GROUP"],
	]
	lines = lines.filter(func(l): return not l.is_empty())
	var seen := {}
	for info in Progress.LEVELS:
		if info.post_launch:
			continue
		for t in Progress.level_testers(info.path):
			if seen.has(t):
				continue
			seen[t] = true
			lines.append([FocusGroup.profile(t).get("outlet", "Freelance"), t])
	lines.append_array([
		["SPECIAL THANKS"],
		["The investors", "(mandatory)"],
		["Darren from Accounting", "We still don't know who took the yogurt"],
		["Every grey box", "You were beautiful"],
		["Yellow paint", "86.9 GB of it"],
		["No focus testers were harmed in the making of this game.\n(Several fell. That's different.)"],
	])
	return lines


func _credit_row(role: String, name_text: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 40)
	var r := _label(role, 22, SOFT)
	r.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	r.custom_minimum_size = Vector2(480, 0)
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(r)
	var n := _label(name_text, 22, YELLOW if name_text.begins_with("Contractor #") else Color.WHITE)
	n.custom_minimum_size = Vector2(480, 0)
	n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(n)
	return row


## Up to 3 stat quotes from the testers who played the most, + the ending's line from another one.
func _tester_quotes() -> Array:
	var stats: Dictionary = Progress.tester_stats
	var names: Array = stats.keys()
	names.sort_custom(func(a, b): return stats[a].get("tests", 0) > stats[b].get("tests", 0))
	var out := []
	for n in names.slice(0, 3):
		out.append([ENDINGS.tester_quote(stats[n]), "%s, %s" % [n, FocusGroup.profile(n).get("outlet", "freelance")]])
	var tail_by := "Rhea Spawn"
	if names.size() > 3:
		tail_by = names[3]
	elif not names.is_empty():
		tail_by = names[0]
	out.append([_ending.tester_tail, "%s, %s" % [tail_by, FocusGroup.profile(tail_by).get("outlet", "freelance")]])
	return out


## A header and quotes appearing one by one, then everything fades.
func _quote_page(header: String, quotes: Array) -> void:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 34)
	col.add_child(_label(header, 24, YELLOW, true))
	var items := []
	for q in quotes:
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 4)
		var text := _label("\"%s\"" % q[0], 28, Color.WHITE, true)
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.custom_minimum_size = Vector2(1300, 0)
		box.add_child(text)
		box.add_child(_label("- " + q[1], 18, SOFT, true))
		box.modulate.a = 0.0
		col.add_child(box)
		items.append(box)
	_centered(col)
	col.modulate.a = 0.0
	_seq.tween_property(col, "modulate:a", 1.0, 0.8)
	for box in items:
		_seq.tween_property(box, "modulate:a", 1.0, 0.7)
		_seq.tween_interval(2.6)
	_seq.tween_interval(1.5)
	_seq.tween_property(col, "modulate:a", 0.0, 0.8)
	_seq.tween_callback(col.queue_free)
	_seq.tween_interval(0.5)


func _scores(screen: Vector2) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 160)
	var critics := _score_block("THE CRITICS", "METACRISIS", _ending.critics_label, "", 100)
	var gamers := _score_block("THE GAMERS", "STEAMY USER REVIEWS", _ending.gamers_label, _ending.gamers_quote, 10)
	row.add_child(critics.root)
	row.add_child(gamers.root)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 70)
	col.add_child(row)
	var ending_label := _label("ENDING: %s" % _ending.title.to_upper(), 30, YELLOW, true)
	ending_label.modulate.a = 0.0
	col.add_child(ending_label)
	_centered(col)
	critics.root.modulate.a = 0.0
	gamers.root.modulate.a = 0.0

	# Critics first...
	_seq.tween_property(critics.root, "modulate:a", 1.0, 0.6)
	_seq.tween_method(func(v: float): _set_score(critics, v, 100, false), 0.0, float(_ending.critics), 2.0) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_seq.tween_callback(func(): Sfx.play("score_reveal", 0.0); critics.verdict.modulate.a = 1.0)
	_seq.tween_interval(2.0)
	# ...then the gamers.
	_seq.tween_property(gamers.root, "modulate:a", 1.0, 0.6)
	_seq.tween_method(func(v: float): _set_score(gamers, v, 10, true), 0.0, float(_ending.gamers), 2.0) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_seq.tween_callback(func(): Sfx.play("score_reveal", 0.0); gamers.verdict.modulate.a = 1.0; gamers.quote.modulate.a = 1.0)
	_seq.tween_interval(2.5)
	_seq.tween_property(ending_label, "modulate:a", 1.0, 1.0)
	_seq.tween_interval(4.0)
	_seq.tween_property(col, "modulate:a", 0.0, 1.5)


func _score_block(who: String, outlet: String, verdict: String, quote: String, _max: int) -> Dictionary:
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 6)
	root.custom_minimum_size = Vector2(520, 0)
	root.add_child(_label(who, 26, SOFT, true))
	root.add_child(_label(outlet, 16, Color(1, 1, 1, 0.35), true))
	var number := _label("0", 150, Color.WHITE, true)
	root.add_child(number)
	var v := _label(verdict, 26, Color.WHITE, true)
	v.modulate.a = 0.0  # Hidden but still taking its space, so nothing jumps when it appears.
	root.add_child(v)
	var q := _label(quote, 20, SOFT, true)
	q.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	q.custom_minimum_size = Vector2(520, 0)
	q.modulate.a = 0.0
	root.add_child(q)
	return {root = root, number = number, verdict = v, quote = q}


func _set_score(block: Dictionary, value: float, max_value: int, decimal: bool) -> void:
	block.number.text = ("%.1f" % value) if decimal else str(roundi(value))
	var ratio := value / max_value
	var c := Color(0.95, 0.3, 0.25) if ratio < 0.5 else (YELLOW if ratio < 0.75 else Color(0.4, 0.85, 0.4))
	block.number.add_theme_color_override("font_color", c)
	block.verdict.add_theme_color_override("font_color", c)


func _finish() -> void:
	Progress.finish_credits()
	Progress.desktop_fade_in = true
	get_tree().change_scene_to_file(Progress.MENU_SCENE)


# --- Helpers ---------------------------------------------------------------

## Adds `node` centred on screen (inside a full-screen CenterContainer). Returns the node.
func _centered(node: Control) -> Control:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	center.add_child(node)
	_hint.move_to_front()
	return node


## Fade in, hold, fade out, then remove.
func _fade(node: Control, fade_in: float, hold: float, fade_out: float) -> void:
	node.modulate.a = 0.0
	_seq.tween_property(node, "modulate:a", 1.0, fade_in)
	_seq.tween_interval(hold)
	_seq.tween_property(node, "modulate:a", 0.0, fade_out)
	_seq.tween_callback(node.get_parent().queue_free)


func _label(text: String, size: int, color: Color, center := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if center:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l
