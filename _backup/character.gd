extends CharacterBody3D

const BASE_SPEED := 10.0
const MOUSE_SENSITIVITY := 0.002
const JUMP_VELOCITY := 4.5
const GRAVITY := 9.8

@onready var head = $Head
@onready var camera = $Head/Camera3D

#Player Movement
var SPEED := 10.0
var locked_mouse = true # This is for Debugging, get rid of it later mayber
var velocity_value: Vector3 = Vector3.ZERO
var pitch := 0.0  # Vertical camera angle
var sprint = false
var sprint_rate = 1

#Interacting Objects
var held_object: RigidBody3D = null
var is_charging_throw := false
var throw_charge := 0.0
const MAX_THROW_FORCE := 50.0

#Resources
@export var money: int:
	set(value):
		if money == value:
			return
		money = value
		emit_signal("money_changed", money)

@export var mana: int:
	set(value):
		if mana == value:
			return
		mana = value
		emit_signal("mana_changed", mana)

signal money_changed(new_value)
signal mana_changed(new_value)

func _ready():
	money = 50
	mana = 100
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
func _unhandled_input(event):
	pass
					
	#Get info
	if event.is_action_pressed("lock_mouse"): #Lock/Unlock mouse
		if locked_mouse :
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			locked_mouse = false
		else :
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			locked_mouse = true

func _input(event):
	if event is InputEventMouseMotion and locked_mouse:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		pitch = clamp(pitch - event.relative.y * MOUSE_SENSITIVITY, deg_to_rad(-75), deg_to_rad(75))
		head.rotation.x = pitch

func _physics_process(delta): #Basic Movement
	var input_dir = Vector3.ZERO
	if Input.is_action_pressed("move_forward"):
		input_dir.z -= 1
	if Input.is_action_pressed("move_back"):
		input_dir.z += 1
	if Input.is_action_pressed("move_left"):
		input_dir.x -= 1
	if Input.is_action_pressed("move_right"):
		input_dir.x += 1

	input_dir = input_dir.normalized()
	var base = global_transform.basis
	var direction = (base.x * input_dir.x + base.z * input_dir.z).normalized()
	
	velocity.x = direction.x * SPEED
	velocity.z = direction.z * SPEED

	# Gravity
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		if Input.is_action_just_pressed("jump"):
			velocity.y = JUMP_VELOCITY
	
	if Input.is_action_just_pressed("sprint"):
		sprint = true
		
	if Input.is_action_just_released("sprint"):
		sprint = false
	
	if sprint and SPEED <= BASE_SPEED * 1.5:
		SPEED += sprint_rate
		if camera.fov < 105 :
			camera.fov += sprint_rate
	elif !sprint and SPEED >= BASE_SPEED :
		SPEED = BASE_SPEED
		if camera.fov > 90 :
			camera.fov -= sprint_rate * 2
	
	move_and_slide()
