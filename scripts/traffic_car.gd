class_name TrafficCar
extends CrashProp

# One physical body for its entire lifetime. Driver control never owns transforms.
enum DriverState { DRIVE, BRAKE, UNCONTROLLED, SETTLED }
var driver_state: int = DriverState.BRAKE
var started: bool = false
var fleet: Array = []
var route_direction: Vector3 = Vector3.RIGHT
var lane_origin: Vector3
var route_points: Array[Vector3] = []
var waypoint_index: int = 0
var cruise_speed: float = 5.5
var queued: bool = false
var driver_clock: float = 0.0
var reaction_time: float = .25
var hazard_clock: float = 0.0
var clear_clock: float = 0.0
var quiet_clock: float = 0.0
var wheel_phase: float = 0.0
var brake_lights: bool = true
var previous_velocity: Vector3 = Vector3.ZERO
var previous_spin: Vector3 = Vector3.ZERO
var last_motor_force: Vector3 = Vector3.ZERO
var contact_times: Dictionary = {}
var pending_contacts: Dictionary = {}
var cause_clock: float = -1.0
var lamps: Array[MeshInstance3D] = []
var wheels: Array[Node3D] = []
var exited: bool = false
var paint_color: Color = Color("ffc54e")
const ACCELERATION: float = 4.0
const BRAKING: float = 6.0
const SAFETY_GAP: float = 1.5
const HULL_LENGTH: float = 3.3

func _ready() -> void:
	super._ready()
	set_meta("traffic", true)
	# A cheap hull is intentional; wheel rotation is presentation, not suspension.
	physics_material_override.friction = .16
	physics_material_override.bounce = .05
	linear_damp = .10
	angular_damp = .65
	max_contacts_reported = 16
	threshold = 2.0
	for node in visual.get_children() if visual else []:
		if node is Node3D and str(node.name).begins_with("Wheel_"): wheels.append(node)
	var body: MeshInstance3D = visual.get_node_or_null("Body") if visual else null
	if body and body.mesh:
		for i in body.mesh.get_surface_count():
			var material: Material = body.get_active_material(i)
			if material is StandardMaterial3D and "yellow" in material.resource_name.to_lower():
				var paint: StandardMaterial3D = material.duplicate()
				paint.albedo_color=paint_color
				body.set_surface_override_material(i,paint)
	var light_material := StandardMaterial3D.new()
	light_material.albedo_color = Color("ff4b32")
	light_material.emission_enabled = true
	light_material.emission = Color("ff321c")
	light_material.emission_energy_multiplier = 1.6
	for side in [-1, 1]:
		var lamp := MeshInstance3D.new()
		var mesh := BoxMesh.new(); mesh.size = Vector3(.24, .12, .035)
		lamp.mesh = mesh; lamp.material_override = light_material
		add_child(lamp); lamp.position = Vector3(side * .65, .76, -1.665)
		lamps.append(lamp)

func start_driver(cars: Array) -> void:
	fleet = cars
	started = true
	lane_origin = global_position
	if not route_points.is_empty(): route_direction = (route_points[0] - lane_origin).normalized()
	origin = global_position
	freeze = false
	sleeping = false
	grace = 0.0
	driver_state = DriverState.BRAKE if queued else DriverState.DRIVE
	linear_velocity = Vector3.ZERO if queued else route_direction * cruise_speed
	previous_velocity = linear_velocity
	previous_spin = Vector3.ZERO

func _physics_process(delta: float) -> void:
	if not started or not is_instance_valid(game) or not game.is_live(): return
	if not armed and absf(global_position.x) > 32.0:
		# Finite fleet leaves through the open road end; never recycle a payable ID.
		exited = true; visible = false; freeze = true
		collision_layer = 0; collision_mask = 0
		return
	driver_clock += delta
	if driver_state in [DriverState.DRIVE, DriverState.BRAKE] and waypoint_index < route_points.size():
		var to_point: Vector3 = route_points[waypoint_index] - global_position; to_point.y=0
		if to_point.dot(route_direction) < 1.4:
			lane_origin = route_points[waypoint_index]; waypoint_index+=1
			if waypoint_index < route_points.size():
				route_direction = (route_points[waypoint_index] - lane_origin).normalized()
	wheel_phase += linear_velocity.dot(global_basis.z) * delta / .31
	if driver_state == DriverState.UNCONTROLLED:
		quiet_clock = quiet_clock + delta if linear_velocity.length() < .35 and angular_velocity.length() < .3 else 0.0
		if quiet_clock > .65: driver_state = DriverState.SETTLED
	elif driver_state == DriverState.SETTLED and linear_velocity.length() > .6:
		driver_state = DriverState.UNCONTROLLED; quiet_clock = 0.0
	brake_lights = driver_state == DriverState.BRAKE
	for lamp in lamps: lamp.visible = brake_lights
	for wheel in wheels: wheel.rotation.x = wheel_phase

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	last_motor_force = Vector3.ZERO
	if not started or not is_instance_valid(game) or not game.is_live(): return
	# Inspect contacts before applying any driver force: impact authority wins this tick.
	# Preserve real same-step collision evidence while a predecessor's callback
	# establishes cause; expire it after one subsequent solver tick.
	for id in pending_contacts.keys():
		var evidence: Dictionary = pending_contacts[id]
		var predecessor: Object = evidence.other.get_ref()
		if driver_clock-float(evidence.time)>state.step*2.1 or not is_instance_valid(predecessor):
			pending_contacts.erase(id); continue
		if predecessor is CrashProp and predecessor.armed:
			if not predecessor is TrafficCar or predecessor.cause_clock<=float(evidence.time)+state.step*.5:
				receive_caused_contact(predecessor,float(evidence.strength),evidence.at)
			pending_contacts.erase(id)
	for i in state.get_contact_count():
		var other: Object = state.get_contact_collider_object(i)
		if other == null: continue
		var normal: Vector3 = state.get_contact_local_normal(i).normalized()
		if absf(normal.y) > .7: continue # Floor support is neither traffic damage nor a hazard.
		var at: Vector3 = state.get_contact_local_position(i)
		var incoming: Vector3 = previous_velocity + previous_spin.cross(at - state.transform.origin)
		var other_incoming: Vector3 = state.get_contact_collider_velocity_at_position(i)
		if other is TrafficCar:
			other_incoming = other.previous_velocity + other.previous_spin.cross(at - other.global_position)
		var closing: float = maxf(0.0, -(incoming - other_incoming).dot(normal))
		var resolved: Vector3 = state.linear_velocity + state.angular_velocity.cross(at - state.transform.origin)
		var strength: float = maxf(state.get_contact_impulse(i).length() / mass, maxf(0.0, (resolved - incoming).dot(normal)))
		# A simultaneous three-body transfer can reach a resting third body in
		# the same solve. Measured normal momentum transfer is valid even when
		# its predecessor's pre-solve velocity was still zero.
		if closing < .8 and strength < 1.2: continue
		# Some Godot first contacts report no impulse; normal approach still establishes
		# a real collider contact and the separate cause contract, never travelled distance.
		hit_strength = maxf(strength, closing * .5)
		if hit_strength < .65: continue
		release_driver()
		var causal: bool = other.has_meta("rider") or (other is CrashProp and other.armed)
		var other_id: int = other.get_instance_id()
		if not causal and not armed and other is CrashProp:
			if not pending_contacts.has(other_id) or hit_strength>float(pending_contacts[other_id].strength):
				pending_contacts[other_id]={"other":weakref(other),"strength":hit_strength,"at":at,"time":driver_clock}
		if driver_clock - float(contact_times.get(other_id, -10.0)) < .18: continue
		contact_times[other_id] = driver_clock
		if causal: receive_caused_contact(other,hit_strength,at)
		if armed and hit_strength >= threshold and not broken: call_deferred("shatter")
	previous_velocity = state.linear_velocity
	previous_spin = state.angular_velocity
	if driver_state not in [DriverState.DRIVE, DriverState.BRAKE]: return
	var speed: float = maxf(0.0, state.linear_velocity.dot(route_direction))
	var target: float = 0.0 if queued else cruise_speed
	var hazard: bool = false
	for other in fleet:
		if other == self or not is_instance_valid(other) or other.exited: continue
		var offset: Vector3 = other.global_position - state.transform.origin
		var forward: float = offset.dot(route_direction)
		var lateral: float = absf(offset.dot(Vector3(-route_direction.z, 0, route_direction.x)))
		if forward <= 0.0 or lateral > 1.95: continue
		var bumper_gap: float = forward - HULL_LENGTH
		var stop_distance: float = speed * reaction_time + speed * speed / (2.0 * BRAKING) + SAFETY_GAP
		if bumper_gap < stop_distance:
			hazard = true
			# Brake after perception latency; gap includes this latency above.
			if hazard_clock >= reaction_time:
				target = minf(target, maxf(0.0, bumper_gap - SAFETY_GAP) * .65)
	if hazard:
		hazard_clock += state.step; clear_clock = 0.0
	else:
		clear_clock += state.step
		if clear_clock > .3: hazard_clock = 0.0
	var previous_state: int = driver_state
	driver_state = DriverState.BRAKE if queued or target < cruise_speed * .8 else DriverState.DRIVE
	if previous_state == DriverState.DRIVE and driver_state == DriverState.BRAKE and speed > 2.0 and game.has_method("traffic_braked"):
		game.traffic_braked(self)
	var acceleration: float = clampf((target - speed) * 4.0 + (2.3 if target > .1 else 0.0), -BRAKING, ACCELERATION)
	var nose: Vector3 = state.transform.basis.z; nose.y=0; nose=nose.normalized()
	last_motor_force = nose * acceleration * mass
	state.apply_central_force(last_motor_force)
	# Small bounded lane correction, wholly removed after the first substantial contact.
	var side: Vector3 = Vector3(-route_direction.z, 0, route_direction.x)
	var error: float = (state.transform.origin - lane_origin).dot(side)
	state.apply_central_force(side * clampf(-error * 3.0 - state.linear_velocity.dot(side) * 2.0, -3.0, 3.0) * mass)
	var heading: Vector3 = state.transform.basis.z; heading.y = 0.0
	var yaw_error: float = heading.signed_angle_to(route_direction, Vector3.UP)
	state.apply_torque(Vector3.UP * clampf(yaw_error * 7.0 - state.angular_velocity.y * 3.0, -5.0, 5.0) * mass)

func receive_caused_contact(other: Object, strength: float, at: Vector3) -> void:
	if not armed:
		cause_clock=driver_clock
		cause_label=str(other.get_meta("limb",other.name)) if other.has_meta("rider") else other.stable_id
	armed=true
	if game.has_method("traffic_contact"): game.traffic_contact(self,other,strength,at)
	if strength>=threshold and not broken: call_deferred("shatter")

func release_driver() -> void:
	if driver_state not in [DriverState.UNCONTROLLED, DriverState.SETTLED]:
		driver_state = DriverState.UNCONTROLLED
		quiet_clock = 0.0
		# The cheap rigid hull slides after tire control is lost; retaining the
		# driving friction here arrests a broadside crash before its second contact.
		physics_material_override.friction = .055
		linear_damp = .04
		angular_damp = .3
	last_motor_force = Vector3.ZERO

func apply_shove(impulse: Vector3, source: String = "rider") -> void:
	if not impulse.is_finite() or impulse.is_zero_approx(): return
	if not armed: cause_clock=driver_clock
	armed = true
	if cause_label.is_empty(): cause_label = source
	release_driver(); sleeping = false
	apply_central_impulse(impulse)

func activate(impulse: Vector3) -> void:
	# Compatibility only; normal traffic launch must use start_driver, never activate.
	apply_shove(impulse, "rider")

func has_causal_motion() -> bool:
	return armed and driver_state == DriverState.UNCONTROLLED and (linear_velocity.length() > .35 or angular_velocity.length() > .3)

func imminent_contact(horizon: float = 1.5) -> bool:
	if not armed: return false
	for other in fleet:
		if other == self or other.exited or other.armed or other.driver_state not in [DriverState.DRIVE, DriverState.BRAKE]: continue
		var relative: Vector3 = other.global_position - global_position
		var velocity: Vector3 = other.linear_velocity - linear_velocity
		var t: float = clampf(-relative.dot(velocity) / maxf(.01, velocity.length_squared()), 0.0, horizon)
		if t > .01 and (relative + velocity * t).length() < 3.6: return true
	return false

func snapshot() -> Dictionary:
	return {"driver_state": driver_state, "wheel_phase": wheel_phase, "brake_lights": brake_lights,
		"damage": broken, "visible": visible, "armed": armed, "cause": cause_label}

func apply_snapshot(data: Dictionary) -> void:
	driver_state = int(data.get("driver_state", DriverState.SETTLED))
	wheel_phase = float(data.get("wheel_phase", 0.0)); brake_lights = bool(data.get("brake_lights", false))
	visible = bool(data.get("visible", true)); armed = bool(data.get("armed", false))
	cause_label = str(data.get("cause", "")); broken = bool(data.get("damage", false))
	set_damaged_visual(broken)
	for lamp in lamps: lamp.visible = brake_lights
	for wheel in wheels: wheel.rotation.x = wheel_phase

func set_damaged_visual(damaged: bool) -> void:
	# Hero taxi has a local dent morph: retain paint, glazing and separate wheels.
	var body: MeshInstance3D = visual.get_node_or_null("Body") if visual else null
	if body and body.mesh is ArrayMesh:
		for i in body.mesh.get_blend_shape_count():
			if body.mesh.get_blend_shape_name(i) == "Crumple":
				visual_broken = damaged
				body.set_blend_shape_value(i, .85 if damaged else 0.0)
				return
	super.set_damaged_visual(damaged)
