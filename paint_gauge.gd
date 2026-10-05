class_name PaintGauge
extends Control
## HUD bar showing how much of the paint can is used.
## Zones: up to optimal (no penalty), then -1, -2 and -3 stars (game.gd paint_steps()), up to the hard limit.
## Ticks mark the round's minimum and optimal amounts.

var used := 0:
	set(v):
		used = v
		queue_redraw()
var minimum := 0
var optimal := 0
var steps: Array[int] = []  ## Splat counts where the penalty becomes -1, -2, -3.
var limit := 1
var flash := 0.0  ## Set >0 to flash red (out of paint).

const ZONE_OK := Color(0.25, 0.75, 0.35, 0.35)
const ZONE_WARN := Color(1.0, 0.6, 0.1, 0.35)
const ZONE_BAD := Color(0.9, 0.2, 0.15, 0.35)
const FILL := Color(1.0, 0.82, 0.05)


func setup(p_minimum: int, p_steps: Array[int], p_limit: int) -> void:
	minimum = p_minimum
	steps = p_steps
	optimal = p_steps[0] - 1 if not p_steps.is_empty() else p_minimum
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
	# Each zone covers the splat counts that cost that many stars (a splat count n sits in [n-1, n]).
	var edges: Array[float] = [0.0]
	for st in steps:
		edges.append(st - 1)
	edges.append(limit)
	var colors := [ZONE_OK, ZONE_WARN, ZONE_WARN.lerp(ZONE_BAD, 0.5), ZONE_BAD]
	for i in edges.size() - 1:
		var a := _x(edges[i])
		draw_rect(Rect2(a, 0, _x(edges[i + 1]) - a, h), colors[mini(i, colors.size() - 1)])
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
