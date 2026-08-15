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
