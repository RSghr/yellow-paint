class_name Coin
extends Area3D
## Shiny collectible. The playtester spots coins without paint (they sparkle, as all AAA
## coins do), but will only WALK to them. A coin past a gap needs paint to get there.

signal collected(coin: Coin)

var taken := false
var _t := 0.0

@onready var _visual: Node3D = $Visual


func _ready() -> void:
	add_to_group("coin")
	add_to_group("resettable")
	body_entered.connect(_on_body_entered)
	_t = randf() * TAU


func _process(delta: float) -> void:
	_t += delta
	_visual.rotation.y += delta * 2.5
	_visual.position.y = 0.9 + sin(_t * 2.0) * 0.08


func _on_body_entered(body: Node3D) -> void:
	if taken or not body is Runner:
		return
	taken = true
	visible = false
	set_deferred("monitoring", false)
	collected.emit(self)


func reset_state() -> void:
	taken = false
	visible = true
	set_deferred("monitoring", true)
