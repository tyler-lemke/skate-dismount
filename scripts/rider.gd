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
var visuals: Dictionary = {}
var limbs: Array[RagdollLimb] = []
var joints: Array[Joint3D] = []
var ragdoll: bool = false
var torso: RagdollLimb
var game: Node
var pose: float = 0.0
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
	pose_ride(0.0, 0.0)

func model_key(key: String) -> String:
	if key.begins_with("arm_"): return "upper_arm"
	if key.begins_with("fore_"): return "forearm"
	if key.begins_with("thigh_"): return "thigh"
	if key.begins_with("shin_"): return "shin"
	return key

func pose_ride(time: float, steer: float) -> void:
	if ragdoll: return
	var bob: float = sin(time * 10.0) * 0.025
	for key in visuals:
		visuals[key].position = offsets[key]
		visuals[key].rotation = Vector3.ZERO
	visuals.torso.position.y -= 0.12 + bob
	visuals.torso.rotation.x = 0.18
	visuals.torso.rotation.z = -steer * 0.13
	visuals.head.position.y -= 0.12 + bob
	visuals.pelvis.position.y -= 0.08
	visuals.arm_l.rotation.z = -0.42 - steer * 0.2
	visuals.arm_r.rotation.z = 0.42 - steer * 0.2
	visuals.fore_l.rotation.x = -0.70
	visuals.fore_r.rotation.x = -0.70
	visuals.thigh_l.rotation.x = -0.32
	visuals.thigh_r.rotation.x = -0.32
	visuals.shin_l.rotation.x = 0.25
	visuals.shin_r.rotation.x = 0.25
	visuals.board.rotation.z = -steer * 0.07

func bail(velocity: Vector3, lift: float = 3.5) -> void:
	if ragdoll: return
	ragdoll = true
	var parent: Node = get_parent()
	var body_map: Dictionary = {}
	for key in offsets:
		var limb := RagdollLimb.new()
		limb.name = key
		limb.limb_name = key
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
		limb.add_child(mesh)
		parent.add_child(limb)
		limb.global_transform = visuals[key].global_transform
		limb.linear_velocity = velocity + Vector3(0, lift, 0)
		limb.angular_velocity = Vector3(2.5, 0.1, -velocity.x * 0.18)
		if key == "board":
			limb.linear_velocity += Vector3(0,-1,3)
			limb.angular_velocity = Vector3(4,2,1)
		body_map[key] = limb
		limbs.append(limb)
		visuals[key].visible = false
	torso = body_map.torso
	join(body_map.torso, body_map.pelvis, global_position + Vector3(0,1.02,0))
	join(body_map.torso, body_map.head, global_position + Vector3(0,1.68,0))
	for side in ["l", "r"]:
		var x: float = -1.0 if side == "l" else 1.0
		join(body_map.torso,body_map["arm_"+side],global_position+Vector3(x*.34,1.56,0))
		join(body_map["arm_"+side],body_map["fore_"+side],global_position+Vector3(x*.48,1.15,0.04))
		join(body_map.pelvis,body_map["thigh_"+side],global_position+Vector3(x*.18,.80,0))
		join(body_map["thigh_"+side],body_map["shin_"+side],global_position+Vector3(x*.18,.42,0))

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

func aftertouch(direction: Vector3, boost: bool, delta: float) -> void:
	if not ragdoll: return
	for body in limbs:
		if is_instance_valid(body):
			body.apply_central_force(direction * body.mass * 5.0)
			if boost:
				body.apply_central_impulse(Vector3(0, 5.4, 9.0) * body.mass)
				body.apply_torque_impulse(Vector3(1.4,0,0) * body.mass)
