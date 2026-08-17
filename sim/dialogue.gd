extends RefCounted
class_name Dialogue

# A conversation: a list of lines, played one at a time.
#
# Headless, like everything in `sim/`. It knows who is speaking, what they say,
# how long the line holds and whether it has been skipped. It knows nothing
# about bubbles, panels, fonts or audio devices — `ui/dialogue_view.gd` reads
# this and draws it, and `verify.sh play` reads the same thing and asserts on it
# with no window open.
#
# A line is a dictionary:
#
#   {"id": "tock_boarded_01", "speaker": "TOCK", "actor": "tock",
#    "style": "comms", "text": "…", "seconds": 3.5, "audio": "…"}
#
#   id       stable name. Audio files and checks key off it, so it must not
#            change once a voice file has been recorded against it.
#   speaker  the name shown. Not necessarily a crew id — the captain is not
#            aboard as an actor.
#   actor    optional crew id. Present means "anchor this to that person";
#            absent means it has nowhere on the ship to point at.
#   style    "comms" for a panel, "bubble" for a speech bubble over `actor`.
#   seconds  how long it holds if nobody clicks.
#   audio    optional path. **Never load-bearing** — see below.
#
# **`seconds` is authoritative, not the audio.** A missing or unreadable sound
# file must leave the line playing as text for its written duration. A demo that
# stops because one `.ogg` failed to import is a demo that does not happen, and
# a sequence whose timing depends on a file the simulation cannot see could not
# be tested headlessly at all.

signal line_changed(line: Dictionary)
signal finished

var lines: Array = []
var playing: bool = false

# Whether the simulation should hold still while this plays. A cold open wants
# it; a line of banter during a firefight does not.
var pauses_simulation: bool = false

var _index: int = -1
var _elapsed: float = 0.0


static func from_config(config: Dictionary) -> Dialogue:
	var made: Dialogue = Dialogue.new()
	made.lines = (config.get("lines", []) as Array).duplicate(true)
	made.pauses_simulation = bool(config.get("pause_simulation", false))
	return made


func start() -> void:
	if lines.is_empty():
		playing = false
		finished.emit()
		return
	playing = true
	_index = -1
	_advance()


# The line on screen right now, or an empty dictionary between lines.
func current() -> Dictionary:
	if not playing or _index < 0 or _index >= lines.size():
		return {}
	return lines[_index] as Dictionary


func current_id() -> String:
	return str(current().get("id", ""))


# 0..1 through the current line, for anything that wants to show it.
func line_progress() -> float:
	var hold: float = float(current().get("seconds", 0.0))
	if hold <= 0.0:
		return 1.0
	return clampf(_elapsed / hold, 0.0, 1.0)


func tick(delta: float) -> void:
	if not playing:
		return
	_elapsed += delta
	if _elapsed >= float(current().get("seconds", 2.0)):
		_advance()


# The player clicked, or pressed space. Moves on immediately.
func advance() -> void:
	if playing:
		_advance()


# The player pressed escape. Ends the whole conversation at once.
#
# **Skipping must land in the same state as watching.** Nothing here changes the
# game, so that holds by construction — and it is why dialogue does not carry
# side effects. A line that freed a captive would make skipping and watching
# different games, and the first bug report would be from someone who skipped.
func skip() -> void:
	if not playing:
		return
	playing = false
	_index = lines.size()
	finished.emit()


func _advance() -> void:
	_index += 1
	_elapsed = 0.0
	if _index >= lines.size():
		playing = false
		finished.emit()
		return
	line_changed.emit(current())
