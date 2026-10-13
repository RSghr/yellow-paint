@tool
extends EditorScript
## Creates a new level from levels/_template.tscn and opens it.
##
## How to run: open this file in Godot's Script editor, then File > Run (Ctrl+Shift+X).
## The file is levels/level_new.tscn (level_new_2.tscn... if taken): rename the FILE once, right away, to what the level
## is (level_lava_bridge.tscn), with Godot's FileSystem dock. Never rename it after that: saves and playtest logs are
## keyed by file name. Then add it to game.tscn > Inspector > Level order (Levels or DLC) where you want it.
## Until it's listed it shows up last, with a warning.

const TEMPLATE := "res://levels/_template.tscn"


func _run() -> void:
	var path := "res://levels/level_new.tscn"
	var n := 2
	while FileAccess.file_exists(path):
		path = "res://levels/level_new_%d.tscn" % n
		n += 1

	var text := FileAccess.get_file_as_string(TEMPLATE)
	if text.is_empty():
		push_error("Template not found: " + TEMPLATE)
		return
	text = text.replace('[node name="LevelTemplate" type="Node3D"]', '[node name="NewLevel" type="Node3D"]')

	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()

	EditorInterface.get_resource_filesystem().update_file(path)
	EditorInterface.open_scene_from_path(path)
	print("Created %s. Rename the file now (FileSystem dock), add it to game.tscn's Level order, set level_name, build it, then playtest with F6." % path)
