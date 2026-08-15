extends RefCounted
class_name LogEvent

# Structured, never a formatted string. GAME_SPEC_v0.2 §7a and
# VOICE_AND_EVENTS.md §6: ui/ turns these into text, and in v0.4 TOCK's bark
# system subscribes to the same stream. If sim/ emitted strings, adding that
# would mean rewriting every logging call site.

const NEUTRAL: String = "neutral"
const WARNING: String = "warning"
const CRITICAL: String = "critical"

var type: String = ""
var severity: String = NEUTRAL
var subjects: Array[String] = []
var values: Dictionary = {}
var t: float = 0.0


static func make(
	type_in: String,
	severity_in: String = NEUTRAL,
	subjects_in: Array[String] = [],
	values_in: Dictionary = {},
	t_in: float = 0.0
) -> LogEvent:
	var e: LogEvent = LogEvent.new()
	e.type = type_in
	e.severity = severity_in
	e.subjects = subjects_in.duplicate()
	e.values = values_in.duplicate()
	e.t = t_in
	return e
