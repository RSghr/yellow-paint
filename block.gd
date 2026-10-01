@tool
extends StaticBody3D
## Static level block. Resize it with `size` (not the node scale) so physics stays clean.

@export var size := Vector3(2, 2, 2):
	set(value):
		size = value
		if is_node_ready():
			_apply()

@export var color := Color(0.55, 0.56, 0.6):
	set(value):
		color = value
		if is_node_ready():
			_apply()

@onready var _shape: CollisionShape3D = $CollisionShape3D
@onready var _mesh: MeshInstance3D = $MeshInstance3D


func _ready() -> void:
	_apply()


func _apply() -> void:
	# Each block owns its own shape/mesh/material so resizing one doesn't resize them all.
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	_shape.shape = box_shape

	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	_mesh.mesh = box_mesh

	var mat := ShaderMaterial.new()
	mat.shader = preload("res://grid.gdshader")
	mat.set_shader_parameter("base_color", color)
	mat.set_shader_parameter("line_color", color.darkened(0.35))
	_mesh.material_override = mat
