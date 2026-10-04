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
signal returned  ## Back at its start on its own (return_after): buttons that opened it re-arm.

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
## Elevator: seconds after it arrives before it slides back on its own (0 = stays open). It waits while the
## playtester stands on it, and the button that sent it re-arms, so a tester who fell can call it again.
@export var return_after := 0.0

var kind := "door"
var is_open := false
var moving := false  ## True while sliding. The playtester waits for it to stop.
var _closed_position: Vector3
var _tween: Tween
var _ghost: MeshInstance3D  ## Editor only: where it will end up.
var _return_timer := -1.0  ## Counting down to return_after (-1 = not waiting).
var _returning := false  ## Sliding back on its own.


func _ready() -> void:
	super()
	if Engine.is_editor_hint():
		_update_ghost()
	else:
		_closed_position = position
		# Inside another door (e.g. maze walls under the wall that raises them): physics must follow the
		# parent's movement too. With sync_to_physics the collider would stay behind while the mesh moves.
		if _inside_door():
			set("sync_to_physics", false)  # The root is an AnimatableBody3D (the script extends block.gd).
		add_to_group("interactable")
		add_to_group("resettable")
		if is_platform:
			add_to_group("mover")


func _inside_door() -> bool:
	var p := get_parent()
	while p:
		if p is AnimatableBody3D:
			return true
		p = p.get_parent()
	return false


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
	if is_open and return_after > 0.0:
		_return_timer = return_after
	state_changed.emit()


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if _returning:
		_scoop_playtester()
		return
	if _return_timer < 0.0:
		return
	if _carrying_playtester():
		_return_timer = return_after  # Someone's on it: wait until they step off.
		return
	_return_timer -= delta
	if _return_timer <= 0.0:
		_return_timer = -1.0
		_go_back()


## Slides back to where it started (an elevator coming back down), then re-arms its buttons.
func _go_back() -> void:
	if _tween:
		_tween.kill()
	moving = true
	_returning = true
	state_changed.emit()
	Sfx.play("door", 0.0)
	_tween = create_tween()
	_tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_tween.tween_property(self, "position", _closed_position, open_time) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_callback(func():
		is_open = false
		moving = false
		_returning = false
		state_changed.emit()
		returned.emit())


## Coming back down onto a playtester who is under it (e.g. it fell to the bottom of the shaft): it steps on
## instead of being pushed through the floor.
func _scoop_playtester() -> void:
	var box := global_transform * AABB(-size * 0.5, size)
	for body in get_tree().get_nodes_in_group("playtester"):
		var feet: Vector3 = body.global_position - Vector3.UP * 0.9
		var inside_xz := feet.x > box.position.x - 0.3 and feet.x < box.end.x + 0.3 \
			and feet.z > box.position.z - 0.3 and feet.z < box.end.z + 0.3
		if inside_xz and feet.y < box.end.y and feet.y + 1.9 > box.position.y:
			body.global_position.y = box.end.y + 0.95
			body.velocity = Vector3.ZERO


## Is the playtester standing on top of it?
func _carrying_playtester() -> bool:
	var top := global_transform * AABB(-size * 0.5, size)
	top = top.grow(0.4)
	top.position.y += top.size.y - 0.8
	top.size.y = 2.3
	for body in get_tree().get_nodes_in_group("playtester"):
		if top.has_point(body.global_position - Vector3.UP * 0.5):
			return true
	return false


func reset_state() -> void:
	if _tween:
		_tween.kill()
	is_open = false
	moving = false
	_return_timer = -1.0
	_returning = false
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
