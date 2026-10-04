class_name RagdollLimb
extends RigidBody3D

var game: Node
var cooldown: float = 0.0
var limb_name: String
var previous_linear_velocity: Vector3 = Vector3.ZERO
var previous_angular_velocity: Vector3 = Vector3.ZERO
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
	# Arcade energy ceiling keeps overlapping drum blasts in the playable crash zone.
	state.linear_velocity=state.linear_velocity.limit_length(36.0)
	state.linear_velocity.y=clampf(state.linear_velocity.y,-24.0,9.0)
	state.angular_velocity=state.angular_velocity.limit_length(18.0)
	var incoming_velocity: Vector3 = previous_linear_velocity
	var incoming_spin: Vector3 = previous_angular_velocity
	previous_linear_velocity = state.linear_velocity
	previous_angular_velocity = state.angular_velocity
	if limb_name == "board" or cooldown > 0.0 or not is_instance_valid(game) or not game.is_live(): return
	var force: float = 0.0
	var contact_position: Vector3 = global_position
	var contact_source: String = "unknown"
	for i in state.get_contact_count():
		# "Local" identifies this body, not a body-space coordinate. Contacts
		# and normals from the solver are already expressed in world space.
		var normal: Vector3 = state.get_contact_local_normal(i).normalized()
		var contact_offset: Vector3 = state.get_contact_local_position(i) - state.transform.origin
		var relative_velocity: Vector3 = incoming_velocity + incoming_spin.cross(contact_offset) - state.get_contact_collider_velocity_at_position(i)
		var closing_speed: float = maxf(0.0, -relative_velocity.dot(normal))
		# Support impulses and friction on a resting body are not fresh injuries.
		# A new impact needs real normal approach and measured momentum change.
		if closing_speed < 1.5: continue
		var impact: float = state.get_contact_impulse(i).length() / mass
		# Some first-contact solver reports have zero impulse despite resolving
		# a bounce. The observed contact-point velocity change captures that hit.
		var incoming_point_velocity: Vector3 = incoming_velocity + incoming_spin.cross(contact_offset)
		var resolved_point_velocity: Vector3 = state.linear_velocity + state.angular_velocity.cross(contact_offset)
		impact = maxf(impact, maxf(0.0, (resolved_point_velocity - incoming_point_velocity).dot(normal)))
		if impact > force:
			force = impact
			contact_position = state.get_contact_local_position(i)
			var other: Object = state.get_contact_collider_object(i)
			contact_source = str(other.name) if other is Node else "unknown"
	if force > 3.0:
		cooldown = 0.24
		game.call_deferred("rider_hit", limb_name, minf(force, 100.0), contact_position, contact_source)
