extends SceneTree
#
# Renders main.tscn offscreen and writes PNGs. Needs a display, so under CI:
#
#   xvfb-run -a godot --script res://tools/screenshot.gd -- --out /tmp/shot
#
# This exists to catch "the game runs but the screen is empty" — a layout bug
# that no headless boot check can see, and which CLAUDE.md names the number one
# cause of that symptom. It proves pixels were drawn.
#
# It cannot tell you whether anything feels good. Nothing in a GPU-less
# container can. Do not use it for that.

const SETTLE_FRAMES: int = 12


func _init() -> void:
	var out_prefix: String = _arg_str("--out", "/tmp/deadweight")

	var packed: PackedScene = load("res://main.tscn") as PackedScene
	if packed == null:
		printerr("could not load res://main.tscn")
		quit(1)
		return

	var main: Node = packed.instantiate()
	root.add_child(main)
	await _settle()

	await _shot(out_prefix + "-1-proposal.png")

	# Drive the simulation directly, exactly as the UI buttons do.
	var sim: RescueScene = main.get("scene") as RescueScene
	if sim == null:
		printerr("main.gd exposes no scene")
		quit(1)
		return

	sim.choose_plan("fight")
	await _settle()
	await _shot(out_prefix + "-2-plan-chosen.png")

	# Catch a frame mid-corridor. Transit is the one thing a post-arrival
	# screenshot can never show, and it is the whole point of the drawn view.
	sim.order_move("shields")
	await _run_seconds(sim, 1.5)
	await _shot(out_prefix + "-2b-walking.png")
	await _run_seconds(sim, 1.7)

	# Then one order for the whole remaining route, the way a player gives it.
	sim.order_move("cargo")
	await _run_seconds(sim, 7.0)
	await _shot(out_prefix + "-3-in-the-hold.png")

	for m: CrewMember in sim.crew:
		if m.is_tied():
			sim.order_free(m.id)
			break
	await _run_seconds(sim, 14.0)
	await _shot(out_prefix + "-4-firefight.png")

	quit(0)



func _run_seconds(sim: RescueScene, seconds: float) -> void:
	var ticks: int = int(seconds * 20.0)
	for i: int in range(ticks):
		sim.tick(1.0 / 20.0)
	await _settle()


func _settle() -> void:
	for i: int in range(SETTLE_FRAMES):
		await process_frame


func _shot(path: String) -> void:
	await process_frame
	var image: Image = root.get_texture().get_image()
	var err: int = image.save_png(path)
	if err != OK:
		printerr("could not write %s (error %d)" % [path, err])
		return
	print("wrote %s  %dx%d" % [path, image.get_width(), image.get_height()])


func _arg_str(flag: String, fallback: String) -> String:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for i: int in range(args.size()):
		if args[i] == flag and i + 1 < args.size():
			return args[i + 1]
		if args[i].begins_with(flag + "="):
			return args[i].split("=", true, 1)[1]
	return fallback
