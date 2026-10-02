class_name FocusGroup
## The focus testers (each playtest gets a random one) and what they say about your level.

## The roster. Each tester has three traits, 0 (lowest) to 2. 1 is the default playtester.
##   jump:     how reliable their unpainted (improvised) jumps are.  2 Precise | 1 Hit or miss | 0 Incapable
##   trust:    how much paint they need and how fast they decide.    2 Blind trust | 1 Thoughtful | 0 Needs a whole bucket
##   patience: how soon they start improvising when lost.            2 Explorer | 1 Lost fast | 0 No paint, no way
## Rule: a tester has at most ONE trait at 0. The operator only sees stars, never the names of the traits' values.
## `outlet` (a parody of a games site/magazine) and `intro` (a hint at their archetype) show on the round card.
const ROSTER := {
	"Rhea Spawn": {jump = 1, trust = 1, patience = 1,
		outlet = "IBN",
		intro = "Reviews everything, scores everything 7/10. Follows the paint, takes a breath before each jump. Proudly average."},
	"Polly Gonn": {jump = 1, trust = 2, patience = 1,
		outlet = "Polygone",
		intro = "If it's yellow, she's on it. Has never once questioned a splat, a quest marker, or a loading screen tip."},
	"Al Gorithm": {jump = 1, trust = 0, patience = 1,
		outlet = "GameFAKs",
		intro = "Writes 40-page walkthroughs. A drop of paint is a rumour; he wants a puddle before he commits to anything."},
	"Bea Tah": {jump = 1, trust = 1, patience = 2,
		outlet = "Early Axess Weekly",
		intro = "Has played every beta since 2009. Gets bored fast and goes looking for 'secrets' (ledges)."},
	"Moe Cap": {jump = 0, trust = 1, patience = 1,
		outlet = "Game Misinformer",
		intro = "Brilliant writer, 30 years in the industry. Nobody has ever told him he can't jump."},
	"Liv Elup": {jump = 2, trust = 1, patience = 0,
		outlet = "Rock Paper Shortcut",
		intro = "Speedrun world record holder. Pixel-perfect jumps, but strictly by the book: no paint, no jump."},
	"Cass Cene": {jump = 1, trust = 1, patience = 0,
		outlet = "Cinematic Universe Digest",
		intro = "Believes games should be movies. Will stand perfectly still until something tells her where to go."},
	"Lou Tbox": {jump = 2, trust = 1, patience = 2,
		outlet = "Kotakoo",
		intro = "Opens every chest, climbs every wall, reads every note. Lands anything, painted or not."},
	"Max Levell": {jump = 2, trust = 0, patience = 1,
		outlet = "Eurogamble",
		intro = "Only plays on Nightmare difficulty. Flawless jumper, once there's enough paint to convince him it's intended."},
	"Frank Rate": {jump = 2, trust = 2, patience = 2,
		outlet = "PC Gamerish (240 FPS edition)",
		intro = "Hardcore. Needs nothing from you and will mention it in the review."},
	"Dee Sync": {jump = 0, trust = 2, patience = 1,
		outlet = "Twitchy (streamer, 14 viewers)",
		intro = "Trusts chat, trusts paint, trusts everything. Jumping is another story."},
	"Sven Tory": {jump = 1, trust = 0, patience = 2,
		outlet = "Destructoad",
		intro = "Loot goblin. Wanders off to explore everything, but trusts nothing smaller than a bucket of paint."},
	"Hugh Dee": {jump = 1, trust = 2, patience = 0,
		outlet = "The Casual Observer",
		intro = "Plays on his phone during cutscenes. Follows yellow instantly, won't move an inch without it."},
	"Mike Rotransaction": {jump = 0, trust = 1, patience = 2,
		outlet = "Freemium Times",
		intro = "Would pay to skip any jump. Gets bored and tries them anyway. It never works."},
}

const TRAIT_LABELS := {jump = "Jump precision", trust = "Trust", patience = "Patience"}
const TRAIT_VALUES := {  ## For the docs/editor only. The game shows stars.
	jump = ["Incapable", "Hit or miss", "Precise"],
	trust = ["Needs a whole bucket", "Thoughtful", "Blind trust"],
	patience = ["No paint, no way", "Lost fast", "Explorer"],
}
const DEFAULT_TESTER := "Rhea Spawn"


## Results quotes by stars. For 2-4 stars there are separate lines depending on what cost the
## stars: too much paint ("paint") or missed coins ("coins").
const QUOTES := {
	5: [
		"I didn't even notice the paint. It just felt... right.",
		"Ten out of ten. Very intuitive. I'm clearly a natural.",
		"Was there yellow paint? I just followed my instincts.",
		"Finally, a game that respects my intelligence.",
	],
	4: {
		paint = [
			"Pretty smooth. A little more yellow than I'd like.",
			"Good level. The paint was only slightly patronising.",
		],
		coins = [
			"Great flow! I'm sure I didn't miss anything important.",
			"Loved it. Were there collectibles? Nobody painted them.",
		],
	},
	3: {
		paint = [
			"It was fine. Felt a bit like a guided tour.",
			"I'd play it again. With sunglasses.",
		],
		coins = [
			"Solid, but I could hear coins I never found.",
			"Three stars. Somewhere out there, my coins are lonely.",
		],
	},
	2: {
		paint = [
			"So much yellow I thought I was inside a banana.",
			"Did the designer think I was a toddler?",
		],
		coins = [
			"I saw the flag. I saw nothing else. Not even a coin.",
			"Zero treasure. Zero joy. The paint was nice, I guess.",
		],
	},
	1: [
		"My eyes hurt. Everything was yellow. EVERYTHING.",
		"I've seen less paint at a hardware store.",
		"Please let me play something without handholding. Or with fewer hands.",
		"I collected nothing and saw everything. In yellow.",
	],
}


## Said at the end when hotfixes (painting during the playtest) cost the most stars.
## Key 1 = 1-3 hotfixes, 2 = 4 or more.
const HOTFIX_QUOTES := {
	1: [
		"The level changed while I was playing it. Is that a feature?",
		"Day-one patch? More like mid-run patch.",
		"I'm pretty sure that yellow wasn't there a second ago.",
		"Fun level. Slightly haunted. Paint kept appearing.",
	],
	2: [
		"The floor kept rewriting itself. I've played early access games more stable than this.",
		"Was someone painting behind me the whole time?",
		"I didn't play the level. The level played me.",
		"Every time I got stuck, yellow appeared. I don't feel like I earned anything.",
	],
}


static func profile(tester: String) -> Dictionary:
	return ROSTER.get(tester, ROSTER[DEFAULT_TESTER])


## "Rhea Spawn, IBN"
static func byline(tester: String) -> String:
	var p := profile(tester)
	return "%s, %s" % [tester, p.get("outlet", "freelance")]


static func intro(tester: String) -> String:
	return profile(tester).get("intro", "")


static func stars(value: int) -> String:
	return "★".repeat(value + 1) + "☆".repeat(2 - value)


## "Jump precision ★★☆   Trust ★★★   Patience ★☆☆"
static func trait_line(tester: String) -> String:
	var p := profile(tester)
	var parts: PackedStringArray = []
	for t in ["jump", "trust", "patience"]:
		parts.append("%s %s" % [TRAIT_LABELS[t], stars(p[t])])
	return "   ".join(parts)


## Pick a quote for a result from game.gd's score() (stars, paint_penalty, coin_penalty).
static func quote_for(result: Dictionary) -> String:
	var hotfix_penalty: int = result.get("hotfix_penalty", 0)
	if hotfix_penalty > 0 and hotfix_penalty >= result.paint_penalty and hotfix_penalty >= result.coin_penalty:
		return HOTFIX_QUOTES[hotfix_penalty].pick_random()
	var lines = QUOTES[result.stars]
	if lines is Dictionary:
		lines = lines.paint if result.paint_penalty >= result.coin_penalty else lines.coins
	return lines.pick_random()
