extends SceneTree

const Fixtures = preload("res://tests/test_fixtures.gd")
var fixture = Fixtures.new("test_lifecycle")
var checks := 0
var failures := 0
var game: Node3D
var replacements: Array[Dictionary] = []
var taxi_cases: Array[Dictionary] = []
var collider_geometry: Array[Dictionary] = []
# Independent published physical contract, checked against real spawned shapes.
# The torso box encloses its final convex rings and is conservative for clearance.
const SIZES := {"torso":Vector3(.68,.70,.44),"pelvis":Vector3(.52,.28,.38),
	"head":Vector3(.44,.48,.42),"board":Vector3(.76,.18,1.65),
	"fore_l":Vector3(.28,.44,.30),"fore_r":Vector3(.28,.44,.30)}
const OFFSETS := {"torso":Vector3(0,.04,0),"fore_l":Vector3(0,-.03,0),"fore_r":Vector3(0,-.03,0)}

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: ", message)

func counts() -> Dictionary:
	var result := {"tree_nodes":get_node_count(),"rigid_bodies":0,"joints":0,"players":0,"replay_roots":0,"replay_queries":0,
		"orphan_nodes":int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))}
	var pending: Array[Node] = [root]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		pending.append_array(node.get_children())
		if node is RigidBody3D: result.rigid_bodies += 1
		if node is Joint3D: result.joints += 1
		if node is AudioStreamPlayer or node is AudioStreamPlayer2D or node is AudioStreamPlayer3D: result.players += 1
		if node.name == "ReplayPresentation": result.replay_roots += 1
		if str(node.name).begins_with("ReplayQuery_"): result.replay_queries += 1
	return result

func settle_frees() -> void:
	await process_frame
	await process_frame
	await physics_frame

func validate_physical_shapes() -> void:
	for key in game.skater.body_parts:
		var body: RigidBody3D = game.skater.body_parts[key]
		var shapes: Array[CollisionShape3D] = []
		for child in body.get_children():
			if child is CollisionShape3D: shapes.append(child)
		check(shapes.size() == 1,"independent hull oracle finds exactly one actual physical shape for "+str(key))
		if shapes.size() != 1: continue
		var shape: CollisionShape3D = shapes[0]
		var expected_size: Vector3 = SIZES.get(key,Vector3(.21,.35,.24))
		var expected_offset: Vector3 = OFFSETS.get(key,Vector3.ZERO)
		if key == "torso":
			check(shape.shape is ConvexPolygonShape3D,"published torso uses its actual convex physical hull")
			if not shape.shape is ConvexPolygonShape3D: continue
			var convex: ConvexPolygonShape3D = shape.shape
			var points: PackedVector3Array = convex.points
			check(points.size() == 16,"actual torso has exactly the sixteen published ring vertices")
			var literals := PackedVector3Array()
			for ring in 2:
				for i in 8:
					var angle := float(i)*TAU/8.0
					var literal := Vector3((.24 if ring == 0 else .34)*cos(angle),-.35 if ring == 0 else .35,
						(.18 if ring == 0 else .22)*sin(angle))
					literals.append(literal)
					var matched := false
					for actual in points:
						if actual.distance_to(literal) <= .000001: matched = true
					check(matched,"actual torso includes independent published ring%d vertex%d" % [ring,i])
			collider_geometry.append({"part":str(key),"actual_shape":"convex","actual_points":points,
				"literal_points":literals,"conservative_box_size":expected_size,"literal_offset":expected_offset})
		else:
			check(shape.shape is BoxShape3D,"independent hull oracle verifies actual BoxShape3D for "+str(key))
			if not shape.shape is BoxShape3D: continue
			var box: BoxShape3D = shape.shape
			check(box.size.is_equal_approx(expected_size),"published literal hull dimensions match actual physical part "+str(key))
			collider_geometry.append({"part":str(key),"actual_shape":"box","actual_size":box.size,
				"literal_size":expected_size,"literal_offset":expected_offset})
		check(shape.transform.is_equal_approx(Transform3D(Basis.IDENTITY,expected_offset)),"published literal hull offset matches actual physical part "+str(key))
		collider_geometry.back()["actual_local_transform"] = shape.transform

func replacement_matrix() -> void:
	var route_baselines := {}
	for iteration in 20:
		var route := iteration % 3
		game._replace_route(route)
		game.start_ready()
		await settle_frees()
		var baseline := counts()
		if route_baselines.has(route):
			check(baseline == route_baselines[route], "route%d settled construction counts remain stable at replacement%d" % [route,iteration])
		else:
			route_baselines[route] = baseline
		game.charge = .75
		game.launch()
		game.bail_out()
		if iteration == 0: validate_physical_shapes()
		for tick in 5: await physics_frame
		game.finish_run("manual")
		check(game.phase == game.Phase.RESULTS and game.replay_timeline.can_play(), "replacement%d seals real spawned body/timestamp tape" % iteration)
		game.start_replay()
		check(game.phase == game.Phase.REPLAY and is_instance_valid(game.replay_presentation.root), "replacement%d constructs private replay display" % iteration)
		game.toggle_pause()
		await process_frame
		await process_frame
		var displaying := counts()
		check(displaying.replay_roots == 1 and displaying.replay_queries > 0, "replacement%d owns exactly one bounded replay query scene" % iteration)
		check(displaying.players == baseline.players, "replacement%d replay allocates no extra sound players" % iteration)
		game.resume()
		if iteration % 2 == 0:
			game.retry()
		else:
			# Natural short-tape completion, then the supported result route action.
			var frames := 0
			while game.phase == game.Phase.REPLAY and frames < 60:
				await process_frame
				frames += 1
			check(game.phase == game.Phase.RESULTS, "replacement%d short playback finishes within sixty actual renders" % iteration)
			game.select_route(route)
			game.start_ready()
		await settle_frees()
		var restored := counts()
		check(game.phase == game.Phase.READY and game.replay_presentation.root == null and game.replay_catalog.is_empty(), "replacement%d discards prior display and detached catalog" % iteration)
		check(restored.replay_roots == 0 and restored.replay_queries == 0 and restored.joints == 0, "replacement%d removes all replay queries and old physical joints" % iteration)
		check(restored == baseline, "replacement%d exact settled node/body/player/orphan counts return to route baseline" % iteration)
		replacements.append({"iteration":iteration,"route":route+1,"exit":"retry" if iteration%2==0 else "replay_end_then_route",
			"before":baseline,"displaying":displaying,"after":restored})

func box_bounds(transform: Transform3D, size: Vector3) -> AABB:
	var half := size * .5
	var first := transform * -half
	var bounds := AABB(first,Vector3.ZERO)
	for x in [-1,1]:
		for y in [-1,1]:
			for z in [-1,1]: bounds = bounds.expand(transform * (half * Vector3(x,y,z)))
	return bounds

func taxi_bounds(taxi: CrashProp) -> AABB:
	for child in taxi.get_children():
		if child is CollisionShape3D and child.shape is BoxShape3D:
			return box_bounds(child.global_transform,child.shape.size)
	check(false,"authored taxi has a real box hull")
	return AABB()

func left_clearance(taxi: CrashProp) -> float:
	# Independent world-space bounds from literal physical sizes/offsets and actual
	# riding transforms. No contact helper, radius heuristic, or production proxy.
	var hull := taxi_bounds(taxi)
	var minimum := INF
	for key in game.skater.visuals:
		var part: Node3D = game.skater.visuals[key]
		var size: Vector3 = SIZES.get(key,Vector3(.21,.35,.24))
		var offset: Vector3 = OFFSETS.get(key,Vector3.ZERO)
		var bounds := box_bounds(part.global_transform * Transform3D(Basis.IDENTITY,offset),size)
		minimum = minf(minimum,hull.position.x - bounds.end.x)
	return minimum

func authored_taxi(seed_value: int, strike: bool) -> void:
	game._replace_route(0)
	game.start_ready()
	await settle_frees()
	var taxi: CrashProp
	for prop in game.world.props:
		if is_instance_valid(prop) and prop.kind == "taxi" and not prop.get_meta("traffic",false): taxi = prop; break
	check(taxi != null and taxi.visual.get_node_or_null("Body") != null, "actual authored premium taxi/model exists")
	if taxi == null: return
	# Isolate this real authored obstacle from other payable actors; preserve the
	# complete actual route/tread geometry and ordinary main controller.
	for prop in game.world.props:
		if is_instance_valid(prop) and prop != taxi: prop.free()
	game.world.props.assign([taxi])
	game.world.traffic.clear()
	var placement_rng := RandomNumberGenerator.new()
	placement_rng.seed = seed_value
	var jitter_x := placement_rng.randf_range(-.002,.002)
	var jitter_z := placement_rng.randf_range(-.002,.002)
	taxi.position.x += jitter_x
	game.charge = 1.0
	game.launch()
	# Explicit supported maximum-speed construction control, not earned gameplay
	# acceleration and not a global/random physics solver seed.
	game.run_speed = 31.0
	var start_z: float = taxi.global_position.z - 4.0 + jitter_z
	var start_x: float = taxi.global_position.x if strike else taxi.global_position.x - 1.9
	var query := PhysicsRayQueryParameters3D.create(Vector3(start_x,50,start_z),Vector3(start_x,-5,start_z),1)
	var support: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(query)
	check(not support.is_empty(), "maximum-speed taxi fixture starts over actual route support")
	if support.is_empty(): return
	game.skater.position = Vector3(start_x,float(support.position.y)+.23,start_z)
	game.skater.pose_ride(game.run_clock,0,31,false)
	game.skater.reset_physics_interpolation()
	var minimum := left_clearance(taxi)
	var ticks := 0
	var speed := 0.0
	var target_z: float = taxi.global_position.z + 4.0
	while game.phase == game.Phase.RUN and game.skater.global_position.z < target_z and ticks < 120:
		await physics_frame
		ticks += 1
		speed = maxf(speed,game.run_speed)
		if not strike: minimum = minf(minimum,left_clearance(taxi))
	check(ticks < 120 and speed >= 30.9 and speed <= 31.001, "actual physics ticks exercise supported maximum speed")
	if strike:
		check(game.phase == game.Phase.CRASH and game.accepted_contact.get("id","") == taxi.stable_id, "actual main swept collision strikes the authored taxi and bails")
		check(taxi.armed and game.skater.ragdoll and game.skater.limbs.size() == 12, "accepted strike transfers cause and creates real rider bodies")
		check(float(game.accepted_contact.get("error_bound",INF)) <= .002, "accepted strike retains declared spatial tolerance")
		for tick in 4: await physics_frame
		check(taxi.linear_velocity.is_finite() and taxi.linear_velocity.length() > .05, "accepted taxi strike transfers actual physical momentum")
	else:
		check(minimum > .05, "actual authored taxi near miss retains independently positive full-rider hull clearance")
		check(game.phase == game.Phase.RUN and game.accepted_contact.is_empty() and not taxi.armed and not taxi.broken, "maximum-speed near miss neither bails nor activates/pays taxi")
		check(game.rules.score == 0, "clear near miss awards no fallback claim")
	taxi_cases.append({"route":1,"seed":seed_value,"seed_scope":"small initial placement jitter, not solver randomization",
		"jitter_x":jitter_x,"jitter_z":jitter_z,"pose":0,"charge":1.0,"speed_control":31.0,
		"strike":strike,"ticks":ticks,"measured_max_speed":speed,"minimum_x_hull_clearance":minimum,
		"taxi_armed":taxi.armed,"accepted_contact":game.accepted_contact.duplicate(true),"score":game.rules.score})

func run() -> void:
	game = fixture.create_game(root)
	if game == null: return
	await replacement_matrix()
	for seed_value in [1,90210,777]:
		await authored_taxi(seed_value,false)
		await authored_taxi(seed_value,true)
	var report := {"scope":"actual scene/physics lifecycle and authored taxi fixtures; headless counts do not establish native audio",
		"engine":Engine.get_version_info(),"collider_geometry":collider_geometry,"replacements":replacements,"taxi_cases":taxi_cases}
	var file := FileAccess.open(fixture.artifact_path("lifecycle.json"),FileAccess.WRITE)
	check(file != null,"lifecycle telemetry opens inside selected suite directory")
	if file != null:
		file.store_string(JSON.stringify(report,"\t"))
		file.close()
	game.queue_free()
	await settle_frees()
	print("LIFECYCLE: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
