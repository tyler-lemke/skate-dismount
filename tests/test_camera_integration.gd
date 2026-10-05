extends SceneTree
const Fixtures=preload("res://tests/test_fixtures.gd")
var fixture=Fixtures.new("test_camera_integration")
var checks: int=0
var failures: int=0
var reports: Array[Dictionary]=[]
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures+=1; printerr("FAIL: "+message)
func _initialize() -> void: call_deferred("run")
func validate(game: Node, route: int) -> Dictionary:
	var frame: Transform3D=game.camera.global_transform
	var lens:=SphereShape3D.new(); lens.radius=.26
	var query:=PhysicsShapeQueryParameters3D.new(); query.shape=lens
	query.transform=Transform3D(Basis.IDENTITY,frame.origin); query.collision_mask=3
	var hits: Array=game.get_world_3d().direct_space_state.intersect_shape(query,1)
	check(hits.is_empty(),"actual displayed route%d camera lens clears real solid geometry" % route)
	var near: float=game.camera.near
	var half_height: float=tan(deg_to_rad(game.camera.fov)*.5)*near
	var corner_radius: float=sqrt(near*near+half_height*half_height*(1+1.6*1.6))
	check(corner_radius<=.26,"declared16:10 near-plane corners fit the real lens envelope")
	var direction: Vector3=game.camera_target-frame.origin
	var angle: float=rad_to_deg(acos(clampf((-frame.basis.z).normalized().dot(direction.normalized()),-1,1)))
	check(angle<=.1,"actual camera aims after floor/path corrections")
	check(frame.origin.is_finite() and is_finite(game.camera.fov),"actual displayed camera transform/projection remain finite")
	return {"route":route,"phase":game.phase,"view":game.camera_style,"sim":game.run_clock+game.crash_clock,"lens":frame.origin,"aim_error":angle,"safe":hits.is_empty(),"diagnostic":game.camera_diagnostic.duplicate(true)}
func run() -> void:
	var game: Node3D=fixture.create_game(root)
	if game==null: return
	for route in 3:
		game._replace_route(route); game.start_ready(); game.charge=.8; game.launch()
		var ticks: int=0
		while game.phase==game.Phase.RUN and ticks<900:
			await physics_frame; await process_frame; ticks+=1
			if ticks%20==0: reports.append(validate(game,route))
		check(game.phase==game.Phase.CRASH,"camera trace reaches real obstacle crash")
		for tick in 360:
			if game.phase!=game.Phase.CRASH: break
			if tick%45==0: game.camera_style=(tick/45)%3; game.camera_policy.reset()
			await physics_frame; await process_frame
			if tick%10==0: reports.append(validate(game,route))
		if game.phase==game.Phase.CRASH: game.finish_run()
	var file:=FileAccess.open(fixture.artifact_path("camera_trace.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(reports,"\t")); file.close()
	game.queue_free(); await process_frame; await process_frame
	print("CAMERA_INTEGRATION: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
