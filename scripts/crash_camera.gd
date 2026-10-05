class_name CrashCamera
extends RefCounted

# Mask 3 sees level geometry and wreckable props, but ignores rider bodies (layer 4).
const WORLD_MASK: int = 3
const FLOOR_CLEARANCE: float = 1.5
const LENS_RADIUS: float = .22
const PATH_MARGIN: float = .002
const SUBJECT_MARGIN: float = .35
const MAX_SHAKE: float = .6

var last_safe_position := Vector3.ZERO
var has_last_safe: bool = false
var smoothed_focus := Vector3.ZERO
var has_focus: bool = false
var reset_pending: bool = true
var last_view_mode: int = -1

func reset() -> void:
	has_last_safe = false
	has_focus = false
	reset_pending = true
	last_view_mode = -1

static func lens_clear(space: PhysicsDirectSpaceState3D, at: Vector3, mask: int = WORLD_MASK, exclude: Array[RID] = []) -> bool:
	if space == null or not at.is_finite(): return false
	var shape := SphereShape3D.new()
	shape.radius = LENS_RADIUS
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, at)
	query.collision_mask = mask
	query.exclude = exclude
	query.collide_with_areas = false
	return space.intersect_shape(query, 1).is_empty()

static func clear_view(space: PhysicsDirectSpaceState3D, from: Vector3, target: Vector3, mask: int = WORLD_MASK, exclude: Array[RID] = []) -> bool:
	if not target.is_finite() or not lens_clear(space, from, mask, exclude): return false
	var toward: Vector3=from-target
	if toward.length_squared()<.01: return true
	# Stop short of the rider: a prop next to the body must not look like a wall.
	var to: Vector3=target+toward.normalized()*minf(SUBJECT_MARGIN, toward.length()*.5)
	var query:=PhysicsRayQueryParameters3D.create(from,to,mask,exclude)
	query.hit_from_inside = true
	return space.intersect_ray(query).is_empty()

static func _floor_at(context: Dictionary, at: Vector3) -> float:
	var floor_y: float = float(context.get("floor_y", 0.0))
	var support: Callable = context.get("floor_height", Callable())
	if support.is_valid(): floor_y = float(support.call(at))
	return floor_y if is_finite(floor_y) else 0.0

static func _above_floor(context: Dictionary, at: Vector3) -> Vector3:
	var corrected := at
	corrected.y = maxf(corrected.y, _floor_at(context, at) + FLOOR_CLEARANCE)
	return corrected

static func _candidates(target: Vector3, desired: Vector3, context: Dictionary) -> Array[Vector3]:
	var base := _above_floor(context, desired)
	var offset := base - target
	var floor_y := _floor_at(context, base)
	var ceiling := maxf(maxf(floor_y + 11.0, target.y + 7.0), base.y + 4.8)
	var result: Array[Vector3] = [base]
	for lift in [2.6, 4.8]:
		var raised: Vector3 = base + Vector3.UP * float(lift)
		raised.y = minf(raised.y, ceiling)
		result.append(_above_floor(context, raised))
	# Keep the original same-side raises/shoulder before mirroring the view.
	var shoulder := target + Vector3(offset.x * 1.6, offset.y + 3.3, offset.z)
	shoulder.y = minf(shoulder.y, ceiling)
	if shoulder.distance_to(target) < offset.length() * 1.55:
		result.append(_above_floor(context, shoulder))
	var mirrored := target + Vector3(-offset.x, offset.y + 2.6, offset.z)
	mirrored.y = minf(mirrored.y, ceiling)
	result.append(_above_floor(context, mirrored))
	var shifted := base + Vector3(0.0, 2.6, -2.0)
	if shifted.distance_to(target) <= maxf(offset.length() * 1.55, 3.0):
		result.append(_above_floor(context, shifted))
	var overhead := target + Vector3(0.0, minf(offset.length(), 7.0), offset.z * .4)
	if overhead.distance_to(target) <= maxf(offset.length() * 1.55, 3.0):
		result.append(_above_floor(context, overhead))
	return result

static func _pick(space: PhysicsDirectSpaceState3D, target: Vector3, desired: Vector3, context: Dictionary,
		last_safe: Vector3, use_last_safe: bool) -> Dictionary:
	var mask: int = int(context.get("mask", WORLD_MASK))
	var exclude: Array[RID] = []
	exclude.assign(context.get("exclude", []))
	var candidates := _candidates(target, desired, context)
	var first_clear := -1
	for index in candidates.size():
		var candidate: Vector3 = candidates[index]
		if not lens_clear(space, candidate, mask, exclude): continue
		if first_clear < 0: first_clear = index
		if clear_view(space, candidate, target, mask, exclude):
			return {"position": candidate, "safe": true, "sight_clear": true,
				"candidate_index": index, "fallback_reason": "", "candidates_considered": index + 1}
	if use_last_safe and last_safe.y >= _floor_at(context, last_safe) + FLOOR_CLEARANCE and lens_clear(space, last_safe, mask, exclude):
		return {"position": last_safe, "safe": true, "sight_clear": clear_view(space, last_safe, target, mask, exclude),
			"candidate_index": -1, "fallback_reason": "revalidated_last_safe", "candidates_considered": candidates.size()}
	if first_clear >= 0:
		# Geometry safety takes priority when every bounded sight line is occluded.
		return {"position": candidates[first_clear], "safe": true, "sight_clear": false,
			"candidate_index": first_clear, "fallback_reason": "bounded_occluded_fallback", "candidates_considered": candidates.size()}
	# A completely enclosed lens has no honest safe answer within the envelope.
	# Callers receive safe=false and must not label this a verified placement.
	return {"position": candidates[0], "safe": false, "sight_clear": false,
		"candidate_index": -1, "fallback_reason": "no_verified_position", "candidates_considered": candidates.size()}

static func choose_position(space: PhysicsDirectSpaceState3D, target: Vector3, desired: Vector3, floor_y: float) -> Vector3:
	if not target.is_finite(): target = Vector3.ZERO
	if not desired.is_finite(): desired = target + Vector3(5.8, 4.5, -6.8)
	var chosen := _pick(space, target, desired, {"floor_y": floor_y}, Vector3.ZERO, false)
	return chosen.position

static func path_fraction(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3,
		mask: int = WORLD_MASK, exclude: Array[RID] = []) -> float:
	if not lens_clear(space, from, mask, exclude) or not to.is_finite(): return 0.0
	if from.distance_squared_to(to) < .0000001: return 1.0
	var shape := SphereShape3D.new()
	shape.radius = LENS_RADIUS
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, from)
	query.motion = to - from
	query.collision_mask = mask
	query.exclude = exclude
	query.collide_with_areas = false
	var fractions := space.cast_motion(query)
	if fractions.size() != 2: return 0.0
	var safe_fraction: float = clampf(fractions[0], 0.0, 1.0)
	if safe_fraction < 1.0:
		safe_fraction = maxf(0.0, safe_fraction - PATH_MARGIN / from.distance_to(to))
	return safe_fraction

# The caller owns phase/view composition, support sampling, world/proxy space,
# render clock, and the camera node. This API never captures a live skater.
func update(phase: String, view_mode: int, focus: Vector3, desired: Vector3, presentation_delta: float,
		query_context: Dictionary, current_transform: Transform3D, current_fov: float = 52.0,
		target_fov: float = 52.0, shake: Vector3 = Vector3.ZERO) -> Dictionary:
	if last_view_mode >= 0 and last_view_mode != view_mode: reset()
	last_view_mode = view_mode
	var space: PhysicsDirectSpaceState3D = query_context.get("space")
	var mask: int = int(query_context.get("mask", WORLD_MASK))
	var exclude: Array[RID] = []
	exclude.assign(query_context.get("exclude", []))
	var invalid_input := not focus.is_finite() or not desired.is_finite() or not is_finite(presentation_delta)
	if not focus.is_finite(): focus = Vector3.ZERO
	if not desired.is_finite(): desired = focus + Vector3(5.8, 4.5, -6.8)
	if not is_finite(presentation_delta): presentation_delta = 0.0
	var blend := 1.0 - exp(-maxf(presentation_delta, 0.0) * 4.0)
	if reset_pending or not has_focus:
		smoothed_focus = focus
	else:
		smoothed_focus = smoothed_focus.lerp(focus, blend)
	has_focus = true
	var picked := _pick(space, smoothed_focus, desired, query_context, last_safe_position, has_last_safe)
	var destination: Vector3 = picked.position
	var start: Vector3 = current_transform.origin
	var start_clear := start.is_finite() and start.y >= _floor_at(query_context, start) + FLOOR_CLEARANCE and lens_clear(space, start, mask, exclude)
	var lens := destination
	var clipped := false
	var used_reset := reset_pending
	if start_clear and not reset_pending and picked.safe:
		lens = _above_floor(query_context, start.lerp(destination, blend))
		var fraction := path_fraction(space, start, lens, mask, exclude)
		if fraction < 1.0:
			lens = start.lerp(lens, fraction)
			clipped = true
	var floor_corrected := desired.y < _floor_at(query_context, desired) + FLOOR_CLEARANCE
	var final_safe := lens.y >= _floor_at(query_context, lens) + FLOOR_CLEARANCE and lens_clear(space, lens, mask, exclude)
	if not final_safe and has_last_safe and lens_clear(space, last_safe_position, mask, exclude) and last_safe_position.y >= _floor_at(query_context, last_safe_position) + FLOOR_CLEARANCE:
		lens = last_safe_position
		final_safe = true
		picked.fallback_reason = "revalidated_last_safe"
	if final_safe:
		last_safe_position = lens
		has_last_safe = true
	else:
		has_last_safe = false
	reset_pending = false
	if not shake.is_finite(): shake = Vector3.ZERO
	if shake.length() > MAX_SHAKE: shake = shake.normalized() * MAX_SHAKE
	var aim := smoothed_focus + shake
	var direction := aim - lens
	var degenerate := direction.length_squared() < .0000001
	if degenerate:
		aim = lens + Vector3.FORWARD
		direction = Vector3.FORWARD
	var up := Vector3.UP
	if absf(direction.normalized().dot(up)) > .999: up = Vector3.FORWARD
	var final_transform := Transform3D(Basis.IDENTITY, lens).looking_at(aim, up)
	if not is_finite(current_fov): current_fov = 52.0
	if not is_finite(target_fov): target_fov = 52.0
	var fov := clampf(lerpf(current_fov, target_fov, 1.0 if used_reset else blend), 1.0, 179.0)
	return {"transform": final_transform, "fov": fov, "target": aim, "safe": final_safe,
		"diagnostic": {"phase": phase, "view_mode": view_mode, "lens_radius": LENS_RADIUS,
			"floor_clearance": FLOOR_CLEARANCE, "floor_corrected": floor_corrected,
			"initial_overlap_or_floor_violation": not start_clear, "path_clipped": clipped,
			"reset": used_reset, "candidate_index": picked.candidate_index,
			"candidates_considered": picked.candidates_considered, "fallback_reason": picked.fallback_reason,
			"sight_clear": final_safe and clear_view(space, lens, smoothed_focus, mask, exclude),
			"degenerate_aim": degenerate, "invalid_input": invalid_input}}
