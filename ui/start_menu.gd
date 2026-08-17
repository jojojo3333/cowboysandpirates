extends Control

# The scene the game boots into: pick what to look at.
#
# This exists so the project always opens on something that says what is here
# and what is broken, rather than dropping straight into one mission. That is
# the owner's call and it is the right one — the alternative is finding out a
# scene stopped loading only when you happen to open it.
#
# It is not a title screen and should not become one. When there is a real game
# to start, this becomes the developer's way in and something else greets a
# player.
#
# **Nothing else boots through here.** `tools/play.gd`, `tools/screenshot.gd`
# and `tools/walk_frames.gd` all load their scene by path, so the menu costs the
# automated checks nothing and cannot break them by existing.

const BG: Color = Color(0.045, 0.052, 0.067)
const PANEL: Color = Color(0.075, 0.086, 0.108, 0.94)
const EDGE: Color = Color(0.26, 0.30, 0.37, 0.82)
const TEXT: Color = Color(0.84, 0.87, 0.92)
const DIM: Color = Color(0.48, 0.54, 0.64)
const ACCENT: Color = Color(0.54, 0.76, 0.92)
const BROKEN: Color = Color(0.92, 0.55, 0.50)

# What can be launched. Adding a scene here is the whole job of registering it —
# the menu, and the check in tools/play.gd that every entry actually loads, both
# read this list.
const ENTRIES: Array[Dictionary] = [
	{
		"id": "combat",
		"title": "SHIP TO SHIP",
		"blurb": "Two ships facing each other. Composition and HUD test — no combat rules yet.",
		"scene": "res://main_combat.tscn",
	},
	{
		"id": "boarding",
		"title": "THE BOARDING",
		"blurb": "In-engine cutscene test. Four pirates come aboard and move on their own.",
		"scene": "res://main_boarding.tscn",
	},
	{
		"id": "tutorial",
		"title": "THE CARGO HOLD",
		"blurb": "The playable mission. Crew movement, orders, and getting to know the ship.",
		"scene": "res://rescue_scene.tscn",
	},
]

var _rows: VBoxContainer = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()


func _build() -> void:
	var bg: ColorRect = ColorRect.new()
	bg.color = BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 48)
	add_child(margin)

	var centre: CenterContainer = CenterContainer.new()
	margin.add_child(centre)

	var column: VBoxContainer = VBoxContainer.new()
	column.custom_minimum_size = Vector2(560.0, 0.0)
	column.add_theme_constant_override("separation", 10)
	centre.add_child(column)

	column.add_child(_text("DEADWEIGHT", TEXT, 26))
	column.add_child(_text("development build — pick a scene", DIM, 12))
	column.add_child(_spacer(14.0))

	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 8)
	column.add_child(_rows)

	for entry: Dictionary in ENTRIES:
		_rows.add_child(_entry_button(entry))

	column.add_child(_spacer(10.0))
	column.add_child(_text("ESC quits.  Every scene above is checked by tools/verify.sh play.", DIM, 11))


# One launchable scene. If its file cannot be loaded the row says so and is
# disabled, rather than offering a button that does nothing when pressed — the
# menu is meant to report what is broken, not to hide it.
func _entry_button(entry: Dictionary) -> Control:
	var path: String = str(entry["scene"])
	var ok: bool = ResourceLoader.exists(path)

	var button: Button = Button.new()
	button.custom_minimum_size = Vector2(0.0, 64.0)
	button.disabled = not ok
	button.add_theme_stylebox_override("normal", _style(PANEL, EDGE))
	button.add_theme_stylebox_override("hover", _style(Color(0.13, 0.16, 0.20), ACCENT))
	button.add_theme_stylebox_override("pressed", _style(Color(0.10, 0.13, 0.17), ACCENT))
	button.add_theme_stylebox_override("disabled", _style(Color(0.07, 0.06, 0.07), BROKEN))
	if ok:
		button.pressed.connect(_on_entry_pressed.bind(path))

	# The label sits inside the button as a child rather than as button.text, so
	# the title and the blurb can be different sizes and colours.
	var box: VBoxContainer = VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.add_theme_constant_override("margin_left", 14)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 2)
	button.add_child(box)

	box.add_child(_text(str(entry["title"]), ACCENT if ok else BROKEN, 16))
	box.add_child(_text(
		str(entry["blurb"]) if ok else "MISSING: %s" % path, DIM if ok else BROKEN, 11
	))
	return button


func _on_entry_pressed(path: String) -> void:
	var err: int = get_tree().change_scene_to_file(path)
	if err != OK:
		push_error("could not change to %s (error %d)" % [path, err])


func _unhandled_key_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_ESCAPE:
		get_tree().quit()


func _text(content: String, colour: Color, size_px: int) -> Label:
	var label: Label = Label.new()
	label.text = content
	label.add_theme_color_override("font_color", colour)
	label.add_theme_font_size_override("font_size", size_px)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


# Containers size themselves to their children, so vertical breathing room has
# to be an actual node with a height. A bare Control defaults to zero.
func _spacer(height: float) -> Control:
	var gap: Control = Control.new()
	gap.custom_minimum_size = Vector2(0.0, height)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return gap


func _style(fill: Color, border: Color) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(2)
	box.content_margin_left = 14.0
	box.content_margin_right = 14.0
	return box
