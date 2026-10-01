extends Area3D
## End of level. Always visible to the runner (it's the one thing that's pre-painted).


func _ready() -> void:
	add_to_group("goal")
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	$Ring.rotate_y(delta * 1.5)


func _on_body_entered(body: Node3D) -> void:
	if body is Runner:
		body.celebrate()
