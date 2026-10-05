extends SceneTree

const Policy = preload("res://scripts/crash_camera.gd")
var checks: int = 0
var failures: int = 0
var world: Node3D
var space: PhysicsDirectSpaceState3D
var reports: Array[Dictionary] = []

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: ", message)

func box(at: Vector3, size: Vector3, layer: int = 2) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = layer
	body.collision_mask = 0
	body.position = at
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	body.add_child(collider)
	world.add_child(body)
	return body

func synchronize() -> void:
	await physics_frame
	await physics_frame

# These oracles construct their own queries against real collider geometry.
# They do not call Policy.clear_view/lens_clear/path_fraction or share its shape.
func independent_lens_clear(at: Vector3, mask: int = 3) -> bool:
	var point := PhysicsPointQueryParameters3D.new()
	point.position = at
	point.collision_mask = mask
	if not space.intersect_point(point, 1).is_empty(): return false
	var envelope := SphereShape3D.new()
	envelope.radius = .22
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = envelope
	query.transform = Transform3D(Basis.IDENTITY, at)
	query.collision_mask = mask
	return space.intersect_shape(query, 1).is_empty()

func independent_sight(from: Vector3, target: Vector3) -> bool:
	var offset := from - target
	if offset.length() < .001: return true
	var end := target + offset.normalized() * minf(.35, offset.length() * .5)
	var ray := PhysicsRayQueryParameters3D.create(from, end, 3)
	ray.hit_from_inside = true
	return space.intersect_ray(ray).is_empty()

func independent_path(from: Vector3, to: Vector3) -> bool:
	for sample in range(33):
		if not independent_lens_clear(from.lerp(to, float(sample) / 32.0)): return false
	var envelope := SphereShape3D.new()
	envelope.radius = .22
	var swept := PhysicsShapeQueryParameters3D.new()
	swept.shape = envelope
	swept.transform = Transform3D(Basis.IDENTITY, from)
	swept.motion = to - from
	swept.collision_mask = 3
	var fractions := space.cast_motion(swept)
	return fractions.size() == 2 and fractions[0] >= .99999

func support_height(at: Vector3) -> float:
	var ray := PhysicsRayQueryParameters3D.create(Vector3(at.x, 50, at.z), Vector3(at.x, -50, at.z), 1)
	var hit := space.intersect_ray(ray)
	return float(hit.position.y) if not hit.is_empty() else 0.0

func context() -> Dictionary:
	return {"space": space, "mask": 3, "floor_height": support_height}

func validate(result: Dictionary, name: String, require_sight: bool = true) -> void:
	var transform: Transform3D = result.transform
	check(result.safe, name + ": policy reports a verified lens")
	check(transform.origin.is_finite() and transform.basis.x.is_finite() and transform.basis.y.is_finite() and transform.basis.z.is_finite(), name + ": transform is finite")
	check(is_finite(result.fov) and result.fov >= 1 and result.fov <= 179, name + ": FOV is finite and bounded")
	check(independent_lens_clear(transform.origin), name + ": independent real collider lens envelope is clear")
	check(transform.origin.y >= support_height(transform.origin) + 1.5 - .0001, name + ": lens clears independently queried support")
	var direction: Vector3 = result.target - transform.origin
	var forward := -transform.basis.z.normalized()
	var aim_error := rad_to_deg(acos(clampf(forward.dot(direction.normalized()), -1.0, 1.0)))
	check(aim_error <= .1, name + ": final actual orientation aims after every correction")
	if require_sight: check(independent_sight(transform.origin, result.target), name + ": separately constructed sight ray is clear")
	reports.append({"case": name, "lens": str(transform.origin), "aim_error_degrees": aim_error, "diagnostic": result.diagnostic})

func run() -> void:
	world = Node3D.new()
	root.add_child(world)
	space = world.get_world_3d().direct_space_state
	box(Vector3(0, -.5, 0), Vector3(100, 1, 100), 1)
	await synchronize()
	var focus := Vector3(0, 1, 0)
	var desired := Vector3(5.8, 3.4, -6.8)
	var policy := Policy.new()
	var clear: Dictionary = policy.update("CRASH", 0, focus, desired, 1.0 / 60.0, context(), Transform3D(Basis.IDENTITY, desired))
	validate(clear, "unobstructed_chase")
	check(clear.transform.origin.is_equal_approx(desired), "unobstructed chase preserves intended baseline composition")
	var rider := box(desired, Vector3.ONE * 2, 4)
	await synchronize()
	check(not independent_lens_clear(desired, 4), "rider-layer control is a real solid containing the lens")
	check(Policy.choose_position(space, focus, desired, 0.0).is_equal_approx(desired), "mask excludes actual rider-layer collider")
	rider.queue_free()
	await synchronize()
	var solid := box(desired, Vector3.ONE)
	await synchronize()
	check(not independent_lens_clear(desired), "independent shape/point oracle confirms candidate starts inside real solid")
	check(not Policy.clear_view(space, desired, focus), "production rejects inside-origin candidate")
	var collider_before := solid.global_transform
	policy.reset()
	var inside: Dictionary = policy.update("CRASH", 0, focus, desired, .02, context(), Transform3D(Basis.IDENTITY, desired))
	validate(inside, "inside_origin")
	check(inside.diagnostic.initial_overlap_or_floor_violation, "inside-origin correction is diagnosed")
	check(solid.global_transform == collider_before, "camera queries leave collider transform untouched")
	solid.queue_free()
	await synchronize()
	var cart := box((focus + desired) * .5, Vector3(1, 2, 1))
	await synchronize()
	check(not independent_sight(desired, focus), "cart independently blocks initial sight")
	policy.reset()
	var cart_view: Dictionary = policy.update("CRASH", 0, focus, desired, .02, context(), Transform3D(Basis.IDENTITY, desired))
	validate(cart_view, "cart_raise")
	check(cart_view.transform.origin.x > 0 and cart_view.transform.origin.y > desired.y, "cart first chooses a same-side raise")
	check(cart_view.transform.origin.distance_to(focus) <= desired.distance_to(focus) * 1.6, "cart keeps original chase distance envelope")
	cart.queue_free()
	await synchronize()
	var tower := box((focus + desired) * .5, Vector3(3, 10, 3))
	await synchronize()
	policy.reset()
	var tower_view: Dictionary = policy.update("CRASH", 0, focus, desired, .02, context(), Transform3D(Basis.IDENTITY, desired))
	validate(tower_view, "tower_mirror")
	check(tower_view.transform.origin.x < 0, "tower uses bounded mirrored fallback after same-side candidates")
	tower.queue_free()
	await synchronize()
	var below := Vector3(5, -3, -6)
	policy.reset()
	var floor_view: Dictionary = policy.update("RUN", 0, focus, below, .02, context(), Transform3D(Basis.IDENTITY, below), 58, 58)
	validate(floor_view, "floor_before_aim")
	check(floor_view.diagnostic.floor_corrected, "below-floor correction is reported")
	var starts := Vector3(-4, 3, -7)
	var ends := Vector3(4, 3, -7)
	var wall := box(Vector3(0, 3, -7), Vector3(1, 4, 2))
	await synchronize()
	check(independent_lens_clear(starts) and independent_lens_clear(ends), "path negative fixture has two clear endpoints")
	check(not independent_path(starts, ends), "independent sweep and samples detect solid between endpoints")
	policy.reset()
	var initial: Dictionary = policy.update("CRASH", 0, focus, starts, .02, context(), Transform3D(Basis.IDENTITY, starts))
	var travel: Dictionary = policy.update("CRASH", 0, focus, ends, 1.0, context(), initial.transform)
	validate(travel, "blocked_intermediate_path")
	check(travel.diagnostic.path_clipped, "blocked interpolation path is shortened rather than blindly lerped")
	check(independent_path(starts, travel.transform.origin), "actual shortened lens path is independently collision-free")
	wall.position = travel.transform.origin
	await synchronize()
	check(not independent_lens_clear(travel.transform.origin), "moving solid really invalidates previous safe lens")
	var displaced: Dictionary = policy.update("CRASH", 0, focus, ends, .02, context(), travel.transform)
	validate(displaced, "moving_solid_invalidates_history")
	check(displaced.diagnostic.initial_overlap_or_floor_violation, "moving-solid discontinuity is documented")
	wall.queue_free()
	await synchronize()
	for style in range(3):
		var offset: Vector3 = [Vector3(5.8, 3.4, -6.8), Vector3(17, 10, 8), Vector3(0, 22, 4)][style]
		var style_view: Dictionary = policy.update("REPLAY", style, focus, focus + offset, .02, context(), displaced.transform)
		validate(style_view, "caller_supplied_focus_style_%d" % style)
		check(style_view.diagnostic.view_mode == style, "view style is explicit caller context")
	policy.reset()
	var traffic_focus := Vector3(12, 1, 12)
	var traffic_view: Dictionary = policy.update("CRASH", 0, traffic_focus, traffic_focus + Vector3(8.5, 6.2, -11), .02, context(), displaced.transform, 52, 52, Vector3(100, 100, 0))
	validate(traffic_view, "supplied_traffic_focus")
	check(traffic_view.target.distance_to(traffic_focus) <= .60001, "shake is bounded on target and cannot displace lens")
	var stationary: Transform3D = traffic_view.transform
	var maximum_jump: float = 0.0
	for frame in range(12):
		var steady: Dictionary = policy.update("CRASH", 0, traffic_focus, traffic_focus + Vector3(8.5, 6.2, -11), 1.0 / 60.0, context(), stationary)
		maximum_jump = maxf(maximum_jump, stationary.origin.distance_to(steady.transform.origin))
		check(independent_lens_clear(steady.transform.origin), "fixed timestep final lens remains independently clear")
		stationary = steady.transform
	check(maximum_jump < .0001, "unchanged composition does not oscillate among bounded candidates")
	policy.reset()
	var degenerate_position := Vector3(0, 3, 0)
	var degenerate: Dictionary = policy.update("READY", 0, degenerate_position, degenerate_position, .02, context(), Transform3D(Basis.IDENTITY, degenerate_position), NAN, NAN)
	validate(degenerate, "degenerate_aim")
	check(degenerate.diagnostic.degenerate_aim, "degenerate look direction uses documented finite forward fallback")
	var enclosure := box(Vector3(0, 10, 0), Vector3.ONE * 200)
	await synchronize()
	var enclosed: Dictionary = policy.update("CRASH", 0, focus, desired, .02, context(), degenerate.transform)
	check(not enclosed.safe and not policy.has_last_safe, "fully enclosed world cannot reuse stale safety or claim a verified fallback")
	check(enclosed.diagnostic.fallback_reason == "no_verified_position", "impossible bounded placement is explicitly diagnosed")
	enclosure.queue_free()
	world.queue_free()
	await process_frame
	print("CAMERA_GEOMETRY: %d checks, %d failures; %s" % [checks, failures, JSON.stringify(reports)])
	quit(1 if failures else 0)
