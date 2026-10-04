extends SceneTree

func _initialize() -> void:
	var models: Array[String]=["barrel","barrier","cart","cone","crate","domino","hat_clockwork","hat_cone","hat_crane","hero","rider_forearm","rider_head","rider_pelvis","rider_shin","rider_thigh","rider_torso","rider_upper_arm","skateboard","taxi"]
	var sounds: Array[String]=["impact","blast","boost","launch","clack","finish","fracture","receipt","funded","metal_crash","squeal","horn","cascade","roll","engine"]
	var failures: int=0
	for name in models:
		var scene: PackedScene=load("res://assets/models/"+name+".glb")
		if scene==null: failures+=1; continue
		var model: Node=scene.instantiate()
		if name=="hero":
			var skeletons: Array[Node]=model.find_children("*","Skeleton3D",true,false)
			if skeletons.size()!=1 or skeletons[0].get_bone_count()!=11: failures+=1
		if name=="taxi":
			var body: MeshInstance3D=model.get_node_or_null("Body")
			if body==null or not body.mesh is ArrayMesh or body.mesh.get_blend_shape_count()==0: failures+=1
		model.free()
	for name in sounds:
		var stream: AudioStreamWAV=load("res://assets/audio/"+name+".wav")
		if stream==null or stream.data.is_empty(): failures+=1
	for excluded in ["docs/VALIDATION.md","tests/test_game.gd","blender/hero.blend","tools/test.sh"]:
		if FileAccess.file_exists("res://"+excluded): failures+=1; printerr("UNEXPECTED PACKAGED FILE: ",excluded)
	print("PACKAGED_ASSETS: ",models.size()," models / ",sounds.size()," audio; ",failures," failures")
	quit(1 if failures else 0)
