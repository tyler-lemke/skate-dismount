extends SceneTree

var checks: int = 0
var failures: int = 0
var game: Node3D

func _initialize() -> void: call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: ",message)

func dispatch(code: int, pressed: bool = true, echo: bool = false) -> void:
	var event := InputEventKey.new()
	event.keycode=code
	event.physical_keycode=code
	event.pressed=pressed
	event.echo=echo
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await process_frame

func fresh_crash() -> void:
	game.select_route(0)
	game.start_ready()
	game.charge=.3
	game.launch()
	game.bail_out()
	await physics_frame

func fixture(kind: String, mass_value: float, at: Vector3, radius: float = .055) -> CrashProp:
	var prop := CrashProp.new()
	prop.name="Fixture_%d" % game.world.props.size()
	prop.kind=kind
	prop.mass=mass_value
	prop.game=game
	prop.explosive=kind=="barrel"
	prop.gravity_scale=0.0
	prop.grace=2.0
	prop.position=at
	var collider:=CollisionShape3D.new()
	var shape:=SphereShape3D.new()
	shape.radius=radius
	collider.shape=shape
	prop.add_child(collider)
	game.level_root.add_child(prop)
	game.world.props.append(prop)
	return prop

func isolate_rider_for_pulse() -> void:
	# The pulse test measures the environmental impulse, not a subsequent rider-body collision.
	for body in game.skater.limbs:
		body.freeze=true
		body.collision_layer=0
		body.collision_mask=0

func no_charge(message: String, events: int = 0) -> void:
	check(game.boosts==1 and game.breaker_events.size()==events,message)

func input_contract() -> void:
	game.select_route(0)
	game.start_ready()
	await dispatch(KEY_SHIFT)
	no_charge("Shift in READY cannot spend the charge")
	await dispatch(KEY_SHIFT,false)
	game.launch()
	await dispatch(KEY_SHIFT)
	no_charge("Shift in RUN cannot spend the charge")
	await dispatch(KEY_SHIFT,false)
	game.bail_out()
	await physics_frame
	await dispatch(KEY_SHIFT,true,true)
	no_charge("key-repeat Shift cannot spend an available charge")
	await dispatch(KEY_SHIFT)
	check(game.boosts==0 and game.breaker_events.size()==1,"actual Shift spends exactly one charge during CRASH")
	var first_event: Dictionary=game.breaker_events[0]
	check((first_event.aim as Vector3).is_finite(),"spent event records a finite captured direction")
	await dispatch(KEY_SHIFT)
	await dispatch(KEY_SHIFT,true,true)
	check(game.boosts==0 and game.breaker_events.size()==1,"held and repeated Shift cannot fire again")
	await dispatch(KEY_SHIFT,false)
	game.finish_run()
	await dispatch(KEY_SHIFT)
	check(game.phase==game.Phase.RESULTS and game.boosts==0 and game.breaker_events.size()==1,"Shift in RESULTS cannot create a second event")
	await dispatch(KEY_SHIFT,false)
	game.retry()
	check(game.phase==game.Phase.READY and game.boosts==1 and game.breaker_events.is_empty(),"retry restores one charge and clears the prior event")
	check(game.claim_events.is_empty(),"retry clears the prior claim ledger")
	game.launch()
	game.bail_out()
	for i in 12: await physics_frame
	game.finish_run()
	if game.replay_frames.size()>1:
		game.start_replay()
		await dispatch(KEY_SHIFT)
		check(game.phase==game.Phase.REPLAY and game.boosts==1 and game.breaker_events.is_empty(),"Shift in REPLAY cannot spend or apply a live effect")
		await dispatch(KEY_SHIFT,false)
	else:
		check(false,"fixture recorded enough frames for replay input test")
	game.retry()
	game.launch()
	game.bail_out()
	game.toggle_pause()
	await dispatch(KEY_SHIFT)
	no_charge("paused crash cannot spend its charge")
	await dispatch(KEY_SHIFT,false)
	game.toggle_pause()
	game.hud.help_panel.visible=true
	await dispatch(KEY_SHIFT)
	no_charge("visible help blocks the crashbreaker")
	await dispatch(KEY_SHIFT,false)
	game.hud.help_panel.visible=false
	await dispatch(KEY_SHIFT)
	check(game.boosts==0 and game.breaker_events.size()==1,"closing help restores the same unspent charge")
	await dispatch(KEY_SHIFT,false)

func directional_contract() -> void:
	var deltas: Array[float] = []
	for side in [-1,1]:
		await fresh_crash()
		var key: int=KEY_A if side<0 else KEY_D
		await dispatch(key)
		var before: Vector3=game.skater.torso.linear_velocity
		await dispatch(KEY_SHIFT)
		var aim: Vector3=game.breaker_events[0].aim
		var after: Vector3=game.skater.torso.linear_velocity
		deltas.append(after.x-before.x)
		check(aim.x*side>.5 and (after.x-before.x)*side>2.0,"one charge physically steers the rider to side %d" % side)
		await dispatch(KEY_SHIFT,false)
		await dispatch(key,false)
	check(deltas.size()==2 and deltas[1]-deltas[0]>4.0,"opposite aim inputs cause distinct rider velocity changes")

func pulse_contract() -> void:
	await fresh_crash()
	isolate_rider_for_pulse()
	var focus: Vector3=game.skater.focus_position()
	var light: CrashProp=fixture("crate",5.0,focus+Vector3(-.23,0,1.23))
	var heavy: CrashProp=fixture("taxi",200.0,focus+Vector3(.23,0,1.23))
	var behind: CrashProp=fixture("crate",5.0,focus+Vector3(0,0,-1.0))
	var distant: CrashProp=fixture("crate",5.0,focus+Vector3(0,0,3.0))
	var explosive: CrashProp=fixture("barrel",8.0,focus+Vector3(.65,0,1.2))
	await physics_frame
	var before_score: int=game.rules.score
	game.crashbreaker()
	check(game.boosts==0 and game.breaker_events.size()==1,"fixture pulse consumes the sole charge")
	check(light.armed and heavy.armed and explosive.armed,"near forward physical objects receive a sourced pulse")
	check(not behind.armed and not distant.armed,"behind-cone and beyond-radius objects receive no pulse")
	check(explosive.fuse<0 and not explosive.broken and game.rules.score==before_score,"pulse alone neither ignites a drum nor pays a claim")
	await physics_frame
	check(light.linear_velocity.length()>heavy.linear_velocity.length()*4.0,"same bounded pulse moves a light prop more than a heavy vehicle")
	for prop in [light,heavy,explosive]:
		check(prop.linear_velocity.length()<=4.01,"single pulse cannot add more than four metres per second")
	await fresh_crash()
	isolate_rider_for_pulse()
	focus=game.skater.focus_position()
	var target: CrashProp=fixture("crate",5.0,focus+Vector3(0,0,1.55))
	var wall:=StaticBody3D.new()
	wall.name="PulseOccluder"
	wall.collision_layer=1
	wall.collision_mask=0
	var shape_node:=CollisionShape3D.new()
	var wall_shape:=BoxShape3D.new()
	wall_shape.size=Vector3(.65,1.0,.10)
	shape_node.shape=wall_shape
	wall.add_child(shape_node)
	wall.position=focus+Vector3(0,0,.75)
	game.level_root.add_child(wall)
	await physics_frame
	game.crashbreaker()
	check(not target.armed and target.linear_velocity.length()<.01,"solid line-of-sight blocker prevents the pulse")
	await fresh_crash()
	isolate_rider_for_pulse()
	focus=game.skater.focus_position()
	var many: Array[CrashProp]=[]
	for i in 12:
		var x: float=-.66+i*.12
		var z: float=sqrt(1.30*1.30-x*x)
		many.append(fixture("crate",10.0,focus+Vector3(x,0,z),.035))
	await physics_frame
	game.crashbreaker()
	await physics_frame
	var impulse_total: float=0.0
	var hit_count: int=0
	for prop in many:
		if prop.armed:
			hit_count+=1
			impulse_total+=prop.linear_velocity.length()*prop.mass
			check(prop.linear_velocity.length()<=4.01,"crowded pulse retains the per-object velocity cap")
	check(hit_count>=8,"crowded forward fixture exposes most candidates to the pulse")
	check(impulse_total>35.0 and impulse_total<=90.5,"crowded pulse has a useful but bounded total impulse budget")

func time_rate_contract() -> void:
	var measured: Array[float]=[]
	for rate in [1.0,.55,.25,.18]:
		await fresh_crash()
		Engine.time_scale=rate
		var before: Vector3=game.skater.torso.linear_velocity
		game.skater.launch_impulse(Vector3.FORWARD,8.5)
		await physics_frame
		var added: Vector3=game.skater.torso.linear_velocity-before
		measured.append(added.length())
		check(added.is_finite() and added.z< -7.9,"physical rider impulse applies at time scale %.2f" % rate)
		Engine.time_scale=1.0
	check(measured.max()-measured.min()<.05,"immediate impulse size does not depend on presentation time scale")

func run() -> void:
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.test_mode=true
	game.save_path="res://builds/crashbreaker_test_records.json"
	game.best_scores.assign([0,0,0])
	await input_contract()
	await directional_contract()
	await pulse_contract()
	await time_rate_contract()
	Engine.time_scale=1.0
	game.unpause()
	game.queue_free()
	await process_frame
	await process_frame
	print("CRASHBREAKER: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
