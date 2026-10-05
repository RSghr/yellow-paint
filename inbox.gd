extends RefCounted
## The emails in Inlook (the desktop's mail app). Newest first. Bodies are BBCode (RichTextLabel).
## Add a starting mail: append a dictionary to MAILS with a unique `id`. Read state is saved in Progress.read_mails.
## Mails that arrive during play (new levels, flavor) are written by mail_writer.gd and stored in Progress.
## The "welcome" mail is the story intro (unread at first launch). "hr_exit" offers the save reset (level_select.gd).

const MAILS := [
	{
		id = "welcome",
		from = "Chad Bossworth",
		address = "c.bossworth@synergex-interactive.biz",
		cc = "Investor Relations; Legal; Marketing; Marketing (2); Brand Synergy Taskforce",
		subject = "RE: RE: FW: Welcome aboard!!! (AAAA project) [CONFIDENTIAL] [URGENT] [READ ME]",
		date = "Mon 8:02 AM",
		flag = true,
		body = """Hi [FIRST_NAME],

Welcome to the [b]Level Readability Department[/b] at Synergex Interactive! As discussed in your four-minute interview, you will be supporting playtesting on our upcoming flagship title:

[center][b][font_size=26]HYPERION LEGENDS: ETERNAL DAWN[/font_size][/b]
[i]The world's first AAAA game.*[/i][/center]

[b]Your job is simple.[/b] Our focus testers come from the biggest names in games journalism, and they get lost. A lot. Industry research (one slide, very convincing) shows players can only find a ledge if it is [color=#d9a400][b]painted yellow[/b][/color]. So you'll be painting it.

[b]A few things before you start:[/b]

[ul]Your workstation is a [b]ThinkBox 2009[/b]. Due to budget constraints, it can only render the game as [b]grey boxes[/b]. The testers play on the real hardware and see HYPERION LEGENDS in all its ray-traced, 12K-textured glory. Please do not tell them what you see. They will feel sorry for you.
Use as little paint as possible. The art team spent four years on those textures and says yellow paint "ruins the immersion". You will have to take their word for it.
Every star the testers give us goes straight into a slide for the investors. They like five stars. They have asked us not to show them fewer than five stars.
Each tester is different. Read their profile. Some of them will need a lot of help. Some of them will jump off anything. All of them write reviews.
If something goes wrong during a session, you [i]can[/i] push a hotfix. Management approved a budget of two per playtest. Please don't use it. The testers notice, and so does Legal.
Paint is expensive. Use it like it comes out of your salary. (It does.)[/ul]

We are all extremely excited. Let's make this the most intuitive game ever made, together!

Best regards and synergy,

[b]Chad Bossworth[/b]
VP of Player Engagement & Synergy
Synergex Interactive | [i]"We put the extra A in AAAA."[/i]

[font_size=15][color=#6b6e7a]*Fourth A pending legal review. This email and any attachments are confidential and may contain enthusiasm. If you received it by mistake, you now work here.[/color][/font_size]""",
	},
	{
		id = "keys",
		from = "IT Helpdesk",
		address = "noreply-helpdesk@synergex-interactive.biz",
		cc = "",
		subject = "Your new workstation: quick start guide (please read, we are begging you)",
		date = "Mon 7:55 AM",
		flag = false,
		body = """Dear user,

Welcome to your ThinkBox 2009. It has been reformatted for you. Most of it.

[b]Controls[/b]
[ul][b]{move}[/b] to walk, [b]{sprint}[/b] to sprint. [b]{paint}[/b] to paint, [b]{scrape}[/b] to scrape paint off (you get it back).
[b]{start_test}[/b] starts the playtest. The tester only starts looking around when you press it.
[b]{toggle_fly}[/b] switches gravity off. Facilities asked us to remind you this only works inside the game.
Hold [b]{jump}[/b] to fly up. [b]{fly_down}[/b] to go down.
[b]{toggle_spectator}[/b] switches to the camera that follows the tester automatically.
[b]{fast_forward}[/b] fast-forwards the playtest. The dev team managed to bend spacetime so the tester behaves exactly the same. Please do not ask them how. They do not know either.
Hold [b]{reset_runner}[/b] to restart the tester.
[b]{toggle_ai_debug}[/b] toggles the debug view: what the tester has noticed, and how far it can jump.
[b]{clear_paint}[/b] deletes all your paint (only before a playtest).
[b]{toggle_tester_card}[/b] shows the tester's profile again. Read it. They are all different.
[b]Caps Lock[/b] toggles [color=#3cb043][b]green paint[/b][/color]. It is disabled, as the feature is part of [i]ThinkBox 2009 Pro+[/i], which was out of our budget.[/ul]

[b]About the yellow paint[/b]
Yellow paint must be [b]subtle[/b], but it has to get the player through the level. On your grey boxes the way looks obvious. It is not. The testers see 12K moss, ray-traced puddles and about forty overlapping textures per ledge, and they have no idea where to go. One well-placed splat beats ten random ones.

[b]Hotfixes[/b]
If a playtest goes wrong, you can paint a [color=#e0402a][b]red hotfix[/b][/color] during the session. The tester will drop everything and go there. Management grants you [b]2 hotfixes per playtest[/b] (all three testers together). After that, every one breaks immersion, and your score with it.

[b]Scores[/b]
Each level is rated [b]out of 15[/b] (three testers, five stars each). A level needs at least [b]10/15[/b] before management schedules the next playtest.

If you have any further questions, please open a ticket. Tickets are reviewed quarterly.

IT Helpdesk | [i]"Have you tried turning it off and on again? (Please don't. It took us three days to set up.)"[/i]""",
	},
	{
		id = "art",
		from = "Art Department",
		address = "art-direction@synergex-interactive.biz",
		cc = "",
		subject = "RE: Please stop painting our moss",
		date = "Mon 7:48 AM",
		flag = false,
		body = """Hi all,

Quick reminder about the levels you're working on.

Every ledge in HYPERION LEGENDS has hand-sculpted moss. Every brick has its own normal map. The puddles are ray-traced. The waterfall in the Tower took one of us eight months and most of a marriage.

We are told your workstation shows all of this as [b]grey boxes[/b]. We have filed a complaint with IT. IT has filed it.

So, from the people who can actually see the game: please [b]do not[/b] paint the moss yellow. Yellow is not part of the brand. Yellow is the opposite of immersion.

Thanks,
The Art Department (both of us)""",
	},
	{
		id = "workstation",
		from = "IT Helpdesk",
		address = "noreply-helpdesk@synergex-interactive.biz",
		cc = "",
		subject = "RE: Workstation upgrade request #88412 (DENIED)",
		date = "Mon 7:30 AM",
		flag = false,
		body = """Dear user,

Your request for a graphics card has been [b]denied[/b].

Your workstation (ThinkBox 2009, 2 GB of RAM, "integrated graphics") renders HYPERION LEGENDS as grey boxes. This is all the Level Readability Department needs to see. Grey boxes have edges. Edges are where the yellow goes.

Approved alternatives:
[ul]squinting
asking a focus tester to describe it
imagining it (imagination requests go through the portal)[/ul]

The workstation fan is loud. This is normal. If it starts smelling like toast, this is also normal.

IT Helpdesk | [i]"Have you tried turning it off and on again? (It takes 40 minutes to boot.)"[/i]""",
	},
	{
		id = "it",
		from = "IT Helpdesk",
		address = "noreply-helpdesk@synergex-interactive.biz",
		cc = "",
		subject = "ACTION REQUIRED: your password expires in -3 days",
		date = "Sun 11:59 PM",
		flag = false,
		body = """Dear user,

Your password expired 3 days ago. To keep using company resources, please choose a new password that:

[ul]is at least 24 characters long
contains an uppercase letter, a number, a symbol and an emoji
is different from your last 400 passwords
includes the CEO's birthday (ask Legal)[/ul]

If you have already changed your password, please change it again.

This is an automated message. Replies are sent directly to a folder nobody reads.

IT Helpdesk | [i]"Have you tried turning it off and on again? (Do not turn it off during working hours.)"[/i]""",
	},
	{
		id = "fun",
		from = "People & Culture",
		address = "happiness@synergex-interactive.biz",
		cc = "",
		subject = "Mandatory Fun Friday (attendance tracked)",
		date = "Fri 4:30 PM",
		flag = false,
		body = """Hi team!

This Friday is [b]Mandatory Fun Friday[/b]! Join us in Meeting Room B (the one without chairs) for:

[ul]Pizza (one slice per four employees, please share)
A team-building exercise: "Crunch Is a Mindset"
A raffle! The prize is a day off (to be taken on a Saturday)[/ul]

Attendance is optional but will be reflected in your yearly review.

Stay synergized!
People & Culture""",
	},
	{
		id = "hr_exit",
		from = "People & Culture",
		address = "happiness@synergex-interactive.biz",
		cc = "",
		subject = "Your mandatory exit interview (optional)",
		date = "Fri 5:59 PM",
		flag = false,
		body = """Hi [FIRST_NAME]!

As part of our commitment to employee wellbeing, every contractor is entitled to one (1) mandatory optional [b]exit interview[/b].

During this meeting you will:
[ul]sign your resignation letter
return your paint can (please rinse it)
forfeit all your stars, session times and emails (and any game you shipped: it will be quietly un-shipped)
be replaced by a new contractor within the hour[/ul]

As a gesture of goodwill, your settings (mouse sensitivity, volume) will be kept for your replacement.

To book the meeting, use the button below. Slots are available 24/7, because we never sleep.

People & Culture
[i]"Your exit is our entrance."[/i]""",
	},
]


## Everything in the inbox, newest first: mails received during play, then the starting ones.
static func all_mails() -> Array:
	var mails: Array = Progress.delivered_mails.duplicate()
	mails.reverse()
	for m in MAILS:
		if m.id == "keys":
			m = m.duplicate()
			m.body = _with_keys(m.body)
		if Progress.resignations > 0 and m.id in ["welcome", "hr_exit"]:
			m = m.duplicate()
			if m.id == "welcome":
				m.body += "\n\n[b]P.S.[/b] Your predecessor (Contractor #%d) left some yellow paint in the drawer. Please do not use it." % (Progress.contractor_id() - 1)
			else:
				m.body += "\n\n[i]Our records show %d resignation%s from your desk so far. Keep up the great work![/i]" % [
					Progress.resignations, "" if Progress.resignations == 1 else "s"]
		mails.append(m)
	return mails


## The quick start guide shows the keys of THIS keyboard (from the Input Map). {action} = its key(s);
## {move} = the four move keys. Lines naming an action that doesn't exist are left out.
static func _with_keys(body: String) -> String:
	var menu: GDScript = load("res://settings_menu.gd")
	var lines: PackedStringArray = []
	for line in body.split("\n"):
		var ok := true
		var start := line.find("{")
		while start != -1:
			var end := line.find("}", start)
			if end == -1:
				break
			var action := line.substr(start + 1, end - start - 1)
			var keys := ""
			if action == "move":
				var parts: PackedStringArray = []
				for a in ["move_forward", "move_left", "move_back", "move_right"]:
					if InputMap.has_action(a):
						parts.append(menu._keys_for(a))
				keys = "".join(parts)
			elif InputMap.has_action(action):
				keys = menu._keys_for(action).split(" / ")[0]  # Just the main key ("Enter", not "Enter / Kp Enter").
			if keys == "":
				ok = false
				break
			line = line.substr(0, start) + keys + line.substr(end + 1)
			start = line.find("{", start + keys.length())
		if ok:
			lines.append(line)
	return "\n".join(lines)


static func unread_count() -> int:
	var n := 0
	for m in all_mails():
		if m.id not in Progress.read_mails and not (m.id == "welcome" and Progress.seen_intro):
			n += 1
	return n


static func is_read(id: String) -> bool:
	return id in Progress.read_mails or (id == "welcome" and Progress.seen_intro)
