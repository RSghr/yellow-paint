extends CharacterBody3D
## The Operator: a first-person level-dresser with a can of yellow paint.

const BASE_SPEED := 10.0
const SPRINT_MULTIPLIER := 1.5
const MOUSE_SENSITIVITY := 0.002
const JUMP_VELOCITY := 4.5
const GRAVITY := 9.8
const BASE_FOV := 90.0
const SPRINT_FOV := 105.0
const PAINT_RANGE := 30.0
const PAINT_REPEAT := 0.12  ## Seconds between splats while holding the button.
const FALL_RESET_Y := -30.0
const JETPACK_ACCEL := 22.0  ## Hold jump in the air to float upward.
const JETPACK_MAX_RISE := 5.0
const FLY_SPEED := 8.0  ## Vertical speed in fly mode.

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D

var locked_mouse := true
var bounds := AABB()  ## Set by game.gd: the far edge of the overheat zone. Sides and top only (falling is FALL_RESET_Y's job).
var active := true  ## False while spectating: no moving, looking or painting (gravity still applies).
var flying := false  ## Fly mode: no gravity, Space up, Ctrl down.
var pitch := 0.0
var speed := BASE_SPEED
var _paint_cooldown := 0.0
var _spawn_transform: Transform3D
var _paint: PaintManager


func _ready() -> void:
	_spawn_transform = global_transform
	_paint = get_tree().get_first_node_in_group("paint_manager")
	if _paint:
		_paint.hotfix_mode_changed.connect(_on_hotfix_mode_changed)
	_set_mouse_locked(true)


## In Hotfix mode (during a playtest) the can turns red, like the splats it makes.
func _on_hotfix_mode_changed(on: bool) -> void:
	var can := get_node_or_null("Head/Camera3D/PaintCan") as MeshInstance3D
	if not can:
		return
	var mat := can.get_surface_override_material(0) as StandardMaterial3D
	if mat:
		mat = mat.duplicate()
		mat.albedo_color = _paint.hotfix_color if on else _paint.paint_color
		mat.emission = mat.albedo_color
		can.set_surface_override_material(0, mat)


func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return
	if event.is_action_pressed("lock_mouse"):
		_set_mouse_locked(not locked_mouse)
	elif event.is_action_pressed("toggle_fly"):
		flying = not flying
		velocity.y = 0.0
	elif not locked_mouse and event is InputEventMouseButton and event.pressed:
		# Clicking the game window grabs the mouse again instead of painting.
		_set_mouse_locked(true)
		get_viewport().set_input_as_handled()
	elif locked_mouse and event.is_action_pressed("scrape"):
		_scrape()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and locked_mouse and active:
		var s := MOUSE_SENSITIVITY * Settings.mouse_sensitivity
		rotate_y(-event.relative.x * s)
		pitch = clamp(pitch - event.relative.y * s, deg_to_rad(-85), deg_to_rad(85))
		head.rotation.x = pitch


func _physics_process(delta: float) -> void:
	# Fast-forward (game.gd) speeds up the playtest, not you: undo Engine.time_scale for the operator.
	delta /= Engine.time_scale
	_move(delta)
	_handle_paint(delta)
	if global_position.y < FALL_RESET_Y:
		global_transform = _spawn_transform
		velocity = Vector3.ZERO


func _move(delta: float) -> void:
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back") if active else Vector2.ZERO
	var direction := (global_basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	var sprinting := Input.is_action_pressed("sprint") and input_dir != Vector2.ZERO
	var target_speed := BASE_SPEED * (SPRINT_MULTIPLIER if sprinting else 1.0)
	var target_fov := SPRINT_FOV if sprinting else BASE_FOV
	speed = move_toward(speed, target_speed, 30.0 * delta)
	camera.fov = move_toward(camera.fov, target_fov, 90.0 * delta)

	velocity.x = direction.x * speed
	velocity.z = direction.z * speed

	if flying:
		var vertical := Input.get_axis("fly_down", "jump") if active else 0.0
		velocity.y = move_toward(velocity.y, vertical * FLY_SPEED, 40.0 * delta)
	elif is_on_floor():
		if active and Input.is_action_just_pressed("jump"):
			velocity.y = JUMP_VELOCITY
	else:
		velocity.y -= GRAVITY * delta
		# Jetpack: keep holding jump in the air to float upward.
		if active and Input.is_action_pressed("jump") and velocity.y < JETPACK_MAX_RISE:
			velocity.y = minf(velocity.y + JETPACK_ACCEL * delta, JETPACK_MAX_RISE)

	var ts := Engine.time_scale
	velocity /= ts  # move_and_slide() steps by the scaled physics delta.
	move_and_slide()
	velocity *= ts
	_keep_in_bounds()


## The level's edges, plus leeway for wide shots: it stops there like against a wall.
func _keep_in_bounds() -> void:
	if not bounds.has_volume():
		return
	var p := global_position
	var lo := bounds.position
	var hi := bounds.end
	var c := Vector3(clampf(p.x, lo.x, hi.x), minf(p.y, hi.y), clampf(p.z, lo.z, hi.z))
	if c.is_equal_approx(p):
		return
	global_position = c
	if c.x != p.x:
		velocity.x = 0.0
	if c.y != p.y:
		velocity.y = minf(velocity.y, 0.0)
	if c.z != p.z:
		velocity.z = 0.0


func _handle_paint(delta: float) -> void:
	_paint_cooldown -= delta
	if active and locked_mouse and Input.is_action_pressed("paint") and _paint_cooldown <= 0.0:
		_paint_cooldown = PAINT_REPEAT
		var hit := _aim_ray()
		if hit and _paint and _paint.paint(hit.position, hit.normal, hit.collider):
			Sfx.play("spray", 0.12)


func _scrape() -> void:
	var hit := _aim_ray()
	if hit and _paint and _paint.scrape(hit.position) > 0:
		Sfx.play("scrape")


## What the crosshair is pointing at (level geometry only).
func _aim_ray() -> Dictionary:
	var from := camera.global_position
	var to := from - camera.global_basis.z * PAINT_RANGE
	var query := PhysicsRayQueryParameters3D.create(from, to, 1, [get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(query)


func _set_mouse_locked(value: bool) -> void:
	locked_mouse = value
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED if value else Input.MOUSE_MODE_VISIBLE)
