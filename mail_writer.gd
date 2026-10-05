extends RefCounted
## Writes the emails that arrive as you progress (stored in Progress.delivered_mails, shown in Inlook).
##   announcement(...)  - from Chad: how your last level went (by score bracket) + the new playtest
##                        that got added to the scheduler.
##   performance(...)   - from Chad, when a level is finished under the unlock threshold.
##   greenlight(...)    - from Chad, once every level scored 10+: the last greenlight before shipping.
##   ending_mail(...)   - from Chad after the greenlight, depends on the ending (endings.gd).
##   patch_notes(...)   - the day-one patch notes: level changes because of how each tester did there in the best runs (Progress.best_runs).
##   patch_mail(...)    - from Chad after the credits: early access went well, Patch 1.1.
##   flavor_for(...)    - "flavor" mails: a parody of a toxic workplace. One is about a tester of the
##                        new level (their traits decide what kind of trouble they got into), and
##                        sometimes a generic one from the company.
## Edit the texts freely. Placeholders: {name} {outlet} {level} {total} {testers}.

const CHAD := ["Chad Bossworth", "c.bossworth@synergex-interactive.biz"]
const ENDINGS := preload("res://endings.gd")

## Chad's opening line about your last level, by total stars (out of 15).
const BRACKETS := {
	15: "A perfect [b]{total}/15[/b]. I printed the report and framed it. Then the investors took the frame home. They want more of this.",
	10: "[b]{total}/15[/b]. Solid work. Not perfect, but the slide only shows the first digit anyway.",
	5: "[b]{total}/15[/b]. I'm not angry, I'm just putting it in your file. The investors saw the number. One of them sighed. Out loud.",
	0: "[b]{total}/15[/b]. I have scheduled a meeting to discuss this meeting. Legal will attend. Legal brought snacks, which is never a good sign.",
}

## Flavor mails about a tester, keyed by "trait=value". One matching their traits is picked at random
## (70%), otherwise one of the "any" stories.
const TESTER_STORIES := [
	["patience=2", "Corporate Security", "security@synergex-interactive.biz", "Security incident (resolved)",
		"Team,\n\nDuring their last visit, {name} from {outlet} wandered into the server room \"looking for secrets\" and leaked the level to a competitor.\n\nThe leak was possible because the admin password was [b]admin123[/b]. Our security team made sure no one uses admin123 ever again. The new password is [b]admin1234[/b].\n\nPlease do not share it.\n\nCorporate Security"],
	["patience=0", "Corporate Security", "security@synergex-interactive.biz", "Visitor refusing to leave parking lot",
		"Hi all,\n\n{name} from {outlet} has been sitting in their car in Lot C since 8 AM. They say they won't walk to the entrance \"until someone paints the way\".\n\nPlease do [b]not[/b] paint the parking lot. We are aware of the irony.\n\nCorporate Security"],
	["jump=0", "Facilities", "facilities@synergex-interactive.biz", "Incident report: lobby fern",
		"Hello,\n\nDuring their visit, {name} from {outlet} attempted to jump over the potted fern in the lobby. The fern won.\n\nReminder: the fern is not a platform. It is not painted. Do not jump on the fern.\n\nFacilities"],
	["trust=0", "Finance", "finance@synergex-interactive.biz", "Expense report flagged",
		"Hi,\n\n{name} from {outlet} submitted an expense claim for [b]40 buckets of yellow paint[/b], \"for confidence reasons\".\n\nThis is not a reimbursable expense. Whoever keeps approving it: please stop.\n\nFinance"],
	["trust=2", "Facilities", "facilities@synergex-interactive.biz", "Found: one focus tester",
		"Hello,\n\n{name} from {outlet} followed a yellow \"Wet floor\" sign into the janitor's closet on Monday. They were found three hours later, waiting for the next sign.\n\nAll signs have been changed to beige.\n\nFacilities"],
	["jump=2", "People & Culture", "happiness@synergex-interactive.biz", "Fire drill results",
		"Hi team!\n\nCongratulations to visiting tester {name} from {outlet}, who completed Tuesday's fire drill in 14 seconds by jumping from the second floor balcony to the parking lot. Flawless landing.\n\nWe have been asked not to give out a prize.\n\nPeople & Culture"],
	["patience=2", "Marketing", "marketing@synergex-interactive.biz", "Early review (please stop them)",
		"Hi all,\n\n{name} from {outlet} published a 4,000-word essay titled \"The Emotional Weight of Moss\" about the next level. It has no spoilers, because they never found the exit.\n\nTheir only criticism: \"someone painted yellow on a 12K cliff texture. Why.\"\n\nMarketing"],
	["trust=2", "Art Department", "art-direction@synergex-interactive.biz", "Finally, someone who gets it",
		"Hi,\n\n{name} from {outlet} spent twenty minutes in photo mode taking pictures of a door handle. Their words: \"a masterpiece of handle-craft\".\n\nWe asked them about the yellow paint. They said \"what yellow paint? Oh. That. Yeah, I followed it.\"\n\nThe Art Department (both of us, emotional)"],
	["any", "Marketing", "marketing@synergex-interactive.biz", "Leaked screenshots (exciting!)",
		"Hi all,\n\nScreenshots of the next level appeared on {outlet} this morning, posted by {name}. They are stunning. Two million likes.\n\nTop comment: \"why is there yellow paint on that gorgeous cliff?\" (41,000 likes)\n\nMarketing is handling it. Legal is also handling it, separately.\n\nMarketing"],
	["any", "IT Helpdesk", "noreply-helpdesk@synergex-interactive.biz", "Incident: tester used the Level Readability workstation",
		"Dear user,\n\n{name} from {outlet} sat down at your workstation by mistake and saw HYPERION LEGENDS rendered as grey boxes for thirty seconds. They had to lie down. They are now asking for hazard pay.\n\nPlease lock your screen when you leave your desk.\n\nIT Helpdesk"],
]

## Generic office flavor. Each is sent at most once.
const OFFICE_STORIES := [
	["pto", "People & Culture", "happiness@synergex-interactive.biz", "Unlimited PTO: update",
		"Hi team!\n\nGood news: our Unlimited PTO policy is still unlimited.\n\nReminder: requests must be approved by your manager, their manager, and the investors. Average approval time: one fiscal year.\n\nPeople & Culture"],
	["sync", "Chad Bossworth", "c.bossworth@synergex-interactive.biz", "Quick sync?",
		"Quick sync at 6:45 PM? Should only take two hours. Bring snacks (for me).\n\nChad\n\n[i]Sent from my yacht[/i]"],
	["coffee", "Facilities", "facilities@synergex-interactive.biz", "The coffee machine is now a subscription",
		"Hello,\n\nThe coffee machine now requires a [b]SynergyBrew+[/b] subscription (9.99/month, deducted from payroll).\n\nThe free tier still offers hot water and a motivational quote.\n\nFacilities"],
	["wellness", "People & Culture", "happiness@synergex-interactive.biz", "It's Wellness Week!",
		"Hi team!\n\nThis week is Wellness Week! To reduce stress, we have moved all deadlines to Friday.\n\nAll of them.\n\nBreathe in.\n\nPeople & Culture"],
	["training", "IT Helpdesk", "noreply-helpdesk@synergex-interactive.biz", "Mandatory security training",
		"Dear user,\n\nPlease complete the 4-hour training [i]\"Never Click Links In Emails\"[/i] by Friday by clicking the link below.\n\n[u]https://totally-legit-training.biz/login[/u]\n\nIT Helpdesk"],
	["yogurt", "Darren (Accounting)", "d.whitlock@synergex-interactive.biz", "RE: RE: RE: RE: Who took my yogurt",
		"Reply all: please remove me from this thread.\n\n> Reply all: please remove me from this thread.\n>> Reply all: who is Darren\n>>> It was a strawberry yogurt. It had my NAME on it.\n\n[i]This thread has 214 replies.[/i]"],
	["texture_tour", "People & Culture", "happiness@synergex-interactive.biz", "Texture tour this Thursday!",
		"Hi team!\n\nJoin the Art Department this Thursday for a guided tour of the 12K textures of HYPERION LEGENDS. Highlights include the moss, the other moss, and a single brick they are very proud of.\n\nThe Level Readability Department is excused, as their workstations \"can't handle it\".\n\nThere will be cake (rendered).\n\nPeople & Culture"],
	["fan", "Facilities", "facilities@synergex-interactive.biz", "Noise complaint: Level Readability workstation",
		"Hello,\n\nThe fan of the Level Readability workstation has been measured at 87 dB and is now classified as a small aircraft.\n\nPlease do not open the case. The case is load-bearing.\n\nFacilities"],
	["kudos", "People & Culture", "happiness@synergex-interactive.biz", "This month's Kudos Wall",
		"Hi team!\n\nThis month's Kudos Wall winner is the coffee machine, for \"always being there\".\n\nHonorable mention: the Level Readability Department, for using slightly less yellow.\n\nPeople & Culture"],
]


## Chad's remark when a tester spent half the session (or more) lost. "" if nobody did.
## rounds: [{tester, session, lost}]
static func lost_note(rounds: Array) -> String:
	var worst := {}
	var worst_ratio := 0.0
	for r in rounds:
		if r.session <= 0.0:
			continue
		var ratio: float = r.lost / r.session
		if ratio >= 0.5 and ratio > worst_ratio:
			worst_ratio = ratio
			worst = r
	if worst.is_empty():
		return ""
	var lost := "%d:%02d" % [roundi(worst.lost) / 60, roundi(worst.lost) % 60]
	var session := "%d:%02d" % [roundi(worst.session) / 60, roundi(worst.session) % 60]
	var lines := [
		"PS: {name} spent [b]{lost}[/b] of a {session} session wandering around, lost. The investors timed it. One of them used a sundial.",
		"PS: I'm told {name} was lost for [b]{lost}[/b] out of {session}. That's {pct}% of the session spent admiring the scenery. The art team is thrilled. I am not. Please paint with intent.",
		"PS: {name} was lost for [b]{lost}[/b] (out of {session}). Marketing wants to call it \"open world\". Legal says we can't.",
	]
	return lines.pick_random().replace("{name}", worst.tester).replace("{lost}", lost) \
		.replace("{session}", session).replace("{pct}", str(roundi(worst_ratio * 100)))


static func lost_mail(level_name: String, note: String) -> Dictionary:
	var body := "Hi,\n\nQuick one about [b]%s[/b].\n\n%s\n\nChad" % [level_name, note.trim_prefix("PS: ")]
	return _mail(CHAD[0], CHAD[1], "RE: %s (time sheet)" % level_name, body, false)


static func announcement(level_name: String, total: int, testers: PackedStringArray, note := "") -> Dictionary:
	var names: PackedStringArray = []
	for t in testers:
		names.append("[b]%s[/b] from %s" % [t, FocusGroup.profile(t).get("outlet", "freelance")])
	var body := "Hi,\n\n%s\n\nBecause of your results, a new playtest has been added to your scheduler: [b]%s[/b].\n\nYour focus testers for this one: %s. Look out for it in Level Select, and read their profiles. Some of them are... a lot.\n\nAs always: as little yellow as possible.\n\nChad%s" % [
		bracket_text(total), level_name, ", ".join(names), ("\n\n" + note) if note != "" else ""]
	return _mail(CHAD[0], CHAD[1], "New playtest scheduled: %s" % level_name, body, true)


static func performance(level_name: String, total: int, needed: int, note := "", final := false) -> Dictionary:
	var body := "Hi,\n\nAbout [b]%s[/b].\n\n%s\n\n%s stays [b]on hold[/b] until this session scores at least [b]%d/15[/b]. Please run it again.\n\nChad%s" % [
		level_name, bracket_text(total), "The launch of HYPERION LEGENDS" if final else "The next playtest", needed,
		("\n\n" + note) if note != "" else ""]
	return _mail(CHAD[0], CHAD[1], "RE: %s results" % level_name, body, true)


# --- Release ------------------------------------------------------------------

static func greenlight(note := "") -> Dictionary:
	var body := """Hi,

Big day. Every playtest has been run and every department has signed off on [b]HYPERION LEGENDS: ETERNAL DAWN[/b]:

[ul]Art: approved (they cried)
Legal: approved (with snacks)
Marketing: approved (they announced the release date last week)
The investors: approved (they did not read it)[/ul]

You are the [b]last department[/b] that needs to give their greenlight.

When you press the button below, the build ships. Whatever your [b]best scores[/b] are at that moment go on the launch slide, and the launch slide is forever. You can still rerun any playtest before you press it. Take your time. (Do not take your time.)

Chad%s""" % (("\n\n" + note) if note != "" else "")
	return _mail(CHAD[0], CHAD[1], "FINAL GREENLIGHT NEEDED: HYPERION LEGENDS (gold master)", body, true)


## scores: [{name, stars}] of the levels that decided the ending.
static func ending_mail(ending: String, scores: Array) -> Dictionary:
	var lines: PackedStringArray = []
	for sc in scores:
		lines.append("%s: [b]%d/15[/b]" % [sc.name, sc.stars])
	var table := "[ul]%s[/ul]" % "\n".join(lines)
	var subject := ""
	var body := ""
	match ending:
		"investors":
			subject = "WE DID IT (the investors did it)"
			body = "Hi,\n\nIt's shipping. Look at this slide:\n\n%s\n\nPerfect. Every. Single. Session. I showed it to the board and three investors cried. One of them bought a second yacht, to have somewhere to put the first one.\n\nThe art team says the game has \"no soul\" and \"plays itself\". The art team is not on the slide.\n\nThe day-one patch notes are next in your inbox. Read them, then close Inlook and enjoy launch day.\n\nChad"
		"goty":
			subject = "RE: the launch slide (we need to talk)"
			body = "Hi,\n\nIt's shipping. Here is the slide:\n\n%s\n\n[b]Ten.[/b] Every session. Exactly the minimum. Not nine, not eleven. Do you know how hard it is to be [i]that[/i] consistently average? The investors asked if it was a typo. It is not a typo. I checked. Twice.\n\nWe're shipping anyway because Marketing already spent the budget on a blimp.\n\nThe day-one patch notes are next in your inbox. Read them, then close Inlook and enjoy launch day. We will discuss your future after the launch.\n\nChad"
		_:
			subject = "We're shipping!"
			body = "Hi,\n\nIt's shipping. Here is the slide:\n\n%s\n\nThe investors looked at it for a long time and said \"fine\". I have decided to hear \"great\".\n\nThe day-one patch notes are next in your inbox. Read them, then close Inlook and enjoy launch day.\n\nChad"
	return _mail(CHAD[0], CHAD[1], subject, body % table, true)


## The day-one patch notes. The level changes are explained by the testers who struggled there.
## totals = Progress.tester_totals() (telemetry table), levels = Progress.level_stats() ([{name, testers}]).
static func patch_notes(ending: String, totals: Dictionary, levels: Array) -> Dictionary:
	var names: Array = totals.keys()
	names.sort_custom(func(a, b): return totals[a].get("tests", 0) > totals[b].get("tests", 0))
	var total := {}
	for n in names:
		for k in totals[n]:
			total[k] = total.get(k, 0) + totals[n][k]

	var changes := ""
	for lv in levels:
		var testers: Dictionary = lv.testers
		var order: Array = testers.keys()
		order.sort_custom(func(a, b): return testers[a].get("tests", 0) > testers[b].get("tests", 0))
		var lines: PackedStringArray = []
		for t in order:
			lines.append(_level_change(t, testers[t]))
		changes += "[b]%s[/b]\n[ul]%s[/ul]\n" % [lv.name if lv.name != "" else "All levels", "\n".join(lines)]
	if changes == "":
		changes = "[ul]No playtest data was found. We changed nothing and are shipping anyway.[/ul]\n"

	var table := "[table=5][cell][b]Tester[/b]   [/cell][cell][b]Rounds[/b]   [/cell][cell][b]Missed jumps[/b]   [/cell][cell][b]Time lost[/b]   [/cell][cell][b]Hotfixes seen[/b][/cell]"
	for n in names:
		var st: Dictionary = totals[n]
		table += "[cell]%s   [/cell][cell]%d[/cell][cell]%d[/cell][cell]%s[/cell][cell]%d[/cell]" % [
			n, st.get("tests", 0), st.get("failed_jumps", 0), _t(st.get("lost", 0.0)), st.get("hotfixes_seen", 0)]
	table += "[/table]"

	var known: PackedStringArray = []
	match ending:
		"investors":
			known.append("Players report that the game \"plays itself\". Investigating whether this is a feature. (It is a feature.)")
			known.append("Some players report seeing yellow when they close their eyes. Working as intended.")
		"goty":
			known.append("Some ledges are not yellow. Players love this. Management does not. Investigating.")
			known.append("Players report \"having fun\" and \"getting lost\". A fix is planned.")
		_:
			known.append("The game is fine.")
			known.append("Some ledges are yellow and some are not. Nobody can explain the pattern, including us.")
	known.append("Yellow paint can be seen on top of the hand-sculpted moss. The Art Department has been informed. The Art Department is not okay.")
	known.append("The Level Readability workstation still renders the game as grey boxes. IT says this is a feature.")

	var body := """[b]HYPERION LEGENDS: ETERNAL DAWN - v1.0.0 Day-One Patch[/b]
[font_size=15][color=#6b6e7a]Download size: 87 GB (80 GB of 12K moss textures, 7 GB of yellow paint)[/color][/font_size]

[b]GENERAL[/b]
[ul]Shipped.
In their best runs, focus testers spent a combined [b]%s[/b] lost (\"admiring the scenery\") and missed [b]%d[/b] jumps.
%s[/ul]

[b]LEVEL CHANGES[/b] (based on focus group feedback)
%s
[b]TELEMETRY[/b] (Legal says we have to show this)
%s

[b]KNOWN ISSUES[/b]
[ul]%s[/ul]

The HYPERION LEGENDS Live Team
[i]"Patching it live since day one."[/i]""" % [
		_t(total.get("lost", 0.0)), int(total.get("failed_jumps", 0)),
		("The emergency red splat painted during the final playtests is now a permanent part of the art direction. Legal would like to know who painted it."
			if int(total.get("hotfixes", 0)) == 1 else
			"The %d emergency red splats painted during the final playtests are now a permanent part of the art direction. Legal would like to know who painted them." % int(total.get("hotfixes", 0)))
			if total.get("hotfixes", 0) > 0 else "Zero hotfixes were applied during playtests. Legal is suspicious.",
		changes, table, "\n".join(known)]
	var m := _mail("HYPERION LEGENDS Live Team", "liveops@synergex-interactive.biz",
		"HYPERION LEGENDS v1.0.0 - Day-One Patch Notes", body, false)
	m.date = "Launch day"
	return m


## What was changed in a level because of how a tester did there. {name} {n} {time} are filled in.
const LEVEL_CHANGES := {
	deaths = [
		"Added invisible walls along the edges after [b]{name}[/b] fell off {n} times.",
		"Added a safety net under the jumps. [b]{name}[/b] requested it in writing, after falling {n} times.",
		"Made the pit 2 metres shallower so falling feels less final ([b]{name}[/b] fell in {n} times).",
	],
	failed_jumps = [
		"Moved some ledges 30 cm closer together after [b]{name}[/b] missed {n} jumps.",
		"Gaps are now slightly less gappy, after [b]{name}[/b] came up short {n} times.",
		"Ledges are now 10% stickier, after [b]{name}[/b] missed {n} landings.",
	],
	hotfixes_seen = [
		"The {n} red splats [b]{name}[/b] saw appear mid-session are now officially part of the level design.",
		"Added permanent paint where [b]{name}[/b] needed {n} emergency hotfixes. They were always there.",
	],
	lost = [
		"Added a giant yellow arrow at the start, after [b]{name}[/b] spent {time} admiring the scenery instead of finding the exit.",
		"Turned the waterfall down a little: [b]{name}[/b] spent {time} staring at it instead of the path.",
		"Removed a very pretty sunset that distracted [b]{name}[/b] for {time}.",
	],
	retries = [
		"Added a checkpoint after [b]{name}[/b] had to be restarted {n} times.",
		"Shortened the walk from the start, which [b]{name}[/b] had to repeat {n} times.",
	],
	clean = [
		"No changes needed for [b]{name}[/b]. We added more yellow paint anyway, just in case.",
		"[b]{name}[/b] finished without trouble. We are investigating what went wrong.",
	],
}


static func _level_change(name: String, s: Dictionary) -> String:
	var stat := ENDINGS.notable_stat(s)
	var n: int = int(s.get(stat, 0)) if stat != "clean" else 0
	var line := (LEVEL_CHANGES[stat].pick_random() as String).replace("{name}", name) \
		.replace("{n}", str(n)).replace("{time}", _t(s.get("lost", 0.0)))
	if n == 1:  # "1 red splats ... are" -> "1 red splat ... is"
		line = line.replace("1 red splats", "1 red splat").replace(" are now", " is now") \
			.replace("1 emergency hotfixes", "1 emergency hotfix").replace("1 times", "once") \
			.replace("1 jumps", "1 jump").replace("1 landings", "1 landing")
	return line


## After the credits. `extra_level` = the post-launch level's name ("" if the game has none).
static func patch_mail(ending: String, extra_level: String) -> Dictionary:
	var e := ENDINGS.info(ending)
	var opener := ""
	match ending:
		"investors":
			opener = "The critics gave us a [b]%d[/b]. The players gave us a [b]%.1f[/b] and a lot of words I had to look up. The investors have asked me to stop forwarding them the player reviews." % [e.critics, e.gamers]
		"goty":
			opener = "The players gave us a [b]%.1f[/b] and are calling it Game of the Year. The critics gave us a %d. The investors gave me a look. I am choosing to take credit for all of it." % [e.gamers, e.critics]
		_:
			opener = "Critics: [b]%d[/b]. Players: [b]%.1f[/b]. Investors: \"fine\". It's fine. Everything is fine." % [e.critics, e.gamers]
	var dlc := ""
	if extra_level != "":
		dlc = "\n\nAlso, the devs managed to finish a [b]new secret area[/b] that 4.3%% of players could experience: [b]%s[/b]. We're selling it for [b]$4.99[/b]. It's in your Level Select. It needs paint." % extra_level
	var body := "Hi,\n\nGreat news: early access is going well. (We are calling it early access now. Legal says it helps.)\n\n%s\n\nWe raised enough funds to patch the game: welcome to [b]Patch 1.1[/b]. Your scores stay on file. You can replay any playtest and try to beat your best scores and times. Nothing is at stake anymore. (Something is always at stake.)%s\n\nChad\n\n[i]Sent from my yacht (financed by Patch 1.1)[/i]" % [opener, dlc]
	return _mail(CHAD[0], CHAD[1], "Early access is going GREAT (Patch 1.1)", body, true)


static func _t(seconds: float) -> String:
	var s := roundi(seconds)
	return "%d:%02d" % [s / 60, s % 60]


static func bracket_text(total: int) -> String:
	var key := 0
	if total >= 15:
		key = 15
	elif total >= 10:
		key = 10
	elif total >= 5:
		key = 5
	return BRACKETS[key].replace("{total}", str(total))


## 1-2 flavor mails for a newly added level: one about one of its testers, maybe one office one.
## `used` = template ids already sent (so office stories don't repeat).
static func flavor_for(testers: PackedStringArray, used: Array) -> Array[Dictionary]:
	var mails: Array[Dictionary] = []
	if not testers.is_empty():
		var tester: String = testers[randi() % testers.size()]
		var p := FocusGroup.profile(tester)
		# A story about one of their traits if there is one (sometimes a generic one anyway, for variety).
		var specific := TESTER_STORIES.filter(func(st): return st[0] != "any" and _matches(st[0], p))
		var generic := TESTER_STORIES.filter(func(st): return st[0] == "any")
		var pool: Array = specific if not specific.is_empty() and randf() < 0.7 else generic
		var story: Array = pool.pick_random()
		mails.append(_mail(story[1], story[2], story[3],
			story[4].replace("{name}", tester).replace("{outlet}", p.get("outlet", "freelance")), false))
	var fresh := OFFICE_STORIES.filter(func(s): return "office_" + s[0] not in used)
	if not fresh.is_empty() and (mails.is_empty() or randf() < 0.6):
		var s: Array = fresh.pick_random()
		var m := _mail(s[1], s[2], s[3], s[4], false)
		m.template = "office_" + s[0]
		mails.append(m)
	return mails


static func _matches(rule: String, profile: Dictionary) -> bool:
	if rule == "any":
		return true
	var parts := rule.split("=")
	return int(profile.get(parts[0], 1)) == int(parts[1])


static func _mail(from: String, address: String, subject: String, body: String, flag: bool) -> Dictionary:
	var t := Time.get_datetime_dict_from_system()
	var days := ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
	var hour12: int = t.hour % 12 if t.hour % 12 != 0 else 12
	return {
		id = "", from = from, address = address, cc = "", subject = subject, flag = flag, body = body,
		date = "%s %d:%02d %s" % [days[t.weekday], hour12, t.minute, "AM" if t.hour < 12 else "PM"],
		template = "",
	}
