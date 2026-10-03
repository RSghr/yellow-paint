extends Control
## Main menu, dressed as the operator's company computer (Synergex Interactive).
##   Desktop icons: Inlook (mail, inbox.gd), Level Select, Company Settings, Recycle Bin.
##   Taskbar: Start menu (with Shut down), open windows, clock.
##   Quitting = shutting the computer down, which HR has opinions about.
## First launch is a clean desktop (the Inlook badge does the talking). Coming back from a level reopens Level Select.
## Release: Chad's "greenlight" mail has the ship button; after it, closing Inlook (patch notes read) rolls
## the credits (credits.gd), which come back here for Patch 1.1.
## Everything is built in code; windows are desk_window.gd.

const SETTINGS_MENU := preload("res://settings_menu.gd")
const DESK_WINDOW := preload("res://desk_window.gd")
const INBOX := preload("res://inbox.gd")
const SPLAT := preload("res://art/paint_splat.png")
const CREDITS_SCENE := "res://credits.tscn"
const ENDINGS := preload("res://endings.gd")

const YELLOW := Color(1, 0.82, 0.05)
const INK := Color(0.12, 0.12, 0.15)
const MUTED := Color(0.42, 0.43, 0.48)
const CORP_BLUE := Color(0.16, 0.33, 0.62)
const TASKBAR_H := 52.0

var _windows := {}  ## id -> desk window
var _layer: Control  ## Windows live here (above icons, below the taskbar).
var _taskbar_buttons: HBoxContainer
var _start_menu: Control
var _clock: Label
var _inbox_badge: Label
var _modal: Control  ## Shut down dialog / settings, blocks the desktop.
var _close_modal := Callable()  ## How Esc closes the current modal (settings closes itself).


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().paused = false
	_build_wallpaper()
	_build_icons()
	_layer = Control.new()
	_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_layer)
	_build_taskbar()

	if Progress.desktop_fade_in:  # Back from the credits: the screen comes back on.
		Progress.desktop_fade_in = false
		_fade_in()
	if Progress.new_mail_ping and Progress.seen_intro:
		Progress.new_mail_ping = false
		_toast.call_deferred()
	# First launch: a clean desktop. The unread badge on Inlook does the talking.
	if Progress.open_levels_on_menu:
		_open_levels.call_deferred()
	Progress.open_levels_on_menu = false


func _process(_delta: float) -> void:
	if _clock:
		var t := Time.get_datetime_dict_from_system()
		_clock.text = "%02d:%02d\n%02d/%02d/%d" % [t.hour, t.minute, t.day, t.month, t.year]


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if _modal:
			if _close_modal.is_valid():
				_close_modal.call()
			return
		if _start_menu and _start_menu.visible:
			_start_menu.visible = false
		elif _layer.get_child_count() > 0:
			(_layer.get_child(_layer.get_child_count() - 1)).close_window()
		else:
			_show_start_menu()


# --- Desktop ---------------------------------------------------------------

func _build_wallpaper() -> void:
	var grad := Gradient.new()
	grad.set_color(0, Color(0.09, 0.16, 0.3))
	grad.set_color(1, Color(0.03, 0.05, 0.1))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.42)
	tex.fill_to = Vector2(1.1, 1.1)
	var bg := TextureRect.new()
	bg.texture = tex
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.offset_bottom = -TASKBAR_H
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(col)
	var splat := TextureRect.new()
	splat.texture = SPLAT
	splat.modulate = Color(YELLOW, 0.9)
	splat.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	splat.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	splat.custom_minimum_size = Vector2(260, 260)
	col.add_child(splat)
	col.add_child(_label("YELLOW PAINT", 64, YELLOW, HORIZONTAL_ALIGNMENT_CENTER))
	col.add_child(_label("SYNERGEX INTERACTIVE  ·  We put the extra A in AAAA", 20, Color(1, 1, 1, 0.45), HORIZONTAL_ALIGNMENT_CENTER))


func _build_icons() -> void:
	var col := VBoxContainer.new()
	col.position = Vector2(28, 28)
	col.add_theme_constant_override("separation", 18)
	add_child(col)
	col.add_child(_icon("Inlook", "mail", func(): _open_inlook()))
	col.add_child(_icon("Level Select", "play", _open_levels))
	col.add_child(_icon("Company\nSettings", "gear", _open_settings))
	col.add_child(_icon("Recycle Bin", "bin", _open_bin))


func _icon(text: String, kind: String, action: Callable) -> Control:
	# The tile is a flat button (hover highlight, click to open) with the picture and name inside.
	var tile := Button.new()
	tile.flat = true
	tile.focus_mode = Control.FOCUS_NONE
	tile.custom_minimum_size = Vector2(116, 112)
	tile.pressed.connect(func(): Sfx.play("ui_click"); action.call())
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_top = 6
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 4)
	tile.add_child(box)
	var art := Control.new()
	art.custom_minimum_size = Vector2(64, 64)
	art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.draw.connect(func(): _draw_icon(art, kind))
	box.add_child(art)
	var label := _label(text, 16, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("outline_size", 5)
	box.add_child(label)
	if kind == "mail":
		_inbox_badge = _label("", 15, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
		var badge_style := StyleBoxFlat.new()
		badge_style.bg_color = Color(0.85, 0.15, 0.12)
		badge_style.set_corner_radius_all(11)
		badge_style.content_margin_left = 7
		badge_style.content_margin_right = 7
		_inbox_badge.add_theme_stylebox_override("normal", badge_style)
		_inbox_badge.position = Vector2(52, -8)
		_inbox_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		art.add_child(_inbox_badge)
		_update_badge()
	return tile


func _draw_icon(c: Control, kind: String) -> void:
	var r := Rect2(Vector2.ZERO, c.size)
	match kind:
		"mail":
			c.draw_rect(Rect2(2, 12, 60, 42), Color(0.2, 0.5, 0.9))
			c.draw_rect(Rect2(2, 12, 60, 42), Color.WHITE, false, 2.0)
			c.draw_polyline(PackedVector2Array([Vector2(3, 13), Vector2(32, 36), Vector2(61, 13)]), Color.WHITE, 3.0)
		"play":
			c.draw_rect(Rect2(4, 4, 56, 56), YELLOW)
			c.draw_colored_polygon(PackedVector2Array([Vector2(24, 18), Vector2(46, 32), Vector2(24, 46)]), INK)
		"gear":
			var center := r.get_center()
			for i in 8:
				var a := TAU * i / 8.0
				var d := Vector2(cos(a), sin(a))
				c.draw_line(center + d * 18, center + d * 29, Color(0.75, 0.77, 0.8), 9.0)
			c.draw_circle(center, 21, Color(0.75, 0.77, 0.8))
			c.draw_circle(center, 9, Color(0.09, 0.16, 0.3))
		"bin":
			c.draw_colored_polygon(PackedVector2Array([Vector2(14, 16), Vector2(50, 16), Vector2(45, 60), Vector2(19, 60)]), Color(0.8, 0.85, 0.9, 0.85))
			c.draw_rect(Rect2(10, 10, 44, 6), Color(0.9, 0.92, 0.95))
			for x in [24, 32, 40]:
				c.draw_line(Vector2(x, 22), Vector2(x, 54), Color(0.5, 0.55, 0.62), 2.0)
			# A crumpled grey box (the old art direction) sticking out.
			c.draw_rect(Rect2(26, 2, 14, 10), Color(0.55, 0.56, 0.6))


## "You've got mail" popup above the taskbar (bottom right). Click it to open Inlook.
func _toast() -> void:
	var n := INBOX.unread_count()
	if n == 0:
		return
	Sfx.play("mail", 0.0)
	var toast := Button.new()
	toast.text = "  Inlook\n  %d new email%s" % [n, "" if n == 1 else "s"]
	toast.alignment = HORIZONTAL_ALIGNMENT_LEFT
	toast.add_theme_font_size_override("font_size", 18)
	toast.add_theme_color_override("font_color", Color.WHITE)
	toast.add_theme_color_override("font_hover_color", YELLOW)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.11, 0.12, 0.16, 0.97)
	style.border_width_left = 5
	style.border_color = Color(0.85, 0.15, 0.12)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(14)
	style.shadow_color = Color(0, 0, 0, 0.5)
	style.shadow_size = 12
	for state in ["normal", "hover", "pressed", "focus"]:
		toast.add_theme_stylebox_override(state, style)
	toast.custom_minimum_size = Vector2(300, 0)
	toast.focus_mode = Control.FOCUS_NONE
	add_child(toast)
	await get_tree().process_frame
	var screen := get_viewport_rect().size
	toast.position = Vector2(screen.x + 10, screen.y - TASKBAR_H - toast.size.y - 16)
	toast.pressed.connect(func():
		toast.queue_free()
		_open_inlook())
	var t := toast.create_tween()
	t.tween_property(toast, "position:x", screen.x - toast.size.x - 16, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_interval(6.0)
	t.tween_property(toast, "modulate:a", 0.0, 0.6)
	t.tween_callback(toast.queue_free)
	if _inbox_badge:  # Little bounce on the desktop badge too.
		_inbox_badge.pivot_offset = _inbox_badge.size / 2.0
		var b := _inbox_badge.create_tween()
		b.tween_property(_inbox_badge, "scale", Vector2(1.5, 1.5), 0.15)
		b.tween_property(_inbox_badge, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _update_badge() -> void:
	if not _inbox_badge:
		return
	var n := INBOX.unread_count()
	_inbox_badge.text = str(n)
	_inbox_badge.visible = n > 0


# --- Taskbar & start menu --------------------------------------------------

func _build_taskbar() -> void:
	var bar := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.08, 0.11, 0.96)
	style.border_width_top = 1
	style.border_color = Color(1, 1, 1, 0.12)
	style.content_margin_left = 8
	style.content_margin_right = 14
	bar.add_theme_stylebox_override("panel", style)
	bar.anchor_left = 0
	bar.anchor_right = 1
	bar.anchor_top = 1
	bar.anchor_bottom = 1
	bar.offset_top = -TASKBAR_H
	add_child(bar)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	bar.add_child(row)

	var start := Button.new()
	start.text = "  Start"
	start.icon = _splat_icon()
	start.expand_icon = false
	start.custom_minimum_size = Vector2(120, 44)
	start.add_theme_font_size_override("font_size", 18)
	start.focus_mode = Control.FOCUS_NONE
	start.pressed.connect(func(): Sfx.play("ui_click"); _toggle_start_menu())
	row.add_child(start)

	_taskbar_buttons = HBoxContainer.new()
	_taskbar_buttons.add_theme_constant_override("separation", 6)
	_taskbar_buttons.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_taskbar_buttons)

	row.add_child(_label("VPN: connected (probably)    Wi-Fi: Synergex_Guest", 15, Color(1, 1, 1, 0.55)))
	_clock = _label("", 15, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT)
	_clock.custom_minimum_size = Vector2(110, 0)
	row.add_child(_clock)


func _splat_icon() -> Texture2D:
	var img := SPLAT.get_image()
	img.resize(28, 28)
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			img.set_pixel(x, y, Color(YELLOW, c.a))
	return ImageTexture.create_from_image(img)


func _refresh_taskbar() -> void:
	for b in _taskbar_buttons.get_children():
		b.queue_free()
	for id in _windows:
		var w: Control = _windows[id]
		var b := Button.new()
		b.text = w.title
		b.custom_minimum_size = Vector2(190, 44)
		b.clip_text = true
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 16)
		b.pressed.connect(func(): _raise(w))
		_taskbar_buttons.add_child(b)


func _toggle_start_menu() -> void:
	if _start_menu and _start_menu.visible:
		_start_menu.visible = false
	else:
		_show_start_menu()


func _show_start_menu() -> void:
	if not _start_menu:
		_start_menu = PanelContainer.new()
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.11, 0.12, 0.16, 0.98)
		style.set_corner_radius_all(8)
		style.set_content_margin_all(14)
		style.shadow_color = Color(0, 0, 0, 0.5)
		style.shadow_size = 16
		_start_menu.add_theme_stylebox_override("panel", style)
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 6)
		_start_menu.add_child(col)
		col.add_child(_label("Contractor #%d" % Progress.contractor_id(), 20, Color.WHITE))
		col.add_child(_label("Level Readability Department", 14, Color(1, 1, 1, 0.5)))
		if Progress.shipped():
			col.add_child(_label("HYPERION LEGENDS v1.1  ·  shipped: %s" % ENDINGS.info(Progress.ending).title,
				14, YELLOW))
		col.add_child(HSeparator.new())
		for item in [["Inlook", func(): _open_inlook()], ["Level Select", _open_levels],
				["Company Settings", _open_settings], ["Recycle Bin", _open_bin]]:
			col.add_child(_menu_button(item[0], item[1]))
		col.add_child(HSeparator.new())
		col.add_child(_menu_button("Shut down...", _ask_shutdown))
		add_child(_start_menu)
	_start_menu.visible = true
	_start_menu.move_to_front()
	_start_menu.reset_size()
	_start_menu.position = Vector2(8, get_viewport_rect().size.y - TASKBAR_H - _start_menu.size.y - 6)


func _menu_button(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.flat = true
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(300, 40)
	b.add_theme_font_size_override("font_size", 18)
	b.pressed.connect(func():
		Sfx.play("ui_click")
		_start_menu.visible = false
		action.call())
	return b


# --- Windows ---------------------------------------------------------------

## Opens (or brings to front) a window. Returns it.
func _window(id: String, title: String, body: Control, at: Vector2) -> Control:
	if _windows.has(id):
		_raise(_windows[id])
		body.free()
		return _windows[id]
	var w = DESK_WINDOW.new()
	w.title = title
	w.body = body
	w.position = at
	_layer.add_child(w)
	_windows[id] = w
	w.focused.connect(func(): _raise(w))
	w.closed.connect(func():
		_windows.erase(id)
		_refresh_taskbar.call_deferred())
	_refresh_taskbar()
	return w


func _raise(w: Control) -> void:
	w.move_to_front()


func _open_levels() -> void:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	var pad := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 18)
	pad.add_child(col)
	col.add_child(_label("Patch 1.1: replay any session" if Progress.shipped() else "Scheduled playtest sessions", 24, INK))
	col.add_child(_label("Each session: 3 focus testers, one after the other. Your paint stays between testers.", 15, MUTED))
	var hidden := 0
	for i in Progress.LEVELS.size():
		if Progress.is_unlocked(i):
			col.add_child(_level_row(i))
		elif not Progress.LEVELS[i].post_launch:
			hidden += 1  # Locked levels are invisible: they arrive by email.
	if hidden > 0:
		col.add_child(_label("More playtests will be scheduled based on your results (%d/15 or better)." % Progress.UNLOCK_STARS, 15, MUTED))
	var w := _window("levels", "Level Select - PlaytestScheduler Pro", pad, Vector2(560, 120))
	_focus_first_play(w)


func _focus_first_play(w: Control) -> void:
	var first := w.find_child("Play*", true, false) as Button
	if first:
		first.grab_focus.call_deferred()


func _level_row(i: int) -> Control:
	var info: Dictionary = Progress.LEVELS[i]
	var best := Progress.best(info.path)
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1)
	style.border_color = Color(0.82, 0.82, 0.8)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	panel.add_child(row)
	var num := _label("%02d" % (i + 1), 30, CORP_BLUE)
	num.custom_minimum_size = Vector2(52, 0)
	row.add_child(num)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.custom_minimum_size = Vector2(430, 0)
	row.add_child(text)
	text.add_child(_label(info.name + ("   [$4.99 DLC]" if info.post_launch else ""), 22, INK))
	var best_time := Progress.best_total_time(info.path)
	text.add_child(_label("Testers: " + ", ".join(Progress.level_testers(info.path))
		+ (("   ·   best time " + Progress.format_time(best_time)) if best_time >= 0.0 else ""), 14, MUTED))
	var score := _label(("%d / 15★" % best) if best > 0 else "not tested", 20, Color(0.75, 0.55, 0.0) if best > 0 else MUTED)
	score.custom_minimum_size = Vector2(110, 0)
	score.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(score)
	var play := Button.new()
	play.name = "Play%d" % i
	play.text = "Start session"
	play.custom_minimum_size = Vector2(150, 44)
	play.add_theme_font_size_override("font_size", 17)
	play.pressed.connect(func(): Sfx.play("ui_click"); Progress.play(i))
	row.add_child(play)
	return panel


func _open_inlook(select := "") -> void:
	if _windows.has("inlook"):
		_raise(_windows.inlook)
		return
	var _mails := INBOX.all_mails()
	var root := HBoxContainer.new()
	root.add_theme_constant_override("separation", 0)
	root.custom_minimum_size = Vector2(1240, 720)

	# Left: folder + list of emails.
	var left := PanelContainer.new()
	var left_style := StyleBoxFlat.new()
	left_style.bg_color = Color(0.89, 0.9, 0.92)
	left_style.set_content_margin_all(10)
	left.add_theme_stylebox_override("panel", left_style)
	left.custom_minimum_size = Vector2(400, 0)
	root.add_child(left)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 6)
	left.add_child(list)
	var search := LineEdit.new()
	search.placeholder_text = "Search (disabled by IT)"
	search.editable = false
	list.add_child(search)
	var folder := _label("", 18, INK)
	list.add_child(folder)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list.add_child(scroll)
	var rows_box := VBoxContainer.new()
	rows_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows_box.add_theme_constant_override("separation", 6)
	scroll.add_child(rows_box)

	# Right: reading pane.
	var right := PanelContainer.new()
	var right_style := StyleBoxFlat.new()
	right_style.bg_color = Color(0.97, 0.97, 0.96)
	right_style.set_content_margin_all(22)
	right.add_theme_stylebox_override("panel", right_style)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(right)
	var pane := VBoxContainer.new()
	pane.add_theme_constant_override("separation", 6)
	right.add_child(pane)

	var rows := []
	var show_mail := func(index: int) -> void:
		var mail: Dictionary = _mails[index]
		Progress.mark_mail_read(mail.id)
		for child in pane.get_children():
			child.queue_free()
		pane.add_child(_label(mail.subject, 24, INK))
		pane.add_child(_label("From:  %s <%s>" % [mail.from, mail.address], 15, MUTED))
		pane.add_child(_label("To:  You <contractor-%d@synergex-interactive.biz>" % Progress.contractor_id(), 15, MUTED))
		if mail.cc != "":
			pane.add_child(_label("Cc:  " + mail.cc, 15, MUTED))
		pane.add_child(_label("Date:  " + mail.date, 15, MUTED))
		pane.add_child(HSeparator.new())
		var body := RichTextLabel.new()
		body.bbcode_enabled = true
		body.text = mail.body
		body.size_flags_vertical = Control.SIZE_EXPAND_FILL
		body.add_theme_color_override("default_color", INK)
		for font in ["normal_font_size", "bold_font_size", "italics_font_size", "bold_italics_font_size"]:
			body.add_theme_font_size_override(font, 18)
		pane.add_child(body)
		if mail.id == "welcome":
			pane.add_child(_welcome_buttons())
		elif mail.id == "hr_exit":
			pane.add_child(_hr_buttons())
		elif mail.id == "greenlight":
			pane.add_child(_greenlight_buttons())
		elif mail.id == "patch_notes" and Progress.ship_state == "credits":
			pane.add_child(_launch_buttons())
		for r in rows.size():
			_style_mail_row(rows[r], _mails[r], r == index)
		folder.text = "Inbox (%d unread)" % INBOX.unread_count()
		_update_badge()

	for i in _mails.size():
		var row := Button.new()
		row.custom_minimum_size = Vector2(0, 74)
		row.focus_mode = Control.FOCUS_NONE
		row.pressed.connect(func(): Sfx.play("ui_click"); show_mail.call(i))
		rows_box.add_child(row)
		rows.append(row)
		_style_mail_row(row, _mails[i], false)
	folder.text = "Inbox (%d unread)" % INBOX.unread_count()

	var win := _window("inlook", "Inlook - Inbox - contractor-%d@synergex-interactive.biz" % Progress.contractor_id(), root, Vector2(300, 70))
	win.closed.connect(_on_inlook_closed)
	var start := -1
	for i in _mails.size():
		if _mails[i].id == select:
			start = i
	if start == -1:  # Otherwise the newest unread one.
		for i in _mails.size():
			if not INBOX.is_read(_mails[i].id):
				start = i
				break
	start = maxi(start, 0)
	if select != "" or INBOX.unread_count() > 0:
		show_mail.call(start)
	else:
		pane.add_child(_label("Select an email to read it.", 18, MUTED))


func _style_mail_row(row: Button, mail: Dictionary, selected: bool) -> void:
	for c in row.get_children():
		c.queue_free()
	var unread := not INBOX.is_read(mail.id)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.78, 0.86, 0.97) if selected else Color(1, 1, 1)
	style.border_width_left = 5 if unread else 0
	style.border_color = CORP_BLUE
	style.set_corner_radius_all(3)
	for state in ["normal", "hover", "pressed"]:
		var s := style.duplicate()
		if state == "hover" and not selected:
			s.bg_color = Color(0.92, 0.95, 1)
		row.add_theme_stylebox_override(state, s)
	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 14
	col.offset_top = 6
	col.offset_right = -8
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 0)
	row.add_child(col)
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(top)
	var from := _label(mail.from + ("   [!]" if mail.flag else ""), 17, INK if unread else MUTED)
	from.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(from)
	top.add_child(_label(mail.date, 13, MUTED))
	var subject := _label(mail.subject, 15, CORP_BLUE if unread else MUTED)
	subject.autowrap_mode = TextServer.AUTOWRAP_OFF
	subject.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	subject.custom_minimum_size = Vector2(340, 0)
	col.add_child(subject)
	for l in [from, subject]:
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _welcome_buttons() -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 12)
	var decline := Button.new()
	decline.text = "Decline"
	decline.disabled = true
	decline.tooltip_text = "This option has been disabled by HR."
	decline.custom_minimum_size = Vector2(150, 44)
	decline.add_theme_font_size_override("font_size", 18)
	row.add_child(decline)
	var accept := Button.new()
	accept.text = "Accept & grab the paint"
	accept.custom_minimum_size = Vector2(280, 44)
	accept.add_theme_font_size_override("font_size", 18)
	accept.add_theme_color_override("font_color", INK)
	accept.add_theme_color_override("font_hover_color", INK)
	for state in ["normal", "hover", "pressed", "focus"]:
		var s := StyleBoxFlat.new()
		s.bg_color = YELLOW.lightened(0.15) if state == "hover" else YELLOW
		s.set_corner_radius_all(4)
		accept.add_theme_stylebox_override(state, s)
	accept.pressed.connect(func():
		Sfx.play("ui_click")
		if _windows.has("inlook"):
			_windows.inlook.close_window()
		_open_levels())
	row.add_child(accept)
	return row


func _hr_buttons() -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	var book := Button.new()
	book.text = "Schedule meeting"
	book.custom_minimum_size = Vector2(240, 44)
	book.add_theme_font_size_override("font_size", 18)
	book.pressed.connect(func(): Sfx.play("ui_click"); _ask_resignation())
	row.add_child(book)
	return row


func _yellow_button(text: String, width: float) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(width, 44)
	b.add_theme_font_size_override("font_size", 18)
	b.add_theme_color_override("font_color", INK)
	b.add_theme_color_override("font_hover_color", INK)
	b.add_theme_color_override("font_focus_color", INK)
	for state in ["normal", "hover", "pressed", "focus"]:
		var st := StyleBoxFlat.new()
		st.bg_color = YELLOW.lightened(0.15) if state == "hover" else YELLOW
		st.set_corner_radius_all(4)
		b.add_theme_stylebox_override(state, st)
	return b


func _greenlight_buttons() -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	if Progress.ship_state != "":
		var done := Button.new()
		done.text = "Greenlit ✓"
		done.disabled = true
		done.custom_minimum_size = Vector2(200, 44)
		done.add_theme_font_size_override("font_size", 18)
		row.add_child(done)
		return row
	var go := _yellow_button("Give the greenlight...", 280)
	go.pressed.connect(func(): Sfx.play("ui_click"); _ask_greenlight())
	row.add_child(go)
	return row


func _launch_buttons() -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	var go := _yellow_button("Publish patch notes & launch", 320)
	go.pressed.connect(func():
		Sfx.play("ui_click")
		if _windows.has("inlook"):
			_windows.inlook.close_window())  # Closing Inlook rolls the credits.
	row.add_child(go)
	return row


## Patch notes read and Inlook closed after the greenlight: launch day (the credits).
func _on_inlook_closed() -> void:
	if Progress.ship_state == "credits" and INBOX.is_read("patch_notes"):
		_roll_credits()


func _roll_credits() -> void:
	var black := ColorRect.new()
	black.color = Color.BLACK
	black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	black.mouse_filter = Control.MOUSE_FILTER_STOP
	black.modulate.a = 0.0
	add_child(black)
	var t := create_tween()
	t.tween_property(black, "modulate:a", 1.0, 1.6)
	t.tween_interval(0.6)
	t.tween_callback(func(): get_tree().change_scene_to_file(CREDITS_SCENE))


func _fade_in() -> void:
	var black := ColorRect.new()
	black.color = Color.BLACK
	black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(black)
	var t := create_tween()
	t.tween_interval(0.4)
	t.tween_property(black, "modulate:a", 0.0, 1.4)
	t.tween_callback(black.queue_free)


## A centred modal window over a dimmed desktop. Returns [overlay, window, close_callable].
func _dialog(title: String, body: Control) -> Array:
	var overlay := Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)
	add_child(overlay)
	_modal = overlay
	var w = DESK_WINDOW.new()
	w.title = title
	w.body = body
	overlay.add_child(w)
	var close := func():
		_modal = null
		_close_modal = Callable()
		if is_instance_valid(overlay):
			overlay.queue_free()
	_close_modal = close
	w.closed.connect(close)
	(func(): w.position = (get_viewport_rect().size - w.size) / 2.0).call_deferred()
	return [overlay, w, close]


## The ship button: shows what goes on the launch slide, then ships for good.
func _ask_greenlight() -> void:
	if _modal or Progress.ship_state != "":
		return
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	var pad := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 26)
	pad.add_child(col)
	var lines: PackedStringArray = []
	for i in Progress.ending_levels():
		lines.append("%s: [b]%d/15[/b]" % [Progress.LEVELS[i].name, Progress.best(Progress.LEVELS[i].path)])
	var text := RichTextLabel.new()
	text.bbcode_enabled = true
	text.fit_content = true
	text.custom_minimum_size = Vector2(640, 0)
	text.add_theme_color_override("default_color", INK)
	for f in ["normal_font_size", "bold_font_size", "italics_font_size"]:
		text.add_theme_font_size_override(f, 19)
	text.text = ("[b]RELEASE APPROVAL[/b]\n\nI, Contractor #%d, give the final greenlight to ship [b]HYPERION LEGENDS: ETERNAL DAWN[/b].\n\nThe launch slide will show:\n[ul]%s[/ul]\n\nI understand that the launch slide is forever, and that the game cannot be un-shipped.\n[font_size=13][color=#6b6e7a]Tutorial sessions are not on the slide. Neither is the art.[/color][/font_size]") % [
		Progress.contractor_id(), "\n".join(lines)]
	col.add_child(text)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	buttons.add_theme_constant_override("separation", 12)
	col.add_child(buttons)
	var wait := Button.new()
	wait.text = "Not yet"
	wait.custom_minimum_size = Vector2(160, 44)
	wait.add_theme_font_size_override("font_size", 17)
	buttons.add_child(wait)
	var ship := _yellow_button("Greenlight & ship it", 260)
	buttons.add_child(ship)
	var d := _dialog("Release approval - DocuSigh", pad)
	var close: Callable = d[2]
	wait.pressed.connect(func(): Sfx.play("ui_click"); close.call())
	ship.pressed.connect(func():
		Sfx.play("ui_click")
		close.call()
		Progress.greenlight()
		if _windows.has("inlook"):
			_windows.inlook.close_window()
		_open_inlook("ending")
		Sfx.play("mail", 0.0))
	wait.grab_focus.call_deferred()


## The exit interview: sign, confirm, the screen switches off, and a new contractor starts from scratch.
func _ask_resignation() -> void:
	if _modal:
		return
	var overlay := Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)
	add_child(overlay)
	_modal = overlay

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	var pad := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 26)
	pad.add_child(col)
	var letter := RichTextLabel.new()
	letter.bbcode_enabled = true
	letter.fit_content = true
	letter.custom_minimum_size = Vector2(640, 0)
	letter.add_theme_color_override("default_color", INK)
	for f in ["normal_font_size", "bold_font_size", "italics_font_size"]:
		letter.add_theme_font_size_override(f, 19)
	letter.text = ("[b]RESIGNATION LETTER[/b]\n\nI, Contractor #%d, hereby resign from the Level Readability Department of Synergex Interactive.\n\nI understand that:\n[ul]all my stars, session times and emails will be deleted\nmy desk will be given to a new contractor within the hour\nmy parking spot will be reassigned\nmy coffee subscription will continue[/ul]\n[font_size=13][color=#6b6e7a]By signing, you also agree to the Non-Disparagement Clause, the Non-Compete Clause, and the Non-Feelings Clause.[/color][/font_size]") % Progress.contractor_id()
	col.add_child(letter)

	var sig_row := HBoxContainer.new()
	sig_row.add_theme_constant_override("separation", 14)
	col.add_child(sig_row)
	var sig := _label("Signature:  ______________________", 20, INK)
	sig.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sig_row.add_child(sig)
	var sign_btn := Button.new()
	sign_btn.text = "Sign"
	sign_btn.custom_minimum_size = Vector2(120, 40)
	sign_btn.add_theme_font_size_override("font_size", 17)
	sig_row.add_child(sign_btn)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	buttons.add_theme_constant_override("separation", 12)
	col.add_child(buttons)
	var cancel := Button.new()
	cancel.text = "I changed my mind"
	cancel.custom_minimum_size = Vector2(200, 44)
	cancel.add_theme_font_size_override("font_size", 17)
	buttons.add_child(cancel)
	var confirm := Button.new()
	confirm.text = "Confirm resignation"
	confirm.disabled = true
	confirm.tooltip_text = "Sign the letter first."
	confirm.custom_minimum_size = Vector2(230, 44)
	confirm.add_theme_font_size_override("font_size", 17)
	confirm.add_theme_color_override("font_color", Color(0.75, 0.1, 0.08))
	buttons.add_child(confirm)

	var w = DESK_WINDOW.new()
	w.title = "Exit interview - DocuSigh"
	w.body = pad
	overlay.add_child(w)
	var close_dialog := func():
		_modal = null
		_close_modal = Callable()
		if is_instance_valid(overlay):
			overlay.queue_free()
	_close_modal = close_dialog
	cancel.pressed.connect(func(): Sfx.play("ui_click"); close_dialog.call())
	w.closed.connect(close_dialog)
	sign_btn.pressed.connect(func():
		Sfx.play("ui_click")
		sig.text = "Signature:  ~ Contractor #%d ~" % Progress.contractor_id()
		sig.add_theme_color_override("font_color", Color(0.1, 0.2, 0.6))
		sign_btn.disabled = true
		confirm.disabled = false
		confirm.tooltip_text = "")
	confirm.pressed.connect(func():
		_close_modal = Callable()  # No backing out now.
		_power_off())
	cancel.grab_focus.call_deferred()
	(func(): w.position = (get_viewport_rect().size - w.size) / 2.0).call_deferred()


## Old-monitor switch-off: the picture squashes into a line, then a dot, then black. Then a fresh save.
func _power_off() -> void:
	Sfx.play("power_off", 0.0)
	var screen := get_viewport_rect().size
	var black := ColorRect.new()
	black.color = Color.BLACK
	black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	black.mouse_filter = Control.MOUSE_FILTER_STOP
	black.modulate.a = 0.0
	add_child(black)
	var glow := ColorRect.new()
	glow.color = Color(0.92, 0.95, 1.0)
	glow.size = screen
	glow.position = Vector2.ZERO
	glow.modulate.a = 0.0
	add_child(glow)
	var t := create_tween()
	t.tween_property(glow, "modulate:a", 0.85, 0.06)
	t.tween_callback(func(): black.modulate.a = 1.0)
	t.tween_property(glow, "size:y", 4.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(glow, "position:y", screen.y / 2.0 - 2.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(glow, "size:x", 6.0, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(glow, "position:x", screen.x / 2.0 - 3.0, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(glow, "modulate:a", 0.0, 0.25)
	t.tween_interval(1.2)
	t.tween_callback(func():
		Progress.resign()
		get_tree().reload_current_scene())


func _open_bin() -> void:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	var pad := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 18)
	pad.add_child(col)
	for f in ["art_direction_v1.psd", "art_direction_v2_colourful.psd", "art_direction_v3_less_colourful.psd",
			"workstation_upgrade_request_v7_DENIED.docx", "yellow_paint_ban_petition.docx", "work_life_balance.pdf",
			"unpaid_overtime_policy_DRAFT.docx", "AAA_logo_old.png", "fun.exe"]:
		col.add_child(_label(f, 17, INK))
	col.add_child(HSeparator.new())
	var empty := Button.new()
	empty.text = "Empty Recycle Bin"
	empty.disabled = true
	empty.tooltip_text = "Requires manager approval."
	col.add_child(empty)
	_window("bin", "Recycle Bin", pad, Vector2(240, 160))


func _open_settings() -> void:
	if _modal:
		return
	var menu = SETTINGS_MENU.new()
	menu.title = "COMPANY SETTINGS"
	_modal = menu
	add_child(menu)
	_close_modal = Callable()  # The settings menu handles Esc itself.
	menu.closed.connect(func(): _modal = null)


func _ask_shutdown() -> void:
	if _modal:
		return
	var overlay := Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.5)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)
	add_child(overlay)
	_modal = overlay

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 18)
	var pad := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 24)
	pad.add_child(col)
	var text := RichTextLabel.new()
	text.bbcode_enabled = true
	text.fit_content = true
	text.custom_minimum_size = Vector2(560, 0)
	text.add_theme_color_override("default_color", INK)
	text.add_theme_font_size_override("normal_font_size", 22)
	text.add_theme_font_size_override("bold_font_size", 22)
	text.text = "[b]Are you sure you want to shut down?[/b]\n\nLeaving during working hours may result in your [font_size=12][s]contract[/s][/font_size] termination."
	col.add_child(text)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	buttons.add_theme_constant_override("separation", 12)
	col.add_child(buttons)
	var leave := Button.new()
	leave.text = "Shut down anyway"
	leave.custom_minimum_size = Vector2(200, 44)
	leave.add_theme_font_size_override("font_size", 18)
	leave.pressed.connect(func(): get_tree().quit())
	buttons.add_child(leave)
	var stay := Button.new()
	stay.text = "Keep working"
	stay.custom_minimum_size = Vector2(180, 44)
	stay.add_theme_font_size_override("font_size", 18)
	buttons.add_child(stay)

	var w = DESK_WINDOW.new()
	w.title = "Shut down"
	w.body = pad
	overlay.add_child(w)
	var close_dialog := func():
		_modal = null
		_close_modal = Callable()
		if is_instance_valid(overlay):
			overlay.queue_free()
	_close_modal = close_dialog
	stay.pressed.connect(func(): Sfx.play("ui_click"); close_dialog.call())
	w.closed.connect(close_dialog)
	stay.grab_focus.call_deferred()
	# Centre it once it knows its size.
	(func(): w.position = (get_viewport_rect().size - w.size) / 2.0).call_deferred()


func _label(text: String, size: int, color: Color, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l
