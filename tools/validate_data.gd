extends SceneTree
#
# Data contract validation. Run headless:
#   godot --headless --script tools/validate_data.gd
#
# Enforces ARCHITECTURE.md §5: a missing key is a crash at startup, not a null
# at hour three. Unknown bonus keys are a WARNING, never a failure, so v0.3 keys
# can be authored before the code that reads them exists.
#
# Note: Godot 4.7 treats several type-inference warnings as errors, so every
# declaration here is explicitly typed. Keep it that way.

var errors: Array[String] = []
var warnings: Array[String] = []


func _init() -> void:
	var classes: Variant = _load_json("res://data/classes.json")
	var crew: Variant = _load_json("res://data/crew.json")

	var class_ids: Array = []
	if classes != null:
		class_ids = _check_classes(classes)

	# The layout is checked first because crew.json is checked against it.
	var room_ids: Array = _check_layout()
	var crew_ids: Array = []
	if crew != null:
		crew_ids = _check_crew(crew, class_ids, room_ids)

	_check_scene(room_ids, crew_ids)

	for w: String in warnings:
		print("WARN  ", w)
	for e: String in errors:
		printerr("ERROR ", e)

	if errors.is_empty():
		print("data contracts OK (%d warnings)" % warnings.size())
		quit(0)
	else:
		printerr("data validation failed: %d error(s)" % errors.size())
		quit(1)


func _load_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		errors.append("%s does not exist" % path)
		return null
	var text: String = FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null:
		errors.append("%s is not valid JSON" % path)
		return null
	return parsed


func _check_classes(data: Variant) -> Array:
	var ids: Array = []
	if not (data is Dictionary) or not (data as Dictionary).has("classes"):
		errors.append("classes.json: missing top-level 'classes' array")
		return ids

	var dict: Dictionary = data as Dictionary
	var known_bonus_keys: Array = []
	if dict.has("_bonus_keys") and dict["_bonus_keys"] is Dictionary:
		known_bonus_keys = (dict["_bonus_keys"] as Dictionary).keys()

	var required: Array[String] = ["id", "label", "description", "unique", "is_synthetic", "bonuses"]
	var commanders: int = 0

	for entry: Variant in dict["classes"]:
		var c: Dictionary = entry as Dictionary
		var cid: String = str(c.get("id", ""))
		for key: String in required:
			if not c.has(key):
				errors.append("classes.json: class '%s' missing '%s'" % [cid, key])
		if ids.has(cid):
			errors.append("classes.json: duplicate class id '%s'" % cid)
		ids.append(cid)
		if cid == "commander":
			commanders += 1
		if c.get("bonuses") is Dictionary:
			for bkey: Variant in (c["bonuses"] as Dictionary).keys():
				if not known_bonus_keys.is_empty() and not known_bonus_keys.has(bkey):
					warnings.append(
						"classes.json: class '%s' uses bonus key '%s' not in _bonus_keys"
						% [cid, str(bkey)]
					)

	if commanders != 1:
		errors.append("classes.json: expected exactly one 'commander' class, found %d" % commanders)
	return ids


func _check_layout() -> Array:
	var layout: ShipLayout = DataLoader.load_layout()
	var ids: Array = []

	if layout.rooms.is_empty():
		errors.append("ship_layout.json: no rooms loaded")
		return ids

	if layout.plate_path == "" or not FileAccess.file_exists(layout.plate_path):
		errors.append("ship_layout.json: plate '%s' does not exist" % layout.plate_path)
	if layout.plate_normal_path != "" and not FileAccess.file_exists(layout.plate_normal_path):
		errors.append("ship_layout.json: plate_normal '%s' does not exist" % layout.plate_normal_path)

	for room: ShipRoom in layout.rooms:
		if room.id == "":
			errors.append("ship_layout.json: a room has no id")
		if ids.has(room.id):
			errors.append("ship_layout.json: duplicate room id '%s'" % room.id)
		ids.append(room.id)
		if room.adjacent.is_empty():
			errors.append("ship_layout.json: room '%s' is isolated" % room.id)

		# A room with no shape is invisible and unclickable, and the failure
		# looks like a dead click rather than a crash.
		if room.polygon.size() < 3:
			errors.append("ship_layout.json: room '%s' has no polygon" % room.id)
		else:
			for p: Vector2 in room.polygon:
				if p.x < 0.0 or p.y < 0.0 or p.x > layout.plate_size.x or p.y > layout.plate_size.y:
					errors.append(
						"ship_layout.json: room '%s' has a point outside the plate: %s"
						% [room.id, str(p)]
					)
					break
			if not Geometry2D.is_point_in_polygon(room.centre(), room.polygon):
				errors.append(
					"ship_layout.json: room '%s' centroid falls outside its own polygon"
					% room.id
				)

	# Every connection needs a way to walk it: either an authored bulkhead door,
	# or both compartments opening onto the corridor. Without one of those, crew
	# walk through a wall.
	#
	# It also needs a distance, or travel is free and the ship's size stops
	# mattering — which is the whole point of charging by distance.
	for room: ShipRoom in layout.rooms:
		for other_id: String in room.adjacent:
			if layout.get_room(other_id) == null:
				continue
			var on_corridor: bool = (
				layout.corridor_door(room.id) != Vector2.ZERO
				and layout.corridor_door(other_id) != Vector2.ZERO
			)
			var found: bool = false
			for d: Dictionary in layout.doors:
				var pair: Array = d.get("between", []) as Array
				if pair.size() == 2 and (
					(pair[0] == room.id and pair[1] == other_id)
					or (pair[0] == other_id and pair[1] == room.id)
				):
					found = true
					break
			if not found and not on_corridor:
				errors.append(
					"ship_layout.json: '%s' and '%s' are adjacent with no door and no corridor route"
					% [room.id, other_id]
				)
			if layout.walk_distance(room.id, other_id) <= 0.0:
				errors.append(
					"ship_layout.json: no walk distance between '%s' and '%s'"
					% [room.id, other_id]
				)

	# --- the corridor graph -------------------------------------------------
	# Crew walk this, so a waypoint off the plate or a compartment with no way
	# out is a crew member walking through a wall, which is the bug this data
	# exists to fix.
	var plate: Rect2 = Rect2(Vector2.ZERO, layout.plate_size)

	for wp_id: Variant in layout.waypoints.keys():
		var at: Vector2 = layout.waypoints[wp_id] as Vector2
		if not plate.has_point(at):
			errors.append(
				"ship_layout.json: waypoint '%s' is outside the plate: %s" % [str(wp_id), str(at)]
			)

	for edge: Array in layout.corridor_edges:
		for end: Variant in edge:
			if not layout.waypoints.has(str(end)):
				errors.append("ship_layout.json: corridor_edge names unknown waypoint '%s'" % str(end))

	for room_id: Variant in layout.room_doors.keys():
		if layout.get_room(str(room_id)) == null:
			errors.append("ship_layout.json: room_doors names unknown room '%s'" % str(room_id))
		var wp: String = layout.corridor_waypoint(str(room_id))
		if not layout.waypoints.has(wp):
			errors.append(
				"ship_layout.json: room '%s' opens onto unknown waypoint '%s'" % [str(room_id), wp]
			)
		var door_at: Vector2 = layout.corridor_door(str(room_id))
		if not plate.has_point(door_at):
			errors.append(
				"ship_layout.json: door for room '%s' is outside the plate: %s"
				% [str(room_id), str(door_at)]
			)

	_check_reachability(layout, ids)

	for room: ShipRoom in layout.rooms:
		if room.capacity <= 0:
			warnings.append(
				"ship_layout.json: room '%s' has no capacity — it will hold any number of bodies"
				% room.id
			)

	# An asymmetric adjacency list produces a room fire can enter and not leave.
	# That bug would only surface once v0.2 exists, which is exactly why it is
	# worth catching now.
	for problem: String in layout.asymmetric_pairs():
		errors.append("ship_layout.json: asymmetric adjacency %s" % problem)

	return ids


# Every compartment must reach every other one by walking: through its corridor
# door, along corridor_edges, and out through another compartment's door. A room
# with no corridor door of its own — life support opens only into the reactor —
# may use an authored bulkhead door instead, and nothing else may.
func _check_reachability(layout: ShipLayout, room_ids: Array) -> void:
	if room_ids.is_empty():
		return

	var graph: Dictionary = {}
	var link: Callable = func(a: String, b: String) -> void:
		if not graph.has(a):
			graph[a] = [] as Array[String]
		if not graph.has(b):
			graph[b] = [] as Array[String]
		(graph[a] as Array[String]).append(b)
		(graph[b] as Array[String]).append(a)

	for edge: Array in layout.corridor_edges:
		if edge.size() == 2:
			link.call("wp:" + str(edge[0]), "wp:" + str(edge[1]))
	for room_id: Variant in layout.room_doors.keys():
		link.call("room:" + str(room_id), "wp:" + layout.corridor_waypoint(str(room_id)))
	for d: Dictionary in layout.doors:
		var pair: Array = d.get("between", []) as Array
		if pair.size() != 2:
			continue
		var a: String = str(pair[0])
		var b: String = str(pair[1])
		if layout.corridor_door(a) == Vector2.ZERO or layout.corridor_door(b) == Vector2.ZERO:
			link.call("room:" + a, "room:" + b)

	var start: String = "room:" + str(room_ids[0])
	var seen: Dictionary = {start: true}
	var queue: Array[String] = [start]
	while not queue.is_empty():
		var current: String = queue.pop_front()
		for neighbour: String in (graph.get(current, []) as Array[String]):
			if not seen.has(neighbour):
				seen[neighbour] = true
				queue.append(neighbour)

	for room_id: Variant in room_ids:
		if not seen.has("room:" + str(room_id)):
			errors.append(
				"ship_layout.json: room '%s' cannot be walked to from '%s'"
				% [str(room_id), str(room_ids[0])]
			)


func _check_scene(room_ids: Array, crew_ids: Array) -> void:
	var scene: Dictionary = DataLoader.load_scene()
	if scene.is_empty():
		errors.append("scene_rescue.json: did not load")
		return

	for key: String in ["tock_start_room", "captives_room"]:
		var room_id: String = str(scene.get(key, ""))
		if not room_ids.is_empty() and not room_ids.has(room_id):
			errors.append("scene_rescue.json: %s '%s' is not a room" % [key, room_id])

	var captives: Array = scene.get("captives", [])
	if captives.is_empty():
		errors.append("scene_rescue.json: no captives listed")
	for entry: Variant in captives:
		var cid: String = str(entry)
		if not crew_ids.is_empty() and not crew_ids.has(cid):
			errors.append("scene_rescue.json: captive '%s' is not in crew.json" % cid)

	# The hold has to fit every captive plus whoever walks in to cut them loose,
	# or the scene deadlocks on a move the simulation is right to refuse.
	var layout_for_scene: ShipLayout = DataLoader.load_layout()
	var hold: ShipRoom = layout_for_scene.get_room(str(scene.get("captives_room", "")))
	if hold != null and hold.capacity > 0 and hold.capacity < captives.size() + 1:
		errors.append(
			"ship_layout.json: '%s' holds %d but the rescue puts %d captives plus TOCK in it"
			% [hold.id, hold.capacity, captives.size()]
		)

	var timing: Dictionary = scene.get("timing", {}) as Dictionary
	for key: String in [
		"crew_walk_speed", "free_seconds", "hack_seconds",
		"hack_stagger_seconds", "fight_seconds", "boarder_count",
		"fight_damage_per_crew", "crew_max_hp",
	]:
		if not timing.has(key):
			errors.append("scene_rescue.json: timing is missing '%s'" % key)

	var proposal: Dictionary = scene.get("proposal", {}) as Dictionary
	var choice_ids: Array = []
	for entry: Variant in proposal.get("choices", []):
		choice_ids.append(str((entry as Dictionary).get("id", "")))
	for required: String in ["hack", "fight"]:
		if not choice_ids.has(required):
			errors.append("scene_rescue.json: proposal is missing the '%s' choice" % required)

	# Every plan needs an ending, or finishing the scene shows a fallback string.
	var endings: Dictionary = scene.get("endings", {}) as Dictionary
	for plan: Variant in choice_ids:
		if not endings.has(str(plan)):
			errors.append("scene_rescue.json: no ending for plan '%s'" % str(plan))


func _check_crew(data: Variant, class_ids: Array, layout_room_ids: Array) -> Array:
	var out_ids: Array = []
	if not (data is Dictionary) or not (data as Dictionary).has("crew"):
		errors.append("crew.json: missing top-level 'crew' array")
		return out_ids

	var dict: Dictionary = data as Dictionary
	var ids: Array = []
	var commanders: int = 0
	var required: Array[String] = ["id", "name", "class", "starting_room"]
	out_ids = ids

	for entry: Variant in dict["crew"]:
		var m: Dictionary = entry as Dictionary
		var mid: String = str(m.get("id", ""))
		for key: String in required:
			if not m.has(key):
				errors.append("crew.json: member '%s' missing '%s'" % [mid, key])
		if ids.has(mid):
			errors.append("crew.json: duplicate crew id '%s'" % mid)
		ids.append(mid)

		var cls: String = str(m.get("class", ""))
		if not class_ids.is_empty() and not class_ids.has(cls):
			errors.append("crew.json: '%s' references unknown class '%s'" % [mid, cls])
		if cls == "commander":
			commanders += 1

		# A starting room that is not on the ship is a crew member standing
		# nowhere. It went unnoticed for three plates because the rescue moves
		# every captive into the hold before anyone is drawn.
		var start_room: String = str(m.get("starting_room", ""))
		if not layout_room_ids.is_empty() and not layout_room_ids.has(start_room):
			errors.append(
				"crew.json: '%s' starts in '%s', which is not a room" % [mid, start_room]
			)

	if commanders != 1:
		errors.append("crew.json: expected exactly one commander, found %d" % commanders)
	return out_ids
