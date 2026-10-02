class_name FocusGroup
## The focus testers (each playtest gets a random one) and what they say about your level.

const TESTERS := [
	"Rhea Spawn",
	"Lou Tbox",
	"Polly Gonn",
	"Frank Rate",
	"Al Gorithm",
	"Mike Rotransaction",
	"Cass Cene",
	"Dee Sync",
	"Max Levell",
	"Sven Tory",
	"Liv Elup",
	"Hugh Dee",
	"Moe Cap",
	"Bea Tah",
]

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


static func random_tester() -> String:
	return TESTERS.pick_random()


## Pick a quote for a result from game.gd's score() (stars, paint_penalty, coin_penalty).
static func quote_for(result: Dictionary) -> String:
	var hotfix_penalty: int = result.get("hotfix_penalty", 0)
	if hotfix_penalty > 0 and hotfix_penalty >= result.paint_penalty and hotfix_penalty >= result.coin_penalty:
		return HOTFIX_QUOTES[hotfix_penalty].pick_random()
	var lines = QUOTES[result.stars]
	if lines is Dictionary:
		lines = lines.paint if result.paint_penalty >= result.coin_penalty else lines.coins
	return lines.pick_random()
