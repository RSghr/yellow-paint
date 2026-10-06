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
const HOTFIX_BUDGET := 2  ## Free hotfixes per level (keep in sync with game.gd free_hotfixes).
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
	["patience=2", "Marketing", "marketing@synergex-interactive.biz", "early review (pls make them stop)",
		"hiii all,\n\nso {name} from {outlet} dropped a 4,000-word essay called \"The Emotional Weight of Moss\" about the next level and honestly?? it's giving literature. zero spoilers bc they never found the exit lmao\n\nonly L: \"someone painted yellow on a 12K cliff texture. why.\" ratio'd but valid ngl\n\nMarketing (we're so back)"],
	["trust=2", "Art Department", "art-direction@synergex-interactive.biz", "Finally, someone who gets it",
		"Hi,\n\n{name} from {outlet} spent twenty minutes in photo mode taking pictures of a door handle. Their words: \"a masterpiece of handle-craft\".\n\nWe asked them about the yellow paint. They said \"what yellow paint? Oh. That. Yeah, I followed it.\"\n\nThe Art Department (both of us, emotional)"],
	["any", "Marketing", "marketing@synergex-interactive.biz", "leaked screenshots (we're thriving??)",
		"hey besties,\n\n{name} from {outlet} leaked screenshots of the next level this morning and they're literally stunning. 2M likes. we didn't even pay for it fr\n\ntop comment: \"why is there yellow paint on that gorgeous cliff?\" (41k likes). lowkey not a vibe.\n\nlegal is handling it. separately. no cap.\n\nMarketing"],
	["any", "IT Helpdesk", "noreply-helpdesk@synergex-interactive.biz", "Incident: tester used the Level Readability workstation",
		"Dear user,\n\n{name} from {outlet} sat down at your workstation by mistake and saw HYPERION LEGENDS rendered as grey boxes for thirty seconds. They had to lie down. They are now asking for hazard pay.\n\nPlease lock your screen when you leave your desk.\n\nIT Helpdesk | [i]\"Any expired license needs to be approved by Legal and Darren from Accounting.\"[/i]"],
]

## Story mails: written once, delivered at fixed points of the career (Progress: story_for()).
## id: [from, address, subject, body]
const STORY_MAILS := {
	yogurt = ["Darren (Accounting)", "d.whitlock@synergex-interactive.biz", "RE: RE: RE: RE: Who took my yogurt",
		"Reply all: please remove me from this thread.\n\n> Reply all: please remove me from this thread.\n>> Reply all: has anyone checked the fridge cam?\n>>> It was a strawberry yogurt. It had my NAME on it.\n\n[i]This thread has 214 replies.[/i]"],
	yogurt_chad = ["Kevin (Level Design)", "k.osei@synergex-interactive.biz", "RE: RE: RE: RE: RE: RE: Who took my yogurt",
		"It was Chad.\n\n> Reply all: please stop replying all.\n>> Reply all: please remove me from this thread.\n>>> Reply all: has anyone checked the fridge cam?\n>>>> It was a strawberry yogurt. It had my NAME on it.\n\n[i]This thread has 389 replies. This is the last one.[/i]"],
	burnout = ["Chad Bossworth", "c.bossworth@synergex-interactive.biz", "A difficult message (read, then delete)",
		"Team,\n\nIt is with great sadness that I announce we have lost another colleague to burnout. Kevin from Level Design will be missed. His desk is available. (Not to you. You have a desk.)\n\nI also want to address something. Information has been leaking. Fridge information, mostly. Leaks scare the investors, and when the investors are scared they buy fewer yachts, and that hurts all of us.\n\nGoing forward, anyone who shares [b]anything[/b] without consulting Legal first will be invited to a meeting with People & Culture for a [b]burnout assessment[/b]. It is a formality. Kevin passed his.\n\nOur thoughts are with Kevin.\n\nChad\n\n[i]Sent from my yacht[/i]"],
	desk_move = ["Facilities", "facilities@synergex-interactive.biz", "Good news: your new desk (Level -3)",
		"Hello,\n\nWe heard you're now testing the more demanding levels. Congratulations! To support you, your workstation is moving to a brand new desk on [b]Level -3[/b], right next to the parking lot.\n\nThe great part: you can start working the second you park your car. No elevator, no small talk, no windows.\n\nThe ThinkBox fan will finally get some air. The garage is very well ventilated, especially when the cars are running.\n\nChad approved this initiative personally.\n\nFacilities"],
	nephew = ["Vivian Moneypenny", "v.moneypenny@moneypenny-ventures.com", "Quick favour (my nephew)",
		"Hello,\n\nI'm told you are the one who decides what goes into the game. My nephew Brayden (11) would like to be a playable character. He is very good at the video games and has a lot of ideas.\n\nHe would like to be a dragon. Or a sniper. Or a dragon who is also a sniper.\n\nI'm sure this won't be a problem, considering.\n\nWarm regards,\nVivian Moneypenny\nMoneypenny Ventures | [i]\"Patient capital. Impatient people.\"[/i]"],
	readability = ["Level Readability", "readability@synergex-interactive.biz", "are you okay?",
		"hey.\n\nare you okay? i know about the fan. i know about the paint. i know what goes on the slide.\n\nyou don't know me. i sat at your desk before you, back when it was on the 2nd floor and had a window. contractor [b]#3502[/b].\n\nthey never revoked my login. corporate security never renewed the credentials. i still get all the mails. i still see grey boxes when i close my eyes.\n\nyou did good. the testers found the flag. nobody will ever know it was you.\n\ndon't reply. replies go to a folder nobody reads.\n\ni read it.\n\n#3502"],
}

## The antivirus feud: one mail per main level unlocked (1 = The Gauntlet, 2 = The Tower, ...).
const ANTIVIRUS_THREAD := [
	["Corporate Security", "security@synergex-interactive.biz", "New mandatory antivirus: VigilantShield Enterprise",
		"Team,\n\nFollowing the recent leak, every workstation now runs [b]VigilantShield Enterprise[/b], in addition to the four antiviruses already installed. They will scan each other. This is called defense in depth.\n\nYou may notice your workstation is slower. That is what being safe feels like.\n\nCorporate Security"],
	["IT Helpdesk", "noreply-helpdesk@synergex-interactive.biz", "RE: New mandatory antivirus: VigilantShield Enterprise",
		"Dear Corporate Security,\n\nWe have received [b]312 tickets[/b] about performance since the new antivirus. The ThinkBox 2009 on Level -3 now takes 55 minutes to boot, and one of the five antiviruses has quarantined another one.\n\nWe request permission to uninstall one (1) of them.\n\nIT Helpdesk | [i]\"Any expired license needs to be approved by Legal and Darren from Accounting.\"[/i]\n\n> Request denied. The antiviruses are fine. We have installed a sixth one to monitor the other five.\n> Corporate Security"],
	["Corporate Security", "security@synergex-interactive.biz", "RE: RE: New mandatory antivirus: VigilantShield Enterprise",
		"IT,\n\nThe sixth antivirus has flagged the yellow paint as a threat. Please stop sending us tickets about it. The tickets have also been quarantined.\n\nCorporate Security"],
]

## When the story mails arrive. Keys: "unlock_N" (the Nth main level unlocked), "greenlight", "patch".
const STORY_SCHEDULE := {
	unlock_1 = ["yogurt"],
	unlock_2 = ["desk_move", "nephew"],
	greenlight = ["yogurt_chad", "burnout"],
	patch = ["readability"],
}


## The story mails for an event, in delivery order: [{id, mail}]. Already delivered ids are the caller's job.
static func story_for(event: String) -> Array:
	var out := []
	if event.begins_with("unlock_"):
		var n := int(event.trim_prefix("unlock_"))
		if n >= 1 and n <= ANTIVIRUS_THREAD.size():
			var t: Array = ANTIVIRUS_THREAD[n - 1]
			out.append({id = "story_antivirus_%d" % n, mail = _mail(t[0], t[1], t[2], t[3], false)})
	for id in STORY_SCHEDULE.get(event, []):
		var m: Array = STORY_MAILS[id]
		out.append({id = "story_" + id, mail = _mail(m[0], m[1], m[2], m[3], false)})
	return out


## Generic office flavor. Each is sent at most once (with Chad's performance reviews, see office_mail()).
const OFFICE_STORIES := [
	["shadow_drop", "Marketing", "marketing@synergex-interactive.biz", "the shadow drop ATE",
		"hiii,\n\nwe shadow dropped 3 cryptic images of the game at 3am with zero context: a moss close-up, a door handle, and one (1) yellow splat we didn't catch in time.\n\nreception: insane. every platform. the memes were PEAK. someone made the yellow splat a sun god and it has a fandom now. it has fanart. it has a name: \"Mustard\".\n\nwe're not deleting it. we're leaning in.\n\nMarketing (on fire, metaphorically)"],
	["trends", "Marketing", "marketing@synergex-interactive.biz", "quick q for the devs (urgent-ish)",
		"hey devs!!\n\nquick one: can we add [b]rizz[/b] as a stat? and an emote where the hero hits the griddy on the final boss? and a battle pass? and a crossover with that one viral capybara?\n\nwe ran it by our focus group (the group chat) and it's a 10/10, no notes.\n\nalso can the yellow paint be less mid. like holographic or smth\n\nMarketing"],
	["art_vision", "Art Department", "art-direction@synergex-interactive.biz", "Small idea for the next patch",
		"Hi,\n\nSmall idea. What if the map was [b]500 km²[/b]? Fully explorable. And it changes with the seasons. Real seasons: if you play in December it snows, and the snow remembers your footprints until March.\n\nAlso every NPC keeps a dream journal. And the moss grows in real time. Slowly. Like real moss.\n\nWe've already started. We didn't ask.\n\nThe Art Department (both of us, sleeping here now)"],
	["pto", "People & Culture", "happiness@synergex-interactive.biz", "Unlimited PTO: update",
		"Hi team!\n\nGood news: our Unlimited PTO policy is still unlimited.\n\nReminder: requests must be approved by your manager, their manager, and the investors. Average approval time: one fiscal year.\n\nPeople & Culture"],
	["sync", "Chad Bossworth", "c.bossworth@synergex-interactive.biz", "Quick sync?",
		"Quick sync at 6:45 PM? Should only take two hours. Bring snacks (for me).\n\nChad\n\n[i]Sent from my yacht[/i]"],
	["coffee", "Facilities", "facilities@synergex-interactive.biz", "The coffee machine is now a subscription",
		"Hello,\n\nThe coffee machine now requires a [b]SynergyBrew+[/b] subscription (9.99/month, deducted from payroll).\n\nThe free tier still offers hot water and a motivational quote.\n\nFacilities"],
	["wellness", "People & Culture", "happiness@synergex-interactive.biz", "It's Wellness Week!",
		"Hi team!\n\nThis week is Wellness Week! To reduce stress, we have moved all deadlines to Friday.\n\nAll of them.\n\nBreathe in.\n\nPeople & Culture"],
	["training", "Corporate Security", "security@synergex-interactive.biz", "Mandatory security training",
		"Team,\n\nPlease complete the 4-hour training [i]\"Never Click Links In Emails\"[/i] by Friday by clicking the link below.\n\n[url=https://www.wikihow.com/Be-Safe-on-the-Internet]https://totally-legit-training.biz/login[/url]\n\nCorporate Security"],
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


## Chad's remark about the hotfixes of the level's 3 runs. rounds: [{hotfixes, hotfix_budget}]. "" if none.
## Within the budget it's tolerated; over it, he notices.
static func hotfix_note(rounds: Array) -> String:
	var n := 0
	var budget := 2
	for r in rounds:
		n += int(r.get("hotfixes", 0))
		budget = int(r.get("hotfix_budget", budget))
	if n == 0:
		return ""
	var lines: Array
	if n <= budget:
		lines = [
			"PS: {n} {hotfixes} this session. Within budget. Finance sent a thumbs-up emoji, which they have never done before.",
			"PS: You used {n} of your {budget} approved hotfixes. That's what they're for. Don't make it a personality.",
			"PS: {n} {hotfixes}, all within budget. Legal looked at them and said nothing. From Legal, that's a hug.",
		]
	else:
		lines = [
			"PS: {n} hotfixes. The budget was {budget}. Legal would like to know where the other {over} came from.",
			"PS: {n} hotfixes against an approved budget of {budget}. The testers have started calling the level \"haunted\". Marketing loves it. I don't.",
			"PS: {over} hotfixes over budget. Finance has opened a ticket. The ticket has a ticket.",
		]
	return (lines.pick_random() as String).replace("{n}", str(n)).replace("{budget}", str(budget)) \
		.replace("{over}", str(n - budget)).replace("{hotfixes}", "hotfix" if n == 1 else "hotfixes")


## Over the hotfix budget with nothing else to say: Chad writes anyway (once per level).
static func hotfix_mail(level_name: String, note: String) -> Dictionary:
	var body := "Hi,\n\nQuick one about [b]%s[/b].\n\n%s\n\nChad" % [level_name, note.trim_prefix("PS: ")]
	return _mail(CHAD[0], CHAD[1], "RE: %s (hotfix budget)" % level_name, body, false)


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
	known.append("Crafting was never added. The 1,400 crafting components scattered across the world remain fully collectible.")
	known.append([
		"Ammo can be collected, but there are no guns yet. Guns are planned for Season 2.",
		"The hunger bar was removed in v0.9. Some players report still feeling hungry.",
		"Some players skipped the 600 pages of lore carved into the architecture. They will be found.",
		"The 214 map icons on the starting hill are now 213. Nobody noticed which one.",
	].pick_random())

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
		_t(total.get("lost", 0.0)), int(total.get("failed_jumps", 0)), _hotfix_summary(levels),
		changes, table, "\n".join(known)]
	var m := _mail("HYPERION LEGENDS Live Team", "liveops@synergex-interactive.biz",
		"HYPERION LEGENDS v1.0.0 - Day-One Patch Notes", body, false)
	m.date = "Launch day"
	return m


## The GENERAL line about hotfixes: none, all within each level's budget, or over it somewhere.
static func _hotfix_summary(levels: Array) -> String:
	var n := 0
	var over := 0
	for lv in levels:
		var level_n := 0
		for t in lv.testers:
			level_n += int(lv.testers[t].get("hotfixes", 0))
		n += level_n
		over += maxi(0, level_n - HOTFIX_BUDGET)
	if n == 0:
		return "Zero hotfixes were applied during playtests. Legal is suspicious."
	if over == 0:
		return ("The approved hotfix applied during the final playtests stayed within budget. Finance sent the spreadsheet to the Art Department, who made it part of the lore."
			if n == 1 else
			"The %d approved hotfixes applied during the final playtests stayed within budget. Finance sent the spreadsheet to the Art Department, who made it part of the lore." % n)
	return "%d emergency red splats were painted during the final playtests, [b]%d over budget[/b]. They are now a permanent part of the art direction. Legal would like to know who painted them." % [n, over]


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
static func flavor_for(testers: PackedStringArray, used: Array, office := true) -> Array[Dictionary]:
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
	if office and (mails.is_empty() or randf() < 0.6):
		var m := office_mail(used)
		if not m.is_empty():
			mails.append(m)
	return mails


## A generic office mail not sent yet ({} if they all were). `used` = templates already delivered.
static func office_mail(used: Array) -> Dictionary:
	var fresh := OFFICE_STORIES.filter(func(s): return "office_" + s[0] not in used)
	if fresh.is_empty():
		return {}
	var s: Array = fresh.pick_random()
	var m := _mail(s[1], s[2], s[3], s[4], false)
	m.template = "office_" + s[0]
	return m


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
