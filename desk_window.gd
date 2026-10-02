extends PanelContainer
## A window on the fake company desktop (level_select.gd): title bar you can drag, a close button,
## and whatever content you put in `body`. Emits `closed` and frees itself when closed.

signal closed
signal focused

const TITLE_BG := Color(0.16, 0.33, 0.62)
const FRAME := Color(0.93, 0.93, 0.91)

var title := "Window"
var body: Control  ## Set before adding to the tree.
var _dragging := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var frame := StyleBoxFlat.new()
	frame.bg_color = FRAME
	frame.set_corner_radius_all(6)
	frame.shadow_color = Color(0, 0, 0, 0.45)
	frame.shadow_size = 18
	frame.shadow_offset = Vector2(0, 6)
	add_theme_stylebox_override("panel", frame)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	add_child(col)

	var bar := PanelContainer.new()
	var bar_style := StyleBoxFlat.new()
	bar_style.bg_color = TITLE_BG
	bar_style.corner_radius_top_left = 6
	bar_style.corner_radius_top_right = 6
	bar_style.content_margin_left = 14
	bar_style.content_margin_right = 6
	bar_style.content_margin_top = 4
	bar_style.content_margin_bottom = 4
	bar.add_theme_stylebox_override("panel", bar_style)
	bar.mouse_filter = Control.MOUSE_FILTER_STOP
	bar.gui_input.connect(_on_bar_input)
	col.add_child(bar)

	var row := HBoxContainer.new()
	bar.add_child(row)
	var label := Label.new()
	label.text = title
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(label)
	for glyph in ["_", "□"]:  # Decorative, like every corporate machine's broken minimize/maximize.
		var fake := Label.new()
		fake.text = glyph
		fake.custom_minimum_size = Vector2(34, 0)
		fake.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		fake.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
		fake.add_theme_font_size_override("font_size", 18)
		fake.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(fake)
	var close := Button.new()
	close.text = "X"
	close.flat = true
	close.custom_minimum_size = Vector2(40, 30)
	close.add_theme_color_override("font_color", Color.WHITE)
	close.add_theme_color_override("font_hover_color", Color(1, 0.5, 0.45))
	close.add_theme_font_size_override("font_size", 18)
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(close_window)
	row.add_child(close)

	if body:
		col.add_child(body)


func close_window() -> void:
	Sfx.play("ui_click")
	closed.emit()
	queue_free()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		focused.emit()


func _on_bar_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
		if event.pressed:
			focused.emit()
	elif event is InputEventMouseMotion and _dragging:
		position += event.relative
		# Keep the title bar on screen.
		var screen := get_viewport_rect().size
		position.x = clampf(position.x, -size.x + 120, screen.x - 120)
		position.y = clampf(position.y, 0, screen.y - 90)
