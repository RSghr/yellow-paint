extends Control
## Main menu: title, level list with best stars, Settings, Quit.
## The level list comes from Progress (every levels/level_*.tscn).

const SETTINGS_MENU := preload("res://settings_menu.gd")

@onready var _list: VBoxContainer = $Center/VBox/Levels
@onready var _center: Control = $Center


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().paused = false
	for i in Progress.LEVELS.size():
		var info: Dictionary = Progress.LEVELS[i]
		var stars := Progress.best(info.path)
		var button := _button("%d.  %s      %s" % [i + 1, info.name,
			("★".repeat(stars) + "☆".repeat(5 - stars)) if stars > 0 else "not finished"])
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(func(): Sfx.play("ui_click"); Progress.play(i))
		_list.add_child(button)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 12)
	_list.add_child(spacer)
	var settings := _button("Settings")
	settings.pressed.connect(_open_settings)
	_list.add_child(settings)
	var quit := _button("Quit")
	quit.pressed.connect(func(): get_tree().quit())
	_list.add_child(quit)

	if _list.get_child_count() > 0:
		(_list.get_child(0) as Button).grab_focus()


func _button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(560, 56)
	b.add_theme_font_size_override("font_size", 26)
	return b


func _open_settings() -> void:
	Sfx.play("ui_click")
	_center.visible = false
	var menu: Control = SETTINGS_MENU.new()
	add_child(menu)
	menu.closed.connect(func(): _center.visible = true)
