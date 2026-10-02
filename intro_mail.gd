extends Control
## The intro: a corporate email from the boss explaining the job (and why everything is grey boxes).
## Shown by the main menu on first launch (Progress.seen_intro), and from its "Inbox" button after that.
## Built in code; emits `closed` and frees itself.

signal closed

const YELLOW := Color(1, 0.82, 0.05)
const PAPER := Color(0.96, 0.96, 0.94)
const INK := Color(0.12, 0.12, 0.15)
const MUTED := Color(0.42, 0.43, 0.48)
const CORP_BLUE := Color(0.16, 0.33, 0.62)

const FROM := "Chad Bossworth <c.bossworth@synergex-interactive.biz>"
const TO := "You <contractor-4471@synergex-interactive.biz>"
const CC := "Investor Relations; Legal; Marketing; Marketing (2); Brand Synergy Taskforce"
const SUBJECT := "RE: RE: FW: Welcome aboard!!! (AAAA project) [CONFIDENTIAL] [URGENT] [READ ME]"
const DATE := "Monday, 8:02 AM"

const BODY := """Hi [FIRST_NAME],

Welcome to the [b]Level Readability Department[/b] at Synergex Interactive! As discussed in your four-minute interview, you will be supporting playtesting on our upcoming flagship title:

[center][b][font_size=26]HYPERION LEGENDS: ETERNAL DAWN[/font_size][/b]
[i]The world's first AAAA game.*[/i][/center]

[b]Your job is simple.[/b] Our focus testers come from the biggest names in games journalism, and they get lost. A lot. Industry research (one slide, very convincing) shows players can only find a ledge if it is [color=#d9a400][b]painted yellow[/b][/color]. So you'll be painting it.

[b]A few things before you start:[/b]

[ul]You may notice the game is currently made of grey boxes. This is an [b]early build[/b]. The art direction is being finalized and will be breathtaking. Please do not mention the boxes to the testers.
Use as little paint as possible. The art team says yellow paint "ruins the immersion". (They have not seen the boxes either.)
Every star the testers give us goes straight into a slide for the investors. The investors like five stars. The investors have asked us not to show them fewer than five stars.
Each tester is different. Read their profile. Some of them will need a lot of help. Some of them will jump off anything. All of them write reviews.
If something goes wrong during a session, you [i]can[/i] push a hotfix. Please don't. The testers notice, and so does Legal.
Paint is expensive. Use it like it comes out of your salary. (It does.)[/ul]

We are all extremely excited. Let's make this the most intuitive game ever made, together!

Best regards and synergy,

[b]Chad Bossworth[/b]
VP of Player Engagement & Synergy
Synergex Interactive | [i]"We put the extra A in AAAA."[/i]

[font_size=15][color=#6b6e7a]*Fourth A pending legal review. This email and any attachments are confidential and may contain enthusiasm. If you received it by mistake, you now work here.[/color][/font_size]"""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.05, 0.07, 0.92)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var window := PanelContainer.new()
	window.custom_minimum_size = Vector2(980, 0)
	window.add_theme_stylebox_override("panel", _box(PAPER, 6))
	center.add_child(window)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	window.add_child(col)

	# Title bar of the (very corporate) mail client.
	var bar := PanelContainer.new()
	bar.add_theme_stylebox_override("panel", _box(CORP_BLUE, 0, 10))
	col.add_child(bar)
	bar.add_child(_label("SynergyMail Enterprise 365+   ·   Inbox (1 unread, 4,812 flagged)", 18, Color.WHITE))

	var head := VBoxContainer.new()
	head.add_theme_constant_override("separation", 4)
	var head_box := PanelContainer.new()
	head_box.add_theme_stylebox_override("panel", _box(PAPER, 0, 18))
	head_box.add_child(head)
	col.add_child(head_box)
	head.add_child(_label(SUBJECT, 24, INK))
	for row in [["From", FROM], ["To", TO], ["Cc", CC], ["Date", DATE]]:
		head.add_child(_label("%s:  %s" % row, 16, MUTED))

	var line := ColorRect.new()
	line.color = Color(0.82, 0.82, 0.8)
	line.custom_minimum_size = Vector2(0, 2)
	col.add_child(line)

	var body := RichTextLabel.new()
	body.bbcode_enabled = true
	body.text = BODY
	body.custom_minimum_size = Vector2(940, 470)
	body.scroll_active = true
	body.add_theme_color_override("default_color", INK)
	body.add_theme_font_size_override("normal_font_size", 19)
	body.add_theme_font_size_override("bold_font_size", 19)
	body.add_theme_font_size_override("italics_font_size", 19)
	var body_box := PanelContainer.new()
	body_box.add_theme_stylebox_override("panel", _box(PAPER, 0, 20))
	body_box.add_child(body)
	col.add_child(body_box)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	buttons.add_theme_constant_override("separation", 14)
	var buttons_box := PanelContainer.new()
	buttons_box.add_theme_stylebox_override("panel", _box(Color(0.9, 0.9, 0.88), 0, 14))
	buttons_box.add_child(buttons)
	col.add_child(buttons_box)

	var decline := Button.new()
	decline.text = "Decline"
	decline.disabled = true
	decline.tooltip_text = "This option has been disabled by HR."
	decline.custom_minimum_size = Vector2(160, 46)
	decline.add_theme_font_size_override("font_size", 20)
	buttons.add_child(decline)

	var accept := Button.new()
	accept.text = "Accept & grab the paint"
	accept.custom_minimum_size = Vector2(300, 46)
	accept.add_theme_font_size_override("font_size", 20)
	accept.add_theme_color_override("font_color", INK)
	accept.add_theme_stylebox_override("normal", _box(YELLOW, 4))
	accept.add_theme_stylebox_override("hover", _box(YELLOW.lightened(0.2), 4))
	accept.add_theme_stylebox_override("pressed", _box(YELLOW.darkened(0.15), 4))
	accept.add_theme_stylebox_override("focus", _box(YELLOW.lightened(0.2), 4))
	accept.pressed.connect(_close)
	buttons.add_child(accept)
	accept.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close()


func _close() -> void:
	Sfx.play("ui_click")
	closed.emit()
	queue_free()


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func _box(color: Color, radius := 0, margin := 0) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = color
	b.set_corner_radius_all(radius)
	b.set_content_margin_all(margin)
	return b
