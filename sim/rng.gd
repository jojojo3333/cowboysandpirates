extends RefCounted
class_name RunRng

# The only randomness in the project. Global randi() / randf()
# are forbidden, because a run seed must reproduce a run exactly or the headless
# harness cannot replay a failure.

var seed_value: int = 0

var _rng: RandomNumberGenerator = null


func _init(seed_in: int = 0) -> void:
	_rng = RandomNumberGenerator.new()
	if seed_in == 0:
		# Pick the seed first, then set it, so seed_value and the generator can
		# never disagree. randomize() alone leaves a 19-digit signed value that
		# is useless to read off a screen and retype into a bug report.
		var picker: RandomNumberGenerator = RandomNumberGenerator.new()
		picker.randomize()
		seed_value = picker.randi_range(100000, 999999)
	else:
		seed_value = seed_in
	_rng.seed = seed_value


func randi_range(from: int, to: int) -> int:
	return _rng.randi_range(from, to)


func randf() -> float:
	return _rng.randf()


func chance(probability: float) -> bool:
	return _rng.randf() < probability


func pick(options: Array) -> Variant:
	if options.is_empty():
		return null
	return options[_rng.randi_range(0, options.size() - 1)]
