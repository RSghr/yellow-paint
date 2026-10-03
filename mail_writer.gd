extends RefCounted
## Writes the emails that arrive as you progress (stored in Progress.delivered_mails, shown in Inlook).
##   announcement(...)  - from Chad: how your last level went (by score bracket) + the new playtest
##                        that got added to the scheduler.
##   performance(...)   - from Chad, when a level is finished under the unlock threshold.
##   flavor_for(...)    - "flavor" mails: a parody of a toxic workplace. One is about a tester of the
##                        new level (their traits decide what kind of trouble they got into), and
##                        sometimes a generic one from the company.
## Edit the texts freely. Placeholders: {name} {outlet} {level} {total} {testers}.

const CHAD := ["Chad Bossworth", "c.bossworth@synergex-interactive.biz"]

## Chad's opening line about your last level, by total stars (out of 15).
const BRACKETS := {
	15: "A perfect [b]{total}/15[/b]. I printed the report and framed it. Then the investors took the frame home. They want more of this.",
	10: "[b]{total}/15[/b]. Solid work. Not perfect, but the slide only shows the first digit anyway.",
	5: "[b]{total}/15[/b]. I'm not angry, I'm just putting it in your file. The investors saw the number. One of them sighed. Out loud.",
	0: "[b]{total}/15[/b]. I have scheduled a meeting to discuss this meeting. Legal will attend. Legal brought snacks, which is never a good sign.",
}

## Flavor mails about a tester, keyed by "trait=value" (checked in this order). The first that
## matches the tester is used; "any" always matches.
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
	["any", "Marketing", "marketing@synergex-interactive.biz", "Leaked screenshots (exciting!)",
		"Hi all,\n\nScreenshots of the next level appeared on {outlet} this morning, posted by {name}. They show grey boxes.\n\nMarketing is calling them \"an exciting early look at our bold minimalist art direction\". Legal is calling them something else.\n\nMarketing"],
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
		"PS: I'm told {name} was lost for [b]{lost}[/b] out of {session}. That's {pct}% of the session spent admiring our grey boxes. Please paint with intent.",
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


static func performance(level_name: String, total: int, needed: int, note := "") -> Dictionary:
	var body := "Hi,\n\nAbout [b]%s[/b].\n\n%s\n\nThe next playtest stays [b]on hold[/b] until this session scores at least [b]%d/15[/b]. Please run it again.\n\nChad%s" % [
		level_name, bracket_text(total), needed, ("\n\n" + note) if note != "" else ""]
	return _mail(CHAD[0], CHAD[1], "RE: %s results" % level_name, body, true)


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
		for story in TESTER_STORIES:
			if _matches(story[0], p):
				var m := _mail(story[1], story[2], story[3],
					story[4].replace("{name}", tester).replace("{outlet}", p.get("outlet", "freelance")), false)
				mails.append(m)
				break
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
