extends RefCounted

# Physical ragdoll and pre-bail sweeps share one authored shape contract. Each
# call owns a new mutable resource; replay and attempts never share shapes.
static func torso_points() -> PackedVector3Array:
	var points := PackedVector3Array()
	for ring in 2:
		for index in 8:
			var angle: float = TAU * index / 8.0
			points.append(Vector3(cos(angle) * (.24 if ring == 0 else .34), -.35 if ring == 0 else .35, sin(angle) * (.18 if ring == 0 else .22)))
	return points

static func create_shape(key: String) -> Shape3D:
	if key == "torso":
		var core := ConvexPolygonShape3D.new()
		core.points = torso_points()
		core.custom_solver_bias = .5
		return core
	var box := BoxShape3D.new()
	match key:
		"pelvis": box.size = Vector3(.52,.28,.38)
		"head": box.size = Vector3(.44,.48,.42)
		"fore_l", "fore_r": box.size = Vector3(.28,.44,.30)
		"board": box.size = Vector3(.76,.18,1.65)
		_: box.size = Vector3(.21,.35,.24)
	if key != "board": box.custom_solver_bias = .3
	return box

static func offset(key: String) -> Transform3D:
	return Transform3D(Basis.IDENTITY, Vector3(0,.04,0) if key == "torso" else (Vector3(0,-.03,0) if key.begins_with("fore_") else Vector3.ZERO))

static func radius(key: String) -> float:
	if key == "torso":
		var maximum: float = 0.0
		for point in torso_points(): maximum = maxf(maximum, point.length())
		return maximum
	return bounds_size(key).length() * .5

static func bounds_size(key: String) -> Vector3:
	match key:
		"torso": return Vector3(.68,.70,.44)
		"pelvis": return Vector3(.52,.28,.38)
		"head": return Vector3(.44,.48,.42)
		"fore_l", "fore_r": return Vector3(.28,.44,.30)
		"board": return Vector3(.76,.18,1.65)
		_: return Vector3(.21,.35,.24)
