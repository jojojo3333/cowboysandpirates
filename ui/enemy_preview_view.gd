extends Control
class_name EnemyPreviewView

# The enemy ship, drawn from its own plate with a few hostile crew standing in it.
#
# There is no enemy simulation yet. These figures do not move, think or fight —
# they are here so the composition can be judged with people in both ships,
# because a hull with nobody in it reads as scenery rather than as a threat.
# Making them look busy is the next real step and it needs a state model, not a
# better sprite.

const PLATE_PATH: String = "res://assets/ship/enemywarship1.png"
const CREW_SHEET: String = "res://assets/crew/soldier_idle.png"
const DISPLAY_SCALE: float = 1.20
const OVERFLOW: float = 1.30

# Must match ui/ship_view.gd. The enemy borrows the player's crew sheets, so it
# inherits their cell layout too.
const FACINGS: int = 8
const IDLE_FRAMES: int = 4
const CREW_SCALE: float = 0.52
const CREW_ART_OFFSET: float = -3.5

# Dark red and matte, against the player crew's lit steel.
#
# The first pass at this drew the enemies by hand — polygons and circles in
# `_draw()` — on the reasoning that hostiles should not be "another metallic
# clone". The intent was right and the result was an eyesore next to a rendered
# figure, because a flat silhouette beside a lit 3D render does not read as a
# different faction, it reads as a placeholder that nobody replaced.
#
# So it is the same render, re-lit. `STRENGTH` pulls it hard towards red and the
# low `LIFT` is what kills the metal: the sheet's highlights are what make it
# look like steel, and multiplying below 1.0 crushes them into the body colour.
# Player crew lift to 1.30 for legibility; these deliberately sit darker and
# duller, which is also how they stay distinguishable at a glance.
# The lift was 0.78 on the first attempt, on the reasoning that "matte" means
# "darker". It does not — the sheet's mean brightness is 49, so multiplying below
# 1.0 rendered three figures that were technically present and effectively
# invisible on a dark deck. Matte comes from crushing the *highlights* towards
# the body colour, which the strong tint already does; the lift only has to keep
# them readable. Player crew sit at 1.30, these at 1.18: same job, still
# obviously not the same side.
const ENEMY_TINT: Color = Color(0.78, 0.15, 0.12)
const ENEMY_TINT_STRENGTH: float = 0.86
const ENEMY_TINT_LIFT: float = 1.18

# Where the hostiles stand, in plate pixels — one each in three separate
# compartments, forward and amidships.
#
# **These are eyeballed off the image.** The enemy ship has no room data: no
# traced polygons, no adjacency, no corridor graph, none of what
# `data/ship_layout.json` gives the player's plate. So there is nothing to ask
# "which room is this?" and nothing to stop a figure standing in a bulkhead if
# the plate is ever replaced. Tracing the enemy plate is the prerequisite for
# enemy crew that move, and it comes before any behaviour work.
const ENEMY_POSTS: Array[Vector2] = [
	Vector2(1105.0, 245.0),
	Vector2(735.0, 250.0),
	Vector2(1075.0, 495.0),
]

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

	var sheet: Texture2D = load(CREW_SHEET) as Texture2D
	if sheet == null:
		push_error("crew sheet missing: %s" % CREW_SHEET)
		return
	for i: int in range(ENEMY_POSTS.size()):
		_add_figure(sheet, ENEMY_POSTS[i], i)


func _add_figure(sheet: Texture2D, at: Vector2, index: int) -> void:
	var sprite: Sprite2D = Sprite2D.new()
	sprite.name = "enemy_%d" % index
	sprite.texture = sheet
	sprite.hframes = IDLE_FRAMES
	sprite.vframes = FACINGS
	# Facing 0 held, and one fixed frame each. Nothing here animates yet, and a
	# breathing loop on a figure that cannot act would promise behaviour that
	# does not exist.
	sprite.frame = index % IDLE_FRAMES
	sprite.position = at
	sprite.offset = Vector2(0.0, CREW_ART_OFFSET)
	# The whole world is mirrored, so the sprite is counter-mirrored to keep the
	# figure itself the right way round. Without this the rifle changes hands.
	sprite.scale = Vector2(-CREW_SCALE if mirrored else CREW_SCALE, CREW_SCALE)
	sprite.modulate = Color(1.0, 1.0, 1.0).lerp(ENEMY_TINT, ENEMY_TINT_STRENGTH) * ENEMY_TINT_LIFT
	sprite.z_index = 2
	_world.add_child(sprite)


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
