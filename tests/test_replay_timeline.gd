extends SceneTree
const Timeline = preload("res://scripts/replay_timeline.gd")
var checks: int = 0
var failures: int = 0
func check(value: bool, text: String) -> void:
	checks += 1
	if not value: failures += 1; printerr("FAIL: " + text)
func _initialize() -> void:
	var tape = Timeline.new()
	tape.begin({"attempt":42,"catalog":{"rider/head":{"kind":"head"}}})
	var input: Dictionary = {"actors":{"rider/head":Transform3D(Basis.IDENTITY,Vector3.ZERO)},"limbs":{"head":0}}
	check(tape.capture_actors(0,input), "initial actor sample accepted")
	input.limbs.head = 99
	for time in [.055,.110,.1627778,.2127778,.237]:
		check(tape.capture_actors(time,{"actors":{"rider/head":Transform3D(Basis.IDENTITY,Vector3(time*8,0,0))},"limbs":{"head":int(time*100)}}), "irregular actual-time sample accepted")
	check(not tape.capture_actors(.1,input), "backwards actor capture rejected")
	tape.capture_camera(-.02,Transform3D(Basis.IDENTITY,Vector3(0,4,0)),61,"initial",0)
	tape.capture_camera(.10,Transform3D(Basis.IDENTITY,Vector3(2,4,0)),72)
	tape.capture_camera(.10,Transform3D(Basis.IDENTITY,Vector3(3,4,0)),74)
	tape.capture_camera(.20,Transform3D(Basis.IDENTITY,Vector3(5,4,0)),80,"final",.237)
	check(tape.seal(.237) and tape.can_play(), "short final interval preserves exact duration")
	for time in [0,.02,.08,.13,.18,.225,.237]:
		var state: Dictionary = tape.sample_actors(time)
		check(state.actors["rider/head"].origin.distance_to(Vector3(time*8,0,0)) < .002, "linear fixture interpolates independent position at " + str(time))
	check(tape.sample_actors(0).limbs.head == 0, "input dictionary mutation cannot alter captured damage")
	var state: Dictionary = tape.sample_actors(.08)
	state.limbs.head = 100
	check(tape.sample_actors(.08).limbs.head == 5, "sample mutation cannot alter tape")
	check(tape.sample_camera(.10).transform.origin == Vector3(3,4,0), "equal timestamp uses latest camera sequence")
	check(is_equal_approx(tape.sample_camera(.15).fov,77), "lens interpolates its separate time track")
	check(tape.sample_camera(.237).transform.origin == Vector3(5,4,0), "older final camera holds after last render source")
	check(is_equal_approx(float(tape.camera_frames().back().age),.037), "final camera sample age remains explicit")
	check(not tape.capture_actors(.3,input) and not tape.capture_camera(.3,Transform3D.IDENTITY,52), "sealed tape refuses mutation through capture API")
	var zero = Timeline.new()
	zero.begin({}); zero.capture_actors(0,input); zero.capture_camera(0,Transform3D.IDENTITY,52); zero.seal(0)
	check(not zero.can_play(), "zero-duration tape cannot start playback")
	check(zero.sample_camera(0).fov == 52, "zero-duration sample has no division by zero")
	print("REPLAY_TIMELINE: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
