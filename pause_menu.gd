extends CanvasLayer
## Pause menu (Esc during a level): Resume, Settings, Level select, Quit.
## Runs while the tree is paused.

const SETTINGS_MENU := preload("res://settings_menu.gd")
const YELLOW := Color(1, 0.82, 0.05)

signal resumed

var _panel: Control
var _settings: Control
var _was_mouse_captured := true


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_panel.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause"):
		return
	if _settings:
		return  # The settings overlay handles its own Esc.
	get_viewport().set_input_as_handled()
	if get_tree().paused:
		resume()
	else:
		pause()


func pause() -> void:
	_was_mouse_captured = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_panel.visible = true
	(_panel.find_child("Resume", true, false) as Button).grab_focus()


func resume() -> void:
	Sfx.play("ui_click")
	_panel.visible = false
	get_tree().paused = false
	if _was_mouse_captured:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	resumed.emit()


func _open_settings() -> void:
	Sfx.play("ui_click")
	_panel.visible = false
	_settings = SETTINGS_MENU.new()
	add_child(_settings)
	_settings.closed.connect(func():
		_settings = null
		_panel.visible = true
		(_panel.find_child("Settings", true, false) as Button).grab_focus())


func _build() -> void:
	_panel = Control.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_panel)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	center.add_child(box)
	var title := Label.new()
	title.text = "PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 56)
	title.add_theme_color_override("font_color", YELLOW)
	box.add_child(title)
	for entry in [["Resume", resume], ["Settings", _open_settings],
			["Level select", func(): Sfx.play("ui_click"); get_tree().paused = false; Progress.to_menu()],
			["Quit game", func(): get_tree().quit()]]:
		var b := Button.new()
		b.name = entry[0].split(" ")[0]
		b.text = entry[0]
		b.custom_minimum_size = Vector2(320, 56)
		b.add_theme_font_size_override("font_size", 26)
		b.pressed.connect(entry[1])
		box.add_child(b)
