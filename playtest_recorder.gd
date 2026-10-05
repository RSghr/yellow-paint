extends Node
## DEBUG (branch claude/playtest-recorder): records each playtest attempt to debug_logs/*.json so it can be
## replayed headless with the exact same paint and tester. Added by game.gd.
##
## Recorded: level, tester + traits, every splat (position, normal, role, host, hotfix) at Enter, then a
## timeline: the tester's position/state every 0.25 s, every state change, every new plan, jumps (from, to,
## kind), falls, the trail, speech, and how the attempt ended.

const SAMPLE_EVERY := 0.25

var game: Node
var _on := false
var _data := {}
var _events: Array = []
var _samples: Array = []
var _t := 0.0
var _sample_timer := 0.0
var _last_state := ""
var _last_plan := ""
var _last_retrace := Vector3.INF


func begin() -> void:
	if _on:
		return
	var r = game.runner
	_on = true
	_t = 0.0
	_sample_timer = 0.0
	_events = []
	_samples = []
	_last_state = ""
	_last_plan = ""
	_last_retrace = Vector3.INF
	var marks := []
	for m in game.paint.get_marks():
		marks.append({pos = _v(m.global_position), normal = _v(m.normal), role = m.role,
			host = String(game.level.get_path_to(m.host)) if is_instance_valid(m.host) else "",
			stand = _v(m.stand_point), hotfix = m.hotfix})
	_data = {
		level = Progress.current_path(), level_name = game.level.level_name,
		round = game.round_index + 1, tester = r.tester_name, profile = r.profile,
		runner_start = _v(r.global_position), paint = marks,
		godot_time = Time.get_datetime_string_from_system(),
	}
	if not r.said.is_connected(_on_said):
		r.said.connect(_on_said)
	_event("start", {})


func _physics_process(delta: float) -> void:
	if not _on or not is_instance_valid(game) or not is_instance_valid(game.runner):
		return
	var r = game.runner
	_t += delta
	var st: String = r.State.keys()[r.state]
	if st != _last_state:
		var extra := {}
		if st == "JUMPING" and not r._path.is_empty():
			extra = {from = _v(r._jump_from), step = _step(r._path[0])}
		_event("state", {to = st, extra = extra})
		_last_state = st
	var plan := JSON.stringify(r._path.map(_step))
	if plan != _last_plan:
		_last_plan = plan
		_event("plan", {path = r._path.map(_step)})
	if r._retrace_to != _last_retrace:
		_last_retrace = r._retrace_to
		_event("retrace", {to = _v(r._retrace_to), trail = r._trail.map(_v), home_y = snappedf(r._home_y, 0.01),
			failed_jump = {from = _v(r._failed_jump.get("from", Vector3.INF)), to = _v(r._failed_jump.get("to", Vector3.INF))}})
	_sample_timer -= delta
	if _sample_timer <= 0.0:
		_sample_timer = SAMPLE_EVERY
		_samples.append({t = snappedf(_t, 0.01), feet = _v(r.feet()), state = st, home_y = snappedf(r._home_y, 0.01),
			wanders = r._wanders, lost = snappedf(r._lost_time, 0.1), shaken = r._shaken, trail = r._trail.size(),
			floor = r.is_on_floor()})


func finish(outcome: String) -> void:
	if not _on:
		return
	_on = false
	var r = game.runner
	_event("end", {outcome = outcome})
	_data.events = _events
	_data.samples = _samples
	_data.outcome = outcome
	_data.trail = r._trail.map(_v)
	_data.trail_from = r._trail_from.map(_v)
	_data.visited = r._visited.map(_v)
	_data.session_time = snappedf(r.session_time, 0.01)
	var dir := "res://debug_logs"
	if not DirAccess.dir_exists_absolute(dir):
		dir = "user://debug_logs"
		DirAccess.make_dir_recursive_absolute(dir)
	var stamp := Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
	var file_name := "%s/%s_%s_%s_%s.json" % [dir, Progress.current_path().get_file().get_basename(),
		String(r.tester_name).replace(" ", ""), outcome, stamp]
	var f := FileAccess.open(file_name, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(_data, " "))
		f.close()
		print("Playtest log saved: ", ProjectSettings.globalize_path(file_name))
		if game.message_label:
			game.message_label.text = "Playtest log saved: " + file_name.get_file()
	else:
		push_warning("Playtest log: can't write " + file_name)


func _on_said(text: String) -> void:
	if _on:
		_event("said", {text = text})


func _event(kind: String, info: Dictionary) -> void:
	var r = game.runner
	var e := {t = snappedf(_t, 0.01), kind = kind, feet = _v(r.feet()) if r.is_inside_tree() else null}
	e.merge(info)
	_events.append(e)


func _step(s: Dictionary) -> Dictionary:
	var out := {kind = s.get("kind", ""), pos = _v(s.pos), jump = s.get("jump", false)}
	for k in ["leap", "desperate", "coin_gamble", "overreach", "paint"]:
		if s.get(k, false):
			out[k] = true
	return out


func _v(v: Vector3) -> Variant:
	if not v.is_finite():
		return null
	return [snappedf(v.x, 0.01), snappedf(v.y, 0.01), snappedf(v.z, 0.01)]
