extends Control
class_name EnemyPreviewView

# The first enemy rendering pass. It owns only the supplied plate and three
# static hostile figures; combat targeting and enemy behaviour come later.

const PLATE_PATH: String = "res://assets/ship/enemywarship1.png"
const DISPLAY_SCALE: float = 1.20
const OVERFLOW: float = 1.30

var _world: Node2D = null
var _plate: Sprite2D = null
var _fit_scale: float = 1.0

# Both plates are authored bow-right. The enemy sits on the right of the screen,
# so its plate is flipped to face back across the gutter at us. Mirroring the
# whole Node2D rather than the Sprite2D alone means the figures standing in its
# compartments travel with it and stay in the rooms they were placed in.
var mirrored: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	_build()


func _process(_delta: float) -> void:
	_fit()


func _build() -> void:
	_world = Node2D.new()
	add_child(_world)

	_plate = Sprite2D.new()
	_plate.centered = false
	_plate.texture = load(PLATE_PATH) as Texture2D
	if _plate.texture == null:
		push_error("enemy plate missing: %s" % PLATE_PATH)
		return
	_world.add_child(_plate)

	# Cockpit: one officer in the large upper-forward control compartment.
	_add_figure(Vector2(1110.0, 250.0))
	# Weapons: two operators in the middle-forward console compartment.
	_add_figure(Vector2(1030.0, 495.0))
	_add_figure(Vector2(1135.0, 525.0))


func _add_figure(at: Vector2) -> void:
	var figure: EnemyFigure = EnemyFigure.new()
	figure.position = at
	figure.scale = Vector2(1.08, 1.08)
	figure.z_index = 2
	_world.add_child(figure)


func _fit() -> void:
	if _plate == null or _plate.texture == null or size.x < 1.0 or size.y < 1.0:
		return
	var plate_size: Vector2 = _plate.texture.get_size()
	var by_width: float = size.x / plate_size.x
	var by_height: float = size.y / plate_size.y
	_fit_scale = minf(by_width, by_height * OVERFLOW) * DISPLAY_SCALE
	_world.scale = Vector2(-_fit_scale if mirrored else _fit_scale, _fit_scale)
	_world.position = ((size - plate_size * _fit_scale) * 0.5).floor()
	# A negative x scale flips the plate about the node's origin, which puts it
	# entirely to the left of that point. Shifting by its own width brings it
	# back into frame.
	if mirrored:
		_world.position.x += plate_size.x * _fit_scale
