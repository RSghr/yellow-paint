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


func build_visual(normal: Vector3, texture: Texture2D) -> void:
	var decal := Decal.new()
	var s := randf_range(0.9, 1.3)
	decal.size = Vector3(1.3 * s, 0.6, 1.3 * s)
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
