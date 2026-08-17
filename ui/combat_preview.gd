extends Control

# A launchable composition test for the first ship-to-ship combat screen.
#
# This intentionally contains no combat rules. It answers one visual question:
# can two full plates, drawn at equal scale, leave the crew and compartments
# readable with only the smallest possible amount of UI chrome?
#
# The rescue mission remains in res://rescue_scene.tscn. It is kept separate so
# its simulation and behavioural checks remain useful while this becomes the
# game's default visual test.

const BG: Color = Color(0.045, 0.052, 0.067)
const TEXT: Color = Color(0.84, 0.87, 0.92)
const DIM: Color = Color(0.48, 0.54, 0.64)
const PLAYER: Color = Color(0.54, 0.76, 0.92)
const ENEMY: Color = Color(0.92, 0.55, 0.50)
const PANEL: Color = Color(0.075, 0.086, 0.108, 0.94)
const EDGE: Color = Color(0.26, 0.30, 0.37, 0.82)
const HULL: Color = Color(0.50, 0.84, 0.46)
const SHIELD: Color = Color(0.38, 0.67, 0.98)
const POWER: Color = Color(0.90, 0.72, 0.28)
const HEALTH: Color = Color(0.52, 0.84, 0.64)
const GUTTER: int = 14
const MARGIN: int = 8
const SHIP_SCALE: float = 1.20

# **The ship has no name yet, and this is not it.**
#
# This panel briefly read "ISS VENGEANCE", which was invented here rather than
# taken from anywhere — nothing in `SETTING.md`, `data/` or `world/` names the
# player's ship at all. It is also wrong twice over for the setting: "ISS" is
# generic sci-fi in a Sol-in-2100 story with no aliens and no FTL, and
# "Vengeance" is a warship's name on a working crew's boat.
#
# So it is a placeholder that looks like a placeholder. Naming the ship is
# content and belongs to the owner — `world/` is their folder. Replace this
# string the moment there is a real name, and not before.
const PLAYER_SHIP_NAME: String = "OUR SHIP"
const ENEMY_SHIP_NAME: String = "PIRATE CUTTER"

var _player_scene: RescueScene = null
var _player_ship: ShipView = null
var _enemy_ship: EnemyPreviewView = null
var _status: Label = null
var _pause_button: Button = null
var _pause_caption: Label = null
var _tock_health: SegmentedMeter = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	_build_ships()


func _process(delta: float) -> void:
	if _player_ship == null or _enemy_ship == null:
		return
	# The preview borrows the already-tested rescue movement simulation. Only
	# the player-side copy advances; the enemy is a static visual plate until an
	# actual combat simulation exists.
	_player_scene.tick(delta)
	_update_hud()


func _build_ui() -> void:
	var bg: ColorRect = ColorRect.new()
	bg.color = BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", MARGIN)
	margin.add_theme_constant_override("margin_right", MARGIN)
	margin.add_theme_constant_override("margin_top", MARGIN)
	margin.add_theme_constant_override("margin_bottom", MARGIN)
	add_child(margin)

	var root: VBoxContainer = VBoxContainer.new()
	root.add_theme_constant_override("separation", 4)
	margin.add_child(root)

	root.add_child(_build_top_hud())

	var ships: HBoxContainer = HBoxContainer.new()
	ships.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ships.add_theme_constant_override("separation", GUTTER)
	root.add_child(ships)
	# Ours on the left, theirs on the right. Both bows point inward, so the two
	# ships face each other across the gutter.
	ships.add_child(_ship_column(PLAYER_SHIP_NAME, PLAYER, true))
	ships.add_child(_enemy_column())

	root.add_child(_build_bottom_hud())


func _build_top_hud() -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	row.custom_minimum_size = Vector2(0.0, 82.0)
	row.add_theme_constant_override("separation", 8)

	# Ours on the left, matching the ship beneath it. A status panel that sits
	# over the other side's hull is a misread waiting to happen in a fight.
	var player: PanelContainer = _ship_status(PLAYER_SHIP_NAME, "CREW 6", PLAYER, 30, 30, 10, 10, 18, 20)
	player.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(player)

	var centre: PanelContainer = _panel()
	centre.custom_minimum_size = Vector2(132.0, 0.0)
	var centre_box: VBoxContainer = VBoxContainer.new()
	centre_box.alignment = BoxContainer.ALIGNMENT_CENTER
	centre.add_child(centre_box)
	_pause_caption = _label("COMBAT PAUSED", DIM, 10)
	_pause_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	centre_box.add_child(_pause_caption)
	_pause_button = Button.new()
	_pause_button.custom_minimum_size = Vector2(108.0, 30.0)
	_pause_button.add_theme_stylebox_override("normal", _button_style(PANEL, EDGE))
	_pause_button.add_theme_stylebox_override("hover", _button_style(Color(0.13, 0.16, 0.20), PLAYER))
	_pause_button.pressed.connect(_toggle_pause)
	centre_box.add_child(_pause_button)
	row.add_child(centre)

	var enemy: PanelContainer = _ship_status(ENEMY_SHIP_NAME, "HOSTILE", ENEMY, 15, 15, 0, 2, 1, 1)
	enemy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(enemy)
	return row


func _ship_status(
	title: String, subtitle: String, title_colour: Color,
	hull: int, hull_max: int, shields: int, shields_max: int, power: int, power_max: int
) -> PanelContainer:
	var panel: PanelContainer = _panel()
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 1)
	panel.add_child(box)

	var heading: HBoxContainer = HBoxContainer.new()
	var name: Label = _label(title, title_colour, 12)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(name)
	var note: Label = _label(subtitle, DIM, 10)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	heading.add_child(note)
	box.add_child(heading)
	box.add_child(_meter("HULL", hull, hull_max, HULL))
	box.add_child(_meter("SHIELDS", shields, shields_max, SHIELD))
	box.add_child(_meter("POWER", power, power_max, POWER))
	return panel


func _build_bottom_hud() -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	row.custom_minimum_size = Vector2(0.0, 74.0)
	row.add_theme_constant_override("separation", 8)

	var crew: PanelContainer = _panel()
	crew.custom_minimum_size = Vector2(245.0, 0.0)
	var crew_box: VBoxContainer = VBoxContainer.new()
	crew_box.add_theme_constant_override("separation", 1)
	crew.add_child(crew_box)
	crew_box.add_child(_label("SELECTED CREW", DIM, 10))
	crew_box.add_child(_label("TOCK  ·  SYNTHETIC", TEXT, 13))
	_tock_health = _meter("HEALTH", 100, 100, HEALTH)
	crew_box.add_child(_tock_health)
	row.add_child(crew)

	var order: PanelContainer = _panel()
	order.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var order_box: VBoxContainer = VBoxContainer.new()
	order_box.add_theme_constant_override("separation", 2)
	order.add_child(order_box)
	order_box.add_child(_label("CURRENT ORDER", DIM, 10))
	_status = _label("TOCK awaiting orders  ·  click a PLAYER room to move", TEXT, 13)
	order_box.add_child(_status)
	row.add_child(order)

	var systems: PanelContainer = _panel()
	systems.custom_minimum_size = Vector2(350.0, 0.0)
	var systems_box: VBoxContainer = VBoxContainer.new()
	systems_box.add_theme_constant_override("separation", 4)
	systems.add_child(systems_box)
	systems_box.add_child(_label("SYSTEMS  ·  COMBAT CONTROLS", DIM, 10))
	var tiles: HBoxContainer = HBoxContainer.new()
	tiles.add_theme_constant_override("separation", 4)
	for system: Dictionary in [
		{"name": "ENG", "colour": PLAYER}, {"name": "WPN", "colour": POWER},
		{"name": "SHD", "colour": SHIELD}, {"name": "TGT", "colour": ENEMY},
	]:
		tiles.add_child(_system_tile(str(system["name"]), system["colour"] as Color))
	systems_box.add_child(tiles)
	row.add_child(systems)
	return row


func _meter(caption: String, amount: int, maximum: int, colour: Color) -> SegmentedMeter:
	var meter: SegmentedMeter = SegmentedMeter.new()
	meter.caption = caption
	meter.amount = amount
	meter.maximum = maximum
	meter.colour = colour
	return meter


func _system_tile(caption: String, colour: Color) -> Control:
	var tile: PanelContainer = PanelContainer.new()
	tile.custom_minimum_size = Vector2(72.0, 28.0)
	var edge_colour: Color = colour
	edge_colour.a = 0.72
	var style: StyleBoxFlat = _button_style(Color(0.04, 0.05, 0.065), edge_colour)
	tile.add_theme_stylebox_override("panel", style)
	var label: Label = _label(caption, colour, 11)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tile.add_child(label)
	return tile


func _ship_column(title: String, colour: Color, is_player: bool) -> Control:
	var column: VBoxContainer = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 2)

	var label: Label = _label(title, colour, 12)
	label.custom_minimum_size = Vector2(0.0, 16.0)
	column.add_child(label)

	var ship: ShipView = ShipView.new()
	ship.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ship.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# Our plate is authored bow-right, and we sit on the left, so it already
	# faces the enemy and must not be mirrored. The enemy is the one that flips —
	# see EnemyPreviewView.
	ship.mirrored = false
	ship.display_scale_multiplier = SHIP_SCALE
	if is_player:
		ship.room_clicked.connect(_on_player_room_clicked)
	column.add_child(ship)
	if is_player:
		_player_ship = ship
	return column


func _enemy_column() -> Control:
	var column: VBoxContainer = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 2)

	var label: Label = _label(ENEMY_SHIP_NAME, ENEMY, 12)
	label.custom_minimum_size = Vector2(0.0, 16.0)
	column.add_child(label)

	_enemy_ship = EnemyPreviewView.new()
	_enemy_ship.mirrored = true
	_enemy_ship.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_enemy_ship.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_enemy_ship)
	return column


func _build_ships() -> void:
	# The player owns the current movement simulation. The enemy plate is kept
	# separate, ready for its own state model when ship-to-ship combat arrives.
	_player_scene = RescueScene.new(0)
	# The rescue simulation starts with a plan choice. The preview has no choice
	# UI, so select the non-damaging route simply to enable TOCK's move command.
	_player_scene.choose_plan("hack")

	_player_ship.scene = _player_scene
	_player_ship.layout = _player_scene.layout


func _on_player_room_clicked(room_id: String) -> void:
	if _player_scene.order_move(room_id):
		var room: ShipRoom = _player_scene.layout.get_room(room_id)
		var label: String = room.label if room != null else room_id.to_upper()
		_status.text = "TOCK moving to %s. Click another PLAYER room to re-route." % label
	else:
		_status.text = "TOCK cannot move there right now. Choose another PLAYER room."


func _unhandled_key_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_SPACE:
		_toggle_pause()
		get_viewport().set_input_as_handled()


func _toggle_pause() -> void:
	if _player_scene != null:
		_player_scene.toggle_pause()


func _update_hud() -> void:
	if _player_scene == null or _pause_button == null or _pause_caption == null or _status == null:
		return
	var paused: bool = _player_scene.is_paused()
	_pause_button.text = "RESUME" if paused else "PAUSE"
	_pause_caption.text = "SIMULATION PAUSED" if paused else "COMBAT PREVIEW"
	if _tock_health != null and _player_scene.tock != null:
		_tock_health.set_amount(_player_scene.tock.hp, _player_scene.tock.max_hp)
	if _player_scene.tock != null and _player_scene.tock.is_moving():
		var going_to: String = _player_scene.tock.move_target
		var room: ShipRoom = _player_scene.layout.get_room(going_to)
		var target: String = room.label if room != null else going_to.to_upper()
		_status.text = "TOCK → %s  ·  %d%%  ·  click a room to re-route" % [
			target, int(_player_scene.tock.move_progress() * 100.0),
		]
	elif paused:
		_status.text = "TOCK awaiting orders  ·  PAUSED"
	else:
		_status.text = "TOCK awaiting orders  ·  click a PLAYER room to move"


func _label(text: String, colour: Color, font_size: int) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_color_override("font_color", colour)
	label.add_theme_font_size_override("font_size", font_size)
	return label


func _panel() -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = PANEL
	style.border_color = EDGE
	style.set_border_width_all(1)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", style)
	return panel


func _button_style(background: Color, border: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	return style
