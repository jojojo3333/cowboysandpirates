extends Control

# The only script attached to the only scene. Every Control below is built in
# GDScript at runtime — CLAUDE.md constraint 1. No .tscn is ever created or
# hand-edited beyond main.tscn itself.
#
# This holds no authoritative state: everything it draws it reads from `scene`,
# and every click it turns into a call back into the simulation. The ship
# itself is drawn by ui/ship_view.gd.

const BG: Color = Color(0.06, 0.07, 0.09)
const PANEL: Color = Color(0.11, 0.13, 0.16)

const TEXT: Color = Color(0.82, 0.85, 0.88)
const DIM: Color = Color(0.50, 0.54, 0.58)
const WARN: Color = Color(0.90, 0.75, 0.35)
const CRIT: Color = Color(0.92, 0.44, 0.38)
const VOICE: Color = Color(0.55, 0.80, 0.85)

const MAX_LOG_LINES: int = 120

var scene: RescueScene = null

var _ship: ShipView = null
var _log_box: VBoxContainer = null
var _log_scroll: ScrollContainer = null
var _voice_label: Label = null
var _status_label: Label = null
var _title_label: Label = null
var _proposal_panel: PanelContainer = null
var _proposal_text: Label = null
var _choice_row: HBoxContainer = null
var _ending_panel: PanelContainer = null
var _ending_label: Label = null


func _ready() -> void:
	print("BOOT OK")
	_build_ui()
	_start_run(0)


func _start_run(seed_in: int) -> void:
	scene = RescueScene.new(seed_in)
	scene.log_bus.event_appended.connect(_on_log_event)
	scene.phase_changed.connect(_on_phase_changed)

	_ship.scene = scene
	_ship.layout = scene.layout

	_clear_log()
	for e: LogEvent in scene.log_bus.events:
		_on_log_event(e)

	_title_label.text = "%s   —   seed %d" % [
		str(scene.config.get("title", "THE CARGO HOLD")), scene.rng.seed_value
	]
	_proposal_text.text = str((scene.config.get("proposal", {}) as Dictionary).get("text", ""))
	_build_choice_buttons()
	_ending_panel.visible = false
	_proposal_panel.visible = true
	_voice_label.text = ""
	_refresh()


func _process(delta: float) -> void:
	if scene == null:
		return
	scene.tick(delta)
	_refresh()


func _unhandled_key_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY_SPACE and scene != null:
		scene.toggle_pause()
		get_viewport().set_input_as_handled()


# --- construction ----------------------------------------------------------

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var bg: ColorRect = ColorRect.new()
	bg.color = BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	add_child(margin)

	var root: VBoxContainer = VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	margin.add_child(root)

	_title_label = _make_label("", TEXT, 18)
	root.add_child(_title_label)

	var middle: HBoxContainer = HBoxContainer.new()
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	middle.add_theme_constant_override("separation", 10)
	root.add_child(middle)

	var ship_frame: PanelContainer = _make_panel(PANEL)
	ship_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ship_frame.size_flags_stretch_ratio = 2.2
	middle.add_child(ship_frame)

	_ship = ShipView.new()
	_ship.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ship.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_ship.custom_minimum_size = Vector2(560, 320)
	_ship.room_clicked.connect(_on_room_clicked)
	_ship.crew_clicked.connect(_on_crew_clicked)
	ship_frame.add_child(_ship)

	middle.add_child(_build_log_panel())

	root.add_child(_build_voice_panel())
	root.add_child(_build_proposal_panel())
	root.add_child(_build_ending_panel())

	_status_label = _make_label("", DIM, 13)
	root.add_child(_status_label)


func _build_log_panel() -> Control:
	var panel: PanelContainer = _make_panel(PANEL)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size = Vector2(320, 0)

	var box: VBoxContainer = VBoxContainer.new()
	panel.add_child(box)
	box.add_child(_make_label("LOG", DIM, 12))

	_log_scroll = ScrollContainer.new()
	_log_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(_log_scroll)

	_log_box = VBoxContainer.new()
	_log_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_log_box.add_theme_constant_override("separation", 2)
	_log_scroll.add_child(_log_box)

	return panel


func _build_voice_panel() -> Control:
	var panel: PanelContainer = _make_panel(Color(0.09, 0.14, 0.16))
	_voice_label = _make_label("", VOICE, 14)
	_voice_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_voice_label.custom_minimum_size = Vector2(0, 42)
	panel.add_child(_voice_label)
	return panel


func _build_proposal_panel() -> Control:
	_proposal_panel = _make_panel(Color(0.13, 0.12, 0.09))
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	_proposal_panel.add_child(box)

	_proposal_text = _make_label("", TEXT, 14)
	_proposal_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_proposal_text)

	_choice_row = HBoxContainer.new()
	_choice_row.add_theme_constant_override("separation", 8)
	box.add_child(_choice_row)

	return _proposal_panel


func _build_choice_buttons() -> void:
	for child: Node in _choice_row.get_children():
		child.queue_free()
	var proposal: Dictionary = scene.config.get("proposal", {}) as Dictionary
	for entry: Variant in proposal.get("choices", []):
		var c: Dictionary = entry as Dictionary
		var btn: Button = Button.new()
		btn.text = "%s  —  %s" % [str(c.get("label", "")), str(c.get("detail", ""))]
		btn.custom_minimum_size = Vector2(0, 34)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(_on_plan_pressed.bind(str(c.get("id", ""))))
		_choice_row.add_child(btn)


func _build_ending_panel() -> Control:
	_ending_panel = _make_panel(Color(0.10, 0.14, 0.11))
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	_ending_panel.add_child(box)

	_ending_label = _make_label("", TEXT, 16)
	_ending_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_ending_label)

	var restart: Button = Button.new()
	restart.text = "RESTART"
	restart.custom_minimum_size = Vector2(0, 34)
	restart.pressed.connect(_on_restart_pressed)
	box.add_child(restart)

	_ending_panel.visible = false
	return _ending_panel


# --- per-frame refresh -----------------------------------------------------

func _refresh() -> void:
	if scene == null:
		return
	_status_label.text = _status_text()
	_proposal_panel.visible = scene.phase == RescueScene.Phase.PROPOSAL


func _status_text() -> String:
	var bits: Array[String] = []
	bits.append("t %5.1fs" % scene.time)
	bits.append("tied %d" % scene.tied_count())

	if scene.phase == RescueScene.Phase.PROPOSAL:
		bits.append("awaiting orders")
	elif scene.phase == RescueScene.Phase.RESOLVED:
		bits.append("resolved")
	else:
		if scene.task == RescueScene.Task.TRANSIT:
			bits.append("moving %d%%" % int(scene.task_progress() * 100.0))
		elif scene.task == RescueScene.Task.FREEING:
			bits.append("cutting %d%%" % int(scene.task_progress() * 100.0))
		else:
			bits.append("click a room to move, a captive to cut them loose")
		if scene.hack_active:
			bits.append("hack %4.1fs" % maxf(scene.hack_remaining, 0.0))
		if scene.fight_active:
			bits.append("firefight %4.1fs" % maxf(scene.fight_remaining, 0.0))
		bits.append("PAUSED — SPACE" if scene.is_paused() else "SPACE to pause")

	return "     ".join(bits)


# --- log ------------------------------------------------------------------

func _clear_log() -> void:
	for child: Node in _log_box.get_children():
		child.queue_free()


func _on_log_event(event: LogEvent) -> void:
	if event.type == "TOCK_LINE":
		_voice_label.text = "TOCK:  %s" % str(event.values.get("text", ""))
		_append_log_line("        %s" % str(event.values.get("text", "")), VOICE)
		return

	var colour: Color = TEXT
	if event.severity == LogEvent.WARNING:
		colour = WARN
	elif event.severity == LogEvent.CRITICAL:
		colour = CRIT
	_append_log_line("%5.1f  %s" % [event.t, _format(event)], colour)


# Every state change writes a line. GAME_SPEC_v0.2 §7a: no visual effect may
# ever be the only indication that something happened. That rule is why the
# drawn ship view is allowed to be pretty — it is never the only channel.
func _format(event: LogEvent) -> String:
	var who: String = ""
	if not event.subjects.is_empty():
		var m: CrewMember = scene.get_crew(event.subjects[0]) if scene != null else null
		who = m.display_name.to_upper() if m != null else event.subjects[0].to_upper()

	match event.type:
		"SCENE_START": return "SIGNAL LOST. SYSTEMS REBOOTING."
		"BRIEF": return str(event.values.get("text", ""))
		"PLAN_CHOSEN": return "PLAN: %s" % str(event.values.get("plan", "")).to_upper()
		"MOVE_ORDERED": return "%s MOVING TO %s." % [who, str(event.values.get("to", "")).to_upper()]
		"ARRIVED": return "%s IN %s." % [who, str(event.values.get("room", "")).to_upper()]
		"FREEING_STARTED": return "CUTTING RESTRAINTS: %s." % who
		"CREW_FREED": return "%s IS FREE." % who
		"BOARDER_DOWN": return "BOARDER %d DOWN." % int(event.values.get("index", 0))
		"WEAPONS_TAKEN": return "CARGO CACHE OPENED. WEAPONS RECOVERED."
		"FIGHT_STARTED": return "CONTACT. FIREFIGHT IN THE HOLD."
		"CREW_INJURED": return "%s INJURED. %d HP." % [who, int(event.values.get("hp", 0))]
		"SCENE_RESOLVED": return "ALL %d ACCOUNTED FOR. %.1fs." % [
			int(event.values.get("freed", 0)), float(event.values.get("seconds", 0.0))
		]
	return event.type


func _append_log_line(text: String, colour: Color) -> void:
	var label: Label = _make_label(text, colour, 12)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_log_box.add_child(label)

	while _log_box.get_child_count() > MAX_LOG_LINES:
		var oldest: Node = _log_box.get_child(0)
		_log_box.remove_child(oldest)
		oldest.queue_free()

	await get_tree().process_frame
	if is_instance_valid(_log_scroll):
		_log_scroll.scroll_vertical = int(_log_scroll.get_v_scroll_bar().max_value)


# --- input handlers --------------------------------------------------------

func _on_plan_pressed(plan_id: String) -> void:
	if scene != null:
		scene.choose_plan(plan_id)


func _on_room_clicked(room_id: String) -> void:
	if scene != null:
		scene.order_move(room_id)


func _on_crew_clicked(crew_id: String) -> void:
	if scene != null:
		scene.order_free(crew_id)


func _on_restart_pressed() -> void:
	_start_run(0)


func _on_phase_changed(phase: int) -> void:
	if phase == RescueScene.Phase.RESOLVED:
		_ending_label.text = "%s\n\n%s" % [scene.ending_text(), _survivor_summary()]
		_ending_panel.visible = true


func _survivor_summary() -> String:
	var parts: Array[String] = []
	for m: CrewMember in scene.crew:
		parts.append("%s %d hp" % [m.display_name, m.hp])
	if scene.tock != null:
		parts.append("%s %d hp" % [scene.tock.display_name, scene.tock.hp])
	return "     ".join(parts)


# --- small helpers ---------------------------------------------------------

func _make_label(text: String, colour: Color, size: int) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_color_override("font_color", colour)
	label.add_theme_font_size_override("font_size", size)
	return label


func _make_panel(colour: Color) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = colour
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_left = 3
	style.corner_radius_bottom_right = 3
	panel.add_theme_stylebox_override("panel", style)
	return panel
