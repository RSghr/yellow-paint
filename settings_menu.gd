extends Control
## Settings overlay: options + the full controls list. Used from the main menu and the pause menu.
## Built in code; emits `closed` and frees itself on Back.

signal closed

var title := "SETTINGS"  ## The desktop calls it "COMPANY SETTINGS".

const YELLOW := Color(1, 0.82, 0.05)

## [action, description]. Keys are read from the Input Map, so they always match the real bindings.
const CONTROLS := [
	["move_forward", "Move forward"],
	["move_left", "Move left"],
	["move_back", "Move back"],
	["move_right", "Move right"],
	["jump", "Jump (hold in the air to fly)"],
	["sprint", "Sprint"],
	["toggle_fly", "Fly mode on/off"],
	["fly_down", "Fly down"],
	["paint", "Paint (hold)"],
	["scrape", "Scrape paint (refund, only before a playtest)"],
	["clear_paint", "Clear all paint (only before a playtest)"],
	["start_test", "Start the playtest"],
	["reset_runner", "Hold: reset the level / retry this tester"],
	["toggle_spectator", "Spectator camera (follow the playtester)"],
	["toggle_tester_card", "Show / hide the focus tester card"],
	["toggle_ai_debug", "Show what the AI knows + its jump reach"],
	["next_level", "Next tester (after a round)"],
	["back_to_menu", "Level select"],
	["pause", "Pause menu"],
	["lock_mouse", "Free / capture the mouse"],
]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.08, 0.1, 0.96)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	root.custom_minimum_size = Vector2(760, 0)
	center.add_child(root)

	root.add_child(_label(title, 48, YELLOW))

	# --- Options
	var options := GridContainer.new()
	options.columns = 3
	options.add_theme_constant_override("h_separation", 18)
	root.add_child(options)
	_slider_row(options, "Mouse sensitivity", 0.2, 3.0, 0.05, Settings.mouse_sensitivity,
		func(v): Settings.mouse_sensitivity = v, func(v): return "%.2fx" % v)
	_slider_row(options, "Master volume", 0.0, 1.0, 0.05, Settings.master_volume,
		func(v): Settings.master_volume = v; Settings.apply(), func(v): return "%d%%" % roundi(v * 100))
	_slider_row(options, "Sound effects", 0.0, 1.0, 0.05, Settings.sfx_volume,
		func(v): Settings.sfx_volume = v; Settings.apply(), func(v): return "%d%%" % roundi(v * 100))
	_slider_row(options, "Music", 0.0, 1.0, 0.05, Settings.music_volume,
		func(v): Settings.music_volume = v; Settings.apply(), func(v): return "%d%%" % roundi(v * 100))
	options.add_child(_label("Fullscreen", 20))
	var fs := CheckBox.new()
	fs.button_pressed = Settings.fullscreen
	fs.toggled.connect(func(on): Settings.fullscreen = on; Settings.apply())
	options.add_child(fs)
	options.add_child(Control.new())

	# --- Controls
	root.add_child(_label("Controls", 28, YELLOW))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(760, 420)
	root.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 30)
	grid.add_theme_constant_override("v_separation", 6)
	scroll.add_child(grid)
	for entry in CONTROLS:
		if not InputMap.has_action(entry[0]):
			continue
		var key := _label(_keys_for(entry[0]), 20, YELLOW)
		key.custom_minimum_size = Vector2(200, 0)
		grid.add_child(key)
		grid.add_child(_label(entry[1], 20))

	var back := Button.new()
	back.text = "Back"
	back.custom_minimum_size = Vector2(200, 48)
	back.add_theme_font_size_override("font_size", 24)
	back.pressed.connect(_close)
	root.add_child(back)
	back.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close()


func _close() -> void:
	Sfx.play("ui_click")
	Settings.save()
	closed.emit()
	queue_free()


## Human-readable keys for an action, shown as they're labelled on THIS keyboard layout.
static func _keys_for(action: String) -> String:
	var names: PackedStringArray = []
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			var code: Key = ev.keycode
			if ev.physical_keycode != KEY_NONE:
				# Show the label printed on THIS keyboard (e.g. Z instead of W on AZERTY).
				code = ev.physical_keycode
				if DisplayServer.get_name() != "headless":
					code = DisplayServer.keyboard_get_keycode_from_physical(ev.physical_keycode)
			names.append(OS.get_keycode_string(code))
		elif ev is InputEventMouseButton:
			names.append({MOUSE_BUTTON_LEFT: "Left click", MOUSE_BUTTON_RIGHT: "Right click",
				MOUSE_BUTTON_MIDDLE: "Middle click"}.get(ev.button_index, "Mouse %d" % ev.button_index))
	return " / ".join(names) if names.size() > 0 else "(unbound)"


func _label(text: String, size := 20, color := Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func _slider_row(grid: GridContainer, title: String, lo: float, hi: float, step: float, value: float,
		on_change: Callable, fmt: Callable) -> void:
	grid.add_child(_label(title, 20))
	var slider := HSlider.new()
	slider.min_value = lo
	slider.max_value = hi
	slider.step = step
	slider.value = value
	slider.custom_minimum_size = Vector2(320, 24)
	grid.add_child(slider)
	var readout := _label(fmt.call(value), 20, YELLOW)
	grid.add_child(readout)
	slider.value_changed.connect(func(v):
		on_change.call(v)
		readout.text = fmt.call(v))
