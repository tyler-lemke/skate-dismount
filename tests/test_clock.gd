extends SceneTree
const Clock = preload("res://scripts/game_clock.gd")
var checks: int = 0
var failures: int = 0

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + description)

func _initialize() -> void:
	var clock = Clock.new()
	check(clock.sample_at(1000000) == 0.0, "first sample establishes origin")
	check(is_equal_approx(clock.sample_at(1250000), .25), "wall interval measured independently of simulation")
	check(clock.sample_at(1400000, true) == 0.0, "paused interval excluded")
	check(is_equal_approx(clock.sample_at(1450000), .05), "resume excludes paused interval")
	clock.rebase(8000000)
	check(is_equal_approx(clock.sample_at(8050000), .05), "explicit resume anchor excludes gap without rendering")
	check(clock.sample_at(7000000) == 0.0, "backwards sample does not produce negative time")
	check(is_equal_approx(clock.sample_at(8100000), .05), "backwards sample does not move anchor backwards")
	check(is_equal_approx(clock.active_seconds, .40), "only active intervals accumulated")
	for rate in [1.0, .55, .25, .18]:
		for next_rate in [1.0, .55, .25, .18]:
			var prior: float = clock.active_seconds
			clock.sample_at(8200000 + checks * 100000)
			clock.rebase(10000000)
			check(is_equal_approx(clock.sample_at(10100000), .1), "rate transition %s to %s does not alter wall time" % [rate, next_rate])
			check(clock.active_seconds >= prior, "active wall time remains monotonic")
	print("CLOCK: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
