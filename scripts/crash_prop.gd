class_name CrashProp
extends RigidBody3D

signal wrecked(prop: CrashProp, explosive: bool)
var kind: String = "crate"
var value: int = 900
var armed: bool = false
var broken: bool = false
var explosive: bool = false
var origin: Vector3
var hit_strength: float = 0.0
var visual: Node3D
var threshold: float = 2.8
var nominal_radius: float = 0.65
var grace: float = 0.65
var fuse: float = -1.0
var game: Node
var visual_broken: bool = false
var damaged_material: StandardMaterial3D
var fuse_material: StandardMaterial3D
var fuse_clock: float = 0.0

func _ready() -> void:
	origin = global_position
	contact_monitor = true
	max_contacts_reported = 8
	continuous_cd = true
	linear_damp = 0.08
	angular_damp = 0.16
	collision_layer = 2
	collision_mask = 7
	var material := PhysicsMaterial.new()
	material.friction = 0.48
	material.bounce = 0.13
	physics_material_override = material

func _physics_process(delta: float) -> void:
	if not is_instance_valid(game) or not game.is_live(): return
	grace = maxf(0.0, grace - delta)
	if not armed: return
	if explosive and fuse>0:
		fuse_clock+=delta
		if fuse_material:
			fuse_material.emission_energy_multiplier=.35+absf(sin(fuse_clock*16))*1.8
	if fuse > 0.0:
		fuse -= delta
		if fuse <= 0.0 and not broken: shatter()
	if not broken and grace == 0.0:
		var travel: float = global_position.distance_to(origin)
		var tilt: float = global_basis.y.dot(Vector3.UP)
		if travel > 0.55 or tilt < 0.76:
			if explosive: ignite()
			else: shatter()
	if global_position.y < -12.0:
		queue_free()

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if broken or grace > 0.0 or not is_instance_valid(game) or not game.is_live(): return
	for i in state.get_contact_count():
		var other: Object = state.get_contact_collider_object(i)
		if other == null: continue
		var causal: bool = other.has_meta("rider") or (other is CrashProp and other.armed)
		if not causal: continue
		var relative: float = (state.get_contact_local_velocity_at_position(i) - state.get_contact_collider_velocity_at_position(i)).length()
		var impulse: float = state.get_contact_impulse(i).length() / maxf(mass, 1.0)
		hit_strength = maxf(relative, impulse)
		if hit_strength > 0.7:
			armed = true
			if explosive: call_deferred("ignite")
		if hit_strength >= threshold:
			if not explosive: call_deferred("shatter")
			break

func activate(impulse: Vector3) -> void:
	armed = true
	sleeping = false
	apply_central_impulse(impulse)
	if explosive: ignite()

func ignite() -> void:
	if broken or fuse>=0 or not armed: return
	# Stable staggered fuses make the same setup learnable on a retry.
	fuse=.68+float(int(get_meta("slot",0))%5)*.09
	fuse_material=StandardMaterial3D.new(); fuse_material.albedo_color=Color("ff8b41"); fuse_material.emission_enabled=true; fuse_material.emission=Color("ff5924")
	for mesh in visual.find_children("*","MeshInstance3D",true,false): mesh.material_override=fuse_material

func shatter() -> void:
	if broken or not armed or not is_instance_valid(game) or not game.is_live(): return
	broken = true
	wrecked.emit(self, explosive)
	# Keep the physical body intact: wrecked drums and cars still carry the chain reaction.
	set_damaged_visual(true)

func set_damaged_visual(damaged: bool) -> void:
	if visual_broken==damaged or not visual: return
	visual_broken=damaged
	if damaged and damaged_material==null:
		damaged_material=StandardMaterial3D.new()
		damaged_material.albedo_color=Color("c56746") if explosive else Color("657c7c")
		damaged_material.roughness=.85
	for mesh in visual.find_children("*", "MeshInstance3D", true, false):
		mesh.material_override=damaged_material if damaged else null
