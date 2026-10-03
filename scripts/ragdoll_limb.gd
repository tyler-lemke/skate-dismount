class_name RagdollLimb
extends RigidBody3D

var game: Node
var cooldown: float = 0.0
var limb_name: String
func _ready() -> void:
	set_meta("rider", true)
	collision_layer = 4
	collision_mask = 3
	max_contacts_reported = 6
	continuous_cd = true
	linear_damp = 0.05
	angular_damp = 0.25
	var mat := PhysicsMaterial.new()
	mat.friction = 0.38
	mat.bounce = 0.16
	physics_material_override = mat

func _physics_process(delta: float) -> void:
	cooldown = maxf(0.0, cooldown - delta)

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if cooldown > 0.0 or not is_instance_valid(game) or not game.is_live(): return
	var force: float = 0.0
	for i in state.get_contact_count():
		force = maxf(force, state.get_contact_impulse(i).length() / mass)
	if force > 3.0:
		cooldown = 0.24
		game.call_deferred("rider_hit", limb_name, force, global_position)
