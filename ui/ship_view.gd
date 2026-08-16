extends Control
class_name ShipView

# The ship view. The ship is a painted plate; this builds a small Node2D world
# on top of it and lights it with the engine.
#
# CLAUDE.md rule 2: hull, compartment floors, bulkheads and doors come from
# assets/ship/hull_plate.png. Nothing here draws them. What this file owns is
# the scene graph — plate, lights, particles, crew sprites — plus hit-testing
# and the mapping between plate pixels and screen pixels. Changing state is
# drawn by ShipOverlay.
#
# The plate is modulated down to near-darkness and the PointLight2Ds bring it
# back. That is not decoration: an unpowered or wrecked compartment can simply
# go dark, which is a state change the player reads instantly and which the log
# also records in words.
#
# No .tscn is created — every node here is built in code, per rule 1.

signal room_clicked(room_id: String)
signal crew_clicked(crew_id: String)

# How dark the plate sits before any light touches it. Lights add on top, so
# this is the "lights out" look of the ship.
const AMBIENT: Color = Color(0.82, 0.85, 0.92)

const LIGHT_ENERGY: float = 0.85
const LIGHT_WARM: Color = Color(1.0, 0.94, 0.84)
const LIGHT_REACTOR: Color = Color(1.0, 0.68, 0.34)
const CREW_HIT_RADIUS: float = 48.0
const CREW_TEX: int = 96
const SLOT_SPREAD: float = 152.0

# How far the ship may exceed the panel height before it is scaled back. The
# plate carries empty space above and below the hull, so a little overflow costs
# nothing visible and buys a much larger ship.
const SLOT_ROW: float = 172.0
const OVERFLOW: float = 1.30

var scene: RescueScene = null
var layout: ShipLayout = null

var _world: Node2D = null
var _plate: Sprite2D = null
var _overlay: ShipOverlay = null
var _crew_layer: Node2D = null
var _lights: Dictionary = {}
var _crew_sprites: Dictionary = {}
var _class_colours: Dictionary = {}
var _clock: float = 0.0
var _fit_scale: float = 1.0
var _hover_room: String = ""
var _hover_crew: String = ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	_load_class_colours()


# main.gd assigns scene and layout after construction, so the world is built on
# the first frame that has both rather than in _ready.
func _build() -> void:
	_world = Node2D.new()
	add_child(_world)

	_plate = Sprite2D.new()
	_plate.centered = false
	_plate.texture = _plate_texture()
	_plate.modulate = AMBIENT
	_world.add_child(_plate)

	for room: ShipRoom in layout.rooms:
		_add_room_light(room)

	_crew_layer = Node2D.new()
	_world.add_child(_crew_layer)

	_overlay = ShipOverlay.new()
	_overlay.scene = scene
	_overlay.layout = layout
	_overlay.view = self
	_world.add_child(_overlay)


# Diffuse and normal in one CanvasTexture. Without the normal map a PointLight2D
# just brightens a region evenly, which looks like a torch shone at a
# photograph; with it, the plating catches light edge-on and reads as relief.
func _plate_texture() -> Texture2D:
	var diffuse: Texture2D = load(layout.plate_path) as Texture2D
	var normal: Texture2D = load(layout.plate_normal_path) as Texture2D
	if diffuse == null:
		push_error("ship plate missing: %s" % layout.plate_path)
		return null
	if normal == null:
		return diffuse

	var tex: CanvasTexture = CanvasTexture.new()
	tex.diffuse_texture = diffuse
	tex.normal_texture = normal
	tex.specular_shininess = 0.35
	return tex


func _add_room_light(room: ShipRoom) -> void:
	var light: PointLight2D = PointLight2D.new()
	light.texture = _light_texture()
	light.position = room.centre()
	light.color = LIGHT_REACTOR if room.id == "reactor" else LIGHT_WARM
	light.energy = LIGHT_ENERGY
	light.blend_mode = Light2D.BLEND_MODE_ADD

	# Sized to the compartment, so a long hold gets a long pool of light and a
	# small one does not spill into its neighbours.
	var extent: Rect2 = _polygon_bounds(room.polygon)
	light.texture_scale = maxf(extent.size.x, extent.size.y) / 256.0 * 1.15
	_world.add_child(light)
	_lights[room.id] = light


func _light_texture() -> Texture2D:
	var grad: Gradient = Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1))
	grad.set_color(1, Color(1, 1, 1, 0))
	grad.add_point(0.55, Color(1, 1, 1, 0.55))

	var tex: GradientTexture2D = GradientTexture2D.new()
	tex.gradient = grad
	tex.width = 256
	tex.height = 256
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	return tex


func _polygon_bounds(poly: PackedVector2Array) -> Rect2:
	if poly.is_empty():
		return Rect2()
	var out: Rect2 = Rect2(poly[0], Vector2.ZERO)
	for p: Vector2 in poly:
		out = out.expand(p)
	return out


func _load_class_colours() -> void:
	var raw: Dictionary = DataLoader.load_json(DataLoader.CLASSES_PATH)
	for entry: Variant in raw.get("classes", []):
		var c: Dictionary = entry as Dictionary
		_class_colours[str(c.get("id", ""))] = Color(str(c.get("colour", "#b0b0b0")))


func _process(delta: float) -> void:
	if scene == null or layout == null:
		return
	if _world == null:
		_build()

	_clock += delta
	_fit()
	_sync_crew()
	_pulse_lights()

	_overlay.clock = _clock
	_overlay.hover_room = _hover_room
	_overlay.hover_crew = _hover_crew
	_overlay.queue_redraw()


# --- layout ----------------------------------------------------------------

# The whole ship scales to fit the panel. Everything downstream works in plate
# pixels, so no other code has to know the window size.
#
# Width first, not the smaller of the two. The plate is 2.16:1 and the panel is
# nearer 1.8:1, so fitting both axes letterboxed the ship into the middle third
# of its own frame. Filling the width and letting the plate's own empty margin
# crop off the top and bottom uses the space the ship is actually in. Overflow
# is capped so a very short panel cannot swallow the hull.
func _fit() -> void:
	if size.x < 1.0 or size.y < 1.0:
		return
	var plate: Vector2 = layout.plate_size
	var by_width: float = size.x / plate.x
	var by_height: float = size.y / plate.y
	_fit_scale = minf(by_width, by_height * OVERFLOW)
	_world.scale = Vector2(_fit_scale, _fit_scale)
	_world.position = ((size - plate * _fit_scale) * 0.5).floor()


func to_plate(local: Vector2) -> Vector2:
	if _fit_scale <= 0.0:
		return Vector2.ZERO
	return (local - _world.position) / _fit_scale


# --- crew ------------------------------------------------------------------

func all_crew() -> Array[CrewMember]:
	var out: Array[CrewMember] = []
	for m: CrewMember in scene.crew:
		out.append(m)
	if scene.tock != null and not out.has(scene.tock):
		out.append(scene.tock)
	return out


func _tock_in_transit() -> bool:
	return scene.task == RescueScene.Task.TRANSIT and scene.task_target != ""


# The single source of truth for where a crew member stands. Drawing, the
# sprites and hit-testing all read this, so a click can never land beside the
# figure it looks like it is on.
func crew_position(member: CrewMember) -> Vector2:
	if member == scene.tock and _tock_in_transit():
		return _walk_position()

	var room: ShipRoom = layout.get_room(member.room)
	if room == null:
		return Vector2.ZERO

	var here: Array[CrewMember] = _occupants(member.room)
	var index: int = maxi(here.find(member), 0)
	return _slot(room, index, here.size())


func _occupants(room_id: String) -> Array[CrewMember]:
	var out: Array[CrewMember] = []
	for m: CrewMember in all_crew():
		if m.room == room_id and not (m == scene.tock and _tock_in_transit()):
			out.append(m)
	return out


# Crew stand around the compartment centroid rather than on a fixed grid, so
# five of them in a tapered hold spread out instead of stacking up.
func _slot(room: ShipRoom, index: int, total: int) -> Vector2:
	var centre: Vector2 = room.centre()
	if total <= 1:
		return centre

	var bounds: Rect2 = _polygon_bounds(room.polygon)
	var per_row: int = 3
	var rows: int = maxi(int(ceil(float(total) / float(per_row))), 1)
	var col: int = index % per_row
	var row: int = index / per_row
	var in_row: int = mini(per_row, total - row * per_row)

	var step_x: float = minf(SLOT_SPREAD, bounds.size.x / float(per_row + 1))
	# Rows need more room than columns: the name plate hangs below each figure
	# and at column spacing the plates landed on the heads of the row beneath.
	var step_y: float = minf(SLOT_ROW, bounds.size.y / float(rows + 1))
	return centre + Vector2(
		(float(col) - (float(in_row) - 1.0) * 0.5) * step_x,
		(float(row) - (float(rows) - 1.0) * 0.5) * step_y
	)


# TOCK walks from where he is, through the doorway, to the next compartment —
# not in a straight line between two room centres. The simulation already
# models the hop as a duration; this reads the progress it publishes and spends
# it along the real two-leg path.
func _walk_position() -> Vector2:
	var from_room: ShipRoom = layout.get_room(scene.tock.room)
	var to_room: ShipRoom = layout.get_room(scene.task_target)
	if from_room == null or to_room == null:
		return Vector2.ZERO

	var a: Vector2 = from_room.centre()
	var door: Vector2 = layout.door_between(scene.tock.room, scene.task_target)
	var b: Vector2 = to_room.centre()

	var leg_a: float = a.distance_to(door)
	var leg_b: float = door.distance_to(b)
	var total: float = maxf(leg_a + leg_b, 0.001)
	var travelled: float = total * scene.task_progress()

	if travelled <= leg_a:
		return a.lerp(door, travelled / maxf(leg_a, 0.001))
	return door.lerp(b, (travelled - leg_a) / maxf(leg_b, 0.001))


# The ordered route as a polyline through every doorway still to be passed.
func route_points() -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array([crew_position(scene.tock)])
	var previous: String = scene.tock.room
	for room_id: String in scene.route:
		var door: Vector2 = layout.door_between(previous, room_id)
		if door != Vector2.ZERO:
			out.append(door)
		var room: ShipRoom = layout.get_room(room_id)
		if room != null:
			out.append(room.centre())
		previous = room_id
	return out


func _sync_crew() -> void:
	for member: CrewMember in all_crew():
		if not _crew_sprites.has(member.id):
			_crew_sprites[member.id] = _make_crew_sprite(member)
		var sprite: Sprite2D = _crew_sprites[member.id] as Sprite2D
		var at: Vector2 = crew_position(member)

		# A walk cycle stands in for animation frames until real crew art
		# exists: a short bob and a lean in the direction of travel. It is
		# driven by the same progress the simulation publishes, so it stops
		# dead when the game is paused.
		var walking: bool = member == scene.tock and _tock_in_transit()
		if walking:
			sprite.position = at + Vector2(0.0, -2.0 * absf(sin(_clock * 11.0)))
			sprite.rotation = sin(_clock * 11.0) * 0.09
		else:
			sprite.position = at
			sprite.rotation = 0.0

		# The suit colour is baked into the texture, so modulate is only used to
		# knock a restrained crew member down — never to carry identity.
		sprite.modulate = Color(0.62, 0.55, 0.55) if member.is_tied() else Color.WHITE


# Placeholder crew art, generated once into a texture rather than drawn every
# frame — so the compartment lights fall on the figures the same way they fall
# on the hull. Swapping in a real sprite sheet is a change to this function and
# nothing else.
func _make_crew_sprite(member: CrewMember) -> Sprite2D:
	var sprite: Sprite2D = Sprite2D.new()
	var colour: Color = _class_colours.get(member.class_id, Color(0.72, 0.75, 0.80))
	sprite.texture = _crew_texture(member.is_synthetic, colour)
	_crew_layer.add_child(sprite)
	return sprite


func _crew_texture(synthetic: bool, suit: Color) -> Texture2D:
	var s: int = CREW_TEX
	var img: Image = Image.create(s, s, false, Image.FORMAT_RGBA8)
	var mid: Vector2 = Vector2(float(s), float(s)) * 0.5
	var unit: float = float(s) * 0.5

	# A figure seen from directly above is shoulders with a head on top, not a
	# disc. The first attempt was a disc with a stripe through it and read as a
	# lozenge; this reads as a person at the size compartments actually give us.
	for y: int in range(s):
		for x: int in range(s):
			var p: Vector2 = (Vector2(float(x) + 0.5, float(y) + 0.5) - mid) / unit

			# Shoulders: an ellipse wider than it is deep.
			var shoulder: float = (p.x / 0.96) * (p.x / 0.96) + (p.y / 0.74) * (p.y / 0.74)
			if shoulder > 1.0:
				continue

			var head: float = p.length() / 0.44
			var colour: Color
			if head <= 1.0:
				# Helmet dome, lit from the top-left to match the room lights.
				var lit: float = clampf(0.30 - (p.x * 0.15 + p.y * 0.18), 0.07, 0.36)
				colour = Color(lit, lit, lit, 1.0)
				# Specular pip, which is what sells a curved surface at 30 px.
				if (p - Vector2(-0.15, -0.18)).length() < 0.11:
					colour = Color(0.50, 0.52, 0.56, 1.0)
			else:
				# Suit: darker, and darker still toward the outside edge so the
				# silhouette holds against a bright compartment floor.
				# The class colour lives here and nowhere else. Modulating the
				# whole sprite tinted the helmet too and turned every crew member
				# back into the coloured disc this was meant to replace.
				var falloff: float = clampf(1.05 - shoulder * 0.62, 0.30, 1.0)
				colour = Color(
					suit.r * 0.30 * falloff, suit.g * 0.30 * falloff, suit.b * 0.30 * falloff, 1.0
				)

			# Soft edge rather than a hard jagged one; these are scaled down a
			# long way and aliasing on a 96 px source is very visible.
			var edge: float = clampf((1.0 - shoulder) * 7.0, 0.0, 1.0)
			colour.a = edge
			img.set_pixel(x, y, colour)

	# TOCK is a machine and must never be mistaken for crew: a hard rectangular
	# sensor bar instead of a visor slit.
	var bar_y0: int = int(float(s) * (0.40 if synthetic else 0.44))
	var bar_y1: int = int(float(s) * (0.50 if synthetic else 0.48))
	var bar_x0: int = int(float(s) * (0.33 if synthetic else 0.37))
	var bar_x1: int = int(float(s) * (0.67 if synthetic else 0.63))
	for y: int in range(bar_y0, bar_y1):
		for x: int in range(bar_x0, bar_x1):
			img.set_pixel(x, y, Color(0.06, 0.07, 0.09, 1.0))

	return ImageTexture.create_from_image(img)


# The reactor breathes and the compartment lights flicker very slightly. Both
# are cosmetic and run off a clock that never reaches the simulation, so they
# keep moving while paused without advancing anything that matters.
func _pulse_lights() -> void:
	for room_id: Variant in _lights.keys():
		var light: PointLight2D = _lights[room_id] as PointLight2D
		if str(room_id) == "reactor":
			light.energy = LIGHT_ENERGY * (1.25 + 0.18 * sin(_clock * 1.9))
		else:
			light.energy = LIGHT_ENERGY * (1.0 + 0.02 * sin(_clock * 2.7 + float(light.position.x)))


# --- input -----------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	# Hover feedback. Without it nothing on the ship reacts until it is clicked,
	# and a player cannot tell what is clickable from what is painted on.
	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	if motion != null:
		_update_hover(to_plate(motion.position))
		return

	var click: InputEventMouseButton = event as InputEventMouseButton
	if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	if scene == null or layout == null or _world == null:
		return

	var at: Vector2 = to_plate(click.position)

	# Crew are smaller and stand inside rooms, so they are tested first, at the
	# exact positions the sprites were placed.
	for member: CrewMember in all_crew():
		if at.distance_to(crew_position(member)) <= CREW_HIT_RADIUS:
			crew_clicked.emit(member.id)
			accept_event()
			return

	for room: ShipRoom in layout.rooms:
		if room.contains(at):
			room_clicked.emit(room.id)
			accept_event()
			return


func _update_hover(at: Vector2) -> void:
	if scene == null or layout == null:
		return
	_hover_crew = ""
	_hover_room = ""
	for member: CrewMember in all_crew():
		if at.distance_to(crew_position(member)) <= CREW_HIT_RADIUS:
			_hover_crew = member.id
			return
	for room: ShipRoom in layout.rooms:
		if room.contains(at):
			_hover_room = room.id
			return


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		_hover_room = ""
		_hover_crew = ""
