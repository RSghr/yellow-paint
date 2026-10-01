extends Camera3D
## Third-person camera that follows the playtester. Mouse orbits, scroll wheel zooms.
## The Game scene toggles it with the spectator key (A on AZERTY).

@export var height := 1.0  ## Looks at this point above the target's origin.
@export var min_distance := 2.0
@export var max_distance := 16.0

var target: Node3D
var yaw := 0.0
var pitch := -0.35
var distance := 6.0
var active := false:
	set(value):
		active = value
		current = value
		if value and target:
			global_position = _desired_position()


func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var s := 0.003 * Settings.mouse_sensitivity
		yaw -= event.relative.x * s
		pitch = clampf(pitch - event.relative.y * s, -1.3, 0.4)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			distance = maxf(min_distance, distance - 0.6)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			distance = minf(max_distance, distance + 0.6)


func _process(delta: float) -> void:
	if not active or not is_instance_valid(target):
		return
	global_position = global_position.lerp(_desired_position(), 1.0 - exp(-10.0 * delta))
	look_at(_pivot(), Vector3.UP)


func _pivot() -> Vector3:
	return target.global_position + Vector3.UP * height


func _desired_position() -> Vector3:
	var pivot := _pivot()
	var offset := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, pitch) * Vector3(0, 0, distance)
	var desired := pivot + offset
	# Don't clip through level geometry: pull in if something is between the camera and the target.
	var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(pivot, desired, 1))
	if hit:
		desired = hit.position + hit.normal * 0.3
	return desired
