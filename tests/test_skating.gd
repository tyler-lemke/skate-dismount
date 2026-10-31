extends SceneTree

const TestFixtures = preload("res://tests/test_fixtures.gd")
var fixtures = TestFixtures.new("test_skating")

var checks: int=0
var failures: int=0
var game: Node3D

func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures+=1; printerr("FAIL: ",message)

func frames(n: int) -> void:
	for i in n: await physics_frame

func held(code: int, pressed: bool) -> void:
	var event:=InputEventKey.new(); event.physical_keycode=code; event.keycode=code; event.pressed=pressed
	Input.parse_input_event(event); Input.flush_buffered_events()

func _initialize() -> void: call_deferred("run")

func run() -> void:
	game=fixtures.create_game(root)
	if game == null: return
	game._replace_route(0); game.start_ready(); game.charge=.15; game.launch()
	var start: float=game.run_speed
	await frames(18)
	check(game.phase==game.Phase.RUN and game.skater.position.z<0,"coast fixture remains on the flat run-up")
	check(game.run_speed<start and game.push_count==0,"flat coasting loses speed without inventing kicks")
	held(KEY_W,true)
	var before: float=game.run_speed
	await frames(36)
	check(game.push_count==1,"holding push delivers one physical kick during a full ground stroke")
	check(game.run_speed>before+1.5,"the completed kick creates a noticeable real speed gain")
	check(game.skater.foot_contacts.l.planted,"front foot stays planted through the pushing cycle")
	held(KEY_W,false)
	await frames(5)
	check(game.skater.foot_contacts.l.planted and game.skater.foot_contacts.r.planted,"release returns both feet to the deck")
	var count: int=game.push_count
	await frames(10)
	check(game.push_count==count,"release stops further push impulses")
	# Carve uses heading and forward motion; it is not an instantaneous sideways snap.
	game.retry(); game.charge=.15; game.launch()
	var original: Vector3=game.skater.position
	held(KEY_D,true); await frames(14)
	check(game.heading>0 and game.skater.position.x>original.x and game.skater.position.z>original.z,"steering physically carves a forward and lateral path")
	check(is_equal_approx(game.skater.rotation.y,game.heading),"board and body face the actual carving heading")
	check(absf(game.heading)<.3,"carving stays within a controllable arc")
	held(KEY_D,false); await frames(16)
	check(absf(game.heading)<.01,"release recenters the heading for a straight approach")
	# READY can select the marked outside traffic line without a running steering stunt.
	game.retry(); held(KEY_A,true); await frames(60); held(KEY_A,false)
	check(is_equal_approx(game.skater.position.x,-4.7),"ready selection reaches the outside traffic line")
	game.queue_free(); await process_frame; await process_frame
	print("SKATING: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
