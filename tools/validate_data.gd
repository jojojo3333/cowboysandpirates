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
	if crew != null:
		_check_crew(crew, class_ids)

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


func _check_crew(data: Variant, class_ids: Array) -> void:
	if not (data is Dictionary) or not (data as Dictionary).has("crew"):
		errors.append("crew.json: missing top-level 'crew' array")
		return

	var dict: Dictionary = data as Dictionary
	var ids: Array = []
	var commanders: int = 0
	var required: Array[String] = ["id", "name", "class", "starting_room"]

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
