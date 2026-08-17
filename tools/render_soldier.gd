extends SceneTree
#
# Bakes the Silver Soldier into the crew sprite sheets the game already reads.
# Needs a display:
#
#   xvfb-run -a godot --script res://tools/render_soldier.gd -- --mode preview
#   xvfb-run -a godot --script res://tools/render_soldier.gd -- --mode angles
#   xvfb-run -a godot --script res://tools/render_soldier.gd -- --mode bake
#
# --mode angles is the one that settles arguments about the camera. It shoots
# the same figure down a list of pitches and prints the alpha bounding box of
# each, so CAMERA_SIZE and ShipView's CREW_ART_OFFSET can be set from measured
# numbers instead of guessed and re-guessed. --pitch and --size override the
# constants for a single run without editing the file.
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
# How far above the deck the camera sits, in degrees. 80 is a top-down read:
# helmet dome, shoulders, and enough arm and leg to see that a person is moving.
#
# This was 62 until 2026-08-17. 62 was chosen on the reasoning that "a pure
# overhead view of a human is a head and a pair of shoulders, which is the same
# blob the drawn version produced". Shot properly at `--mode angles --cell 190`
# that turns out to be wrong about 90 as well: the figure stays legible all the
# way up, because this model wears a helmet and carries a rifle and those two
# things alone give it a silhouette and a facing. Nothing became a blob.
#
# So the choice is taste, not legibility, and it is the owner's. What is not
# taste: at 62 the crew read as side-on figures standing on a top-down ship,
# which is the thing Void War does not do and the reason this changed.
#
# Change this number and re-bake. Everything below is tuned around it, and
# `--mode bake` will print the new CREW_ART_OFFSET for ui/ship_view.gd.
const CAMERA_PITCH: float = 80.0
const CAMERA_SIZE: float = 1.18
const AIM_HEIGHT: float = 0.46
const SETTLE: int = 2

# Must match CLIP_FRAMES in ui/ship_view.gd or the sheets are sliced wrongly.
const CLIPS: Dictionary = {"walk": 8, "idle": 4, "die": 6}

# The frame of his own animation used as the base pose — standing, rifle held
# across the body. Everything below is layered on top of this.
const CARRY_POSE_T: float = 0.0

# Walk shape, in degrees unless noted. Tuned at CAMERA_PITCH, in `--mode
# preview`, which is the only view that matters.
#
# Which of these does any work is decided by the camera, not by taste. A world
# displacement (dx, dy, dz) lands on the screen at (dx, dy·cos p − dz·sin p).
# At p = 80 that is: sideways 1.00, forwards 0.98, upwards 0.17. So from
# overhead, everything horizontal survives and everything vertical is gone.
#
# That is why this is not the old side-on stride with bigger numbers:
#   - knee lift and torso bob are vertical, so they are worth almost nothing.
#   - the torso hides the legs from above, so a stride is only visible if the
#     feet swing wide enough to clear the body's own outline.
#   - hip and shoulder counter-rotation is pure yaw, invisible from the side
#     and the single strongest "this is a person walking" cue from above.
const THIGH_SWING: float = 30.0
const KNEE_BEND: float = 26.0
const ANKLE: float = 8.0
const ARM_SWING: float = 19.0

# Outward, not forward. These push the elbows and the swinging foot past the
# silhouette of the torso so there is something to see at all.
const ARM_SPREAD: float = 8.0
const LEG_SPREAD: float = 5.5

# Counter-rotation about the spine: shoulders lead one way, hips the other.
const SHOULDER_YAW: float = 11.0
const HIP_YAW: float = 7.0

# Weight shifting over the stance foot, in model heights. Sideways, so it is the
# one whole-body movement the camera keeps at full value.
const BODY_SWAY: float = 0.028

# Kept small and deliberately near-useless at this pitch: the rise is along the
# camera axis. It is here so the walk does not fall apart if CAMERA_PITCH is
# ever lowered again.
const TORSO_BOB: float = 0.007
const TORSO_ROLL: float = 2.0

# Bone name fragments. Twist, share and scale-compensation helpers are excluded:
# driving those fights the real joint and shears the mesh.
#
# `pelvis` and `chest` are on separate branches of the rig — Hip forks into
# Pelvis (which owns the legs) and Waist → Spine (which owns the arms) — so
# yawing one against the other counter-rotates hips against shoulders without
# any of it leaking into the other half of the body.
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
	"pelvis": "CC_Base_Pelvis_06",
	"chest": "CC_Base_Spine02_038",
}

var _viewport: SubViewport = null
var _pivot: Node3D = null
var _instance: Node3D = null
var _skel: Skeleton3D = null
var _base: Dictionary = {}      # bone index -> Quaternion, the carry pose
var _axis: Dictionary = {}      # bone index -> Vector3, local axis for a pitch swing
var _bone: Dictionary = {}      # key -> bone index
var _ground: float = 0.0
var _pitch: float = CAMERA_PITCH
var _cam_size: float = CAMERA_SIZE
var _cell: int = CELL


func _init() -> void:
	var mode: String = _arg("--mode", "preview")
	var out: String = _arg("--out", "/tmp/soldier")
	_pitch = float(_arg("--pitch", str(CAMERA_PITCH)))
	_cam_size = float(_arg("--size", str(CAMERA_SIZE)))
	# The baked cell is 128 px, which is too small to judge a pose by eye. The
	# preview and contact-sheet modes are for a human to look at, so they can be
	# shot larger; --mode bake leaves this alone.
	_cell = int(_arg("--cell", str(CELL)))
	_build_rig()
	await _load_model()
	if _skel == null:
		printerr("no skeleton found in ", SRC)
		quit(1)
		return

	match mode:
		"bake": await _bake(out)
		"angles": await _angles(out)
		_: await _preview(out)
	quit(0)


# --- the walk ---------------------------------------------------------------

# One full stride is phase 0..1: left leg forward, pass, right leg forward, pass.
func _pose_walk(phase: float) -> void:
	_rest()
	var a: float = phase * TAU
	var swing_l: float = sin(a)
	var swing_r: float = sin(a + PI)

	# Legs swing fore-and-aft *and* out to the side. The splay is what makes the
	# stride visible at all from overhead — without it both feet stay inside the
	# torso's own outline for the whole cycle and the figure appears to skate.
	# It peaks on the forward swing, so the planted leg stays under the body.
	_bone_pose(
		"thigh_l",
		deg_to_rad(THIGH_SWING) * swing_l,
		0.0,
		deg_to_rad(LEG_SPREAD) * maxf(0.0, swing_l)
	)
	_bone_pose(
		"thigh_r",
		deg_to_rad(THIGH_SWING) * swing_r,
		0.0,
		-deg_to_rad(LEG_SPREAD) * maxf(0.0, swing_r)
	)

	# The knee only ever bends one way, and bends most as the leg swings through
	# under the body. A signed sine here would hyperextend it backwards, which
	# is the single most obvious way a hand-authored walk looks wrong.
	#
	# Smaller than it was side-on. Bending the knee mostly raises the foot, which
	# the camera throws away, while visibly shortening the leg on screen — so a
	# big bend reads from above as the leg retracting into the body.
	_bone_pose("calf_l", -deg_to_rad(KNEE_BEND) * maxf(0.0, sin(a - 0.7)), 0.0, 0.0)
	_bone_pose("calf_r", -deg_to_rad(KNEE_BEND) * maxf(0.0, sin(a + PI - 0.7)), 0.0, 0.0)

	# Ankles counter-rotate so the feet stay roughly level with the deck.
	_bone_pose("foot_l", -deg_to_rad(ANKLE) * swing_l, 0.0, 0.0)
	_bone_pose("foot_r", -deg_to_rad(ANKLE) * swing_r, 0.0, 0.0)

	# Arms swing against the legs, with the elbows carried outward so they break
	# the shoulder line. He is carrying a rifle two-handed, so the fore-aft part
	# stays modest — a full march swing would tear his hands off the grip.
	_bone_pose(
		"arm_l", deg_to_rad(ARM_SWING) * swing_r, 0.0, -deg_to_rad(ARM_SPREAD) * absf(swing_r)
	)
	_bone_pose(
		"arm_r", deg_to_rad(ARM_SWING) * swing_l, 0.0, deg_to_rad(ARM_SPREAD) * absf(swing_l)
	)

	# Hips and shoulders counter-rotate about the spine. Pure yaw: worth nothing
	# from the side, and from above it is most of what says "walking".
	_bone_pose("pelvis", 0.0, deg_to_rad(HIP_YAW) * swing_l, 0.0)
	_bone_pose("chest", 0.0, -deg_to_rad(SHOULDER_YAW) * swing_l, 0.0)
	_bone_pose("waist", 0.0, 0.0, deg_to_rad(TORSO_ROLL) * sin(a))

	# Weight rides over whichever foot is planted — sideways, so the camera keeps
	# it — and the body rises twice per stride, once over each leg, which it very
	# nearly does not.
	_instance.position.x = BODY_SWAY * sin(a)
	_instance.position.y = _ground + TORSO_BOB * absf(sin(a))


# Standing. Not frozen: a very small breath, because four identical frames of a
# man holding a rifle read as the game having stalled.
func _pose_idle(phase: float) -> void:
	_rest()
	var a: float = phase * TAU
	_bone_pose("arm_l", deg_to_rad(1.4) * sin(a), 0.0, 0.0)
	_bone_pose("arm_r", deg_to_rad(1.4) * sin(a), 0.0, 0.0)
	_bone_pose("waist", 0.0, 0.0, deg_to_rad(0.7) * sin(a))
	_instance.position.x = 0.0
	_instance.position.y = _ground + 0.004 * sin(a)


# Collapsing forwards. Not a real death animation — the model has none — but a
# body on the deck reads as a body on the deck, and the log says it in words.
#
# This is the one clip the new camera flatters. Seen from the side a fall is
# mostly downwards, which is the axis an overhead camera discards; seen from
# above it is a figure that stops being a compact silhouette and becomes a long
# shape lying across the deck. The fall twists as it goes so he lands on his
# side rather than face down, because face down from above is a backpack.
func _pose_die(t: float) -> void:
	_rest()
	var k: float = clampf(t, 0.0, 1.0)
	var fall: float = k * k
	_bone_pose("waist", deg_to_rad(70.0) * fall, deg_to_rad(28.0) * fall, 0.0)
	_bone_pose("pelvis", 0.0, deg_to_rad(18.0) * fall, 0.0)
	_bone_pose("thigh_l", deg_to_rad(-40.0) * fall, 0.0, deg_to_rad(16.0) * fall)
	_bone_pose("thigh_r", deg_to_rad(-25.0) * fall, 0.0, 0.0)
	_bone_pose("calf_l", -deg_to_rad(80.0) * fall, 0.0, 0.0)
	_bone_pose("calf_r", -deg_to_rad(60.0) * fall, 0.0, 0.0)
	_bone_pose("arm_l", deg_to_rad(35.0) * fall, 0.0, -deg_to_rad(22.0) * fall)
	_bone_pose("arm_r", deg_to_rad(25.0) * fall, 0.0, deg_to_rad(10.0) * fall)
	_instance.position.x = 0.0
	_instance.position.y = _ground - 0.30 * fall


# Puts every driven bone back to the carry pose. Each pose function starts here
# and then states only what it changes, so a bone left over from the previous
# frame can never leak into this one.
func _rest() -> void:
	for key: String in _bone.keys():
		var idx: int = int(_bone[key])
		if idx >= 0:
			_skel.set_bone_pose_rotation(idx, _base[idx] as Quaternion)


# Rotates a bone on top of the carry pose: `swing` fore-and-aft, `yaw` about the
# body's vertical, `roll` outward from the body's centre line.
#
# The axes are derived from each bone's own rest orientation rather than
# assumed. Character Creator bones do not share a convention — some point down
# the limb, some are mirrored — so hardcoding "rotate about local X" swings one
# leg forward and the other sideways. Converting a known world axis into each
# bone's local frame is the only version that works on both sides.
#
# All three compose in one call because the overhead walk needs two axes on the
# same bone at once — a thigh swings forward *and* splays outward — and two
# separate calls would have the second silently overwrite the first.
func _bone_pose(key: String, swing: float, yaw: float, roll: float) -> void:
	var idx: int = int(_bone.get(key, -1))
	if idx < 0:
		return
	var local: Basis = _skel.get_bone_global_rest(idx).basis.inverse()
	var q: Quaternion = _base[idx] as Quaternion
	if not is_zero_approx(swing):
		q *= Quaternion(_axis[idx] as Vector3, swing)
	if not is_zero_approx(yaw):
		q *= Quaternion((local * Vector3.UP).normalized(), yaw)
	if not is_zero_approx(roll):
		q *= Quaternion((local * Vector3.FORWARD).normalized(), roll)
	_skel.set_bone_pose_rotation(idx, q)


# --- rendering --------------------------------------------------------------

# Places the camera at `pitch` degrees above the deck, looking at the figure.
#
# look_at_from_position() rather than look_at(): the latter fails silently on a
# node that is not yet in the tree and leaves the camera pointing at the
# horizon. The aim point moves the body in frame the opposite way to intuition —
# aiming higher pushes the body down — and it has to fall as the camera rises,
# because from overhead the figure's centre of area is its chest, not its waist.
#
# At exactly 90 degrees the view direction is parallel to Vector3.UP and
# look_at() has no way to orient the roll — it errors and leaves the camera
# unrotated. Straight down is a legitimate thing to want to photograph, so the
# up vector switches to the world axis that still projects to "screen up".
func _aim(pitch_deg: float, size: float) -> void:
	var camera: Camera3D = _viewport.get_node("cam") as Camera3D
	var pitch: float = deg_to_rad(pitch_deg)
	camera.size = size
	var up: Vector3 = Vector3.UP if pitch_deg < 89.9 else Vector3.FORWARD
	camera.look_at_from_position(
		Vector3(0.0, sin(pitch) * 6.0, cos(pitch) * 6.0), Vector3(0.0, AIM_HEIGHT, 0.0), up
	)


# One contact sheet, one row per pitch, so the camera angle is chosen by looking
# at the figure rather than by reasoning about degrees. Prints the measured alpha
# bounding box of each row — that is what CAMERA_SIZE and CREW_ART_OFFSET are set
# from, and guessing them cost three re-renders the first time round.
func _angles(out: String) -> void:
	var pitches: PackedFloat32Array = PackedFloat32Array([62.0, 70.0, 76.0, 82.0, 90.0])
	var poses: int = 8
	var sheet: Image = Image.create(
		_cell * poses, _cell * pitches.size(), false, Image.FORMAT_RGBA8
	)

	for row: int in range(pitches.size()):
		_aim(pitches[row], _cam_size)
		var box: Rect2i = Rect2i()
		for i: int in range(poses):
			# Four facings standing, then four frames of the walk facing south —
			# the two questions are "is this a person?" and "is it moving?".
			if i < 4:
				_pivot.rotation.y = TAU * float(i) / 4.0
				_pose_idle(0.0)
			else:
				_pivot.rotation.y = 0.0
				_pose_walk(float(i - 4) / 4.0)
			var frame: Image = await _shot()
			box = _union(box, frame.get_used_rect())
			sheet.blit_rect(frame, Rect2i(0, 0, _cell, _cell), Vector2i(_cell * i, _cell * row))
		print(
			"pitch %5.1f  used rect y %3d..%3d (h %3d)  x %3d..%3d (w %3d)"
			% [
				pitches[row], box.position.y, box.end.y, box.size.y,
				box.position.x, box.end.x, box.size.x
			]
		)

	var path: String = "%s-angles.png" % out
	if sheet.save_png(path) == OK:
		print("wrote ", path)
	else:
		printerr("could not write ", path)


func _union(a: Rect2i, b: Rect2i) -> Rect2i:
	if a.size == Vector2i.ZERO:
		return b
	if b.size == Vector2i.ZERO:
		return a
	return a.merge(b)


# One stride, at the game's own camera, in the two facings that read most
# differently: walking towards the player and walking across the screen.
#
# The camera used to be dropped to 18 degrees here because "a walk is
# unreadable from directly above". That is how the walk got wonky. A stride
# tuned side-on and shipped overhead is tuned in a view no player ever has —
# from above, a leg swinging forward mostly moves *across* the screen and the
# knee lift disappears entirely. Judge it where it lands.
func _preview(out: String) -> void:
	_aim(_pitch, _cam_size)

	# The frames that actually ship, not a smoother sample of them. A stride that
	# only reads at 16 frames is not the stride the player sees.
	var n: int = int(CLIPS["walk"])
	var rows: PackedFloat32Array = PackedFloat32Array([0.0, 90.0])
	var sheet: Image = Image.create(_cell * n, _cell * rows.size(), false, Image.FORMAT_RGBA8)
	for row: int in range(rows.size()):
		_pivot.rotation.y = deg_to_rad(rows[row])
		for i: int in range(n):
			_pose_walk(float(i) / float(n))
			sheet.blit_rect(
				await _shot(), Rect2i(0, 0, _cell, _cell), Vector2i(_cell * i, _cell * row)
			)
	var path: String = "%s-walk-%d.png" % [out, int(round(_pitch))]
	sheet.save_png(path)
	print("wrote ", path)


func _bake(out: String) -> void:
	# Where the figure actually sits inside its cell, across every frame and
	# facing of the walk and idle clips. ShipView offsets the sprite by this, so
	# that crew stand on the point the simulation says they occupy instead of
	# beside it. It is printed rather than guessed because guessing it cost three
	# re-renders the first time, and it moves whenever CAMERA_PITCH does.
	#
	# `die` is excluded on purpose: a body on the deck is meant to lie off-centre.
	var stand: Rect2i = Rect2i()

	for clip: String in CLIPS.keys():
		var frames: int = int(CLIPS[clip])
		var sheet: Image = Image.create(_cell * frames, _cell * FACINGS, false, Image.FORMAT_RGBA8)
		for facing: int in range(FACINGS):
			_pivot.rotation.y = TAU * float(facing) / float(FACINGS)
			for f: int in range(frames):
				match clip:
					"walk": _pose_walk(float(f) / float(frames))
					"die": _pose_die(float(f) / float(maxi(frames - 1, 1)))
					_: _pose_idle(float(f) / float(frames))
				var frame: Image = await _shot()
				if clip != "die":
					stand = _union(stand, frame.get_used_rect())
				sheet.blit_rect(
					frame, Rect2i(0, 0, _cell, _cell), Vector2i(_cell * f, _cell * facing)
				)
		var path: String = "%s%s_%s.png" % [OUT_DIR, NAME, clip]
		if sheet.save_png(path) == OK:
			print("wrote %s  (%d frames x %d facings)" % [path, frames, FACINGS])
		else:
			printerr("could not write ", path)

	var centre: float = float(stand.position.y) + float(stand.size.y) * 0.5
	print(
		"figure occupies y %d..%d of %d; set ShipView.CREW_ART_OFFSET to %.1f"
		% [stand.position.y, stand.end.y, _cell, float(_cell) * 0.5 - centre]
	)


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
	_viewport.size = Vector2i(_cell, _cell)
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
	_viewport.add_child(camera)
	_aim(_pitch, _cam_size)

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
