@tool
class_name Door
extends "res://block.gd"
## A block that slides when something calls open() (a WallButton, usually).
##
## As a DOOR (default): slides up out of the way. The playtester can't open doors by itself,
## and painting a door doesn't help (the joke).
##
## As a PLATFORM (`is_platform` on): paint on its TOP is a landing like any other, and the paint
## rides along when it moves. Use it as an elevator (paint it, put the button on it) or as a
## bridge that slides into place. The playtester stands still while it's moving under its feet,
## and won't jump onto it until it has stopped.
##
## The root is an AnimatableBody3D, so it carries whatever stands on it.

signal state_changed

@export var move_direction := Vector3.UP:  ## Which way it slides (any axis, normalized for you).
	set(v):
		move_direction = v
		_update_ghost()
@export var move_distance := 3.6:  ## How far it slides, in metres. The editor shows a ghost where it ends up.
	set(v):
		move_distance = v
		_update_ghost()
@export var open_time := 1.0  ## Seconds to get there.
@export var is_platform := false  ## Paint on top = a landing that moves with it. Off = a plain door.

var kind := "door"
var is_open := false
var moving := false  ## True while sliding. The playtester waits for it to stop.
var _closed_position: Vector3
var _tween: Tween
var _ghost: MeshInstance3D  ## Editor only: where it will end up.


func _ready() -> void:
	super()
	if Engine.is_editor_hint():
		_update_ghost()
	else:
		_closed_position = position
		add_to_group("interactable")
		add_to_group("resettable")
		if is_platform:
			add_to_group("mover")


func paint_role(normal: Vector3) -> String:
	if is_platform and normal.y >= 0.7:
		return "nav"
	return "none"


func is_used() -> bool:
	return true


## Paint on a platform rides along with it (see PaintMark).
func carries_paint() -> bool:
	return is_platform


func open_position() -> Vector3:
	return _closed_position + move_direction.normalized() * move_distance


func open() -> void:
	if is_open:
		return
	is_open = true
	Sfx.play("door", 0.0)
	if not is_platform:
		var paint := get_tree().get_first_node_in_group("paint_manager")
		if paint:
			paint.remove_marks_on(self)
	if _tween:
		_tween.kill()
	moving = true
	state_changed.emit()
	_tween = create_tween()
	_tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)  # Moves in step with physics so riders are carried.
	_tween.tween_property(self, "position", open_position(), open_time) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_callback(_on_arrived)


func _on_arrived() -> void:
	moving = false
	state_changed.emit()


func reset_state() -> void:
	if _tween:
		_tween.kill()
	is_open = false
	moving = false
	position = _closed_position
	state_changed.emit()


## Editor preview: a see-through copy at the open position (not saved in the scene).
func _update_ghost() -> void:
	if not Engine.is_editor_hint() or not is_inside_tree():
		return
	if not _ghost:
		_ghost = MeshInstance3D.new()
		var mat := StandardMaterial3D.new()
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(0.3, 0.8, 1.0, 0.25)
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_ghost.material_override = mat
		add_child(_ghost)  # No owner: never saved.
	var box := BoxMesh.new()
	box.size = size
	_ghost.mesh = box
	var offset := move_direction.normalized() * move_distance
	_ghost.position = transform.basis.inverse() * offset
