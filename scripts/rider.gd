class_name Skater
extends Node3D

const MODELS: Dictionary = {
	"torso": preload("res://assets/models/rider_torso.glb"),
	"pelvis": preload("res://assets/models/rider_pelvis.glb"),
	"head": preload("res://assets/models/rider_head.glb"),
	"upper_arm": preload("res://assets/models/rider_upper_arm.glb"),
	"forearm": preload("res://assets/models/rider_forearm.glb"),
	"thigh": preload("res://assets/models/rider_thigh.glb"),
	"shin": preload("res://assets/models/rider_shin.glb"),
	"board": preload("res://assets/models/skateboard.glb")
}
const HAT_PATHS: Array[String] = ["res://assets/models/hat_clockwork.glb", "res://assets/models/hat_crane.glb", "res://assets/models/hat_cone.glb"]
var visuals: Dictionary = {}
var limbs: Array[RagdollLimb] = []
var joints: Array[Joint3D] = []
var ragdoll: bool = false
var bail_frames: Dictionary = {}
var bail_anchors: Dictionary = {}
var torso: RagdollLimb
var game: Node
var pose: float = 0.0
var skin: RiderSkin
var riding_push_phase: float = -1.0
var foot_contacts: Dictionary = {}
var pose_index: int = 0
var hat_index: int = 0
var body_parts: Dictionary = {}
var damage_states: Dictionary = {}
var damage_materials: Dictionary = {}
var damage_patches: Dictionary = {}
var pose_anchors: Dictionary = {}
var offsets: Dictionary = {
	"torso": Vector3(0, 1.35, 0), "pelvis": Vector3(0, 0.90, 0), "head": Vector3(0, 1.99, 0.0),
	"arm_l": Vector3(-0.44,1.34,0), "arm_r": Vector3(0.44,1.34,0),
	"fore_l": Vector3(-0.52,1.01,0.08), "fore_r": Vector3(0.52,1.01,0.08),
	"thigh_l": Vector3(-0.18,0.61,-0.10), "thigh_r": Vector3(0.18,0.61,0.13),
	"shin_l": Vector3(-0.18,0.23,-0.10), "shin_r": Vector3(0.18,0.23,0.13),
	"board": Vector3(0,0.04,0)
}

func _ready() -> void:
	for key in offsets:
		var model: Node3D = MODELS[model_key(key)].instantiate()
		add_child(model)
		model.position = offsets[key]
		visuals[key] = model
	skin = RiderSkin.new()
	skin.name = "ContinuousHero"
	add_child(skin)
	skin.setup(offsets)
	for key in visuals:
		if key != "board": hide_legacy_meshes(visuals[key])
	pose_ride(0.0, 0.0)
	set_hat(hat_index)
	reset_physics_interpolation()
	sync_skin()

func attach_hat(head_model: Node3D) -> void:
	var previous: Node = head_model.get_node_or_null("CrashHat")
	if is_instance_valid(previous):
		head_model.remove_child(previous)
		previous.queue_free()
	var path: String = HAT_PATHS[hat_index]
	if not ResourceLoader.exists(path): return
	var scene: PackedScene = load(path)
	if scene == null: return
	var accessory: Node3D = scene.instantiate()
	accessory.name = "CrashHat"
	accessory.position = Vector3(0, .34, 0)
	head_model.add_child(accessory)

func set_hat(index: int) -> void:
	hat_index = clampi(index, 0, HAT_PATHS.size() - 1)
	if visuals.has("head"): attach_hat(visuals.head)
	if body_parts.has("head"):
		var head: Node3D = body_parts.head
		var head_model: Node3D = head.get_node_or_null("RiderModel")
		if head_model != null: attach_hat(head_model)

func model_key(key: String) -> String:
	if key.begins_with("arm_"): return "upper_arm"
	if key.begins_with("fore_"): return "forearm"
	if key.begins_with("thigh_"): return "thigh"
	if key.begins_with("shin_"): return "shin"
	return key

func _process(_delta: float) -> void:
	# Render is the sole recurring bone-pose owner. Immediate resets/export use
	# the public simulation sync explicitly, never as a second physics callback.
	sync_skin(true)

func sync_skin(use_interpolated: bool = false) -> void:
	if skin != null: skin.sync_parts(body_parts if ragdoll else visuals, use_interpolated)

func hide_legacy_meshes(node: Node) -> void:
	if node is MeshInstance3D: node.visible = false
	for child in node.get_children(): hide_legacy_meshes(child)

func set_push_phase(value: float) -> void:
	riding_push_phase = fposmod(value, 1.0)

func pose_ride(time: float, steer: float, speed: float = 0.0, pushing: bool = false) -> void:
	if ragdoll: return
	for key in visuals:
		visuals[key].position = offsets[key]
		visuals[key].rotation = Vector3.ZERO
	apply_launch_pose(steer)
	# Upper body retains the selected bail silhouette. Grounded legs use explicit
	# hip/knee/ankle constraints, so the animation cannot be overwritten by the pose.
	var phase: float = riding_push_phase if riding_push_phase >= 0.0 else fposmod(time / .72, 1.0)
	var lean: float = steer * .11 * clampf(speed / 10.0, 0.0, 1.0)
	var sway: float = sin(time * 4.0) * .012 * clampf(speed / 5.0, 0.0, 1.0)
	if pushing: sway -= sin(phase * PI) * .10
	for key in ["torso", "pelvis", "head", "arm_l", "arm_r", "fore_l", "fore_r"]:
		visuals[key].position.x += lean
		visuals[key].position.y += sway
	for key in pose_anchors:
		pose_anchors[key].x += lean
		pose_anchors[key].y += sway
	foot_contacts.clear()
	for side in ["l", "r"]:
		var sign_x: float = -1.0 if side == "l" else 1.0
		# Both feet stand along the deck; the right foot performs one smooth kick.
		var ankle: Vector3 = visuals.board.position + visuals.board.basis * Vector3(sign_x * .17, .30, -.29 if side == "l" else .30)
		var contact: bool = true
		if side == "r" and pushing:
			var stroke: float = sin(phase * PI)
			ankle.x += stroke * .38
			ankle.z += sin(phase * TAU) * .29
			ankle.y -= stroke * .304
			# Recovery toe clearance; kick impulse occurs at phase .55.
			if phase > .62: ankle.y += sin((phase-.62)/.38*PI) * .16
			contact = phase < .10 or phase > .95
		var hip: Vector3 = pose_anchors["hip_"+side]
		# Positive-Z knee bend remains consistent throughout carve and recovery.
		var delta: Vector3 = ankle - hip
		var length: float = delta.length()
		var bend: Vector3 = Vector3.FORWARD.cross(delta).cross(delta).normalized()
		if bend.z < 0.0: bend = -bend
		var knee: Vector3 = (hip + ankle) * .5 + bend * sqrt(maxf(0.0, .43*.43-length*length*.25))
		place_segment("thigh_"+side, hip, knee)
		# The shin frame includes the shoe. Keep its sole horizontal while planted,
		# and retain a knee anchor for the real joint rather than rotating the shoe into the deck.
		visuals["shin_"+side].position = ankle
		visuals["shin_"+side].basis = visuals.board.basis
		pose_anchors["knee_"+side] = knee
		foot_contacts[side] = {"planted": contact, "sole": ankle + visuals.board.basis * Vector3(0,-.266,.07)}

func set_pose(index: int) -> void:
	if ragdoll: return
	pose_index = clampi(index, 0, 2)
	pose_ride(0.0, 0.0)
	reset_physics_interpolation()
	sync_skin()

func place_segment(key: String, start: Vector3, finish: Vector3) -> void:
	var part: Node3D = visuals[key]
	part.position = (start + finish) * .5
	# All anatomical models have their long axis along local Y.
	var up: Vector3 = (start - finish).normalized()
	var right: Vector3 = Vector3.FORWARD.cross(up).normalized()
	if right.length_squared() < .01: right = Vector3.RIGHT
	part.basis = Basis(right, up, right.cross(up)).orthonormalized()

func apply_launch_pose(steer: float) -> void:
	pose_anchors.clear()
	var hip := Vector3(0, .91, 0)
	var shoulder := Vector3(0, 1.55, .08)
	if pose_index == 0: # TUCK: compact arms and folded knees.
		hip = Vector3(0, .72, -.08)
		shoulder = Vector3(0, 1.25, .29)
	elif pose_index == 2: # TORPEDO: long, forward-leaning silhouette.
		shoulder = Vector3(0, 1.44, .43)
	var spine: Vector3 = (shoulder - hip).normalized()
	place_segment("torso", shoulder, hip + spine * .12)
	visuals.pelvis.position = hip
	visuals.pelvis.basis = visuals.torso.basis
	visuals.head.position = shoulder + spine * .36
	visuals.head.basis = visuals.torso.basis
	pose_anchors["waist"] = hip + spine * .10
	pose_anchors["neck"] = shoulder + spine * .13
	for side in ["l", "r"]:
		var sign_x: float = -1.0 if side == "l" else 1.0
		var arm_start: Vector3 = shoulder + Vector3(sign_x * .34, -.04, 0)
		var elbow: Vector3
		var wrist: Vector3
		var knee: Vector3
		var ankle: Vector3
		var leg_start: Vector3 = hip + Vector3(sign_x * .18, -.07, 0)
		if pose_index == 0:
			elbow = arm_start + Vector3(sign_x * .08, -.28, .16)
			wrist = elbow + Vector3(-sign_x * .10, -.21, -.23)
			knee = leg_start + Vector3(sign_x * .02, -.19, .32)
			ankle = knee + Vector3(0, -.31, -.20)
		elif pose_index == 1: # STARFISH: wide arms and separated legs.
			elbow = arm_start + Vector3(sign_x * .33, .02, 0)
			wrist = elbow + Vector3(sign_x * .31, .04, .02)
			knee = leg_start + Vector3(sign_x * .17, -.35, 0)
			ankle = knee + Vector3(sign_x * .10, -.36, .02)
		else:
			elbow = arm_start + Vector3(-sign_x * .13, .18, .25)
			wrist = elbow + Vector3(-sign_x * .10, .14, .27)
			knee = leg_start + Vector3(0, -.36, -.10)
			ankle = knee + Vector3(0, -.35, -.05)
		place_segment("arm_" + side, arm_start, elbow)
		place_segment("fore_" + side, elbow, wrist)
		place_segment("thigh_" + side, leg_start, knee)
		place_segment("shin_" + side, knee, ankle)
		pose_anchors["shoulder_" + side] = arm_start
		pose_anchors["elbow_" + side] = elbow
		pose_anchors["hip_" + side] = leg_start
		pose_anchors["knee_" + side] = knee
	visuals.board.rotation.z = -steer * .07

func bail(velocity: Vector3, lift: float = 3.5) -> void:
	if ragdoll: return
	ragdoll = true
	bail_frames.clear()
	bail_anchors.clear()
	for key in visuals: bail_frames[key] = visuals[key].global_transform
	for key in pose_anchors: bail_anchors[key] = to_global(pose_anchors[key])
	var parent: Node = get_parent()
	var body_map: Dictionary = {}
	for key in offsets:
		var limb := RagdollLimb.new()
		limb.name = key
		limb.limb_name = key
		limb.set_meta("stable_id", "rider/" + key)
		limb.game = game
		limb.mass = 11.0 if key == "torso" else (6.0 if key == "pelvis" else 2.0)
		if key == "board": limb.mass = 2.0
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		match key:
			"torso": box.size = Vector3(.64,.68,.4)
			"pelvis": box.size = Vector3(.52,.28,.38)
			"head": box.size = Vector3(.44,.48,.42)
			"board": box.size = Vector3(.76,.18,1.65)
			_: box.size = Vector3(.21,.35,.24)
		shape.shape = box
		limb.add_child(shape)
		var mesh: Node3D = MODELS[model_key(key)].instantiate()
		mesh.name = "RiderModel"
		limb.add_child(mesh)
		parent.add_child(limb)
		limb.global_transform = bail_frames[key]
		limb.reset_physics_interpolation()
		limb.linear_velocity = velocity + Vector3(0, lift, 0)
		limb.angular_velocity = Vector3([4.2, 1.0, .35][pose_index], 0.0, -velocity.x * 0.18)
		if key == "board":
			limb.linear_velocity += Vector3(0,-1,3)
			limb.angular_velocity = Vector3(4,2,1)
		limb.previous_linear_velocity = limb.linear_velocity
		limb.previous_angular_velocity = limb.angular_velocity
		body_map[key] = limb
		body_parts[key] = limb
		if key != "board":
			hide_legacy_meshes(mesh)
			prepare_damage_visual(key, limb, mesh)
		if key == "head": attach_hat(mesh)
		limbs.append(limb)
		visuals[key].visible = false
	torso = body_map.torso
	join(body_map.torso, body_map.pelvis, to_global(pose_anchors.waist))
	join(body_map.torso, body_map.head, to_global(pose_anchors.neck))
	for side in ["l", "r"]:
		join(body_map.torso,body_map["arm_"+side],to_global(pose_anchors["shoulder_"+side]))
		join(body_map["arm_"+side],body_map["fore_"+side],to_global(pose_anchors["elbow_"+side]))
		join(body_map.pelvis,body_map["thigh_"+side],to_global(pose_anchors["hip_"+side]))
		join(body_map["thigh_"+side],body_map["shin_"+side],to_global(pose_anchors["knee_"+side]))
	apply_damage_states(damage_states.duplicate())
	sync_skin()

func overlay_meshes(node: Node, material: StandardMaterial3D) -> void:
	if node is MeshInstance3D: node.material_overlay = material
	for child in node.get_children(): overlay_meshes(child, material)

func prepare_damage_visual(key: String, limb: RagdollLimb, mesh: Node3D) -> void:
	var bruise := StandardMaterial3D.new()
	bruise.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bruise.albedo_color = Color(.30, .045, .16, 0)
	bruise.roughness = .9
	damage_materials[key] = bruise
	overlay_meshes(mesh, bruise)
	var patch := MeshInstance3D.new()
	patch.name = "InjuryMarker"
	var ring := TorusMesh.new()
	var radius: float = .32 if key == "torso" else (.25 if key in ["head", "pelvis"] else .145)
	ring.inner_radius = radius * .72
	ring.outer_radius = radius
	ring.rings = 12
	ring.ring_segments = 8
	patch.mesh = ring
	patch.position.y = -.15 if key not in ["head", "pelvis"] else 0.0
	patch.scale.y = .65
	var marker := StandardMaterial3D.new()
	marker.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	marker.albedo_color = Color("ffcb57")
	marker.emission_enabled = true
	marker.emission = Color("ff723f")
	marker.emission_energy_multiplier = .7
	patch.material_override = marker
	patch.visible = false
	limb.add_child(patch)
	damage_patches[key] = patch

func set_limb_damage(limb: String, severity: float) -> void:
	if limb == "board" or not offsets.has(limb): return
	var value: float = clampf(severity, 0, 100)
	damage_states[limb] = value
	if skin != null: skin.set_damage(limb, value)
	if not damage_materials.has(limb): return
	var bruise: StandardMaterial3D = damage_materials[limb]
	bruise.albedo_color = Color(.30, .045, .16, .68 * value / 100.0)
	var patch: MeshInstance3D = damage_patches[limb]
	patch.visible = value > 0
	var marker: StandardMaterial3D = patch.material_override
	marker.albedo_color = Color("ffcb57").lerp(Color("ff304f"), value / 100.0)
	marker.emission = marker.albedo_color
	patch.scale.x = .85 + value * .003
	patch.scale.z = patch.scale.x

func apply_damage_states(states: Dictionary) -> void:
	# Replay snapshots are complete states: absent limbs must become healthy again.
	var snapshot: Dictionary = states.duplicate()
	for key in offsets:
		if key != "board": set_limb_damage(key, float(snapshot.get(key, 0.0)))

func join(a: RigidBody3D, b: RigidBody3D, at: Vector3) -> void:
	var joint := PinJoint3D.new()
	get_parent().add_child(joint)
	joint.global_position = at
	joint.node_a = joint.get_path_to(a)
	joint.node_b = joint.get_path_to(b)
	joint.set_param(PinJoint3D.PARAM_BIAS, 0.3)
	joint.set_param(PinJoint3D.PARAM_DAMPING, 1.0)
	joint.exclude_nodes_from_collision = true
	joints.append(joint)

func focus_position() -> Vector3:
	if ragdoll and is_instance_valid(torso): return torso.global_position
	return global_position + Vector3(0,1,0)

func speed() -> float:
	if ragdoll and is_instance_valid(torso): return torso.linear_velocity.length()
	return 0.0

func aftertouch(direction: Vector3, boost: bool, _delta: float) -> void:
	if not ragdoll: return
	var aim: Vector3 = direction.normalized() if direction.is_finite() else Vector3.ZERO
	for body in limbs:
		if is_instance_valid(body) and body.limb_name != "board":
			body.apply_central_force(aim * body.mass * 5.0)
	if boost: launch_impulse(Vector3(0, 0, 1))

func launch_impulse(direction: Vector3, strength: float = 9.0) -> void:
	if not ragdoll or not direction.is_finite() or not is_finite(strength): return
	var aim := Vector3(direction.x, 0, direction.z)
	if aim.length_squared() < .001: aim = Vector3(0, 0, 1)
	aim = aim.normalized()
	var impulse: Vector3 = aim * clampf(strength, 0.0, 12.0) + Vector3.UP * 2.7
	for body in limbs:
		if is_instance_valid(body) and body.limb_name != "board":
			body.apply_central_impulse(impulse * body.mass)
	if is_instance_valid(torso): torso.apply_torque_impulse(Vector3(1.0, 0, -aim.x * .6) * torso.mass)

func presentation_focus_position() -> Vector3:
	if ragdoll and is_instance_valid(torso): return torso.get_global_transform_interpolated().origin
	return get_global_transform_interpolated().origin + Vector3(0,1,0)
