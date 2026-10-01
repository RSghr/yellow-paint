@tool
extends EditorScript
## Creates the next levels/level_XX.tscn from levels/_template.tscn and opens it.
##
## How to run: open this file in Godot's Script editor, then File > Run (Ctrl+Shift+X).
## The new level shows up in the level select automatically (levels are sorted by file name).

const TEMPLATE := "res://levels/_template.tscn"


func _run() -> void:
	var n := 1
	while FileAccess.file_exists("res://levels/level_%02d.tscn" % n):
		n += 1
	var path := "res://levels/level_%02d.tscn" % n

	var text := FileAccess.get_file_as_string(TEMPLATE)
	if text.is_empty():
		push_error("Template not found: " + TEMPLATE)
		return
	text = text.replace('[node name="LevelTemplate" type="Node3D"]', '[node name="Level%02d" type="Node3D"]' % n)
	text = text.replace('level_name = "New level"', 'level_name = "Level %d"' % n)

	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()

	EditorInterface.get_resource_filesystem().update_file(path)
	EditorInterface.open_scene_from_path(path)
	print("Created %s. Rename it via level_name, build it, then playtest with F6." % path)
