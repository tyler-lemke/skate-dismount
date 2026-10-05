extends SceneTree
const Fixtures=preload("res://tests/test_fixtures.gd")
var fixture=Fixtures.new("test_settlement_activity")
var checks: int=0
var failures: int=0
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures+=1; printerr("FAIL: "+message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game: Node3D=fixture.create_game(root)
	if game==null: return
	game.start_ready(); game.launch(); game.bail_out()
	for body in game.skater.limbs:
		body.freeze=true; body.linear_velocity=Vector3.ZERO; body.angular_velocity=Vector3.ZERO
	for prop in game.world.props:
		prop.freeze=true; prop.linear_velocity=Vector3.ZERO; prop.angular_velocity=Vector3.ZERO
	var car: TrafficCar=game.world.traffic[0]
	car.freeze=false; car.armed=true; car.broken=true; car.release_driver()
	car.global_position=Vector3(0,.756,WreckRules.LEVELS[0].steps*WreckRules.LEVELS[0].run+5)
	car.reset_physics_interpolation(); car.angular_velocity=Vector3(0,7,0)
	game.crash_clock=3.1; game.idle_clock=0
	var report: Array[Dictionary]=[]
	var ticks: int=0
	while game.phase==game.Phase.CRASH and game.crash_clock<4.5 and ticks<1000:
		await physics_frame; ticks+=1
		if ticks%10==0: report.append({"sim":game.crash_clock,"linear":car.linear_velocity.length(),"angular":car.angular_velocity.length(),"idle":game.idle_clock,"driver":car.driver_state,"activity":game.settlement_activity.duplicate(true)})
	check(game.phase==game.Phase.CRASH,"a real yawing causal car cannot trigger the old premature idle settlement")
	check(car.angular_velocity.length()>.3 and game.idle_clock==0,"actual road yaw keeps quiet dwell at zero")
	while game.phase==game.Phase.CRASH and ticks<4000:
		await physics_frame; ticks+=1
	check(game.phase==game.Phase.RESULTS,"physical cascade reaches a bounded settlement")
	check(game.finish_reason in ["idle","simulation_limit","presentation_limit"],"settlement records its actual reason")
	if game.finish_reason=="idle":
		check(car.angular_velocity.length()<.3 and car.linear_velocity.length()<.35 and car.driver_state!=car.DriverState.UNCONTROLLED,"idle requires the causal driver's own rotation and quiet thresholds")
	var file:=FileAccess.open(fixture.artifact_path("settlement.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"trace":report,"finish_reason":game.finish_reason,"final_sim":game.crash_clock,"final_spin":car.angular_velocity.length()},"\t")); file.close()
	game.queue_free(); await process_frame; await process_frame
	print("SETTLEMENT_ACTIVITY: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
