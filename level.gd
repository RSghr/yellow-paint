class_name Level
extends Node3D
## Root script for every level scene (levels/level_XX.tscn).
##
## A level contains ONLY the world: blocks, interactables, coins, the Goal, and two Marker3D
## spawn points named "RunnerSpawn" and "OperatorSpawn". The Game scene (game.tscn) adds the
## HUD, the operator, the playtester, paint and scoring around it.
##
## Tip: press F6 on a level scene and it launches inside the Game scene automatically.

@export var level_name := "Untitled level"
@export_multiline var intro_text := "Paint a route, then press Enter to start the playtest."
@export var minimum_paint := 5  ## Fewest splats that reliably get the playtester to the flag (no coins). Set from playtesting.
@export var death_height := -2.5  ## The playtester is lost below this height.


func _ready() -> void:
	# Opened directly with F6? Hop into the Game scene with this level loaded.
	if not Engine.is_editor_hint() and get_tree().current_scene == self:
		Progress.play_path.call_deferred(scene_file_path)


func runner_spawn() -> Transform3D:
	var m := get_node_or_null("RunnerSpawn") as Node3D
	return m.global_transform if m else Transform3D(Basis(), Vector3(0, 0.9, 0))


func operator_spawn() -> Transform3D:
	var m := get_node_or_null("OperatorSpawn") as Node3D
	return m.global_transform if m else Transform3D(Basis(), Vector3(-2, 1.05, 2))
