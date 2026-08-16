extends RefCounted
class_name CorridorMap

# Turns a room-to-room hop into the path a person would actually walk.
#
# The simulation says "TOCK is moving from the magazine to the medbay" and
# charges one transit for it. It does not know the ship has a shape. This class
# is what knows: it reads the corridor graph traced off the yellow guidance
# stripe on the plate and returns a polyline that stays in the corridors.
#
# Before this existed, ShipView walked room centre -> door -> room centre in
# straight lines, so crew cut corners through bulkheads and occasionally crossed
# half the ship diagonally. The fix was the data, not the interpolation: the
# plate paints where the corridors are, so the corridors got traced.
#
# This lives in ui/ on purpose. ARCHITECTURE.md keeps geometry out of sim/, and
# the corridor graph is geometry.

var layout: ShipLayout = null

var _adjacency: Dictionary = {}   # waypoint id -> Array[String]
var _cache: Dictionary = {}       # "from|to" -> PackedVector2Array


func _init(layout_in: ShipLayout) -> void:
	layout = layout_in
	for edge: Array in layout.corridor_edges:
		if edge.size() != 2:
			continue
		var a: String = str(edge[0])
		var b: String = str(edge[1])
		if not _adjacency.has(a):
			_adjacency[a] = [] as Array[String]
		if not _adjacency.has(b):
			_adjacency[b] = [] as Array[String]
		(_adjacency[a] as Array[String]).append(b)
		(_adjacency[b] as Array[String]).append(a)


# The walk for one hop, from the centre of `from_id` to the centre of `to_id`.
# Always at least two points, so callers can treat it as a polyline without
# checking for the degenerate case.
func hop(from_id: String, to_id: String) -> PackedVector2Array:
	var key: String = "%s|%s" % [from_id, to_id]
	if _cache.has(key):
		return _cache[key] as PackedVector2Array
	var route: PackedVector2Array = _build_hop(from_id, to_id)
	_cache[key] = route
	return route


func _build_hop(from_id: String, to_id: String) -> PackedVector2Array:
	var from_room: ShipRoom = layout.get_room(from_id)
	var to_room: ShipRoom = layout.get_room(to_id)
	if from_room == null or to_room == null:
		return PackedVector2Array()

	var out: PackedVector2Array = PackedVector2Array([from_room.centre()])

	var from_wp: String = layout.corridor_waypoint(from_id)
	var to_wp: String = layout.corridor_waypoint(to_id)

	# Two compartments joined by a bulkhead door rather than by the corridor —
	# life support opens only into the reactor. Straight through the door.
	if from_wp == "" or to_wp == "" or not _adjacency.has(from_wp) or not _adjacency.has(to_wp):
		var door: Vector2 = layout.door_between(from_id, to_id)
		if door != Vector2.ZERO:
			out.append(door)
		out.append(to_room.centre())
		return out

	out.append(layout.corridor_door(from_id))
	for wp: String in _waypoint_path(from_wp, to_wp):
		out.append(layout.waypoints.get(wp, Vector2.ZERO) as Vector2)
	out.append(layout.corridor_door(to_id))
	out.append(to_room.centre())
	return _dedupe(out)


# Breadth-first over corridor_edges. There is no need for A* at this scale —
# the whole ship is nine waypoints.
func _waypoint_path(from_wp: String, to_wp: String) -> Array[String]:
	var single: Array[String] = [from_wp]
	if from_wp == to_wp:
		return single

	var came_from: Dictionary = {from_wp: ""}
	var queue: Array[String] = [from_wp]
	while not queue.is_empty():
		var current: String = queue.pop_front()
		if current == to_wp:
			var chain: Array[String] = []
			var node: String = to_wp
			while node != "":
				chain.push_front(node)
				node = str(came_from[node])
			return chain
		for neighbour: String in (_adjacency.get(current, []) as Array[String]):
			if not came_from.has(neighbour):
				came_from[neighbour] = current
				queue.append(neighbour)

	# Disconnected graph. validate_data.gd fails on this, so it should never
	# reach a running game; going via both taps is still better than a diagonal.
	var both: Array[String] = [from_wp, to_wp]
	return both


# Consecutive duplicates come from a room whose door sits on top of its
# waypoint. They are harmless to draw and would divide by zero when walked.
func _dedupe(points: PackedVector2Array) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	for p: Vector2 in points:
		if out.is_empty() or out[out.size() - 1].distance_to(p) > 0.5:
			out.append(p)
	return out


# The point `t` of the way along a polyline, measured by distance rather than
# by segment count, so a long corridor leg does not go past at the same rate as
# a short step through a doorway.
static func point_along(points: PackedVector2Array, t: float) -> Vector2:
	if points.is_empty():
		return Vector2.ZERO
	if points.size() == 1:
		return points[0]

	var total: float = 0.0
	for i: int in range(points.size() - 1):
		total += points[i].distance_to(points[i + 1])
	if total <= 0.0:
		return points[0]

	var travelled: float = total * clampf(t, 0.0, 1.0)
	for i: int in range(points.size() - 1):
		var leg: float = points[i].distance_to(points[i + 1])
		if travelled <= leg or i == points.size() - 2:
			return points[i].lerp(points[i + 1], travelled / maxf(leg, 0.001))
		travelled -= leg
	return points[points.size() - 1]
