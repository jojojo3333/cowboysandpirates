extends Control
class_name ShipView

# Top-down ship view: rooms as drawn rectangles at real pixel positions, crew
# as markers that move between them. FTL's projection, which is flat overhead —
# not isometric.
#
# Everything here is drawn in _draw(). No imported assets, no .tscn. The room
# grid comes from data/ship_layout.json, so moving a room is a data change.
#
# This is a viewer. It holds no authoritative state: it reads the simulation
# and turns clicks into signals that main.gd forwards back into it.

signal room_clicked(room_id: String)
signal crew_clicked(crew_id: String)

const CELL_MIN: Vector2 = Vector2(150.0, 118.0)
const CELL_MAX: Vector2 = Vector2(300.0, 230.0)
const GAP: float = 34.0
const CREW_RADIUS: float = 15.0
const CREW_HIT_RADIUS: float = 20.0
const SLOTS_PER_ROW: int = 3

const COL_HULL: Color = Color(0.09, 0.10, 0.13)
const COL_ROOM: Color = Color(0.17, 0.19, 0.23)
const COL_ROOM_EMPTY: Color = Color(0.14, 0.16, 0.19)
const COL_EDGE: Color = Color(0.30, 0.34, 0.40)
const COL_EDGE_REACHABLE: Color = Color(0.55, 0.78, 0.85)
const COL_CORRIDOR: Color = Color(0.13, 0.15, 0.18)
const COL_LABEL: Color = Color(0.58, 0.63, 0.69)
const COL_TEXT: Color = Color(0.85, 0.88, 0.91)
const COL_TIED: Color = Color(0.55, 0.35, 0.32)
const COL_OUTLINE: Color = Color(0.05, 0.06, 0.08)
const COL_PATH: Color = Color(0.45, 0.70, 0.78, 0.55)

var scene: RescueScene = null
var layout: ShipLayout = null

var _class_colours: Dictionary = {}
var _origin: Vector2 = Vector2.ZERO
var _font: Font = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_font = ThemeDB.fallback_font
	_load_class_colours()


func _process(_delta: float) -> void:
	# Positions animate every frame while TOCK is in transit.
	queue_redraw()


func _load_class_colours() -> void:
	var raw: Dictionary = DataLoader.load_json(DataLoader.CLASSES_PATH)
	for entry: Variant in raw.get("classes", []):
		var c: Dictionary = entry as Dictionary
		_class_colours[str(c.get("id", ""))] = Color(str(c.get("colour", "#b0b0b0")))


# --- geometry --------------------------------------------------------------

# Rooms grow to fill whatever space the window gives them, clamped so they
# never get so small that six markers collide or so large that the ship stops
# reading as one object.
func _cell() -> Vector2:
	var cols: float = float(maxi(layout.grid_columns, 1))
	var rows: float = float(maxi(layout.grid_rows, 1))
	var free: Vector2 = size - Vector2((cols - 1.0) * GAP, (rows - 1.0) * GAP) - Vector2(16.0, 16.0)
	return Vector2(
		clampf(free.x / cols, CELL_MIN.x, CELL_MAX.x),
		clampf(free.y / rows, CELL_MIN.y, CELL_MAX.y)
	)


func _grid_size() -> Vector2:
	var cell: Vector2 = _cell()
	var cols: float = float(maxi(layout.grid_columns, 1))
	var rows: float = float(maxi(layout.grid_rows, 1))
	return Vector2(
		cols * cell.x + (cols - 1.0) * GAP,
		rows * cell.y + (rows - 1.0) * GAP
	)


func _recentre() -> void:
	_origin = ((size - _grid_size()) * 0.5).floor().maxf(8.0)


func _room_rect(room: ShipRoom) -> Rect2:
	var cell: Vector2 = _cell()
	return Rect2(
		_origin + Vector2(room.col * (cell.x + GAP), room.row * (cell.y + GAP)),
		cell
	)


func _room_centre(room_id: String) -> Vector2:
	var room: ShipRoom = layout.get_room(room_id)
	if room == null:
		return _origin
	return _room_rect(room).get_center()


# Crew stand on a slot grid inside the room. Slots are derived from the room
# rectangle rather than a fixed pixel step, so six markers in the hold spread
# out instead of stacking on each other.
func _slot(room_id: String, index: int, total: int) -> Vector2:
	var room: ShipRoom = layout.get_room(room_id)
	if room == null:
		return _origin
	var rect: Rect2 = _room_rect(room)
	var inner: Rect2 = Rect2(
		rect.position + Vector2(8.0, 30.0),
		rect.size - Vector2(16.0, 42.0)
	)
	if total <= 1:
		return inner.get_center()

	var rows: int = maxi(int(ceil(float(total) / float(SLOTS_PER_ROW))), 1)
	var col: int = index % SLOTS_PER_ROW
	var row: int = index / SLOTS_PER_ROW
	var in_row: int = mini(SLOTS_PER_ROW, total - row * SLOTS_PER_ROW)
	var step_x: float = inner.size.x / float(SLOTS_PER_ROW)
	var step_y: float = inner.size.y / float(rows)
	return Vector2(
		inner.get_center().x + (float(col) - (float(in_row) - 1.0) * 0.5) * step_x,
		inner.position.y + step_y * (float(row) + 0.5)
	)


# Crew are called by one name in play, and a full name under a 30px disc is
# what produced "SmithBraOstrTIED" on the first attempt.
func _short_name(member: CrewMember) -> String:
	var parts: PackedStringArray = member.display_name.split(" ", false)
	return parts[parts.size() - 1] if parts.size() > 0 else member.display_name


# The single source of truth for who stands where. Drawing, TOCK's position and
# hit-testing all go through this. They used to compute it three separate ways,
# which put TOCK on a slot nobody else agreed with and made clicks land beside
# the markers rather than on them.
func _occupants(room_id: String) -> Array[CrewMember]:
	var out: Array[CrewMember] = []
	for m: CrewMember in scene.crew:
		if m.room == room_id:
			out.append(m)
	# A crew member in transit is on the corridor, not in either room.
	if scene.tock != null and scene.tock.room == room_id and not _tock_in_transit():
		out.append(scene.tock)
	return out


func _tock_in_transit() -> bool:
	return scene.task == RescueScene.Task.TRANSIT and scene.task_target != ""


# TOCK sits on the line between the room he left and the one he is entering.
# The simulation already models transit as a duration; this reads the progress
# it publishes rather than inventing an animation of its own.
func _tock_position() -> Vector2:
	if _tock_in_transit():
		return _room_centre(scene.tock.room).lerp(
			_room_centre(scene.task_target), scene.task_progress()
		)
	var here: Array[CrewMember] = _occupants(scene.tock.room)
	return _slot(scene.tock.room, maxi(here.find(scene.tock), 0), here.size())


# --- drawing ---------------------------------------------------------------

func _draw() -> void:
	if scene == null or layout == null or layout.rooms.is_empty():
		return
	_recentre()

	draw_rect(Rect2(Vector2.ZERO, size), COL_HULL)

	_draw_corridors()
	for room: ShipRoom in layout.rooms:
		_draw_room(room)
	if scene.task == RescueScene.Task.TRANSIT:
		_draw_path()
	_draw_crew()


func _draw_corridors() -> void:
	# Drawn once per pair. Adjacency is a real rule in this game — fire spreads
	# along it in v0.2 — so it should be visible rather than implied.
	var seen: Dictionary = {}
	for room: ShipRoom in layout.rooms:
		for other_id: String in room.adjacent:
			var key: String = room.id + "|" + other_id
			var mirror: String = other_id + "|" + room.id
			if seen.has(mirror) or seen.has(key):
				continue
			seen[key] = true
			var other: ShipRoom = layout.get_room(other_id)
			if other == null:
				continue
			var a: Vector2 = _room_rect(room).get_center()
			var b: Vector2 = _room_rect(other).get_center()
			draw_line(a, b, COL_CORRIDOR, 18.0)


func _draw_room(room: ShipRoom) -> void:
	var rect: Rect2 = _room_rect(room)
	var fill: Color = COL_ROOM if room.system != "" else COL_ROOM_EMPTY
	draw_rect(rect, fill, true)

	var reachable: bool = (
		scene.phase == RescueScene.Phase.EXECUTING
		and scene.task == RescueScene.Task.IDLE
		and layout.are_adjacent(scene.tock.room, room.id)
	)
	var edge: Color = COL_EDGE_REACHABLE if reachable else COL_EDGE
	draw_rect(rect, edge, false, 2.0 if reachable else 1.0)

	draw_string(
		_font, rect.position + Vector2(10.0, 20.0), room.label,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 12, COL_LABEL
	)
	if reachable:
		draw_string(
			_font, rect.position + Vector2(10.0, rect.size.y - 9.0), "MOVE",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 11, COL_EDGE_REACHABLE
		)


func _draw_path() -> void:
	var a: Vector2 = _room_centre(scene.tock.room)
	var b: Vector2 = _room_centre(scene.task_target)
	draw_line(a, b, COL_PATH, 3.0)


func _draw_crew() -> void:
	for room: ShipRoom in layout.rooms:
		var here: Array[CrewMember] = _occupants(room.id)
		for i: int in range(here.size()):
			_draw_marker(here[i], _slot(room.id, i, here.size()), here[i] == scene.tock)

	# Drawn last and separately only while he is between rooms, where no room's
	# slot grid applies.
	if scene.tock != null and _tock_in_transit():
		_draw_marker(scene.tock, _tock_position(), true)


func _draw_marker(member: CrewMember, at: Vector2, is_tock: bool) -> void:
	var colour: Color = _class_colours.get(member.class_id, Color(0.7, 0.7, 0.7))
	if member.is_tied():
		colour = colour.lerp(COL_TIED, 0.55)

	draw_circle(at, CREW_RADIUS + 2.0, COL_OUTLINE)
	draw_circle(at, CREW_RADIUS, colour)

	# TOCK reads as machine: a square inside the disc rather than a face.
	if is_tock:
		var s: float = CREW_RADIUS * 0.52
		draw_rect(Rect2(at - Vector2(s, s), Vector2(s, s) * 2.0), COL_OUTLINE, false, 2.0)
	else:
		draw_string(
			_font, at + Vector2(-4.0, 5.0), member.display_name.substr(0, 1),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 14, COL_OUTLINE
		)

	# A bound crew member gets a visible restraint, not only a duller colour —
	# CLAUDE.md rule 8: nothing that matters is carried by colour alone.
	if member.is_tied():
		draw_line(
			at + Vector2(-CREW_RADIUS, 0.0), at + Vector2(CREW_RADIUS, 0.0),
			COL_OUTLINE, 3.0
		)

	var label: String = _short_name(member)
	if member.hp < member.max_hp:
		label += " %d" % member.hp
	draw_string(
		_font, at + Vector2(-40.0, CREW_RADIUS + 14.0), label,
		HORIZONTAL_ALIGNMENT_CENTER, 80.0, 11, COL_TEXT
	)
	if member.is_tied():
		draw_string(
			_font, at + Vector2(-40.0, CREW_RADIUS + 26.0), "TIED",
			HORIZONTAL_ALIGNMENT_CENTER, 80.0, 10, COL_TIED
		)

	if scene.task == RescueScene.Task.FREEING and scene.task_target == member.id:
		var w: float = 44.0
		var bar: Rect2 = Rect2(at + Vector2(-w * 0.5, CREW_RADIUS + 20.0), Vector2(w, 4.0))
		draw_rect(bar, COL_OUTLINE)
		draw_rect(
			Rect2(bar.position, Vector2(w * scene.task_progress(), 4.0)),
			COL_EDGE_REACHABLE
		)


# --- input -----------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	var click: InputEventMouseButton = event as InputEventMouseButton
	if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	if scene == null or layout == null:
		return

	# Crew are smaller and sit on top of rooms, so they are tested first, at the
	# exact positions _draw_crew used.
	for room: ShipRoom in layout.rooms:
		var here: Array[CrewMember] = _occupants(room.id)
		for i: int in range(here.size()):
			if click.position.distance_to(_slot(room.id, i, here.size())) <= CREW_HIT_RADIUS:
				crew_clicked.emit(here[i].id)
				accept_event()
				return

	for room: ShipRoom in layout.rooms:
		if _room_rect(room).has_point(click.position):
			room_clicked.emit(room.id)
			accept_event()
			return
