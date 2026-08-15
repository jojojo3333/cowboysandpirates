extends RefCounted
class_name ShipLayout

# Rooms and adjacency, loaded from data/ship_layout.json. Adjacency is what
# movement costs in this scene and what fire spreads along in v0.2.

var rooms: Array[ShipRoom] = []

# Everything below is for the viewer. The simulation reads `adjacent` only —
# see path() — so a ship's shape can change without the sim noticing.
var plate_path: String = ""
var plate_normal_path: String = ""
var plate_size: Vector2 = Vector2(1848.0, 855.0)
var doors: Array[Dictionary] = []

var _by_id: Dictionary = {}


# Where two rooms connect on the plate. Crew walk through this rather than
# straight between room centres.
func door_between(a: String, b: String) -> Vector2:
	for d: Dictionary in doors:
		var pair: Array = d.get("between", []) as Array
		if pair.size() == 2 and ((pair[0] == a and pair[1] == b) or (pair[0] == b and pair[1] == a)):
			return d.get("at", Vector2.ZERO) as Vector2
	# No authored door: fall back to the midpoint, which is what the view did
	# for every pair before doors existed.
	var ra: ShipRoom = get_room(a)
	var rb: ShipRoom = get_room(b)
	if ra == null or rb == null:
		return Vector2.ZERO
	return (ra.centre() + rb.centre()) * 0.5


func add_room(room: ShipRoom) -> void:
	rooms.append(room)
	_by_id[room.id] = room


func get_room(room_id: String) -> ShipRoom:
	if _by_id.has(room_id):
		return _by_id[room_id] as ShipRoom
	return null


func has_room(room_id: String) -> bool:
	return _by_id.has(room_id)


func are_adjacent(a: String, b: String) -> bool:
	var room: ShipRoom = get_room(a)
	if room == null:
		return false
	return room.is_adjacent_to(b)


# Shortest route from one room to another as a list of rooms to enter, excluding
# the starting room and including the destination. Empty if unreachable.
#
# GAME_SPEC_v0.1 §2 rules pathfinding out of scope, on the assumption that crew
# teleport. They no longer do, and a player who has to click each room in turn
# is performing the pathfinding by hand — which is exactly what made movement
# read as hopping between boxes rather than walking through a ship.
func path(from_id: String, to_id: String) -> Array[String]:
	var empty: Array[String] = []
	if from_id == to_id or not has_room(from_id) or not has_room(to_id):
		return empty

	var came_from: Dictionary = {from_id: ""}
	var queue: Array[String] = [from_id]

	while not queue.is_empty():
		var current: String = queue.pop_front()
		if current == to_id:
			var route: Array[String] = []
			var node: String = to_id
			while node != from_id:
				route.push_front(node)
				node = str(came_from[node])
			return route
		var room: ShipRoom = get_room(current)
		if room == null:
			continue
		for neighbour: String in room.adjacent:
			if not came_from.has(neighbour):
				came_from[neighbour] = current
				queue.append(neighbour)

	return empty


# Symmetry check for the validator: if A lists B, B must list A. An asymmetric
# adjacency list produces a room fire can enter and not leave, which is the kind
# of bug that only shows up once v0.2 exists.
func asymmetric_pairs() -> Array[String]:
	var bad: Array[String] = []
	for room: ShipRoom in rooms:
		for other_id: String in room.adjacent:
			var other: ShipRoom = get_room(other_id)
			if other == null:
				bad.append("%s -> %s (no such room)" % [room.id, other_id])
			elif not other.is_adjacent_to(room.id):
				bad.append("%s -> %s but not back" % [room.id, other_id])
	return bad
