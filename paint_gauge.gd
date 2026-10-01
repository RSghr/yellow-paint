class_name PaintGauge
extends Control
## HUD bar showing how much of the paint can is used.
## Zones: up to optimal (no penalty), then -1 star, then -2 stars, up to the hard limit.
## Ticks mark the level's minimum and optimal amounts.

var used := 0:
	set(v):
		used = v
		queue_redraw()
var minimum := 0
var optimal := 0
var limit := 1
var flash := 0.0  ## Set >0 to flash red (out of paint).

const ZONE_OK := Color(0.25, 0.75, 0.35, 0.35)
const ZONE_WARN := Color(1.0, 0.6, 0.1, 0.35)
const ZONE_BAD := Color(0.9, 0.2, 0.15, 0.35)
const FILL := Color(1.0, 0.82, 0.05)


func setup(p_minimum: int, p_optimal: int, p_limit: int) -> void:
	minimum = p_minimum
	optimal = p_optimal
	limit = maxi(p_limit, 1)
	queue_redraw()


func _process(delta: float) -> void:
	if flash > 0.0:
		flash -= delta
		queue_redraw()


func _x(amount: float) -> float:
	return size.x * clampf(amount / limit, 0.0, 1.0)


func _draw() -> void:
	var h := size.y
	draw_rect(Rect2(0, 0, size.x, h), Color(0, 0, 0, 0.55))
	# Penalty zones.
	var bad_start := optimal + 5
	draw_rect(Rect2(0, 0, _x(optimal), h), ZONE_OK)
	draw_rect(Rect2(_x(optimal), 0, _x(bad_start) - _x(optimal), h), ZONE_WARN)
	draw_rect(Rect2(_x(bad_start), 0, size.x - _x(bad_start), h), ZONE_BAD)
	# Paint used.
	var fill := FILL
	if flash > 0.0 and fmod(flash, 0.2) < 0.1:
		fill = Color(1, 0.15, 0.1)
	draw_rect(Rect2(0, 3, _x(used), h - 6), fill)
	# Minimum / optimal ticks.
	for mark in [[minimum, Color(1, 1, 1, 0.9)], [optimal, Color(0.4, 1, 0.5)]]:
		var x := _x(mark[0])
		draw_line(Vector2(x, -4), Vector2(x, h + 4), mark[1], 2.0)
	draw_rect(Rect2(0, 0, size.x, h), Color(1, 1, 1, 0.6), false, 1.0)
