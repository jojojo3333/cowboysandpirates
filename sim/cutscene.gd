extends RefCounted
class_name Cutscene

# A scripted sequence of things happening to actors, on the simulation's clock.
#
# This is what makes an in-engine cutscene possible: not a video, not a separate
# renderer, but the game moving its own people around its own ship while the
# player watches. What they see during the story is the same thing they will be
# looking at while they play, which is the whole argument for doing it this way.
#
# Headless, like everything in sim/. It issues orders and reads state; it draws
# nothing and knows about no node. That is what lets `verify.sh play` run a whole
# cutscene with no window open and assert who ended up where.
#
# A beat is a dictionary:
#
#   {"at": 0.0,  "actor": "pirate_1", "move_to": "quarters"}
#   {"at": 2.5,  "actors": ["pirate_3", "pirate_4"], "move_to": "cargo"}
#   {"at": 6.0,  "wait_until_still": true}
#
# `at` is seconds from the start of the cutscene. Beats fire in order and each
# fires once. `wait_until_still` holds the timeline — not the simulation —
# until nobody is walking, which is how "and then, once they have arrived…" is
# expressed without counting corridor lengths by hand.
#
# **Deliberately not a behaviour system.** Nothing here decides anything. A beat
# says what happens and when, and that is the entire vocabulary. Pirates that
# choose their own targets are a different feature with a different name, and
# building it accidentally inside this one would be the expensive mistake.

signal finished

var beats: Array = []
var playing: bool = false
var time: float = 0.0

var _next: int = 0
var _scene: RescueScene = null
var _holding: bool = false


var places: Dictionary = {}


# Built from one entry of `data/mission_01.json`'s `cutscenes` block.
static func from_config(scene: RescueScene, config: Dictionary) -> Cutscene:
	var made: Cutscene = Cutscene.new(scene, config.get("beats", []) as Array)
	made.places = (config.get("places", {}) as Dictionary).duplicate()
	return made


func _init(scene: RescueScene, beats_in: Array) -> void:
	_scene = scene
	beats = beats_in.duplicate(true)


# Puts actors where the cutscene needs them, which is not where the mission
# starts them. The pirates come aboard through the airlock; by the time the
# player has control they have spread out, and `data/scene_rescue.json` places
# them there. Staging teleports rather than walks — this is the cut before the
# scene, not part of it.
func stage() -> void:
	for actor_id: String in places:
		var m: CrewMember = _scene.get_crew(actor_id)
		if m == null:
			push_warning("cutscene stages unknown actor '%s'" % actor_id)
			continue
		m.stop_moving()
		m.room = str(places[actor_id])


func start() -> void:
	stage()
	playing = true
	time = 0.0
	_next = 0
	_holding = false


func stop() -> void:
	playing = false


# Advance the timeline. Called with the same delta the simulation gets, so a
# cutscene runs on game time and stops dead when the game is paused.
func tick(delta: float) -> void:
	if not playing:
		return

	# A hold does not advance the clock, or every beat after it would fire late
	# by however long the wait took.
	if _holding:
		if _scene.anyone_moving():
			return
		_holding = false

	time += delta

	while _next < beats.size():
		var beat: Dictionary = beats[_next] as Dictionary
		if float(beat.get("at", 0.0)) > time:
			break
		_next += 1
		if bool(beat.get("wait_until_still", false)):
			_holding = true
			return
		_fire(beat)

	if _next >= beats.size() and not _holding and not _scene.anyone_moving():
		playing = false
		finished.emit()


# Runs everything the beat asks for. Unknown keys are ignored rather than
# treated as errors, so a beat can carry notes for a human without breaking.
func _fire(beat: Dictionary) -> void:
	var who: Array[String] = _actors(beat)
	var destination: String = str(beat.get("move_to", ""))
	if destination != "" and not who.is_empty():
		# Straight to _order_move so a cutscene can move hostiles, who the
		# player is not allowed to command. The restriction on the player's side
		# lives in the UI, which is where it belongs.
		_scene.order_move(destination, who)


func _actors(beat: Dictionary) -> Array[String]:
	var out: Array[String] = []
	if beat.has("actor"):
		out.append(str(beat["actor"]))
	for a: Variant in beat.get("actors", []):
		out.append(str(a))
	return out


# How far through, 0..1, for anything that wants to show progress. Reaches 1.0
# only once every beat has fired and everyone has stopped walking.
func progress() -> float:
	if not playing:
		return 1.0
	if beats.is_empty():
		return 1.0
	var fired: float = clampf(float(_next) / float(beats.size()), 0.0, 1.0)
	# Every beat having fired is not the same as the scene being over — the last
	# one is usually people walking. Holding short of 1.0 until they stop keeps
	# a progress readout from claiming to be finished while it plainly is not.
	if fired >= 1.0 and (_holding or _scene.anyone_moving()):
		return 0.99
	return fired
