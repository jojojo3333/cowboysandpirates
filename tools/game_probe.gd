class_name GameProbe
extends RefCounted

# Asks the running game what is true, in the game's own nouns.
#
# This is the truth layer. A screenshot is the visual layer, and the two answer
# different questions: a screenshot can show that the hold looks wrong, but only
# this can say *which crew member is selected*, *where Kwon actually stands*,
# *which clip is playing*, *what the log said*. An agent that has to infer any of
# that from pixels is guessing, and a test that asserts on pixels fails for
# reasons that have nothing to do with the bug.
#
# Why it exists at all, in one example. The collapsed-HUD bug — a Control with
# anchors 0,0,1,1 and offsets that made it 0x0, so its children stacked in the
# top-left — was found by writing a throwaway script that printed node sizes.
# Two minutes, worked perfectly, thrown away, and it would have to be rewritten
# from scratch the next time. `ui_layout()` below is that probe, kept.
#
# Three rules this follows, and they are what stop it rotting:
#
#   1. **It only reads.** Nothing here may call into the simulation to change
#      anything. A probe that can move a crew member is a second, undocumented
#      way to play the game, and the two will drift.
#   2. **It reports, it does not judge.** No thresholds, no pass/fail. The
#      assertions live in tools/play.gd, so what is *measured* and what is
#      *expected* can be argued about separately.
#   3. **Its output is plain data** — Dictionary, Array, String, float — so it
#      can be printed as JSON, diffed between two runs, and read by something
#      that is not Godot.

const PHASE_NAMES: Dictionary = {0: "PROPOSAL", 1: "ACTIVE", 2: "RESOLVED"}
const TASK_NAMES: Dictionary = {0: "IDLE", 1: "FREEING"}
const STATE_NAMES: Dictionary = {0: "ACTIVE", 1: "TIED", 2: "DOWN"}

var _main: Node = null
var _scene: RescueScene = null
var _ship: ShipView = null


func _init(main: Node) -> void:
	_main = main
	_scene = main.get("scene") as RescueScene
	_ship = _find_ship(main)


# Everything, as one plain dictionary. This is what gets dumped to JSON and
# diffed between runs; the narrower accessors below are for assertions that only
# care about one thing.
func snapshot() -> Dictionary:
	return {
		"t": _round(_scene.time),
		"paused": _scene.is_paused(),
		"phase": str(PHASE_NAMES.get(_scene.phase, _scene.phase)),
		"plan": _scene.plan,
		"task": task(),
		"crew": crew(),
		"rooms": rooms(),
		"log": log_lines(),
		"ui": ui_layout(),
	}


# Which crew members the player has selected — the question the whole truth
# layer was justified with, finally answerable.
func selected() -> Array:
	return _ship.selected.duplicate() if _ship != null else []


# Everyone currently walking somewhere. One name per mover, so an assertion can
# say "three people set off" without unpacking the whole roster.
func movers() -> Array:
	var out: Array = []
	for member: CrewMember in _crew_list():
		if member.is_moving():
			out.append(member.id)
	return out


func task() -> Dictionary:
	return {
		"name": str(TASK_NAMES.get(_scene.task, _scene.task)),
		"target": _scene.task_target,
		"progress": _round(_scene.task_progress()),
		"busy": _scene.is_busy(),
	}


# One entry per crew member, simulation state and drawn state side by side.
#
# The two being in one record is the point. "Kwon is in the hold" and "Kwon is
# drawn at (412, 388)" are separately true and separately checkable, and every
# crew-rendering bug this project has had — figures standing below the point the
# simulation says they occupy, crew walking through bulkheads, markers landing on
# heads — is a disagreement between them.
func crew() -> Array:
	var out: Array = []
	for member: CrewMember in _crew_list():
		var record: Dictionary = {
			"id": member.id,
			"name": member.display_name,
			"class": member.class_id,
			"room": member.room,
			"hp": member.hp,
			"state": str(STATE_NAMES.get(member.state, member.state)),
			"synthetic": member.is_synthetic,
			"moving": member.is_moving(),
			"move_target": member.move_target,
			"route": member.route.duplicate(),
		}
		if _ship != null:
			record["selected"] = _ship.selected.has(member.id)
		if _ship != null:
			var point: Vector2 = _ship.crew_position(member)
			record["at"] = [_round(point.x), _round(point.y)]
			record["in_own_room"] = _point_in_room(point, member.room)

			# Where the *picture* lands, which is not the same question. The
			# sprite carries an art offset to compensate for the figure sitting
			# low in its render cell, so `at` can be perfectly correct while the
			# player sees someone standing in the corridor outside. Asking only
			# the first question is how a wrong offset survives.
			var sprite: Sprite2D = _crew_sprite(member.id)
			if sprite != null:
				var drawn: Vector2 = sprite.position + sprite.offset * sprite.scale
				record["drawn_at"] = [_round(drawn.x), _round(drawn.y)]
				record["drawn_in_own_room"] = _point_in_room(drawn, member.room)
				record["clip"] = _clip_of(sprite)
				record["frame"] = sprite.frame
		out.append(record)
	return out


func rooms() -> Array:
	var out: Array = []
	for room: ShipRoom in _scene.layout.rooms:
		var here: Array[CrewMember] = _scene.crew_in_room(room.id)
		var ids: Array = []
		for m: CrewMember in here:
			ids.append(m.id)
		out.append({
			"id": room.id,
			"label": room.label,
			"capacity": room.capacity,
			"occupants": ids,
			"over_capacity": room.capacity > 0 and ids.size() > room.capacity,
		})
	return out


# The log as structured events, not as the strings the panel renders. CLAUDE.md
# makes the log the game's spine — "if it matters, it writes a log line" — which
# makes it the best assertion surface in the project: if a thing happened, there
# is a machine-readable record that it happened.
func log_lines() -> Array:
	var out: Array = []
	for e: LogEvent in _scene.log_bus.events:
		out.append({
			"t": _round(e.t),
			"type": e.type,
			"severity": e.severity,
			"subjects": e.subjects.duplicate(),
		})
	return out


func log_types() -> Array:
	var out: Array = []
	for e: LogEvent in _scene.log_bus.events:
		out.append(e.type)
	return out


# Every Control in the tree, with the size it actually resolved to.
#
# This is the permanent version of the throwaway probe that found the collapsed
# HUD. A zero-width Control is invisible and silent — the game runs, nothing
# errors, and the screen is empty — which CLAUDE.md names the number one cause of
# that symptom. Reporting sizes makes it a one-line assertion instead of an
# afternoon.
func ui_layout() -> Dictionary:
	var out: Dictionary = {}
	_collect_controls(_main, "", out)
	return out


func zero_sized_controls() -> Array:
	var out: Array = []
	var layout: Dictionary = ui_layout()
	for path: String in layout:
		var box: Dictionary = layout[path]
		if bool(box["visible"]) and (float(box["w"]) <= 0.0 or float(box["h"]) <= 0.0):
			out.append(path)
	return out


# Controls anchored to fill their parent that do not, in fact, fill it.
#
# **This is the real signature of the `set_anchors_preset()` bug**, and it is not
# the one that was being looked for. The note in BACKLOG.md says such a Control
# "can end up ... a 0x0 node", so the first version of this probe searched for
# zero sizes and found nothing, because a *Container* does not collapse to zero
# — it shrinks to fit its own children. Reproduced deliberately, the top-level
# margin came back 1071x609 inside a 1280x720 window: not zero, just wrong, and
# invisible to any check looking for zero.
#
# Anchors saying "fill the parent" while the resolved size says otherwise is
# what actually distinguishes the two, and it catches the shrink and the total
# collapse alike.
func full_rect_not_filling() -> Array:
	var out: Array = []
	for path: String in ui_layout():
		var box: Dictionary = ui_layout()[path]
		if not bool(box["visible"]) or not bool(box["full_rect"]):
			continue
		if (
			not is_equal_approx(float(box["w"]), float(box["parent_w"]))
			or not is_equal_approx(float(box["h"]), float(box["parent_h"]))
		):
			out.append("%s is %dx%d inside a %dx%d parent"
				% [path, box["w"], box["h"], box["parent_w"], box["parent_h"]])
	return out


# Whether the layout numbers above are worth believing at all.
#
# Under `--headless` Godot lays Controls out against a 64x64 stand-in window
# while their children resolve against the real project viewport, so the tree
# comes back internally inconsistent — the root reports 64x64 with 1071x609
# children inside it. Nothing errors, and every "is anything zero-sized?" check
# passes on numbers that mean nothing. **A check that silently passes on junk is
# worse than no check**, so the harness asks this first and reports the layout
# assertions as skipped rather than green when it is false.
func layout_is_trustworthy() -> bool:
	if _main == null or not is_instance_valid(_main):
		return false
	var control: Control = _main as Control
	if control == null:
		return false
	# Against the *project's* configured viewport, not the runtime one. Asking
	# the runtime viewport is asking the same broken thing twice: headless
	# reports 64x64 for both, they agree, and the answer comes back "trustworthy"
	# having checked nothing.
	var want: Vector2 = Vector2(
		float(ProjectSettings.get_setting("display/window/size/viewport_width", 0)),
		float(ProjectSettings.get_setting("display/window/size/viewport_height", 0))
	)
	if want.x <= 0.0 or want.y <= 0.0:
		return false
	return control.size.is_equal_approx(want)


# --- internals --------------------------------------------------------------

# ShipView names each crew sprite `crew_<id>`, which is the whole reason this
# can be found from outside without ShipView exposing its internals.
func _crew_sprite(crew_id: String) -> Sprite2D:
	return _find_sprite(_ship, "crew_%s" % crew_id)


func _find_sprite(node: Node, want: String) -> Sprite2D:
	if node == null:
		return null
	if node.name == want:
		return node as Sprite2D
	for child: Node in node.get_children():
		var found: Sprite2D = _find_sprite(child, want)
		if found != null:
			return found
	return null


# Which sheet the sprite is currently pointed at — walk, idle or die. Read off
# the texture path rather than tracked separately, so it cannot disagree with
# what is actually on screen.
func _clip_of(sprite: Sprite2D) -> String:
	if sprite.texture == null:
		return ""
	var stem: String = sprite.texture.resource_path.get_file().get_basename()
	var parts: PackedStringArray = stem.split("_")
	return parts[parts.size() - 1] if parts.size() > 1 else stem


func _crew_list() -> Array[CrewMember]:
	if _ship != null:
		return _ship.all_crew()
	return _scene.crew


# Whether the point a crew member is drawn at falls inside the compartment the
# simulation says they are in. False is not automatically a bug — someone in
# transit is legitimately out in a corridor — so this reports and play.gd decides.
func _point_in_room(point: Vector2, room_id: String) -> bool:
	var room: ShipRoom = _scene.layout.get_room(room_id)
	if room == null:
		return false
	return room.contains(point)


func _collect_controls(node: Node, path: String, out: Dictionary) -> void:
	var here: String = path + "/" + node.name
	var control: Control = node as Control
	if control != null:
		var parent: Control = control.get_parent() as Control
		var parent_size: Vector2 = (
			parent.size if parent != null else control.get_viewport().get_visible_rect().size
		)
		out[here] = {
			"w": _round(control.size.x),
			"h": _round(control.size.y),
			"x": _round(control.global_position.x),
			"y": _round(control.global_position.y),
			"visible": control.is_visible_in_tree(),
			# Anchors, so a Control that claims to fill its parent can be held to
			# it. Reported rather than judged — see full_rect_not_filling().
			"full_rect": (
				is_equal_approx(control.anchor_left, 0.0)
				and is_equal_approx(control.anchor_top, 0.0)
				and is_equal_approx(control.anchor_right, 1.0)
				and is_equal_approx(control.anchor_bottom, 1.0)
			),
			"parent_w": _round(parent_size.x),
			"parent_h": _round(parent_size.y),
		}
	for child: Node in node.get_children():
		_collect_controls(child, here, out)


func _find_ship(node: Node) -> ShipView:
	var view: ShipView = node as ShipView
	if view != null:
		return view
	for child: Node in node.get_children():
		var found: ShipView = _find_ship(child)
		if found != null:
			return found
	return null


# Two decimal places everywhere. Snapshots get compared between runs to prove
# determinism, and raw floats differ in the last bit for reasons that are not
# bugs.
func _round(value: float) -> float:
	return snappedf(value, 0.01)
