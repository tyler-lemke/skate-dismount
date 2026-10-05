extends SceneTree

const TestFixtures = preload("res://tests/test_fixtures.gd")
const Rules = preload("res://scripts/game_rules.gd")
var fixtures = TestFixtures.new("test_bail_transfer")
var checks: int = 0
var failures: int = 0
var game: Node3D
var immediate_cases: Array[Dictionary] = []
var normal_cases: Array[Dictionary] = []

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ",message)

func _initialize() -> void: call_deferred("run")

func frame_error(a: Transform3D, b: Transform3D) -> float:
	return maxf(a.origin.distance_to(b.origin),maxf((a.basis.x-b.basis.x).length(),maxf((a.basis.y-b.basis.y).length(),(a.basis.z-b.basis.z).length())))

func hero_mesh(rider: Skater) -> MeshInstance3D:
	for mesh in rider.skin.skin_meshes:
		if str(mesh.name) == "HeroSkin": return mesh
	return null

# This oracle uses actual imported glTF inverse bind matrices and the completed
# Skeleton3D poses. It never derives vertices from production sync_parts math.
func skin_regions(mesh: MeshInstance3D, skeleton: Skeleton3D) -> Dictionary:
	var result: Dictionary = {}
	var palette: Array[Transform3D] = []
	for bind in mesh.skin.get_bind_count():
		var bone: int = mesh.skin.get_bind_bone(bind)
		if bone < 0: bone = skeleton.find_bone(mesh.skin.get_bind_name(bind))
		palette.append(skeleton.global_transform * skeleton.get_bone_global_pose(bone) * mesh.skin.get_bind_pose(bind))
	for surface in mesh.mesh.get_surface_count():
		var arrays: Array = mesh.mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var bones: Variant = arrays[Mesh.ARRAY_BONES]
		var weights: Variant = arrays[Mesh.ARRAY_WEIGHTS]
		var influences: int = bones.size() / maxi(1,vertices.size())
		var posed := PackedVector3Array()
		for index in vertices.size():
			var point := Vector3.ZERO
			for slot in influences:
				var offset: int = index * influences + slot
				if weights[offset] > 0.0: point += (palette[bones[offset]] * vertices[index]) * weights[offset]
			posed.append(point)
		var material: Material = mesh.get_active_material(surface)
		var name: String = material.resource_name.split("__")[0]
		result[name] = {"vertices":posed,"indices":arrays[Mesh.ARRAY_INDEX]}
	return result

func geometry_jump(before: Dictionary, after: Dictionary) -> float:
	var largest: float = 0.0
	for region in before:
		for index in before[region].vertices.size():
			largest = maxf(largest,before[region].vertices[index].distance_to(after[region].vertices[index]))
	return largest

func pivots_for(rider: Skater) -> Array[Dictionary]:
	var pivots: Array[Dictionary] = []
	for joint in rider.joints:
		var a: RigidBody3D = joint.get_node(joint.node_a)
		var b: RigidBody3D = joint.get_node(joint.node_b)
		var local_a: Vector3 = a.global_transform.affine_inverse() * joint.global_position
		var local_b: Vector3 = b.global_transform.affine_inverse() * joint.global_position
		check(local_a.distance_to(PhysicsServer3D.pin_joint_get_local_a(joint.get_rid())) < .0001 and local_b.distance_to(PhysicsServer3D.pin_joint_get_local_b(joint.get_rid())) < .0001,"independent world pivot matches actual physics-server pin anchor")
		pivots.append({"a":a,"b":b,"local_a":local_a,"local_b":local_b})
	return pivots

func pivot_error(pivots: Array[Dictionary]) -> float:
	var largest: float = 0.0
	for pivot in pivots:
		largest = maxf(largest,(pivot.a.global_transform * pivot.local_a).distance_to(pivot.b.global_transform * pivot.local_b))
	return largest

func finite_rig(rider: Skater) -> bool:
	for limb in rider.limbs:
		if not limb.global_transform.origin.is_finite() or not limb.global_basis.x.is_finite() or not limb.global_basis.y.is_finite() or not limb.global_basis.z.is_finite() or not limb.linear_velocity.is_finite() or not limb.angular_velocity.is_finite(): return false
	return true

func box_depth(a: RagdollLimb, b: RagdollLimb) -> float:
	var sa: BoxShape3D = a.get_child(0).shape
	var sb: BoxShape3D = b.get_child(0).shape
	var axes_a: Array[Vector3] = [a.global_basis.x,a.global_basis.y,a.global_basis.z]
	var axes_b: Array[Vector3] = [b.global_basis.x,b.global_basis.y,b.global_basis.z]
	var axes: Array[Vector3] = axes_a.duplicate()
	axes.append_array(axes_b)
	for u in axes_a:
		for v in axes_b:
			if u.cross(v).length_squared() > .00001: axes.append(u.cross(v).normalized())
	var minimum: float = INF
	for axis in axes:
		var radius_a: float = 0.0
		var radius_b: float = 0.0
		for index in 3:
			radius_a += absf(axis.dot(axes_a[index])) * sa.size[index] * .5
			radius_b += absf(axis.dot(axes_b[index])) * sb.size[index] * .5
		var depth: float = radius_a + radius_b - absf((b.global_position-a.global_position).dot(axis))
		if depth <= 0.0: return 0.0
		minimum = minf(minimum,depth)
	return minimum

func export_regions(regions: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key in regions:
		var vertices: Array = []
		for point in regions[key].vertices: vertices.append([point.x,point.y,point.z])
		var indices: Array = []
		for index in regions[key].indices: indices.append(index)
		result[key] = {"vertices":vertices,"indices":indices}
	return result

func triangles(region: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var vertices: PackedVector3Array = region.vertices
	var indices: Variant = region.indices
	for offset in range(0,indices.size(),3):
		var points: Array[Vector3] = [vertices[indices[offset]],vertices[indices[offset+1]],vertices[indices[offset+2]]]
		var bounds := AABB(points[0],Vector3.ZERO).expand(points[1]).expand(points[2])
		result.append({"points":points,"bounds":bounds,"index":offset / 3})
	return result

# Proper nonadjacent surface crossings, rather than box overlap. The surfaces
# tested are separate anatomical material regions on the connected actual hero.
# Endpoint/shared-edge contacts are rejected; an edge must pass through a face.
func surface_crossings(regions: Dictionary, first: String, second: String) -> Dictionary:
	var crossings: int = 0
	var evidence: Array[Dictionary] = []
	var aa: Array[Dictionary] = triangles(regions[first])
	var bb: Array[Dictionary] = triangles(regions[second])
	for a in aa:
		for b in bb:
			if not a.bounds.grow(.000001).intersects(b.bounds.grow(.000001)): continue
			var crossed: bool = false
			for direction in 2:
				var edges: Array[Vector3] = a.points if direction == 0 else b.points
				var face: Array[Vector3] = b.points if direction == 0 else a.points
				for edge in 3:
					var start: Vector3 = edges[edge]
					var end: Vector3 = edges[(edge+1)%3]
					var point: Variant = Geometry3D.segment_intersects_triangle(start,end,face[0],face[1],face[2])
					if point is Vector3 and point.distance_to(start) > .0001 and point.distance_to(end) > .0001:
						crossed = true
						if evidence.size() < 8: evidence.append({"triangle_a":a.index,"triangle_b":b.index,"point":[point.x,point.y,point.z]})
						break
				if crossed: break
			if crossed: crossings += 1
	return {"crossing_triangle_pairs":crossings,"examples":evidence}

func immediate_fixture(pose: int, rate: float, stairs: bool, hat: int) -> void:
	var group := Node3D.new()
	game.level_root.add_child(group)
	var rider := Skater.new()
	rider.hat_index = hat
	group.add_child(rider)
	var z: float = 7.013 if stairs else -8.0
	rider.position = Vector3(-4.7,Rules.surface_y(Rules.LEVELS[0],z)+.23,z)
	rider.rotation.y = -.16 if stairs else .16
	rider.reset_physics_interpolation()
	rider.set_pose(pose)
	rider.set_push_phase(.55)
	rider.pose_ride(.37,-.5 if stairs else .5,20.0,stairs)
	rider.sync_skin(false)
	var mesh: MeshInstance3D = hero_mesh(rider)
	var before: Dictionary = skin_regions(mesh,rider.skin.skeleton)
	var frames: Dictionary = {}
	var anchors: Dictionary = {}
	for key in rider.visuals: frames[key] = rider.visuals[key].global_transform
	for key in rider.pose_anchors: anchors[key] = rider.to_global(rider.pose_anchors[key])
	var score_before: int = game.rules.score
	Engine.time_scale = rate
	rider.bail(Vector3(-1.3,-2.2,12.0),.5)
	check(rider.limbs.size() == 12 and rider.joints.size() == 10,"pose %d rate %.2f physical actor/joint counts" % [pose,rate])
	check(rider.skin.physics_interpolation_mode == Node.PHYSICS_INTERPOLATION_MODE_OFF,"skin reads interpolated bodies without a second interpolation pass")
	var physical_error: float = 0.0
	for key in frames:
		physical_error = maxf(physical_error,frame_error(frames[key],rider.body_parts[key].global_transform))
		check(str(rider.body_parts[key].get_meta("stable_id","")) == "rider/"+str(key),"stable physical identity for "+key)
	check(physical_error < .0001,"all first body frames preserve captured simulation pose")
	var anchor_error: float = 0.0
	for key in anchors: anchor_error = maxf(anchor_error,anchors[key].distance_to(rider.bail_anchors[key]))
	check(anchor_error < .0001,"bail captures world anatomical anchors once")
	var after: Dictionary = skin_regions(mesh,rider.skin.skeleton)
	var jump: float = geometry_jump(before,after)
	check(jump < .0001,"all actual weighted skin vertices preserve immediate bail pose")
	rider._process(0.0)
	var render_jump: float = geometry_jump(after,skin_regions(mesh,rider.skin.skeleton))
	check(render_jump < .0001,"new-body interpolation reset preserves first rendered bail geometry")
	check(rider.body_parts.head.get_node_or_null("RiderModel/CrashHat") != null,"selected hat survives physical handoff")
	check(rider.body_parts.board.linear_velocity.z > rider.body_parts.torso.linear_velocity.z + 2.9,"independent board retains extra launch momentum")
	var pivots: Array[Dictionary] = pivots_for(rider)
	var max_anchor: float = 0.0
	var finite: bool = true
	var elapsed: float = 0.0
	var ticks: int = 0
	var boosted: bool = false
	while elapsed < 1.2 and ticks < 2000:
		await physics_frame
		elapsed += rider.get_physics_process_delta_time()
		ticks += 1
		max_anchor = maxf(max_anchor,pivot_error(pivots))
		finite = finite and finite_rig(rider)
		if elapsed > .35 and not boosted:
			rider.launch_impulse(Vector3(.2,0,1),8.5)
			boosted = true
	check(ticks < 2000 and elapsed >= 1.2,"bounded rate fixture reaches measured simulation landing interval")
	check(max_anchor <= .05,"world joint pivots remain within five centimeters through landing and impulse")
	check(finite,"all anatomical and board frames/velocities remain finite")
	rider.apply_damage_states({"head":74.0,"fore_l":45.0})
	check(float(rider.skin.region_materials.head[0].get_shader_parameter("severity")) == 74.0 and float(rider.skin.region_materials.fore_l[0].get_shader_parameter("severity")) == 45.0,"local damage regions remain independent")
	rider.apply_damage_states({})
	var healthy: bool = true
	for materials in rider.skin.region_materials.values():
		for material in materials: healthy = healthy and float(material.get_shader_parameter("severity")) == 0.0
	check(healthy,"complete healthy snapshot clears every anatomical damage region")
	check(game.rules.score == score_before,"skin and display-only damage callbacks cannot award payouts")
	immediate_cases.append({"pose":pose,"rate":rate,"stairs":stairs,"pushing_pose":stairs,"heading":-.16 if stairs else .16,"hat":hat,"body_error":physical_error,"anchor_capture_error":anchor_error,"vertex_discontinuity":jump,"first_render_discontinuity":render_jump,"max_joint_pivot_error":max_anchor,"simulation_elapsed":elapsed,"physics_ticks":ticks,"finite":finite})
	group.queue_free()
	await process_frame
	await process_frame

func normal_crash(pose: int) -> void:
	Engine.time_scale = 1.0
	game.set_process(true)
	game.set_physics_process(true)
	game._replace_route(0)
	game.start_ready()
	game.set_pose(pose)
	game.charge = .75
	game.launch()
	var run_ticks: int = 0
	while game.phase == game.Phase.RUN and run_ticks < 900:
		await physics_frame
		run_ticks += 1
	check(game.phase == game.Phase.CRASH,"normal pose %d approach produces actual controller bail" % pose)
	if game.phase != game.Phase.CRASH: return
	var rider: Skater = game.skater
	var mesh: MeshInstance3D = hero_mesh(rider)
	var pivots: Array[Dictionary] = pivots_for(rider)
	var pairs: Array[Array] = [["head","pelvis"],["fore_l","torso"],["fore_r","torso"]]
	var largest: Dictionary = {}
	var snapshots: Dictionary = {}
	var snapshot_times: Dictionary = {}
	rider.sync_skin(false)
	var initial: Dictionary = skin_regions(mesh,rider.skin.skeleton)
	var max_angle: float = 0.0
	var max_anchor: float = 0.0
	var finite: bool = true
	var ticks: int = 0
	while game.phase == game.Phase.CRASH and ticks < 2800:
		await physics_frame
		ticks += 1
		max_anchor = maxf(max_anchor,pivot_error(pivots))
		finite = finite and finite_rig(rider)
		max_angle = maxf(max_angle,rad_to_deg(rider.body_parts.head.global_basis.y.angle_to(rider.body_parts.torso.global_basis.y)))
		for pair in pairs:
			var key: String = pair[0]+":"+pair[1]
			var depth: float = box_depth(rider.body_parts[pair[0]],rider.body_parts[pair[1]])
			if depth > float(largest.get(key,-1.0)):
				largest[key] = depth
				var frames: Dictionary = {}
				for part in rider.body_parts: frames[part] = rider.body_parts[part].global_transform
				snapshots[key] = frames
				snapshot_times[key] = game.crash_clock
	check(finite,"normal crash pose %d stays finite" % pose)
	check(max_anchor <= .05,"normal crash pose %d world joint pivots remain connected" % pose)
	# Freeze the completed scene, then reconstruct ONLY the captured display
	# frames in a separate nonphysical Skater for CPU shape inspection.
	game.phase = game.Phase.RESULTS
	game.freeze_actors()
	game.set_process(false)
	game.set_physics_process(false)
	var display_group := Node3D.new()
	root.add_child(display_group)
	var display := Skater.new()
	display.ragdoll = true
	display_group.add_child(display)
	display.set_process(false)
	for visual in display.visuals.values(): visual.visible = false
	for part in rider.offsets:
		var frame := Node3D.new()
		display_group.add_child(frame)
		display.body_parts[part] = frame
	var shape_cases: Dictionary = {}
	for pair in pairs:
		var key: String = pair[0]+":"+pair[1]
		for part in snapshots[key]: display.body_parts[part].global_transform = snapshots[key][part]
		display.sync_skin(false)
		var regions: Dictionary = skin_regions(hero_mesh(display),display.skin.skeleton)
		var crossed: Dictionary = surface_crossings(regions,pair[0],pair[1])
		var first_crossed: Dictionary = surface_crossings(initial,pair[0],pair[1])
		shape_cases[key] = {"coarse_box_max_depth":largest[key],"simulation_time":snapshot_times[key],"initial_visible_crossings":first_crossed.crossing_triangle_pairs,"visible_crossings":crossed.crossing_triangle_pairs,"crossing_examples":crossed.examples}
		var geometry := FileAccess.open(fixtures.artifact_path("pose_%d_%s_geometry.json" % [pose,key.replace(":","_")]),FileAccess.WRITE)
		if geometry != null:
			geometry.store_string(JSON.stringify({"pose":pose,"time":snapshot_times[key],"pair":key,"regions":export_regions(regions),"crossings":crossed},"\t"))
			geometry.close()
		else: check(false,"matched CPU geometry export opens")
	normal_cases.append({"pose":pose,"run_ticks":run_ticks,"crash_ticks":ticks,"max_joint_pivot_error":max_anchor,"max_head_torso_up_angle_degrees":max_angle,"finite":finite,"shape_inspection":shape_cases})
	display_group.queue_free()
	await process_frame
	await process_frame

func run() -> void:
	game = fixtures.create_game(root)
	if game == null: return
	game.set_process(false)
	game.set_physics_process(false)
	var rates: Array[float] = [1.0,.55,.25,.18]
	for pose in 3:
		for index in rates.size():
			await immediate_fixture(pose,rates[index],false,(pose+index)%3)
			await immediate_fixture(pose,rates[index],true,(pose+index)%3)
	for pose in 3: await normal_crash(pose)
	# Fresh route replacement owns a new pose/history. The new body cannot use
	# interpolated samples from the discarded attempt, even before another tick.
	Engine.time_scale = 1.0
	var old_rider: Skater = game.skater
	game._replace_route(2)
	game.start_ready()
	check(game.skater != old_rider and game.skater.limbs.is_empty() and game.skater.body_parts.is_empty(),"route replacement removes old crash body ownership")
	game.skater.sync_skin(false)
	var root_before: Vector3 = game.skater.global_position
	game.skater._process(0.0)
	check(game.skater.skin.skeleton.global_transform.origin.distance_to(root_before) < .0001,"new route render root resets immediately to fresh placement")
	var file := FileAccess.open(fixtures.artifact_path("bail_transfer.json"),FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"immediate_cases":immediate_cases,"normal_cases":normal_cases,"checks":checks,"failures":failures,"native_visual_validation":false},"\t"))
		file.close()
	else: check(false,"bail evidence file opens")
	game.queue_free()
	await process_frame
	await process_frame
	print("BAIL_TRANSFER: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
