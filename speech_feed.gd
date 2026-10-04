extends Control
## The playtester's speech on the HUD as a chat log (top right, under "Focus tester: ..."), added by game.gd.
## Like an online chat: "Name: message", oldest on top, newest at the bottom, up to `max_lines`.
## Each line disappears `line_life` seconds after it was said. The newest line is a bit bigger
## (`newest_scale`); it goes back to normal size when the next one arrives.
## game.gd hides the whole feed while spectating (the speech bubble above the tester is visible then).

const YELLOW := Color(1, 0.82, 0.05)

@export var max_lines := 3
@export var line_life := 6.0  ## Seconds a line stays before fading out.
@export var width := 620.0
@export var font_size := 19
@export var newest_scale := 1.5  ## Size of the latest line relative to the others.

var _box: VBoxContainer


func _ready() -> void:
	anchor_left = 1.0
	anchor_right = 1.0
	offset_left = -width - 20
	offset_right = -20
	offset_top = 82
	offset_bottom = 300
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box = VBoxContainer.new()
	_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_box.add_theme_constant_override("separation", 3)
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_box)


func push(speaker: String, text: String) -> void:
	var line := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.07, 0.55)
	style.set_corner_radius_all(4)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 3
	style.content_margin_bottom = 4
	line.add_theme_stylebox_override("panel", style)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_set_font_px(label, roundi(font_size * newest_scale))
	label.text = "[b][color=#%s]%s:[/color][/b] %s" % [YELLOW.to_html(false), speaker, _escape(text)]
	line.add_child(label)

	# The previous newest line goes back to normal size.
	for old in _box.get_children():
		if old.get_child_count() > 0:
			_set_font_px(old.get_child(0), font_size)
	line.modulate.a = 0.0
	_box.add_child(line)
	while _box.get_child_count() > max_lines:
		var oldest := _box.get_child(0)
		_box.remove_child(oldest)
		oldest.queue_free()

	var t := line.create_tween()
	t.set_ignore_time_scale(true)  # Readable at fast-forward too.
	t.tween_property(line, "modulate:a", 1.0, 0.15)
	t.tween_interval(line_life)
	t.tween_property(line, "modulate:a", 0.0, 0.5)
	t.tween_callback(line.queue_free)


func clear() -> void:
	for c in _box.get_children():
		c.queue_free()


func _set_font_px(label: RichTextLabel, px: int) -> void:
	label.add_theme_font_size_override("normal_font_size", px)
	label.add_theme_font_size_override("bold_font_size", px)


static func _escape(text: String) -> String:
	return text.replace("[", "[lb]")
