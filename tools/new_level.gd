@tool
extends EditorScript
## Creates a new level from levels/_template.tscn and opens it.
##
## How to run: open this file in Godot's Script editor, then File > Run (Ctrl+Shift+X).
## The file is levels/level_new.tscn (level_new_2.tscn... if taken): rename the FILE once, right away, to what the level
## is (level_lava_bridge.tscn), with Godot's FileSystem dock so references follow. Never rename it after that: saves and
## playtest logs are keyed by file name. Its place in the game is its `order` (Inspector), set here to come last;
## to move levels around, change their `order` numbers.

const TEMPLATE := "res://levels/_template.tscn"


func _run() -> void:
	var path := "res://levels/level_new.tscn"
	var n := 2
	while FileAccess.file_exists(path):
		path = "res://levels/level_new_%d.tscn" % n
		n += 1

	# Last of the main game: one more than the highest `order` so far.
	var last := 0
	for f in DirAccess.get_files_at("res://levels"):
		if f.begins_with("level_") and f.ends_with(".tscn") and not f.begins_with("level_dlc_"):
			var packed := load("res://levels/" + f) as PackedScene
			var state := packed.get_state() if packed else null
			for i in (state.get_node_property_count(0) if state else 0):
				if state.get_node_property_name(0, i) == "order":
					last = maxi(last, int(state.get_node_property_value(0, i)))

	var text := FileAccess.get_file_as_string(TEMPLATE)
	if text.is_empty():
		push_error("Template not found: " + TEMPLATE)
		return
	text = text.replace('[node name="LevelTemplate" type="Node3D"]', '[node name="NewLevel" type="Node3D"]')
	text = text.replace('level_name = "New level"', 'level_name = "New level"\norder = %d' % (last + 1))

	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()

	EditorInterface.get_resource_filesystem().update_file(path)
	EditorInterface.open_scene_from_path(path)
	print("Created %s (order %d). Rename the file now (FileSystem dock), set level_name, build it, then playtest with F6." % [path, last + 1])
