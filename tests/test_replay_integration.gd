extends SceneTree
const Fixtures=preload("res://tests/test_fixtures.gd")
var fixture=Fixtures.new("test_replay_integration")
var checks: int=0
var failures: int=0
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures+=1; printerr("FAIL: "+message)
func _initialize() -> void: call_deferred("run")
func live_state(game: Node) -> Dictionary:
	var props: Dictionary={}
	for prop in game.world.props:
		if is_instance_valid(prop):
			var driver: Dictionary=prop.snapshot() if prop is TrafficCar else {}
			# Live actor visibility is temporarily hidden by the display scene and
			# independently checked on restoration; it is not an AI state field.
			driver.erase("visible")
			props[prop.stable_id]={"frame":prop.global_transform,"linear":prop.linear_velocity,"angular":prop.angular_velocity,"broken":prop.broken,"armed":prop.armed,"fuse":prop.fuse,"cause":prop.cause_label,"grace":prop.grace,"visual":prop.visual_broken,"traffic":driver}
	var limbs: Dictionary={}
	for key in game.skater.body_parts:
		var body=game.skater.body_parts[key]
		var exceptions: Array[int]=[]
		# The engine's typed exclusion array can contain ownerless entries.
		# Retain their count alongside every observable owner, without dereferencing null.
		for excluded in body.get_collision_exceptions(): exceptions.append(excluded.get_instance_id() if is_instance_valid(excluded) else 0)
		exceptions.sort()
		limbs[key]={"frame":body.global_transform,"linear":body.linear_velocity,"angular":body.angular_velocity,"previous_linear":body.previous_linear_velocity,"previous_angular":body.previous_angular_velocity,"cooldown":body.cooldown,"collision_layer":body.collision_layer,"collision_mask":body.collision_mask,"collision_exceptions":exceptions,"assembly_envelope":body.use_assembly_envelope}
	var gates: Array[Dictionary]=[]
	for gate in game.skater.collision_gates:
		gates.append({"first":str(gate.first.get_meta("stable_id","")),"second":str(gate.second.get_meta("stable_id","")),"waiting":gate.waiting,"query_transform":gate.query.transform,"query_mask":gate.query.collision_mask,"shape_transform":gate.shape.transform})
	return {"props":props,"limbs":limbs,"collision_gates":gates,"damage":game.skater.damage_states.duplicate(),"score":game.rules.score,"fund":game.fund_total(),"events":game.claim_events.duplicate(true),"edges":game.traffic_edges.duplicate(true),"records":FileAccess.get_file_as_bytes(fixture.records_path)}
func compare_state(actual: Dictionary, expected: Dictionary) -> bool:
	for key in expected:
		if actual[key]!=expected[key]:
			if actual[key] is Dictionary:
				for id in expected[key]:
					if actual[key].get(id)!=expected[key][id]: print("STATE_DIFF ",key,"/",id," actual=",actual[key].get(id)," expected=",expected[key][id])
			else: print("STATE_DIFF ",key," actual=",actual[key]," expected=",expected[key])
	return actual==expected
func run() -> void:
	var game: Node3D=fixture.create_game(root)
	if game==null: return
	game.start_ready(); game.charge=.65; game.launch()
	var ticks: int=0
	while game.phase==game.Phase.RUN and ticks<1200:
		await physics_frame; ticks+=1
	check(game.phase==game.Phase.CRASH,"actual approach creates a physical crash")
	for tick in 280: await physics_frame
	if game.phase==game.Phase.CRASH: game.finish_run()
	check(game.phase==game.Phase.RESULTS and game.replay_timeline.can_play(),"physical claim seals a playable timed tape")
	var frames: Array=game.replay_frames.duplicate(true)
	var camera_frames: Array=game.replay_timeline.camera_frames()
	check(frames.front().time==0 and is_equal_approx(frames.back().time,game.crash_clock),"tape covers actual initial and final simulation boundaries")
	var last_time: float=-1
	for frame in frames:
		check(frame.time>last_time,"actor source timestamps increase")
		last_time=frame.time
	check(not camera_frames.is_empty() and camera_frames.front().time<=0,"camera boundary keeps actual source age")
	var original_visibility: Dictionary={}
	for prop in game.world.props:
		if is_instance_valid(prop): original_visibility[prop.stable_id]=prop.visible
	# Residual live effects are separate nodes, even on the headless backend.
	var particle:=MeshInstance3D.new(); particle.mesh=BoxMesh.new(); game.level_root.add_child(particle)
	game.particles.append({"mesh":particle,"velocity":Vector3.ZERO,"life":100.0})
	var frozen: Dictionary=live_state(game)
	for playback in 3:
		var final_camera: Transform3D=game.camera.global_transform
		var final_fov: float=game.camera.fov
		var final_style: int=game.camera_style
		game.start_replay()
		check(not particle.visible,"residual final live debris is hidden throughout historical replay")
		check(game.phase==game.Phase.REPLAY and is_instance_valid(game.replay_presentation.root),"playback uses a separate display scene")
		check(game.sound.replay_audio,"replay owns music-only audio policy")
		for tick in 24: await process_frame
		check(game.replay_receipt_cursor>0 and game.hud.claim_panel.visible,"historical receipt feed is visible at recorded event times")
		var time: float=game.replay_clock
		var left: Dictionary=frames.front()
		var right: Dictionary=left
		for index in range(frames.size()-1):
			if frames[index].time<=time and time<frames[index+1].time:
				left=frames[index]; right=frames[index+1]; break
		var weight: float=0 if right.time==left.time else (time-left.time)/(right.time-left.time)
		var expected: Transform3D=left.actors["rider/torso"].interpolate_with(right.actors["rider/torso"],weight)
		check(game.replay_presentation.actors["rider/torso"].global_position.distance_to(expected.origin)<.0001,"playback positions follow independent actual-time interpolation")
		check(game.replay_presentation.rider.damage_states==left.limbs,"historical injuries belong to display rider")
		check(compare_state(live_state(game),frozen),"playback leaves every authoritative body/score/fuse/driver/record unchanged")
		var recorded: Transform3D=game.camera.global_transform
		game.camera_style=2; game.camera_policy.reset()
		await process_frame
		check(game.camera.global_transform!=recorded and game.camera_diagnostic.safe,"alternate replay view is distinct and collider-safe")
		game.toggle_pause()
		var paused_time: float=game.replay_clock
		for tick in 8: await process_frame
		check(game.replay_clock==paused_time and live_state(game)==frozen,"paused replay advances neither tape nor live actors")
		game.resume(); game.replay_clock=game.replay_timeline.duration
		await process_frame
		check(game.phase==game.Phase.RESULTS and game.replay_presentation.root==null,"completed playback disposes its private scene")
		check(not game.sound.replay_audio,"completion releases replay audio policy")
		check(game.camera.global_transform==final_camera and game.camera.fov==final_fov and game.camera_style==final_style,"completion restores exact final camera transform projection and view")
		check(particle.visible,"completion restores residual live effect visibility")
		check(live_state(game)==frozen and game.skater.visible,"completion restores visibility without rewriting final live state")
		for prop in game.world.props:
			if is_instance_valid(prop): check(prop.visible==original_visibility[prop.stable_id],"completion restores each original actor's visibility")
	game.start_replay(); game.retry()
	check(game.phase==game.Phase.READY and game.replay_presentation.root==null and game.replay_catalog.is_empty(),"retry discards tape templates and presentation")
	game.queue_free(); await process_frame; await process_frame
	print("REPLAY_INTEGRATION: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
