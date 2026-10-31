extends SceneTree
const Rules=preload("res://scripts/game_rules.gd")
const Fixtures=preload("res://tests/test_fixtures.gd")
var fixture=Fixtures.new("test_skating_descent")
var checks: int=0
var failures: int=0
var reports: Array[Dictionary]=[]
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures+=1; printerr("FAIL: "+message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game: Node3D=fixture.create_game(root)
	if game==null: return
	game.set_process(false); game.set_physics_process(false)
	for route in 3:
		for pushing in [false,true]:
			game._replace_route(route); game.start_ready()
			await process_frame; await physics_frame; await physics_frame
			# Empty obstruction lane exercises every authored tread through launch
			# and the natural final bail; contact sweep has separate real-hull tests.
			for prop in game.world.props:
				if is_instance_valid(prop): prop.free()
			game.world.props.clear(); game.world.traffic.clear()
			game.charge=1; game.launch()
			if pushing:
				var down:=InputEventKey.new(); down.physical_keycode=KEY_W; down.keycode=KEY_W; down.pressed=true; Input.parse_input_event(down); Input.flush_buffered_events()
				await process_frame
			var maximum_gap: float=0
			var top_speed: float=0
			var stairs: int=0
			var ticks: int=0
			while game.phase==game.Phase.RUN and ticks<1200:
				game._physics_process(1.0/90.0)
				ticks+=1; top_speed=maxf(top_speed,game.run_speed)
				if game.skater.position.z<0: continue
				var at: Vector3=game.skater.global_position
				var ray:=PhysicsRayQueryParameters3D.create(Vector3(at.x,50,at.z),Vector3(at.x,-5,at.z),1)
				var hit: Dictionary=game.get_world_3d().direct_space_state.intersect_ray(ray)
				check(not hit.is_empty(),"authored stair has actual support for route%d" % route)
				if not hit.is_empty(): maximum_gap=maxf(maximum_gap,absf(at.y-float(hit.position.y)-.23))
				stairs+=1
			check(game.phase==game.Phase.CRASH and stairs>30,"route%d full-speed approach traverses stairs then bails" % route)
			check(maximum_gap<.002,"route%d wheel reference follows real treads within2mm, measured%.6f" % [route,maximum_gap])
			check(top_speed>=24 and top_speed<=31,"full-charge descent reaches bounded high speed")
			if pushing:
				var up:=InputEventKey.new(); up.physical_keycode=KEY_W; up.keycode=KEY_W; up.pressed=false; Input.parse_input_event(up); Input.flush_buffered_events()
				await process_frame
				check(game.push_count>0,"heldW survives launch and generates real stroke impulses")
			reports.append({"route":route+1,"push":pushing,"ticks":ticks,"stair_samples":stairs,"max_gap":maximum_gap,"top_speed":top_speed,"kicks":game.push_count})
	# Real engine-stepped outer-lane runs exercise simulation ownership and
	# actual held input, alongside the explicit fixed-delta support cases above.
	game.set_physics_process(true)
	for route in 3:
		for pushing in [false,true]:
			game._replace_route(route); game.start_ready()
			await process_frame; await physics_frame; await physics_frame
			for prop in game.world.props:
				if is_instance_valid(prop): prop.free()
			game.world.props.clear(); game.world.traffic.clear()
			game.skater.position.x=Rules.LEVELS[route].width*.5-.8
			game.skater.reset_physics_interpolation()
			game.charge=1; game.launch()
			if pushing:
				var down:=InputEventKey.new(); down.physical_keycode=KEY_W; down.keycode=KEY_W; down.pressed=true
				Input.parse_input_event(down); Input.flush_buffered_events()
			var maximum_gap: float=0
			var samples: int=0
			var ticks: int=0
			var earliest_bail: float=Rules.LEVELS[route].steps*Rules.LEVELS[route].run-.35
			while game.phase==game.Phase.RUN and ticks<1000:
				await physics_frame; ticks+=1
				var at: Vector3=game.skater.global_position
				if at.z<0: continue
				var ray:=PhysicsRayQueryParameters3D.create(Vector3(at.x,50,at.z),Vector3(at.x,-5,at.z),1)
				var hit: Dictionary=game.get_world_3d().direct_space_state.intersect_ray(ray)
				check(not hit.is_empty(),"real outer-lane stair has actual support")
				if not hit.is_empty(): maximum_gap=maxf(maximum_gap,absf(at.y-float(hit.position.y)-.23))
				samples+=1
			check(game.phase==game.Phase.CRASH and game.skater.position.z>=earliest_bail and samples>30,"real outer-lane descent reaches the authored end without premature bail")
			check(maximum_gap<.002,"real outer-lane wheel reference follows support within2mm")
			check(game.push_count>0 if pushing else game.push_count==0,"real outer-lane W strokes respect held/released input")
			reports.append({"route":route+1,"push":pushing,"real_engine_stepped":true,"outer_lane":game.skater.position.x,"samples":samples,"ticks":ticks,"max_gap":maximum_gap,"kicks":game.push_count})
			if pushing:
				var up:=InputEventKey.new(); up.physical_keycode=KEY_W; up.keycode=KEY_W; up.pressed=false
				Input.parse_input_event(up); Input.flush_buffered_events(); await process_frame
	var file:=FileAccess.open(fixture.artifact_path("descents.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(reports,"\t")); file.close()
	game.queue_free(); await process_frame; await process_frame
	print("SKATING_DESCENT: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
