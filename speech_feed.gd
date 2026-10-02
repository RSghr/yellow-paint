extends Control
## The playtester's speech on the HUD (top right, under "Focus tester: ..."), added by game.gd.
## The newest line sits on top at full size. When a new one arrives, older lines slide down,
## shrink and dim. Up to `max_lines` (1 current + 2 old). Old lines fade away after `old_fade_delay`
## seconds without a new message; the current line stays.
## game.gd hides the whole feed while spectating (the speech bubble above the tester is visible then).

@export var max_lines := 3
@export var old_fade_delay := 4.0
@export var line_gap := 4.0
const SCALES := [1.0, 0.8, 0.68]
const ALPHAS := [1.0, 0.7, 0.5]

var _lines: Array[Label] = []  ## [0] = newest.
var _fade_timer: SceneTreeTimer


func _ready() -> void:
	anchor_left = 1.0
	anchor_right = 1.0
	offset_left = -920
	offset_right = -20
	offset_top = 80
	offset_bottom = 260
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func push(text: String) -> void:
	var l := Label.new()
	l.text = "\"%s\"" % text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size = Vector2(size.x, 0)
	l.custom_minimum_size = Vector2(size.x, 0)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", 22)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", 6)
	l.modulate.a = 0.0
	add_child(l)
	_lines.push_front(l)
	while _lines.size() > max_lines:
		_lines.pop_back().queue_free()
	_layout.call_deferred()
	# Old lines fade if nothing new is said for a while.
	_fade_timer = get_tree().create_timer(old_fade_delay)
	var timer := _fade_timer
	timer.timeout.connect(func():
		if timer == _fade_timer:
			_fade_old())


func clear() -> void:
	for l in _lines:
		l.queue_free()
	_lines.clear()
	_fade_timer = null


func _layout() -> void:
	var y := 0.0
	for i in _lines.size():
		var l := _lines[i]
		if not is_instance_valid(l):
			continue
		var s: float = SCALES[mini(i, SCALES.size() - 1)]
		l.pivot_offset = Vector2(l.size.x, 0)  # Shrink toward the right edge.
		if l.has_meta("tween"):
			(l.get_meta("tween") as Tween).kill()
		var t := create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		l.set_meta("tween", t)
		if i == 0:
			l.position = Vector2(0, -12)
			t.tween_property(l, "position", Vector2(0, y), 0.25)
		else:
			t.tween_property(l, "position", Vector2(0, y), 0.3)
		t.tween_property(l, "scale", Vector2(s, s), 0.3)
		t.tween_property(l, "modulate:a", ALPHAS[mini(i, ALPHAS.size() - 1)], 0.3)
		y += l.size.y * s + line_gap


func _fade_old() -> void:
	while _lines.size() > 1:
		var l: Label = _lines.pop_back()
		if not is_instance_valid(l):
			continue
		if l.has_meta("tween"):
			(l.get_meta("tween") as Tween).kill()
		var t := create_tween()
		t.tween_property(l, "modulate:a", 0.0, 0.8)
		t.tween_callback(l.queue_free)
