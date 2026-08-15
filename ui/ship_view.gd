extends Control
class_name ShipView

# Top-down ship view: rooms as drawn rectangles at real pixel positions, crew
# as markers that move between them. Void War's projection, which is flat
# overhead — not isometric.
#
# Everything structural here is drawn in _draw(). The room grid comes from
# data/ship_layout.json, so moving a room is a data change. Furniture comes
# from data/room_props.json and is the only imported art on screen; every file
# it names has a row in ASSETS.md.
#
# This is a viewer. It holds no authoritative state: it reads the simulation
# and turns clicks into signals that main.gd forwards back into it. Nothing
# drawn here is the only channel for anything — CLAUDE.md rule 8 — the log
# carries every state change in words regardless of how the ship looks.

signal room_clicked(room_id: String)
signal crew_clicked(crew_id: String)

const PROPS_PATH: String = "res://data/room_props.json"
const PROP_DIR: String = "res://assets/props/"

# Rooms used to grow to 300x230, which left five of the six as vast empty grey
# fields and made the ship read as a spreadsheet. Void War's rooms are small;
# the ship should be compact enough that the hull around it is visible.
const CELL_MIN: Vector2 = Vector2(132.0, 104.0)
const CELL_MAX: Vector2 = Vector2(224.0, 168.0)

# Rooms tile flush against each other. They used to be separated by a gap, and
# six free-floating rectangles read as six boxes rather than as one ship — the
# first thing a human said after playing it.
const GAP: float = 0.0

# --- hull geometry ---------------------------------------------------------
# The hull is deliberately NOT a uniform offset of the room block. A rectangle
# plus a triangle reads as a sheet of paper with a point on it. What makes a
# silhouette read as a ship is variation along its length — a narrowed nose, cut
# corners, and engine pods carried outside the body on pylons.
# HULL_PAD is deliberately large. With a thin pad the room block *is* the
# silhouette, and no amount of chamfering on an 18px margin is visible — which
# is the whole reason the first version read as a sheet of paper. The hull needs
# enough body around the rooms to have a shape of its own.
const HULL_PAD: float = 34.0
const CHAMFER: float = 50.0
const PROW: float = 66.0
const BRIDGE: float = 26.0
const STERN: float = 34.0
const NECK: float = 0.34
const NACELLE_GAP: float = 16.0
const NACELLE_H: float = 34.0
const MARGIN: float = 22.0

const WALL_W: float = 8.0
const WALL_OUTER: float = 11.0
const DOOR: float = 0.34

const FLOOR_GRID: float = 26.0
const CREW_RADIUS: float = 15.0
const CREW_HIT_RADIUS: float = 20.0
const SLOTS_PER_ROW: int = 3
const STAR_COUNT: int = 220

# --- palette ---------------------------------------------------------------

const COL_SPACE: Color = Color(0.034, 0.040, 0.058)
const COL_SPACE_WARM: Color = Color(0.058, 0.052, 0.064)
const COL_NEBULA: Color = Color(0.20, 0.16, 0.30, 0.055)
const COL_STAR: Color = Color(0.74, 0.80, 0.92)

const COL_HULL_PLATE: Color = Color(0.155, 0.170, 0.200)
const COL_HULL_DARK: Color = Color(0.082, 0.092, 0.112)
const COL_HULL_LIT: Color = Color(0.255, 0.278, 0.322)
const COL_HULL_LINE: Color = Color(0.315, 0.350, 0.410)
const COL_PANEL_LINE: Color = Color(0.09, 0.10, 0.13, 0.55)
const COL_CANOPY: Color = Color(0.30, 0.48, 0.56)
const COL_ENGINE: Color = Color(0.42, 0.70, 0.92)
const COL_ENGINE_CORE: Color = Color(0.78, 0.90, 1.00)

# Interiors are lit and the hull outside them is not. Floors darker than the
# hull plate made the rooms read as holes cut in the ship rather than as decks
# with the lights on, which is backwards and is most of why it looked like a
# diagram.
const COL_FLOOR: Color = Color(0.178, 0.196, 0.232)
const COL_FLOOR_SYS: Color = Color(0.206, 0.228, 0.268)
const COL_FLOOR_GRID: Color = Color(1.0, 1.0, 1.0, 0.028)
const COL_BEVEL_LIT: Color = Color(1.0, 1.0, 1.0, 0.055)
const COL_BEVEL_DARK: Color = Color(0.0, 0.0, 0.0, 0.30)

const COL_WALL: Color = Color(0.238, 0.262, 0.308)
const COL_WALL_OUTER: Color = Color(0.132, 0.146, 0.176)
const COL_WALL_LIT: Color = Color(0.345, 0.375, 0.435)
const COL_WALL_DARK: Color = Color(0.072, 0.082, 0.100)
const COL_DOOR: Color = Color(0.40, 0.70, 0.78)
const COL_DOOR_LEAF: Color = Color(0.285, 0.315, 0.370)

const COL_TARGET: Color = Color(0.55, 0.78, 0.85)
const COL_LABEL: Color = Color(0.52, 0.58, 0.66)
const COL_TEXT: Color = Color(0.85, 0.88, 0.91)
const COL_TIED: Color = Color(0.62, 0.38, 0.34)
const COL_OUTLINE: Color = Color(0.04, 0.05, 0.07)
const COL_PATH: Color = Color(0.45, 0.70, 0.78, 0.60)
const COL_SHADOW: Color = Color(0.0, 0.0, 0.0, 0.38)

# Kenney's station kit is bright and pastel; Deadweight is cold and worn.
# Modulating the props knocks them into the ship's palette instead of letting
# them glow like stickers. Tuning this is a taste call, so it is one constant.
const COL_PROP: Color = Color(0.70, 0.75, 0.86)
const COL_PROP_SHADOW: Color = Color(0.0, 0.0, 0.0, 0.30)

var scene: RescueScene = null
var layout: ShipLayout = null

var _class_colours: Dictionary = {}
var _props: Dictionary = {}
var _prop_textures: Dictionary = {}
var _origin: Vector2 = Vector2.ZERO
var _font: Font = null
var _clock: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_font = ThemeDB.fallback_font
	_load_class_colours()
	_load_props()


func _process(delta: float) -> void:
	# Positions animate every frame while TOCK is in transit, and the engine
	# glow breathes whether or not anything is happening. This clock is cosmetic
	# only: it never reaches the simulation, so it keeps running while paused
	# without advancing anything that matters.
	_clock += delta
	queue_redraw()


func _load_class_colours() -> void:
	var raw: Dictionary = DataLoader.load_json(DataLoader.CLASSES_PATH)
	for entry: Variant in raw.get("classes", []):
		var c: Dictionary = entry as Dictionary
		_class_colours[str(c.get("id", ""))] = Color(str(c.get("colour", "#b0b0b0")))


func _load_props() -> void:
	var raw: Dictionary = DataLoader.load_json(PROPS_PATH)
	_props = raw.get("rooms", {}) as Dictionary
	for room_id: Variant in _props.keys():
		for entry: Variant in _props[room_id] as Array:
			var name: String = str((entry as Dictionary).get("sprite", ""))
			if name == "" or _prop_textures.has(name):
				continue
			var path: String = PROP_DIR + name + ".png"
			if ResourceLoader.exists(path):
				_prop_textures[name] = load(path) as Texture2D
			else:
				push_error("room_props.json names a missing sprite: %s" % path)


# --- geometry --------------------------------------------------------------

# Rooms grow to fill whatever space the window gives them, clamped so they
# never get so small that six markers collide or so large that the ship stops
# reading as one object.
func _cell() -> Vector2:
	var cols: float = float(maxi(layout.grid_columns, 1))
	var rows: float = float(maxi(layout.grid_rows, 1))
	# Everything that sticks out past the room block — nose, stern, engine pods —
	# comes off the budget before the rooms are sized. Otherwise the hull is
	# drawn outside the control and gets clipped.
	var chrome: Vector2 = Vector2(
		2.0 * (HULL_PAD + MARGIN) + PROW + BRIDGE + STERN,
		2.0 * (HULL_PAD + NACELLE_GAP + NACELLE_H + MARGIN)
	)
	var free: Vector2 = size - chrome - Vector2((cols - 1.0) * GAP, (rows - 1.0) * GAP)
	return Vector2(
		clampf(free.x / cols, CELL_MIN.x, CELL_MAX.x),
		clampf(free.y / rows, CELL_MIN.y, CELL_MAX.y)
	)


# The full extent of the drawn ship, pods and bridge included. Centring on the
# room block instead put the nose off-screen, because the nose is only on one
# side; centring on the body alone would now clip the pods for the same reason.
func _hull_size() -> Vector2:
	return _grid_size() + Vector2(
		2.0 * HULL_PAD + PROW + BRIDGE + STERN,
		2.0 * (HULL_PAD + NACELLE_GAP + NACELLE_H)
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
	var free: Vector2 = ((size - _hull_size()) * 0.5).maxf(0.0)
	_origin = (free + Vector2(
		HULL_PAD + PROW + BRIDGE,
		HULL_PAD + NACELLE_GAP + NACELLE_H
	)).floor()


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
		rect.position + Vector2(10.0, 26.0),
		rect.size - Vector2(20.0, 44.0)
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
	if size.x < 1.0 or size.y < 1.0:
		return
	_recentre()

	_draw_space()
	_draw_hull()
	for room: ShipRoom in layout.rooms:
		_draw_room(room)
	for room: ShipRoom in layout.rooms:
		_draw_props(room)
	_draw_walls()
	if scene.task == RescueScene.Task.TRANSIT:
		_draw_path()
	_draw_crew()
	_draw_vignette()


func _block() -> Rect2:
	return Rect2(_origin, _grid_size())


# --- space -----------------------------------------------------------------

# A deterministic hash rather than a random number generator. CLAUDE.md rule 6
# says the simulation owns the only RNG, and a starfield that reseeded itself
# every frame would flicker anyway. Same integer in, same star out, forever.
func _hash01(n: int) -> float:
	var x: int = (n * 374761393 + 668265263) & 0x7fffffff
	x = ((x ^ (x >> 13)) * 1274126177) & 0x7fffffff
	return float(x % 100003) / 100003.0


func _draw_space() -> void:
	# A shallow vertical gradient, drawn as bands. Flat black made the hull look
	# like a diagram on a page; anything with a direction to it reads as a place.
	var bands: int = 16
	for i: int in range(bands):
		var t: float = float(i) / float(bands - 1)
		draw_rect(
			Rect2(
				Vector2(0.0, size.y * float(i) / float(bands)),
				Vector2(size.x, size.y / float(bands) + 1.0)
			),
			COL_SPACE.lerp(COL_SPACE_WARM, t)
		)

	# One soft dust cloud, low and to the left, so the frame is not uniform.
	var centre: Vector2 = Vector2(size.x * 0.24, size.y * 0.78)
	for i: int in range(9):
		draw_circle(centre, size.y * (0.10 + 0.045 * float(i)), COL_NEBULA)

	for i: int in range(STAR_COUNT):
		var p: Vector2 = Vector2(_hash01(i * 3 + 1) * size.x, _hash01(i * 3 + 2) * size.y)
		var b: float = _hash01(i * 3 + 3)
		var alpha: float = 0.12 + b * b * 0.72
		var radius: float = 0.7 + b * b * b * 1.9
		draw_circle(p, radius, Color(COL_STAR, alpha))
		# The brightest few get a cross flare, which is what stops a starfield
		# from reading as sensor noise.
		if b > 0.972:
			var arm: float = 2.6 + b * 3.0
			draw_line(p - Vector2(arm, 0.0), p + Vector2(arm, 0.0), Color(COL_STAR, 0.34), 1.0)
			draw_line(p - Vector2(0.0, arm), p + Vector2(0.0, arm), Color(COL_STAR, 0.34), 1.0)


# --- hull ------------------------------------------------------------------

func _draw_hull() -> void:
	var b: Rect2 = _block()
	var x0: float = b.position.x - HULL_PAD
	var y0: float = b.position.y - HULL_PAD
	var x1: float = b.end.x + HULL_PAD
	var y1: float = b.end.y + HULL_PAD
	var ym: float = b.get_center().y
	var neck: float = (y1 - y0) * NECK
	var nose_x: float = x0 - PROW
	var stern_x: float = x1 + STERN
	var taper: float = (y1 - y0) * 0.16

	var body: PackedVector2Array = PackedVector2Array([
		Vector2(nose_x, ym - neck),
		Vector2(x0, y0 + CHAMFER),
		Vector2(x0 + CHAMFER, y0),
		Vector2(x1 - CHAMFER, y0),
		Vector2(x1, y0 + CHAMFER),
		Vector2(stern_x, y0 + CHAMFER + taper),
		Vector2(stern_x, y1 - CHAMFER - taper),
		Vector2(x1, y1 - CHAMFER),
		Vector2(x1 - CHAMFER, y1),
		Vector2(x0 + CHAMFER, y1),
		Vector2(x0, y1 - CHAMFER),
		Vector2(nose_x, ym + neck),
	])

	# A dropped copy first: the body sits on its own shadow, which is what
	# separates it from the starfield instead of floating in front of it.
	var shadow: PackedVector2Array = PackedVector2Array()
	for p: Vector2 in body:
		shadow.append(p + Vector2(0.0, 5.0))
	draw_colored_polygon(shadow, COL_HULL_DARK)

	draw_colored_polygon(body, COL_HULL_PLATE)
	_draw_hull_plating(x0, x1, y0, y1, nose_x, stern_x, ym, neck)
	draw_polyline(body + PackedVector2Array([body[0]]), COL_HULL_LINE, 2.0)

	# Rim light along the upper edges only. One light source, from above and
	# ahead, is the cheapest thing that makes flat shapes read as solid.
	draw_polyline(
		PackedVector2Array([body[0], body[1], body[2], body[3], body[4]]),
		COL_HULL_LIT, 2.5
	)

	_draw_bridge(nose_x, ym, neck)
	_draw_stern_exhaust(stern_x, y0 + CHAMFER + taper, y1 - CHAMFER - taper)

	# Pods last, so their pylons overlap the hull edge instead of disappearing
	# underneath it. Drawn first, they read as two objects flying in formation
	# beside the ship rather than as parts bolted to it.
	_draw_nacelle(x0, x1, stern_x, y0, true)
	_draw_nacelle(x0, x1, stern_x, y1, false)


func _draw_hull_plating(
	x0: float, x1: float, y0: float, y1: float,
	nose_x: float, stern_x: float, ym: float, neck: float
) -> void:
	# The room block covers the middle of the hull, so plating is only drawn
	# where hull is actually visible: the nose taper, the stern, and the narrow
	# pad ring around the rooms.
	for i: int in range(1, 3):
		var t: float = float(i) / 3.0
		var x: float = lerpf(nose_x, x0, t)
		var h: float = lerpf(neck, (y1 - y0) * 0.5, t)
		draw_line(Vector2(x, ym - h + 5.0), Vector2(x, ym + h - 5.0), COL_PANEL_LINE, 1.0)

	var x_stern: float = lerpf(x1, stern_x, 0.5)
	draw_line(Vector2(x_stern, y0 + 16.0), Vector2(x_stern, y1 - 16.0), COL_PANEL_LINE, 1.0)

	var step: float = 74.0
	var x_tick: float = x0 + step
	while x_tick < x1:
		draw_line(Vector2(x_tick, y0), Vector2(x_tick, y0 + HULL_PAD), COL_PANEL_LINE, 1.5)
		draw_line(Vector2(x_tick, y1 - HULL_PAD), Vector2(x_tick, y1), COL_PANEL_LINE, 1.5)
		x_tick += step

	_draw_hull_details(x0, x1, y0, y1)


# Greebles. A hull with nothing on it reads as a shape; a hull with a docking
# collar and a mast on it reads as equipment. Both sit in the pad ring, which is
# the only part of the hull the room block does not cover.
func _draw_hull_details(x0: float, x1: float, y0: float, y1: float) -> void:
	var collar_x: float = lerpf(x0, x1, 0.30)
	var collar: Rect2 = Rect2(Vector2(collar_x - 26.0, y0 + 4.0), Vector2(52.0, HULL_PAD - 8.0))
	draw_rect(collar, COL_HULL_DARK, true)
	draw_rect(collar, COL_HULL_LINE, false, 1.5)
	draw_line(
		Vector2(collar_x, collar.position.y + 3.0), Vector2(collar_x, collar.end.y - 3.0),
		COL_HULL_LIT, 1.5
	)

	var mast_x: float = lerpf(x0, x1, 0.62)
	draw_line(Vector2(mast_x, y1 - 4.0), Vector2(mast_x, y1 + 22.0), COL_HULL_LINE, 2.0)
	draw_line(
		Vector2(mast_x - 9.0, y1 + 18.0), Vector2(mast_x + 9.0, y1 + 18.0), COL_HULL_LINE, 1.5
	)
	draw_circle(Vector2(mast_x, y1 + 22.0), 2.5, COL_ENGINE)

	# Two hull tanks along the underside, forward of the mast.
	for i: int in range(2):
		var tank: Rect2 = Rect2(
			Vector2(lerpf(x0, x1, 0.16 + 0.11 * float(i)), y1 - HULL_PAD + 5.0),
			Vector2(30.0, HULL_PAD - 10.0)
		)
		draw_rect(tank, COL_HULL_DARK, true)
		draw_rect(tank, COL_HULL_LINE, false, 1.0)


# Engine nacelles carried outside the body on struts, running most of the hull's
# length. Short stubby pods at the stern read as two darts flying in formation;
# long parallel booms give the ship a direction and a length, which is what a
# wide, short hull has no way to express on its own.
func _draw_nacelle(x_fwd: float, x_body: float, x_aft: float, y_edge: float, is_top: bool) -> void:
	var nose: float = 30.0
	var pod_x0: float = x_fwd + CHAMFER * 0.5
	var pod_x1: float = x_aft - 2.0
	var top: float = y_edge - NACELLE_GAP - NACELLE_H if is_top else y_edge + NACELLE_GAP
	var bottom: float = top + NACELLE_H
	var mid_y: float = (top + bottom) * 0.5

	# Struts first, so the boom is drawn over their tops. They are spaced across
	# the straight part of the hull edge only: further aft or forward the edge is
	# chamfering away and the strut foot would stand over empty space.
	var straight_a: float = x_fwd + CHAMFER
	var straight_b: float = x_body - CHAMFER
	for t: float in [0.14, 0.52, 0.88]:
		var sx: float = lerpf(straight_a, straight_b, t)
		var root: float = y_edge + (10.0 if is_top else -10.0)
		var strut: PackedVector2Array = PackedVector2Array([
			Vector2(sx - 7.0, mid_y), Vector2(sx + 7.0, mid_y),
			Vector2(sx + 15.0, root), Vector2(sx - 15.0, root),
		])
		draw_colored_polygon(strut, COL_HULL_PLATE)
		draw_polyline(
			PackedVector2Array([Vector2(sx - 7.0, mid_y), Vector2(sx - 15.0, root)]),
			COL_HULL_LINE, 1.5
		)
		draw_polyline(
			PackedVector2Array([Vector2(sx + 7.0, mid_y), Vector2(sx + 15.0, root)]),
			COL_HULL_LINE, 1.5
		)

	var boom: PackedVector2Array = PackedVector2Array([
		Vector2(pod_x0, mid_y),
		Vector2(pod_x0 + nose, top),
		Vector2(pod_x1, top),
		Vector2(pod_x1, bottom),
		Vector2(pod_x0 + nose, bottom),
	])
	var boom_shadow: PackedVector2Array = PackedVector2Array()
	for p: Vector2 in boom:
		boom_shadow.append(p + Vector2(0.0, 4.0))
	draw_colored_polygon(boom_shadow, COL_HULL_DARK)
	draw_colored_polygon(boom, COL_HULL_PLATE)
	draw_polyline(boom + PackedVector2Array([boom[0]]), COL_HULL_LINE, 2.0)
	draw_line(
		Vector2(pod_x0 + nose, top if is_top else bottom),
		Vector2(pod_x1, top if is_top else bottom),
		COL_HULL_LIT, 2.0
	)
	draw_line(
		Vector2(pod_x0 + nose + 10.0, mid_y), Vector2(pod_x1 - 12.0, mid_y),
		COL_PANEL_LINE, 1.5
	)
	# Plating across the boom, which is what keeps a long thin shape from reading
	# as a drawn line rather than as a built object.
	var tick: float = pod_x0 + nose + 40.0
	while tick < pod_x1 - 30.0:
		draw_line(Vector2(tick, top + 4.0), Vector2(tick, bottom - 4.0), COL_PANEL_LINE, 1.0)
		tick += 62.0

	_draw_exhaust(pod_x1, top + 4.0, bottom - 4.0)


# A slow breath rather than a flicker. The engines are lit whether or not the
# ship is moving, because in this scene it is adrift and the reactor is up —
# and because a dead ship with dead engines reads as a screenshot.
func _draw_exhaust(x: float, y_top: float, y_bottom: float) -> void:
	var pulse: float = 0.78 + 0.22 * sin(_clock * 1.7)
	var h: float = y_bottom - y_top
	for i: int in range(5):
		var t: float = float(i) / 4.0
		var w: float = 4.0 + t * 15.0
		var shrink: float = t * h * 0.24
		draw_rect(
			Rect2(Vector2(x, y_top + shrink), Vector2(w, h - shrink * 2.0)),
			Color(COL_ENGINE, (0.32 - t * 0.055) * pulse)
		)
	draw_rect(
		Rect2(Vector2(x - 3.0, y_top + 2.0), Vector2(6.0, h - 4.0)),
		Color(COL_ENGINE_CORE, 0.62 * pulse)
	)


func _draw_bridge(nose_x: float, ym: float, neck: float) -> void:
	var x0: float = nose_x - BRIDGE
	var module: PackedVector2Array = PackedVector2Array([
		Vector2(x0 + 4.0, ym - neck * 0.36),
		Vector2(x0 + 14.0, ym - neck * 0.76),
		Vector2(nose_x + 6.0, ym - neck),
		Vector2(nose_x + 6.0, ym + neck),
		Vector2(x0 + 14.0, ym + neck * 0.76),
		Vector2(x0 + 4.0, ym + neck * 0.36),
	])
	draw_colored_polygon(module, COL_HULL_PLATE)
	draw_polyline(module + PackedVector2Array([module[0]]), COL_HULL_LINE, 2.0)
	draw_polyline(
		PackedVector2Array([module[0], module[1], module[2]]), COL_HULL_LIT, 2.0
	)

	# The canopy. Small, off-centre toward the top, and the only warm-cool break
	# on the whole hull — so the eye finds the front of the ship immediately.
	var canopy: PackedVector2Array = PackedVector2Array([
		Vector2(x0 + 13.0, ym - neck * 0.44),
		Vector2(x0 + 19.0, ym - neck * 0.66),
		Vector2(nose_x + 2.0, ym - neck * 0.74),
		Vector2(nose_x + 2.0, ym - neck * 0.10),
	])
	draw_colored_polygon(canopy, COL_CANOPY)
	draw_polyline(canopy + PackedVector2Array([canopy[0]]), COL_HULL_LIT, 1.0)


func _draw_stern_exhaust(x: float, y_top: float, y_bottom: float) -> void:
	var h: float = (y_bottom - y_top) * 0.26
	var mid: float = (y_top + y_bottom) * 0.5
	_draw_exhaust(x, mid - h - 6.0, mid - 6.0)
	_draw_exhaust(x, mid + 6.0, mid + h + 6.0)


# --- rooms -----------------------------------------------------------------

func _draw_room(room: ShipRoom) -> void:
	var rect: Rect2 = _room_rect(room)
	draw_rect(rect, COL_FLOOR_SYS if room.system != "" else COL_FLOOR, true)
	_draw_floor_grid(rect)
	_draw_bevel(rect)

	# Inset past the walls, which are drawn on top of the rooms. At 3px the
	# destination marker was hidden underneath the wall bars entirely.
	if _is_target(room.id):
		draw_rect(rect, Color(COL_TARGET, 0.13), true)
		draw_rect(rect.grow(-9.0), Color(COL_TARGET, 0.55), false, 2.0)

	# Letterspaced and dim: chrome that names the room without competing with the
	# crew standing in it. Full-brightness text made every room look like a form
	# field; along the bottom edge it collided with the crew name plates, which
	# is where the slot grid puts its last row.
	_draw_tracked(
		rect.position + Vector2(12.0, 19.0), room.label, 10, COL_LABEL, 1.8
	)


func _draw_floor_grid(rect: Rect2) -> void:
	var x: float = rect.position.x + FLOOR_GRID
	while x < rect.end.x - 1.0:
		draw_line(Vector2(x, rect.position.y), Vector2(x, rect.end.y), COL_FLOOR_GRID, 1.0)
		x += FLOOR_GRID
	var y: float = rect.position.y + FLOOR_GRID
	while y < rect.end.y - 1.0:
		draw_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y), COL_FLOOR_GRID, 1.0)
		y += FLOOR_GRID


# Light from the top-left, shadow bottom-right. Two lines per room, and the
# floors stop being flat colour and start being recessed.
func _draw_bevel(rect: Rect2) -> void:
	var a: Vector2 = rect.position + Vector2(1.0, 1.0)
	var b: Vector2 = Vector2(rect.end.x - 1.0, rect.position.y + 1.0)
	var c: Vector2 = Vector2(rect.position.x + 1.0, rect.end.y - 1.0)
	var d: Vector2 = rect.end - Vector2(1.0, 1.0)
	draw_line(a, b, COL_BEVEL_LIT, 2.0)
	draw_line(a, c, COL_BEVEL_LIT, 2.0)
	draw_line(c, d, COL_BEVEL_DARK, 3.0)
	draw_line(b, d, COL_BEVEL_DARK, 3.0)


func _is_target(room_id: String) -> bool:
	return scene.task == RescueScene.Task.TRANSIT and not scene.route.is_empty() \
		and scene.route[scene.route.size() - 1] == room_id


# --- props -----------------------------------------------------------------

# Furniture. Decoration only: nothing here is clickable, the simulation does not
# know it exists, and an empty props list is the normal case.
func _draw_props(room: ShipRoom) -> void:
	if not _props.has(room.id):
		return
	var rect: Rect2 = _room_rect(room)
	for entry: Variant in _props[room.id] as Array:
		var d: Dictionary = entry as Dictionary
		var name: String = str(d.get("sprite", ""))
		if not _prop_textures.has(name):
			continue
		var tex: Texture2D = _prop_textures[name] as Texture2D
		if tex == null or tex.get_height() == 0:
			continue

		var h: float = rect.size.y * float(d.get("size", 0.25))
		var w: float = h * float(tex.get_width()) / float(tex.get_height())
		var centre: Vector2 = rect.position + Vector2(
			rect.size.x * float(d.get("x", 0.5)), rect.size.y * float(d.get("y", 0.5))
		)
		var dst: Rect2 = Rect2((centre - Vector2(w, h) * 0.5).floor(), Vector2(w, h))

		# The same sprite drawn twice: once offset and flattened to black as a
		# contact shadow, then the sprite itself. Without it the furniture floats.
		draw_texture_rect(
			tex, Rect2(dst.position + Vector2(2.0, 5.0), dst.size), false, COL_PROP_SHADOW
		)
		draw_texture_rect(tex, dst, false, COL_PROP)


# --- walls -----------------------------------------------------------------

# Interior walls between grid neighbours, with a door exactly where the
# adjacency list says two rooms connect. Where two rooms touch but are not
# adjacent, the wall is solid — so the drawing and the rule the simulation uses
# cannot drift apart.
func _draw_walls() -> void:
	for room: ShipRoom in layout.rooms:
		var rect: Rect2 = _room_rect(room)
		var right: ShipRoom = _room_at(room.col + 1, room.row)
		if right != null:
			_wall(
				Vector2(rect.end.x, rect.position.y),
				Vector2(rect.end.x, rect.end.y),
				layout.are_adjacent(room.id, right.id), true
			)
		var below: ShipRoom = _room_at(room.col, room.row + 1)
		if below != null:
			_wall(
				Vector2(rect.position.x, rect.end.y),
				Vector2(rect.end.x, rect.end.y),
				layout.are_adjacent(room.id, below.id), false
			)
	_draw_outer_wall()


func _room_at(col: int, row: int) -> ShipRoom:
	for room: ShipRoom in layout.rooms:
		if room.col == col and room.row == row:
			return room
	return null


# Walls used to be 2px lines, which is a floor plan, not a ship. Real thickness
# with a lit edge is what makes the rooms read as compartments cut into a hull.
func _wall(from: Vector2, to: Vector2, has_door: bool, vertical: bool) -> void:
	if not has_door:
		_wall_bar(from, to, WALL_W, vertical)
		return
	var mid: Vector2 = (from + to) * 0.5
	var half: Vector2 = (to - from) * (DOOR * 0.5)
	_wall_bar(from, mid - half, WALL_W, vertical)
	_wall_bar(mid + half, to, WALL_W, vertical)
	_door(mid - half, mid + half, vertical)


func _wall_bar(from: Vector2, to: Vector2, w: float, vertical: bool) -> void:
	var rect: Rect2
	if vertical:
		rect = Rect2(Vector2(from.x - w * 0.5, from.y), Vector2(w, to.y - from.y))
	else:
		rect = Rect2(Vector2(from.x, from.y - w * 0.5), Vector2(to.x - from.x, w))
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	draw_rect(rect, COL_WALL, true)
	if vertical:
		draw_line(rect.position, Vector2(rect.position.x, rect.end.y), COL_WALL_LIT, 1.5)
		draw_line(Vector2(rect.end.x, rect.position.y), rect.end, COL_WALL_DARK, 1.5)
	else:
		draw_line(rect.position, Vector2(rect.end.x, rect.position.y), COL_WALL_LIT, 1.5)
		draw_line(Vector2(rect.position.x, rect.end.y), rect.end, COL_WALL_DARK, 1.5)


# A door is a recess with two leaves parked either side and a lit threshold
# between them. The gap is where the simulation says crew may pass.
func _door(from: Vector2, to: Vector2, vertical: bool) -> void:
	var w: float = WALL_W + 3.0
	var rect: Rect2
	if vertical:
		rect = Rect2(Vector2(from.x - w * 0.5, from.y), Vector2(w, to.y - from.y))
	else:
		rect = Rect2(Vector2(from.x, from.y - w * 0.5), Vector2(to.x - from.x, w))
	draw_rect(rect, COL_WALL_DARK, true)

	var leaf: float = 0.24
	if vertical:
		var span: float = rect.size.y
		draw_rect(Rect2(rect.position, Vector2(w, span * leaf)), COL_DOOR_LEAF, true)
		draw_rect(
			Rect2(Vector2(rect.position.x, rect.end.y - span * leaf), Vector2(w, span * leaf)),
			COL_DOOR_LEAF, true
		)
		var x: float = rect.get_center().x
		draw_line(
			Vector2(x, rect.position.y + span * leaf),
			Vector2(x, rect.end.y - span * leaf), COL_DOOR, 2.0
		)
	else:
		var span: float = rect.size.x
		draw_rect(Rect2(rect.position, Vector2(span * leaf, w)), COL_DOOR_LEAF, true)
		draw_rect(
			Rect2(Vector2(rect.end.x - span * leaf, rect.position.y), Vector2(span * leaf, w)),
			COL_DOOR_LEAF, true
		)
		var y: float = rect.get_center().y
		draw_line(
			Vector2(rect.position.x + span * leaf, y),
			Vector2(rect.end.x - span * leaf, y), COL_DOOR, 2.0
		)


# The pressure hull, drawn darker than the interior partitions. Lit to the same
# brightness it competed with the ship's own silhouette, and a bright rectangle
# around the rooms is precisely the shape this pass exists to get rid of.
func _draw_outer_wall() -> void:
	var b: Rect2 = _block()
	for corner: Array in [
		[b.position, Vector2(b.end.x, b.position.y), false],
		[Vector2(b.position.x, b.end.y), b.end, false],
		[b.position, Vector2(b.position.x, b.end.y), true],
		[Vector2(b.end.x, b.position.y), b.end, true],
	]:
		var from: Vector2 = corner[0] as Vector2
		var to: Vector2 = corner[1] as Vector2
		var vertical: bool = corner[2] as bool
		var rect: Rect2
		if vertical:
			rect = Rect2(
				Vector2(from.x - WALL_OUTER * 0.5, from.y), Vector2(WALL_OUTER, to.y - from.y)
			)
		else:
			rect = Rect2(
				Vector2(from.x, from.y - WALL_OUTER * 0.5), Vector2(to.x - from.x, WALL_OUTER)
			)
		draw_rect(rect, COL_WALL_OUTER, true)
	draw_rect(_block().grow(WALL_OUTER * 0.5), COL_WALL_DARK, false, 1.5)


# --- route, crew, framing --------------------------------------------------

# The whole remaining route, not just the current hop. `route` holds every room
# still to be entered, so the player sees the path they actually ordered.
func _draw_path() -> void:
	var points: PackedVector2Array = PackedVector2Array([_tock_position()])
	for room_id: String in scene.route:
		points.append(_room_centre(room_id))
	if points.size() < 2:
		return

	for i: int in range(points.size() - 1):
		_dashed(points[i], points[i + 1])

	var end: Vector2 = points[points.size() - 1]
	var pulse: float = 7.0 + 2.0 * sin(_clock * 4.0)
	draw_arc(end, pulse, 0.0, TAU, 24, COL_PATH, 2.0)


func _dashed(a: Vector2, b: Vector2) -> void:
	var total: float = a.distance_to(b)
	if total < 1.0:
		return
	var dir: Vector2 = (b - a) / total
	var dash: float = 9.0
	var gap: float = 7.0
	# The offset crawls along the line, so a standing order reads as movement.
	var t: float = fmod(_clock * 26.0, dash + gap)
	var d: float = -t
	while d < total:
		var s: float = maxf(d, 0.0)
		var e: float = minf(d + dash, total)
		if e > s:
			draw_line(a + dir * s, a + dir * e, COL_PATH, 2.5)
		d += dash + gap


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

	# Cast shadow, then the disc shaded from the same top-left light as the
	# rooms: a lit crown and a darker skirt, so the marker reads as a body.
	draw_circle(at + Vector2(1.0, 4.0), CREW_RADIUS + 1.0, COL_SHADOW)
	draw_circle(at, CREW_RADIUS + 2.0, COL_OUTLINE)
	draw_circle(at, CREW_RADIUS, colour.darkened(0.28))
	draw_circle(at - Vector2(0.0, 1.5), CREW_RADIUS - 2.0, colour)
	draw_arc(
		at, CREW_RADIUS - 3.0, PI * 1.15, PI * 1.85, 16,
		colour.lightened(0.35), 2.0
	)

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
	# A dark plate behind the name. Over a textured floor, unbacked small text is
	# the first thing that stops being readable.
	var plate: Rect2 = Rect2(
		at + Vector2(-34.0, CREW_RADIUS + 3.0), Vector2(68.0, 14.0)
	)
	draw_rect(plate, Color(0.04, 0.05, 0.07, 0.62), true)
	draw_string(
		_font, at + Vector2(-34.0, CREW_RADIUS + 14.0), label,
		HORIZONTAL_ALIGNMENT_CENTER, 68.0, 11, COL_TEXT
	)
	if member.is_tied():
		draw_string(
			_font, at + Vector2(-34.0, CREW_RADIUS + 27.0), "TIED",
			HORIZONTAL_ALIGNMENT_CENTER, 68.0, 10, COL_TIED
		)

	if scene.task == RescueScene.Task.FREEING and scene.task_target == member.id:
		var w: float = 44.0
		var bar: Rect2 = Rect2(at + Vector2(-w * 0.5, CREW_RADIUS + 20.0), Vector2(w, 4.0))
		draw_rect(bar, COL_OUTLINE)
		draw_rect(
			Rect2(bar.position, Vector2(w * scene.task_progress(), 4.0)), COL_TARGET
		)


# Darkens the frame edges so the eye settles on the ship. Drawn as nested
# outlines because the alternative is a shader, and CLAUDE.md rule 2 keeps this
# to what Control can do on its own.
func _draw_vignette() -> void:
	var steps: int = 22
	for i: int in range(steps):
		var t: float = float(i) / float(steps)
		draw_rect(
			Rect2(Vector2(i, i), size - Vector2(i * 2, i * 2)),
			Color(0.0, 0.0, 0.0, 0.055 * (1.0 - t) * (1.0 - t)),
			false, 1.0
		)


# Draws text with letter spacing, which draw_string cannot do. Used for room
# labels, where tracking is most of the difference between "a label" and "a
# label on a machine".
func _draw_tracked(
	pos: Vector2, text: String, font_size: int, colour: Color, tracking: float
) -> void:
	var pen: Vector2 = pos
	for i: int in range(text.length()):
		var code: int = text.unicode_at(i)
		_font.draw_char(get_canvas_item(), pen, code, font_size, colour)
		pen.x += _font.get_char_size(code, font_size).x + tracking


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
