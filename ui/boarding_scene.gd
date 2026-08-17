extends Control

# The boarding, played as an in-engine cutscene.
#
# **This is a proving ground, not the finished thing.** What it demonstrates is
# that the game can move its own people around its own ship on a script, with no
# player input and no separate renderer — which is the foundation everything in
# act 1's cold open rests on. See `MISSION_01.md`.
#
# What is deliberately missing: the pirates walk into the crew quarters and stop.
# They do not strike anybody and they do not drag anyone to the hold, because
# neither pose is authored yet and faking it with the clips we have would look
# like a bug rather than a placeholder. That is the next chunk.

const BG: Color = Color(0.045, 0.052, 0.067)
const PANEL: Color = Color(0.075, 0.086, 0.108, 0.94)
const TEXT: Color = Color(0.84, 0.87, 0.92)
const DIM: Color = Color(0.48, 0.54, 0.64)
const ENEMY: Color = Color(0.92, 0.55, 0.50)

var scene: RescueScene = null
var cutscene: Cutscene = null

var _ship: ShipView = null
var _caption: Label = null
var _status: Label = null
var _replay: Button = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	_start()


func _start() -> void:
	scene = RescueScene.new(0)
	# The cutscene runs before the player has chosen anything, and order_move
	# only accepts orders once the scene is executing. Choosing here is staging,
	# not a decision — the cold open has not happened yet in the story.
	scene.choose_plan("hack")

	_ship.scene = scene
	_ship.layout = scene.layout

	var config: Dictionary = DataLoader.load_json("res://data/mission_01.json")
	var cutscenes: Dictionary = config.get("cutscenes", {}) as Dictionary
	cutscene = Cutscene.from_config(scene, cutscenes.get("boarding", {}) as Dictionary)
	cutscene.finished.connect(_on_finished)
	cutscene.start()

	_caption.text = "Four boarders come through the airlock."
	_replay.visible = false


func _process(delta: float) -> void:
	if scene == null:
		return
	cutscene.tick(delta)
	scene.tick(delta)

	var walking: int = 0
	for m: CrewMember in scene.hostiles():
		if m.is_moving():
			walking += 1
	_status.text = "cutscene %d%%   ·   %d of %d boarders moving" % [
		int(cutscene.progress() * 100.0), walking, scene.hostiles().size()
	]


func _on_finished() -> void:
	_caption.text = "They reach the crew quarters. (Striking and dragging are the next chunk — see MISSION_01.md.)"
	_replay.visible = true


func _build_ui() -> void:
	var bg: ColorRect = ColorRect.new()
	bg.color = BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	add_child(margin)

	var root: VBoxContainer = VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	margin.add_child(root)

	var heading: Label = _label("THE BOARDING", ENEMY, 18)
	root.add_child(heading)

	var frame: PanelContainer = PanelContainer.new()
	frame.add_theme_stylebox_override("panel", _panel_style())
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(frame)

	_ship = ShipView.new()
	_ship.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ship.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_ship.custom_minimum_size = Vector2(640.0, 300.0)
	frame.add_child(_ship)

	_caption = _label("", TEXT, 14)
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_caption.custom_minimum_size = Vector2(0.0, 40.0)
	root.add_child(_caption)

	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	root.add_child(row)

	_status = _label("", DIM, 12)
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_status)

	_replay = Button.new()
	_replay.text = "Replay"
	_replay.custom_minimum_size = Vector2(110.0, 30.0)
	_replay.pressed.connect(_start)
	row.add_child(_replay)

	var back: Button = Button.new()
	back.text = "Back to menu"
	back.custom_minimum_size = Vector2(130.0, 30.0)
	back.pressed.connect(_on_back)
	row.add_child(back)


func _on_back() -> void:
	get_tree().change_scene_to_file("res://main.tscn")


func _label(content: String, colour: Color, size_px: int) -> Label:
	var made: Label = Label.new()
	made.text = content
	made.add_theme_color_override("font_color", colour)
	made.add_theme_font_size_override("font_size", size_px)
	return made


func _panel_style() -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = PANEL
	box.border_color = Color(0.26, 0.30, 0.37, 0.82)
	box.set_border_width_all(1)
	return box
