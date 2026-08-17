extends SceneTree
#
# Photographs a candidate crew model at the exact size and angle the game draws
# crew at, so a decision about art can be made by looking rather than by reading
# a description:
#
#   xvfb-run -a godot --script res://tools/preview_models.gd -- --out /tmp/cast
#
# Same camera, same lights, same cell size as tools/render_crew.gd. That is the
# whole point — a model that looks good in a modelling package and a model that
# reads at 66 px from 62 degrees above are different questions, and only the
# second one matters here.
#
# This renders a still per facing. It says nothing about whether a model can
# walk; for that it needs animation clips, which this also reports.

const CELL: int = 128
# Must match CAMERA_PITCH in tools/render_soldier.gd. The whole point of this
# script is judging a candidate model in the view the game actually uses, so a
# stale number here silently answers the wrong question.
const CAMERA_PITCH: float = 80.0
const CAMERA_SIZE: float = 1.18
const FACINGS: int = 8
const SETTLE_FRAMES: int = 3

var _viewport: SubViewport = null
var _pivot: Node3D = null


func _init() -> void:
	var out_prefix: String = _arg_str("--out", "/tmp/cast")
	_build_rig()

	for spec: String in [
		"res://assets/crew_src_modular/male.fbx",
		"res://assets/crew_src_modular/female.fbx",
		"res://tools/crew_src/character-male-a.glb",
	]:
		await _shoot(spec, out_prefix)

	quit(0)


func _build_rig() -> void:
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(CELL, CELL)
	_viewport.transparent_bg = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.own_world_3d = true
	_viewport.world_3d = World3D.new()
	root.add_child(_viewport)

	_pivot = Node3D.new()
	_viewport.add_child(_pivot)

	var camera: Camera3D = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = CAMERA_SIZE
	_viewport.add_child(camera)
	var pitch: float = deg_to_rad(CAMERA_PITCH)
	camera.look_at_from_position(
		Vector3(0.0, sin(pitch) * 6.0, cos(pitch) * 6.0),
		Vector3(0.0, 0.46, 0.0),
		Vector3.UP
	)

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


func _shoot(path: String, out_prefix: String) -> void:
	if not ResourceLoader.exists(path):
		printerr("missing: ", path)
		return
	var packed: PackedScene = load(path) as PackedScene
	if packed == null:
		printerr("could not load: ", path)
		return

	var instance: Node3D = packed.instantiate() as Node3D
	_pivot.add_child(instance)
	# get_global_transform() is only valid once the node is actually in the
	# tree. Measuring before this frame returns identity and the fit is wrong.
	await process_frame

	var label: String = path.get_file().get_basename()
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(instance, meshes)
	var names: PackedStringArray = PackedStringArray()
	for m: MeshInstance3D in meshes:
		names.append(m.name)

	var player: AnimationPlayer = _find_player(instance)
	var clips: PackedStringArray = (
		player.get_animation_list() if player != null else PackedStringArray()
	)

	print("%s: %d mesh part(s), %d animation clip(s)" % [label, meshes.size(), clips.size()])
	print("    parts: %s" % ", ".join(names))
	print("    clips: %s" % ("(none)" if clips.is_empty() else ", ".join(clips)))

	# The model is authored to whatever scale its source used. Fit it to the
	# same head-to-heel span the Kenney crew occupy, or a model in centimetres
	# renders as an empty frame and reads as "the import failed".
	_fit_height(instance, meshes)

	# Every mesh part ships in the same file, so showing them all at once puts
	# four suits of armour inside one body. Photograph the bare body and one
	# dressed variant instead — those are the two things worth judging.
	for variant: String in ["bare", "dressed"]:
		_show_variant(meshes, variant)
		var sheet: Image = Image.create(CELL * FACINGS, CELL, false, Image.FORMAT_RGBA8)
		for facing: int in range(FACINGS):
			_pivot.rotation.y = TAU * float(facing) / float(FACINGS)
			for i: int in range(SETTLE_FRAMES):
				await process_frame
			var frame: Image = _viewport.get_texture().get_image()
			sheet.blit_rect(frame, Rect2i(0, 0, CELL, CELL), Vector2i(CELL * facing, 0))
		var path_out: String = "%s-%s-%s.png" % [out_prefix, label, variant]
		if sheet.save_png(path_out) != OK:
			printerr("could not write ", path_out)

	instance.queue_free()
	await process_frame


# "bare" is the plain body with no armour on it; "dressed" adds the first
# armour, boots and bracers found. Body_forArmor* are cut-down bodies meant to
# sit under a suit, so they are hidden unless that suit is on.
func _show_variant(meshes: Array[MeshInstance3D], variant: String) -> void:
	var worn: Dictionary = {}
	for m: MeshInstance3D in meshes:
		var n: String = m.name.to_lower()
		var is_body: bool = n.begins_with("body")
		var is_cut_body: bool = n.begins_with("body_for")
		if variant == "bare":
			m.visible = is_body and not is_cut_body
			continue
		# One item per slot, or every suit is worn at once.
		var slot: String = ""
		if n.contains("armor"):
			slot = "armor"
		elif n.contains("boots"):
			slot = "boots"
		elif n.contains("bracers"):
			slot = "bracers"
		if slot == "":
			m.visible = is_cut_body and n.contains("armorandboots")
			continue
		m.visible = not worn.has(slot)
		worn[slot] = true


# Scales the model so it stands about 1.0 unit tall, which is where the camera
# is aimed.
func _fit_height(instance: Node3D, meshes: Array[MeshInstance3D]) -> void:
	var lo: float = INF
	var hi: float = -INF
	for m: MeshInstance3D in meshes:
		if m.mesh == null:
			continue
		var box: AABB = m.get_global_transform() * m.mesh.get_aabb()
		lo = minf(lo, box.position.y)
		hi = maxf(hi, box.position.y + box.size.y)
	var height: float = hi - lo
	if height <= 0.0 or not is_finite(height):
		return
	var factor: float = 1.0 / height
	instance.scale = Vector3(factor, factor, factor)
	instance.position.y = -lo * factor


func _collect_meshes(node: Node, out: Array[MeshInstance3D]) -> void:
	var mesh: MeshInstance3D = node as MeshInstance3D
	if mesh != null:
		out.append(mesh)
	for child: Node in node.get_children():
		_collect_meshes(child, out)


func _find_player(node: Node) -> AnimationPlayer:
	var player: AnimationPlayer = node as AnimationPlayer
	if player != null:
		return player
	for child: Node in node.get_children():
		var found: AnimationPlayer = _find_player(child)
		if found != null:
			return found
	return null


func _arg_str(flag: String, fallback: String) -> String:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for i: int in range(args.size()):
		if args[i] == flag and i + 1 < args.size():
			return args[i + 1]
		if args[i].begins_with(flag + "="):
			return args[i].split("=", true, 1)[1]
	return fallback
