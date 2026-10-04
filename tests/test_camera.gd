extends SceneTree
const CameraHelper = preload("res://scripts/crash_camera.gd")

var checks: int=0
var failures: int=0
var world: Node3D

func _initialize() -> void: call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks+=1
	if not condition:
		failures+=1
		printerr("FAIL: ",message)

func box(at: Vector3, size: Vector3, layer: int = 1) -> StaticBody3D:
	var body:=StaticBody3D.new()
	body.collision_layer=layer
	body.collision_mask=0
	body.position=at
	var collider:=CollisionShape3D.new()
	var shape:=BoxShape3D.new(); shape.size=size; collider.shape=shape
	body.add_child(collider)
	world.add_child(body)
	return body

func run() -> void:
	world=Node3D.new(); root.add_child(world)
	var target:=Vector3(0,1,0)
	var desired:=Vector3(5.8,3.4,-6.8)
	var space:PhysicsDirectSpaceState3D=world.get_world_3d().direct_space_state
	var clear:Vector3=CameraHelper.choose_position(space,target,desired,0.0)
	check(clear==desired,"unblocked default crash composition stays unchanged")
	check(CameraHelper.clear_view(space,clear,target),"unblocked view has actual line of sight")
	var rider:=box((target+desired)*.5,Vector3(2.0,3.0,2.0),4)
	await physics_frame
	check(CameraHelper.choose_position(space,target,desired,0.0)==desired,"rider collision layer cannot redirect its own camera")
	rider.queue_free(); await physics_frame
	var cart:=box((target+desired)*.5,Vector3(1.0,2.0,1.0))
	await physics_frame
	check(not CameraHelper.clear_view(space,desired,target),"real cart collider blocks the default view")
	var raised:Vector3=CameraHelper.choose_position(space,target,desired,0.0)
	check(raised.y>desired.y and raised.x>0,"blocked camera first rises on the same side")
	check(CameraHelper.clear_view(space,raised,target),"raised vantage restores a real clear ray")
	check(raised.distance_to(target)<desired.distance_to(target)*1.6,"raised vantage does not zoom away")
	check(raised.y<=11.0 and raised.y>=1.5,"raised vantage respects the local height band")
	cart.queue_free(); await physics_frame
	var tower:=box((target+desired)*.5,Vector3(3.0,10.0,3.0))
	await physics_frame
	var mirrored:Vector3=CameraHelper.choose_position(space,target,desired,0.0)
	check(mirrored.x<0,"tall same-side obstruction selects mirrored angle")
	check(CameraHelper.clear_view(space,mirrored,target),"mirrored angle clears the actual collider")
	check(mirrored.distance_to(target)<desired.distance_to(target)*1.6,"mirrored angle stays close to the rider")
	tower.queue_free(); await physics_frame
	var low:Vector3=CameraHelper.choose_position(space,target,Vector3(5,-3,-6),0.0)
	check(low.y>=1.5 and low.is_finite(),"camera stays above the floor with finite coordinates")
	var many: Array[Vector3]=[Vector3(5,4,-7),Vector3(-5,2,-7),Vector3(0,2,-6),Vector3(8,10,-10)]
	for candidate in many:
		var chosen:Vector3=CameraHelper.choose_position(space,target,candidate,0.0)
		check(chosen.is_finite() and chosen.y>=1.5,"candidate produces a bounded finite above-floor position")
		check(chosen.distance_to(target)<=maxf(candidate.distance_to(target)*1.6,3.0),"candidate keeps its original chase scale")
	world.queue_free(); await process_frame
	print("CAMERA: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
