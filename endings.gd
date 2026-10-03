extends RefCounted
## The 3 endings of HYPERION LEGENDS, decided at the greenlight from the best scores of the levels
## after the tutorials (Progress.compute_ending()):
##   investors - 15/15 on every level. Critics and investors love it, gamers hate being hand-held.
##   goty      - exactly 10/15 on every level. Barely enough yellow: gamers love it, investors are furious.
##   decent    - anything else. It's fine.
## Used by mail_writer.gd (Chad's mails, patch notes) and credits.gd. Edit the texts freely.

const ENDINGS := {
	investors = {
		title = "The Investors' Cut",
		critics = 97, critics_label = "Universal acclaim",
		gamers = 1.9, gamers_label = "Overwhelmingly negative",
		gamers_quote = "\"The game plays itself. I watched it for 40 hours.\"",
		investors = [
			["The numbers are perfect. I didn't play it. Why would I?", "Brock Hedgewell, Hedgewell Capital"],
			["Fifteen out of fifteen, every single time. That's not a game, that's a dividend.", "Name withheld (yacht)"],
			["The players hate it? The players aren't on the cap table.", "Vivian Moneypenny, Moneypenny Ventures"],
		],
		tester_tail = "Every ledge was yellow. Every single one. I never had to think once. Is that... good?",
	},
	goty = {
		title = "Game of the Year (by gamers)",
		critics = 68, critics_label = "Mixed or average",
		gamers = 9.6, gamers_label = "Overwhelmingly positive",
		gamers_quote = "\"I got LOST. In a VIDEO GAME. In this ECONOMY. Game of the year.\"",
		investors = [
			["Ten out of fifteen. On every level. I want whoever did this found.", "Brock Hedgewell, Hedgewell Capital"],
			["It sold forty million copies and I am still upset.", "Name withheld (yacht, smaller)"],
			["The gamers love it. Disgusting.", "Vivian Moneypenny, Moneypenny Ventures"],
		],
		tester_tail = "I got lost, then I found my way. I think that's what they call a game.",
	},
	decent = {
		title = "Mostly Fine",
		critics = 79, critics_label = "Generally favorable",
		gamers = 6.8, gamers_label = "Mixed",
		gamers_quote = "\"It's fine. The yellow is fine. I'm fine.\"",
		investors = [
			["It's fine. We'll make it back on the battle pass.", "Brock Hedgewell, Hedgewell Capital"],
			["A solid B-minus. Like my son.", "Name withheld (yacht)"],
			["I've seen worse. I've funded worse.", "Vivian Moneypenny, Moneypenny Ventures"],
		],
		tester_tail = "It was a game. I played it. Some of it was yellow.",
	},
}


static func info(id: String) -> Dictionary:
	return ENDINGS.get(id, ENDINGS.decent)


## The stat a tester is most remembered for: "deaths", "failed_jumps", "hotfixes_seen", "lost", "retries" or "clean".
static func notable_stat(s: Dictionary) -> String:
	var weights := {
		deaths = s.get("deaths", 0) * 3.0,
		failed_jumps = s.get("failed_jumps", 0) * 2.0,
		hotfixes_seen = s.get("hotfixes_seen", 0) * 2.0,
		lost = s.get("lost", 0.0) / 15.0,  # One point per 15 s lost.
		retries = s.get("retries", 0) * 1.0,
	}
	var best := "clean"
	var best_w := 1.5  # Below this, nothing stood out.
	for k in weights:
		if weights[k] > best_w:
			best_w = weights[k]
			best = k
	return best


## What a tester said about the launch, from their own record.
static func tester_quote(s: Dictionary) -> String:
	var n := func(k): return str(int(s.get(k, 0)))
	match notable_stat(s):
		"deaths":
			return "I fell %s times. The yellow and I are no longer on speaking terms." % n.call("deaths")
		"failed_jumps":
			return "%s of my jumps landed short. I blame the paint. The paint blames me." % n.call("failed_jumps")
		"hotfixes_seen":
			return "I saw %s red splats appear out of nowhere. Someone was watching me. Thank you? I think?" % n.call("hotfixes_seen")
		"lost":
			return "I spent %s just admiring the scenery. No idea where to go, but what a view." % _time(s.get("lost", 0.0))
		"retries":
			return "They reset me %s times. Every time I woke up at the start, and every time it was yellow." % n.call("retries")
	return "Flawless run. Suspiciously flawless. Who painted all this?"


static func _time(seconds: float) -> String:
	var t := roundi(seconds)
	return "%d:%02d" % [t / 60, t % 60]
