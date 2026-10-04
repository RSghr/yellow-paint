class_name WallButton
extends StaticBody3D
## A button on a post. The playtester only presses it if it's painted (any paint on it counts).
## The button faces this node's -Z; the playtester stands in front of it to press.

signal state_changed

## Usually a Door. Anything with an open() method works. A plain node (e.g. a "Maze" Node3D) opens
## every door inside it.
@export var target: NodePath
## More things to open with the same press (doors, or groups of doors).
@export var extra_targets: Array[NodePath] = []

var kind := "button"
var pressed := false

@onready var _cap: MeshInstance3D = $Cap
var _cap_rest: Vector3
var _cap_material := StandardMaterial3D.new()


func _ready() -> void:
	add_to_group("interactable")
	add_to_group("resettable")
	_cap_rest = _cap.position
	_cap_material.emission_enabled = true
	_cap.material_override = _cap_material
	_update_look()
	# An elevator that comes back on its own (Door.return_after) re-arms this button.
	for path in [target] + extra_targets:
		var node := get_node_or_null(path)
		if node and node.has_signal("returned"):
			node.returned.connect(reset_state)


func paint_role(_normal: Vector3) -> String:
	return "interact"


func interact_point(_hit_position: Vector3, _normal: Vector3) -> Vector3:
	var front := -global_basis.z
	front.y = 0
	var p := global_position + front.normalized() * 0.9
	var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 1.0, p - Vector3.UP * 3.0, 1, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	return hit.position if hit else p


func interact_duration() -> float:
	return 0.7


func is_used() -> bool:
	return pressed


func interact(_runner: Node) -> void:
	press()


func press() -> void:
	if pressed:
		return
	pressed = true
	_update_look()
	Sfx.play("button", 0.0)
	for path in [target] + extra_targets:
		_open(get_node_or_null(path))
	state_changed.emit()


## Opens `node`, or if it can't be opened, every openable thing inside it.
func _open(node: Node) -> void:
	if node == null:
		return
	if node.has_method("open"):
		node.open()
		return
	for child in node.get_children():
		_open(child)


func reset_state() -> void:
	pressed = false
	_update_look()
	state_changed.emit()


func _update_look() -> void:
	var c := Color(0.2, 0.9, 0.3) if pressed else Color(0.9, 0.15, 0.1)
	_cap_material.albedo_color = c
	_cap_material.emission = c
	_cap_material.emission_energy_multiplier = 0.6
	_cap.position = _cap_rest + (Vector3(0, 0, 0.05) if pressed else Vector3.ZERO)
