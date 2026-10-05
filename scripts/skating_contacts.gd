extends RefCounted

# Contact proxies match the existing ragdoll's physical boxes. Hats are cosmetic.
# Transforms follow the actual riding parts, including STARFISH arms and board lean.
# Twelve parts share five immutable BoxShape resources; queries never change actors.
const PART_SIZES: Dictionary = {
	"torso": Vector3(.64,.68,.40), "pelvis": Vector3(.52,.28,.38),
	"head": Vector3(.44,.48,.42), "board": Vector3(.76,.18,1.65)
}
const LIMB_SIZE := Vector3(.21,.35,.24)
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
	for key in PART_SIZES:
		var box := BoxShape3D.new()
		box.size = PART_SIZES[key]
		box.margin = QUERY_MARGIN
		shapes[key] = box
	var limb := BoxShape3D.new()
	limb.size = LIMB_SIZE
	limb.margin = QUERY_MARGIN
	shapes["limb"] = limb
	_query.collision_mask = 2
	_query.collide_with_areas = false

func capture_proxies(rider: Node3D) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for key in rider.visuals:
		var part: Node3D = rider.visuals[key]
		if not is_instance_valid(part): continue
		var shape: BoxShape3D = shapes[key if shapes.has(key) else "limb"]
		result.append({"id":str(key), "shape":shape, "local_transform":rider.global_transform.affine_inverse() * part.global_transform})
	return result

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
	for proxy in end_proxies: ends[proxy.id] = proxy.local_transform
	var earliest: Dictionary = {}
	for proxy in proxies:
		var local_from: Transform3D = proxy.local_transform
		var local_to: Transform3D = ends.get(proxy.id,local_from)
		var shape: BoxShape3D = proxy.shape
		var radius: float = maxf(local_from.origin.length(),local_to.origin.length()) + shape.size.length() * .5
		var angle: float = _angle(previous.basis,next.basis) + _angle(local_from.basis,local_to.basis)
		var travel: float = previous.origin.distance_to(next.origin) + radius * angle + local_from.origin.distance_to(local_to.origin)
		var steps: int = maxi(1,maxi(int(ceil(travel / MAX_STEP_TRAVEL)),int(ceil(angle / MAX_STEP_ANGLE))))
		for index in steps:
			var a: float = float(index) / steps
			if not earliest.is_empty() and a > earliest.fraction: break
			var b: float = float(index + 1) / steps
			if not earliest.is_empty(): b = minf(b,earliest.fraction)
			var hit := _search(space,previous,next,local_from,local_to,shape,radius,a,b,eligible,excluded,0)
			if not hit.is_empty():
				hit.proxy_id = proxy.id
				if earliest.is_empty() or hit.fraction < earliest.fraction: earliest = hit
				break
	return earliest

func _search(space: PhysicsDirectSpaceState3D, previous: Transform3D, next: Transform3D,
		local_from: Transform3D, local_to: Transform3D, shape: BoxShape3D, radius: float,
		a: float, b: float, eligible: Dictionary, excluded: Array[RID], depth: int) -> Dictionary:
	var root_a: Transform3D = previous.interpolate_with(next,a)
	var root_b: Transform3D = previous.interpolate_with(next,b)
	var local_a: Transform3D = local_from.interpolate_with(local_to,a)
	var local_b: Transform3D = local_from.interpolate_with(local_to,b)
	var root_angle: float = _angle(root_a.basis,root_b.basis)
	var local_angle: float = _angle(local_a.basis,local_b.basis)
	var half_shape: float = shape.size.length() * .5
	# A midpoint-oriented box plus this Minkowski margin contains every rotating
	# corner during the segment, including local part animation. It only selects
	# candidates. Recursion reduces angular overreach below the contact tolerance.
	var angular_margin: float = 2.0 * radius * sin(root_angle * .25) + local_a.origin.distance_to(local_b.origin) * .5 + 2.0 * half_shape * sin(local_angle * .25)
	var middle: float = (a + b) * .5
	var middle_root: Transform3D = previous.interpolate_with(next,middle)
	var middle_pose: Transform3D = middle_root * local_from.interpolate_with(local_to,middle)
	var cast_start := Transform3D(middle_pose.basis,root_a.origin + middle_pose.origin - middle_root.origin)
	var motion: Vector3 = root_b.origin - root_a.origin
	var candidate := _query_bound(space,shape,cast_start,motion,QUERY_MARGIN + angular_margin,eligible,excluded)
	if candidate.is_empty(): return {}
	var boundary_travel: float = motion.length() + 2.0 * radius * sin(root_angle * .5) + local_a.origin.distance_to(local_b.origin) + 2.0 * half_shape * sin(local_angle * .5)
	if boundary_travel <= LEAF_TRAVEL or depth >= 22:
		# Accept only a narrow query against the real oriented proxy. A broad
		# angular margin near a tangential pass can otherwise move the contact
		# many centimeters along the route despite a sub-millimeter hull bound.
		candidate = _query_bound(space,shape,root_a * local_a,Vector3.ZERO,0.0,eligible,excluded)
		if not candidate.is_empty(): candidate.fraction = 0.0
		else:
			candidate = _query_bound(space,shape,middle_pose,Vector3.ZERO,0.0,eligible,excluded)
			if not candidate.is_empty(): candidate.fraction = .5
			else:
				candidate = _query_bound(space,shape,root_b * local_b,Vector3.ZERO,0.0,eligible,excluded)
				if candidate.is_empty(): return {}
				candidate.fraction = 1.0
		candidate.fraction = clampf(lerpf(a,b,candidate.fraction),0.0,1.0)
		candidate.transform = previous.interpolate_with(next,candidate.fraction)
		candidate.error_bound = boundary_travel + QUERY_MARGIN * 3.0
		return candidate
	var left := _search(space,previous,next,local_from,local_to,shape,radius,a,middle,eligible,excluded,depth + 1)
	if not left.is_empty(): return left
	return _search(space,previous,next,local_from,local_to,shape,radius,middle,b,eligible,excluded,depth + 1)

func _query_bound(space: PhysicsDirectSpaceState3D, shape: BoxShape3D, at: Transform3D,
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
