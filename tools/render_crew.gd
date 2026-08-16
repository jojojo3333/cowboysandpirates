extends SceneTree
#
# Renders the CC0 3D crew models down to 2D sprite sheets. Needs a display:
#
#   xvfb-run -a godot --script res://tools/render_crew.gd
#
# The Kenney Mini Characters are rigged and ship with a full animation set —
# walk, idle, die, holding-right, interact and more. That was worth checking
# before faking anything: the first version of this script rendered one static
# pose per facing and the "walk" was a sine bob applied to it in ShipView. These
# are real cycles.
#
# Output is one sheet per model per animation, laid out as a grid:
#
#   columns = animation frames, rows = facings
#
# so a Sprite2D can use hframes/vframes and pick a cell with `frame`. One file
# per animation beats several hundred loose PNGs for both import time and for
# anyone reading the directory.
#
# The camera looks down at CAMERA_PITCH rather than straight down. A pure
# overhead view of a human is a head and a pair of shoulders and nothing else,
# which is exactly the blob an earlier hand-drawn version produced. The tilt
# keeps the top-down read while leaving enough body to recognise a person.
#
# No .tscn is created — the whole scene is built here at runtime, per rule 1.

const SRC_DIR: String = "res://tools/crew_src/"
const OUT_DIR: String = "res://assets/crew/"
const CELL: int = 128
const CAMERA_PITCH: float = 62.0
const CAMERA_SIZE: float = 1.18
const SETTLE_FRAMES: int = 3
const FACINGS: int = 8

# name -> frames sampled evenly across the clip. Walk gets eight; below about
# six the cycle reads as a stutter rather than as steps.
const CLIPS: Dictionary = {
	"walk": 8,
	"idle": 4,
	"die": 6,
}

var _models: Array[String] = [
	"character-male-a", "character-female-b", "character-male-d",
	"character-female-e", "character-male-c", "character-female-a",
	"character-male-f", "character-male-e",
]

var _viewport: SubViewport = null


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))

	_viewport = SubViewport.new()
	_viewport.size = Vector2i(CELL, CELL)
	_viewport.transparent_bg = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.own_world_3d = true
	_viewport.world_3d = World3D.new()
	root.add_child(_viewport)

	var pivot: Node3D = Node3D.new()
	_viewport.add_child(pivot)

	var camera: Camera3D = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = CAMERA_SIZE
	_viewport.add_child(camera)
	# look_at() fails silently on a node that is not yet in the tree, leaving the
	# camera unrotated and pointing at the horizon. Add first, then aim.
	var pitch: float = deg_to_rad(CAMERA_PITCH)
	camera.look_at_from_position(
		Vector3(0.0, sin(pitch) * 6.0, cos(pitch) * 6.0),
		Vector3(0.0, 0.46, 0.0),
		Vector3.UP
	)

	# Key light from roughly where the ship plate is lit from, plus a cool fill
	# so the shadow side does not go to solid black at 40 px on screen.
	var key: DirectionalLight3D = DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-58.0, -34.0, 0.0)
	key.light_energy = 1.5
	_viewport.add_child(key)

	var fill: DirectionalLight3D = DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20.0, 150.0, 0.0)
	fill.light_energy = 0.45
	fill.light_color = Color(0.72, 0.80, 0.95)
	_viewport.add_child(fill)

	var env: WorldEnvironment = WorldEnvironment.new()
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.34, 0.36, 0.42)
	environment.ambient_light_energy = 1.0
	env.environment = environment
	_viewport.add_child(env)

	var sheets: int = 0
	for model_name: String in _models:
		var path: String = SRC_DIR + model_name + ".glb"
		if not ResourceLoader.exists(path):
			printerr("missing model: ", path)
			continue
		var packed: PackedScene = load(path) as PackedScene
		if packed == null:
			printerr("could not load: ", path)
			continue

		var instance: Node3D = packed.instantiate() as Node3D
		pivot.add_child(instance)

		var player: AnimationPlayer = _find_player(instance)
		if player == null:
			printerr("no AnimationPlayer in ", model_name)
			instance.queue_free()
			continue

		for clip: String in CLIPS.keys():
			if not player.has_animation(clip):
				printerr(model_name, " has no clip '", clip, "'")
				continue
			var frames: int = int(CLIPS[clip])
			var sheet: Image = await _render_sheet(instance, player, clip, frames)
			var out: String = "%s%s_%s.png" % [OUT_DIR, model_name, clip]
			if sheet.save_png(out) == OK:
				sheets += 1
			else:
				printerr("could not write ", out)

		instance.queue_free()
		await process_frame

	print("render_crew: wrote %d sheets to %s" % [sheets, OUT_DIR])
	quit(0)


func _find_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child: Node in node.get_children():
		var found: AnimationPlayer = _find_player(child)
		if found != null:
			return found
	return null


# One image, frames across and facings down.
func _render_sheet(
	instance: Node3D, player: AnimationPlayer, clip: String, frames: int
) -> Image:
	var sheet: Image = Image.create(
		CELL * frames, CELL * FACINGS, false, Image.FORMAT_RGBA8
	)
	var length: float = player.get_animation(clip).length

	player.play(clip)
	player.pause()

	for facing: int in range(FACINGS):
		instance.rotation_degrees = Vector3(
			0.0, 360.0 * float(facing) / float(FACINGS), 0.0
		)
		for f: int in range(frames):
			# Sampled across the clip rather than played, so the sheet is the
			# same on every machine regardless of frame rate. seek(.., true)
			# applies the pose immediately instead of on the next tick.
			player.seek(length * float(f) / float(frames), true)
			for i: int in range(SETTLE_FRAMES):
				await process_frame

			var cell: Image = _viewport.get_texture().get_image()
			sheet.blit_rect(
				cell, Rect2i(0, 0, CELL, CELL), Vector2i(CELL * f, CELL * facing)
			)

	return sheet
