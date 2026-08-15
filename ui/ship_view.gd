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

# Rooms tile flush against each other. They used to be separated by a gap, and
# six free-floating rectangles read as six boxes rather than as one ship — the
# first thing a human said after playing it.
const GAP: float = 0.0
const HULL_PAD: float = 15.0
const PROW: float = 62.0
const STERN: float = 30.0
const DOOR: float = 0.34
const CREW_RADIUS: float = 15.0
const CREW_HIT_RADIUS: float = 20.0
const SLOTS_PER_ROW: int = 3

const COL_HULL: Color = Color(0.09, 0.10, 0.13)
const COL_ROOM: Color = Color(0.17, 0.19, 0.23)
const COL_ROOM_EMPTY: Color = Color(0.14, 0.16, 0.19)
const COL_EDGE: Color = Color(0.30, 0.34, 0.40)
const COL_EDGE_REACHABLE: Color = Color(0.55, 0.78, 0.85)
const COL_SHELL: Color = Color(0.115, 0.13, 0.155)
const COL_DOOR: Color = Color(0.34, 0.46, 0.52)
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
	# The prow and stern stick out past the room block, so they have to come off
	# the budget before the rooms are sized — otherwise the hull is drawn
	# outside the control and gets clipped.
	var chrome: Vector2 = Vector2(
		2.0 * HULL_PAD + PROW + STERN + 16.0,
		2.0 * HULL_PAD + 16.0
	)
	var free: Vector2 = size - chrome - Vector2((cols - 1.0) * GAP, (rows - 1.0) * GAP)
	return Vector2(
		clampf(free.x / cols, CELL_MIN.x, CELL_MAX.x),
		clampf(free.y / rows, CELL_MIN.y, CELL_MAX.y)
	)


func _hull_size() -> Vector2:
	return _grid_size() + Vector2(2.0 * HULL_PAD + PROW + STERN, 2.0 * HULL_PAD)


func _grid_size() -> Vector2:
	var cell: Vector2 = _cell()
	var cols: float = float(maxi(layout.grid_columns, 1))
	var rows: float = float(maxi(layout.grid_rows, 1))
	return Vector2(
		cols * cell.x + (cols - 1.0) * GAP,
		rows * cell.y + (rows - 1.0) * GAP
	)


# Centres the hull, not the room block. The two differ by the prow, which is
# only on one side, so centring the block put the nose off-screen.
func _recentre() -> void:
	var free: Vector2 = ((size - _hull_size()) * 0.5).maxf(0.0)
	_origin = (free + Vector2(HULL_PAD + PROW, HULL_PAD)).floor()


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

	_draw_hull()
	for room: ShipRoom in layout.rooms:
		_draw_room(room)
	_draw_walls()
	if scene.task == RescueScene.Task.TRANSIT:
		_draw_path()
	_draw_crew()


func _block() -> Rect2:
	return Rect2(_origin, _grid_size())


# A silhouette around the whole room block, so the ship reads as one object with
# an outside. Decoration only — nothing here is clickable and the simulation
# knows nothing about it.
func _draw_hull() -> void:
	var b: Rect2 = _block()
	var x0: float = b.position.x - HULL_PAD
	var y0: float = b.position.y - HULL_PAD
	var x1: float = b.end.x + HULL_PAD
	var y1: float = b.end.y + HULL_PAD
	var ym: float = b.get_center().y

	var shell: PackedVector2Array = PackedVector2Array([
		Vector2(x0 - PROW, ym),
		Vector2(x0, y0),
		Vector2(x1 - 34.0, y0),
		Vector2(x1 + STERN, y0 + 26.0),
		Vector2(x1 + STERN, y1 - 26.0),
		Vector2(x1 - 34.0, y1),
		Vector2(x0, y1),
	])
	draw_colored_polygon(shell, COL_SHELL)
	draw_polyline(shell + PackedVector2Array([shell[0]]), COL_EDGE, 2.0)

	# Engine bells, aft.
	for offset: float in [-46.0, 10.0]:
		draw_rect(Rect2(Vector2(x1 + STERN - 4.0, ym + offset), Vector2(16.0, 36.0)), COL_SHELL)
		draw_rect(
			Rect2(Vector2(x1 + STERN - 4.0, ym + offset), Vector2(16.0, 36.0)),
			COL_EDGE, false, 2.0
		)


func _draw_room(room: ShipRoom) -> void:
	var rect: Rect2 = _room_rect(room)
	var fill: Color = COL_ROOM if room.system != "" else COL_ROOM_EMPTY
	draw_rect(rect, fill, true)

	if _is_target(room.id):
		draw_rect(rect, COL_EDGE_REACHABLE * Color(1, 1, 1, 0.10), true)

	draw_string(
		_font, rect.position + Vector2(10.0, 20.0), room.label,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 12, COL_LABEL
	)


func _is_target(room_id: String) -> bool:
	return scene.task == RescueScene.Task.TRANSIT and not scene.route.is_empty() \
		and scene.route[scene.route.size() - 1] == room_id


# Interior walls between grid neighbours, with a gap where the adjacency list
# says there is a door. Where two rooms touch but are not adjacent, the wall is
# solid — so the drawing and the rule the simulation uses cannot drift apart.
func _draw_walls() -> void:
	var cell: Vector2 = _cell()
	for room: ShipRoom in layout.rooms:
		var rect: Rect2 = _room_rect(room)
		var right: ShipRoom = _room_at(room.col + 1, room.row)
		if right != null:
			_wall(
				Vector2(rect.end.x, rect.position.y),
				Vector2(rect.end.x, rect.end.y),
				layout.are_adjacent(room.id, right.id)
			)
		var below: ShipRoom = _room_at(room.col, room.row + 1)
		if below != null:
			_wall(
				Vector2(rect.position.x, rect.end.y),
				Vector2(rect.end.x, rect.end.y),
				layout.are_adjacent(room.id, below.id)
			)
	draw_rect(Rect2(_origin, _grid_size()), COL_EDGE, false, 2.0)


func _room_at(col: int, row: int) -> ShipRoom:
	for room: ShipRoom in layout.rooms:
		if room.col == col and room.row == row:
			return room
	return null


func _wall(from: Vector2, to: Vector2, has_door: bool) -> void:
	if not has_door:
		draw_line(from, to, COL_EDGE, 2.0)
		return
	var mid: Vector2 = (from + to) * 0.5
	var half: Vector2 = (to - from) * (DOOR * 0.5)
	draw_line(from, mid - half, COL_EDGE, 2.0)
	draw_line(mid + half, to, COL_EDGE, 2.0)
	draw_line(mid - half, mid + half, COL_DOOR, 3.0)


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
