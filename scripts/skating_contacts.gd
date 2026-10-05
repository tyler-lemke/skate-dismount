extends RefCounted

# Contact proxies use the ragdoll's authored physical hulls. Hats are cosmetic.
# Transforms follow the actual riding parts, including STARFISH arms and board lean.
# Twelve parts share six immutable query shapes; queries never change actors.
const CollisionGeometry = preload("res://scripts/rider_collision.gd")
const SHAPE_KEYS: Array[String] = ["torso","pelvis","head","board","fore_l","limb"]
const WHEEL_REFERENCE: float = .23
const CONTACT_TOLERANCE: float = .002
const LEAF_TRAVEL: float = .0008
const QUERY_MARGIN: float = .0001
const MAX_STEP_TRAVEL: float = .10
const MAX_STEP_ANGLE: float = PI / 36.0
var shapes: Dictionary = {}
var _query := PhysicsShapeQueryParameters3D.new()
var query_count: int = 0

func _init() -> void:
	for key in SHAPE_KEYS: shapes[key] = CollisionGeometry.create_shape(key)
	_query.collision_mask = 2
	_query.collide_with_areas = false

func capture_proxies(rider: Node3D) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for key in rider.visuals:
		var part: Node3D = rider.visuals[key]
		if not is_instance_valid(part): continue
		var shape_key: String = "fore_l" if str(key).begins_with("fore_") else (key if shapes.has(key) else "limb")
		var shape: Shape3D = shapes[shape_key]
		var part_transform: Transform3D = rider.global_transform.affine_inverse() * part.global_transform
		var collision_offset: Transform3D = CollisionGeometry.offset(shape_key)
		result.append({"id":str(key), "shape":shape, "shape_radius":CollisionGeometry.radius(shape_key), "part_transform":part_transform, "collision_offset":collision_offset, "local_transform":part_transform * collision_offset})
	return result

static func _shape_radius(shape: Shape3D) -> float:
	if shape is BoxShape3D: return (shape as BoxShape3D).size.length()*.5
	if shape is ConvexPolygonShape3D:
		var radius: float = 0.0
		for vertex in (shape as ConvexPolygonShape3D).points: radius=maxf(radius,vertex.length())
		return radius
	assert(false,"Skating proxies require a supported box or convex hull")
	return 0.0

# End proxies are optional for callers whose pose does not change within a tick.
# When supplied they must have the same IDs/shapes as capture_proxies(previous).
func find_obstruction(space: PhysicsDirectSpaceState3D, previous: Transform3D, next: Transform3D,
		proxies: Array, route_props: Array, end_proxies: Array = []) -> Dictionary:
	query_count = 0
	var eligible: Dictionary = {}
	var excluded: Array[RID] = []
	for prop in route_props:
		if not is_instance_valid(prop) or not prop is CollisionObject3D: continue
		if prop is CrashProp and not prop.broken and not prop.get_meta("traffic",false):
			eligible[prop.get_rid()] = prop
		else:
			excluded.append(prop.get_rid())
	if eligible.is_empty(): return {}
	var ends: Dictionary = {}
	for proxy in end_proxies: ends[proxy.id] = proxy
	var earliest: Dictionary = {}
	for proxy in proxies:
		# Animate the anatomical frame, then apply its fixed collider offset.
		# Interpolating offset-space origins would follow a different arc from
		# the accepted part frame that main rewinds before activating the rig.
		var local_from: Transform3D = proxy.get("part_transform",proxy.local_transform)
		var endpoint: Dictionary = ends.get(proxy.id,proxy)
		var local_to: Transform3D = endpoint.get("part_transform",endpoint.local_transform)
		var offset: Transform3D = proxy.get("collision_offset",Transform3D.IDENTITY)
		var shape: Shape3D = proxy.shape
		var shape_radius: float = float(proxy.shape_radius) if proxy.has("shape_radius") else _shape_radius(shape)
		var radius: float = maxf(local_from.origin.length(),local_to.origin.length()) + offset.origin.length() + shape_radius
		var angle: float = _angle(previous.basis,next.basis) + _angle(local_from.basis,local_to.basis)
		var travel: float = previous.origin.distance_to(next.origin) + radius * angle + local_from.origin.distance_to(local_to.origin)
		var steps: int = maxi(1,maxi(int(ceil(travel / MAX_STEP_TRAVEL)),int(ceil(angle / MAX_STEP_ANGLE))))
		for index in steps:
			var a: float = float(index) / steps
			if not earliest.is_empty() and a > earliest.fraction: break
			var b: float = float(index + 1) / steps
			if not earliest.is_empty(): b = minf(b,earliest.fraction)
			var hit := _search(space,previous,next,local_from,local_to,shape,radius,shape_radius,offset,a,b,eligible,excluded,0)
			if not hit.is_empty():
				hit.proxy_id = proxy.id
				if earliest.is_empty() or hit.fraction < earliest.fraction: earliest = hit
				break
	return earliest

func _search(space: PhysicsDirectSpaceState3D, previous: Transform3D, next: Transform3D,
		local_from: Transform3D, local_to: Transform3D, shape: Shape3D, radius: float, shape_radius: float, offset: Transform3D,
		a: float, b: float, eligible: Dictionary, excluded: Array[RID], depth: int) -> Dictionary:
	var root_a: Transform3D = previous.interpolate_with(next,a)
	var root_b: Transform3D = previous.interpolate_with(next,b)
	var local_a: Transform3D = local_from.interpolate_with(local_to,a)
	var local_b: Transform3D = local_from.interpolate_with(local_to,b)
	var root_angle: float = _angle(root_a.basis,root_b.basis)
	var local_angle: float = _angle(local_a.basis,local_b.basis)
	var half_shape: float = shape_radius + offset.origin.length()
	# A midpoint-oriented box plus this Minkowski margin contains every rotating
	# corner during the segment, including local part animation. It only selects
	# candidates. Recursion reduces angular overreach below the contact tolerance.
	var angular_margin: float = 2.0 * radius * sin(root_angle * .25) + local_a.origin.distance_to(local_b.origin) * .5 + 2.0 * half_shape * sin(local_angle * .25)
	var middle: float = (a + b) * .5
	var middle_root: Transform3D = previous.interpolate_with(next,middle)
	var middle_pose: Transform3D = middle_root * local_from.interpolate_with(local_to,middle) * offset
	var cast_start := Transform3D(middle_pose.basis,root_a.origin + middle_pose.origin - middle_root.origin)
	var motion: Vector3 = root_b.origin - root_a.origin
	var candidate := _query_bound(space,shape,cast_start,motion,QUERY_MARGIN + angular_margin,eligible,excluded)
	if candidate.is_empty(): return {}
	var boundary_travel: float = motion.length() + 2.0 * radius * sin(root_angle * .5) + local_a.origin.distance_to(local_b.origin) + 2.0 * half_shape * sin(local_angle * .5)
	if boundary_travel <= LEAF_TRAVEL or depth >= 22:
		# Accept only a narrow query against the real oriented proxy. A broad
		# angular margin near a tangential pass can otherwise move the contact
		# many centimeters along the route despite a sub-millimeter hull bound.
		candidate = _query_bound(space,shape,root_a * local_a * offset,Vector3.ZERO,0.0,eligible,excluded)
		if not candidate.is_empty(): candidate.fraction = 0.0
		else:
			candidate = _query_bound(space,shape,middle_pose,Vector3.ZERO,0.0,eligible,excluded)
			if not candidate.is_empty(): candidate.fraction = .5
			else:
				candidate = _query_bound(space,shape,root_b * local_b * offset,Vector3.ZERO,0.0,eligible,excluded)
				if candidate.is_empty(): return {}
				candidate.fraction = 1.0
		candidate.fraction = clampf(lerpf(a,b,candidate.fraction),0.0,1.0)
		candidate.transform = previous.interpolate_with(next,candidate.fraction)
		candidate.error_bound = boundary_travel + QUERY_MARGIN * 3.0
		return candidate
	var left := _search(space,previous,next,local_from,local_to,shape,radius,shape_radius,offset,a,middle,eligible,excluded,depth + 1)
	if not left.is_empty(): return left
	return _search(space,previous,next,local_from,local_to,shape,radius,shape_radius,offset,middle,b,eligible,excluded,depth + 1)

func _query_bound(space: PhysicsDirectSpaceState3D, shape: Shape3D, at: Transform3D,
		motion: Vector3, margin: float, eligible: Dictionary, excluded: Array[RID]) -> Dictionary:
	_query.shape = shape
	_query.transform = at
	_query.motion = Vector3.ZERO
	_query.margin = margin
	_query.exclude = excluded
	# Starting overlaps need an explicit test: cast_motion intentionally ignores them.
	for attempt in 32:
		query_count += 1
		var overlap: Array[Dictionary] = space.intersect_shape(_query,64)
		if overlap.is_empty(): break
		var selected: RID
		for contact in overlap:
			if eligible.has(contact.rid):
				if not selected.is_valid(): selected = contact.rid
			elif not excluded.has(contact.rid): excluded.append(contact.rid)
		if selected.is_valid():
			# Read the contact from the selected real body; nearby ineligible
			# colliders must not supply its point or normal.
			var contact_excludes: Array[RID] = excluded.duplicate()
			for rid in eligible:
				if rid != selected: contact_excludes.append(rid)
			_query.exclude = contact_excludes
			_query.margin = margin + QUERY_MARGIN
			var rest: Dictionary = space.get_rest_info(_query)
			if rest.is_empty():
				var points: Array[Vector3] = space.collide_shape(_query,1)
				if points.size() >= 2:
					rest = {"point":points[1],"normal":(points[0]-points[1]).normalized()}
			return _contact(eligible[selected],0.0,rest,at.origin,motion)
		_query.exclude = excluded
	if motion.length_squared() <= .000000000001: return {}
	for attempt in 32:
		_query.transform = at
		_query.motion = motion
		_query.margin = margin
		_query.exclude = excluded
		query_count += 1
		var fractions: PackedFloat32Array = space.cast_motion(_query)
		if fractions.size() != 2 or fractions[0] >= 1.0: return {}
		var unsafe: float = fractions[1]
		_query.transform.origin = at.origin + motion * unsafe
		_query.motion = Vector3.ZERO
		# A tiny contact readback tolerance handles the solver's touching boundary.
		_query.margin = margin + QUERY_MARGIN
		var rest: Dictionary = space.get_rest_info(_query)
		if not rest.is_empty():
			if eligible.has(rest.rid): return _contact(eligible[rest.rid],fractions[0],rest,_query.transform.origin,motion)
			if not excluded.has(rest.rid): excluded.append(rest.rid)
			continue
		var overlaps: Array[Dictionary] = space.intersect_shape(_query,64)
		for contact in overlaps:
			if eligible.has(contact.rid): return _contact(eligible[contact.rid],fractions[0],{},_query.transform.origin,motion)
			if not excluded.has(contact.rid): excluded.append(contact.rid)
		# An unsafe sweep without contact readback must not invent an actor.
		if overlaps.is_empty(): return {}
	return {}

func _contact(collider: CrashProp, fraction: float, rest: Dictionary, fallback: Vector3, motion: Vector3) -> Dictionary:
	var normal: Vector3 = rest.get("normal",-motion.normalized() if motion.length_squared() > .000001 else Vector3.UP)
	return {"collider":collider,"fraction":fraction,"at":rest.get("point",fallback),"normal":normal}

static func _angle(a: Basis, b: Basis) -> float:
	return a.orthonormalized().get_rotation_quaternion().angle_to(b.orthonormalized().get_rotation_quaternion())

# The simulation root follows the authored tread top without a vertical speed
# cap. Presentation may interpolate this placement, but must not feed back into it.
static func grounded_height(level: Dictionary, z: float) -> float:
	if z < 0.0: return float(level.steps) * float(level.rise) + WHEEL_REFERENCE
	if z >= float(level.steps) * float(level.run): return WHEEL_REFERENCE
	return (float(level.steps) - floorf(z / float(level.run)) - 1.0) * float(level.rise) + WHEEL_REFERENCE
