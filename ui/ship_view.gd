extends Control
class_name ShipView

# The ship view. The ship is a painted plate; this builds a small Node2D world
# on top of it and lights it with the engine.
#
# The ship is art: hull, compartment floors, bulkheads and doors come from
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
# The node tree is built in code because it is generated from the room data,
# not because scenes are off-limits. If a hand-authored scene is ever the
# clearer way to express part of this, use one.

signal room_clicked(room_id: String)
signal crew_clicked(crew_id: String)

# A drag finished. Carries every crew member inside the box, which may be empty
# — an empty box on bare deck is how a player clears their selection.
signal crew_box_selected(crew_ids: Array)

# How far the mouse must travel before a press counts as a drag rather than a
# click. Without this, every click is a 1x1 selection box and nothing is ever
# clickable: hands shake, and a mouse reports motion between press and release
# almost every time.
const DRAG_THRESHOLD: float = 6.0

# How dark the plate sits before any light touches it. Lights add on top, so
# this is the "lights out" look of the ship.
const AMBIENT: Color = Color(0.82, 0.85, 0.92)

const LIGHT_ENERGY: float = 0.85
const LIGHT_WARM: Color = Color(1.0, 0.94, 0.84)
const LIGHT_REACTOR: Color = Color(1.0, 0.68, 0.34)
const CREW_HIT_RADIUS: float = 26.0
const CREW_TEX: int = 96
const SLOT_SPREAD: float = 74.0

# How far the ship may exceed the panel height before it is scaled back. The
# plate carries empty space above and below the hull, so a little overflow costs
# nothing visible and buys a much larger ship.
const SLOT_ROW: float = 86.0
const OVERFLOW: float = 1.30

# Which render a standing crew member uses, and how the eight renders line up
# with screen angles. Both are tuned by looking at the result, which is the only
# way to get them right.
const FACING_IDLE: int = 0
const FACING_OFFSET: int = 2

# The renders sit slightly low in their 128 px cell — the figures span y 22..113,
# so their centre is 3.5 px below the cell's. Without this the crew stand below
# the point the simulation says they occupy, and markers drawn at that point land
# on their heads.
#
# Do not hand-tune this. `tools/render_soldier.gd --mode bake` measures it off
# the sheets it just wrote and prints the value to use; it moves whenever the
# render camera does, and it moved from -9.0 when the camera went overhead.
const CREW_ART_OFFSET: float = -3.5

# Crew are drawn at half the render size. The sheets are 128 px cells, and the
# compartments on this plate are 130-230 px across — a full-size figure filled
# an entire room. Rendering large and scaling down keeps the sprites sharp if a
# later plate has bigger rooms.
const CREW_SCALE: float = 0.52

# How far a class colour pulls the figure away from neutral, and how much it
# brightens it. Values above 1.0 in modulate brighten in Godot; without the lift
# a tinted dark sprite reads as a darker dark sprite.
const CLASS_TINT_STRENGTH: float = 0.72
const CLASS_TINT_LIFT: float = 1.30

# Boarders. Same suit, different side. Matched to ui/enemy_preview_view.gd so a
# pirate looks the same standing on our deck as on their own.
const HOSTILE_TINT_STRENGTH: float = 0.86
const HOSTILE_TINT_LIFT: float = 1.18

var scene: RescueScene = null
var layout: ShipLayout = null

# Expands each room-to-room hop into a walk through the corridors.
var _corridors: CorridorMap = null

var _world: Node2D = null
var _plate: Sprite2D = null
var _overlay: ShipOverlay = null
var _crew_layer: Node2D = null
var _lights: Dictionary = {}
var _crew_sprites: Dictionary = {}
var _crew_frames: Dictionary = {}
var _crew_last: Dictionary = {}
var _class_colours: Dictionary = {}
var _clock: float = 0.0
var _anim_clock: float = 0.0
var _fit_scale: float = 1.0
var _hover_room: String = ""
var _hover_crew: String = ""

# Who is selected, and the drag in progress. Selection is view state, not
# simulation state: the simulation does not care who the player has clicked on,
# and putting it in sim/ would be the first crack in the wall ARCHITECTURE.md
# spends its first section defending.
var selected: Array[String] = []
var _drag_from: Vector2 = Vector2.ZERO
var _drag_to: Vector2 = Vector2.ZERO
var _dragging: bool = false
var _pressed: bool = false

# Combat shows two ships from the same distance. The enemy plate is mirrored so
# the bows face each other, while every room, crew position and click still uses
# the authored plate coordinates.
var mirrored: bool = false

# A combat composition may deliberately show only the useful centre of a ship.
# Raising this above 1.0 enlarges the plate within its clipped viewport, cutting
# peripheral hull / engine detail rather than shrinking crew and room state.
var display_scale_multiplier: float = 1.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	_load_class_colours()


# main.gd assigns scene and layout after construction, so the world is built on
# the first frame that has both rather than in _ready.
func _build() -> void:
	_corridors = CorridorMap.new(layout)

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
	# Crew animation runs on its own clock that stops with the simulation.
	# _clock keeps going so the hover outline and the route dashes stay alive
	# while paused; a crew member marching on the spot in a paused game does not.
	if not scene.is_paused():
		_anim_clock += delta
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
	_fit_scale = minf(by_width, by_height * OVERFLOW) * display_scale_multiplier
	var horizontal_scale: float = -_fit_scale if mirrored else _fit_scale
	_world.scale = Vector2(horizontal_scale, _fit_scale)
	_world.position = ((size - plate * _fit_scale) * 0.5).floor()
	if mirrored:
		_world.position.x += plate.x * _fit_scale


# Screen to plate coordinates.
#
# **Guarded against `_world` not existing yet**, which is not a hypothetical: the
# node is created in one frame and `_build()` runs in the first `_process` that
# has both a scene and a layout. A mouse moving across the panel in between —
# which is most of them, because the pointer is usually already over the window
# when a scene loads — arrives at `_gui_input` and lands here. It crashed the
# combat screen on load.
#
# The old guard checked `_fit_scale`, which is 1.0 before any fitting has
# happened, so it passed and then dereferenced a null `_world` one line later.
func to_plate(local: Vector2) -> Vector2:
	if _world == null or _fit_scale <= 0.0:
		return Vector2.ZERO
	return (local - _world.position) / _fit_scale


# The inverse. Only `tools/play.gd` needs it, so that a test can say "drag a box
# over the whole ship" in plate coordinates and have real mouse events land in
# the right place whatever the zoom happens to be.
func to_screen(plate_point: Vector2) -> Vector2:
	if _world == null:
		return Vector2.ZERO
	return plate_point * _fit_scale + _world.position


# --- crew ------------------------------------------------------------------

# Everyone standing on this plate, ours and theirs. Boarders are drawn, hovered,
# hit-tested and animated by exactly the same code as the crew — the only thing
# that differs is the colour and who may give them orders.
func all_crew() -> Array[CrewMember]:
	var out: Array[CrewMember] = []
	for m: CrewMember in scene.crew:
		out.append(m)
	if scene.tock != null and not out.has(scene.tock):
		out.append(scene.tock)
	for b: CrewMember in scene.boarders:
		out.append(b)
	return out


# Anybody walking, not just TOCK. This used to be `_tock_in_transit()` and it
# had to be, because the simulation could only ever have one person in motion.
func _in_transit(member: CrewMember) -> bool:
	return member.is_moving()


# The single source of truth for where a crew member stands. Drawing, the
# sprites and hit-testing all read this, so a click can never land beside the
# figure it looks like it is on.
func crew_position(member: CrewMember) -> Vector2:
	if _in_transit(member):
		return _walk_position(member)

	var room: ShipRoom = layout.get_room(member.room)
	if room == null:
		return Vector2.ZERO

	var here: Array[CrewMember] = _occupants(member.room)
	var index: int = maxi(here.find(member), 0)
	return _slot(room, index, here.size())


func _occupants(room_id: String) -> Array[CrewMember]:
	var out: Array[CrewMember] = []
	for m: CrewMember in all_crew():
		if m.room == room_id and not _in_transit(m):
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


# TOCK walks from where he is, along the corridors, to the next compartment —
# not in a straight line between two room centres, and not diagonally through a
# bulkhead. The simulation already models the hop as a duration; this reads the
# progress it publishes and spends it along the real corridor polyline.
func _walk_position(member: CrewMember) -> Vector2:
	var walk: PackedVector2Array = _corridors.hop(member.room, member.move_target)
	if walk.is_empty():
		return Vector2.ZERO
	return CorridorMap.point_along(walk, member.move_progress())


# The whole ordered route as one polyline through the corridors, so the dashed
# route line the overlay draws follows the same path the crew member walks.
func route_points_for(member: CrewMember) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array([crew_position(member)])
	var previous: String = member.room
	for room_id: String in member.route:
		var walk: PackedVector2Array = _corridors.hop(previous, room_id)
		# The first point of each hop is the room centre the crew member is
		# leaving, which the previous hop already ended on — and on the first
		# hop it is behind them, because they have already started walking.
		for i: int in range(1, walk.size()):
			out.append(walk[i])
		previous = room_id
	return out


func _sync_crew() -> void:
	for member: CrewMember in all_crew():
		if not _crew_sprites.has(member.id):
			_crew_sprites[member.id] = _make_crew_sprite(member)
		var sprite: Sprite2D = _crew_sprites[member.id] as Sprite2D
		var at: Vector2 = crew_position(member)
		var previous: Vector2 = _crew_last.get(member.id, at) as Vector2
		_crew_last[member.id] = at
		sprite.position = at

		var walking: bool = _in_transit(member)
		var clip: String = "walk" if walking else "idle"
		var facing: int = _facing_for(at - previous) if walking else FACING_IDLE

		# Restrained crew hold a single frame. An idle breathing loop on someone
		# who is tied up reads as nobody being in any trouble.
		var frames: int = int(CLIP_FRAMES.get(clip, 1))
		var step: int = 0
		if not member.is_tied():
			step = int(_anim_clock * CLIP_FPS.get(clip, 6.0)) % frames

		_apply_frame(sprite, member, clip, facing, step)

		# Everyone wears the same armour, so colour is the only thing telling one
		# crew member from another. The sheet is near-neutral (measured: 0.07
		# saturation) which is what makes a tint land as hue rather than mud —
		# but it is also dark, mean brightness 49, and a plain multiply on a dark
		# sprite only makes it darker. So the tint lifts as well as colours.
		var tint: Color = _class_colours.get(member.class_id, Color(0.80, 0.82, 0.86))
		# Hostiles are pulled harder towards their colour and lifted less. The
		# lift is what makes the suit read as lit steel; crushing it is what
		# makes a boarder read as matte and not-ours at a glance, which is the
		# same treatment the enemy ship's crew already get.
		if member.is_hostile:
			tint = Color(1.0, 1.0, 1.0).lerp(tint, HOSTILE_TINT_STRENGTH) * HOSTILE_TINT_LIFT
		else:
			tint = Color(1.0, 1.0, 1.0).lerp(tint, CLASS_TINT_STRENGTH) * CLASS_TINT_LIFT
		if member.is_tied():
			tint = tint.darkened(0.34)
		sprite.modulate = tint


# Crew sprites are baked by tools/render_soldier.gd from the Silver Soldier
# model. One sheet per clip: columns are frames, rows are the eight facings.
#
# Everyone uses the same figure, including TOCK. That is deliberate for now —
# the owner's call is that a robot who glides is worse than an android who
# walks, and this is the only model in the project with a usable walk. TOCK gets
# his own chassis once there is one that can move.
#
# The walk is authored on the model's own skeleton rather than taken from its
# animation clip, which is a weapon-handling loop and not locomotion. See
# tools/render_soldier.gd for the measurements behind that.
const CREW_MODEL: String = "soldier"

# Rows in every sheet. Read by _apply_frame and _facing_for.
const FACINGS: int = 8

const CLIP_FRAMES: Dictionary = {"walk": 8, "idle": 4, "die": 6}
const CLIP_FPS: Dictionary = {"walk": 11.0, "idle": 3.0, "die": 8.0}


func _make_crew_sprite(member: CrewMember) -> Sprite2D:
	var sprite: Sprite2D = Sprite2D.new()
	# Named after the crew member so the running scene tree can be read back by
	# something that is not a person looking at it — tools/game_probe.gd matches
	# on this prefix to check that the figure is drawn where the simulation says
	# the crew member is. Anonymous @Sprite2D@14 tells nobody anything.
	sprite.name = "crew_%s" % member.id
	sprite.offset = Vector2(0.0, CREW_ART_OFFSET)
	sprite.scale = Vector2(CREW_SCALE, CREW_SCALE)
	_crew_layer.add_child(sprite)
	return sprite


func _crew_model(_member: CrewMember) -> String:
	return CREW_MODEL


# Points the sprite at one cell of one sheet. hframes/vframes are set every
# time because a crew member switching from idle to walk switches sheets, and
# the two have different frame counts.
func _apply_frame(
	sprite: Sprite2D, member: CrewMember, clip: String, facing: int, step: int
) -> void:
	var sheet: Texture2D = _crew_sheet(_crew_model(member), clip)
	if sheet == null:
		return
	var frames: int = int(CLIP_FRAMES.get(clip, 1))
	sprite.texture = sheet
	sprite.hframes = frames
	sprite.vframes = FACINGS
	sprite.frame = posmod(facing, FACINGS) * frames + posmod(step, frames)


func _crew_sheet(model: String, clip: String) -> Texture2D:
	var key: String = "%s_%s" % [model, clip]
	if _crew_frames.has(key):
		return _crew_frames[key] as Texture2D
	var path: String = "res://assets/crew/%s.png" % key
	var tex: Texture2D = load(path) as Texture2D
	if tex == null:
		push_error("crew sheet missing: %s — run tools/render_crew.gd" % path)
	_crew_frames[key] = tex
	return tex


# Which of the eight renders faces the way this crew member is going. Screen
# angles run clockwise from east; the renders run anticlockwise from the model's
# own forward, hence the negation and the offset.
func _facing_for(direction: Vector2) -> int:
	if direction.length_squared() < 0.01:
		return FACING_IDLE
	var angle: float = atan2(-direction.y, direction.x)
	var step: int = int(round(angle / (TAU / float(FACINGS))))
	return posmod(step + FACING_OFFSET, FACINGS)


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

# Left button does two jobs, told apart by whether the mouse moved:
#
#   press, move, release  → a selection box
#   press, release        → a click on whatever is under the cursor
#
# The two cannot be separated at press time, so the decision is deferred to
# release. That is also why the click actions live in the release branch rather
# than the press branch, where they used to be.
func _gui_input(event: InputEvent) -> void:
	# Nothing to point at until the world exists. This guard used to sit below
	# the motion branch, which meant hover was processed on a half-built view.
	if scene == null or layout == null or _world == null:
		return

	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	if motion != null:
		var here: Vector2 = to_plate(motion.position)
		if _pressed:
			_drag_to = here
			if not _dragging and _drag_from.distance_to(here) > DRAG_THRESHOLD:
				_dragging = true
		# Hover feedback. Without it nothing on the ship reacts until it is
		# clicked, and a player cannot tell what is clickable from what is
		# painted on.
		_update_hover(here)
		return

	var click: InputEventMouseButton = event as InputEventMouseButton
	if click == null or click.button_index != MOUSE_BUTTON_LEFT:
		return

	if click.pressed:
		_pressed = true
		_dragging = false
		_drag_from = to_plate(click.position)
		_drag_to = _drag_from
		accept_event()
		return

	# Released.
	_pressed = false
	var at: Vector2 = to_plate(click.position)
	if _dragging:
		_dragging = false
		crew_box_selected.emit(_crew_in_box(selection_box()))
		accept_event()
		return

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


# The drag rectangle in plate coordinates, normalised so dragging up-and-left
# works exactly like dragging down-and-right.
func selection_box() -> Rect2:
	return Rect2(_drag_from, _drag_to - _drag_from).abs()


func is_dragging() -> bool:
	return _dragging


# Everyone the player can actually command. A box drawn over tied captives — or
# over boarders — selects nobody, because ordering them anywhere would be
# refused and a selection that cannot be acted on is a lie told by the interface.
func _crew_in_box(box: Rect2) -> Array:
	var out: Array = []
	for member: CrewMember in all_crew():
		if member.is_hostile or not member.can_take_orders():
			continue
		if box.has_point(crew_position(member)):
			out.append(member.id)
	return out


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
