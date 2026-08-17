extends SceneTree
#
# Plays the game and checks what happened. The fourth verify command:
#
#   godot --headless --script res://tools/play.gd
#   godot --headless --script res://tools/play.gd -- --dump /tmp/run.json
#
# What this is for, and how it differs from the three that already exist.
#
#   verify.sh static  — does the project parse and import?
#   verify.sh sim     — does the simulation, with no UI attached, behave?
#   screenshot.gd     — were pixels drawn at all?
#   **this**          — does the assembled game, UI included, do what it should?
#
# The gap it closes is the one between "the simulation is correct" and "the
# thing the player touches is correct". `sim_runner.gd` runs RescueScene with no
# UI, which is exactly why it survived two renderer rewrites without noticing —
# and equally why it could not have caught a crew member drawn nine pixels below
# the room they are standing in, or a HUD panel that resolved to zero width.
#
# Time is driven by hand. main.gd's _process() is switched off and stepped with
# a fixed delta, so a run is reproducible in the way CLAUDE.md already requires
# of the RNG: same seed, same steps, same answers, every time and on every
# machine. Wall-clock frame timing is the one source of flake a real-time-with-
# pause game cannot afford in its own tests.
#
# GameProbe reads state; every judgement lives here. That split is deliberate —
# what is measured and what is expected should be arguable separately.

const STEP: float = 1.0 / 30.0
const MAX_STEPS: int = 4000
const SEED: int = 0

var _failures: Array[String] = []
var _skipped: Array[String] = []
var _checks: int = 0


func _init() -> void:
	var dump: String = _arg("--dump", "")

	var first: Array = await _run(dump)
	# Same seed, same steps, same answers. If this ever disagrees, something is
	# reading wall-clock time or an unseeded RNG, and every other check in this
	# file becomes unreliable rather than wrong — which is worse.
	var second: Array = await _run("")
	_check("determinism", first == second,
		"two runs of seed %d produced different state" % SEED)
	if first != second:
		_report_first_divergence(first, second)

	print("")
	for line: String in _skipped:
		print("SKIP ", line)
	if _failures.is_empty():
		print("play: OK (%d checks, %d skipped)" % [_checks, _skipped.size()])
		quit(0)
		return
	for line: String in _failures:
		printerr("FAIL ", line)
	printerr("play: %d of %d checks failed" % [_failures.size(), _checks])
	quit(1)


# One scripted playthrough. Returns the state trace, so two of them can be
# compared for determinism.
func _run(dump: String) -> Array:
	var packed: PackedScene = load("res://main.tscn") as PackedScene
	if packed == null:
		_fail("boot", "could not load res://main.tscn")
		return []
	var main: Node = packed.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	# Take the clock. From here nothing advances unless this script says so.
	main.set_process(false)

	var probe: GameProbe = GameProbe.new(main)
	var trace: Array = []

	# --- boot ---------------------------------------------------------------
	# The number one cause of "the game runs but the screen is empty", made into
	# an assertion rather than a warning in a document.
	#
	# Only under a real display. Headless Godot lays the root Control out against
	# a 64x64 stand-in window while its children resolve against the project
	# viewport, so every size is inconsistent and the assertion would pass on
	# meaningless numbers. Say so out loud rather than bank a fake green.
	if probe.layout_is_trustworthy():
		var collapsed: Array = probe.zero_sized_controls()
		_check("layout-zero", collapsed.is_empty(),
			"visible Controls resolved to zero size: %s"
				% ", ".join(PackedStringArray(collapsed)))
		# The check that actually bites. A Container with stale offsets shrinks
		# to its content instead of collapsing, so it is never zero-sized and
		# the check above sails past it.
		var shrunk: Array = probe.full_rect_not_filling()
		_check("layout-fill", shrunk.is_empty(),
			"anchored to fill their parent but do not: %s"
				% "; ".join(PackedStringArray(shrunk)))
	else:
		_skipped.append("layout — needs a display; run under xvfb-run")

	var boot: Dictionary = probe.snapshot()
	_check("boot-phase", boot["phase"] == "PROPOSAL",
		"expected to boot into PROPOSAL, got %s" % boot["phase"])
	_check("boot-crew", (boot["crew"] as Array).size() > 0, "no crew at boot")
	_check("boot-paused", not bool(boot["paused"]), "booted paused")

	# Everyone standing still should be drawn inside the compartment the
	# simulation says they are in. This is the check that would have caught the
	# -9 px sprite offset being wrong, and it is why the offset is now measured
	# by the renderer rather than guessed.
	for member: Dictionary in boot["crew"]:
		_check("crew-placement", bool(member.get("in_own_room", true)),
			"%s is in %s but stands outside it, at %s"
				% [member["name"], member["room"], member["at"]])
		# And the picture, separately. `at` being right and `drawn_at` being
		# wrong is precisely the shape of a bad art offset, and it is invisible
		# to any check that only asks the simulation where people are.
		_check("crew-art-offset", bool(member.get("drawn_in_own_room", true)),
			"%s stands in %s at %s but is drawn at %s, outside it"
				% [member["name"], member["room"], member["at"], member.get("drawn_at", [])])

	# --- the player chooses -------------------------------------------------
	# Pressed, not called. `scene.choose_plan("fight")` would skip main.gd's
	# button wiring entirely, and that wiring is exactly the kind of thing this
	# harness exists to cover — sim_runner.gd already proves the simulation works
	# when driven directly.
	var scene: RescueScene = main.get("scene") as RescueScene
	_check("plan-button", _press_plan(main, "Fight our way out"),
		"found no button for the 'fight' plan")
	_step(main, 1)
	_check("plan-phase", probe.snapshot()["phase"] == "ACTIVE",
		"pressing a plan button did not move the phase to ACTIVE")
	_check("plan-logged", probe.log_types().has("PLAN_CHOSEN"),
		"choosing a plan wrote no PLAN_CHOSEN event")

	# --- pause actually pauses ----------------------------------------------
	# CLAUDE.md forbids get_tree().paused precisely so the UI keeps running while
	# the simulation stops. That makes "is it really stopped?" a real question.
	scene.toggle_pause()
	var before: float = scene.time
	_step(main, 30)
	_check("pause", is_equal_approx(scene.time, before),
		"time advanced by %.2fs while paused" % (scene.time - before))
	scene.toggle_pause()

	# --- run it to the end --------------------------------------------------
	# The player is a loop: whenever nobody is busy, walk to the hold, then cut
	# people loose. Same policy sim_runner.gd uses, so the two harnesses are
	# playing the same game — but issued as clicks on the ship rather than as
	# calls into the simulation, so main.gd's click routing is under test too.
	var ship: ShipView = _find_ship(main)
	_check("ship-view", ship != null, "no ShipView in the scene tree")
	var hold: String = str(scene.config.get("captives_room", "cargo"))

	var steps: int = 0
	var seen_transit: bool = false
	while probe.snapshot()["phase"] != "RESOLVED" and steps < MAX_STEPS:
		if scene.task == RescueScene.Task.IDLE:
			_play_turn(ship, scene, hold)
		_step(main, 1)
		steps += 1
		var now: Dictionary = probe.snapshot()
		trace.append(_trace_row(now))

		if str((now["task"] as Dictionary)["name"]) == "TRANSIT":
			seen_transit = true

		# Invariants — true at every single step, not just at the end. Checked
		# silently and reported once, or a broken run prints four thousand lines.
		for room: Dictionary in now["rooms"]:
			if bool(room["over_capacity"]):
				_once("capacity", "%s holds %d crew, capacity %d"
					% [room["id"], (room["occupants"] as Array).size(), room["capacity"]])
		for member: Dictionary in now["crew"]:
			if int(member["hp"]) < 0:
				_once("hp", "%s has negative hp (%d)" % [member["name"], member["hp"]])

	_check("resolves", steps < MAX_STEPS,
		"mission did not resolve within %d steps (%.0fs of game time)"
			% [MAX_STEPS, float(MAX_STEPS) * STEP])
	_check("transit", seen_transit, "nobody ever walked anywhere")

	var end: Dictionary = probe.snapshot()
	_check("ending", scene.ending_text() != "", "resolved with no ending text")
	_check("freed", probe.log_types().has("CREW_FREED"),
		"resolved without freeing anybody")
	_check("arrived", probe.log_types().has("ARRIVED"),
		"resolved without anybody arriving anywhere")
	_check("no-captives", scene.tied_count() == 0,
		"resolved with %d crew still tied" % scene.tied_count())

	if dump != "":
		var file: FileAccess = FileAccess.open(dump, FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(end, "  "))
			file.close()
			print("wrote ", dump)

	print("play: resolved at t=%.1fs after %d steps" % [scene.time, steps])
	main.queue_free()
	await process_frame
	return trace


# --- driving the game like a player -----------------------------------------

# One decision, expressed as a click on the ship. Walk to the hold if not there,
# otherwise cut the next tied crew member loose.
func _play_turn(ship: ShipView, scene: RescueScene, hold: String) -> void:
	if ship == null:
		return
	if scene.tock.room != hold:
		ship.room_clicked.emit(hold)
		return
	for m: CrewMember in scene.crew:
		if m.is_tied():
			ship.crew_clicked.emit(m.id)
			return


# Presses the real Button, so main.gd's `pressed` wiring is what runs. Matched on
# the label the player reads rather than the plan id, because the id is bound
# into the callback and never appears on screen.
func _press_plan(node: Node, label: String) -> bool:
	var button: Button = node as Button
	if button != null and button.text.begins_with(label):
		button.pressed.emit()
		return true
	for child: Node in node.get_children():
		if _press_plan(child, label):
			return true
	return false


func _find_ship(node: Node) -> ShipView:
	var view: ShipView = node as ShipView
	if view != null:
		return view
	for child: Node in node.get_children():
		var found: ShipView = _find_ship(child)
		if found != null:
			return found
	return null


# Advances the game by exactly `count` fixed steps, through the same code path
# the engine would use. main.gd's _process is called directly because its
# automatic processing is switched off; that keeps the real update order —
# simulation tick, then UI refresh — instead of reimplementing it here and
# testing something the player never runs.
func _step(main: Node, count: int) -> void:
	for i: int in range(count):
		main._process(STEP)


# What goes in the determinism trace. Deliberately not the whole snapshot: UI
# layout and log text are not what determinism is about, and including them
# makes a failure hard to read.
func _trace_row(snap: Dictionary) -> Dictionary:
	var crew: Array = []
	for member: Dictionary in snap["crew"]:
		crew.append([member["id"], member["room"], member["hp"], member.get("at", [])])
	return {"t": snap["t"], "task": snap["task"], "crew": crew}


func _report_first_divergence(a: Array, b: Array) -> void:
	for i: int in range(mini(a.size(), b.size())):
		if a[i] != b[i]:
			printerr("  first divergence at step %d:" % i)
			printerr("    run 1: ", a[i])
			printerr("    run 2: ", b[i])
			return
	printerr("  runs agree for %d steps but differ in length (%d vs %d)"
		% [mini(a.size(), b.size()), a.size(), b.size()])


# --- reporting --------------------------------------------------------------

func _check(name: String, ok: bool, detail: String) -> void:
	_checks += 1
	if not ok:
		_fail(name, detail)


func _fail(name: String, detail: String) -> void:
	_failures.append("[%s] %s" % [name, detail])


# For invariants tested thousands of times: report the first breach and stop
# counting. A capacity bug that fires on every frame is one bug.
func _once(name: String, detail: String) -> void:
	for line: String in _failures:
		if line.begins_with("[%s]" % name):
			return
	_checks += 1
	_fail(name, detail)


func _arg(flag: String, fallback: String) -> String:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for i: int in range(args.size()):
		if args[i] == flag and i + 1 < args.size():
			return args[i + 1]
	return fallback
