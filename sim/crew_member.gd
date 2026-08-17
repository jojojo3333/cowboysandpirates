extends RefCounted
class_name CrewMember

# States are a superset of what this scene uses, so v0.2 does not have to
# reshape the enum. TIED and ACTIVE are the only two reached here.
#   Organic:   ACTIVE -> DOWNED -> DEAD          (v0.2 §5)
#   Synthetic: ACTIVE -> DISABLED -> DESTROYED   (v0.2 §5, no bleed-out timer)

enum State { TIED, ACTIVE, DOWNED, DEAD, DISABLED, DESTROYED }

var id: String = ""
var display_name: String = ""
var class_id: String = ""
var room: String = ""
var hp: int = 100
var max_hp: int = 100
var state: int = State.ACTIVE
var is_synthetic: bool = false

# --- movement ---------------------------------------------------------------
#
# Where this crew member is walking, and how far through the current hop they
# are. **This used to live on RescueScene**, as a single `task`/`task_target`/
# `route` that always meant TOCK, because for one slice only TOCK could move.
# Selecting five people and ordering them all somewhere is not a bigger version
# of that; it is the same thing owned by the right object.
#
# `route` is the rooms still to pass through. `move_target` is the one being
# entered right now, empty when standing still.
var move_target: String = ""
var move_remaining: float = 0.0
var move_total: float = 0.0
var route: Array[String] = []


func is_moving() -> bool:
	return move_target != ""


# How far through the current hop, 0..1. Used to place the figure along the
# corridor polyline; the renderer asks, the simulation answers, and no
# coordinate is involved on this side of the line.
func move_progress() -> float:
	if move_total <= 0.0:
		return 0.0
	return clampf(1.0 - (move_remaining / move_total), 0.0, 1.0)


func stop_moving() -> void:
	move_target = ""
	move_remaining = 0.0
	move_total = 0.0
	route.clear()


# Tied crew cannot be ordered anywhere, and a downed one cannot walk. Anything
# that gives a move order asks this first.
func can_take_orders() -> bool:
	return state == State.ACTIVE


func is_tied() -> bool:
	return state == State.TIED


func is_active() -> bool:
	return state == State.ACTIVE


func take_damage(amount: int, floor_hp: int = 0) -> void:
	hp = max(floor_hp, hp - amount)
	if hp <= 0:
		state = State.DISABLED if is_synthetic else State.DOWNED


static func state_name(s: int) -> String:
	match s:
		State.TIED: return "TIED"
		State.ACTIVE: return "ACTIVE"
		State.DOWNED: return "DOWNED"
		State.DEAD: return "DEAD"
		State.DISABLED: return "DISABLED"
		State.DESTROYED: return "DESTROYED"
	return "UNKNOWN"
