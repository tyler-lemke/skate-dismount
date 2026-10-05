extends SceneTree
const Fixtures = preload("res://tests/test_fixtures.gd")
var fixtures = Fixtures.new("test_clock_integration")
var checks: int = 0
var failures: int = 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures += 1; printerr("FAIL: " + message)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var game: Node3D = fixtures.create_game(root)
	if game == null: return
	game.set_process(false); game.set_physics_process(false)
	game.start_ready(); game.launch()
	await physics_frame; await process_frame
	var provider: Node = game.wall_clock
	provider.set_process(false)
	var initial_run: float = game.run_clock
	var simulated: float = 0.0
	for delta in [.011111111,.006111111,.002777778,.002]:
		game._physics_process(delta)
		simulated += delta
	check(absf(game.run_clock-initial_run-simulated) < .000001, "run simulation accumulates supplied physics deltas exactly once")
	game.bail_out()
	for body in game.skater.limbs: body.freeze = true
	for prop in game.world.props: prop.freeze = true
	game.impact_left = 1.0; game.impact_cooldown = 1.1
	provider.rebase()
	provider.now_usec += 125000
	game._process(.001)
	check(absf(game.impact_left-.875) < .000001 and absf(game.impact_cooldown-.975) < .000001, "presentation timers follow independent125ms wall sequence")
	check(is_equal_approx(game.crash_real_clock,.125) and game.crash_clock == 0, "wall elapsed cannot fabricate simulation elapsed")
	game.slow_motion = true; game.apply_time_rate()
	check(is_equal_approx(game.time_rate,.18), "impact pulse has priority over held slow")
	game.impact_left = 0; game.apply_time_rate()
	check(is_equal_approx(game.time_rate,.25), "held slow follows pulse expiry")
	game.slow_motion = false; game.apply_time_rate()
	check(is_equal_approx(game.time_rate,.55), "base crash rate restored")
	game.toggle_pause()
	var before_pause: float = game.crash_real_clock
	provider.now_usec += 7000000
	game._process(7)
	check(game.crash_real_clock == before_pause and is_equal_approx(game.time_rate,1), "pause excludes7s wall interval and restores unscaled interface")
	game.resume()
	provider.now_usec += 100000
	game._process(.9)
	check(absf(game.crash_real_clock-before_pause-.1) < .000001, "resume ignores stale render delta and paused gap")
	var before_crash: float = game.crash_clock
	game._physics_process(.003)
	check(absf(game.crash_clock-before_crash-.003) < .000001, "crash physics delta is not scaled a second time")
	game._replace_route(2)
	check(game.run_clock == 0 and game.crash_clock == 0 and game.crash_real_clock == 0 and game.time_rate == 1 and not game.slow_motion, "route replacement clears attempt clocks and slowdown")
	game.queue_free()
	await process_frame; await process_frame
	print("CLOCK_INTEGRATION: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
