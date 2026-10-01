extends Control
## Title + level list with best stars. Built in code so adding a level only needs a line in progress.gd.

const YELLOW := Color(1, 0.82, 0.05)

@onready var _list: VBoxContainer = $Center/VBox/Levels


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	for i in Progress.LEVELS.size():
		var info: Dictionary = Progress.LEVELS[i]
		var stars := Progress.best(info.path)
		var button := Button.new()
		button.text = "%d.  %s      %s" % [i + 1, info.name, ("★".repeat(stars) + "☆".repeat(5 - stars)) if stars > 0 else "not finished"]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size = Vector2(560, 56)
		button.add_theme_font_size_override("font_size", 26)
		button.pressed.connect(Progress.play.bind(i))
		_list.add_child(button)
	if _list.get_child_count() > 0:
		(_list.get_child(0) as Button).grab_focus()
