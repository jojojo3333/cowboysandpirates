extends Control
class_name DialogueView

# Draws whatever `Dialogue` says is being said.
#
# Two presentations, because two different things are happening:
#
#   **bubble** — somebody aboard is talking. The bubble sits over them and has a
#                tail pointing at them, so it is obvious who spoke.
#   **comms**  — a voice with no body in the room: TOCK over the intercom, the
#                captain answering from their bunk. A panel across the bottom.
#
# It sits **over** the ship rather than inside it. A bubble drawn inside the
# ship's world would scale with the plate — text shrinking as the ship zooms out
# — and would be clipped at the panel edge. Anchoring in screen space and asking
# the ship where a crew member currently is keeps the text a fixed, readable
# size wherever the camera goes.

const PANEL_BG: Color = Color(0.075, 0.086, 0.108, 0.96)
const PANEL_EDGE: Color = Color(0.30, 0.35, 0.43, 0.9)
const BUBBLE_BG: Color = Color(0.10, 0.12, 0.15, 0.96)
const BUBBLE_EDGE: Color = Color(0.55, 0.72, 0.85, 0.9)
const TEXT: Color = Color(0.88, 0.91, 0.95)
const SPEAKER: Color = Color(0.55, 0.80, 0.85)
const DIM: Color = Color(0.48, 0.54, 0.64)

const BUBBLE_WIDTH: float = 260.0
const BUBBLE_LIFT: float = 74.0
const TAIL: float = 11.0

var dialogue: Dialogue = null

# Where to point a bubble. Optional — without it every line falls back to the
# comms panel rather than pointing at nothing.
var ship: ShipView = null

var _bubble: PanelContainer = null
var _bubble_speaker: Label = null
var _bubble_text: Label = null
var _panel: PanelContainer = null
var _panel_speaker: Label = null
var _panel_text: Label = null
var _hint: Label = null
var _anchor: Vector2 = Vector2.ZERO
var _tail_visible: bool = false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Clicks pass through to the ship underneath unless a line is showing, so
	# dialogue never silently eats input it is not using.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()


# The sequence is started by the caller, not here — whoever owns it also ticks
# it, and splitting those two would leave the view able to start a conversation
# nothing then advances.
func play(sequence: Dialogue) -> void:
	dialogue = sequence
	_refresh()


# **Draws only. It does not advance the conversation.**
#
# The owning scene ticks the Dialogue, exactly as it ticks the Cutscene, so a
# whole sequence can be stepped by hand with no window open. When the view held
# the clock, `verify.sh play` could not advance a line at all — the conversation
# only moved if somebody was watching it, which is the definition of untestable.
func _process(_delta: float) -> void:
	if dialogue == null:
		return
	_refresh()
	if _tail_visible:
		queue_redraw()


# The tail. Drawn rather than built from nodes because it is three points that
# have to move with the speaker every frame.
func _draw() -> void:
	if not _tail_visible or _bubble == null or not _bubble.visible:
		return
	var box: Rect2 = Rect2(_bubble.position, _bubble.size)
	var from: Vector2 = Vector2(clampf(_anchor.x, box.position.x + 14.0, box.end.x - 14.0), box.end.y)
	var points: PackedVector2Array = PackedVector2Array([
		from + Vector2(-TAIL, 0.0), from + Vector2(TAIL, 0.0), _anchor,
	])
	draw_colored_polygon(points, BUBBLE_BG)
	draw_line(points[0], points[2], BUBBLE_EDGE, 1.5)
	draw_line(points[1], points[2], BUBBLE_EDGE, 1.5)


func _refresh() -> void:
	var line: Dictionary = dialogue.current()
	if line.is_empty():
		_bubble.visible = false
		_panel.visible = false
		_hint.visible = false
		_tail_visible = false
		return

	_hint.visible = true
	var speaker: String = str(line.get("speaker", ""))
	var text: String = str(line.get("text", ""))
	var anchored: Vector2 = _anchor_for(line)
	var use_bubble: bool = str(line.get("style", "comms")) == "bubble" and anchored != Vector2.INF

	if use_bubble:
		_anchor = anchored
		_bubble_speaker.text = speaker
		_bubble_text.text = text
		_bubble.visible = true
		_panel.visible = false
		_tail_visible = true
		# Placed above the speaker, then pulled back inside the panel so a line
		# spoken by somebody near an edge is still readable.
		var half: float = _bubble.size.x * 0.5
		_bubble.position = Vector2(
			clampf(_anchor.x - half, 8.0, maxf(size.x - _bubble.size.x - 8.0, 8.0)),
			clampf(_anchor.y - BUBBLE_LIFT - _bubble.size.y, 8.0, maxf(size.y - 8.0, 8.0))
		)
	else:
		_panel_speaker.text = speaker
		_panel_text.text = text
		_panel.visible = true
		_bubble.visible = false
		_tail_visible = false


# Screen position of whoever is speaking, or INF when the speaker is not aboard.
func _anchor_for(line: Dictionary) -> Vector2:
	var actor: String = str(line.get("actor", ""))
	if actor == "" or ship == null or ship.scene == null:
		return Vector2.INF
	for member: CrewMember in ship.all_crew():
		if member.id == actor:
			return ship.global_position + ship.to_screen(ship.crew_position(member)) - global_position
	return Vector2.INF


func _unhandled_input(event: InputEvent) -> void:
	if dialogue == null or not dialogue.playing:
		return
	var key: InputEventKey = event as InputEventKey
	if key != null and key.pressed and not key.echo:
		if key.keycode == KEY_ESCAPE:
			dialogue.skip()
			_refresh()
			get_viewport().set_input_as_handled()
		elif key.keycode == KEY_SPACE or key.keycode == KEY_ENTER:
			dialogue.advance()
			_refresh()
			get_viewport().set_input_as_handled()
		return
	var click: InputEventMouseButton = event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		dialogue.advance()
		_refresh()
		get_viewport().set_input_as_handled()


func _build() -> void:
	_bubble = _make_box(BUBBLE_BG, BUBBLE_EDGE)
	_bubble.custom_minimum_size = Vector2(BUBBLE_WIDTH, 0.0)
	_bubble.size = Vector2(BUBBLE_WIDTH, 0.0)
	add_child(_bubble)
	var bubble_box: VBoxContainer = VBoxContainer.new()
	bubble_box.add_theme_constant_override("separation", 2)
	_bubble.add_child(bubble_box)
	_bubble_speaker = _make_label("", SPEAKER, 11)
	bubble_box.add_child(_bubble_speaker)
	_bubble_text = _make_label("", TEXT, 14)
	_bubble_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bubble_text.custom_minimum_size = Vector2(BUBBLE_WIDTH - 28.0, 0.0)
	bubble_box.add_child(_bubble_text)
	_bubble.visible = false

	# The comms panel is anchored to the bottom of the screen rather than placed
	# in a container, because this whole view floats over the game.
	_panel = _make_box(PANEL_BG, PANEL_EDGE)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_panel.offset_left = 90.0
	_panel.offset_right = -90.0
	_panel.offset_top = -104.0
	_panel.offset_bottom = -30.0
	add_child(_panel)
	var panel_box: VBoxContainer = VBoxContainer.new()
	panel_box.add_theme_constant_override("separation", 4)
	_panel.add_child(panel_box)
	_panel_speaker = _make_label("", SPEAKER, 12)
	panel_box.add_child(_panel_speaker)
	_panel_text = _make_label("", TEXT, 16)
	_panel_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel_box.add_child(_panel_text)
	_panel.visible = false

	_hint = _make_label("click or SPACE to continue   ·   ESC to skip", DIM, 11)
	_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_hint.offset_top = -24.0
	_hint.offset_bottom = -6.0
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.visible = false
	add_child(_hint)


func _make_label(content: String, colour: Color, size_px: int) -> Label:
	var made: Label = Label.new()
	made.text = content
	made.add_theme_color_override("font_color", colour)
	made.add_theme_font_size_override("font_size", size_px)
	made.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return made


func _make_box(fill: Color, edge: Color) -> PanelContainer:
	var made: PanelContainer = PanelContainer.new()
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = edge
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 9.0
	style.content_margin_bottom = 9.0
	made.add_theme_stylebox_override("panel", style)
	made.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return made
