class_name FocusGroup
## The focus testers (each playtest gets a random one) and what they say about your level.

## The roster. Each tester has three traits, 0 (lowest) to 2. 1 is the default playtester.
##   jump:     "Jumping": reach of EVERY jump (painted too) + how well improvised ones land.
##             2 Parkour (7 m, 3.2 m up) | 1 Average (5.5 m, 2.5 m up) | 0 Short legs (4.5 m, 2.1 m up, improvised jumps land 50%)
##   trust:    how much paint it takes to convince them to follow it.
##             2 Blind trust (believes paint instantly, nearest yellow first, jumps at paint slightly out of reach)
##             | 1 Thoughtful | 0 Skeptic (believes a lone splat only after ~5 s of doubting; 2 splats ~1.3 s, 3 ≈ normal)
##   patience: "Exploration" on the card: how much they look around when lost, and if/when they improvise.
##             2 Explorer (wanders far and long, improvises late, presses/smashes unpainted things, gambles for coins)
##             | 1 Curious | 0 No paint, no way (short 1.5-3 m look-around walks, never improvises)
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
		intro = "Has played every beta since 2009. Checks every corner for 'secrets' before trying anything risky."},
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
		outlet = "PC Gamerish: 240 FPS Edition",
		intro = "Hardcore. Needs nothing from you and will mention it in the review."},
	"Dee Sync": {jump = 0, trust = 2, patience = 1,
		outlet = "Twitchy (streamer, 14 viewers)",
		intro = "Trusts chat, trusts paint, trusts everything. Jumping is another story."},
	"Sven Tory": {jump = 1, trust = 0, patience = 2,
		outlet = "Destructoad",
		intro = "Loot goblin. Wanders off to explore everything, but trusts nothing smaller than a bucket of paint."},
	"David Goodenough": {jump = 1, trust = 2, patience = 0,
		outlet = "The Casual Observer",
		intro = "Plays on his phone during cutscenes. Follows yellow instantly, won't move an inch without it."},
	"Mike Rotransaction": {jump = 0, trust = 1, patience = 2,
		outlet = "Freemium Times",
		intro = "Would pay to skip any jump. Explores every corner first, then tries one anyway. It rarely works."},
}

const TRAIT_LABELS := {jump = "Jumping", trust = "Trust", patience = "Exploration"}
const TRAIT_VALUES := {  ## For the docs/editor only. The game shows stars.
	jump = ["Short legs", "Average", "Parkour"],  ## Reach (all jumps) + how well improvised jumps land.
	trust = ["Skeptic", "Thoughtful", "Blind trust"],
	patience = ["No paint, no way", "Curious", "Explorer"],
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


## Said at the end when the tester spent half the session or more lost (and hotfixes didn't cost more).
const LOST_QUOTES := [
	"I spent half the session staring at a wall. Great wall, though.",
	"Was I supposed to be lost that long? Is that the 'exploration' part?",
	"I've seen more of this level's corners than its paint.",
	"At some point I just started living there. Lovely neighbourhood.",
	"Lovely level. I would know, I walked around it for ages.",
]


## Said at the end when hotfixes (painting during the playtest) cost the most stars.
## Key 1 = 1-3 hotfixes, 2 = 4 or more.
const HOTFIX_QUOTES := {
	1: [
		"The level changed while I was playing it. Is that a feature?",
		"Day-one patch? More like mid-run patch.",
		"I'm pretty sure that splat wasn't there a second ago.",
		"Fun level. Slightly haunted. Paint kept appearing.",
	],
	2: [
		"The floor kept rewriting itself. I've played early access games more stable than this.",
		"Was someone painting behind me the whole time?",
		"I didn't play the level. The level played me.",
		"Every time I got stuck, a splat appeared. I don't feel like I earned anything.",
	],
}


static func profile(tester: String) -> Dictionary:
	if not ROSTER.has(tester):
		# A renamed tester still used by a level would silently get the default tester's traits.
		push_warning("FocusGroup: no tester named \"%s\" in ROSTER (renamed?). Using %s's traits." % [tester, DEFAULT_TESTER])
	return ROSTER.get(tester, ROSTER[DEFAULT_TESTER])


## "Rhea Spawn, IBN"
static func byline(tester: String) -> String:
	var p := profile(tester)
	return "%s, %s" % [tester, p.get("outlet", "freelance")]


static func intro(tester: String) -> String:
	return profile(tester).get("intro", "")


static func stars(value: int) -> String:
	return "★".repeat(value + 1) + "☆".repeat(2 - value)


## "Jumping ★★☆   Trust ★★★   Exploration ★☆☆"
static func trait_line(tester: String) -> String:
	var p := profile(tester)
	var parts: PackedStringArray = []
	for t in ["jump", "trust", "patience"]:
		parts.append("%s %s" % [TRAIT_LABELS[t], stars(p[t])])
	return "   ".join(parts)


## Pick a quote for a result from game.gd's score() (stars, paint_penalty, coin_penalty).
## `lost_ratio` = time lost / session time (logged, not scored): at 0.5+ the tester talks about being lost.
static func quote_for(result: Dictionary, lost_ratio := 0.0) -> String:
	var hotfix_penalty: int = result.get("hotfix_penalty", 0)
	if hotfix_penalty > 0 and hotfix_penalty >= result.paint_penalty and hotfix_penalty >= result.coin_penalty:
		return HOTFIX_QUOTES[hotfix_penalty].pick_random()
	if lost_ratio >= 0.5:
		return LOST_QUOTES.pick_random()
	var lines = QUOTES[result.stars]
	if lines is Dictionary:
		lines = lines.paint if result.paint_penalty >= result.coin_penalty else lines.coins
	return lines.pick_random()
