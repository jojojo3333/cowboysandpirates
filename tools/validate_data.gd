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
	var crew_ids: Array = []
	if crew != null:
		crew_ids = _check_crew(crew, class_ids)

	var room_ids: Array = _check_layout()
	_check_scene(room_ids, crew_ids)
	_check_room_props(room_ids)

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

	for room: ShipRoom in layout.rooms:
		if room.id == "":
			errors.append("ship_layout.json: a room has no id")
		if ids.has(room.id):
			errors.append("ship_layout.json: duplicate room id '%s'" % room.id)
		ids.append(room.id)
		if room.adjacent.is_empty():
			errors.append("ship_layout.json: room '%s' is isolated" % room.id)

	# An asymmetric adjacency list produces a room fire can enter and not leave.
	# That bug would only surface once v0.2 exists, which is exactly why it is
	# worth catching now.
	for problem: String in layout.asymmetric_pairs():
		errors.append("ship_layout.json: asymmetric adjacency %s" % problem)

	return ids


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

	var timing: Dictionary = scene.get("timing", {}) as Dictionary
	for key: String in [
		"transit_seconds", "free_seconds", "hack_seconds",
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


# Props are decoration, so a missing one cannot break the simulation — it fails
# silently and leaves a room bare, which is exactly the kind of thing nobody
# notices for a month. Checking it here makes it a build failure instead.
#
# The sprite-file check is also the enforcement point for CLAUDE.md rule 2: a
# name here can only resolve to a file in assets/props/, and every file there
# has to earn its row in ASSETS.md before it can be committed.
func _check_room_props(room_ids: Array) -> void:
	var path: String = "res://data/room_props.json"
	if not FileAccess.file_exists(path):
		return
	var data: Variant = _load_json(path)
	if data == null or not (data is Dictionary):
		return

	var rooms: Variant = (data as Dictionary).get("rooms", {})
	if not (rooms is Dictionary):
		errors.append("room_props.json: 'rooms' must be an object keyed by room id")
		return

	for key: Variant in (rooms as Dictionary).keys():
		var room_id: String = str(key)
		if not room_ids.is_empty() and not room_ids.has(room_id):
			errors.append("room_props.json: '%s' is not a room in ship_layout.json" % room_id)
		var list: Variant = (rooms as Dictionary)[key]
		if not (list is Array):
			errors.append("room_props.json: '%s' must hold an array of props" % room_id)
			continue
		for entry: Variant in list as Array:
			if not (entry is Dictionary):
				errors.append("room_props.json: a prop in '%s' is not an object" % room_id)
				continue
			var prop: Dictionary = entry as Dictionary
			var sprite: String = str(prop.get("sprite", ""))
			if sprite == "":
				errors.append("room_props.json: a prop in '%s' has no sprite" % room_id)
				continue
			if not FileAccess.file_exists("res://assets/props/%s.png" % sprite):
				errors.append(
					"room_props.json: '%s' names sprite '%s', but assets/props/%s.png does not exist"
					% [room_id, sprite, sprite]
				)
			for axis: String in ["x", "y"]:
				var v: float = float(prop.get(axis, 0.5))
				if v < 0.0 or v > 1.0:
					errors.append(
						"room_props.json: prop '%s' in '%s' has %s=%s outside 0..1"
						% [sprite, room_id, axis, str(v)]
					)


func _check_crew(data: Variant, class_ids: Array) -> Array:
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

	if commanders != 1:
		errors.append("crew.json: expected exactly one commander, found %d" % commanders)
	return out_ids
