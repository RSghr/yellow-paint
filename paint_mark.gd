class_name PaintMark
extends Node3D
## One yellow splat. Visual is a Decal so it wraps over ledge corners like real paint.

var is_nav := false  ## True if the runner treats this as somewhere it can go.
var is_floor := false  ## On a walkable surface (extra splats on a spot are floor but not nav).
var stand_point := Vector3.ZERO  ## Where the runner's feet should land (nudged away from edges).
var role := "none"  ## "nav" (go here), "interact" (use this thing) or "none" (just paint on a wall).
var host: Node = null  ## The interactable this paint is on, if any.
var normal := Vector3.UP
var interact_point := Vector3.ZERO  ## For "interact" paint: where to stand to use the host.
var hotfix := false  ## Painted during a playtest (a "hotfix"): red, counted separately in the score, removed on reset.


var _follow: Node3D  ## A moving platform this paint is stuck to.
var _local_transform: Transform3D
var _local_stand: Vector3

var _decal: Decal
var _age := 0.0
var _base_size := Vector3.ONE


func build_visual(normal: Vector3, texture: Texture2D, color := Color(1.0, 0.82, 0.05)) -> void:
	var decal := Decal.new()
	_decal = decal
	decal.modulate = color  # The image is white; this makes it yellow (or red for a hotfix).
	var s := randf_range(0.9, 1.3)
	if hotfix:
		s = 1.5  # Big, glowing and pulsing: a hotfix should be impossible to miss.
		decal.texture_emission = texture
		decal.emission_energy = 2.0
	decal.size = Vector3(1.3 * s, 0.6, 1.3 * s)
	_base_size = decal.size
	decal.texture_albedo = texture
	decal.albedo_mix = 1.0
	decal.upper_fade = 0.05
	decal.lower_fade = 0.05
	add_child(decal)

	# A Decal projects along its local -Y, so point local +Y along the surface normal.
	var up := normal.normalized()
	var helper := Vector3.FORWARD if absf(up.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT
	var x_axis := up.cross(helper).normalized()
	var z_axis := x_axis.cross(up).normalized()
	decal.global_basis = Basis(x_axis, up, z_axis).rotated(up, randf() * TAU)


## Stick to a moving platform: from now on this mark (and its stand point) moves with it.
func attach_to(node: Node3D) -> void:
	_follow = node
	_local_transform = node.global_transform.affine_inverse() * global_transform
	_local_stand = node.global_transform.affine_inverse() * stand_point
	set_physics_process(true)


func follows() -> bool:
	return _follow != null


func _ready() -> void:
	set_physics_process(_follow != null)


func _physics_process(_delta: float) -> void:
	if not is_instance_valid(_follow):
		set_physics_process(false)
		return
	global_transform = _follow.global_transform * _local_transform
	stand_point = _follow.global_transform * _local_stand


## Hotfix splats slap down with a pop, then keep pulsing.
func _process(delta: float) -> void:
	if not hotfix or not _decal:
		set_process(false)
		return
	_age += delta
	var pop := 1.0 + 0.6 * exp(-_age * 8.0) * cos(_age * 25.0)  # Overshoot, then settle.
	var pulse := 1.0 + 0.08 * sin(_age * 6.0)
	var k := pop * pulse
	_decal.size = Vector3(_base_size.x * k, _base_size.y, _base_size.z * k)
	_decal.emission_energy = 1.5 + 1.5 * (0.5 + 0.5 * sin(_age * 6.0))
