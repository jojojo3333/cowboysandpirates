extends RefCounted
class_name ShipRoom

# One room. `system` is empty for rooms that hold no combat system — Reactor and
# Cargo. They still hold crew, and from v0.2 they burn, which is the whole
# reason they exist rather than being cut from the layout.
#
# `polygon` is the compartment outline traced from the ship plate, in plate
# pixels. It replaced grid col/row, which forced every ship to be a rectangle of
# identical rooms. Vector2 is a core type, not a Node, so this stays inside the
# ARCHITECTURE.md rule that sim/ never touches scene APIs — and the simulation
# still reads only `adjacent`.

var id: String = ""
var label: String = ""
var system: String = ""
var polygon: PackedVector2Array = PackedVector2Array()
var adjacent: Array[String] = []

# How many bodies fit, friend or foe. A simulation rule, not a drawing hint: a
# move into a full compartment is refused and the refusal is logged. Zero means
# "no limit authored", so a layout written before capacities existed still runs.
var capacity: int = 0


func is_adjacent_to(room_id: String) -> bool:
	return adjacent.has(room_id)


# Area-weighted centroid, so crew stand in the visual middle of an L-shaped or
# tapered compartment rather than at the average of its corners.
func centre() -> Vector2:
	var n: int = polygon.size()
	if n == 0:
		return Vector2.ZERO
	var area: float = 0.0
	var acc: Vector2 = Vector2.ZERO
	for i: int in range(n):
		var a: Vector2 = polygon[i]
		var b: Vector2 = polygon[(i + 1) % n]
		var cross: float = a.x * b.y - b.x * a.y
		area += cross
		acc += (a + b) * cross
	if absf(area) < 0.0001:
		return polygon[0]
	return acc / (3.0 * area)


func contains(point: Vector2) -> bool:
	return Geometry2D.is_point_in_polygon(point, polygon)
