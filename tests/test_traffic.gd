extends SceneTree

class TrafficHarness extends Node3D:
	var live: bool = true
	var claims: Dictionary = {}
	var edges: Array = []
	func is_live() -> bool: return live
	func prop_wrecked(prop: CrashProp, _explosive: bool) -> void: claims[prop.stable_id] = true
	func traffic_contact(car: TrafficCar, other: Object, strength: float, at: Vector3) -> void:
		if car.armed and strength >= car.threshold and other is CrashProp:
			edges.append({"from":other.stable_id,"to":car.stable_id,"strength":strength,"at":at})

var checks: int = 0
var failures: int = 0
var telemetry: Array = []

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; printerr("FAIL: ", message)

func frames(count: int) -> void:
	for i in count: await physics_frame

func _initialize() -> void: call_deferred("run")

func dispatch(code: int, pressed: bool) -> void:
	var event:=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=pressed
	Input.parse_input_event(event);Input.flush_buffered_events()

func actual_approach_runs() -> void:
	var game:Node3D=load("res://scenes/main.tscn").instantiate()
	game.test_mode=true;game.save_path="res://builds/traffic_input_records.json";root.add_child(game)
	for route in 3:
		game.select_route(route);game.start_ready()
		var edge:float=-WreckRules.LEVELS[route].width*.5+.8
		dispatch(KEY_A,true)
		var ticks:int=0
		while game.skater.position.x>edge+.001 and ticks<250: await frames(1);ticks+=1
		dispatch(KEY_A,false)
		check(absf(game.skater.position.x-edge)<.02,"actual steering reaches outside traffic approach")
		dispatch(KEY_SPACE,true)
		ticks=0
		while game.charge<.75 and ticks<200: await frames(1);ticks+=1
		dispatch(KEY_SPACE,false)
		check(game.phase==game.Phase.RUN,"actual charge release launches the traffic approach")
		var bail_z:float=WreckRules.LEVELS[route].steps*WreckRules.LEVELS[route].run-2.0
		ticks=0
		while game.phase==game.Phase.RUN and game.skater.position.z<bail_z and ticks<500: await frames(1);ticks+=1
		check(game.phase==game.Phase.RUN,"outside approach clears stair obstacles until deliberate late bail")
		dispatch(KEY_SPACE,true);dispatch(KEY_SPACE,false)
		check(game.phase==game.Phase.CRASH and game.skater.focus_position().z<bail_z+1.0,"actual bail starts ragdoll on the last stair treads")
		while game.phase==game.Phase.CRASH and game.crash_clock<.5: await frames(1)
		var pulse_at:Vector3=game.skater.focus_position()
		var b:TrafficCar=game.world.traffic[1];var c:TrafficCar=game.world.traffic[2]
		check(pulse_at.distance_to(b.global_position)>2.2 and pulse_at.distance_to(c.global_position)>2.2,"full-game secondary victims start outside direct pulse")
		dispatch(KEY_SHIFT,true);dispatch(KEY_SHIFT,false)
		check(game.boosts==0 and game.breaker_events.size()==1,"actual input spends exactly one intervention")
		ticks=0
		while game.phase==game.Phase.CRASH and ticks<2800:await frames(1);ticks+=1
		var ab:bool=false;var bc:bool=false
		for contact in game.traffic_edges:
			ab=ab or (contact.source==game.world.traffic[0].stable_id and contact.destination==b.stable_id)
			bc=bc or (contact.source==b.stable_id and contact.destination==c.stable_id)
		check(ab and bc,"actual input creates physical authored A→B→C on route "+str(route+1))
		check(game.world.traffic[0].broken and b.broken and c.broken,"all three authored cars qualify for damage claims")
		check(game.rules.prop_ids.has(game.world.traffic[0].get_instance_id()) and game.rules.prop_ids.has(b.get_instance_id()) and game.rules.prop_ids.has(c.get_instance_id()),"all three physical damage claims actually enter the score-once ledger")
		check(c.cause_label==b.stable_id,"third victim inherits cause from the second car rather than rider or pulse")
		check(game.phase==game.Phase.RESULTS,"finite traffic cascade settles to results")
		telemetry.append({"route":route+1,"actual_input":true,"charge":game.charge,"breaker_at":pulse_at,"edges":game.traffic_edges.duplicate(),"payout":game.rules.score,"all_three_broken":game.world.traffic[0].broken and b.broken and c.broken})
	game.queue_free();await process_frame;await process_frame
	Engine.time_scale=1.0

func make_floor(parent: Node3D) -> void:
	var body := StaticBody3D.new(); body.collision_layer=1; body.collision_mask=7
	var collider := CollisionShape3D.new(); var shape := BoxShape3D.new(); shape.size=Vector3(120,.5,120)
	collider.shape=shape; body.add_child(collider); body.position.y=-.25; parent.add_child(body)

func make_car(parent: TrafficHarness, id: String, at: Vector3, direction: Vector3 = Vector3.FORWARD) -> TrafficCar:
	var car := TrafficCar.new(); car.game=parent; car.mass=180; car.kind="taxi"; car.value=9000
	car.stable_id=id; car.name=id; car.route_direction=direction; car.queued=true; car.cruise_speed=0
	car.position=at; car.rotation.y=atan2(direction.x,direction.z)
	var collider:=CollisionShape3D.new(); var shape:=BoxShape3D.new(); shape.size=Vector3(1.85,1.45,3.3)
	collider.shape=shape; car.add_child(collider); car.visual=Node3D.new(); car.add_child(car.visual)
	parent.add_child(car); car.wrecked.connect(parent.prop_wrecked)
	return car

func chain_fixture(displace_b: bool) -> Dictionary:
	var harness:=TrafficHarness.new(); root.add_child(harness); make_floor(harness)
	var a:=make_car(harness,"A",Vector3(1.5,.76,-5.5),Vector3.BACK)
	var b:=make_car(harness,"B",Vector3(14 if displace_b else 0,.76,0),Vector3.RIGHT)
	var c:=make_car(harness,"C",Vector3(5,.76,3.4),Vector3.RIGHT)
	b.queued=false; b.cruise_speed=4
	var fleet:Array=[a,b,c]
	await frames(3) # Let PhysicsServer register the configured masses before impulses.
	for car in fleet: car.start_driver(fleet)
	var b_identity:int=b.get_instance_id()
	check(b.driver_state==TrafficCar.DriverState.DRIVE,"second victim initially has active force-driven AI")
	check(a.position.distance_to(b.position)>2.2 and a.position.distance_to(c.position)>2.2,"both secondary victims start outside breaker pulse radius")
	a.apply_shove(Vector3.BACK*a.mass*10,"CRASHBREAKER")
	await frames(480)
	var result:Dictionary={"negative":displace_b,"claims":harness.claims.keys(),"edges":harness.edges.duplicate(),"positions":[a.position,b.position,c.position]}
	for car in fleet:
		check(car.linear_velocity.is_finite() and car.angular_velocity.is_finite(),"chain body velocities remain finite")
	if displace_b:
		check(not b.armed and not c.armed and not c.broken,"displaced B leaves C uncredited and healthy")
	else:
		var ab:bool=false; var bc:bool=false
		for edge in harness.edges:
			ab=ab or (edge.from=="A" and edge.to=="B")
			bc=bc or (edge.from=="B" and edge.to=="C")
		check(ab and bc,"actual physical A→B→C normal contacts establish both edges")
		check(b.broken and c.broken and harness.claims.has("B") and harness.claims.has("C"),"fresh second and third victims claim through contact only")
		check(b.last_motor_force.is_zero_approx() and c.last_motor_force.is_zero_approx(),"hit cars retain no motor force")
		check(b.get_instance_id()==b_identity,"driver handoff keeps exactly the same physical body")
	harness.queue_free(); await process_frame; await process_frame
	return result

func simultaneous_fixture(reverse_order: bool) -> void:
	var harness:=TrafficHarness.new();root.add_child(harness);make_floor(harness)
	var actors:Dictionary={}
	var positions:Dictionary={"A":Vector3(0,.76,-3.4),"B":Vector3(0,.76,0),"C":Vector3(0,.76,3.32)}
	for id in ["C","B","A"] if reverse_order else ["A","B","C"]:
		actors[id]=make_car(harness,id,positions[id],Vector3.BACK)
	await frames(3)
	for id in actors: actors[id].start_driver(actors.values())
	actors.A.apply_shove(Vector3.BACK*actors.A.mass*18,"CRASHBREAKER")
	await frames(300)
	var bc:bool=false
	for edge in harness.edges:bc=bc or (edge.from=="B" and edge.to=="C")
	check(actors.B.armed and actors.C.armed and actors.C.broken and bc,"near-simultaneous physical chain credits third victim regardless of actor insertion order")
	telemetry.append({"simultaneous":true,"reverse_order":reverse_order,"claims":harness.claims.keys(),"edges":harness.edges.duplicate()})
	harness.queue_free();await process_frame;await process_frame

func run() -> void:
	Engine.time_scale=1.0
	for level_index in 3:
		var harness:=TrafficHarness.new(); root.add_child(harness)
		var world:=WreckWorld.new(); world.build(harness,level_index,harness)
		check(world.traffic.size()==3,"each route has bounded three-car traffic roster")
		await frames(30)
		check(world.traffic[0].freeze and harness.claims.is_empty(),"ready traffic stays frozen and uncredited")
		world.start_traffic()
		await frames(1800)
		var uncontrolled:int=0
		for car in world.traffic:
			if car.driver_state in [TrafficCar.DriverState.UNCONTROLLED,TrafficCar.DriverState.SETTLED]: uncontrolled+=1
			check(not car.armed and not car.broken,"ordinary driving never arms or damages traffic")
			check(car.linear_velocity.is_finite(),"driver velocity is finite")
		check(uncontrolled==0 and harness.edges.is_empty() and harness.claims.is_empty(),"traffic alone has no passive collisions or claims")
		check(not world.traffic_has_motion() and not world.traffic_pending_contact(),"cruising fleet cannot postpone settlement")
		telemetry.append({"level":level_index+1,"uncontrolled":uncontrolled,"positions":[world.traffic[0].position,world.traffic[1].position,world.traffic[2].position]})
		harness.queue_free(); await process_frame; await process_frame
	telemetry.append(await chain_fixture(false))
	telemetry.append(await chain_fixture(true))
	await simultaneous_fixture(false)
	await simultaneous_fixture(true)
	# Braking oracle: ordinary headway must stop a following driver without contact.
	for speed in [4.0,6.0,8.0]:
		var brake_harness:=TrafficHarness.new();root.add_child(brake_harness);make_floor(brake_harness)
		var follower:=make_car(brake_harness,"follower",Vector3(-20,.76,0),Vector3.RIGHT)
		var leader:=make_car(brake_harness,"leader",Vector3(0,.76,0),Vector3.RIGHT)
		follower.queued=false;follower.cruise_speed=speed
		await frames(3);follower.start_driver([follower,leader]);leader.start_driver([follower,leader])
		await frames(1000)
		check(follower.driver_state==TrafficCar.DriverState.BRAKE and follower.linear_velocity.length()<.15,"driver brakes to rest behind an ordinary queue at speed "+str(speed))
		check(leader.position.x-follower.position.x>=TrafficCar.HULL_LENGTH+1.0,"bumper safety margin retained at speed "+str(speed))
		check(not follower.armed and not leader.armed and brake_harness.edges.is_empty(),"safe headway produces no autonomous impact")
		brake_harness.queue_free();await process_frame;await process_frame
	# Travel by itself and a gentle sourced shove are not a damage qualification.
	var harness:=TrafficHarness.new(); root.add_child(harness); make_floor(harness)
	var car:=make_car(harness,"gentle",Vector3(0,.76,0),Vector3.RIGHT)
	await frames(3)
	car.queued=false;car.cruise_speed=5;car.start_driver([car]); await frames(180)
	check(car.position.length()> .55,"travel test actually drives beyond legacy origin threshold")
	car.apply_shove(Vector3.RIGHT*car.mass*.2,"CRASHBREAKER");await frames(180)
	check(car.armed and not car.broken and harness.claims.is_empty(),"small shove after long drive never becomes travel-based payout")
	var recorded:Dictionary=car.snapshot(); car.apply_snapshot({"damage":true,"wheel_phase":5,"brake_lights":true,"armed":true})
	car.apply_snapshot(recorded)
	check(car.broken==recorded.damage and is_equal_approx(car.wheel_phase,recorded.wheel_phase),"replay restores traffic damage and wheel state")
	check(harness.claims.is_empty(),"snapshot application never awards a claim")
	harness.queue_free();await process_frame;await process_frame
	await actual_approach_runs()
	var file:=FileAccess.open("res://builds/traffic_report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"runs":telemetry},"\t"));file.close()
	print("TRAFFIC: ",checks," checks, ",failures," failures; ",JSON.stringify(telemetry))
	quit(1 if failures else 0)
