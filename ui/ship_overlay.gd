extends Node2D
class_name ShipOverlay

# Everything that changes, drawn on top of the ship plate in plate coordinates.
#
# CLAUDE.md rule 2: the plate is the ship — hull, compartment floors, bulkheads
# and doors are art and are not drawn here. What is drawn here is state:
# selection, the ordered route, the destination, restraint markers, name plates
# and progress bars. The test is whether it would be identical in a screenshot
# of a paused game with nothing selected; if so it belongs in the plate.
#
# This node is deliberately unshaded. The lights in ShipView exist to make the
# hull read as metal, and they must not dim a name plate or a progress bar —
# readability of state outranks the lighting, per rule 8.

const COL_SELECT: Color = Color(0.62, 0.86, 0.94)
const COL_PATH: Color = Color(0.52, 0.80, 0.88, 0.75)
const COL_TEXT: Color = Color(0.90, 0.93, 0.96)
const COL_TIED: Color = Color(0.86, 0.46, 0.40)
const COL_PLATE_BG: Color = Color(0.03, 0.04, 0.05, 0.72)

var scene: RescueScene = null
var layout: ShipLayout = null
var view: ShipView = null

var clock: float = 0.0
var _font: Font = null


func _ready() -> void:
	_font = ThemeDB.fallback_font
	var mat: CanvasItemMaterial = CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = mat


func _draw() -> void:
	if scene == null or layout == null or view == null:
		return

	_draw_target()
	_draw_route()
	_draw_crew_state()


# The destination compartment, outlined along its real traced shape rather than
# as a bounding box. An irregular room highlighted with a rectangle is exactly
# the seam that made the old view look like a form laid over a picture.
func _draw_target() -> void:
	if scene.task != RescueScene.Task.TRANSIT or scene.route.is_empty():
		return
	var room: ShipRoom = layout.get_room(scene.route[scene.route.size() - 1])
	if room == null or room.polygon.size() < 3:
		return

	var pulse: float = 0.45 + 0.25 * sin(clock * 3.2)
	draw_colored_polygon(room.polygon, Color(COL_SELECT, 0.10))
	var loop: PackedVector2Array = room.polygon + PackedVector2Array([room.polygon[0]])
	draw_polyline(loop, Color(COL_SELECT, pulse), 3.0)


# The whole ordered route, through the doorways the crew actually walk through.
func _draw_route() -> void:
	if scene.task != RescueScene.Task.TRANSIT or scene.tock == null:
		return
	var points: PackedVector2Array = view.route_points()
	for i: int in range(points.size() - 1):
		_dashed(points[i], points[i + 1])


func _dashed(a: Vector2, b: Vector2) -> void:
	var total: float = a.distance_to(b)
	if total < 1.0:
		return
	var dir: Vector2 = (b - a) / total
	var dash: float = 14.0
	var gap: float = 11.0
	var offset: float = fmod(clock * 42.0, dash + gap)
	var d: float = -offset
	while d < total:
		var s: float = maxf(d, 0.0)
		var e: float = minf(d + dash, total)
		if e > s:
			draw_line(a + dir * s, a + dir * e, COL_PATH, 3.0)
		d += dash + gap


func _draw_crew_state() -> void:
	for member: CrewMember in view.all_crew():
		var at: Vector2 = view.crew_position(member)
		_draw_label(member, at)

		# A bound crew member gets a visible restraint, not only a duller
		# colour — CLAUDE.md rule 8: nothing that matters is colour alone.
		if member.is_tied():
			draw_line(at + Vector2(-38.0, 0.0), at + Vector2(38.0, 0.0), Color(0, 0, 0, 0.85), 11.0)
			draw_line(at + Vector2(-38.0, 0.0), at + Vector2(38.0, 0.0), COL_TIED, 6.0)

		if scene.task == RescueScene.Task.FREEING and scene.task_target == member.id:
			var w: float = 120.0
			var bar: Rect2 = Rect2(at + Vector2(-w * 0.5, 96.0), Vector2(w, 11.0))
			draw_rect(bar.grow(1.0), Color(0, 0, 0, 0.8))
			draw_rect(Rect2(bar.position, Vector2(w * scene.task_progress(), 11.0)), COL_SELECT)


func _draw_label(member: CrewMember, at: Vector2) -> void:
	var parts: PackedStringArray = member.display_name.split(" ", false)
	var name: String = parts[parts.size() - 1] if parts.size() > 0 else member.display_name
	if member.hp < member.max_hp:
		name += "  %d" % member.hp

	var width: float = _font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
	var plate: Rect2 = Rect2(at + Vector2(-width * 0.5 - 9.0, 52.0), Vector2(width + 18.0, 33.0))
	draw_rect(plate, COL_PLATE_BG)
	draw_string(
		_font, at + Vector2(-width * 0.5, 77.0), name,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 26, COL_TEXT
	)
	if member.is_tied():
		draw_string(
			_font, at + Vector2(-45.0, 106.0), "TIED",
			HORIZONTAL_ALIGNMENT_CENTER, 90.0, 22, COL_TIED
		)
