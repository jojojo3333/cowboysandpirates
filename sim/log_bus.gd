extends RefCounted
class_name LogBus

# Append-only stream of LogEvents. Consumers subscribe; none of them may mutate
# an event. The stream is the record of what happened.
#
# Consumers, in order of arrival:
#   ui/  log view          — formats to coloured text        (now)
#   tools/sim_runner.gd    — counts outcomes                 (slice 4)
#   bark system            — a subset, VOICE_AND_EVENTS §4   (v0.4)

signal event_appended(event: LogEvent)

var events: Array[LogEvent] = []


func append(event: LogEvent) -> void:
	events.append(event)
	event_appended.emit(event)


func emit_event(
	type: String,
	severity: String = LogEvent.NEUTRAL,
	subjects: Array[String] = [],
	values: Dictionary = {},
	t: float = 0.0
) -> void:
	append(LogEvent.make(type, severity, subjects, values, t))


func count_of_type(type: String) -> int:
	var n: int = 0
	for e: LogEvent in events:
		if e.type == type:
			n += 1
	return n


func has_type(type: String) -> bool:
	return count_of_type(type) > 0
