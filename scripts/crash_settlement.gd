extends RefCounted
## Only the rider, board and causally armed props keep a claim open. Ordinary
## passing traffic cannot prevent settlement. Rotation matters as much as travel.

static func boundary_radius(body: RigidBody3D) -> float:
	if body.has_meta("settlement_radius"): return float(body.get_meta("settlement_radius"))
	var radius: float = .05
	for child in body.get_children():
		if child is CollisionShape3D and child.shape != null:
			var bounds: AABB = child.shape.get_debug_mesh().get_aabb()
			for corner in 8:
				radius = maxf(radius, (child.transform * bounds.get_endpoint(corner)).length())
	body.set_meta("settlement_radius", radius)
	return radius

static func boundary_speed(body: RigidBody3D) -> float:
	if not body.linear_velocity.is_finite() or not body.angular_velocity.is_finite(): return INF
	return body.linear_velocity.length() + body.angular_velocity.length() * boundary_radius(body)

static func has_activity(rider_parts: Array, props: Array) -> bool:
	return bool(measure(rider_parts,props).active)

static func measure(rider_parts: Array, props: Array) -> Dictionary:
	var movers: Array[Dictionary] = []
	for body in rider_parts:
		if is_instance_valid(body) and boundary_speed(body) >= 1.0:
			movers.append({"id":str(body.get_meta("stable_id",body.name)),"reason":"rider_boundary_motion","boundary_speed":boundary_speed(body),"linear_speed":body.linear_velocity.length(),"angular_speed":body.angular_velocity.length()})
	for prop in props:
		if not is_instance_valid(prop) or not prop.armed: continue
		if prop is TrafficCar:
			if prop.linear_velocity.length() >= .35 or prop.angular_velocity.length() >= .3 or prop.driver_state == TrafficCar.DriverState.UNCONTROLLED:
				movers.append({"id":prop.stable_id,"reason":"causal_traffic_unsettled","linear_speed":prop.linear_velocity.length(),"angular_speed":prop.angular_velocity.length(),"driver_state":prop.driver_state})
		elif boundary_speed(prop) >= 1.0:
			movers.append({"id":prop.stable_id,"reason":"armed_prop_boundary_motion","boundary_speed":boundary_speed(prop),"linear_speed":prop.linear_velocity.length(),"angular_speed":prop.angular_velocity.length()})
	return {"active":not movers.is_empty(),"movers":movers}

static func finish_reason(simulation_seconds: float, presentation_seconds: float, idle_seconds: float, pending: bool) -> String:
	if presentation_seconds >= 34.0: return "presentation_limit"
	if simulation_seconds >= 16.0: return "simulation_limit"
	if simulation_seconds > 3.0 and idle_seconds > 1.25 and not pending: return "idle"
	return ""
