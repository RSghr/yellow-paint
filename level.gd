@tool
class_name Level
extends Node3D
## Root script for every level scene (levels/level_XX.tscn). See docs/LEVEL_DESIGN.md.
##
## A level contains ONLY the world: blocks, interactables, coins, the Goal, and two Marker3D
## spawn points named "RunnerSpawn" and "OperatorSpawn". The Game scene (game.tscn) adds the
## HUD, the operator, the playtester, paint and scoring around it.
##
## Tip: press F6 on a level scene and it launches inside the Game scene automatically.
## The editor shows a warning icon on the root if something required is missing.

@export var level_name := "Untitled level":
	set(v):
		level_name = v
		update_configuration_warnings()
@export_multiline var intro_text := "Paint a route, then press Enter to start the playtest."
@export var minimum_paint := 5:  ## Fewest splats that reliably get the playtester to the flag (no coins). Set from playtesting.
	set(v):
		minimum_paint = v
		update_configuration_warnings()
@export var death_height := -2.5  ## The playtester is lost below this height. Keep it above the pit floor.


func _ready() -> void:
	if Engine.is_editor_hint():
		child_entered_tree.connect(func(_n): update_configuration_warnings())
		child_exiting_tree.connect(func(_n): update_configuration_warnings.call_deferred())
		return
	# Opened directly with F6? Hop into the Game scene with this level loaded.
	if get_tree().current_scene == self:
		var progress := get_tree().root.get_node_or_null("Progress")  # Looked up at runtime: this is also a @tool script.
		if progress:
			progress.play_path.call_deferred(scene_file_path)


func runner_spawn() -> Transform3D:
	var m := get_node_or_null("RunnerSpawn") as Node3D
	return m.global_transform if m else Transform3D(Basis(), Vector3(0, 0.9, 0))


func operator_spawn() -> Transform3D:
	var m := get_node_or_null("OperatorSpawn") as Node3D
	return m.global_transform if m else Transform3D(Basis(), Vector3(-2, 1.05, 2))


func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if not has_node("RunnerSpawn"):
		warnings.append("Add a Marker3D named \"RunnerSpawn\" where the playtester starts (0.9 above the floor).")
	if not has_node("OperatorSpawn"):
		warnings.append("Add a Marker3D named \"OperatorSpawn\" where you (the operator) start.")
	if not _has_goal(self):
		warnings.append("No Goal: instance goal.tscn where the level ends.")
	if minimum_paint <= 0:
		warnings.append("minimum_paint must be at least 1 (the fewest splats that reliably finish the level).")
	if level_name.strip_edges() == "" or level_name == "Untitled level":
		warnings.append("Give the level a level_name; it's shown in the menu and HUD.")
	return warnings


func _has_goal(node: Node) -> bool:
	for child in node.get_children():
		if child.scene_file_path == "res://goal.tscn" or _has_goal(child):
			return true
	return false
