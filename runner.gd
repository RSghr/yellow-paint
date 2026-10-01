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

signal reached_goal
signal died
signal said(text: String)

enum State { WAITING, SCANNING, WALKING, HESITATING, JUMPING, INTERACTING, CONFUSED, CELEBRATING, DEAD }

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

@export_group("Personality")
@export var scan_time := 1.8  ## A full look-around, left to right.
@export var hesitation_per_doubt := 0.9  ## Pause before jumping to a spot with only 1 splat.
@export var leap_error := 0.7  ## Unpainted jumps are guesses: landing error in metres.
@export var wander_limit := 3  ## Wanders on its own this many times before giving up.
@export var patience := 8.0  ## Seconds without progress (after a full look-around) before it jumps at things unpainted.
@export_range(0.0, 1.0, 0.05) var desperate_success_chance := 0.65  ## Chance (0-1) that an unpainted desperate jump lands. A miss falls well short.
@export var coin_detour := 16.0  ## Will go out of its way this far (path cost) for a coin. A painted jump costs ~10.

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

var state := State.WAITING
var tester_name := "Playtester"  ## Set by the Game scene (a random focus tester per run).

var _path: Array[Dictionary] = []  ## Steps: {pos, jump, trust, leap}
var _spawn: Transform3D
var _paint: PaintManager
var _goal: Node3D
var _goal_known := false

# Perception memory
var _attention := {}  ## mark instance id -> how much it has looked at it (1.0 = noticed)
var _seen := {}  ## mark instance id -> true
var _visited: Array[Vector3] = []  ## Paint spots it has stood on.
var _explored: Array[Vector3] = []  ## Places it wandered to (for picking new directions).
var _wanders := 0
var _home_y := 0.0  ## Height of the last trusted ground; wandering stays near it.
var _rethink := false  ## Something new was noticed; reconsider the plan at the next chance.
var _lost_time := 0.0  ## Seconds since it last made progress (reached paint/coin/button/flag, saw new paint, a door opened).
var _last_jump_desperate := false
var _coin_attention := {}  ## coin instance id -> attention
var _seen_coins := {}
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
var _air_time := 0.0
var _jump_flat_velocity := Vector3.ZERO  ## Kept through the jump, like holding forward.
var _stuck_time := 0.0
var _stuck_count := 0
var _last_pos := Vector3.ZERO

@onready var _speech: Label3D = $Speech
@onready var _body: Node3D = $Body
@onready var _head: Node3D = $Body/Head
var _debug_mesh: MeshInstance3D


func _ready() -> void:
	_spawn = global_transform
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

func start() -> void:
	if state in [State.WAITING, State.CONFUSED]:
		_wanders = 0
		_lost_time = 0.0
		say(["Okay! Let's see...", "Playtest starting. Where's the yellow?", "Right. Looking for yellow."].pick_random(), true)
		_start_scan(scan_time)


func reset_to_spawn() -> void:
	global_transform = _spawn
	velocity = Vector3.ZERO
	_path.clear()
	_attention.clear()
	_seen.clear()
	_visited.clear()
	_explored.clear()
	_coin_attention.clear()
	_seen_coins.clear()
	_choices.clear()
	_task = {}
	_body.position = Vector3.ZERO
	_goal_known = false
	_wanders = 0
	_rethink = false
	_lost_time = 0.0
	_last_jump_desperate = false
	_home_y = _spawn.origin.y - FEET_OFFSET
	_head.rotation = Vector3.ZERO
	_body.rotation = Vector3.ZERO
	_body_turn = 0.0
	state = State.WAITING
	say("Ready when you are, boss.", true)


func celebrate() -> void:
	if state == State.DEAD:
		return
	state = State.CELEBRATING
	_path.clear()
	say("I did it! All by myself!", true)
	reached_goal.emit()


func feet() -> Vector3:
	return global_position - Vector3.UP * FEET_OFFSET


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
		if is_instance_valid(mark.host) and mark.host.kind == "breakable" and _breakable_choice(mark.host, seen) == "break":
			continue  # It's going to smash this, not stand on it.
		var trust := 0
		for other in seen:
			if other.role == "nav" and other.global_position.distance_to(mark.global_position) <= trust_radius:
				trust += 1
		spots.append({pos = mark.stand_point, trust = trust, host = mark.host})
	return spots


## Painted things it intends to use: [{pos (where to stand), trust, host}]
func known_tasks() -> Array[Dictionary]:
	var by_host := {}
	var seen := _seen_marks()
	for mark in seen:
		if mark.role != "interact" or not is_instance_valid(mark.host) or mark.host.is_used():
			continue
		var id := mark.host.get_instance_id()
		if not by_host.has(id):
			by_host[id] = {pos = mark.interact_point, trust = 0, host = mark.host}
		by_host[id].trust += 1
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
			if mark.role == "interact":
				i += 1
			elif mark.role == "nav":
				t += 1
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
	if state not in [State.WAITING, State.CELEBRATING, State.DEAD]:
		_lost_time += delta  # Reset whenever it makes progress; wandering doesn't count.

	if state != State.DEAD:
		_perceive_timer += delta
		if _perceive_timer >= PERCEPTION_INTERVAL:
			if is_on_floor() and state not in [State.WAITING, State.JUMPING]:
				_mark_spots_underfoot()
			_perceive(_perceive_timer)
			_perceive_timer = 0.0
			if debug_view:
				_draw_debug()

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


func _idle_physics(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0, 20 * delta)
	velocity.z = move_toward(velocity.z, 0, 20 * delta)
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	move_and_slide()


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
			if off.length() < 1.2:
				_arrive(step)
				return
			if step.leap:
				say(["Made it! ...mostly.", "Nailed it. Sort of."].pick_random(), true)
		_start_scan(scan_time * 0.5)


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
	state = State.INTERACTING
	_timer = 0.0
	_scan_duration = step.host.interact_duration()
	if step.host.kind == "button":
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
	if step.get("kind", "") in ["task", "coin", "paint", "goal"]:
		_lost_time = 0.0
	if step.get("kind", "") == "task":
		_start_interacting(step)
		return
	if step.get("kind", "") == "coin":
		say(["Shiny!", "Ooh, a coin!", "Coin get."].pick_random(), true)
	if step.get("paint", false):
		if not _is_visited(step.pos):
			_visited.append(step.pos)
		_wanders = 0
		_home_y = feet().y
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
			say(["Fine. I'll do it myself.", "No yellow anywhere. Improvising!", "Nobody's painting? I'm jumping.",
				"This is what happens when you don't paint, boss."].pick_random(), true)
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
		target += flat.normalized() * randf_range(-leap_error, leap_error * 0.6)
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
	for s in known_spots():
		nodes.append(s.pos)
		trust.append(s.trust)
		kinds.append("paint")
		payload.append(null)
	if _goal_known:
		nodes.append(_goal.global_position)
		trust.append(5)
		kinds.append("goal")
		payload.append(null)
	for t in known_tasks():
		nodes.append(t.pos)
		trust.append(t.trust)
		kinds.append("task")
		payload.append(t.host)
	for c in known_coins():
		nodes.append(c.global_position)
		trust.append(5)
		kinds.append("coin")
		payload.append(c)

	# Dijkstra. Jumps only land on paint or the flag. Low-trust spots cost extra.
	var n := nodes.size()
	var dist: Array[float] = []
	var prev: Array[int] = []
	var via_jump: Array[bool] = []
	var via_point: Array = []  ## Take-off point to walk to before jumping (or null).
	var done: Array[bool] = []
	for i in n:
		dist.append(INF)
		prev.append(-1)
		via_jump.append(false)
		via_point.append(null)
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
			var link := _link(nodes[u], nodes[v], kinds[v] in ["paint", "goal"])
			if link.is_empty():
				continue
			var nd: float = dist[u] + link.cost + (4.0 / trust[v] if kinds[v] == "paint" else 0.0)
			if nd < dist[v]:
				dist[v] = nd
				prev[v] = u
				via_jump[v] = link.jump
				via_point[v] = link.get("via")

	var target := _pick_target(nodes, trust, kinds, dist)
	_path.clear()
	if target != -1:
		var i := target
		while i > 0:
			_path.push_front({pos = nodes[i], jump = via_jump[i], trust = trust[i], leap = false,
				paint = kinds[i] == "paint", kind = kinds[i], host = payload[i]})
			if via_point[i] != null:
				_path.push_front({pos = via_point[i], jump = false, trust = 99, leap = false,
					paint = false, kind = "walk", host = null})
			i = prev[i]
		# Already standing on the first step? Skip it (otherwise it "arrives" there forever).
		while _path.size() > 1 and not _path[0].jump and _path[0].kind == "paint" \
				and Vector2(_path[0].pos.x - feet().x, _path[0].pos.z - feet().z).length() < 0.35:
			var here: Dictionary = _path.pop_front()
			if not _is_visited(here.pos):
				_visited.append(here.pos)
		match kinds[target]:
			"goal":
				say(["I know where I'm going!", "Flag, here I come."].pick_random())
			"task":
				say(["Going to do the yellow thing.", "I see what I'm supposed to do."].pick_random())
		_advance()
		return

	if _goal_known and _try_leap_of_faith():
		return
	# Out of ideas for `patience` seconds AND it has finished a full round of looking around
	# (that's usually when it spots paint it missed): gamble on a jump instead of sulking.
	if _lost_time >= patience and _wanders >= wander_limit and _try_desperate_jump():
		_lost_time = 0.0  # One gamble, then it gets another patience period.
		return
	if _wanders < wander_limit:
		_wander()
		return

	state = State.CONFUSED
	_timer = 0.0
	say(["...where do I go?", "I can't see any yellow.", "Is that a ledge? It's not yellow, so no.",
		"I need yellow to understand things.", "Hello? Level designer?"].pick_random(), true)


## Priorities: a nearby coin > the flag > painted things to use > unvisited paint.
func _pick_target(nodes: Array[Vector3], trust: Array[int], kinds: Array[String], dist: Array[float]) -> int:
	var best := -1
	for i in nodes.size():
		if kinds[i] == "coin" and dist[i] <= coin_detour and (best == -1 or dist[i] < dist[best]):
			best = i
	if best != -1:
		return best

	var goal_index := kinds.find("goal")
	if goal_index != -1 and dist[goal_index] < INF:
		return goal_index

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
		if _goal_known:
			var gd := nodes[i].distance_to(_goal.global_position)
			if gd > here_to_goal - 0.5:
				continue
			score = -gd + trust[i]
		else:
			score = trust[i] * 1.5 + nodes[i].distance_to(_spawn.origin) * 0.3 - dist[i] * 0.15
		if score > best_score:
			best_score = score
			best = i
	return best


## Any paint spot it's standing on counts as visited, even if it got there by accident.
func _mark_spots_underfoot() -> void:
	var f := feet()
	for spot in known_spots():
		if spot.pos.distance_to(f) < 1.0 and not _is_visited(spot.pos):
			_visited.append(spot.pos)


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
			var score: float
			if _goal_known:
				score = -landing.distance_to(_goal.global_position)
			else:
				var novelty := landing.distance_to(_spawn.origin)
				for v in _visited + _explored:
					novelty = minf(novelty, landing.distance_to(v))
				score = novelty
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
		var target := origin + dir * randf_range(2.0, 5.0)
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
	_path.append({pos = best, jump = false, trust = 1, leap = false, paint = false, kind = "walk"})
	_explored.append(best)
	say(["Just... looking around.", "Nothing yellow here.", "Maybe over here?"].pick_random())
	_advance()


## Can I get from a to b (feet positions)? {} if not, else {cost, jump}.
## Jumps are only allowed onto paint (or the flag it can see).
func _link(a: Vector3, b: Vector3, allow_jump := true) -> Dictionary:
	var d := b - a
	var flat := Vector2(d.x, d.z).length()
	if flat < 0.05 and absf(d.y) < 0.3:
		return {cost = 0.0, jump = false}
	if _walkable(a, b):
		return {cost = flat, jump = false}
	if not allow_jump or d.y > max_jump_up + 1.5 or d.y < -max_drop - 1.5:
		return {}
	if flat <= max_jump_distance and d.y <= max_jump_up and d.y >= -max_drop and _jump_clear(a, b):
		return {cost = flat + 2.0, jump = true}
	# Paint marks where to LAND. Walk to a sensible take-off point on this ground first.
	var space := get_world_3d().direct_space_state
	var back := Vector3(-d.x, 0, -d.z).normalized()
	var r := 1.2
	while r <= max_jump_distance and r < flat:
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
		if j.y > max_jump_up or j.y < -max_drop:
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


func _update_head(delta: float) -> void:
	var target_yaw := 0.0
	_look_timer -= delta
	if _look_timer > 0.0:
		var local := _body.global_basis.inverse() * (_look_point - _head.global_position)
		target_yaw = clampf(atan2(-local.x, -local.z), deg_to_rad(-110), deg_to_rad(110))
	elif state == State.SCANNING or state == State.CONFUSED or state == State.WAITING:
		if state != State.WAITING and absf(_body_turn) > 0.001:
			var turn := clampf(_body_turn, -3.0 * delta, 3.0 * delta)
			_body.rotate_y(turn)
			_body_turn -= turn
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
	# Known paint: post height = trust. Partially noticed paint: short red tick.
	for s in known_spots():
		im.surface_set_color(Color(0.2, 1.0, 0.4))
		im.surface_add_vertex(s.pos)
		im.surface_add_vertex(s.pos + Vector3.UP * (0.4 * s.trust))
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
	if _goal_known:
		im.surface_set_color(Color(1, 0.85, 0.1))
		im.surface_add_vertex(_goal.global_position)
		im.surface_add_vertex(_goal.global_position + Vector3.UP * 4.0)
	im.surface_end()
