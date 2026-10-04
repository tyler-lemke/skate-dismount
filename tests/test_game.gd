extends SceneTree

var checks: int=0
var failures: int=0
var game: Node3D
var summaries: Array[Dictionary]=[]
func check(condition: bool, message: String) -> void:
	checks+=1
	if not condition: failures+=1; printerr("FAIL: ",message)

func frames(count: int) -> void:
	for i in count: await physics_frame

func key(code: int, pressed: bool) -> void:
	var event:=InputEventKey.new();event.physical_keycode=code;event.pressed=pressed
	game._unhandled_input(event)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	game.test_mode=true;game.save_path="res://builds/test_records.json"
	for level_index in range(3):
		game.select_route(level_index)
		check(game.phase==game.Phase.MENU,"route selection starts at menu")
		check(game.world.props.size()>45,"route contains a substantial physical destruction layout")
		game.start_ready()
		await frames(120)
		check(game.rules.score==0,"waiting at start never scores ambient settling")
		check(game.world.props[0].freeze,"props remain frozen during line selection")
		key(KEY_SPACE,true);await frames(110)
		check(game.charge>.7,"holding space charges launch")
		key(KEY_SPACE,false)
		check(game.phase==game.Phase.RUN and game.run_speed>14,"release starts a fast run")
		var before_speed:float=game.run_speed
		await frames(30)
		check(game.run_speed<before_speed,"coasting on the approach has mild rolling drag")
		game.toggle_pause();var paused_z:float=game.skater.position.z;await frames(25)
		check(is_equal_approx(paused_z,game.skater.position.z),"pause freezes simulation")
		game.toggle_pause()
		var budget:int=0
		while game.phase!=game.Phase.CRASH and budget<600:
			await frames(1);budget+=1
		check(game.phase==game.Phase.CRASH,"real obstacle impact triggers ragdoll")
		check(game.skater.limbs.size()==12 and game.skater.joints.size()==10,"full rider and separate board with connected joints")
		check(game.skater.speed()>10,"ragdoll inherits launch momentum")
		key(KEY_TAB,true);check(is_equal_approx(Engine.time_scale,.25) or is_equal_approx(Engine.time_scale,.18),"slow motion engages beneath any active impact pulse")
		key(KEY_TAB,false);check(is_equal_approx(Engine.time_scale,.55) or is_equal_approx(Engine.time_scale,.18),"slow motion releases to cinematic crash speed")
		key(KEY_TAB,true);game.toggle_pause()
		check(is_equal_approx(Engine.time_scale,1),"pause restores unscaled interface clock")
		game.toggle_pause()
		check((is_equal_approx(Engine.time_scale,.55) or is_equal_approx(Engine.time_scale,.18)) and not game.slow_motion,"resume restores crash pacing without sticky Tab")
		check(game.boosts==1,"one crashbreaker is available at bail")
		key(KEY_SHIFT,true)
		await frames(5)
		var velocity:Vector3=game.skater.torso.linear_velocity
		key(KEY_SHIFT,true)
		check(game.boosts==0 and game.skater.torso.linear_velocity==velocity,"single crashbreaker exhausted; repeated input has no effect")
		budget=0
		while game.phase!=game.Phase.RESULTS and budget<3000:
			await frames(1);budget+=1
		check(game.phase==game.Phase.RESULTS,"run completes without player intervention")
		check(game.skater.focus_position().y<25,"ragdoll stays near the arena after blast chains")
		check(game.rules.destroyed>=4,"physics propagates to multiple wreckable objects")
		check(game.rules.score>3000,"real collisions produce a nontrivial score")
		check(game.rules.property_damage+game.rules.rider_damage==game.rules.score,"final damage report balances")
		check(game.replay_frames.size()>40,"actual transforms recorded for replay")
		var final_score:int=game.rules.score;game.start_replay();await frames(60)
		check(game.phase==game.Phase.REPLAY,"replay runs with recorded physics transforms")
		check(game.rules.score==final_score,"replay cannot add score")
		budget=0
		while game.phase==game.Phase.REPLAY and budget<3000:
			await frames(1);budget+=1
		check(game.phase==game.Phase.RESULTS and game.rules.score==final_score,"replay automatically returns to unchanged damage report")
		var report:Dictionary={"level":level_index+1,"score":final_score,"property":game.rules.property_damage,"rider":game.rules.rider_damage,"destroyed":game.rules.destroyed,"explosions":game.rules.explosions}
		game.back_to_menu()
		check(game.phase==game.Phase.MENU and game.rules.score==0 and game.replay_frames.is_empty(),"return to routes clears run and replay")
		summaries.append(report)
	# Isolated causal chain oracle: an untouched prop cannot score; a moved active one scores once.
	game.select_route(0);game.start_ready();game.skater.position.x=4.3;game.charge=.8;game.launch()
	var prop:CrashProp=game.world.props[0];await frames(30)
	prop.shatter();check(game.rules.destroyed==0,"unarmed prop cannot shatter or score")
	prop.activate(Vector3(0,15,30));await frames(120)
	check(prop.broken and game.rules.destroyed>0,"activated prop physically tumbles into scored chain")
	var score:int=game.rules.score;prop.shatter();check(game.rules.score==score,"broken body remains physical but does not rescore")
	game.best_scores.assign([12345,23456,34567]);game.muted=true;game.save_records()
	game.best_scores.assign([0,0,0]);game.muted=false;game.load_records()
	check(game.best_scores==[12345,23456,34567] and game.muted,"records and audio preference round trip")
	game.unpause();game.queue_free();await process_frame;await process_frame;game=null
	print("GAME: ",checks," checks, ",failures," failures; ",JSON.stringify(summaries))
	quit(1 if failures else 0)
