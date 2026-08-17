extends RefCounted
class_name RescueScene

# The cargo hold rescue. Headless: no Node, no Control, no scene API.
#
# There is no fail state. Nobody dies in this scene — damage floors at 1 HP.
# That is a deliberate choice for the first playable slice, not an oversight.
#
# Pause is `time_scale`, 0.0 or 1.0, and every tick multiplies by it.
# CLAUDE.md: never get_tree().paused, because that freezes UI input too and
# this game is meant to be played from the paused state.

enum Phase { PROPOSAL, EXECUTING, RESOLVED }

# TRANSIT is gone: walking is per crew member and lives on CrewMember now, so a
# scene-wide "the task is transit" cannot express five people going five places.
# What is left here is the one thing that genuinely is scene-wide, because only
# TOCK does it and only one at a time — cutting a captive loose.
enum Task { IDLE, FREEING }

signal phase_changed(phase: int)

var phase: int = Phase.PROPOSAL
var plan: String = ""
var time: float = 0.0
var time_scale: float = 1.0

var layout: ShipLayout = null
var log_bus: LogBus = null
var rng: RunRng = null
var config: Dictionary = {}

var crew: Array[CrewMember] = []
var tock: CrewMember = null

var task: int = Task.IDLE
var task_remaining: float = 0.0

# How long the task in progress takes in total. Progress is measured against
# this rather than a constant.
var task_total: float = 0.0
var task_target: String = ""

var hack_active: bool = false
var hack_remaining: float = 0.0
var boarders_down: int = 0

var fight_active: bool = false
var fight_remaining: float = 0.0
var weapons_taken: bool = false

var _by_id: Dictionary = {}
var _said: Dictionary = {}
var _captive_ids: Array[String] = []


func _init(seed_in: int = 0) -> void:
	rng = RunRng.new(seed_in)
	log_bus = LogBus.new()
	layout = DataLoader.load_layout()
	config = DataLoader.load_scene()

	var roster: Array[CrewMember] = DataLoader.load_crew()
	for m: CrewMember in roster:
		_by_id[m.id] = m

	for raw_id: Variant in config.get("captives", []):
		_captive_ids.append(str(raw_id))

	var captives_room: String = str(config.get("captives_room", "cargo"))
	var max_hp: int = int(_timing().get("crew_max_hp", 100))

	for cid: String in _captive_ids:
		if not _by_id.has(cid):
			push_error("scene_rescue.json lists unknown crew id '%s'" % cid)
			continue
		var m: CrewMember = _by_id[cid] as CrewMember
		m.state = CrewMember.State.TIED
		m.room = captives_room
		m.max_hp = max_hp
		m.hp = max_hp
		crew.append(m)

	var tock_id: String = _find_synthetic_id()
	if tock_id != "":
		tock = _by_id[tock_id] as CrewMember
		tock.state = CrewMember.State.ACTIVE
		tock.room = str(config.get("tock_start_room", "weapons"))
		tock.max_hp = max_hp
		tock.hp = max_hp

	_emit("SCENE_START", LogEvent.NEUTRAL, [], {"seed": rng.seed_value})
	for line: Variant in config.get("opening", []):
		_emit("BRIEF", LogEvent.NEUTRAL, [], {"text": str(line)})


func _timing() -> Dictionary:
	return config.get("timing", {}) as Dictionary


func _find_synthetic_id() -> String:
	for key: Variant in _by_id.keys():
		var m: CrewMember = _by_id[key] as CrewMember
		if m.is_synthetic:
			return m.id
	return ""


# --- player commands -------------------------------------------------------

func choose_plan(plan_id: String) -> bool:
	if phase != Phase.PROPOSAL:
		return false
	if plan_id != "hack" and plan_id != "fight":
		return false

	plan = plan_id
	phase = Phase.EXECUTING
	phase_changed.emit(phase)
	_emit("PLAN_CHOSEN", LogEvent.WARNING, [], {"plan": plan_id})

	if plan_id == "hack":
		hack_active = true
		hack_remaining = float(_timing().get("hack_seconds", 18.0))
		_say("plan_hack")
	else:
		_say("plan_fight")
	return true


# Orders crew to a room. Accepts any reachable room, not only a neighbour, and
# walks the whole route. Ordering a new destination mid-walk re-routes from the
# room currently being entered, so nobody is made to wait out a hop they no
# longer want.
#
# `ids` empty means TOCK, which keeps every existing caller working unchanged.
# Returns true if **anybody** accepted: ordering five people into a room with
# space for three should move the three, not refuse all five.
func order_move(room_id: String, ids: Array[String] = []) -> bool:
	if phase != Phase.EXECUTING:
		return false

	var movers: Array[CrewMember] = []
	if ids.is_empty():
		if tock != null:
			movers.append(tock)
	else:
		for crew_id: String in ids:
			var m: CrewMember = get_crew(crew_id)
			if m != null:
				movers.append(m)

	# Everyone accepted leaves a beat after the one before. The first goes at
	# once, so a single crew member — every existing caller — is untouched.
	var stagger: float = float(_timing().get("squad_stagger_seconds", 0.9))
	var leaving: int = 0
	var any: bool = false
	for m: CrewMember in movers:
		if _order_one(m, room_id, stagger * float(leaving)):
			leaving += 1
			any = true
	return any


# One crew member, one destination. Everything that can refuse a move is here.
func _order_one(m: CrewMember, room_id: String, delay: float = 0.0) -> bool:
	if not m.can_take_orders():
		return false
	# TOCK cutting somebody loose is not interruptible by a walk order; the
	# captive would be left half-freed with no way to express that.
	if m == tock and task == Task.FREEING:
		return false

	var start: String = m.move_target if m.is_moving() else m.room
	if room_id == start:
		return false

	var route_to: Array[String] = layout.path(start, room_id)
	if route_to.is_empty():
		return false
	# Counted against the destination *including* whoever is already walking
	# there, so ordering six people into a room for four fills it and turns the
	# rest away, rather than all six being waved through because the room was
	# empty at the moment each of them was asked about.
	if not _room_has_space(room_id, m):
		_refuse_move(room_id, m)
		return false

	m.route = route_to
	# Only set on a fresh departure. Re-routing somebody already walking must not
	# stop them dead for a second in the middle of a corridor.
	if not m.is_committed():
		m.move_delay = maxf(delay, 0.0)
	_emit("MOVE_ORDERED", LogEvent.NEUTRAL, [m.id], {
		"to": room_id, "hops": m.route.size(),
		"seconds": snappedf(_route_seconds(m), 0.1),
	})
	if not m.is_committed():
		_begin_hop(m)
	return true


# The whole ordered walk, so the log can say how long the trip will take rather
# than how many rooms it passes. Hop count stopped being a useful number for the
# player the moment travel started costing distance.
func _route_seconds(m: CrewMember) -> float:
	var total: float = 0.0
	var at: String = m.room
	for room_id: String in m.route:
		total += transit_seconds(at, room_id)
		at = room_id
	return total


func _begin_hop(m: CrewMember) -> void:
	if m.route.is_empty():
		m.stop_moving()
		return
	if not _room_has_space(m.route[0], m):
		_refuse_move(m.route[0], m)
		m.stop_moving()
		return
	m.move_target = m.route[0]
	m.move_total = transit_seconds(m.room, m.move_target)
	m.move_remaining = m.move_total


# How long it takes to walk from one compartment to the next. Distance divided
# by speed, not a flat fee per hop: crossing the whole ship has to cost more
# than stepping across the corridor, or the ship's layout means nothing and it
# does not matter where anyone is standing.
#
# The distance comes precomputed from data/ship_layout.json, measured along the
# corridor. sim/ never reads a coordinate — ARCHITECTURE.md.
#
# Speed is per crew member from here on, which is what lets armour slow someone
# down later. Nobody has a modifier yet, so everyone walks at the scene's speed.
func transit_seconds(from_id: String, to_id: String) -> float:
	var speed: float = float(_timing().get("crew_walk_speed", 103.0))
	if speed <= 0.0:
		return 0.0
	return layout.walk_distance(from_id, to_id) / speed


# A compartment holds at most `capacity` bodies, friend or foe. TOCK is excluded
# from the count because he is the one trying to get in — he is still standing
# in the room he is leaving, and counting him there would let him walk into a
# room that is one over its limit while blocking him from one that is exactly
# full.
# Whether `mover` can fit in `room_id`.
#
# Counts everyone standing in the room plus everyone walking into it, minus the
# mover themselves — someone already heading there is not competing with
# themselves for a place. Committed occupancy rather than current occupancy is
# what makes ordering a squad behave: without it, five people asked one after
# another all see the same empty room and all set off for it.
func _room_has_space(room_id: String, mover: CrewMember = null) -> bool:
	var occupants: int = 0
	for m: CrewMember in all_hands():
		if m == mover:
			continue
		if m.room == room_id or m.move_target == room_id:
			occupants += 1
	return layout.has_space(room_id, occupants)


# Refusals are stated in the log, not left to be inferred from a click that did
# nothing. CLAUDE.md: if it matters, it writes a log line.
func _refuse_move(room_id: String, m: CrewMember) -> void:
	var room: ShipRoom = layout.get_room(room_id)
	_emit("MOVE_REFUSED", LogEvent.WARNING, [m.id], {
		"room": room_id,
		"reason": "full",
		"capacity": room.capacity if room != null else 0,
	})


func order_free(crew_id: String) -> bool:
	if phase != Phase.EXECUTING or task != Task.IDLE or tock == null:
		return false
	if tock.is_moving():
		return false
	var m: CrewMember = get_crew(crew_id)
	if m == null or not m.is_tied():
		return false
	if tock.room != m.room:
		return false
	task = Task.FREEING
	task_target = crew_id
	task_total = float(_timing().get("free_seconds", 6.0))
	task_remaining = task_total
	_emit("FREEING_STARTED", LogEvent.NEUTRAL, [crew_id], {})
	return true


func toggle_pause() -> void:
	time_scale = 0.0 if time_scale > 0.0 else 1.0


func is_paused() -> bool:
	return time_scale <= 0.0


# --- the tick --------------------------------------------------------------

func tick(delta: float) -> void:
	if phase != Phase.EXECUTING:
		return
	var dt: float = delta * time_scale
	if dt <= 0.0:
		return

	time += dt
	_tick_hack(dt)
	_tick_fight(dt)
	_tick_movement(dt)
	_tick_task(dt)
	_check_resolved()


func _tick_hack(dt: float) -> void:
	if not hack_active:
		return
	hack_remaining -= dt

	var total: float = float(_timing().get("hack_seconds", 18.0))
	var stagger: float = float(_timing().get("hack_stagger_seconds", 4.0))
	var count: int = boarder_count()

	if hack_remaining <= total * 0.5:
		_say("hack_progress")

	# Suits fail one at a time, `stagger` seconds apart, ending at zero. Two
	# separate log lines rather than one, because two people stopped breathing
	# at two different moments and the log is the record of what happened.
	var due: int = count - int(ceil(maxf(hack_remaining, 0.0) / stagger))
	while boarders_down < mini(due, count):
		boarders_down += 1
		_emit("BOARDER_DOWN", LogEvent.CRITICAL, [], {"index": boarders_down})

	if hack_remaining <= 0.0:
		hack_active = false
		_say("hack_done")


func _tick_fight(dt: float) -> void:
	if not fight_active:
		return
	fight_remaining -= dt
	if fight_remaining > 0.0:
		return

	fight_active = false
	var count: int = boarder_count()
	for i: int in range(count):
		_emit("BOARDER_DOWN", LogEvent.CRITICAL, [], {"index": i + 1})
	boarders_down = count

	# Everyone in the hold takes it, tied or not. Being restrained during a
	# firefight is worse than being loose in one, not better, and the ending
	# text says everybody is bleeding — so everybody has to actually bleed.
	# No fail state: damage floors at 1 HP, so nobody in this scene can die.
	var dmg: int = int(_timing().get("fight_damage_per_crew", 25))
	var hold: String = str(config.get("captives_room", "cargo"))
	for m: CrewMember in crew:
		if m.room == hold:
			m.take_damage(dmg, 1)
			_emit("CREW_INJURED", LogEvent.WARNING, [m.id], {"hp": m.hp})
	if tock != null and tock.room == hold:
		tock.take_damage(dmg, 1)
		_emit("CREW_INJURED", LogEvent.WARNING, [tock.id], {"hp": tock.hp})

	_say("fight_done")


# Everyone walking advances, independently, in the same tick.
#
# Iterated over a snapshot of the roster because arriving can free somebody,
# which appends to `crew`, and mutating a list mid-loop is the kind of bug that
# shows up as one crew member silently skipping a hop.
func _tick_movement(dt: float) -> void:
	for m: CrewMember in all_hands():
		if not m.is_committed():
			continue
		# Waiting their turn to leave. The delay burns first and any remainder of
		# the tick spills into the walk, so a staggered squad moves at one speed
		# rather than the back of the queue being quietly slower.
		#
		# `step`, not `dt` — `dt` is the whole loop's, and decrementing it here
		# would steal time from every crew member checked after this one.
		var step: float = dt
		if m.move_delay > 0.0:
			m.move_delay -= step
			if m.move_delay > 0.0:
				continue
			step = -m.move_delay
			m.move_delay = 0.0
		m.move_remaining -= step
		if m.move_remaining > 0.0:
			continue
		m.room = m.move_target
		_emit("ARRIVED", LogEvent.NEUTRAL, [m.id], {"room": m.room})
		if not m.route.is_empty():
			m.route.pop_front()
		_begin_hop(m)
		if m == tock:
			_on_arrived()


func _tick_task(dt: float) -> void:
	if task == Task.IDLE:
		return
	task_remaining -= dt
	if task_remaining > 0.0:
		return

	if task == Task.FREEING:
		var m: CrewMember = get_crew(task_target)
		var freed_id: String = task_target
		task = Task.IDLE
		task_target = ""
		if m != null:
			m.state = CrewMember.State.ACTIVE
			_emit("CREW_FREED", LogEvent.WARNING, [m.id], {"name": m.display_name})
			_say("freed_%s" % m.id)
		_on_freed(freed_id)


func _on_arrived() -> void:
	if tock.room != str(config.get("captives_room", "cargo")):
		return
	_say("arrived_cargo")
	if plan == "fight" and not weapons_taken:
		weapons_taken = true
		_emit("WEAPONS_TAKEN", LogEvent.WARNING, [], {})
		_say("weapons_taken")
		fight_active = true
		fight_remaining = float(_timing().get("fight_seconds", 12.0))
		_emit("FIGHT_STARTED", LogEvent.CRITICAL, [], {})
		_say("fight_start")


func _on_freed(_freed_id: String) -> void:
	if tied_count() > 0:
		return
	if plan == "hack":
		_say("all_free_hack")
	else:
		_say("all_free_fight")


# Resolved means nothing is still in flight. Movement left the task system, so
# "task is idle" stopped being the whole answer — a scene that resolved while
# somebody was still walking would cut the mission off mid-stride.
func _check_resolved() -> void:
	if tied_count() > 0 or hack_active or fight_active or task != Task.IDLE:
		return
	if anyone_moving():
		return
	phase = Phase.RESOLVED
	phase_changed.emit(phase)
	_emit("SCENE_RESOLVED", LogEvent.CRITICAL, [], {
		"plan": plan,
		"freed": crew.size(),
		"seconds": snappedf(time, 0.1),
	})


# --- queries ---------------------------------------------------------------

func boarder_count() -> int:
	return int(_timing().get("boarder_count", 2))


func get_crew(crew_id: String) -> CrewMember:
	if _by_id.has(crew_id):
		return _by_id[crew_id] as CrewMember
	return null


func tied_count() -> int:
	var n: int = 0
	for m: CrewMember in crew:
		if m.is_tied():
			n += 1
	return n


# Everyone aboard, TOCK included. `crew` deliberately holds only the captives,
# so anything that means "every person on this ship" has to say so.
func all_hands() -> Array[CrewMember]:
	var out: Array[CrewMember] = []
	if tock != null:
		out.append(tock)
	out.append_array(crew)
	return out


# True while TOCK has something in hand — walking or cutting someone loose.
# This is what "can I give the next order yet?" means, and it is the question
# both harnesses ask.
func is_busy() -> bool:
	if task != Task.IDLE:
		return true
	return tock != null and tock.is_committed()


func anyone_moving() -> bool:
	for m: CrewMember in all_hands():
		if m.is_committed():
			return true
	return false


func crew_in_room(room_id: String) -> Array[CrewMember]:
	var out: Array[CrewMember] = []
	for m: CrewMember in crew:
		if m.room == room_id:
			out.append(m)
	if tock != null and tock.room == room_id:
		out.append(tock)
	return out


func task_progress() -> float:
	if task == Task.IDLE or task_total <= 0.0:
		return 0.0 if task == Task.IDLE else 1.0
	return clampf(1.0 - (task_remaining / task_total), 0.0, 1.0)


func ending_text() -> String:
	var endings: Dictionary = config.get("endings", {}) as Dictionary
	return str(endings.get(plan, "SCENE COMPLETE."))


# --- internals -------------------------------------------------------------

func _emit(
	type: String,
	severity: String,
	subjects: Array[String],
	values: Dictionary
) -> void:
	log_bus.emit_event(type, severity, subjects, values, time)


# TOCK never says anything the log has not already stated in plain form
# (VOICE_AND_EVENTS §3), so every _say() follows a plain _emit(). A line fires
# at most once.
func _say(key: String) -> void:
	if _said.has(key):
		return
	var lines: Dictionary = config.get("lines", {}) as Dictionary
	if not lines.has(key):
		return
	_said[key] = true
	log_bus.emit_event("TOCK_LINE", LogEvent.NEUTRAL, ["tock"], {"key": key, "text": str(lines[key])}, time)
