extends SceneTree
#
# Renders the CC0 3D crew models down to 2D sprites. Needs a display:
#
#   xvfb-run -a godot --script res://tools/render_crew.gd
#
# This is the pipeline ASSETS.md described and nobody ran. The alternative was
# generating crew textures from pixel loops in GDScript, which produced ellipses
# with a lighter blob on them — the project owner's description was "polished
# dots", and that was accurate. A person is not a shape you can derive from two
# radii; it needs a model.
#
# The camera looks down at CAMERA_PITCH rather than straight down. A pure
# overhead view of a human is a head and a pair of shoulders and nothing else,
# which is exactly the blob the hand-drawn version produced. Tilting the camera
# keeps the top-down read while leaving enough of the body visible for the eye
# to recognise a person.
#
# No .tscn is created — the whole scene is built here at runtime, per rule 1.

const SRC_DIR: String = "res://tools/crew_src/"
const OUT_DIR: String = "res://assets/crew/"
const FRAME: int = 192
const CAMERA_PITCH: float = 62.0
const CAMERA_SIZE: float = 1.28
const SETTLE_FRAMES: int = 6

# Eight facings, so a crew member walking any direction has a frame that faces
# the way they are going.
const FACINGS: int = 8

var _models: Array[String] = [
	"character-male-a", "character-male-b", "character-male-c",
	"character-male-d", "character-male-e", "character-male-f",
	"character-female-a", "character-female-b", "character-female-c",
	"character-female-d", "character-female-e", "character-female-f",
]


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))

	var viewport: SubViewport = SubViewport.new()
	viewport.size = Vector2i(FRAME, FRAME)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.own_world_3d = true
	viewport.world_3d = World3D.new()
	root.add_child(viewport)

	var pivot: Node3D = Node3D.new()
	viewport.add_child(pivot)

	var camera: Camera3D = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = CAMERA_SIZE
	# Positioned on the pitch angle, looking back at the origin.
	var pitch: float = deg_to_rad(CAMERA_PITCH)
	viewport.add_child(camera)
	# look_at() requires the node to be in the tree first — called before
	# add_child it fails silently and leaves the camera unrotated, pointing at
	# the horizon instead of at the model.
	camera.look_at_from_position(
		Vector3(0.0, sin(pitch) * 6.0, cos(pitch) * 6.0),
		Vector3(0.0, 0.72, 0.0),
		Vector3.UP
	)

	# Key light from the same direction the ship plate is lit from, plus a dim
	# fill so the shadowed side does not go to pure black at 40 px.
	var key: DirectionalLight3D = DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-58.0, -34.0, 0.0)
	key.light_energy = 1.5
	viewport.add_child(key)

	var fill: DirectionalLight3D = DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20.0, 150.0, 0.0)
	fill.light_energy = 0.45
	fill.light_color = Color(0.72, 0.80, 0.95)
	viewport.add_child(fill)

	var env: WorldEnvironment = WorldEnvironment.new()
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.34, 0.36, 0.42)
	environment.ambient_light_energy = 1.0
	env.environment = environment
	viewport.add_child(env)

	var written: int = 0
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

		for facing: int in range(FACINGS):
			instance.rotation_degrees = Vector3(
				0.0, 360.0 * float(facing) / float(FACINGS), 0.0
			)
			for i: int in range(SETTLE_FRAMES):
				await process_frame

			var image: Image = viewport.get_texture().get_image()
			var out: String = "%s%s_%d.png" % [OUT_DIR, model_name, facing]
			var err: int = image.save_png(out)
			if err != OK:
				printerr("could not write ", out, " err ", err)
			else:
				written += 1

		instance.queue_free()
		await process_frame

	print("render_crew: wrote %d sprites to %s" % [written, OUT_DIR])
	quit(0)
