extends SceneTree

const TestFixtures = preload("res://tests/test_fixtures.gd")
const Contacts = preload("res://scripts/skating_contacts.gd")
const Rules = preload("res://scripts/game_rules.gd")
var fixtures = TestFixtures.new("test_skating_contacts")
var checks: int = 0
var failures: int = 0
var arena: Node3D
var game: Node3D
var helper = Contacts.new()
var cases: Array[Dictionary] = []

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ",message)

func _initialize() -> void: call_deferred("run")

func prop_at(label: String, size: Vector3, at: Vector3, rotation: Vector3 = Vector3.ZERO) -> CrashProp:
	var prop := CrashProp.new()
	prop.name = label
	prop.freeze = true
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	box.margin = .00001
	collision.shape = box
	prop.add_child(collision)
	arena.add_child(prop)
	prop.position = at
	prop.rotation = rotation
	return prop

func independent_proxy(size: Vector3, at: Vector3 = Vector3.ZERO) -> Array[Dictionary]:
	var box := BoxShape3D.new()
	box.size = size
	box.margin = .00001
	return [{"id":"oracle_box","shape":box,"local_transform":Transform3D(Basis.IDENTITY,at)}]

# Independent narrow-phase oracle: actual collision shapes at a fine sequence of
# exact orientations, no cast bound, radius heuristic, or production helper call.
func oracle_hit(space: PhysicsDirectSpaceState3D, transform: Transform3D, proxies: Array, props: Array) -> bool:
	for proxy in proxies:
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = proxy.shape
		query.transform = transform * proxy.local_transform
		query.collision_mask = 2
		query.margin = 0.0
		for hit in space.intersect_shape(query,64):
			if props.has(hit.collider): return true
	return false

func oracle_first(space: PhysicsDirectSpaceState3D, a: Transform3D, b: Transform3D, proxies: Array, props: Array, subdivisions: int = 4096) -> float:
	for i in subdivisions + 1:
		var fraction: float = float(i) / subdivisions
		if oracle_hit(space,a.interpolate_with(b,fraction),proxies,props): return fraction
	return -1.0

func compare_case(label: String, a: Transform3D, b: Transform3D, proxies: Array, props: Array, should_hit: bool, subdivisions: int = 4096) -> Dictionary:
	var space: PhysicsDirectSpaceState3D = arena.get_world_3d().direct_space_state
	var first: float = oracle_first(space,a,b,proxies,props,subdivisions)
	var hit: Dictionary = helper.find_obstruction(space,a,b,proxies,props)
	check((first >= 0.0) == should_hit,label+" independent physical oracle")
	check(not hit.is_empty() == should_hit,label+" accepted contact agrees with actual hull")
	var case: Dictionary = {"name":label,"oracle_first":first,"expected_contact":should_hit,"query_count":helper.query_count,"fraction":hit.get("fraction",-1.0)}
	if not hit.is_empty():
		check(is_finite(hit.fraction) and hit.fraction >= 0.0 and hit.fraction <= 1.0,label+" finite bounded fraction")
		check(hit.at.is_finite() and hit.normal.is_finite(),label+" finite world contact")
		check(hit.error_bound <= .002,label+" refined geometry error below two millimeters")
		if first >= 0.0:
			var length: float = a.origin.distance_to(b.origin) + proxies[0].shape.size.length() * .5 * a.basis.get_rotation_quaternion().angle_to(b.basis.get_rotation_quaternion())
			var error: float = absf(hit.fraction - first) * length
			case.contact_error_m = error
			check(error <= .002 + length / subdivisions,label+" earliest placement bracketed by fine independent samples")
	cases.append(case)
	return hit

func clear_arena() -> void:
	for child in arena.get_children(): child.queue_free()
	await process_frame
	await physics_frame

func run() -> void:
	arena = Node3D.new()
	root.add_child(arena)
	var board: Array = independent_proxy(Vector3(.76,.18,1.65),Vector3(0,.04,0))
	var taxi: CrashProp = prop_at("TaxiSide",Vector3(1.85,1.45,3.3),Vector3(3.3,.76,0))
	await physics_frame
	await physics_frame
	compare_case("clear taxi side",Transform3D(Basis.IDENTITY,Vector3(1.4,.23,-2.4)),Transform3D(Basis.IDENTITY,Vector3(1.4,.23,2.4)),board,[taxi],false)
	compare_case("inward taxi side",Transform3D(Basis.IDENTITY,Vector3(1.99,.23,-2.4)),Transform3D(Basis.IDENTITY,Vector3(2.02,.23,2.4)),board,[taxi],true)
	compare_case("taxi front",Transform3D(Basis.IDENTITY,Vector3(3.3,.23,-4)),Transform3D(Basis.IDENTITY,Vector3(3.3,.23,0)),board,[taxi],true)
	await clear_arena()
	var thin: CrashProp = prop_at("ThinDomino",Vector3(.92,2.12,.026),Vector3(0,1.06,0))
	await physics_frame
	compare_case("thin high speed",Transform3D(Basis.IDENTITY,Vector3(0,.23,-2)),Transform3D(Basis.IDENTITY,Vector3(0,.23,2)),board,[thin],true)
	compare_case("neighboring clear thin",Transform3D(Basis.IDENTITY,Vector3(.845,.23,-2)),Transform3D(Basis.IDENTITY,Vector3(.845,.23,2)),board,[thin],false)
	await clear_arena()
	var tilted: CrashProp = prop_at("RotatedTipped",Vector3(.92,2.12,.26),Vector3(0,.8,0),Vector3(.72,.64,.2))
	await physics_frame
	compare_case("rotated tipped hull",Transform3D(Basis(Vector3.UP,-.2),Vector3(0,.23,-2)),Transform3D(Basis(Vector3.UP,.2),Vector3(0,.23,2)),board,[tilted],true)
	await clear_arena()
	var excluded: CrashProp = prop_at("BrokenFirst",Vector3(1,1,.10),Vector3(0,.5,-1))
	excluded.broken = true
	var traffic: CrashProp = prop_at("TrafficSecond",Vector3(1,1,.10),Vector3(0,.5,-.5))
	traffic.set_meta("traffic",true)
	var target: CrashProp = prop_at("EligibleThird",Vector3(1,1,.02),Vector3(0,.5,1))
	await physics_frame
	var eligible_hit := compare_case("excluded first colliders",Transform3D(Basis.IDENTITY,Vector3(0,.23,-3)),Transform3D(Basis.IDENTITY,Vector3(0,.23,3)),board,[target],true)
	var all_hit: Dictionary = helper.find_obstruction(arena.get_world_3d().direct_space_state,Transform3D(Basis.IDENTITY,Vector3(0,.23,-3)),Transform3D(Basis.IDENTITY,Vector3(0,.23,3)),board,[excluded,traffic,target])
	check(not all_hit.is_empty() and all_hit.collider == target,"broken and traffic RIDs excluded before earliest sweep")
	check(not eligible_hit.is_empty() and not all_hit.is_empty() and absf(eligible_hit.fraction-all_hit.fraction) < .0001,"excluded objects cannot hide a later eligible hit")
	var start_hit: Dictionary = helper.find_obstruction(arena.get_world_3d().direct_space_state,Transform3D(Basis.IDENTITY,Vector3(0,.23,1)),Transform3D(Basis.IDENTITY,Vector3(0,.23,1.1)),board,[target])
	check(not start_hit.is_empty() and start_hit.fraction == 0.0,"initial eligible overlap returns the initial root before cast_motion")
	check(not target.armed and not excluded.armed and not traffic.armed,"contact queries cannot activate property")
	await clear_arena()
	# This contact exists between clear endpoint AND midpoint orientations. A
	# fixed-orientation sampled cast would miss it; the angular bound must find it.
	var needle: Array = independent_proxy(Vector3(2,.2,.006))
	var graze: CrashProp = prop_at("IntermediateTurn",Vector3(.006,.2,.006),Vector3(.97,0,.0074))
	await physics_frame
	var turn_a := Transform3D(Basis(Vector3.UP,-.04),Vector3.ZERO)
	var turn_b := Transform3D(Basis(Vector3.UP,.04),Vector3.ZERO)
	var space: PhysicsDirectSpaceState3D = arena.get_world_3d().direct_space_state
	check(not oracle_hit(space,turn_a,needle,[graze]) and not oracle_hit(space,turn_b,needle,[graze]) and not oracle_hit(space,turn_a.interpolate_with(turn_b,.5),needle,[graze]),"turning grazing fixture clears endpoints and midpoint sample")
	compare_case("intermediate right turn",turn_a,turn_b,needle,[graze],true,16384)
	compare_case("intermediate left turn",turn_b,turn_a,needle,[graze],true,16384)
	graze.position.z = .055
	await physics_frame
	compare_case("positive clearance turn",turn_a,turn_b,needle,[graze],false,8192)
	await clear_arena()
	game = fixtures.create_game(root)
	if game == null: return
	for pose in 3:
		game.skater.set_pose(pose)
		var captured: Array = helper.capture_proxies(game.skater)
		check(captured.size() == 12,"pose %d caches all physical parts including board" % pose)
		var reused: Array = helper.capture_proxies(game.skater)
		check(captured[0].shape == reused[0].shape,"pose %d reuses shape resources" % pose)
		var furthest_arm: float = 0.0
		for proxy in captured:
			if proxy.id in ["arm_l","arm_r","fore_l","fore_r"]: furthest_arm = maxf(furthest_arm,absf(proxy.local_transform.origin.x))
		check(furthest_arm > (.80 if pose == 1 else .25),"pose %d proxies follow actual selected silhouette" % pose)
	# Use the authored real route treads as the oracle, with root-center downward
	# rays. Samples avoid exact shared edges where either adjacent face is valid.
	for route in 3:
		game.select_route(route)
		await physics_frame
		await physics_frame
		var level: Dictionary = Rules.LEVELS[route]
		var route_max_clearance: float = 0.0
		for tick in 350:
			var z: float = -.5 + tick * .137 + .000071
			if z > level.steps * level.run + .4: break
			var ray := PhysicsRayQueryParameters3D.create(Vector3(-4.7,30,z),Vector3(-4.7,-2,z),1)
			var support: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(ray)
			check(not support.is_empty(),"route %d actual tread support exists at %.3f" % [route,z])
			if support.is_empty(): continue
			var clearance: float = absf(helper.grounded_height(level,z) - .23 - support.position.y)
			route_max_clearance = maxf(route_max_clearance,clearance)
			check(clearance <= .03,"route %d support reference follows real tread within 3 cm at %.3f (ground %.3f, hit %.3f %s)" % [route,z,helper.grounded_height(level,z)-.23,support.position.y,support.collider.name])
		cases.append({"name":"route %d real tread support" % route,"max_clearance":route_max_clearance})
	game.queue_free()
	arena.queue_free()
	await process_frame
	await process_frame
	var file := FileAccess.open(fixtures.artifact_path("contacts.json"),FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"cases":cases,"checks":checks,"failures":failures},"\t"))
		file.close()
	else: check(false,"contact evidence file opens")
	print("SKATING_CONTACTS: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
