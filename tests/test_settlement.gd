extends SceneTree
const Settlement = preload("res://scripts/crash_settlement.gd")
var checks: int = 0
var failures: int = 0

func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures += 1; printerr("FAIL: " + message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var board := RigidBody3D.new()
	board.freeze = true
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(.76,.18,1.65)
	collider.shape = shape
	board.add_child(collider)
	root.add_child(board)
	board.angular_velocity = Vector3(0,3,0)
	check(Settlement.has_activity([board], []), "spinning detached board retains causal activity with zero linear travel")
	board.angular_velocity = Vector3.ZERO
	check(not Settlement.has_activity([board], []), "quiet board can settle")
	var car := TrafficCar.new()
	car.freeze = true
	root.add_child(car)
	car.armed = true
	car.driver_state = TrafficCar.DriverState.UNCONTROLLED
	car.linear_velocity = Vector3(.00285,0,0)
	car.angular_velocity = Vector3(0,2.93,0)
	check(Settlement.has_activity([], [car]), "confirmed spinning car cannot be filed as idle")
	car.angular_velocity = Vector3.ZERO
	check(Settlement.has_activity([], [car]), "uncontrolled car still waits for driver's quiet dwell")
	car.driver_state = TrafficCar.DriverState.SETTLED
	check(not Settlement.has_activity([], [car]), "quiet settled causal car permits filing")
	car.angular_velocity = Vector3(0,.31,0)
	check(Settlement.has_activity([], [car]), "angular activity threshold respected after settlement")
	car.armed = false
	car.linear_velocity = Vector3(20,0,0)
	check(not Settlement.has_activity([], [car]), "healthy passing traffic cannot stall a claim")
	check(Settlement.finish_reason(3,1,2,false).is_empty(), "minimum crash observation window enforced")
	check(Settlement.finish_reason(4,2,1.25,false).is_empty(), "idle requires completed dwell")
	check(Settlement.finish_reason(4,2,1.26,false) == "idle", "quiet dwell produces explicit idle reason")
	check(Settlement.finish_reason(4,2,2,true).is_empty(), "pending fuse/contact prevents idle filing")
	check(Settlement.finish_reason(16,2,0,true) == "simulation_limit", "simulated cap remains bounded even with a pending cascade")
	check(Settlement.finish_reason(4,34,0,true) == "presentation_limit", "active wall cap reports its independent reason")
	car.queue_free(); board.queue_free()
	await process_frame
	await process_frame
	print("SETTLEMENT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
