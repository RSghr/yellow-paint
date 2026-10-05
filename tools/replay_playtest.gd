extends SceneTree
## DEBUG: replays a playtest log (debug_logs/*.json, written by playtest_recorder.gd) headless:
## same level, same round's tester, same paint. Prints how each rerun went and its key events.
##   godot --headless --fixed-fps 60 --path . --script tools/replay_playtest.gd -- debug_logs/<file>.json [runs] [seconds]

func _init() -> void:
	_go.call_deferred()


func _go() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		print("usage: --script tools/replay_playtest.gd -- debug_logs/<file>.json [runs] [seconds]")
		quit()
		return
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	var runs := int(args[1]) if args.size() > 1 else 5
	var seconds := float(args[2]) if args.size() > 2 else 300.0
	print("log: ", data.level_name, " round ", data.round, " ", data.tester, " ", data.profile, " -> ", data.outcome,
		" after ", data.session_time, " s, ", data.paint.size(), " splats")
	var progress = root.get_node("Progress")
	for run in runs:
		progress.current = progress.LEVELS.map(func(l): return l.path).find(data.level)
		var game = load("res://game.tscn").instantiate()
		root.add_child(game)
		for i in 5:
			await physics_frame
		var r = game.runner
		r.apply_profile(data.tester, load("res://focus_group.gd").ROSTER[data.tester])
		var space = game.paint.get_world_3d().direct_space_state
		var missed := 0
		for m in data.paint:
			if m.hotfix:
				continue
			var p := Vector3(m.pos[0], m.pos[1], m.pos[2])
			var n := Vector3(m.normal[0], m.normal[1], m.normal[2])
			var hit = space.intersect_ray(PhysicsRayQueryParameters3D.create(p + n * 0.3, p - n * 0.3, 1))
			if hit:
				game.paint.paint(hit.position, hit.normal, hit.collider)
			else:
				missed += 1
		var log := []
		r.said.connect(func(t): log.append("%5.1fs y%5.1f  \"%s\"" % [r.session_time, r.feet().y, t]))
		var ev := InputEventAction.new()
		ev.action = "start_test"
		ev.pressed = true
		game._unhandled_input(ev)
		var last_state := -1
		var f := 0
		while f < 60 * seconds and not game._finished and r.state != r.State.DEAD:
			await physics_frame
			f += 1
			if r.state != last_state:
				if r.state == r.State.JUMPING and not r._path.is_empty():
					var s: Dictionary = r._path[0]
					log.append("%5.1fs y%5.1f  JUMP %s -> %s%s" % [r.session_time, r.feet().y, s.get("kind", ""),
						s.pos.snapped(Vector3.ONE * 0.1), " (gamble)" if s.get("desperate", false) else ""])
				last_state = r.state
		var outcome := "FLAG" if game._finished else ("DEAD" if r.state == r.State.DEAD else "TIMEOUT")
		print("run %d: %s at %.0fs, y %.1f, failed jumps %d%s" % [run, outcome, r.session_time, r.feet().y, r.failed_jumps,
			(", %d splats not found" % missed) if missed else ""])
		if OS.get_environment("VERBOSE") != "":
			for l in log:
				print("    ", l)
		game.queue_free()
		await process_frame
	quit()
