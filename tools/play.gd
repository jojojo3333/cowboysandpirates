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

	await _check_boot_scene()
	await _check_boarders()
	await _check_cutscene()
	await _check_selection()
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


# The scene the game actually starts in, which is not the one played below.
#
# `main.tscn` is the combat-preview composition; the rescue mission lives in
# `rescue_scene.tscn` and is what everything else here drives. Nothing looked at
# the boot scene at all until a UI pass arrived with a helper named
# `draw_ellipse`, colliding with CanvasItem's own method of that name in Godot
# 4.7 — a hard parse error that stopped the whole project loading.
#
# **`verify.sh static` catches that one, and this does not.** Measured, not
# assumed: reintroduced deliberately, `static` goes red on the parse error while
# this check stays green, because Godot serves `main.tscn` from its compiled
# cache and hands back a scene that instantiates perfectly well. Compile errors
# belong to `static`; do not expect a second catch here.
#
# What this does cover is the failure `static` cannot see: a boot scene that
# compiles, loads, and then builds nothing — no script attached, no children, or
# Controls that collapse. That is a live risk now the launch scene is a
# composition assembled entirely in `_ready()`.
func _check_boot_scene() -> void:
	var boot_path: String = str(
		ProjectSettings.get_setting("application/run/main_scene", "res://main.tscn")
	)
	var packed: PackedScene = load(boot_path) as PackedScene
	_check("boot-scene-loads", packed != null, "could not load the boot scene %s" % boot_path)
	if packed == null:
		return

	var node: Node = packed.instantiate()
	root.add_child(node)
	for i: int in range(4):
		await process_frame

	# `load()` succeeding is not the same as the scene working, and this is the
	# distinction the first version of this check missed. When the attached
	# script fails to compile, Godot still hands back a perfectly good
	# PackedScene — the .tscn parses, it is only the script resource that died —
	# so it instantiates into a bare, scriptless Control with no children. Every
	# layout assertion then passes triumphantly on an empty node.
	#
	# A scene whose script did not load has no script and builds nothing. Both
	# are worth asserting, because they fail in that order.
	_check("boot-scene-script", node.get_script() != null,
		"%s instantiated with no script attached; its script failed to compile" % boot_path)
	_check("boot-scene-built", node.get_child_count() > 0,
		"%s built no UI at all — _ready() did not run or did nothing" % boot_path)

	# Every scene the menu offers must actually be there. The menu greys out a
	# missing entry so a human sees it, but only if a human opens the menu —
	# this is the same question asked without one, on every run.
	var entries: Variant = node.get("ENTRIES")
	if entries is Array:
		for entry: Dictionary in entries as Array:
			var path: String = str(entry.get("scene", ""))
			_check("menu-entry", ResourceLoader.exists(path),
				"the menu offers '%s' but %s does not exist" % [entry.get("title", "?"), path])
			_check("menu-entry-loads", load(path) != null,
				"the menu offers '%s' but %s failed to load" % [entry.get("title", "?"), path])
	else:
		_skipped.append("menu-entry — the boot scene exposes no ENTRIES list")

	var probe: GameProbe = GameProbe.new(node)
	if probe.layout_is_trustworthy():
		var collapsed: Array = probe.zero_sized_controls()
		_check("boot-scene-layout", collapsed.is_empty(),
			"%s has visible Controls of zero size: %s"
				% [boot_path, ", ".join(PackedStringArray(collapsed))])
	else:
		_skipped.append("boot-scene-layout — needs a display; run under xvfb-run")

	node.queue_free()
	await process_frame
	await _check_early_input()


# Every scene, poked with a mouse on the frame it appears.
#
# This is a regression check for a real crash: `ShipView` builds its Node2D
# world on the first `_process` that has both a scene and a layout, but
# `_gui_input` starts arriving as soon as the node is in the tree. Since the
# pointer is usually already over the window when a scene loads, the very first
# event is a mouse motion into a half-built view — `to_plate()` dereferenced a
# null `_world` and the combat screen died on load.
#
# **Nothing here caught it**, and the reason is worth keeping: every existing
# check drives a scene that has already settled for several frames. The
# dangerous frame is the first one, so this pokes exactly that.
func _check_early_input() -> void:
	# A bare view first, and this is the version that actually reproduces it.
	#
	# Poking a real scene after `await process_frame` turned out to be a race:
	# whether `_build()` has run by then depends on frame ordering, and it
	# differed between the two scenes and between running this alone and running
	# it after other checks. A test that only sometimes exercises the broken path
	# is worse than none, because it reports green and means nothing. A freshly
	# constructed ShipView has no scene, no layout and no world, always.
	var bare: ShipView = ShipView.new()
	bare.size = Vector2(400.0, 300.0)
	root.add_child(bare)
	_poke(bare)
	bare.queue_free()
	await process_frame

	for path: String in ["res://main_combat.tscn", "res://rescue_scene.tscn"]:
		var packed: PackedScene = load(path) as PackedScene
		if packed == null:
			continue
		var node: Node = packed.instantiate()
		root.add_child(node)
		# Deliberately no frame awaited: this is the state a scene is in at the
		# instant it enters the tree, which is when the first mouse event lands.
		var ship: ShipView = _find_ship(node)
		if ship != null:
			_poke(ship)
		# **There is no assertion here on purpose, and that needs explaining.**
		# A GDScript runtime error prints `SCRIPT ERROR` and carries on — it does
		# not raise, cannot be caught, and does not fail the run. So a check like
		# `_check("early-input", true, ...)` would be a check that cannot fail,
		# which is worth nothing. What catches this is `tools/verify.sh play`
		# grepping the output for SCRIPT ERROR, exactly as `verify.sh static`
		# already does. This function's job is to *provoke* the error; the
		# runner's job is to notice it.
		node.queue_free()
		await process_frame


# A move, a press, a drag and a release, at whatever state the view is in.
func _poke(ship: ShipView) -> void:
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = Vector2(200.0, 150.0)
	ship._gui_input(motion)

	var press: InputEventMouseButton = InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = Vector2(200.0, 150.0)
	ship._gui_input(press)

	var moved: InputEventMouseMotion = InputEventMouseMotion.new()
	moved.position = Vector2(320.0, 260.0)
	ship._gui_input(moved)

	var release: InputEventMouseButton = InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = Vector2(320.0, 260.0)
	ship._gui_input(release)


# One scripted playthrough. Returns the state trace, so two of them can be
# compared for determinism.
func _run(dump: String) -> Array:
	var packed: PackedScene = load("res://rescue_scene.tscn") as PackedScene
	if packed == null:
		_fail("boot", "could not load res://rescue_scene.tscn")
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
		if not scene.is_busy():
			_play_turn(ship, scene, hold)
		_step(main, 1)
		steps += 1
		var now: Dictionary = probe.snapshot()
		trace.append(_trace_row(now))

		if not probe.movers().is_empty():
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


# Boarders are real: they exist, they stand somewhere, they are drawn, and the
# player cannot command them.
#
# That last one is the part worth a check. A boarder is the same class of object
# as a crew member and passes `can_take_orders()`, so nothing but an explicit
# rule stops a selection box scooping up four pirates and marching them into the
# hold. The rule lives in the UI, where the player is; the simulation keeps
# taking orders for them because a cutscene has to be able to move them.
func _check_boarders() -> void:
	var packed: PackedScene = load("res://rescue_scene.tscn") as PackedScene
	if packed == null:
		return
	var main: Node = packed.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	main.set_process(false)

	var scene: RescueScene = main.get("scene") as RescueScene
	var probe: GameProbe = GameProbe.new(main)
	var ship: ShipView = _find_ship(main)

	_check("boarders-exist", scene.hostiles().size() == 4,
		"expected 4 boarders aboard, found %d" % scene.hostiles().size())

	for m: CrewMember in scene.hostiles():
		_check("boarder-room", scene.layout.get_room(m.room) != null,
			"%s is in '%s', which is not a room on this ship" % [m.id, m.room])
		_check("boarder-hostile", m.is_hostile, "%s is aboard but not marked hostile" % m.id)

	# Drawn where the simulation says they are, same as anybody else.
	for member: Dictionary in probe.snapshot()["crew"]:
		if not str(member["id"]).begins_with("pirate"):
			continue
		_check("boarder-drawn", bool(member.get("drawn_in_own_room", false)),
			"%s stands in %s but is drawn at %s, outside it"
				% [member["id"], member["room"], member.get("drawn_at", [])])

	# A box over the whole ship must pick up crew and no pirates.
	if ship != null:
		_drag(ship, Vector2(-4000.0, -4000.0), Vector2(4000.0, 4000.0))
		await process_frame
		var picked: Array = probe.selected()
		var hostile_picked: Array = []
		for id: Variant in picked:
			var m: CrewMember = scene.get_crew(str(id))
			if m != null and m.is_hostile:
				hostile_picked.append(id)
		_check("boarders-unselectable", hostile_picked.is_empty(),
			"a selection box picked up boarders: %s" % [hostile_picked])

	main.queue_free()
	await process_frame


# The cutscene runs, and it runs headlessly.
#
# **This is the check that says an in-engine cutscene is a real system rather
# than an animation.** If a scripted sequence can only be judged by a person
# watching it, every future cutscene costs a person watching it. Because the
# timeline lives in `sim/` and issues ordinary move orders, the whole thing can
# be run with no window open and asserted on: everyone started here, everyone
# ended there, and it finished rather than hanging.
func _check_cutscene() -> void:
	var scene: RescueScene = RescueScene.new(0)
	scene.choose_plan("hack")
	var config: Dictionary = DataLoader.load_json("res://data/mission_01.json")
	var cutscenes: Dictionary = config.get("cutscenes", {}) as Dictionary
	var boarding: Dictionary = cutscenes.get("boarding", {}) as Dictionary
	_check("cutscene-data", not boarding.is_empty(),
		"data/mission_01.json has no 'boarding' cutscene")
	if boarding.is_empty():
		return

	var cut: Cutscene = Cutscene.from_config(scene, boarding)
	cut.start()

	# Staged before a single tick.
	for m: CrewMember in scene.hostiles():
		_check("cutscene-staging", m.room == "airlock",
			"%s should be staged in the airlock, is in %s" % [m.id, m.room])

	var steps: int = 0
	while cut.playing and steps < MAX_STEPS:
		cut.tick(STEP)
		scene.tick(STEP)
		steps += 1

	_check("cutscene-finishes", not cut.playing,
		"the boarding cutscene did not finish within %.0fs" % (float(MAX_STEPS) * STEP))
	_check("cutscene-progress", is_equal_approx(cut.progress(), 1.0),
		"cutscene finished reporting %.2f progress" % cut.progress())
	for m: CrewMember in scene.hostiles():
		_check("cutscene-arrival", m.room == "quarters",
			"%s should have reached the quarters, is in %s" % [m.id, m.room])
	# It has to take time. A cutscene that completes on the first tick means the
	# beats fired but nobody actually walked anywhere.
	_check("cutscene-takes-time", scene.time > 1.0,
		"the cutscene resolved in %.2fs of game time; nobody walked" % scene.time)


# Box-select, then order everyone at once.
#
# **In its own scene, deliberately.** Two constraints leave nowhere else to put
# it. It cannot run after the mission resolves, because a resolved scene refuses
# every order and the check would fail for the wrong reason. And it must not run
# *inside* the played mission, because issuing extra orders would change how
# long the mission takes — the balance canary would move, and it would move
# because of the test rather than because of the game, which is the one thing
# that number must never do.
#
# So: a third run, played only as far as the first captive being cut loose. That
# is the earliest moment more than one person can walk — until then TOCK is the
# entire mobile roster and a multi-crew order is indistinguishable from a single
# one — and it stops well short of resolution, leaving the scene live.
func _check_selection() -> void:
	var packed: PackedScene = load("res://rescue_scene.tscn") as PackedScene
	if packed == null:
		return
	var main: Node = packed.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	main.set_process(false)

	var scene: RescueScene = main.get("scene") as RescueScene
	var probe: GameProbe = GameProbe.new(main)
	var ship: ShipView = _find_ship(main)
	if ship == null:
		_fail("select-setup", "no ShipView in the scene tree")
		return

	_press_plan(main, "Fight our way out")
	_step(main, 1)
	var hold: String = str(scene.config.get("captives_room", "cargo"))

	# Walk to the hold and cut exactly one person loose, then stop.
	var steps: int = 0
	while _commandable(ship).size() < 2 and steps < MAX_STEPS:
		if not scene.is_busy():
			_play_turn(ship, scene, hold)
		_step(main, 1)
		steps += 1
	_check("select-setup", _commandable(ship).size() >= 2,
		"could not get two crew able to take orders; only %s" % [_commandable(ship)])
	if _commandable(ship).size() < 2:
		return

	# A box over the whole ship: everyone who can take an order should be in it.
	var commandable: Array = _commandable(ship)

	_drag(ship, Vector2(-4000.0, -4000.0), Vector2(4000.0, 4000.0))
	await process_frame
	var picked: Array = probe.selected()
	picked.sort()
	commandable.sort()
	_check("select-all", picked == commandable,
		"a box over the whole ship selected %s, expected %s" % [picked, commandable])

	# An empty patch of space selects nobody. This is how a player clears a
	# selection, so it has to actually clear it rather than leave the old one.
	_drag(ship, Vector2(-4000.0, -4000.0), Vector2(-3900.0, -3900.0))
	await process_frame
	_check("select-none", probe.selected().is_empty(),
		"a box over empty space left %s selected" % [probe.selected()])

	# And the point of the whole exercise: select everyone, order one room, and
	# check that more than one person actually sets off.
	_drag(ship, Vector2(-4000.0, -4000.0), Vector2(4000.0, 4000.0))
	await process_frame
	var destination: String = _far_room(scene, ship)
	_check("select-order-room", destination != "", "found no room to order the squad to")
	if destination == "":
		return
	ship.room_clicked.emit(destination)
	_step(main, 2)

	var moving: Array = probe.movers()
	_check("multi-move", moving.size() > 1,
		"ordered %d selected crew to %s but only %s set off"
			% [probe.selected().size(), destination, moving])
	for member: Dictionary in probe.snapshot()["crew"]:
		if not bool(member["moving"]) and not bool(member["waiting_to_leave"]):
			continue
		_check("multi-move-target", str(member["route"][member["route"].size() - 1]) == destination,
			"%s was ordered to %s but is routed to %s"
				% [member["name"], destination, member["route"]])

	# **The squad must not walk as one body.** Ordered together, everyone leaves
	# on the same tick, walks the same corridor at the same speed and occupies
	# the same pixel for the whole journey — the player sees one figure set off
	# and two arrive. They now leave one after another, and this is the check
	# that says so: step into the middle of the walk and measure the gap.
	_step(main, 40)
	var seen: Dictionary = {}
	var closest: float = INF
	var pair: String = ""
	for member: Dictionary in probe.snapshot()["crew"]:
		if not bool(member["moving"]):
			continue
		var at: Vector2 = Vector2(float(member["at"][0]), float(member["at"][1]))
		for other_id: String in seen:
			var gap: float = at.distance_to(seen[other_id] as Vector2)
			if gap < closest:
				closest = gap
				pair = "%s and %s" % [other_id, member["name"]]
		seen[str(member["name"])] = at
	if seen.size() > 1:
		# A figure is about 35 px wide on the plate at crew scale. Anything under
		# that and they are drawn on top of one another.
		_check("squad-spacing", closest > 35.0,
			"%s are %.0f px apart mid-walk; they read as one person" % [pair, closest])
	else:
		_skipped.append("squad-spacing — fewer than two crew were walking at once")

	main.queue_free()
	await process_frame


# Everyone the player could actually give an order to right now.
#
# Hostiles are excluded, matching the rule in ShipView. They pass
# `can_take_orders()` — a boarder is the same class of object as a crew member
# and the simulation will happily move one, because a cutscene has to be able
# to. Only the player is forbidden, so only the player's side of the line
# filters them out. Leaving them in here made this helper report five
# commandable crew at boot, so the mission never bothered freeing anybody.
func _commandable(ship: ShipView) -> Array:
	var out: Array = []
	for member: CrewMember in ship.all_crew():
		if member.is_hostile or not member.can_take_orders():
			continue
		out.append(member.id)
	out.sort()
	return out


# A room nobody is currently standing in, with space for the whole squad —
# ordering people to the room they are already in is correctly refused, which
# would make the check above pass for the wrong reason.
func _far_room(scene: RescueScene, ship: ShipView) -> String:
	var crowd: int = 0
	for member: CrewMember in ship.all_crew():
		if member.can_take_orders():
			crowd += 1
	for room: ShipRoom in scene.layout.rooms:
		if not scene.crew_in_room(room.id).is_empty():
			continue
		if room.capacity >= crowd:
			return room.id
	return ""


# Press, move, release, as the mouse would. Coordinates are in plate space and
# converted back, so a test can say "the whole ship" without knowing the zoom.
func _drag(ship: ShipView, from_plate: Vector2, to_plate: Vector2) -> void:
	var press: InputEventMouseButton = InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = ship.to_screen(from_plate)
	ship._gui_input(press)

	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = ship.to_screen(to_plate)
	ship._gui_input(motion)

	var release: InputEventMouseButton = InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = ship.to_screen(to_plate)
	ship._gui_input(release)


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
