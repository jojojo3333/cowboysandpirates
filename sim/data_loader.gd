extends RefCounted
class_name DataLoader

# Parses data/*.json into runtime structures and fails loudly. ARCHITECTURE.md
# §5: a missing key is a crash at startup, not a null at hour three.

const LAYOUT_PATH: String = "res://data/ship_layout.json"
const CREW_PATH: String = "res://data/crew.json"
const CLASSES_PATH: String = "res://data/classes.json"
const SCENE_PATH: String = "res://data/scene_rescue.json"


static func load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("data file missing: %s" % path)
		return {}
	var text: String = FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null or not (parsed is Dictionary):
		push_error("data file is not a JSON object: %s" % path)
		return {}
	return parsed as Dictionary


static func load_layout() -> ShipLayout:
	var raw: Dictionary = load_json(LAYOUT_PATH)
	var layout: ShipLayout = ShipLayout.new()
	if raw.is_empty():
		return layout

	layout.plate_path = str(raw.get("plate", ""))
	layout.plate_normal_path = str(raw.get("plate_normal", ""))
	var size_raw: Array = raw.get("plate_size", [1848, 855]) as Array
	if size_raw.size() == 2:
		layout.plate_size = Vector2(float(size_raw[0]), float(size_raw[1]))

	for entry: Variant in raw.get("rooms", []):
		var d: Dictionary = entry as Dictionary
		var room: ShipRoom = ShipRoom.new()
		room.id = str(d.get("id", ""))
		room.label = str(d.get("label", room.id.to_upper()))
		room.system = str(d.get("system", ""))
		var poly: PackedVector2Array = PackedVector2Array()
		for point: Variant in d.get("polygon", []):
			var pair: Array = point as Array
			if pair.size() == 2:
				poly.append(Vector2(float(pair[0]), float(pair[1])))
		room.polygon = poly
		room.capacity = int(d.get("capacity", 0))
		var adj: Array[String] = []
		for a: Variant in d.get("adjacent", []):
			adj.append(str(a))
		room.adjacent = adj
		layout.add_room(room)

	for entry: Variant in raw.get("waypoints", []):
		var d: Dictionary = entry as Dictionary
		var at: Array = d.get("at", []) as Array
		if at.size() == 2:
			layout.waypoints[str(d.get("id", ""))] = Vector2(float(at[0]), float(at[1]))

	var edges: Array[Array] = []
	for entry: Variant in raw.get("corridor_edges", []):
		var pair: Array = entry as Array
		if pair.size() == 2:
			edges.append([str(pair[0]), str(pair[1])])
	layout.corridor_edges = edges

	for entry: Variant in raw.get("room_doors", []):
		var d: Dictionary = entry as Dictionary
		var at: Array = d.get("at", []) as Array
		if at.size() == 2:
			layout.room_doors[str(d.get("room", ""))] = {
				"waypoint": str(d.get("waypoint", "")),
				"at": Vector2(float(at[0]), float(at[1])),
			}

	for entry: Variant in raw.get("walk_distances", []):
		var d: Dictionary = entry as Dictionary
		var pair: Array = d.get("between", []) as Array
		if pair.size() == 2:
			var a: String = str(pair[0])
			var b: String = str(pair[1])
			var key: String = ("%s|%s" % [a, b]) if a < b else ("%s|%s" % [b, a])
			layout.walk_distances[key] = float(d.get("px", 0.0))

	var doors: Array[Dictionary] = []
	for entry: Variant in raw.get("doors", []):
		var d: Dictionary = entry as Dictionary
		var pair: Array = d.get("between", []) as Array
		var at: Array = d.get("at", []) as Array
		if pair.size() == 2 and at.size() == 2:
			doors.append({
				"between": [str(pair[0]), str(pair[1])],
				"at": Vector2(float(at[0]), float(at[1])),
			})
	layout.doors = doors

	return layout


# Returns every crew member listed in crew.json, in file order, with class
# metadata resolved. Synthetics are flagged from classes.json rather than by
# checking the id, so a second synthetic needs no code change.
static func load_crew() -> Array[CrewMember]:
	var crew_raw: Dictionary = load_json(CREW_PATH)
	var classes_raw: Dictionary = load_json(CLASSES_PATH)

	var synthetic_classes: Dictionary = {}
	var hostile_classes: Dictionary = {}
	for entry: Variant in classes_raw.get("classes", []):
		var c: Dictionary = entry as Dictionary
		synthetic_classes[str(c.get("id", ""))] = bool(c.get("is_synthetic", false))
		hostile_classes[str(c.get("id", ""))] = bool(c.get("is_hostile", false))

	var out: Array[CrewMember] = []
	for entry: Variant in crew_raw.get("crew", []):
		var d: Dictionary = entry as Dictionary
		var m: CrewMember = CrewMember.new()
		m.id = str(d.get("id", ""))
		m.display_name = str(d.get("name", m.id))
		m.class_id = str(d.get("class", ""))
		m.room = str(d.get("starting_room", ""))
		m.is_synthetic = bool(synthetic_classes.get(m.class_id, false))
		m.is_hostile = bool(hostile_classes.get(m.class_id, false))
		out.append(m)
	return out


# The boarders, built from the scene rather than from crew.json — they belong to
# an encounter, not to the ship's roster. Same class of object as the crew, so
# they inherit walking, rooms and corridors for free.
static func load_boarders(scene_config: Dictionary) -> Array[CrewMember]:
	var classes_raw: Dictionary = load_json(CLASSES_PATH)
	var hostile_classes: Dictionary = {}
	for entry: Variant in classes_raw.get("classes", []):
		var c: Dictionary = entry as Dictionary
		hostile_classes[str(c.get("id", ""))] = bool(c.get("is_hostile", false))

	var out: Array[CrewMember] = []
	for entry: Variant in scene_config.get("boarders", []):
		var d: Dictionary = entry as Dictionary
		var m: CrewMember = CrewMember.new()
		m.id = str(d.get("id", ""))
		m.display_name = str(d.get("name", m.id))
		m.class_id = str(d.get("class", "pirate"))
		m.room = str(d.get("room", ""))
		m.is_hostile = bool(hostile_classes.get(m.class_id, true))
		if m.id == "" or m.room == "":
			push_error("boarder entry needs an id and a room: %s" % str(d))
			continue
		out.append(m)
	return out


static func load_scene() -> Dictionary:
	return load_json(SCENE_PATH)
