extends SceneTree

const TestFixtures = preload("res://tests/test_fixtures.gd")
const Presentation = preload("res://scripts/replay_presentation.gd")
var fixtures = TestFixtures.new("test_replay_presentation")
var checks: int = 0
var failures: int = 0
var callback_count: int = 0
var observations: Array[Dictionary] = []
var game: Node3D

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ",message)

func _initialize() -> void: call_deferred("run")

func material_snapshot(mesh: MeshInstance3D) -> Dictionary:
	var data: Dictionary = {"morph":[],"materials":[]}
	if mesh.mesh is ArrayMesh:
		for index in mesh.mesh.get_blend_shape_count(): data.morph.append(mesh.get_blend_shape_value(index))
	for surface in mesh.mesh.get_surface_count() if mesh.mesh != null else 0:
		var material: Material = mesh.get_active_material(surface)
		if material is StandardMaterial3D:
			data.materials.append({"id":material.get_instance_id(),"albedo":material.albedo_color,"emission":material.emission,"energy":material.emission_energy_multiplier,"emission_enabled":material.emission_enabled})
		elif material is ShaderMaterial:
			data.materials.append({"id":material.get_instance_id(),"severity":material.get_shader_parameter("severity")})
	return data

func authority_snapshot(props: Array) -> Dictionary:
	var values: Dictionary = {"score":game.rules.score,"fund":game.fund_total(),"callbacks":callback_count,"props":{},"skin":{},"game":{}}
	var names: Array[String] = ["best_scores","legacy_scores","last_money_secured","result_was_best","boosts","breaker_events","traffic_edges","claim_events","save_path","pending_save","records_status"]
	for property in game.get_property_list():
		if names.has(property.name):
			var value: Variant = game.get(property.name)
			values.game[property.name] = value.duplicate(true) if value is Dictionary or value is Array else value
	for prop in props:
		var data: Dictionary = {"transform":prop.global_transform,"linear":prop.linear_velocity,"angular":prop.angular_velocity,"armed":prop.armed,"broken":prop.broken,"cause":prop.cause_label,"fuse":prop.fuse,"fuse_clock":prop.fuse_clock,"visual_broken":prop.visual_broken,"meshes":[]}
		if prop is TrafficCar:
			data.driver = prop.driver_state
			data.wheel_phase = prop.wheel_phase
			data.brake_lights = prop.brake_lights
			data.cause_clock = prop.cause_clock
			data.wheels = []
			for wheel in prop.wheels: data.wheels.append(wheel.rotation)
		for mesh in prop.visual.find_children("*","MeshInstance3D",true,false): data.meshes.append(material_snapshot(mesh))
		values.props[prop.stable_id] = data
	for part in game.skater.skin.region_materials:
		values.skin[part] = []
		for material in game.skater.skin.region_materials[part]: values.skin[part].append(material.get_shader_parameter("severity"))
	values.limbs = []
	for limb in game.skater.limbs:
		values.limbs.append({"transform":limb.global_transform,"linear":limb.linear_velocity,"angular":limb.angular_velocity,"cooldown":limb.cooldown})
	return values

func safe_floor(_at: Vector3) -> float: return 0.0

func nodes_under(node: Node) -> int:
	var count: int = 1
	for child in node.get_children(): count += nodes_under(child)
	return count

func no_gameplay_children(node: Node) -> bool:
	if node is RigidBody3D or node is Joint3D or node is CrashProp: return false
	if node is StaticBody3D and (node.collision_layer != 0x10 or node.collision_mask != 0): return false
	for child in node.get_children():
		if not no_gameplay_children(child): return false
	return true

func run() -> void:
	game = fixtures.create_game(root)
	if game == null: return
	game._replace_route(0)
	game.start_ready()
	game.charge = 1.0
	game.launch()
	game.bail_out()
	game.phase = game.Phase.RESULTS
	game.freeze_actors()
	game.set_process(false)
	game.set_physics_process(false)
	Engine.time_scale = 1.0
	var props: Array = []
	var taxi: CrashProp
	var drum: CrashProp
	var crate: CrashProp
	for prop in game.world.props:
		if prop is TrafficCar: continue
		if prop.kind == "taxi" and taxi == null: taxi = prop
		if prop.kind == "barrel" and drum == null: drum = prop
		if prop.kind == "crate" and crate == null: crate = prop
	var car: TrafficCar = game.world.traffic[0]
	props = [taxi,drum,crate,car]
	check(taxi != null and drum != null and crate != null,"real route provides taxi, explosive drum, crate and traffic")
	for prop in props:
		prop.freeze = true
		prop.wrecked.connect(func(_prop: CrashProp,_explosive: bool): callback_count += 1)
		prop.global_position = Vector3(14 + props.find(prop) * 4,30,-45)
		prop.linear_velocity = Vector3(1,2,3)
		prop.angular_velocity = Vector3(.2,.3,.4)
		prop.armed = true
		prop.cause_label = "PRESERVED_CAUSE"
	drum.fuse = 1.25
	drum.fuse_clock = .7
	car.driver_state = car.DriverState.UNCONTROLLED
	car.cause_clock = 2.0
	car.wheel_phase = .7
	car.brake_lights = true
	car.broken = true
	car.set_damaged_visual(true)
	for wheel in car.wheels: wheel.rotation.x = .7
	game.skater.set_limb_damage("head",27.0)
	game.skater.set_limb_damage("torso",61.0)
	await physics_frame
	await physics_frame
	var before: Dictionary = authority_snapshot(props)
	var catalog: Dictionary = Presentation.capture_catalog(props,game.skater)
	check(catalog.size() == 16,"catalog contains four real props and twelve rider/board stable IDs")
	check(catalog.has("rider/board") and catalog.has("rider/torso"),"board and anatomical IDs are stable")
	for prop in props:
		var entry: Dictionary = catalog[prop.stable_id]
		var source_shape: Shape3D = prop.find_children("*","CollisionShape3D",true,false)[0].shape
		check(entry.shapes[0].shape != source_shape,"catalog owns query geometry independent of live "+prop.stable_id)
		check(entry.visual_template.get_parent() == null,"catalog template is detached for "+prop.stable_id)
	check(authority_snapshot(props) == before,"catalog capture preserves every live state and mutable material")
	var parent := Node3D.new()
	root.add_child(parent)
	var base_nodes: int = nodes_under(parent)
	var presentation = Presentation.new()
	var first: Dictionary = {"actors":{},"present":{},"visual":{},"limbs":{}}
	for id in catalog:
		first.actors[id] = catalog[id].spawn_transform
		first.present[id] = true
		first.visual[id] = {"damage":false,"visible":true,"wheel_phase":1.2,"brake_lights":false,"fuse_glow":0.0}
	first.actors[taxi.stable_id] = Transform3D(Basis.IDENTITY,Vector3(0,30,-45))
	first.actors["rider/torso"] = Transform3D(Basis.IDENTITY,Vector3(5,30,-45))
	first.visual[drum.stable_id].fuse_glow = 1.8
	for key in game.skater.offsets:
		if key != "board": first.limbs[key] = 73.0
	var stored_first: Dictionary = first.duplicate(true)
	for cycle in 3:
		presentation.create(parent,catalog,{"hat_index":2,"offsets":game.skater.offsets})
		presentation.apply(first)
		await physics_frame
		check(presentation.actors.size() == 16 and presentation.query_bodies.size() == 4,"one bounded actor/query set per playback")
		check(no_gameplay_children(presentation.root),"proxies have no rigid bodies, joints or driver/contact scripts")
		check(presentation.focus_position() == Vector3(5,30,-45),"camera focus uses replayed torso instead of frozen final live rider")
		check(presentation.rider.ragdoll and presentation.rider.limbs.is_empty() and presentation.rider.joints.is_empty(),"display Skater uses plain part frames without calling bail")
		check(presentation.rider.body_parts.torso is Node3D and not presentation.rider.body_parts.torso is RigidBody3D,"anatomical replay frames are nonphysical")
		check(presentation.rider.body_parts.head.get_node("RiderModel/CrashHat") != null,"replay preserves selected creative hat")
		for part in first.limbs:
			for material in presentation.rider.skin.region_materials[part]: check(material.get_shader_parameter("severity") == 73.0,"isolated skin applies complete recorded limb state "+part)
		for wheel in presentation.visual_states[car.stable_id].wheels: check(is_equal_approx(wheel.rotation.x,1.2),"proxy wheel phase follows recorded display state")
		for lamp in presentation.visual_states[car.stable_id].lamps: check(not lamp.visible,"proxy brake lamps follow recorded state")
		var proxy_drum_mesh: MeshInstance3D = presentation.visual_states[drum.stable_id].meshes[0].mesh
		var proxy_drum_material: StandardMaterial3D = proxy_drum_mesh.get_active_material(0)
		check(is_equal_approx(proxy_drum_material.emission_energy_multiplier,1.8),"fuse glow belongs to proxy material")
		check(authority_snapshot(props) == before,"live authority and materials identical during playback %d" % cycle)
		var space: PhysicsDirectSpaceState3D = parent.get_world_3d().direct_space_state
		var context: Dictionary = presentation.query_context(space,Callable(self,"safe_floor"))
		check(context.mask == 0x11,"replay query combines static geometry bit1 with query-only bit0x10")
		var ray := PhysicsRayQueryParameters3D.create(Vector3(-2,30,-45),Vector3(2,30,-45),context.mask)
		var early: Dictionary = space.intersect_ray(ray)
		check(not early.is_empty() and early.collider == presentation.query_bodies[taxi.stable_id],"camera sees actual early-time replay taxi hull")
		var final_ray := PhysicsRayQueryParameters3D.create(Vector3(12,30,-45),Vector3(16,30,-45),context.mask)
		check(space.intersect_ray(final_ray).is_empty(),"invisible live final taxi cannot obstruct replay camera")
		final_ray.collision_mask = 3
		var live_final: Dictionary = space.intersect_ray(final_ray)
		check(not live_final.is_empty() and live_final.collider == taxi,"positive control verifies disjoint final live hull exists")
		var second: Dictionary = first.duplicate(true)
		second.actors[taxi.stable_id] = Transform3D(Basis(Vector3.UP,.4),Vector3(6,30,-45))
		second.visual[car.stable_id].damage = true
		second.visual[car.stable_id].brake_lights = true
		second.visual[car.stable_id].wheel_phase = 2.7
		second.visual[drum.stable_id].fuse_glow = .45
		second.limbs = {}
		presentation.apply(second)
		# No physics-frame delay: camera hull synchronization happens before solve.
		check(space.intersect_ray(ray).is_empty(),"query transform updates immediately to the displayed replay time")
		for part in presentation.rider.skin.region_materials:
			for material in presentation.rider.skin.region_materials[part]: check(material.get_shader_parameter("severity") == 0.0,"absent limb state restores healthy proxy region "+part)
		for entry in presentation.visual_states[car.stable_id].meshes:
			if entry.dent >= 0: check(is_equal_approx(entry.mesh.get_blend_shape_value(entry.dent),.85),"isolated traffic morph follows recorded deformation")
		var third: Dictionary = second.duplicate(true)
		third.present[taxi.stable_id] = false
		presentation.apply(third)
		check(not presentation.actors[taxi.stable_id].visible and presentation.query_bodies[taxi.stable_id].collision_layer == 0,"absent/deleted replay actor hides visual and query geometry")
		check(first == stored_first,"playback never mutates its immutable source sample")
		check(authority_snapshot(props) == before,"live authority identical after all replay visual states %d" % cycle)
		observations.append({"cycle":cycle,"actors":presentation.actors.size(),"query_bodies":presentation.query_bodies.size(),"nodes":nodes_under(parent),"callbacks":callback_count})
		presentation.dispose()
		check(nodes_under(parent) == base_nodes,"disposal removes every proxy node immediately %d" % cycle)
		check(presentation.actors.is_empty() and presentation.query_bodies.is_empty() and presentation.rider == null,"disposal drops retained proxy references")
		check(authority_snapshot(props) == before,"live authority identical after disposal %d" % cycle)
	check(callback_count == 0,"real wrecked signals and payout callbacks never run during presentation")
	Presentation.dispose_catalog(catalog)
	check(catalog.is_empty(),"discarded attempt releases detached catalog templates")
	parent.queue_free()
	game.queue_free()
	await process_frame
	await process_frame
	var file := FileAccess.open(fixtures.artifact_path("presentation.json"),FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"cycles":observations,"checks":checks,"failures":failures,"callbacks":callback_count},"\t"))
		file.close()
	else: check(false,"presentation evidence file opens")
	print("REPLAY_PRESENTATION: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
