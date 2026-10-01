@tool
class_name Breakable
extends "res://block.gd"
## Something the playtester can smash (planks, crates...).
## Paint on its SIDES means "break this". Paint on its TOP means "stand on this".
## Paint both, and the playtester goes with whichever has more paint (or guesses).

signal state_changed

const DEBRIS_PIECES := 10

var kind := "breakable"
var broken := false


func _ready() -> void:
	super()
	if not Engine.is_editor_hint():
		add_to_group("interactable")
		add_to_group("resettable")


# --- Interactable interface -------------------------------------------------

func paint_role(normal: Vector3) -> String:
	return "nav" if normal.y >= 0.7 else "interact"


## Where to stand to smash the painted side.
func interact_point(hit_position: Vector3, normal: Vector3) -> Vector3:
	var out := Vector3(normal.x, 0, normal.z).normalized()
	return _ground_below(hit_position + out * 0.9)


func interact_duration() -> float:
	return 1.3


func is_used() -> bool:
	return broken


func interact(_runner: Node) -> void:
	smash()


func reset_state() -> void:
	broken = false
	visible = true
	collision_layer = 1
	_shape.disabled = false
	state_changed.emit()


# --- Breaking ---------------------------------------------------------------

func smash() -> void:
	if broken:
		return
	broken = true
	_spawn_debris()
	visible = false
	collision_layer = 0
	_shape.set_deferred("disabled", true)
	var paint := get_tree().get_first_node_in_group("paint_manager")
	if paint:
		paint.remove_marks_on(self)  # The paint goes with the planks.
	state_changed.emit()


func _spawn_debris() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	var piece_size := (size / 3.0).clamp(Vector3.ONE * 0.1, Vector3.ONE * 0.5)
	for i in DEBRIS_PIECES:
		var body := RigidBody3D.new()
		body.collision_layer = 8  # Debris layer: nobody collides with it except the world.
		body.collision_mask = 1
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = piece_size * randf_range(0.5, 1.0)
		shape.shape = box
		var mesh := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = box.size
		mesh.mesh = bm
		mesh.material_override = mat
		body.add_child(shape)
		body.add_child(mesh)
		get_parent().add_child(body)
		body.global_position = global_position + Vector3(
			randf_range(-0.5, 0.5) * size.x, randf_range(-0.5, 0.5) * size.y, randf_range(-0.5, 0.5) * size.z)
		body.apply_central_impulse(Vector3(randf_range(-2, 2), randf_range(1, 4), randf_range(-2, 2)))
		get_tree().create_timer(3.0).timeout.connect(body.queue_free)


func _ground_below(p: Vector3) -> Vector3:
	var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 1.0, p - Vector3.UP * 4.0, 1, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	return hit.position if hit else p
