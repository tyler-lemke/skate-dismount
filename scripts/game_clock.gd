extends RefCounted
## Simulation uses Godot's physics delta. Presentation timers use this monotonic
## clock, independently of whichever slow-motion rate was selected this frame.
var _last_usec: int = -1
var active_seconds: float = 0.0

func rebase(now_usec: int = -1) -> void:
	_last_usec = Time.get_ticks_usec() if now_usec < 0 else now_usec

func sample(paused: bool = false) -> float:
	return sample_at(Time.get_ticks_usec(), paused)

func sample_at(now_usec: int, paused: bool = false) -> float:
	if _last_usec < 0:
		_last_usec = now_usec
		return 0.0
	var elapsed: float = float(maxi(0, now_usec - _last_usec)) / 1000000.0
	_last_usec = maxi(_last_usec, now_usec)
	if paused: return 0.0
	active_seconds += elapsed
	return elapsed
