class_name CrashCamera
extends RefCounted

# Mask 3 sees level geometry and wreckable props, but ignores rider bodies (layer 4).
const WORLD_MASK: int = 3
const FLOOR_CLEARANCE: float = 1.5

static func clear_view(space: PhysicsDirectSpaceState3D, from: Vector3, target: Vector3) -> bool:
	var toward: Vector3=from-target
	if toward.length_squared()<.01: return true
	# Stop short of the rider: a prop next to the body must not look like a wall.
	var to: Vector3=target+toward.normalized()*.35
	var query:=PhysicsRayQueryParameters3D.create(from,to,WORLD_MASK)
	return space.intersect_ray(query).is_empty()

static func choose_position(space: PhysicsDirectSpaceState3D, target: Vector3, desired: Vector3, floor_y: float) -> Vector3:
	if not target.is_finite() or not desired.is_finite() or not is_finite(floor_y): return Vector3(5.8,4.5,-6.8)
	var base: Vector3=desired
	base.y=maxf(base.y,floor_y+FLOOR_CLEARANCE)
	if clear_view(space,base,target): return base
	var offset: Vector3=base-target
	var ceiling: float=maxf(floor_y+11.0,target.y+7.0)
	for lift in [2.6,4.8]:
		var raised: Vector3=base+Vector3.UP*lift
		raised.y=minf(raised.y,ceiling)
		if clear_view(space,raised,target): return raised
	# A nearby cart may still fill the line from directly above; shift within the
	# same camera side before crossing the rider's screen direction.
	var shoulder: Vector3=target+Vector3(offset.x*1.6,offset.y+3.3,offset.z)
	shoulder.y=minf(shoulder.y,ceiling)
	if shoulder.distance_to(target)<offset.length()*1.55 and clear_view(space,shoulder,target): return shoulder
	var mirrored: Vector3=target+Vector3(-offset.x,offset.y+2.6,offset.z)
	mirrored.y=clampf(mirrored.y,floor_y+FLOOR_CLEARANCE,ceiling)
	if clear_view(space,mirrored,target): return mirrored
	return base
