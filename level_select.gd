extends Control
## Main menu: title, level list with best stars, Settings, Quit.
## The level list comes from Progress (every levels/level_*.tscn).

const SETTINGS_MENU := preload("res://settings_menu.gd")
const INTRO_MAIL := preload("res://intro_mail.gd")

@onready var _list: VBoxContainer = $Center/VBox/Levels
@onready var _center: Control = $Center


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().paused = false
	for i in Progress.LEVELS.size():
		var info: Dictionary = Progress.LEVELS[i]
		var stars := Progress.best(info.path)
		var button := _button("%d.  %s      %s" % [i + 1, info.name,
			("%d / 15★" % stars) if stars > 0 else "not finished"])
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(func(): Sfx.play("ui_click"); Progress.play(i))
		_list.add_child(button)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 12)
	_list.add_child(spacer)
	var inbox := _button("Inbox" if Progress.seen_intro else "Inbox (1 unread)")
	inbox.pressed.connect(func(): Sfx.play("ui_click"); _open_mail())
	_list.add_child(inbox)
	var settings := _button("Settings")
	settings.pressed.connect(_open_settings)
	_list.add_child(settings)
	var quit := _button("Quit")
	quit.pressed.connect(func(): get_tree().quit())
	_list.add_child(quit)

	if _list.get_child_count() > 0:
		(_list.get_child(0) as Button).grab_focus()
	if not Progress.seen_intro:
		_open_mail.call_deferred()  # First launch: the boss has a few words.


func _button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(560, 56)
	b.add_theme_font_size_override("font_size", 26)
	return b


func _open_mail() -> void:
	_center.visible = false
	var mail: Control = INTRO_MAIL.new()
	add_child(mail)
	var first_time := not Progress.seen_intro
	mail.closed.connect(func():
		Progress.mark_intro_seen()
		if first_time:
			get_tree().reload_current_scene()  # Refreshes the "unread" label.
		else:
			_center.visible = true)


func _open_settings() -> void:
	Sfx.play("ui_click")
	_center.visible = false
	var menu: Control = SETTINGS_MENU.new()
	add_child(menu)
	menu.closed.connect(func(): _center.visible = true)
