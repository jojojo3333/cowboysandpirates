extends RefCounted
class_name ShipRoom

# One room. `system` is empty for rooms that hold no combat system — Reactor and
# Cargo. They still hold crew, and from v0.2 they burn, which is the whole
# reason they exist rather than being cut from the layout.

var id: String = ""
var label: String = ""
var system: String = ""
var col: int = 0
var row: int = 0
var adjacent: Array[String] = []


func is_adjacent_to(room_id: String) -> bool:
	return adjacent.has(room_id)
