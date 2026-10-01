@tool
class_name Door
extends "res://block.gd"
## A door that slides up when something calls open() (a WallButton, usually).
## The playtester can't open doors by itself, and painting a door doesn't help.

signal state_changed

@export var open_height := 3.6
@export var open_time := 1.0

var kind := "door"
var is_open := false
var _closed_position: Vector3
var _tween: Tween


func _ready() -> void:
	super()
	if not Engine.is_editor_hint():
		_closed_position = position
		add_to_group("interactable")
		add_to_group("resettable")


func paint_role(_normal: Vector3) -> String:
	return "none"


func is_used() -> bool:
	return true


func open() -> void:
	if is_open:
		return
	is_open = true
	var paint := get_tree().get_first_node_in_group("paint_manager")
	if paint:
		paint.remove_marks_on(self)
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "position", _closed_position + Vector3.UP * open_height, open_time) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_callback(state_changed.emit)


func reset_state() -> void:
	if _tween:
		_tween.kill()
	is_open = false
	position = _closed_position
	state_changed.emit()
