extends SceneTree
#
# Renders a crew member's whole walk as a numbered PNG sequence, for assembling
# into a GIF:
#
#   xvfb-run -a godot --script res://tools/walk_frames.gd -- --out /tmp/walk
#
# The corridor route is a geometry change, and geometry is exactly the kind of
# thing that looks correct in the numbers and wrong on the screen. A crew member
# clipping a bulkhead is obvious in three frames of a GIF and invisible in a
# balance report, so this walks TOCK the length of the ship and photographs
# every step of it.
#
# Throwaway in spirit but kept in tools/: the next layout change needs it too.
#
# This still cannot tell you whether anything feels good. Nothing in a GPU-less
# container can — CLAUDE.md. It can only tell you where the crew are.

const SETTLE_FRAMES: int = 8
const STEP_SECONDS: float = 0.20


func _init() -> void:
	var out_prefix: String = _arg_str("--out", "/tmp/walk")
	var destination: String = _arg_str("--to", "cargo")
	var max_seconds: float = float(_arg_str("--seconds", "40"))

	var packed: PackedScene = load("res://rescue_scene.tscn") as PackedScene
	if packed == null:
		printerr("could not load res://rescue_scene.tscn")
		quit(1)
		return

	var main: Node = packed.instantiate()
	root.add_child(main)
	await _settle()

	var sim: RescueScene = main.get("scene") as RescueScene
	if sim == null:
		printerr("main.gd exposes no scene")
		quit(1)
		return

	sim.choose_plan("hack")
	await _settle()

	if not sim.order_move(destination):
		printerr("order_move('%s') refused" % destination)
		quit(1)
		return
	print("route: %s" % str(sim.route))

	var frame: int = 0
	var elapsed: float = 0.0
	while sim.task == RescueScene.Task.TRANSIT and elapsed < max_seconds:
		await _shot("%s-%03d.png" % [out_prefix, frame])
		frame += 1
		var ticks: int = int(STEP_SECONDS * 20.0)
		for i: int in range(ticks):
			sim.tick(1.0 / 20.0)
		elapsed += STEP_SECONDS
		await process_frame

	await _settle()
	await _shot("%s-%03d.png" % [out_prefix, frame])
	print("wrote %d frames, TOCK is in '%s'" % [frame + 1, sim.tock.room])
	quit(0)


func _settle() -> void:
	for i: int in range(SETTLE_FRAMES):
		await process_frame


func _shot(path: String) -> void:
	await process_frame
	var image: Image = root.get_texture().get_image()
	var err: int = image.save_png(path)
	if err != OK:
		printerr("could not write %s (error %d)" % [path, err])


func _arg_str(flag: String, fallback: String) -> String:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for i: int in range(args.size()):
		if args[i] == flag and i + 1 < args.size():
			return args[i + 1]
		if args[i].begins_with(flag + "="):
			return args[i].split("=", true, 1)[1]
	return fallback
