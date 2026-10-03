extends SceneTree
var failures:int=0
var checks:int=0
var game:Node3D
var reports:Array[Dictionary]=[]
func check(condition:bool,message:String) -> void:
	checks+=1
	if not condition: failures+=1;printerr("FAIL: ",message)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.test_mode=true;game.save_path="res://builds/route_test_records.json"
	for route in range(3):
		var scores:Array[int]=[]
		for lane in [-3.3,0.0,3.3]:
			game.select_route(route);game.start_ready();game.skater.position.x=lane;game.charge=.75;game.launch()
			var ticks:int=0
			while game.phase!=game.Phase.RESULTS and ticks<2400:
				await physics_frame;ticks+=1
			check(game.phase==game.Phase.RESULTS,"route %d lane %s finishes"%[route,lane])
			check(game.rules.destroyed>=3,"route %d lane %s starts a real chain"%[route,lane])
			check(game.rules.score>2500,"route %d lane %s rewards destruction"%[route,lane])
			check(game.skater.focus_position().y<20,"route %d lane %s returns to ground"%[route,lane])
			scores.append(game.rules.score)
			reports.append({"route":route+1,"lane":lane,"score":game.rules.score,"wrecked":game.rules.destroyed,"explosions":game.rules.explosions})
		check(scores.max()!=scores.min(),"different lines have different physical outcomes route "+str(route))
	# Manual bail and retry go through the keyboard handler, before an obstacle is reached.
	game.retry();game.charge=.15;game.launch()
	var key:=InputEventKey.new();key.physical_keycode=KEY_SPACE;key.pressed=true;game._unhandled_input(key)
	check(game.phase==game.Phase.CRASH and game.skater.ragdoll,"manual bail works on the runup")
	key.physical_keycode=KEY_R;game._unhandled_input(key)
	check(game.phase==game.Phase.READY and game.rules.score==0 and not game.skater.ragdoll,"keyboard retry restores fresh rider")
	game.queue_free();await process_frame;await process_frame;game=null
	print("ROUTES: ",checks," checks, ",failures," failures; ",JSON.stringify(reports))
	var file:=FileAccess.open("res://builds/route_results.json",FileAccess.WRITE);file.store_string(JSON.stringify(reports,"\t"));file.close()
	quit(1 if failures else 0)
