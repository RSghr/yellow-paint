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
@export var death_height := -2.5  ## The playtester is lost below this height. Keep it above the pit floor.

## A level is played by 3 focus testers in a row (paint carries over between rounds).
## Each round has its own minimum: the fewest splats that reliably get THAT tester to the flag (no coins).
## Pick testers from FocusGroup.ROSTER (dropdown). Set the minimums from playtesting.
@export_group("Round 1")
@export var tester_1 := "Rhea Spawn":
	set(v):
		tester_1 = v
		update_configuration_warnings()
@export var minimum_1 := 5:
	set(v):
		minimum_1 = v
		update_configuration_warnings()
@export_group("Round 2")
@export var tester_2 := "Polly Gonn":
	set(v):
		tester_2 = v
		update_configuration_warnings()
@export var minimum_2 := 5:
	set(v):
		minimum_2 = v
		update_configuration_warnings()
@export_group("Round 3")
@export var tester_3 := "Al Gorithm":
	set(v):
		tester_3 = v
		update_configuration_warnings()
@export var minimum_3 := 5:
	set(v):
		minimum_3 = v
		update_configuration_warnings()

const ROUNDS := 3


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


## [{tester, minimum}] for the 3 rounds.
func rounds() -> Array[Dictionary]:
	return [
		{tester = tester_1, minimum = minimum_1},
		{tester = tester_2, minimum = minimum_2},
		{tester = tester_3, minimum = minimum_3},
	]


## Tester fields show as a dropdown of the roster.
func _validate_property(property: Dictionary) -> void:
	if property.name in ["tester_1", "tester_2", "tester_3"]:
		property.hint = PROPERTY_HINT_ENUM
		property.hint_string = ",".join(PackedStringArray(FocusGroup.ROSTER.keys()))


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
	var used := {}
	for i in ROUNDS:
		var r: Dictionary = rounds()[i]
		if not FocusGroup.ROSTER.has(r.tester):
			warnings.append("Round %d: \"%s\" isn't in FocusGroup.ROSTER." % [i + 1, r.tester])
		elif FocusGroup.ROSTER[r.tester].values().count(0) > 1:
			warnings.append("Round %d: %s has more than one ★☆☆ trait (max one). Fix it in FocusGroup.ROSTER." % [i + 1, r.tester])
		elif used.has(r.tester):
			warnings.append("Round %d: %s already plays round %d. Pick a different tester." % [i + 1, r.tester, used[r.tester]])
		used[r.tester] = i + 1
		if r.minimum <= 0:
			warnings.append("Round %d: minimum must be at least 1 (fewest splats that reliably get this tester to the flag)." % (i + 1))
	if level_name.strip_edges() == "" or level_name == "Untitled level":
		warnings.append("Give the level a level_name; it's shown in the menu and HUD.")
	return warnings


func _has_goal(node: Node) -> bool:
	for child in node.get_children():
		if child.scene_file_path == "res://goal.tscn" or _has_goal(child):
			return true
	return false
