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


static func random_tester() -> String:
	return TESTERS.pick_random()


## Pick a quote for a result from game.gd's score() (stars, paint_penalty, coin_penalty).
static func quote_for(result: Dictionary) -> String:
	var lines = QUOTES[result.stars]
	if lines is Dictionary:
		lines = lines.paint if result.paint_penalty >= result.coin_penalty else lines.coins
	return lines.pick_random()
