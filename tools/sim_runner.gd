extends SceneTree
#
# Headless harness. Drives RescueScene to completion with no UI attached, which
# is only possible because sim/ imports nothing from ui/ (ARCHITECTURE.md §1).
#
#   godot --headless --script res://tools/sim_runner.gd -- --runs 200
#
# Invocation spelling is fixed by GAME_SPEC_v0.1 acceptance criterion 7.
#
# This scene has no fail state, so there is no win rate to report yet. What the
# harness proves instead: both plans reach RESOLVED, every captive ends ACTIVE,
# nobody drops below 1 HP, both boarders go down, and the run is reproducible.
# Slice 2 replaces this with a real win-rate report once combat exists.

const TICK: float = 1.0 / 20.0
const MAX_SECONDS: float = 600.0

var failures: int = 0


func _init() -> void:
	var runs: int = _arg_int("--runs", 200)
	print("sim_runner: %d runs per plan" % runs)

	for plan: String in ["hack", "fight"]:
		_run_plan(plan, runs)

	print("")
	if failures == 0:
		print("sim_runner: OK")
		quit(0)
	else:
		printerr("sim_runner: %d failure(s)" % failures)
		quit(1)


func _run_plan(plan: String, runs: int) -> void:
	var durations: Array[float] = []
	var crashes: int = 0
	var first_hp: Array[int] = []

	for i: int in range(runs):
		var result: Dictionary = _play_once(plan, i + 1)
		if not bool(result.get("resolved", false)):
			crashes += 1
			if crashes == 1:
				printerr("  plan %s: run %d did not resolve (seed %d)" % [
					plan, i + 1, int(result.get("seed", 0))
				])
			continue
		durations.append(float(result.get("seconds", 0.0)))
		if i == 0:
			first_hp = result.get("hp", []) as Array[int]

	var mean: float = 0.0
	for d: float in durations:
		mean += d
	if not durations.is_empty():
		mean /= float(durations.size())

	print("")
	print("plan %-6s  resolved %d/%d  mean %5.1fs  min %5.1fs  max %5.1fs" % [
		plan, durations.size(), runs, mean,
		durations.min() if not durations.is_empty() else 0.0,
		durations.max() if not durations.is_empty() else 0.0,
	])
	print("              end HP: %s" % str(first_hp))

	if crashes > 0:
		failures += 1
	if durations.is_empty():
		failures += 1
		return

	# Determinism: identical seeds must produce identical durations. This is the
	# property that makes a failing run replayable, per GAME_SPEC_v0.1 §8.
	if durations.min() != durations.max():
		printerr("  plan %s: NOT DETERMINISTIC — durations ranged %.2f..%.2f" % [
			plan, durations.min(), durations.max()
		])
		failures += 1


func _play_once(plan: String, seed_in: int) -> Dictionary:
	var scene: RescueScene = RescueScene.new(seed_in)
	scene.choose_plan(plan)

	var elapsed: float = 0.0
	while scene.phase != RescueScene.Phase.RESOLVED and elapsed < MAX_SECONDS:
		if scene.task == RescueScene.Task.IDLE:
			_issue_next_order(scene)
		scene.tick(TICK)
		elapsed += TICK

	var hp: Array[int] = []
	var all_active: bool = true
	for m: CrewMember in scene.crew:
		hp.append(m.hp)
		if not m.is_active():
			all_active = false
		if m.hp < 1:
			all_active = false

	var resolved: bool = scene.phase == RescueScene.Phase.RESOLVED
	if resolved and not all_active:
		printerr("  plan %s seed %d: a captive did not end ACTIVE above 0 HP" % [plan, seed_in])
		failures += 1
	if resolved and scene.boarders_down != scene.boarder_count():
		printerr("  plan %s seed %d: %d boarders down, expected %d" % [
			plan, seed_in, scene.boarders_down, scene.boarder_count()
		])
		failures += 1

	return {
		"resolved": resolved,
		"seconds": scene.time,
		"seed": seed_in,
		"hp": hp,
	}


# Plays the scene the way a competent player would: walk to the hold, then cut
# everyone loose in roster order.
func _issue_next_order(scene: RescueScene) -> void:
	var hold: String = str(scene.config.get("captives_room", "cargo"))

	if scene.tock.room == hold:
		for m: CrewMember in scene.crew:
			if m.is_tied():
				scene.order_free(m.id)
				return
		return

	var step: String = _next_hop(scene.layout, scene.tock.room, hold)
	if step != "":
		scene.order_move(step)


# Breadth-first over the adjacency list. The runner is allowed to path-find;
# the player is not, because GAME_SPEC_v0.1 §2 rules pathfinding out of scope
# and the UI only ever offers adjacent rooms.
func _next_hop(layout: ShipLayout, from_id: String, to_id: String) -> String:
	if from_id == to_id:
		return ""
	var queue: Array[String] = [from_id]
	var came_from: Dictionary = {from_id: ""}

	while not queue.is_empty():
		var current: String = queue.pop_front()
		if current == to_id:
			var node: String = to_id
			while str(came_from[node]) != from_id and str(came_from[node]) != "":
				node = str(came_from[node])
			return node
		var room: ShipRoom = layout.get_room(current)
		if room == null:
			continue
		for neighbour: String in room.adjacent:
			if not came_from.has(neighbour):
				came_from[neighbour] = current
				queue.append(neighbour)
	return ""


func _arg_int(flag: String, fallback: int) -> int:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for i: int in range(args.size()):
		if args[i] == flag and i + 1 < args.size():
			return int(args[i + 1])
		if args[i].begins_with(flag + "="):
			return int(args[i].split("=")[1])
	return fallback
