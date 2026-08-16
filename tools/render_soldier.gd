extends SceneTree
#
# Bakes the Silver Soldier into the crew sprite sheets the game already reads.
# Needs a display:
#
#   xvfb-run -a godot --script res://tools/render_soldier.gd -- --mode preview
#   xvfb-run -a godot --script res://tools/render_soldier.gd -- --mode bake
#
# Why this exists rather than just playing the model's animation.
#
# The GLB ships one 12.72 s clip called FBXExportClip_0, and it is not a walk.
# Measured: three bursts of motion at 0.3-2.1 s, 5.6-6.8 s and 10.7-12.6 s with
# long holds between them, and the two thighs peak 0.08 s apart rather than half
# a stride apart. He raises a weapon, aims, and lowers it. His feet never leave
# the floor. Sampling frames out of that clip and calling it a walk produces a
# man sliding through the ship while fidgeting, which is worse than a static
# pose because it looks like a bug rather than a placeholder.
#
# What the model does have is an excellent rig: 211 bones on a standard
# Character Creator skeleton with predictable names. So the walk is authored
# here, on his own bones. Real hips, knees and arms, not a sine bob applied to a
# flat sprite — that shortcut was tried early in this project and replaced for
# good reason.
#
# The carry pose comes from his own clip so he keeps hold of the rifle; the walk
# is layered on top of it.

const SRC: String = "res://tools/crew_src/silver_soldier_animated.glb"
const OUT_DIR: String = "res://assets/crew/"
const NAME: String = "soldier"

const CELL: int = 128
const FACINGS: int = 8
const CAMERA_PITCH: float = 62.0
const CAMERA_SIZE: float = 1.18
const SETTLE: int = 2

# Must match CLIP_FRAMES in ui/ship_view.gd or the sheets are sliced wrongly.
const CLIPS: Dictionary = {"walk": 8, "idle": 4, "die": 6}

# The frame of his own animation used as the base pose — standing, rifle held
# across the body. Everything below is layered on top of this.
const CARRY_POSE_T: float = 0.0

# Walk shape, in degrees. Tuned by looking at the side-on preview, which is the
# only way to get these right.
const THIGH_SWING: float = 26.0
const KNEE_BEND: float = 42.0
const ANKLE: float = 10.0
const ARM_SWING: float = 15.0
const TORSO_BOB: float = 0.016
const TORSO_ROLL: float = 3.0

# Bone name fragments. Twist, share and scale-compensation helpers are excluded:
# driving those fights the real joint and shears the mesh.
const BONES: Dictionary = {
	"thigh_l": "CC_Base_L_Thigh_00",
	"thigh_r": "CC_Base_R_Thigh_021",
	"calf_l": "CC_Base_L_Calf_07",
	"calf_r": "CC_Base_R_Calf_024",
	"foot_l": "CC_Base_L_Foot_08",
	"foot_r": "CC_Base_R_Foot_025",
	"arm_l": "CC_Base_L_Upperarm_055",
	"arm_r": "CC_Base_R_Upperarm_081",
	"waist": "CC_Base_Waist_036",
}

var _viewport: SubViewport = null
var _pivot: Node3D = null
var _instance: Node3D = null
var _skel: Skeleton3D = null
var _base: Dictionary = {}      # bone index -> Quaternion, the carry pose
var _axis: Dictionary = {}      # bone index -> Vector3, local axis for a pitch swing
var _bone: Dictionary = {}      # key -> bone index
var _ground: float = 0.0


func _init() -> void:
	var mode: String = _arg("--mode", "preview")
	var out: String = _arg("--out", "/tmp/soldier")
	_build_rig()
	await _load_model()
	if _skel == null:
		printerr("no skeleton found in ", SRC)
		quit(1)
		return

	if mode == "bake":
		await _bake(out)
	else:
		await _preview(out)
	quit(0)


# --- the walk ---------------------------------------------------------------

# One full stride is phase 0..1: left leg forward, pass, right leg forward, pass.
func _pose_walk(phase: float) -> void:
	var a: float = phase * TAU
	var swing_l: float = sin(a)
	var swing_r: float = sin(a + PI)

	_swing(_bone["thigh_l"], deg_to_rad(THIGH_SWING) * swing_l)
	_swing(_bone["thigh_r"], deg_to_rad(THIGH_SWING) * swing_r)

	# The knee only ever bends one way, and bends most as the leg swings through
	# under the body. A signed sine here would hyperextend it backwards, which
	# is the single most obvious way a hand-authored walk looks wrong.
	_swing(_bone["calf_l"], -deg_to_rad(KNEE_BEND) * maxf(0.0, sin(a - 0.7)))
	_swing(_bone["calf_r"], -deg_to_rad(KNEE_BEND) * maxf(0.0, sin(a + PI - 0.7)))

	# Ankles counter-rotate so the feet stay roughly level with the deck.
	_swing(_bone["foot_l"], -deg_to_rad(ANKLE) * swing_l)
	_swing(_bone["foot_r"], -deg_to_rad(ANKLE) * swing_r)

	# Arms swing against the legs. He is carrying a rifle two-handed, so this is
	# deliberately small — a full march swing would tear his hands off the grip.
	_swing(_bone["arm_l"], deg_to_rad(ARM_SWING) * swing_r)
	_swing(_bone["arm_r"], deg_to_rad(ARM_SWING) * swing_l)
	_roll(_bone["waist"], deg_to_rad(TORSO_ROLL) * sin(a))

	# The body rises twice per stride, once over each leg.
	_instance.position.y = _ground + TORSO_BOB * absf(sin(a))


# Standing. Not frozen: a very small breath, because four identical frames of a
# man holding a rifle read as the game having stalled.
func _pose_idle(phase: float) -> void:
	var a: float = phase * TAU
	for key: String in _bone.keys():
		_swing(_bone[key], 0.0)
	_swing(_bone["arm_l"], deg_to_rad(1.4) * sin(a))
	_swing(_bone["arm_r"], deg_to_rad(1.4) * sin(a))
	_roll(_bone["waist"], deg_to_rad(0.7) * sin(a))
	_instance.position.y = _ground + 0.004 * sin(a)


# Collapsing forwards. Not a real death animation — the model has none — but a
# body on the deck reads as a body on the deck, and the log says it in words.
func _pose_die(t: float) -> void:
	var k: float = clampf(t, 0.0, 1.0)
	var fall: float = k * k
	_swing(_bone["waist"], deg_to_rad(70.0) * fall)
	_swing(_bone["thigh_l"], deg_to_rad(-40.0) * fall)
	_swing(_bone["thigh_r"], deg_to_rad(-25.0) * fall)
	_swing(_bone["calf_l"], -deg_to_rad(80.0) * fall)
	_swing(_bone["calf_r"], -deg_to_rad(60.0) * fall)
	_swing(_bone["arm_l"], deg_to_rad(35.0) * fall)
	_swing(_bone["arm_r"], deg_to_rad(25.0) * fall)
	_instance.position.y = _ground - 0.30 * fall


# Rotates a bone by `angle` about the character's left-right axis, on top of the
# carry pose.
#
# The axis is derived from the bone's own rest orientation rather than assumed.
# Character Creator bones do not share a convention — some point down the limb,
# some are mirrored — so hardcoding "rotate about local X" swings one leg
# forward and the other sideways. Converting a known world axis into each bone's
# local frame is the only version that works on both sides.
func _swing(idx: int, angle: float) -> void:
	if idx < 0:
		return
	_skel.set_bone_pose_rotation(idx, (_base[idx] as Quaternion) * Quaternion(_axis[idx] as Vector3, angle))


func _roll(idx: int, angle: float) -> void:
	if idx < 0:
		return
	var forward: Vector3 = (_skel.get_bone_global_rest(idx).basis.inverse() * Vector3.FORWARD).normalized()
	_skel.set_bone_pose_rotation(idx, (_base[idx] as Quaternion) * Quaternion(forward, angle))


# --- rendering --------------------------------------------------------------

func _preview(out: String) -> void:
	# Side on, because a walk is unreadable from directly above and this frame
	# is for a human to judge, not for the game.
	var cam: Camera3D = _viewport.get_node("cam") as Camera3D
	var pitch: float = deg_to_rad(18.0)
	cam.look_at_from_position(
		Vector3(0.0, sin(pitch) * 6.0, cos(pitch) * 6.0), Vector3(0.0, 0.5, 0.0), Vector3.UP
	)
	_pivot.rotation.y = deg_to_rad(90.0)

	var n: int = 16
	var sheet: Image = Image.create(CELL * n, CELL, false, Image.FORMAT_RGBA8)
	for i: int in range(n):
		_pose_walk(float(i) / float(n))
		sheet.blit_rect(await _shot(), Rect2i(0, 0, CELL, CELL), Vector2i(CELL * i, 0))
	sheet.save_png("%s-walk-side.png" % out)
	print("wrote %s-walk-side.png" % out)


func _bake(out: String) -> void:
	for clip: String in CLIPS.keys():
		var frames: int = int(CLIPS[clip])
		var sheet: Image = Image.create(CELL * frames, CELL * FACINGS, false, Image.FORMAT_RGBA8)
		for facing: int in range(FACINGS):
			_pivot.rotation.y = TAU * float(facing) / float(FACINGS)
			for f: int in range(frames):
				match clip:
					"walk": _pose_walk(float(f) / float(frames))
					"die": _pose_die(float(f) / float(maxi(frames - 1, 1)))
					_: _pose_idle(float(f) / float(frames))
				sheet.blit_rect(
					await _shot(), Rect2i(0, 0, CELL, CELL), Vector2i(CELL * f, CELL * facing)
				)
		var path: String = "%s%s_%s.png" % [OUT_DIR, NAME, clip]
		if sheet.save_png(path) == OK:
			print("wrote %s  (%d frames x %d facings)" % [path, frames, FACINGS])
		else:
			printerr("could not write ", path)


func _shot() -> Image:
	for i: int in range(SETTLE):
		await process_frame
	return _viewport.get_texture().get_image()


func _load_model() -> void:
	var packed: PackedScene = load(SRC) as PackedScene
	if packed == null:
		printerr("could not load ", SRC)
		return
	_instance = packed.instantiate() as Node3D
	_pivot.add_child(_instance)
	await process_frame

	var skels: Array[Skeleton3D] = []
	_find_skeletons(_instance, skels)
	for s: Skeleton3D in skels:
		if _skel == null or s.get_bone_count() > _skel.get_bone_count():
			_skel = s
	if _skel == null:
		return

	# Take the carry pose out of his own clip, then stop the player so it cannot
	# fight the authored pose on later frames.
	var player: AnimationPlayer = _find_player(_instance)
	if player != null and not player.get_animation_list().is_empty():
		var clip: String = player.get_animation_list()[0]
		player.play(clip)
		player.seek(CARRY_POSE_T, true)
		player.advance(0.0)
		await process_frame
		player.stop()
		player.active = false

	for key: String in BONES.keys():
		var idx: int = _skel.find_bone(str(BONES[key]))
		_bone[key] = idx
		if idx < 0:
			push_warning("bone not found: %s" % str(BONES[key]))
			continue
		_base[idx] = _skel.get_bone_pose_rotation(idx)
		_axis[idx] = (_skel.get_bone_global_rest(idx).basis.inverse() * Vector3.RIGHT).normalized()

	_fit_height()


# Scales the figure to stand one unit tall on the origin, so a model authored in
# centimetres does not render as an empty frame.
func _fit_height() -> void:
	var lo: float = INF
	var hi: float = -INF
	for m: MeshInstance3D in _meshes(_instance):
		var box: AABB = m.get_global_transform() * m.mesh.get_aabb()
		lo = minf(lo, box.position.y)
		hi = maxf(hi, box.position.y + box.size.y)
	var height: float = hi - lo
	if height <= 0.0 or not is_finite(height):
		return
	var factor: float = 1.0 / height
	_instance.scale = Vector3(factor, factor, factor)
	_ground = -lo * factor
	_instance.position.y = _ground


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
	camera.name = "cam"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = CAMERA_SIZE
	_viewport.add_child(camera)
	var pitch: float = deg_to_rad(CAMERA_PITCH)
	camera.look_at_from_position(
		Vector3(0.0, sin(pitch) * 6.0, cos(pitch) * 6.0), Vector3(0.0, 0.46, 0.0), Vector3.UP
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


func _find_skeletons(node: Node, out: Array[Skeleton3D]) -> void:
	var s: Skeleton3D = node as Skeleton3D
	if s != null:
		out.append(s)
	for child: Node in node.get_children():
		_find_skeletons(child, out)


func _find_player(node: Node) -> AnimationPlayer:
	var p: AnimationPlayer = node as AnimationPlayer
	if p != null:
		return p
	for child: Node in node.get_children():
		var found: AnimationPlayer = _find_player(child)
		if found != null:
			return found
	return null


func _meshes(node: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	var m: MeshInstance3D = node as MeshInstance3D
	if m != null and m.mesh != null:
		out.append(m)
	for child: Node in node.get_children():
		out.append_array(_meshes(child))
	return out


func _arg(flag: String, fallback: String) -> String:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for i: int in range(args.size()):
		if args[i] == flag and i + 1 < args.size():
			return args[i + 1]
		if args[i].begins_with(flag + "="):
			return args[i].split("=", true, 1)[1]
	return fallback
