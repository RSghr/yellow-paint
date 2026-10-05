class_name Runner
extends CharacterBody3D
## The "player": an AI playtester that is just smart enough to get lost.
##
## What it can do on its own:
##   - walk around on the ground it's standing on, looking around as it goes
##   - spot the goal flag if it's in view, and remember it
##   - risk an unpainted jump toward the flag when it can see a landing (badly aimed)
##   - when it's been lost for a while, jump at ANY ledge it can see (a gamble that often fails)
## What it needs yellow paint for:
##   - any other jump. It won't trust a ledge that isn't painted.
##
## It only knows about paint it has actually SEEN. A lone splat can be missed;
## a big blob of paint gets noticed fast and is trusted more (faster, no hesitation).
##
## Interactables:
##   - coins: spotted without paint (shiny!), but it only walks to them
##   - buttons: pressed only when painted
##   - breakables: paint on the SIDE = smash it, paint on TOP = stand on it.
##     Both? It goes with whichever has more paint, and guesses on a tie.
##   - moving platforms (Door with is_platform): painted top = a landing. It stands still while one
##     moves under its feet (RIDING), and won't use a spot on one until it has stopped.

signal reached_goal
signal died
signal said(text: String)

enum State { WAITING, SCANNING, WALKING, HESITATING, JUMPING, INTERACTING, CONFUSED, CELEBRATING, DEAD, RIDING }

const GRAVITY := 9.8
const FEET_OFFSET := 0.9  ## Body origin is this far above the feet.
const PERCEPTION_INTERVAL := 0.1

@export_group("Movement")
@export var walk_speed := 3.5  ## Speed toward low-trust paint or while wandering.
@export var confident_speed := 5.5  ## Speed toward well-painted spots.
@export var max_jump_distance := 5.5  ## Horizontal reach of a jump.
@export var max_jump_up := 2.5
@export var max_drop := 8.0  ## Will drop this far onto PAINT (it trusts paint).
@export var max_unpainted_drop := 2.6  ## Without paint it's not THAT stupid (will hop off a plank wall, not into the pit).
@export var jump_apex := 0.9
@export var takeoff_margin := 0.6  ## Take-off spots stay this far from the edge (its body is 0.8m wide).

@export_group("Perception")
@export var view_distance := 22.0
@export var view_angle_deg := 100.0
@export var notice_rate := 1.6  ## Higher = spots paint faster. Lone splats at 5m take about a second of looking.
@export var trust_radius := 1.3  ## Splats within this radius pile up into one spot's trust.
@export var hotfix_trust := 5  ## A hotfix splat is trusted like a big blob: no hesitation, confident walk.

@export_group("Personality")
@export var scan_time := 1.8  ## A full look-around, left to right.
@export var hesitation_per_doubt := 0.9  ## Pause before jumping to a spot with only 1 splat.
@export var leap_error := 0.7  ## Unpainted jumps are guesses: landing error in metres.
@export var wander_limit := 3  ## Wanders on its own this many times before giving up.
@export var wander_range := 5.0  ## Max distance of one wander walk.
@export var patience := 8.0  ## Seconds without progress (after a full look-around) before it jumps at things unpainted.
@export_range(0.0, 1.0, 0.05) var desperate_success_chance := 0.65  ## Chance (0-1) that an unpainted desperate jump lands. A miss falls well short.
@export var setback_drop := 1.5  ## Landing this far below the last trusted spot (by accident) counts as a fall: retrace.
@export var coin_detour := 16.0  ## Will go out of its way this far (path cost) for a coin. A painted jump costs ~10.

## Each focus tester (FocusGroup.ROSTER) has three traits from 0 (lowest) to 2; 1 is the default.
## apply_profile() copies the values below into the fields above. Index = trait level [0, 1, 2].
@export_group("Traits")
@export_subgroup("Jumping (Short legs / Average / Parkour)")
@export var reach_by_level: Array[float] = [4.5, 5.5, 7.0]  ## max_jump_distance: how far ANY jump goes (painted ones too).
@export var reach_up_by_level: Array[float] = [2.1, 2.5, 3.2]  ## max_jump_up: how high a ledge it can jump onto.
@export var jump_success_by_level: Array[float] = [0.5, 0.65, 0.95]  ## desperate_success_chance: odds that an improvised jump lands (Short legs: leaps of faith too).
@export var leap_error_by_level: Array[float] = [0.7, 0.7, 0.25]  ## Leap-of-faith aim error in metres.
@export_subgroup("Trust (Skeptic / Thoughtful / Blind trust)")
## Skeptic: seconds before it believes a spot with ONE splat it has seen (n splats: this / n², so 3 splats ≈ 0.5 s,
## about normal). Until then it won't use the spot: it stares at it, doubts, and may end up improvising. 0 = instant.
@export var conviction_time_by_level: Array[float] = [5.0, 0.0, 0.0]
## Blind trust: heads for the NEAREST yellow (dead end or not), and will jump at paint up to this much further
## than it can actually reach (and fall short). 0 = never.
@export var overreach_by_level: Array[float] = [0.0, 0.0, 1.5]
@export var trust_bonus_by_level: Array[int] = [0, 0, 2]  ## Added to every spot's trust (3+ = no hesitation, confident walk).
@export var notice_rate_by_level: Array[float] = [1.2, 1.6, 2.4]
@export var scan_time_by_level: Array[float] = [2.4, 1.8, 1.1]  ## How long its look-arounds take.
@export var hesitation_by_level: Array[float] = [1.3, 0.9, 0.5]  ## hesitation_per_doubt.
@export_subgroup("Exploration (No paint, no way / Curious / Explorer)")  # "patience" in the code and roster.
@export var patience_by_level: Array[float] = [-1.0, 8.0, 16.0]  ## Seconds lost (after its wanders) before improvising. -1 = never improvises (no desperate jumps, no leaps of faith).
@export var wander_limit_by_level: Array[int] = [3, 3, 8]  ## Look-around walks before it gives up and waits.
@export var wander_range_by_level: Array[float] = [3.0, 5.0, 9.0]  ## How far each look-around walk can go (metres).
@export var wander_min_by_level: Array[float] = [1.5, 2.0, 2.0]  ## Shortest look-around walk (metres).
## True = curious: presses unpainted buttons and smashes unpainted planks it sees, and gambles on a jump for a coin.
@export var curious_by_level: Array[bool] = [false, false, true]

var conviction_time := 0.0  ## See conviction_time_by_level.
var short_legs := false  ## Jumping 1★: leaps of faith only land desperate_success_chance of the time too.
var wander_min := 2.0
var overreach := 0.0  ## See overreach_by_level. > 0 also means "Blind trust": nearest yellow first.
var trust_bonus := 0
var improvises := true  ## False = "No paint, no way": never jumps anywhere unpainted.
var curious := false  ## Explorer: tries unpainted buttons/planks and jumps for coins.
var profile := {jump = 1, trust = 1, patience = 1}

@export_group("Speech")
@export var speech_pixel_size := 0.004  ## Text size up close (world units per font pixel).
@export var speech_grow_distance := 6.0  ## Beyond this camera distance the text grows to stay readable...
@export var speech_max_scale := 4.0  ## ...up to this many times its normal size.

@export var death_height := -2.5
@export var debug_view := false:  ## Show what the AI knows (V in game).
	set(value):
		debug_view = value
		if _debug_mesh:
			_debug_mesh.visible = value
		if _reach_mesh:
			_reach_mesh.visible = value
			_reach_label.visible = value

var state := State.WAITING
var session_time := 0.0  ## Seconds since the playtest started (stops at the flag). Logged, not scored.
var time_lost := 0.0  ## Part of it spent lost: confused, wandering, or winding up an unpainted gamble.
var failed_jumps := 0  ## Jumps that didn't land where it aimed (this attempt). Stats for the patch notes.
var hotfixes_seen := 0  ## Hotfix splats it noticed (this attempt).
var tester_name := "Playtester"  ## Set by the Game scene via apply_profile().

var _path: Array[Dictionary] = []  ## Steps: {pos, jump, trust, leap}
var _spawn: Transform3D
var _paint: PaintManager
var _goal: Node3D
var _goal_known := false

# Perception memory
var _attention := {}  ## mark instance id -> how much it has looked at it (1.0 = noticed)
var _noticed_at := {}  ## mark instance id -> _clock when it noticed it (Skeptic conviction).
var _clock := 0.0  ## Playtest clock (frozen while WAITING).
var _seen := {}  ## mark instance id -> true
var _visited: Array[Vector3] = []  ## Paint spots it has stood on.
var _explored: Array[Vector3] = []  ## Places it wandered to (for picking new directions).
var _furthest := Vector3.INF  ## The most recent NEW paint spot it reached: its best progress so far.
var _retrace_to := Vector3.INF  ## After a fall: head back to this spot before exploring again.
var _failed_jump := {}  ## The jump that went wrong last ({from, to, improvised}): retrace leads back to it.
var _retry_jump := {}  ## Back where an improvised jump failed: try that same jump again.
## Every place it got to, in order: paint spots it reached and where its unpainted jumps landed.
## After a fall it retraces this trail back to where it fell from (painted links walked/jumped as usual,
## unpainted ones jumped again as gambles).
var _trail: Array[Vector3] = []
var _trail_from: Array[Vector3] = []  ## For each trail stop: where the jump to it took off (INF if it walked there).
var _trail_gamble: Array[bool] = []  ## For each trail stop: that jump was unpainted (replaying it is a gamble).
var _look_back := false  ## Truly lost: heading back to the last splat it reached to look again from there.
var _looked_back_at := Vector3.INF  ## The splat it last went back to (once per splat).
var _shaken := false  ## Just fell: no unpainted leaps until it has looked around for a way back (wanders + patience).
var _detoured := false  ## Went off its route for a coin or to use something: may need to return to _furthest.
var _wanders := 0
var _home_y := 0.0  ## Height of the last trusted ground; wandering stays near it.
var _rethink := false  ## Something new was noticed; reconsider the plan at the next chance.
var _urgent := false  ## A hotfix appeared: drop whatever it's standing around doing and replan now.
var _lost_time := 0.0  ## Seconds since it last made progress (reached paint/coin/button/flag, saw new paint, a door opened).
var _last_jump_desperate := false
var _too_far_said := {}  ## Spots it already complained were out of reach (cleared on reset).
var _coin_attention := {}  ## coin instance id -> attention
var _seen_coins := {}
var _seen_things := {}  ## Explorer: unpainted buttons/breakables it has noticed (instance id -> true).
var _choices := {}  ## breakable id -> {i, t, choice}: remembered break-or-climb guesses
var _task: Dictionary = {}  ## The interaction in progress.

# Timers / animation
var _timer := 0.0
var _scan_duration := 1.0
var _perceive_timer := 0.0
var _speech_cooldown := 0.0
var _glance_timer := 0.0
var _glance_yaw := 0.0
var _body_turn := 0.0  ## Remaining yaw for turning around during a look-around.
var _look_point := Vector3.ZERO
var _look_timer := 0.0
var _gaze_timer := 2.0  ## Time until the next gaze while lost.
var _gaze_left := 0.0  ## Time left on the current gaze.
var _gaze_yaw := 0.0
var _gaze_pitch := 0.0
var _air_time := 0.0
var _jump_from := Vector3.ZERO  ## Where the current jump took off.
var _jump_flat_velocity := Vector3.ZERO  ## Kept through the jump, like holding forward.
var _stuck_time := 0.0
var _stuck_count := 0
var _last_pos := Vector3.ZERO

@onready var _speech: Label3D = $Speech
@onready var _body: Node3D = $Body
@onready var _head: Node3D = $Body/Head
@onready var _visor: Node3D = $Body/Head/Visor
@onready var _visor_rest: Vector3 = _visor.position
const VISOR_PIVOT := Vector3(0, -0.12, 0)  ## Centre of the capsule's top dome, in Head space.
var _head_pitch := 0.0  ## Up/down look (cosmetic: perception only uses the head's yaw).
var _debug_mesh: MeshInstance3D
var _reach_mesh: MeshInstance3D  ## V: the jump reach cylinder (drawn every frame by draw_reach()).
var _reach_label: Label3D


func _ready() -> void:
	_spawn = global_transform
	add_to_group("playtester")
	_home_y = feet().y
	_paint = get_tree().get_first_node_in_group("paint_manager")
	_goal = get_tree().get_first_node_in_group("goal")
	_setup_debug()
	for thing in get_tree().get_nodes_in_group("interactable"):
		if thing.has_signal("state_changed"):
			thing.state_changed.connect(_on_world_changed)
	say("Ready when you are, boss.", true)


func _process(_delta: float) -> void:
	# Speech grows with distance (up to a cap) so it stays readable from afar.
	var cam := get_viewport().get_camera_3d()
	if cam:
		var d := cam.global_position.distance_to(_speech.global_position)
		_speech.pixel_size = speech_pixel_size * clampf(d / speech_grow_distance, 1.0, speech_max_scale)


# --- Public API ------------------------------------------------------------

## Counts toward time_lost: no idea where to go (confused, wandering, looking around between wanders,
## or psyching itself up for an unpainted gamble).
func _is_lost() -> bool:
	match state:
		State.CONFUSED:
			return true
		State.WALKING:
			return not _path.is_empty() and _path[0].get("kind", "") == "wander"
		State.SCANNING:
			return _wanders > 0
		State.HESITATING:
			return not _path.is_empty() and (_path[0].get("desperate", false) or _path[0].get("leap", false))
	return false


func start() -> void:
	if state in [State.WAITING, State.CONFUSED]:
		_wanders = 0
		_lost_time = 0.0
		say(["Okay! Let's see...", "Playtest starting. Where's the yellow?", "Right. Looking for yellow.",
			"Wow, look at these textures. Okay, focus. Yellow.", "Gorgeous. Now, where's the yellow?"].pick_random(), true)
		_start_scan(scan_time)


func reset_to_spawn() -> void:
	session_time = 0.0
	time_lost = 0.0
	failed_jumps = 0
	hotfixes_seen = 0
	global_transform = _spawn
	velocity = Vector3.ZERO
	_path.clear()
	_attention.clear()
	_noticed_at.clear()
	_seen.clear()
	_visited.clear()
	_explored.clear()
	_furthest = Vector3.INF
	_retrace_to = Vector3.INF
	_shaken = false
	_failed_jump = {}
	_retry_jump = {}
	_look_back = false
	_looked_back_at = Vector3.INF
	_trail.clear()
	_trail_from.clear()
	_trail_gamble.clear()
	_detoured = false
	_coin_attention.clear()
	_seen_coins.clear()
	_seen_things.clear()
	_choices.clear()
	_task = {}
	_body.position = Vector3.ZERO
	_goal_known = false
	_wanders = 0
	_rethink = false
	_urgent = false
	_lost_time = 0.0
	_last_jump_desperate = false
	_too_far_said.clear()
	_home_y = _spawn.origin.y - FEET_OFFSET
	_head.rotation = Vector3.ZERO
	_head_pitch = 0.0
	_body.rotation = Vector3.ZERO
	_body_turn = 0.0
	_gaze_left = 0.0
	_gaze_timer = 2.0
	state = State.WAITING
	say("Ready when you are, boss.", true)


## Become one of the focus testers: name + traits (see FocusGroup.ROSTER and the "Traits" exports).
func apply_profile(tester: String, p: Dictionary) -> void:
	tester_name = tester
	profile = p
	max_jump_distance = reach_by_level[p.jump]
	max_jump_up = reach_up_by_level[p.jump]
	desperate_success_chance = jump_success_by_level[p.jump]
	leap_error = leap_error_by_level[p.jump]
	short_legs = p.jump == 0
	conviction_time = conviction_time_by_level[p.trust]
	overreach = overreach_by_level[p.trust]
	trust_bonus = trust_bonus_by_level[p.trust]
	notice_rate = notice_rate_by_level[p.trust]
	scan_time = scan_time_by_level[p.trust]
	hesitation_per_doubt = hesitation_by_level[p.trust]
	patience = patience_by_level[p.patience]
	improvises = patience >= 0.0
	wander_limit = wander_limit_by_level[p.patience]
	wander_range = wander_range_by_level[p.patience]
	wander_min = wander_min_by_level[p.patience]
	curious = curious_by_level[p.patience]


func celebrate() -> void:
	if state == State.DEAD:
		return
	state = State.CELEBRATING
	_path.clear()
	say(["I did it! All by myself!", "I did it! And the sunset behind the flag... I'm tearing up.",
		"Made it! Can I go back and look at the scenery?"].pick_random(), true)
	reached_goal.emit()


func feet() -> Vector3:
	return global_position - Vector3.UP * FEET_OFFSET


## The testers see the real HYPERION LEGENDS (full textures, ray tracing...); only the operator's
## workstation renders grey boxes. They comment on it now and then.
const ADMIRE := [
	"Look at the moss on this ledge. You can see every strand.",
	"Is that real-time ray tracing on the puddles?",
	"The lighting in here... I need a minute.",
	"Someone hand-sculpted every brick. I can tell.",
	"The skybox alone is worth the price.",
	"These textures are so crisp I can read the graffiti.",
	"Is that a waterfall? It's GORGEOUS.",
	"I can see my reflection in the marble. Wow.",
	"The volumetric fog! The god rays!",
	"Every leaf is moving. Every single leaf.",
]
@export_range(0.0, 1.0) var admire_chance := 0.12  ## Chance to comment on the (real) graphics after a look-around.


## Gazes: while lost (wandering, looking around between wanders, confused) it stares at the scenery now
## and then, at its feet, up at the walls and sky, or at some random spot, and sometimes says what it sees.
## Purely cosmetic: perception ignores head pitch, and the look-around / confused timers pause during a gaze,
## so it still sweeps as much as before. It just takes longer, and that time counts as lost.
const GAZE_LINES := {
	down = [
		"Look at the cracks in these tiles. Each one is different.",
		"Is that... a tiny beetle? They modelled a BEETLE.",
		"The puddle reflects the clouds. Moving clouds.",
		"Even the gravel has normal maps.",
		"Hand-placed pebbles. Thousands of them.",
		"My shadow has soft edges. SOFT EDGES.",
	],
	up = [
		"The clouds are volumetric. I could stare at them all day.",
		"Look at the light coming through those arches.",
		"Birds! Flocking birds! With individual feathers!",
		"The ceiling has frescoes. Someone painted a ceiling.",
		"Is that a second sun? Lore.",
	],
	spot = [
		"Wait, look at that statue over there.",
		"Ooh. What's that shiny thing?",
		"Look at the ivy on that wall. Physically simulated ivy.",
		"That banner is waving in the wind. Real cloth physics.",
		"I want to live in that little house over there.",
	],
}
@export var gaze_interval := Vector2(2.5, 5.5)  ## Seconds between gazes while lost (random in this range).
@export var gaze_duration := Vector2(1.2, 2.4)  ## How long each gaze lasts.
@export_range(0.0, 1.0) var gaze_line_chance := 0.35  ## Chance it says what it's looking at.


## A remark about how beautiful the game looks (from the tester's point of view).
func admire(chance := 1.0) -> void:
	if randf() < chance:
		say(ADMIRE.pick_random())


func say(text: String, force := false) -> void:
	if not force and _speech_cooldown > 0.0:
		return
	_speech_cooldown = 1.6
	_speech.text = text
	Sfx.play("voice", 0.2, -4.0)
	said.emit(text)


func _seen_marks() -> Array[PaintMark]:
	var result: Array[PaintMark] = []
	if _paint:
		for mark in _paint.get_marks():
			if _seen.has(mark.get_instance_id()):
				result.append(mark)
	return result


## Paint spots the AI knows about and is willing to stand on: [{pos, trust, host}]
func known_spots() -> Array[Dictionary]:
	var spots: Array[Dictionary] = []
	var seen := _seen_marks()
	for mark in seen:
		if not mark.is_nav:
			continue
		if mark.follows() and mark.host.moving:
			continue  # Won't aim for a landing that's still moving.
		if is_instance_valid(mark.host) and mark.host.kind == "breakable" and _breakable_choice(mark.host, seen) == "break":
			continue  # It's going to smash this, not stand on it.
		var trust := 0
		var hot := false
		var looked := 0.0  ## Total seconds it has known each splat of this spot.
		for other in seen:
			if other.role == "nav" and other.global_position.distance_to(mark.global_position) <= trust_radius:
				trust += 1
				hot = hot or other.hotfix
				looked += _clock - _noticed_at.get(other.get_instance_id(), -INF)
		# Skeptic: conviction builds up over time, faster with more splats (n splats: conviction_time / n²).
		var conviction := 1.0
		if conviction_time > 0.0 and not hot and not _is_visited(mark.stand_point):
			conviction = clampf(looked * trust / conviction_time, 0.0, 1.0)
		trust += trust_bonus
		if hot:
			trust = maxi(trust, hotfix_trust)  # The operator stepped in mid-run: that's an order.
		spots.append({pos = mark.stand_point, trust = trust, host = mark.host, hotfix = hot,
			conviction = conviction, convinced = conviction >= 1.0})
	return spots


## Is there ground right under this point (a coin it could land next to)?
func _has_floor_under(p: Vector3) -> bool:
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 0.5, p - Vector3.UP * 1.5, 1, [get_rid()])
	var hit := space.intersect_ray(q)
	return not hit.is_empty() and hit.normal.y > 0.7


## Painted things it intends to use: [{pos (where to stand), trust, host}]
func known_tasks() -> Array[Dictionary]:
	var by_host := {}
	var seen := _seen_marks()
	for mark in seen:
		if mark.role != "interact" or not is_instance_valid(mark.host) or mark.host.is_used():
			continue
		var id := mark.host.get_instance_id()
		if not by_host.has(id):
			by_host[id] = {pos = mark.interact_point, trust = 0, host = mark.host, hotfix = false}
		by_host[id].trust += hotfix_trust if mark.hotfix else 1
		by_host[id].hotfix = by_host[id].hotfix or mark.hotfix
	var tasks: Array[Dictionary] = []
	for task in by_host.values():
		if task.host.kind == "breakable" and _breakable_choice(task.host, seen) != "break":
			continue
		tasks.append(task)
	return tasks


## Side paint says smash, top paint says climb. More paint wins; a tie is a coin flip it remembers.
func _breakable_choice(host: Node, seen: Array[PaintMark]) -> String:
	var i := 0
	var t := 0
	for mark in seen:
		if mark.host == host:
			var weight := 10 if mark.hotfix else 1  # A hotfix settles the question.
			if mark.role == "interact":
				i += weight
			elif mark.role == "nav":
				t += weight
	if i == 0:
		return "climb"
	if t == 0:
		return "break"
	if i != t:
		return "break" if i > t else "climb"
	var id := host.get_instance_id()
	var cached = _choices.get(id)
	if cached and cached.i == i and cached.t == t:
		return cached.choice
	var choice: String = ["break", "climb"].pick_random()
	_choices[id] = {i = i, t = t, choice = choice}
	say("Climb it or smash it? Make up your mind! ...%s!" % ("Smash" if choice == "break" else "Climb"), true)
	return choice


## Explorer: unpainted buttons and breakables it has noticed and could try: [{pos (where to stand), host}].
## Anything with paint on it (that it has seen) is left to the paint: a crate painted on top gets climbed, not smashed.
func known_curios() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not curious:
		return out
	var seen := _seen_marks()
	for node in get_tree().get_nodes_in_group("interactable"):
		if not _seen_things.has(node.get_instance_id()) or node.is_used():
			continue
		if seen.any(func(m): return m.host == node):
			continue
		var pos: Vector3
		if node.kind == "button":
			pos = node.interact_point(Vector3.ZERO, Vector3.ZERO)
		else:
			# The face facing it, at the point of that face closest to it (same distance as a painted side).
			var b: Basis = node.global_basis.orthonormalized()
			var local: Vector3 = b.inverse() * (feet() - node.global_position)
			var h: Vector3 = node.size * 0.5
			var on_x := absf(local.x) - h.x > absf(local.z) - h.z
			var face := Vector3(clampf(local.x, -h.x, h.x), 0, clampf(local.z, -h.z, h.z))
			var normal := Vector3.ZERO
			if on_x:
				normal.x = 1.0 if local.x >= 0.0 else -1.0
				face.x = h.x * normal.x
			else:
				normal.z = 1.0 if local.z >= 0.0 else -1.0
				face.z = h.z * normal.z
			var side: Vector3 = b * normal
			pos = node.interact_point(node.global_position + b * face, side)
		out.append({pos = pos, host = node})
	return out


func known_coins() -> Array[Coin]:
	var result: Array[Coin] = []
	for coin in get_tree().get_nodes_in_group("coin"):
		if not coin.taken and _seen_coins.has(coin.get_instance_id()):
			result.append(coin)
	return result


# --- Main loop -------------------------------------------------------------

func _physics_process(delta: float) -> void:
	_speech_cooldown -= delta
	_timer += delta
	if state != State.WAITING:
		_clock += delta
	if state not in [State.WAITING, State.CELEBRATING, State.DEAD]:
		_lost_time += delta  # Reset whenever it makes progress; wandering doesn't count.
		session_time += delta
		if _is_lost():
			time_lost += delta

	if state not in [State.DEAD, State.WAITING]:  # Before Enter it's only idling: it doesn't take in the paint yet.
		_perceive_timer += delta
		if _perceive_timer >= PERCEPTION_INTERVAL:
			if is_on_floor() and state not in [State.WAITING, State.JUMPING]:
				_mark_spots_underfoot()
			_perceive(_perceive_timer)
			_perceive_timer = 0.0
			if debug_view:
				_draw_debug()

	if state in [State.SCANNING, State.WALKING, State.HESITATING, State.CONFUSED] and _moving_floor():
		_path.clear()
		state = State.RIDING
		_timer = 0.0
		say(["Whoa, the floor's moving!", "Going up! I think?", "Free ride!", "Nobody said the floor moves."].pick_random(), true)

	if _urgent and is_on_floor() and state in [State.SCANNING, State.HESITATING, State.CONFUSED]:
		_urgent = false
		_wanders = 0
		_decide()  # No scanning, no psyching up: the operator just pointed somewhere.

	match state:
		State.WALKING:
			_process_walk(delta)
		State.JUMPING:
			_process_jump(delta)
		State.SCANNING:
			_idle_physics(delta)
			if _timer >= _scan_duration:
				_decide()
		State.HESITATING:
			_idle_physics(delta)
			if _rethink and _path[0].get("desperate", false):
				say(["Oh! Yellow! Never mind.", "Wait, there's paint now?"].pick_random(), true)
				_decide()  # Paint appeared while it was psyching itself up: use that instead.
			elif _timer >= _scan_duration:
				_jump_to(_path[0])
		State.INTERACTING:
			_idle_physics(delta)
			_process_interact()
		State.RIDING:
			_idle_physics(delta)
			if not _moving_floor() and _timer > 0.2:
				_lost_time = 0.0  # Getting somewhere new counts as progress.
				_home_y = feet().y
				_start_scan(scan_time * 0.5)  # New view from up here: look around.
		State.CONFUSED:
			_idle_physics(delta)
			if _rethink or _timer >= 4.0:
				_rethink = false
				_wanders = 0
				_start_scan(scan_time)
		_:
			_idle_physics(delta)

	_update_head(delta)

	if state != State.DEAD and global_position.y < death_height:
		_die()


## The moving platform it's standing on, if it's moving right now.
func _moving_floor() -> Node:
	if not is_on_floor():
		return null
	var q := PhysicsRayQueryParameters3D.create(feet() + Vector3.UP * 0.2, feet() - Vector3.UP * 0.4, 1, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit and hit.collider.is_in_group("mover") and hit.collider.moving:
		return hit.collider
	return null


func _idle_physics(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0, 20 * delta)
	velocity.z = move_toward(velocity.z, 0, 20 * delta)
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	move_and_slide()
	if not is_on_floor() and velocity.y < -2.0 and state in [State.SCANNING, State.HESITATING, State.CONFUSED, State.INTERACTING]:
		# Slipped off an edge while standing around (or winding up a jump): it's a fall, not a plan.
		_path.clear()
		_jump_flat_velocity = Vector3(velocity.x, 0, velocity.z)
		state = State.JUMPING
		_air_time = 0.2


func _process_walk(delta: float) -> void:
	if _path.is_empty():
		_start_scan(scan_time * 0.6)
		return
	if _rethink:
		_rethink = false
		_decide()
		return
	var step: Dictionary = _path[0]
	var to_target: Vector3 = step.pos - feet()
	to_target.y = 0
	if to_target.length() < 0.25:
		_path.pop_front()
		_arrive(step)
		return

	var speed := confident_speed if step.trust >= 3 else walk_speed
	if _gaze_left > 0.0:
		speed *= 0.3  # Ambles while staring at the scenery.
	var dir := to_target.normalized()
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	velocity.y = 0.0 if is_on_floor() else velocity.y - GRAVITY * delta
	_face(dir)
	move_and_slide()

	if not is_on_floor() and velocity.y < -2.0:  # Walked off something.
		_jump_flat_velocity = Vector3.ZERO
		state = State.JUMPING
		_air_time = 0.2
	_stuck_time = _stuck_time + delta if global_position.distance_to(_last_pos) < speed * delta * 0.3 else 0.0
	_last_pos = global_position
	if _stuck_time > 1.0 and _at(step.pos):
		# Blocked right next to where it was going (a splat against a wall or pillar): close enough.
		_stuck_time = 0.0
		_path.pop_front()
		_arrive(step)
		return
	if _stuck_time > 1.0:
		_stuck_time = 0.0
		_stuck_count += 1
		say("Something invisible is in my way.")
		if _stuck_count >= 2:
			_stuck_count = 0
			_wanders = 0
			_wander()  # Shuffle sideways and try again from somewhere else.
		else:
			_start_scan(scan_time * 0.5)


func _process_jump(delta: float) -> void:
	velocity.y -= GRAVITY * delta
	# Keep pushing forward: brushing a ledge's face shouldn't cancel the whole jump.
	velocity.x = _jump_flat_velocity.x
	velocity.z = _jump_flat_velocity.z
	var before := global_position
	move_and_slide()
	_air_time += delta
	# Wedged on something mid-air for too long: give up on this jump.
	if _air_time > 2.0 and global_position.distance_to(before) < 0.001:
		velocity = Vector3.ZERO
		_path.clear()
		say("Ow. That wasn't a jump.")
		_start_scan(scan_time * 0.5)
		return
	if _air_time > 0.1 and is_on_floor():
		velocity = Vector3.ZERO
		Sfx.play("land")
		if not _path.is_empty():
			var step: Dictionary = _path[0]
			var off: Vector3 = step.pos - feet()
			off.y = 0
			_path.pop_front()
			# Made it = landed where it aimed: close in plan AND at about that height (not 8 m under a coin).
			if off.length() < 1.2 and feet().y > step.pos.y - 0.8:
				_home_y = feet().y  # Made it (painted or not): this is the floor it's on now.
				if step.jump:
					# Remember the way and the take-off, so it can make this jump again after a fall.
					var painted: bool = step.get("paint", false)
					_trail_add(step.pos if painted else feet(), _jump_from, not painted)
				_arrive(step)
				return
			if step.get("jump", false):
				failed_jumps += 1
				_failed_jump = {from = _jump_from, to = step.pos, improvised = step.leap}
			# Any landing that isn't where it meant to go might be a fall.
			if not _check_setback():
				_home_y = feet().y
				if step.get("jump", false):
					_trail_add(feet(), _jump_from, true)
				if step.leap:
					say(["Made it! ...mostly.", "Nailed it. Sort of."].pick_random(), true)
		elif not _check_setback():  # Fell off something without meaning to?
			_home_y = feet().y
		_start_scan(scan_time * 0.5)


## Landed somewhere it didn't mean to, well below its last trusted spot: that's a fall.
## It heads back to the furthest paint it had reached, using the spots it knows as stepping stones.
func _check_setback() -> bool:
	if feet().y > _home_y - setback_drop:
		return false
	_home_y = feet().y  # It's on a new floor now: wander here, not on the floor it fell from.
	_wanders = 0
	_shaken = true
	_lost_time = 0.0  # A full patience period on this floor before it improvises again.
	if not _trail.is_empty():
		_retrace_to = _trail.back()  # Where it was when it fell.
		say(["Ow. Okay, I know the way back up.", "Fell. Let's retrace my steps.", "That was a shortcut. Down."].pick_random(), true)
	return true


func _process_interact() -> void:
	var host = _task.get("host")
	if not is_instance_valid(host) or host.is_used():
		_body.position = Vector3.ZERO
		_start_scan(scan_time * 0.5)
		return
	var to_host: Vector3 = host.global_position - global_position
	to_host.y = 0
	if to_host.length() > 0.01:
		_face(to_host.normalized())
	# Little lunges: punching planks, or poking a button.
	var lunge := absf(sin(_timer * (12.0 if host.kind == "breakable" else 5.0))) * 0.15
	_body.position = to_host.normalized() * lunge
	if _timer >= _scan_duration:
		_body.position = Vector3.ZERO
		host.interact(self)
		_task = {}
		_start_scan(scan_time * 0.5)


func _start_interacting(step: Dictionary) -> void:
	_task = step
	_detoured = true
	state = State.INTERACTING
	_timer = 0.0
	_scan_duration = step.host.interact_duration()
	if step.get("kind", "") == "curio":
		if step.host.kind == "button":
			say(["No paint, but a button is a button. *boop*", "Let's see what this one does.", "Pressing it. For science."].pick_random(), true)
		else:
			say(["These planks look smashable. HYAAA!", "Nobody said NOT to smash it.", "Shortcut? Shortcut."].pick_random(), true)
	elif step.host.kind == "button":
		say(["Yellow button. I know this one.", "*boop*", "Pressing the obvious button."].pick_random(), true)
	else:
		say(["Yellow means smash!", "HYAAA!", "Sorry, planks."].pick_random(), true)


func _on_world_changed() -> void:
	# A door opened or something broke: what it can reach has changed.
	_rethink = true
	_lost_time = 0.0
	if state == State.CONFUSED:
		_timer = 4.0


## Reached a step of the path.
func _arrive(step: Dictionary) -> void:
	_stuck_count = 0
	if step.get("kind", "") in ["task", "curio", "coin", "paint", "goal", "trail"]:
		_lost_time = 0.0
	if step.get("kind", "") == "trail":
		_check_retrace_done(step.pos)
	if step.get("kind", "") in ["task", "curio"]:
		_start_interacting(step)
		return
	if step.get("kind", "") == "coin":
		_detoured = true
		say(["Shiny!", "Ooh, a coin!", "Coin get."].pick_random(), true)
	if step.get("paint", false):
		_record_visit(step.pos)
		_wanders = 0
		_home_y = feet().y
		if _look_back and step.pos.distance_to(_furthest) < 1.0 and _path.is_empty():
			_careful_look()  # Back at the last splat: look again, carefully.
			return
	if _path.is_empty():
		_start_scan(scan_time * 0.7)  # End of what it knew: look around.
	elif step.trust <= 1 or _rethink:
		_rethink = false
		_start_scan(scan_time * 0.45)  # Unsure: quick look before going on.
	else:
		_advance()


func _advance() -> void:
	if _path.is_empty():
		_start_scan(scan_time * 0.6)
		return
	var step: Dictionary = _path[0]
	if step.jump:
		var doubt := maxf(0.0, 3.0 - step.trust) / 2.0  # trust 1 -> 1.0, 2 -> 0.5, 3+ -> 0
		if step.get("desperate", false):
			doubt = 1.6
			Sfx.play("desperate", 0.0)
			if step.get("coin_gamble", false):
				say(["No paint? That coin is worth it.", "I can make that. Probably. COIN!", "Money first, safety second."].pick_random(), true)
			elif short_legs:
				say(["I've never made a jump in my life. Here goes!", "How hard can jumping be?",
					"I don't really do jumps. But okay!"].pick_random(), true)
			else:
				say(["Fine. I'll do it myself.", "No yellow anywhere. Improvising!", "Nobody's painting? I'm jumping.",
					"This is what happens when you don't paint, boss."].pick_random(), true)
		elif step.get("overreach", false):
			say(["That's far. But it's YELLOW!", "If it's painted, I can reach it. Right?", "Yellow never lies. JUMPING!"].pick_random(), true)
		elif step.leap:
			doubt = 1.6
			say(["No yellow... but the flag is RIGHT THERE.", "Unpainted jump. Here goes nothing.", "If I die, put that in the report."].pick_random(), true)
		elif step.trust <= 1:
			say(["Is that... a bit of yellow? Okay...", "One drop of yellow. Bold.", "I guess that counts as yellow."].pick_random())
		if doubt > 0.0:
			state = State.HESITATING
			_timer = 0.0
			_scan_duration = doubt * hesitation_per_doubt * (2.0 if step.leap else 1.0)
			_look_at(step.pos, _scan_duration)
			return
		_jump_to(step)
	else:
		state = State.WALKING
		_stuck_time = 0.0
		_last_pos = global_position


func _start_scan(duration: float) -> void:
	state = State.SCANNING
	_timer = 0.0
	_scan_duration = duration
	if duration >= scan_time * 0.6:
		admire(admire_chance)  # Not a forced line: only when it has nothing more urgent to say.
	# On a proper look-around it sometimes turns to check behind itself too.
	if duration >= scan_time * 0.6 and randf() < 0.5:
		_body_turn = deg_to_rad(randf_range(100, 180)) * (1 if randf() < 0.5 else -1)


## Ballistic jump that peaks `jump_apex` above the higher end. Leaps of faith are badly aimed.
func _jump_to(step: Dictionary) -> void:
	if not is_on_floor():
		# Slipped off before taking off: no magic mid-air jump, it just falls.
		_jump_flat_velocity = Vector3(velocity.x, 0, velocity.z)
		state = State.JUMPING
		_air_time = 0.0
		return
	var from := feet()
	if step.pos.y - from.y > max_jump_up + 0.6 and not step.get("overreach", false):
		# Not where it planned to jump from (it slipped, or something moved): that's not a jump, rethink.
		_path.clear()
		_start_scan(scan_time * 0.5)
		return
	_jump_from = from
	var target: Vector3 = step.pos
	var flat := Vector3(target.x - from.x, 0, target.z - from.z)
	_last_jump_desperate = step.get("desperate", false)
	if _last_jump_desperate and flat.length() > 0.01:
		# A gamble with fixed odds: a miss falls well short, a hit lands about where it aimed.
		if randf() >= desperate_success_chance:
			target = from.lerp(target, randf_range(0.45, 0.65))
		else:
			target += flat.normalized() * randf_range(-0.2, 0.3)
	elif step.leap and flat.length() > 0.01:
		if short_legs and randf() >= desperate_success_chance:
			target = from.lerp(target, randf_range(0.45, 0.65))  # Short legs: unpainted jumps usually fall short.
		else:
			target += flat.normalized() * randf_range(-leap_error, leap_error * 0.6)
	if step.get("overreach", false):
		# Blind trust jumped at paint it can't actually reach: it gets as far as its legs allow.
		var full := target - from
		var fl := Vector3(full.x, 0, full.z)
		if fl.length() > max_jump_distance:
			target = from + fl.normalized() * max_jump_distance * 0.92 + Vector3.UP * minf(full.y, max_jump_up)
		elif full.y > max_jump_up:
			target = from + fl * 0.6 + Vector3.UP * max_jump_up * 0.5
	var d := target - from
	var h := d.y
	flat = Vector3(d.x, 0, d.z)
	var apex := maxf(h, 0.0) + jump_apex
	var vy := sqrt(2.0 * GRAVITY * apex)
	var t := (vy + sqrt(maxf(vy * vy - 2.0 * GRAVITY * h, 0.0))) / GRAVITY
	var v_flat := flat / t
	velocity = Vector3(v_flat.x, vy, v_flat.z)
	_jump_flat_velocity = v_flat
	if flat.length() > 0.01:
		_face(flat.normalized())
	state = State.JUMPING
	_air_time = 0.0
	Sfx.play("jump")
	if not step.leap and step.trust >= 3:
		say(["LOTS of yellow! Jumping!", "Yellow means jump!", "Wheee!"].pick_random())


func _die() -> void:
	if state == State.JUMPING:
		failed_jumps += 1  # Died mid-air: that jump didn't work out.
	state = State.DEAD
	_path.clear()
	Sfx.play("fall", 0.0)
	if _last_jump_desperate:
		say(["Improvising was a mistake.", "Should have waited for the yellow...", "Tell the designer I tried."].pick_random(), true)
	else:
		say(["But... it was yellow...", "The paint lied to me!", "Why was the pit yellow?!", "I trusted you!"].pick_random(), true)
	died.emit()


# --- Perception ------------------------------------------------------------

func _perceive(dt: float) -> void:
	var look := -_head.global_basis.z
	look.y = 0
	look = look.normalized()
	var space := get_world_3d().direct_space_state
	# Peers a bit forward so it can see over the edge it's standing at (but never into a wall).
	var eye := _head.global_position + look * 0.5
	var peek := space.intersect_ray(PhysicsRayQueryParameters3D.create(_head.global_position, eye, 1, [get_rid()]))
	if peek:
		eye = _head.global_position.lerp(peek.position, 0.8)
	var cos_half := cos(deg_to_rad(view_angle_deg * 0.5))

	if _paint:
		var marks := _paint.get_marks()
		for mark in marks:
			var id := mark.get_instance_id()
			if _seen.has(id):
				continue
			# Aim a little off the surface: paint on a ledge lip wraps over the edge and shows from below.
			var target := mark.global_position + (Vector3.UP * 0.3 if mark.role == "nav" else mark.normal * 0.25)
			# A hotfix grabs its attention at once, even outside its view cone (it still needs line of sight).
			if mark.hotfix and _can_see(space, eye, look, -1.0, target):
				_seen[id] = true
				_noticed_at[id] = _clock
				_on_noticed(mark, 1)
				continue
			if not _can_see(space, eye, look, cos_half, target):
				continue
			# Bigger blobs of paint are more eye-catching.
			var blob := 0
			for other in marks:
				if other.global_position.distance_to(mark.global_position) <= trust_radius:
					blob += 1
			var dist := eye.distance_to(target)
			var gain := dt * notice_rate * (0.6 + 0.4 * blob) / (1.0 + dist / 5.0) * randf_range(0.5, 1.5)
			_attention[id] = _attention.get(id, 0.0) + gain
			if _attention[id] >= 1.0:
				_seen[id] = true
				_noticed_at[id] = _clock
				_on_noticed(mark, blob)

	# Coins are shiny: no paint needed, and quick to notice.
	for coin in get_tree().get_nodes_in_group("coin"):
		var cid: int = coin.get_instance_id()
		if coin.taken or _seen_coins.has(cid):
			continue
		var ctarget: Vector3 = coin.global_position + Vector3.UP * 0.9
		if not _can_see(space, eye, look, cos_half, ctarget):
			continue
		_coin_attention[cid] = _coin_attention.get(cid, 0.0) + dt * notice_rate * 2.0 / (1.0 + eye.distance_to(ctarget) / 8.0)
		if _coin_attention[cid] >= 1.0:
			_seen_coins[cid] = true
			if state not in [State.WAITING, State.CELEBRATING]:
				_rethink = true
				_look_at(ctarget, 0.8)
				say(["Ooh, shiny!", "A coin! I want it.", "Is that... money?"].pick_random())

	# Explorer: buttons and planks are interesting even without paint.
	if curious:
		for node in get_tree().get_nodes_in_group("interactable"):
			var tid: int = node.get_instance_id()
			if _seen_things.has(tid) or not (node.get("kind") in ["button", "breakable"]) or node.is_used():
				continue
			if not _can_see(space, eye, look, cos_half, node.global_position + Vector3.UP * 0.5):
				continue
			_seen_things[tid] = true

	if _goal and not _goal_known:
		var flag := _goal.global_position + Vector3.UP * 1.5
		if _can_see(space, eye, look, cos_half, flag):
			_goal_known = true
			_rethink = true
			_look_at(flag, 1.2)
			say(["The flag! I can see the flag!", "Ooh, is that the end?", "There's the goal!"].pick_random(), true)


func _can_see(space: PhysicsDirectSpaceState3D, eye: Vector3, look: Vector3, cos_half: float, target: Vector3) -> bool:
	var to := target - eye
	var dist := to.length()
	if dist > view_distance:
		return false
	var flat := Vector3(to.x, 0, to.z)
	if dist > 1.5 and flat.normalized().dot(look) < cos_half:
		return false
	var q := PhysicsRayQueryParameters3D.create(eye, target, 1, [get_rid()])
	var hit := space.intersect_ray(q)
	return hit.is_empty() or hit.position.distance_to(target) < 0.7


func _on_noticed(mark: PaintMark, blob: int) -> void:
	if state in [State.WAITING, State.CELEBRATING]:
		return
	if mark.role in ["interact", "nav"]:
		_lost_time = 0.0
	if mark.hotfix:
		hotfixes_seen += 1
		_lost_time = 0.0
		_rethink = true
		_urgent = true
		_look_at(mark.global_position, 1.0)
		say(["Was that there a second ago?", "Hey! The level just changed!", "Is someone patching this live?",
			"Red paint? Okay, OKAY, I'm going!", "Okay, who's painting behind my back?",
			"A hotfix! Over there!"].pick_random(), true)
		return
	if mark.role == "interact":
		_rethink = true
		_look_at(mark.global_position, 0.8)
		if mark.host.kind == "button":
			say(["A yellow button! Classic.", "Yellow button. Must press."].pick_random())
		else:
			say(["Yellow planks... smash time?", "That looks breakable. And yellow."].pick_random())
	elif mark.role == "none" and is_instance_valid(mark.host) and mark.host.kind == "door":
		say(["A yellow door. Still locked, though.", "Painting the door won't open it, boss."].pick_random())
	elif mark.is_floor:
		_rethink = true
		if state in [State.SCANNING, State.WALKING, State.CONFUSED]:
			_look_at(mark.global_position, 0.8)
		if blob >= 3:
			say(["That's a LOT of yellow. Must be important.", "So. Much. Yellow."].pick_random())
		elif blob == 2:
			say(["Yellow! Over there!", "Ooh, yellow."].pick_random())
		elif conviction_time > 0.0:
			say(["One splat? Could be a coincidence.", "Is that yellow, or just... a stain?",
				"One drop of yellow. I'll think about it."].pick_random())
		elif trust_bonus > 0:
			say(["Yellow! Say no more.", "Paint! I'm in.", "If it's yellow, it's right."].pick_random())
		else:
			say(["Hm? Was that yellow?", "A tiny bit of yellow..."].pick_random())
	else:
		say(["Why is the wall yellow? Is it a door?", "Yellow wall. I'll... ignore that."].pick_random())


# --- Decision making -------------------------------------------------------

func _decide() -> void:
	_rethink = false
	# Graph nodes: me, paint spots, the flag (if seen), things to use, coins.
	var nodes: Array[Vector3] = [feet()]
	var trust: Array[int] = [99]
	var kinds: Array[String] = ["me"]
	var payload: Array = [null]
	var hot: Array[bool] = [false]  ## Hotfix paint: goes to the front of the queue.
	var jumpable: Array[bool] = [false]  ## It will jump onto it (paint, the flag, an Explorer's coin).
	for s in known_spots():
		if not s.convinced:
			continue  # Skeptic: not sure about that one yet.
		nodes.append(s.pos)
		trust.append(s.trust)
		kinds.append("paint")
		payload.append(null)
		hot.append(s.hotfix)
		jumpable.append(true)
	if _goal_known:
		nodes.append(_goal.global_position)
		trust.append(5)
		kinds.append("goal")
		payload.append(null)
		hot.append(false)
		jumpable.append(true)
	for t in known_tasks():
		nodes.append(t.pos)
		trust.append(t.trust)
		kinds.append("task")
		payload.append(t.host)
		hot.append(t.hotfix)
		jumpable.append(false)
	for c in known_coins():
		nodes.append(c.global_position)
		trust.append(5)
		kinds.append("coin")
		payload.append(c)
		hot.append(false)
		# An Explorer will gamble on an unpainted jump for a coin, but only one with a floor under it:
		# a coin floating over a pit is for painted jumps that pass through it, not a place to land.
		jumpable.append(curious and _has_floor_under(c.global_position))
	for t in known_curios():
		nodes.append(t.pos)
		trust.append(1)
		kinds.append("curio")
		payload.append(t.host)
		hot.append(false)
		jumpable.append(false)
	if _retrace_to != Vector3.INF:
		# Retracing: the places it got to without paint are stepping stones too (jumping to them is a gamble again).
		for p in _trail:
			if nodes.any(func(n): return n.distance_to(p) < 1.0):
				continue
			nodes.append(p)
			trust.append(1)
			kinds.append("trail")
			payload.append(null)
			hot.append(false)
			jumpable.append(true)

	# Dijkstra. Jumps only land on paint or the flag. Low-trust spots cost extra.
	var n := nodes.size()
	var dist: Array[float] = []
	var prev: Array[int] = []
	var via_jump: Array[bool] = []
	var via_point: Array = []  ## Take-off point to walk to before jumping (or null).
	var via_over: Array[bool] = []  ## That jump is beyond its real reach (Blind trust): it will fall short.
	var via_replay: Array[bool] = []  ## Retracing: an unpainted jump it made before, made again (a gamble).
	var done: Array[bool] = []
	for i in n:
		dist.append(INF)
		prev.append(-1)
		via_jump.append(false)
		via_point.append(null)
		via_over.append(false)
		via_replay.append(false)
		done.append(false)
	dist[0] = 0.0
	for _iter in n:
		var u := -1
		for i in n:
			if not done[i] and dist[i] < INF and (u == -1 or dist[i] < dist[u]):
				u = i
		if u == -1:
			break
		done[u] = true
		for v in n:
			if done[v]:
				continue
			var link := _link(nodes[u], nodes[v], jumpable[v])
			if link.is_empty():
				link = _replay_link(nodes[u], nodes[v])
			if link.is_empty():
				continue
			var nd: float = dist[u] + link.cost + (4.0 / trust[v] if kinds[v] == "paint" else 0.0)
			if nd < dist[v]:
				dist[v] = nd
				prev[v] = u
				via_jump[v] = link.jump
				via_point[v] = link.get("via")
				via_over[v] = link.get("overreach", false)
				via_replay[v] = link.get("replay", false)

	var target := _pick_target(nodes, trust, kinds, dist, hot)
	_path.clear()
	if target != -1:
		var i := target
		while i > 0:
			_path.push_front({pos = nodes[i], jump = via_jump[i], trust = trust[i], leap = false,
				paint = kinds[i] == "paint", kind = kinds[i], host = payload[i]})
			if via_over[i]:
				_path[0].overreach = true
			if via_jump[i] and (kinds[i] == "trail" or via_replay[i]):
				_path[0].leap = true  # It got there without paint last time: same gamble again.
				_path[0].desperate = true
			if kinds[i] == "coin" and via_jump[i]:
				# No paint there: it's a gamble with this tester's improvised-jump odds.
				_path[0].leap = true
				_path[0].desperate = true
				_path[0].coin_gamble = true
			if via_point[i] != null:
				_path.push_front({pos = via_point[i], jump = false, trust = 99, leap = false,
					paint = false, kind = "walk", host = null})
			i = prev[i]
		if hot[target]:
			# Heading for a hotfix: no doubts or look-arounds on the way, it's on a mission.
			for step in _path:
				step.trust = maxi(step.trust, hotfix_trust)
		# Already standing on the first step? Skip it (otherwise it "arrives" there forever). "On it" = within
		# arm's reach on the same level: a splat painted right against a pillar can't be stood on exactly.
		while _path.size() > 1 and _path[0].kind == "paint" and _at(_path[0].pos):
			var here: Dictionary = _path.pop_front()
			_record_visit(here.pos)
		match kinds[target]:
			"goal":
				say(["I know where I'm going!", "Flag, here I come."].pick_random())
			"task":
				say(["Going to do the yellow thing.", "I see what I'm supposed to do."].pick_random())
			"curio":
				say(["Nobody painted that. Which means I MUST touch it.", "Ooh. What does this do?",
					"Unpainted? Sounds like a secret."].pick_random(), true)
		_advance()
		return
	if _look_back:
		return  # Looking for a way back to the last splat (see below): there's none, the caller carries on.

	# Skeptic: it has seen paint but doesn't believe it yet. It stares at it (that counts as a look-around)
	# until it does, or until it has been lost long enough to improvise instead.
	var doubted := _doubted_spot()
	if doubted != Vector3.INF and not (improvises and _lost_time >= patience and _wanders >= wander_limit):
		_wanders += 1
		_start_scan(scan_time)
		_look_at(doubted, scan_time * 0.8)
		say(["Hmm. Is that really yellow?", "It LOOKS yellow. But is it?", "I've been fooled by yellow before.",
			"Let me think about that splat.", "Yellow... or a reflection? These graphics are too good."].pick_random())
		return
	if not _retry_jump.is_empty() and _try_retry_jump():
		return
	# Just fell and no painted way back: look around this floor first (wanders + patience), no blind leaps yet.
	var cautious := _shaken and not (_wanders >= wander_limit and _lost_time >= patience)
	if improvises and _goal_known and not cautious and _try_leap_of_faith():
		return
	# Truly lost (Curious / Explorer): before any gamble, go back to the last splat it reached and look again
	# carefully from there, with a fresh round of look-around walks (it may just have missed the next splat).
	if improvises and _wanders >= wander_limit and _retrace_to == Vector3.INF and _furthest != Vector3.INF \
			and _looked_back_at.distance_to(_furthest) > 0.5:
		_looked_back_at = _furthest
		say(["Let me go back to the last yellow and look again.", "Back to the last splat. I must have missed something.",
			"Okay. Last known yellow. Start from there."].pick_random(), true)
		if _at(_furthest):
			_careful_look()
			return
		_look_back = true
		_decide()
		if _look_back:  # No way back to it: carry on as usual.
			_look_back = false
			_careful_look()
		return
	# Out of ideas for `patience` seconds AND it has finished a full round of looking around
	# (that's usually when it spots paint it missed): gamble on a jump instead of sulking.
	if improvises and _lost_time >= patience and _wanders >= wander_limit and _try_desperate_jump():
		_lost_time = 0.0  # One gamble, then it gets another patience period.
		return
	if _wanders < wander_limit:
		_wander()
		return

	state = State.CONFUSED
	if _say_too_far():
		return
	_timer = 0.0
	if not improvises and randf() < 0.5:
		say(["No paint, no way.", "I'm not jumping anywhere unpainted. I'll wait.", "I'll stand here until it's yellow."].pick_random(), true)
		return
	say(["...where do I go?", "I can't see any yellow.", "Is that a ledge? It's not yellow, so no.",
		"I need yellow to understand things.", "Hello? Level designer?",
		"So beautiful. So unpainted.", "Stunning level. No idea where to go."].pick_random(), true)


## Back at the last splat after being lost: a long look around (turning), then a fresh round of wanders.
func _careful_look() -> void:
	_look_back = false
	_wanders = 0
	_lost_time = 0.0
	_start_scan(scan_time * 2.0)
	_body_turn = deg_to_rad(randf_range(140, 200)) * (1 if randf() < 0.5 else -1)


## Priorities: hotfixes > a nearby coin > the flag > painted things to use > unvisited paint.
func _pick_target(nodes: Array[Vector3], trust: Array[int], kinds: Array[String], dist: Array[float],
		hot: Array[bool]) -> int:
	var best := -1
	# Hotfixes are the operator stepping in mid-run: go there before anything else (nearest unused one).
	# Once it has stood on it (or used it), it goes back to its normal priorities.
	for i in nodes.size():
		if not hot[i] or dist[i] == INF:
			continue
		if (kinds[i] == "paint" and not _is_visited(nodes[i])) or kinds[i] == "task":
			if best == -1 or dist[i] < dist[best]:
				best = i
	if best != -1:
		_retrace_to = Vector3.INF
		return best

	# Truly lost: back to the last splat it reached (see _decide).
	if _look_back:
		for i in nodes.size():
			if kinds[i] == "paint" and dist[i] < INF and nodes[i].distance_to(_furthest) < 1.0:
				return i

	for i in nodes.size():
		if kinds[i] == "coin" and dist[i] <= coin_detour and (best == -1 or dist[i] < dist[best]):
			best = i
	if best != -1:
		return best

	var goal_index := kinds.find("goal")
	if goal_index != -1 and dist[goal_index] < INF:
		return goal_index

	# Retracing after a fall: go back to the furthest spot it had reached.
	if _retrace_to != Vector3.INF:
		for i in nodes.size():
			if kinds[i] in ["paint", "trail"] and dist[i] < INF and nodes[i].distance_to(_retrace_to) < 1.0:
				return i
		# No direct way back: go to the reachable spot furthest along the route it took (and only forward,
		# so it never bounces between two spots), then try again from there.
		var here_k := _route_index(feet())
		var pick := -1
		var pick_k := here_k
		for i in nodes.size():
			if kinds[i] not in ["paint", "trail"] or dist[i] == INF or nodes[i].distance_to(feet()) < 0.8:
				continue
			var k := _route_index(nodes[i])
			if k > pick_k:
				pick_k = k
				pick = i
		if pick != -1:
			return pick
		# Nothing on the route within reach: explore from here as usual (carefully, see _shaken), but keep
		# the route in mind.

	for i in nodes.size():
		if kinds[i] == "task" and dist[i] < INF:
			if best == -1 or trust[i] > trust[best] or (trust[i] == trust[best] and dist[i] < dist[best]):
				best = i
	if best != -1:
		return best

	# Best unvisited paint it can reach.
	var best_score := -INF
	var here_to_goal := feet().distance_to(_goal.global_position) if _goal_known else 0.0
	for i in nodes.size():
		if kinds[i] != "paint" or dist[i] == INF or _is_visited(nodes[i]):
			continue
		var score: float
		if overreach > 0.0:
			score = -dist[i]  # Blind trust: the nearest yellow, wherever it leads.
		elif _goal_known:
			var gd := nodes[i].distance_to(_goal.global_position)
			if gd > here_to_goal - 0.5:
				continue
			score = -gd + trust[i]
		else:
			score = trust[i] * 1.5 + nodes[i].distance_to(_spawn.origin) * 0.3 - dist[i] * 0.15
		if score > best_score:
			best_score = score
			best = i
	if best != -1:
		return best

	# Explorer: nothing painted left to do, so it pokes at things nobody painted (right or wrong).
	for i in nodes.size():
		if kinds[i] == "curio" and dist[i] < INF and (best == -1 or dist[i] < dist[best]):
			best = i
	if best != -1:
		return best

	# Nothing new to try, but it left its route for a coin or to use something:
	# go back to the furthest spot it had reached and look again from there.
	# (Ordinary wandering doesn't count, or it would keep walking back instead of exploring.)
	if _detoured and _furthest != Vector3.INF and feet().distance_to(_furthest) > 1.5:
		for i in nodes.size():
			if kinds[i] == "paint" and dist[i] < INF and nodes[i].distance_to(_furthest) < 1.0:
				say(["Now, where was I?", "Back to where I left off.", "Detour done. Back on track."].pick_random(), true)
				_detoured = false  # One trip back; if that doesn't help, it explores as usual.
				return i
	return -1


## Any paint spot it's standing on counts as visited, even if it got there by accident.
func _mark_spots_underfoot() -> void:
	var f := feet()
	for spot in known_spots():
		# Standing on it, or right next to it on the same floor (e.g. it landed a jump just beside the splat).
		var flat := Vector2(spot.pos.x - f.x, spot.pos.z - f.z).length()
		if flat < 1.5 and absf(spot.pos.y - f.y) < 0.4:
			_record_visit(spot.pos)


## Remember a paint spot as reached. New spots become its "best progress" (where to retrace to after a fall).
func _record_visit(pos: Vector3) -> void:
	_trail_add(pos)
	if not _is_visited(pos):
		_visited.append(pos)
		_furthest = pos
		_shaken = false  # New ground: it's over the fall.
		_detoured = false  # New progress: whatever detour it took is behind it.
	elif pos.distance_to(_furthest) < 1.0:
		_detoured = false  # Back where it left off.
	_check_retrace_done(pos)


## Retracing after a fall and just got back to where it fell from?
func _check_retrace_done(pos: Vector3) -> void:
	if _retrace_to == Vector3.INF or pos.distance_to(_retrace_to) >= 1.0:
		return
	_retrace_to = Vector3.INF
	_shaken = false
	if not _failed_jump.is_empty():
		say(["Back where I fell. Let's try that again. Carefully.", "This is the jump that got me. Round two.",
			"Okay. Same jump, more confidence."].pick_random())
		if _failed_jump.improvised and _failed_jump.from.distance_to(pos) < 4.0:
			_retry_jump = _failed_jump  # Nothing painted there: same gamble again, no wandering first.
	else:
		say(["Back where I was. Now, onwards.", "Right, I remember this bit."].pick_random())


func _trail_add(p: Vector3, from := Vector3.INF, gamble := false) -> void:
	for t in _trail:
		if t.distance_to(p) < 1.0:
			return
	_trail.append(p)
	_trail_from.append(from)
	_trail_gamble.append(gamble)


## A take-off point a step back from `from` (away from `to`), on the same floor, so a replayed jump doesn't
## start right on the edge it once slipped from.
func _safe_takeoff(from: Vector3, to: Vector3) -> Vector3:
	var back := Vector3(from.x - to.x, 0, from.z - to.z)
	if back.length() < 0.01:
		return from
	back = back.normalized()
	var space := get_world_3d().direct_space_state
	var floor_y = _ground_y(space, from, from.y, 0.45)
	if floor_y == null:
		return from
	for k in [0.7, 0.5, 0.3]:
		var p: Vector3 = from + back * k
		var y = _ground_y(space, p, floor_y, 0.2)
		if y != null:
			return Vector3(p.x, y, p.z)
	return Vector3(from.x, floor_y, from.z)


## Retracing: the jump it once made from trail stop k-1 to stop k can be made again the same way (walk to the
## same take-off, same landing), even from a spot where the planner wouldn't plan it. Unpainted = a gamble again.
func _replay_link(a: Vector3, b: Vector3) -> Dictionary:
	if _retrace_to == Vector3.INF:
		return {}
	var kb := _route_index(b)
	if kb <= 0 or _route_index(a) != kb - 1 or _trail_from[kb] == Vector3.INF:
		return {}
	var from: Vector3 = _safe_takeoff(_trail_from[kb], b)
	if a.distance_to(from) > 0.6 and not _walkable(a, from):
		return {}
	return {cost = a.distance_to(from) + from.distance_to(b) + 4.0, jump = true, via = from, replay = _trail_gamble[kb]}


## Back where an improvised jump failed: walk to where it took off and jump the same way again.
func _try_retry_jump() -> bool:
	var jump := _retry_jump
	_retry_jump = {}
	var from: Vector3 = _safe_takeoff(jump.from, jump.to)
	_path.clear()
	if from.distance_to(feet()) > 0.3:
		if not _walkable(feet(), from):
			return false
		_path.append({pos = from, jump = false, trust = 99, leap = false, paint = false, kind = "walk"})
	_path.append({pos = jump.to, jump = true, trust = 1, leap = true, desperate = true, paint = false, kind = "leap"})
	_advance()
	return true


## It can see paint it would follow, but the jump is beyond its reach: say so (once per spot),
## so the operator knows to paint a closer landing instead of wondering why it stopped.
func _say_too_far() -> bool:
	var me := feet()
	for s in known_spots():
		var pos: Vector3 = s.pos
		if _is_visited(pos) or _too_far_said.has(pos.snapped(Vector3.ONE * 0.5)):
			continue
		var d := pos - me
		var flat := Vector2(d.x, d.z).length()
		var beyond := flat > max_jump_distance or d.y > max_jump_up
		if not beyond or flat > max_jump_distance + 4.0 or d.y > max_jump_up + 2.5:
			continue
		if not _link(me, pos).is_empty():
			continue
		_too_far_said[pos.snapped(Vector3.ONE * 0.5)] = true
		_look_at(pos, 1.0)
		if d.y > max_jump_up and flat <= max_jump_distance:
			say(["That ledge is too high for me.", "I can't jump THAT high. Paint something lower?",
				"Up there? With these legs?"].pick_random(), true)
		else:
			say(["That yellow is too far for my little legs.", "Too far! Paint me something closer.",
				"I can see the paint. I can't reach the paint."].pick_random(), true)
		return true
	return false


## Skeptic: the nearest spot it has seen but isn't convinced about yet (INF if none).
func _doubted_spot() -> Vector3:
	if conviction_time <= 0.0:
		return Vector3.INF
	var best := Vector3.INF
	for s in known_spots():
		if not s.convinced and (best == Vector3.INF or feet().distance_to(s.pos) < feet().distance_to(best)):
			best = s.pos
	return best


## Is it standing on (or right next to, on the same level) this point?
func _at(p: Vector3) -> bool:
	var f := feet()
	return Vector2(p.x - f.x, p.z - f.z).length() < 0.8 and absf(p.y - f.y) < 0.4


## Where this point is along the trail it took (see _trail); -1 if it isn't a place it got to.
func _route_index(p: Vector3) -> int:
	for k in range(_trail.size() - 1, -1, -1):
		if _trail[k].distance_to(p) < 1.0:
			return k
	return -1


func _is_visited(p: Vector3) -> bool:
	for v in _visited:
		if v.distance_to(p) < 0.8:
			return true
	return false


## No paint toward the flag, but it can see it: walk to the edge and guess a jump.
func _try_leap_of_faith() -> bool:
	var goal_pos := _goal.global_position
	var dir := goal_pos - feet()
	dir.y = 0
	if dir.length() < 0.5:
		return false
	dir = dir.normalized()
	var space := get_world_3d().direct_space_state

	# Walk the ground toward the flag until it ends.
	var edge := _find_takeoff(space, feet(), dir)
	if edge == Vector3.INF:
		return false

	# Look across for something to land on that isn't a terrifying drop.
	for k in range(4, int(max_jump_distance / 0.25) + 1):
		var probe := edge + dir * (k * 0.25)
		var from := probe + Vector3.UP * (max_jump_up + 0.5)
		var q := PhysicsRayQueryParameters3D.create(from, probe - Vector3.UP * max_unpainted_drop, 1)
		var hit := space.intersect_ray(q)
		if hit.is_empty() or hit.normal.y < 0.7:
			continue
		var dy: float = hit.position.y - edge.y
		if dy > max_jump_up or dy < -max_unpainted_drop:
			continue
		var landing: Vector3 = hit.position + dir * 0.8
		var land_y = _ground_y(space, landing, hit.position.y, 0.45)
		if land_y == null:
			landing = hit.position
		else:
			landing.y = land_y
		if _walkable(edge, landing):
			continue  # Still the same ground, not across the gap.
		_path.clear()
		if edge.distance_to(feet()) > 0.3:
			_path.append({pos = edge, jump = false, trust = 1, leap = false, paint = false, kind = "walk"})
		_path.append({pos = landing, jump = true, trust = 1, leap = true, paint = false, kind = "leap"})
		_advance()
		return true
	return false


## Lost for too long: look all around for ANY ledge in jumping range and go for it.
## Prefers landings closer to the flag (if seen), otherwise places it hasn't been.
func _try_desperate_jump() -> bool:
	var space := get_world_3d().direct_space_state
	var origin := feet()
	var best: Dictionary = {}
	var best_score := -INF
	for a in 16:
		var dir := Vector3(cos(a * TAU / 16.0), 0, sin(a * TAU / 16.0))
		# Walk the current ground in this direction until it ends.
		var edge := _find_takeoff(space, origin, dir, 12.0)
		if edge == Vector3.INF:
			continue
		if edge.distance_to(origin) > 0.3 and not _walkable(origin, edge):
			continue
		# First thing to land on across the gap.
		for k in range(3, int(max_jump_distance / 0.25) + 1):
			var probe := edge + dir * (k * 0.25)
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(
				probe + Vector3.UP * (max_jump_up + 0.5), probe - Vector3.UP * max_unpainted_drop, 1, [get_rid()]))
			if hit.is_empty() or hit.normal.y < 0.7:
				continue
			var dy: float = hit.position.y - edge.y
			if dy > max_jump_up or dy < -max_unpainted_drop:
				break
			var landing: Vector3 = hit.position + dir * 0.8
			var land_y = _ground_y(space, landing, hit.position.y, 0.45)
			landing = hit.position if land_y == null else Vector3(landing.x, land_y, landing.z)
			if _walkable(origin, landing) or not _jump_clear(edge, landing):
				break  # Same ground (no jump needed), or something in the way.
			# A gamble is for getting somewhere new: never back where it has already been, and not downhill.
			if _trail.any(func(t): return t.distance_to(landing) < 2.0) or _is_visited(landing):
				break
			if not _trail.is_empty() and landing.y < origin.y - 0.5:
				break  # Down is where it came from: never a gamble worth taking.
			var score: float = -maxf(0.0, origin.y - landing.y) * 6.0
			if _goal_known:
				score -= landing.distance_to(_goal.global_position)
			else:
				var novelty := landing.distance_to(_spawn.origin)
				for v in _visited + _explored:
					novelty = minf(novelty, landing.distance_to(v))
				score += novelty
			score += randf() * 1.5 - edge.distance_to(landing) * 0.3
			if score > best_score:
				best_score = score
				best = {edge = edge, landing = landing}
			break
	if best.is_empty():
		return false
	_path.clear()
	if best.edge.distance_to(origin) > 0.3:
		_path.append({pos = best.edge, jump = false, trust = 99, leap = false, paint = false, kind = "walk"})
	_path.append({pos = best.landing, jump = true, trust = 1, leap = true, desperate = true, paint = false, kind = "leap"})
	_explored.append(best.landing)
	_advance()
	return true


## Walk the ground from `from` along `dir` until it ends, and return a take-off point
## `takeoff_margin` back from that edge. Returns Vector3.INF if no edge within `max_dist`
## (or `from` itself if it's already closer to the edge than the margin).
func _find_takeoff(space: PhysicsDirectSpaceState3D, from: Vector3, dir: Vector3, max_dist := 18.0) -> Vector3:
	var p := from
	var travelled := 0.0
	while travelled < max_dist:
		var y = _ground_y(space, p + dir * 0.1, p.y, 0.45)
		if y == null:
			var edge := p - dir * takeoff_margin
			if (edge - from).dot(dir) <= 0.0:
				return from
			var ey = _ground_y(space, edge, p.y, 0.45)
			return Vector3(edge.x, ey if ey != null else p.y, edge.z)
		p += dir * 0.1
		p.y = y
		travelled += 0.1
	return Vector3.INF


## Mooch around the current platform looking for yellow.
func _wander() -> void:
	_wanders += 1
	var space := get_world_3d().direct_space_state
	# Try a ring of spots and prefer the one furthest from anywhere it has already been.
	var best := Vector3.INF
	var best_score := -INF
	var origin := feet()
	for attempt in 12:
		var angle := attempt * TAU / 12.0
		var dir := Vector3(cos(angle), 0, sin(angle))
		var target := origin + dir * randf_range(wander_min, maxf(wander_range, wander_min + 0.5))
		# Stays on roughly the same level: it won't wander down slopes on its own.
		var y = _ground_y(space, target, origin.y, 0.3)
		if y == null or absf(y - _home_y) > 0.3:
			continue
		target.y = y
		if not _walkable(origin, target):
			continue
		# Don't stand right on an edge it can't see.
		if _ground_y(space, target + dir * 0.8, y, 0.3) == null:
			target -= dir * 0.8
		var novelty := target.distance_to(_spawn.origin - Vector3.UP * FEET_OFFSET)
		for v in _visited + _explored:
			novelty = minf(novelty, target.distance_to(v))
		var score := novelty + randf() * 1.5
		if score > best_score:
			best_score = score
			best = target
	if best == Vector3.INF:
		_wanders = wander_limit
		_decide()
		return
	_path.clear()
	_path.append({pos = best, jump = false, trust = 1, leap = false, paint = false, kind = "wander"})
	_explored.append(best)
	if randf() < 0.3:
		admire()
	else:
		say(["Just... looking around.", "Nothing yellow here.", "Maybe over here?", "Sightseeing. Not lost. Sightseeing."].pick_random())
	_advance()


## Can I get from a to b (feet positions)? {} if not, else {cost, jump}.
## Jumps are only allowed onto paint (or the flag it can see).
func _link(a: Vector3, b: Vector3, allow_jump := true) -> Dictionary:
	var link := _link_within(a, b, allow_jump, max_jump_distance, max_jump_up)
	# Blind trust: only when there's no proper way, it jumps at paint a bit beyond its reach (and falls short).
	if link.is_empty() and allow_jump and overreach > 0.0:
		link = _link_within(a, b, true, max_jump_distance + overreach, max_jump_up + overreach * 0.4)
		if not link.is_empty() and link.jump:
			link.overreach = true
			link.cost += 6.0
	return link


func _link_within(a: Vector3, b: Vector3, allow_jump: bool, reach: float, reach_up: float) -> Dictionary:
	var d := b - a
	var flat := Vector2(d.x, d.z).length()
	if flat < 0.05 and absf(d.y) < 0.3:
		return {cost = 0.0, jump = false}
	if _walkable(a, b):
		return {cost = flat, jump = false}
	if not allow_jump or d.y > reach_up + 1.5 or d.y < -max_drop - 1.5:
		return {}
	if flat <= reach and d.y <= reach_up and d.y >= -max_drop and _jump_clear(a, b):
		return {cost = flat + 2.0, jump = true}
	# Paint marks where to LAND. Walk to a sensible take-off point on this ground first.
	var space := get_world_3d().direct_space_state
	var back := Vector3(-d.x, 0, -d.z).normalized()
	var r := 1.2
	while r <= reach and r < flat:
		var launch: Vector3 = b + back * r
		r += 0.2
		var y = _ground_y(space, launch, a.y, 0.45)
		if y == null:
			continue
		launch.y = y
		# Keep a safety margin: there must still be ground between the feet and the edge.
		if _ground_y(space, launch - back * takeoff_margin, y, 0.3) == null:
			continue
		var j: Vector3 = b - launch
		if j.y > reach_up or j.y < -max_drop:
			continue
		if not _walkable(a, launch) or not _jump_clear(launch, b):
			continue
		return {cost = a.distance_to(launch) + r + 2.0, jump = true, via = launch}
	return {}


## Nothing in the way of the jump arc (doors, walls, ceilings).
func _jump_clear(a: Vector3, b: Vector3) -> bool:
	var space := get_world_3d().direct_space_state
	var top := (a + b) * 0.5
	top.y = maxf(a.y, b.y) + jump_apex + 0.4
	var start := a + Vector3.UP * 1.0
	var end := b + Vector3.UP * 0.6
	for seg in [[start, top], [top, end]]:
		if space.intersect_ray(PhysicsRayQueryParameters3D.create(seg[0], seg[1], 1, [get_rid()])):
			return false
	return true


## Continuous ground between a and b, no wall in between, not too steep.
func _walkable(a: Vector3, b: Vector3) -> bool:
	var d := b - a
	var flat := Vector2(d.x, d.z).length()
	if absf(d.y) > flat * 0.5 + 0.3:
		return false
	var space := get_world_3d().direct_space_state
	# Three rays as wide as its body, so it doesn't plan routes that clip posts and corners.
	var side := Vector3(d.z, 0, -d.x).normalized() * 0.38 if flat > 0.01 else Vector3.ZERO
	for offset in [Vector3.ZERO, side, -side]:
		var wall_query := PhysicsRayQueryParameters3D.create(a + Vector3.UP * 0.5 + offset, b + Vector3.UP * 0.5 + offset, 1, [get_rid()])
		if space.intersect_ray(wall_query):
			return false
	var samples := int(ceil(flat / 0.4))
	for s in range(1, samples):
		var p := a.lerp(b, float(s) / samples)
		if _ground_y(space, p, p.y, 0.45) == null:
			return false
	return true


func _ground_y(space: PhysicsDirectSpaceState3D, p: Vector3, ref_y: float, tolerance: float) -> Variant:
	var q := PhysicsRayQueryParameters3D.create(
		Vector3(p.x, ref_y + 0.8, p.z), Vector3(p.x, ref_y - 0.8, p.z), 1)
	var hit := space.intersect_ray(q)
	if hit.is_empty() or absf(hit.position.y - ref_y) > tolerance:
		return null
	return hit.position.y


# --- Looking around --------------------------------------------------------

func _face(dir: Vector3) -> void:
	_body.look_at(_body.global_position + dir, Vector3.UP)


func _look_at(point: Vector3, duration: float) -> void:
	_look_point = point
	_look_timer = duration


## Starts staring at something: its feet, up high, or a random spot around it.
func _start_gaze() -> void:
	_gaze_left = randf_range(gaze_duration.x, gaze_duration.y)
	_gaze_timer = randf_range(gaze_interval.x, gaze_interval.y)
	var kind: String = ["down", "down", "up", "spot", "spot"].pick_random()
	match kind:
		"down":
			_gaze_yaw = deg_to_rad(randf_range(-25, 25))
			_gaze_pitch = deg_to_rad(randf_range(-60, -40))
		"up":
			_gaze_yaw = deg_to_rad(randf_range(-50, 50))
			_gaze_pitch = deg_to_rad(randf_range(30, 50))
		_:
			_gaze_yaw = deg_to_rad(randf_range(50, 100)) * (1 if randf() < 0.5 else -1)
			_gaze_pitch = deg_to_rad(randf_range(-20, 15))
	if randf() < gaze_line_chance:
		say(GAZE_LINES[kind].pick_random() if randf() < 0.7 else ADMIRE.pick_random())


## Is it staring at the scenery right now? (Only while lost, and never over something it's looking at.)
func is_gazing() -> bool:
	return _gaze_left > 0.0


func _update_gaze(delta: float) -> void:
	if not _is_lost() or state == State.HESITATING or _look_timer > 0.0 or _urgent or not is_on_floor():
		_gaze_left = 0.0
		return
	if _gaze_left > 0.0:
		_gaze_left -= delta
		if state in [State.SCANNING, State.CONFUSED]:
			_timer -= delta  # The look-around waits: admiring isn't searching.
		return
	_gaze_timer -= delta
	if _gaze_timer <= 0.0:
		_start_gaze()


func _update_head(delta: float) -> void:
	var target_yaw := 0.0
	var target_pitch := 0.0
	_look_timer -= delta
	_update_gaze(delta)
	if _look_timer > 0.0:
		var local := _body.global_basis.inverse() * (_look_point - _head.global_position)
		target_yaw = clampf(atan2(-local.x, -local.z), deg_to_rad(-110), deg_to_rad(110))
		target_pitch = clampf(atan2(local.y, Vector2(local.x, local.z).length()), deg_to_rad(-50), deg_to_rad(40))
	elif _gaze_left > 0.0:
		target_yaw = _gaze_yaw
		target_pitch = _gaze_pitch  # Any turn-around waits until it's done staring.
	elif state == State.SCANNING or state == State.CONFUSED or state == State.WAITING:
		if state != State.WAITING:
			_turn_body(delta)
		var period := _scan_duration if state == State.SCANNING else 3.0
		target_yaw = sin(_timer / period * TAU) * deg_to_rad(75)
	elif state == State.INTERACTING:
		target_yaw = 0.0
	elif state == State.WALKING:
		_glance_timer -= delta
		if _glance_timer <= 0.0:
			# Occasional glances to the side; it isn't a drone.
			_glance_yaw = 0.0 if _glance_yaw != 0.0 else deg_to_rad(randf_range(35, 65)) * (1 if randf() < 0.5 else -1)
			_glance_timer = randf_range(0.4, 0.8) if _glance_yaw != 0.0 else randf_range(1.0, 2.2)
		target_yaw = _glance_yaw
	_head.rotation.y = lerp_angle(_head.rotation.y, target_yaw, minf(1.0, 7.0 * delta))
	_head_pitch = lerp_angle(_head_pitch, target_pitch, minf(1.0, 4.0 * delta))
	# Only the visor tilts (the head node stays level, so nothing that uses its basis changes). It pivots
	# around the centre of the capsule's dome so it slides over the surface instead of sinking into it.
	var tilt := Basis(Vector3.RIGHT, _head_pitch)
	_visor.position = VISOR_PIVOT + tilt * (_visor_rest - VISOR_PIVOT)
	_visor.basis = tilt


func _turn_body(delta: float) -> void:
	if absf(_body_turn) > 0.001:
		var turn := clampf(_body_turn, -3.0 * delta, 3.0 * delta)
		_body.rotate_y(turn)
		_body_turn -= turn


# --- Debug view ------------------------------------------------------------

func _setup_debug() -> void:
	_debug_mesh = MeshInstance3D.new()
	_debug_mesh.top_level = true
	_debug_mesh.mesh = ImmediateMesh.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.no_depth_test = true
	_debug_mesh.material_override = mat
	_debug_mesh.visible = debug_view
	add_child(_debug_mesh)

	_reach_mesh = MeshInstance3D.new()
	_reach_mesh.top_level = true
	_reach_mesh.mesh = ImmediateMesh.new()
	var reach_mat := StandardMaterial3D.new()
	reach_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	reach_mat.vertex_color_use_as_albedo = true
	reach_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	reach_mat.cull_mode = BaseMaterial3D.CULL_DISABLED  # Bands are visible from both sides.
	_reach_mesh.material_override = reach_mat  # Depth-tested: ledges cut the rings, so you see what's inside.
	_reach_mesh.visible = debug_view
	add_child(_reach_mesh)
	_reach_label = Label3D.new()
	_reach_label.top_level = true
	_reach_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_reach_label.no_depth_test = true
	_reach_label.font_size = 40
	_reach_label.pixel_size = 0.01
	_reach_label.outline_size = 10
	_reach_label.modulate = REACH_COLOR
	_reach_label.visible = debug_view
	add_child(_reach_label)


const REACH_COLOR := Color(0.35, 0.9, 1.0)

## The jump reach as one cylinder centred on `center` (a spot it would stand on):
## bottom ring = how far it can jump, top ring (raised by max_jump_up) = the highest ledge it can land on.
## A ledge whose top pokes above the top ring is too high; a landing outside the rings is too far.
## (It takes off 0.6 m back from an edge, so measure from where it would actually stand.)
func draw_reach(center: Vector3) -> void:
	var im: ImmediateMesh = _reach_mesh.mesh
	im.clear_surfaces()
	if center == Vector3.INF:
		_reach_label.visible = false
		return
	_reach_label.visible = debug_view
	var r := max_jump_distance
	var up := max_jump_up
	var segments := 64
	var ring := func(a: float) -> Vector3: return Vector3(cos(a), 0, sin(a))
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in segments:
		var a: Vector3 = ring.call(TAU * i / segments)
		var b: Vector3 = ring.call(TAU * (i + 1) / segments)
		# Faint disc on the ground: how far it can jump from here.
		im.surface_set_color(Color(REACH_COLOR, 0.07))
		for v in [center + Vector3.UP * 0.03, center + a * r + Vector3.UP * 0.03, center + b * r + Vector3.UP * 0.03]:
			im.surface_add_vertex(v)
		# Ground ring: a flat band, easy to see from above.
		im.surface_set_color(Color(REACH_COLOR, 0.85))
		var y0 := Vector3.UP * 0.04
		for v in [center + a * (r - 0.08) + y0, center + a * (r + 0.08) + y0, center + b * (r + 0.08) + y0,
				center + a * (r - 0.08) + y0, center + b * (r + 0.08) + y0, center + b * (r - 0.08) + y0]:
			im.surface_add_vertex(v)
		# Height ring: an upright band at max_jump_up, easy to see from the side.
		im.surface_set_color(Color(REACH_COLOR, 0.55))
		var lo := Vector3.UP * (up - 0.06)
		var hi := Vector3.UP * (up + 0.06)
		for v in [center + a * r + lo, center + a * r + hi, center + b * r + hi,
				center + a * r + lo, center + b * r + hi, center + b * r + lo]:
			im.surface_add_vertex(v)
	im.surface_end()
	# Thin uprights joining the rings, and a centre post showing the height.
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	im.surface_set_color(Color(REACH_COLOR, 0.35))
	for i in 8:
		var a: Vector3 = ring.call(TAU * i / 8.0)
		im.surface_add_vertex(center + a * r)
		im.surface_add_vertex(center + a * r + Vector3.UP * up)
	im.surface_set_color(Color(REACH_COLOR, 0.9))
	im.surface_add_vertex(center)
	im.surface_add_vertex(center + Vector3.UP * up)
	im.surface_end()
	_reach_label.global_position = center + Vector3.UP * (up * 0.5)  # Mid-height: stays on screen when looking down.
	_reach_label.text = "Jump reach"


func _draw_debug() -> void:
	var im: ImmediateMesh = _debug_mesh.mesh
	im.clear_surfaces()
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	# Vision cone edges.
	var eye := _head.global_position
	var look := -_head.global_basis.z
	look.y = 0
	look = look.normalized()
	var half := deg_to_rad(view_angle_deg * 0.5)
	for side in [-1.0, 1.0]:
		im.surface_set_color(Color(0.3, 0.9, 1.0, 0.6))
		im.surface_add_vertex(eye)
		im.surface_add_vertex(eye + look.rotated(Vector3.UP, half * side) * 6.0)
	# Known paint: post height = trust. Skeptic not convinced yet: orange post growing to full height.
	# Partially noticed paint: short red tick.
	for s in known_spots():
		if s.convinced:
			im.surface_set_color(Color(0.2, 1.0, 0.4))
			im.surface_add_vertex(s.pos)
			im.surface_add_vertex(s.pos + Vector3.UP * (0.4 * s.trust))
		else:
			im.surface_set_color(Color(1.0, 0.55, 0.1))
			im.surface_add_vertex(s.pos)
			im.surface_add_vertex(s.pos + Vector3.UP * (1.2 * s.conviction))
	if _paint:
		for mark in _paint.get_marks():
			var a: float = _attention.get(mark.get_instance_id(), 0.0)
			if a > 0.0 and a < 1.0:
				im.surface_set_color(Color(1, 0.2, 0.2))
				im.surface_add_vertex(mark.global_position)
				im.surface_add_vertex(mark.global_position + Vector3.UP * (0.4 * a))
	for t in known_tasks():
		im.surface_set_color(Color(1, 0.2, 1))
		im.surface_add_vertex(t.pos)
		im.surface_add_vertex(t.pos + Vector3.UP * (0.4 * t.trust))
	for c in known_coins():
		im.surface_set_color(Color(1, 0.7, 0.1))
		im.surface_add_vertex(c.global_position)
		im.surface_add_vertex(c.global_position + Vector3.UP * 0.6)
	# Planned path.
	var prev := feet()
	for step in _path:
		im.surface_set_color(Color(1, 0.6, 0.1) if step.jump else Color(1, 1, 1))
		im.surface_add_vertex(prev + Vector3.UP * 0.1)
		im.surface_add_vertex(step.pos + Vector3.UP * 0.1)
		prev = step.pos
	if _retrace_to != Vector3.INF:
		im.surface_set_color(Color(0.3, 0.6, 1.0))  # Where it's retracing to after a fall.
		im.surface_add_vertex(_retrace_to)
		im.surface_add_vertex(_retrace_to + Vector3.UP * 3.0)
	if _goal_known:
		im.surface_set_color(Color(1, 0.85, 0.1))
		im.surface_add_vertex(_goal.global_position)
		im.surface_add_vertex(_goal.global_position + Vector3.UP * 4.0)
	im.surface_end()
