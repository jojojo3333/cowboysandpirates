extends Control

# The only script attached to the only scene. Every Control below is built in
# GDScript at runtime — CLAUDE.md constraint 1. No .tscn is ever created or
# hand-edited beyond main.tscn itself.
#
# This file is the whole of ui/ for slice 1. It holds no authoritative state:
# everything it draws it reads from `scene`, and every click it turns into a
# call back into the simulation.

const BG: Color = Color(0.06, 0.07, 0.09)
const PANEL: Color = Color(0.11, 0.13, 0.16)
const ROOM_IDLE: Color = Color(0.16, 0.18, 0.22)
const ROOM_TOCK: Color = Color(0.16, 0.26, 0.30)
const ROOM_CAPTIVE: Color = Color(0.28, 0.18, 0.16)

const TEXT: Color = Color(0.82, 0.85, 0.88)
const DIM: Color = Color(0.50, 0.54, 0.58)
const WARN: Color = Color(0.90, 0.75, 0.35)
const CRIT: Color = Color(0.92, 0.44, 0.38)
const VOICE: Color = Color(0.55, 0.80, 0.85)

const MAX_LOG_LINES: int = 120

var scene: RescueScene = null

var _room_panels: Dictionary = {}
var _room_titles: Dictionary = {}
var _room_bodies: Dictionary = {}
var _move_buttons: Dictionary = {}
var _free_buttons: Dictionary = {}

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
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	add_child(margin)

	var root: VBoxContainer = VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)

	_title_label = _make_label("", TEXT, 18)
	root.add_child(_title_label)

	var middle: HBoxContainer = HBoxContainer.new()
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	middle.add_theme_constant_override("separation", 12)
	root.add_child(middle)

	middle.add_child(_build_ship_grid())
	middle.add_child(_build_log_panel())

	root.add_child(_build_voice_panel())
	root.add_child(_build_proposal_panel())
	root.add_child(_build_ending_panel())

	_status_label = _make_label("", DIM, 13)
	root.add_child(_status_label)


func _build_ship_grid() -> Control:
	var wrap: PanelContainer = _make_panel(PANEL)
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrap.size_flags_stretch_ratio = 2.0

	var grid: GridContainer = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	wrap.add_child(grid)

	# Built from data, ordered by grid position so the layout file is the single
	# source of truth for the ship's shape.
	var layout: ShipLayout = DataLoader.load_layout()
	var ordered: Array[ShipRoom] = layout.rooms.duplicate()
	ordered.sort_custom(func(a: ShipRoom, b: ShipRoom) -> bool:
		if a.row != b.row:
			return a.row < b.row
		return a.col < b.col
	)

	for room: ShipRoom in ordered:
		grid.add_child(_build_room_tile(room))

	return wrap


func _build_room_tile(room: ShipRoom) -> Control:
	var panel: PanelContainer = _make_panel(ROOM_IDLE)
	panel.custom_minimum_size = Vector2(190, 150)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)

	var title: Label = _make_label(room.label, TEXT, 14)
	box.add_child(title)

	var body: Label = _make_label("", DIM, 12)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(body)

	var move_btn: Button = Button.new()
	move_btn.text = "MOVE HERE"
	move_btn.pressed.connect(_on_move_pressed.bind(room.id))
	box.add_child(move_btn)

	var free_holder: VBoxContainer = VBoxContainer.new()
	free_holder.add_theme_constant_override("separation", 3)
	box.add_child(free_holder)

	var per_room: Dictionary = {}
	for cid: Variant in scene_captive_ids():
		var crew_id: String = str(cid)
		var btn: Button = Button.new()
		btn.text = "FREE"
		btn.visible = false
		btn.pressed.connect(_on_free_pressed.bind(crew_id))
		free_holder.add_child(btn)
		per_room[crew_id] = btn

	_room_panels[room.id] = panel
	_room_titles[room.id] = title
	_room_bodies[room.id] = body
	_move_buttons[room.id] = move_btn
	_free_buttons[room.id] = per_room
	return panel


func scene_captive_ids() -> Array:
	var cfg: Dictionary = DataLoader.load_scene()
	return cfg.get("captives", [])


func _build_log_panel() -> Control:
	var panel: PanelContainer = _make_panel(PANEL)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size = Vector2(340, 0)

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
	_voice_label.custom_minimum_size = Vector2(0, 46)
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

	var executing: bool = scene.phase == RescueScene.Phase.EXECUTING
	var idle: bool = scene.task == RescueScene.Task.IDLE
	var tock_room: String = scene.tock.room if scene.tock != null else ""

	for room_id: Variant in _room_panels.keys():
		var rid: String = str(room_id)
		var body: Label = _room_bodies[rid] as Label
		var panel: PanelContainer = _room_panels[rid] as PanelContainer

		var occupants: Array[String] = []
		var has_captive: bool = false
		for m: CrewMember in scene.crew_in_room(rid):
			if m.is_tied():
				occupants.append("%s  [TIED]" % m.display_name)
				has_captive = true
			elif m.is_synthetic:
				occupants.append("%s  %d hp" % [m.display_name, m.hp])
			else:
				occupants.append("%s  %d hp" % [m.display_name, m.hp])
		body.text = "\n".join(occupants)

		var tint: Color = ROOM_IDLE
		if rid == tock_room:
			tint = ROOM_TOCK
		elif has_captive:
			tint = ROOM_CAPTIVE
		_set_panel_colour(panel, tint)

		var move_btn: Button = _move_buttons[rid] as Button
		move_btn.visible = executing and idle and scene.layout.are_adjacent(tock_room, rid)

		var buttons: Dictionary = _free_buttons[rid] as Dictionary
		for crew_id: Variant in buttons.keys():
			var cid: String = str(crew_id)
			var btn: Button = buttons[cid] as Button
			var m2: CrewMember = scene.get_crew(cid)
			var can_free: bool = (
				executing and idle and m2 != null and m2.is_tied()
				and m2.room == rid and tock_room == rid
			)
			btn.visible = can_free
			if can_free:
				btn.text = "FREE %s" % m2.display_name

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
		if scene.hack_active:
			bits.append("hack %4.1fs" % maxf(scene.hack_remaining, 0.0))
		if scene.fight_active:
			bits.append("firefight %4.1fs" % maxf(scene.fight_remaining, 0.0))
		bits.append("PAUSED — SPACE" if scene.is_paused() else "running — SPACE to pause")

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
# ever be the only indication that something happened.
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


func _on_move_pressed(room_id: String) -> void:
	if scene != null:
		scene.order_move(room_id)


func _on_free_pressed(crew_id: String) -> void:
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
	_set_panel_colour(panel, colour)
	return panel


func _set_panel_colour(panel: PanelContainer, colour: Color) -> void:
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
