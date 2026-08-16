extends Control
class_name TwoShipTest

# Does the game actually fit two ships side by side?
#
# Open tools/two_ship_test.tscn in Godot and press F6 (Run Current Scene).
# Then resize the window and watch the readout at the bottom.
#
# This is a measuring instrument, not a screen. It draws the player plate twice
# at identical scale with reserved bands above and below where the real UI will
# go, and prints the numbers that decide whether the layout works:
#
#   ship scale   how much the plate is shrunk to fit
#   room         how many pixels a compartment is across on screen
#   crew         how many pixels a crew figure is
#
# The last one is the one that matters. Crew are the smallest thing a player has
# to identify and click, so they are what runs out of room first.
#
# Nothing here is wired to the simulation. It answers a layout question and
# deliberately answers nothing else.

# Both ships render at ONE scale, chosen by whichever ship is more constrained.
# Two ships at different sizes would read as one being nearer the camera, which
# is wrong — they are two ships in space seen from the same distance.
const GUTTER: float = 24.0

# Reserved for the UI chrome that is not built yet. The point of showing them
# empty is that the ships must still fit once these are full.
const TOP_BAND: float = 76.0
const BOTTOM_BAND: float = 132.0

const BG: Color = Color(0.055, 0.063, 0.078)
const BAND: Color = Color(0.10, 0.115, 0.14)
const EDGE: Color = Color(0.24, 0.27, 0.33)
const TEXT: Color = Color(0.86, 0.89, 0.94)
const DIM: Color = Color(0.52, 0.57, 0.66)
const GOOD: Color = Color(0.55, 0.83, 0.62)
const POOR: Color = Color(0.90, 0.62, 0.42)

# Below this many pixels a crew figure stops being a person and starts being a
# smudge. Judged by eye against the current build, where crew draw at about 35.
const CREW_PX_COMFORTABLE: float = 30.0

var _layout: ShipLayout = null
var _plate: Texture2D = null
var _font: Font = null
var _readout: Label = null
var _mirror_enemy: bool = false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_font = ThemeDB.fallback_font
	_layout = DataLoader.load_layout()
	_plate = load(_layout.plate_path) as Texture2D
	if _plate == null:
		push_error("could not load the ship plate: %s" % _layout.plate_path)

	_readout = Label.new()
	_readout.add_theme_font_size_override("font_size", 14)
	_readout.position = Vector2(18.0, 10.0)
	_readout.custom_minimum_size = Vector2(900.0, 22.0)
	add_child(_readout)

	set_process(true)


func _process(_delta: float) -> void:
	queue_redraw()


func _unhandled_key_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed:
		return
	# M mirrors the enemy so the two ships face each other. Worth being able to
	# flip, because which way an enemy faces changes how the pair reads and it
	# is a decision nobody has made yet.
	if key.keycode == KEY_M:
		_mirror_enemy = not _mirror_enemy
	elif key.keycode == KEY_ESCAPE:
		get_tree().quit()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BG)
	if _plate == null:
		draw_string(_font, Vector2(20.0, 60.0), "no plate", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, POOR)
		return

	var plate: Vector2 = _layout.plate_size
	var band_h: float = maxf(size.y - TOP_BAND - BOTTOM_BAND, 1.0)
	var each_w: float = (size.x - GUTTER) * 0.5

	# One scale for both, and it must satisfy width and height at once.
	var scale: float = minf(each_w / plate.x, band_h / plate.y)
	var drawn: Vector2 = plate * scale
	var y: float = TOP_BAND + (band_h - drawn.y) * 0.5
	var left_x: float = (each_w - drawn.x) * 0.5
	var right_x: float = each_w + GUTTER + (each_w - drawn.x) * 0.5

	_draw_band(Rect2(0.0, 0.0, size.x, TOP_BAND), "UI BAND — reserved, top")
	_draw_band(
		Rect2(0.0, size.y - BOTTOM_BAND, size.x, BOTTOM_BAND), "UI BAND — reserved, bottom"
	)

	_draw_ship(Rect2(Vector2(left_x, y), drawn), false, "PLAYER")
	_draw_ship(Rect2(Vector2(right_x, y), drawn), _mirror_enemy, "ENEMY (same plate, same scale)")

	# The gutter, drawn so it is obvious the two are not touching.
	draw_line(
		Vector2(each_w + GUTTER * 0.5, TOP_BAND),
		Vector2(each_w + GUTTER * 0.5, size.y - BOTTOM_BAND),
		Color(EDGE, 0.35), 1.0
	)

	_update_readout(scale, drawn)


func _draw_band(rect: Rect2, label: String) -> void:
	draw_rect(rect, BAND)
	draw_line(
		Vector2(rect.position.x, rect.end.y), Vector2(rect.end.x, rect.end.y), Color(EDGE, 0.5), 1.0
	)
	draw_string(
		_font, Vector2(rect.position.x + 18.0, rect.end.y - 12.0), label,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 12, DIM
	)


func _draw_ship(rect: Rect2, mirrored: bool, label: String) -> void:
	if mirrored:
		# draw_texture_rect_region with a negative width flips horizontally.
		draw_texture_rect_region(
			_plate, Rect2(rect.end.x, rect.position.y, -rect.size.x, rect.size.y),
			Rect2(Vector2.ZERO, _layout.plate_size)
		)
	else:
		draw_texture_rect(_plate, rect, false)

	# The room outlines are the honest test of legibility: if a compartment is
	# too small to click, it is too small at this scale.
	var scale: float = rect.size.x / _layout.plate_size.x
	for room: ShipRoom in _layout.rooms:
		if room.polygon.size() < 3:
			continue
		var pts: PackedVector2Array = PackedVector2Array()
		for p: Vector2 in room.polygon:
			var local: Vector2 = p * scale
			if mirrored:
				local.x = rect.size.x - local.x
			pts.append(rect.position + local)
		pts.append(pts[0])
		draw_polyline(pts, Color(0.42, 0.72, 0.82, 0.45), 1.0)

	# A crew-sized marker in every room, at the size ShipView actually draws
	# them. This is the whole question in one dot.
	var crew_px: float = 128.0 * 0.52 * scale
	for room: ShipRoom in _layout.rooms:
		if room.polygon.size() < 3:
			continue
		var c: Vector2 = room.centre() * scale
		if mirrored:
			c.x = rect.size.x - c.x
		draw_circle(rect.position + c, crew_px * 0.5, Color(0.95, 0.83, 0.45, 0.75))

	draw_string(
		_font, Vector2(rect.position.x, rect.position.y - 8.0), label,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 13, DIM
	)


func _update_readout(scale: float, drawn: Vector2) -> void:
	var room_px: float = 200.0 * scale
	var crew_px: float = 128.0 * 0.52 * scale
	var verdict: String = "fits" if crew_px >= CREW_PX_COMFORTABLE else "TOO SMALL"
	_readout.add_theme_color_override(
		"font_color", GOOD if crew_px >= CREW_PX_COMFORTABLE else POOR
	)
	_readout.text = (
		"window %d x %d    ship scale %.3f    each ship %d x %d    room ~%d px    crew ~%d px    %s"
		% [
			int(size.x), int(size.y), scale, int(drawn.x), int(drawn.y),
			int(room_px), int(crew_px), verdict,
		]
	)
	if _readout.get_parent() != null:
		var hint: String = "   [M] mirror enemy   [ESC] quit"
		_readout.text += hint
