extends RefCounted
## One attempt, two time-stamped tracks. Playback reads fresh values and never
## writes captured dictionaries. Equal-time camera captures prefer the latest.
var header: Dictionary = {}
var duration: float = 0.0
var _actors: Array[Dictionary] = []
var _cameras: Array[Dictionary] = []
var _sealed: bool = false
var _sequence: int = 0

func begin(attempt_header: Dictionary) -> void:
	header = attempt_header.duplicate(true)
	duration = 0.0
	_actors.clear(); _cameras.clear()
	_sealed = false; _sequence = 0

func capture_actors(time: float, state: Dictionary) -> bool:
	if _sealed or not is_finite(time) or time < 0: return false
	if not _actors.is_empty() and time < float(_actors.back().time): return false
	var frame: Dictionary = state.duplicate(true)
	frame.time = time
	if not _actors.is_empty() and is_equal_approx(time, float(_actors.back().time)):
		_actors[_actors.size()-1] = frame
	else: _actors.append(frame)
	return true

func capture_camera(sample_time: float, transform: Transform3D, fov: float, boundary: String = "render", boundary_time: float = -1.0) -> bool:
	if _sealed or not is_finite(sample_time) or not transform.origin.is_finite() or not is_finite(fov) or fov <= 0: return false
	_sequence += 1
	var frame: Dictionary = {"time":sample_time,"sequence":_sequence,"transform":transform,"fov":fov,"boundary":boundary,"boundary_time":boundary_time,"age":maxf(0,boundary_time-sample_time) if boundary_time >= 0 else 0.0}
	# Boundary samples can refer to an older completed render. Their source time
	# stays intact; insertion/ties are explicit rather than made simultaneous.
	var index: int = 0
	while index < _cameras.size() and float(_cameras[index].time) < sample_time: index += 1
	if index < _cameras.size() and is_equal_approx(float(_cameras[index].time), sample_time): _cameras[index] = frame
	else: _cameras.insert(index, frame)
	return true

func seal(final_time: float) -> bool:
	if _sealed or not is_finite(final_time) or final_time < 0 or _actors.is_empty(): return false
	if final_time < float(_actors.back().time): return false
	duration = final_time
	_sealed = true
	return true

func can_play() -> bool:
	return _sealed and duration > 0 and _actors.size() >= 2 and not _cameras.is_empty()

static func _bracket(frames: Array[Dictionary], time: float) -> Dictionary:
	if frames.is_empty(): return {}
	if time <= float(frames.front().time): return {"a":0,"b":0,"weight":0.0}
	if time >= float(frames.back().time): return {"a":frames.size()-1,"b":frames.size()-1,"weight":0.0}
	var low: int = 0
	var high: int = frames.size()-1
	while high-low > 1:
		var middle: int = (low+high)/2
		if float(frames[middle].time) <= time: low = middle
		else: high = middle
	return {"a":low,"b":high,"weight":(time-float(frames[low].time))/(float(frames[high].time)-float(frames[low].time))}

func sample_actors(time: float) -> Dictionary:
	var pair: Dictionary = _bracket(_actors,clampf(time,0,duration))
	if pair.is_empty(): return {}
	var first: Dictionary = _actors[pair.a]
	var second: Dictionary = _actors[pair.b]
	var result: Dictionary = first.duplicate(true)
	var transforms: Dictionary = {}
	for id in first.get("actors",{}):
		var initial: Transform3D = first.actors[id]
		transforms[id] = initial.interpolate_with(second.actors[id],pair.weight) if second.get("actors",{}).has(id) else initial
	result.actors = transforms
	result.time = clampf(time,0,duration)
	return result

func sample_camera(time: float) -> Dictionary:
	var pair: Dictionary = _bracket(_cameras,clampf(time,0,duration))
	if pair.is_empty(): return {}
	var first: Dictionary = _cameras[pair.a]
	var second: Dictionary = _cameras[pair.b]
	return {"transform":first.transform.interpolate_with(second.transform,pair.weight),"fov":lerpf(first.fov,second.fov,pair.weight),"source_a_time":first.time,"source_b_time":second.time}

func actor_frames() -> Array[Dictionary]:
	return _actors.duplicate(true)

func camera_frames() -> Array[Dictionary]:
	return _cameras.duplicate(true)
