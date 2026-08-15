extends RefCounted
class_name ShipLayout

# Rooms and adjacency, loaded from data/ship_layout.json. Adjacency is what
# movement costs in this scene and what fire spreads along in v0.2.

var rooms: Array[ShipRoom] = []
var grid_columns: int = 3
var grid_rows: int = 2

var _by_id: Dictionary = {}


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
