extends Node

# An explicit fixture provider: each rendered test frame advances an independent
# 1/60-second wall sequence, even when simulation time changes or pauses.
# Production uses Time.get_ticks_usec() through scripts/game_clock.gd instead.
const Clock = preload("res://scripts/game_clock.gd")
var clock = Clock.new()
var frame_count: int = 0
var now_usec: int = 0
var active_seconds: float:
	get: return clock.active_seconds

func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = -1000
	clock.rebase(0)

func _process(_simulation_delta: float) -> void:
	frame_count += 1
	now_usec = roundi(float(frame_count)*1000000.0/60.0)

func rebase(_unused_runtime_stamp: int = -1) -> void:
	clock.rebase(now_usec)

func sample(paused: bool = false) -> float:
	return clock.sample_at(now_usec,paused)
