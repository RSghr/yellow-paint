extends RefCounted
## The emails in Inlook (the desktop's mail app). Newest first. Bodies are BBCode (RichTextLabel).
## Add a starting mail: append a dictionary to MAILS with a unique `id`. Read state is saved in Progress.read_mails.
## Mails that arrive during play (new levels, flavor) are written by mail_writer.gd and stored in Progress.
## The "welcome" mail is the story intro: Inlook opens on it at first launch.

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

[font_size=15][color=#6b6e7a]*Fourth A pending legal review. This email and any attachments are confidential and may contain enthusiasm. If you received it by mistake, you now work here.[/color][/font_size]""",
	},
	{
		id = "art",
		from = "Art Department",
		address = "art-direction@synergex-interactive.biz",
		cc = "",
		subject = "RE: Art direction status",
		date = "Mon 7:48 AM",
		flag = false,
		body = """Hi all,

Quick update: the art direction is [b]95% finalized[/b]. We have narrowed the palette down to "grey" and "slightly different grey".

The moodboard is attached: [i]moodboard_v14_FINAL_final(2)_USE_THIS.png[/i] (it's a grey box, but look at the [b]lighting[/b]).

Reminder: please [b]do not[/b] paint the boxes yellow. Yellow is not part of the brand. Yellow is the opposite of immersion.

Thanks,
The Art Department (both of us)""",
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
]


## Everything in the inbox, newest first: mails received during play, then the starting ones.
static func all_mails() -> Array:
	var mails: Array = Progress.delivered_mails.duplicate()
	mails.reverse()
	mails.append_array(MAILS)
	return mails


static func unread_count() -> int:
	var n := 0
	for m in all_mails():
		if m.id not in Progress.read_mails and not (m.id == "welcome" and Progress.seen_intro):
			n += 1
	return n


static func is_read(id: String) -> bool:
	return id in Progress.read_mails or (id == "welcome" and Progress.seen_intro)
