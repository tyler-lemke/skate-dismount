extends SceneTree

var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
 checks += 1
 if not ok:
  failures += 1
  printerr("FAIL: ", message)
func _initialize() -> void: call_deferred("run")

# CPU skinning uses imported glTF bind matrices and actual Godot bone poses.
# It verifies geometry continuity without relying on the headless renderer.
func vertices(mesh: MeshInstance3D, skeleton: Skeleton3D) -> PackedVector3Array:
 var result := PackedVector3Array()
 for surface in mesh.mesh.get_surface_count():
  var a: Array = mesh.mesh.surface_get_arrays(surface)
  var vs: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
  var bones: PackedInt32Array = a[Mesh.ARRAY_BONES]
  var weights: PackedFloat32Array = a[Mesh.ARRAY_WEIGHTS]
  for i in vs.size():
   var point := Vector3.ZERO
   for j in 4:
    var bind: int = bones[i*4+j]
    var name: StringName = mesh.skin.get_bind_name(bind)
    var bone: int = skeleton.find_bone(name) if name != &"" else mesh.skin.get_bind_bone(bind)
    point += skeleton.get_bone_global_pose(bone) * mesh.skin.get_bind_pose(bind) * vs[i] * weights[i*4+j]
   result.append(skeleton.global_transform * point)
 return result

func component_count(mesh: ArrayMesh) -> int:
 var edges: Dictionary = {}
 for surface in mesh.get_surface_count():
  var arrays: Array = mesh.surface_get_arrays(surface)
  var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
  var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
  var keys: Array[String] = []
  for v in positions:
   var key := "%d/%d/%d" % [roundi(v.x*100000),roundi(v.y*100000),roundi(v.z*100000)]
   keys.append(key)
   if not edges.has(key): edges[key] = {}
  for i in range(0,indices.size(),3):
   for j in 3:
    var aa: String = keys[indices[i+j]]
    var bb: String = keys[indices[i+(j+1)%3]]
    edges[aa][bb] = true
    edges[bb][aa] = true
 var visited: Dictionary = {}
 var components := 0
 for key in edges:
  if visited.has(key): continue
  components += 1
  var queue: Array = [key]
  visited[key] = true
  while not queue.is_empty():
   var next: String = queue.pop_back()
   for neighbor in edges[next]:
    if not visited.has(neighbor):
     visited[neighbor] = true
     queue.append(neighbor)
 return components

func run() -> void:
 var group := Node3D.new()
 root.add_child(group)
 var rider := Skater.new()
 group.add_child(rider)
 rider.position = Vector3(3,4,-2)
 rider.rotation.y = .37
 check(rider.skin.skeleton.get_bone_count() == 11,"imported rig has eleven anatomical bones")
 check(rider.skin.region_materials.size() == 11,"all eleven anatomical surfaces have individual damage materials")
 var body: MeshInstance3D
 for mesh in rider.skin.skin_meshes:
  if str(mesh.name) == "HeroSkin": body = mesh
 check(body != null and body.skin != null,"continuous hero mesh imports a real Skin resource")
 check(component_count(body.mesh)==1,"imported hero body is one connected surface across joints and material seams")
 var same_space := true
 for mesh in rider.skin.skin_meshes: same_space = same_space and mesh.global_transform.is_equal_approx(rider.skin.skeleton.global_transform)
 check(same_space,"imported mesh and skeleton frames coincide for CPU render export")
 var weighted_vertices := 0
 var normalized_weights := true
 for surface in body.mesh.get_surface_count():
  var arrays: Array = body.mesh.surface_get_arrays(surface)
  var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
  for i in range(0,weights.size(),4):
   var sum_weights := 0.0
   var influences := 0
   for j in 4:
    sum_weights += weights[i+j]
    if weights[i+j] > .01: influences += 1
   normalized_weights = normalized_weights and absf(sum_weights-1.0)<.002
   if influences>1: weighted_vertices+=1
 check(normalized_weights,"every imported skin vertex has normalized weights")
 check(weighted_vertices > 100,"actual connected body has blended joint weights, not eleven rigid model chunks")
 # Neighboring arms in the rest pose must not drag the pelvis during STARFISH.
 var hip_indices: Array[int] = []
 var vertex_offset := 0
 for surface in body.mesh.get_surface_count():
  var positions: PackedVector3Array = body.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
  for i in positions.size():
   if positions[i].y>.8 and positions[i].y<1.0 and absf(positions[i].x)<.29:hip_indices.append(vertex_offset+i)
  vertex_offset += positions.size()
 var hip_before: PackedVector3Array = vertices(body,rider.skin.skeleton)
 for key in ["arm_l","arm_r","fore_l","fore_r"]:rider.visuals[key].position+=Vector3(3,1,0)
 rider.sync_skin()
 var hip_after: PackedVector3Array = vertices(body,rider.skin.skeleton)
 var hip_drag := 0.0
 for i in hip_indices:hip_drag=maxf(hip_drag,hip_before[i].distance_to(hip_after[i]))
 check(hip_indices.size()>50 and hip_drag<.0001,"moving arms cannot drag pelvis vertices into wings")
 var stances: Array[Vector3] = []
 for style in 3:
  rider.set_pose(style)
  rider.pose_ride(.15,.4,12,false)
  for side in ["l","r"]:
   check(absf((rider.visuals.board.transform.affine_inverse() * rider.foot_contacts[side].sole).y-.034)<.002,"coasting soles remain on deck at every style")
  stances.append(rider.visuals.fore_r.position)
 check(stances[0].distance_to(stances[1])>.4 and stances[1].distance_to(stances[2])>.4,"selected styles retain distinct upper-body silhouettes while riding")
 rider.set_pose(0)
 rider.set_push_phase(.55)
 rider.pose_ride(.4,.3,10,true)
 var kicking: Vector3 = rider.visuals.shin_r.position
 var planted: Vector3 = rider.visuals.shin_l.position
 check(absf((rider.foot_contacts.r.sole.y+.23))<.025,"kick phase sole reaches the ground below the deck")
 check(kicking.x>.45 and not rider.foot_contacts.r.planted,"push stroke leaves deck laterally at kick phase")
 rider.set_push_phase(.82)
 rider.pose_ride(.4,.3,10,true)
 check(rider.visuals.shin_r.position.y>kicking.y+.10,"recovery lifts the pushing foot clear")
 check(rider.visuals.shin_l.position.is_equal_approx(planted),"front foot remains planted through the push cycle")
 rider.pose_ride(.6,.3,10,false)
 rider.sync_skin()
 var before: PackedVector3Array = vertices(body,rider.skin.skeleton)
 var frames: Dictionary = {}
 for key in rider.visuals: frames[key]=rider.visuals[key].global_transform
 rider.bail(Vector3(1,-2,12),.5)
 check(rider.limbs.size()==12 and rider.joints.size()==10,"continuous skin preserves existing physical body and joint counts")
 for key in frames:
  check(rider.body_parts[key].global_transform.is_equal_approx(frames[key]),"first bail transform equals displayed frame for "+key)
 var after: PackedVector3Array = vertices(body,rider.skin.skeleton)
 var biggest_jump := 0.0
 for i in before.size(): biggest_jump=maxf(biggest_jump,before[i].distance_to(after[i]))
 check(biggest_jump<.0001,"first bail has no skinned vertex teleport")
 for key in rider.skin.bone_ids:
  rider.apply_damage_states({key:78.0})
  for region in rider.skin.region_materials:
   for material in rider.skin.region_materials[region]:
    check(is_equal_approx(float(material.get_shader_parameter("severity")),78.0 if region==key else 0.0),"damage isolates "+key+" from "+region)
 rider.apply_damage_states({})
 for materials in rider.skin.region_materials.values():
  for material in materials: check(float(material.get_shader_parameter("severity"))==0.0,"healthy replay restores skin material")
 var head: RigidBody3D = rider.body_parts.head
 head.freeze=true
 head.position+=Vector3(.2,.3,.4)
 head.rotation.z=.8
 rider.sync_skin()
 var bone: int = rider.skin.bone_ids.head
 var displayed: Transform3D = rider.skin.skeleton.global_transform * rider.skin.skeleton.get_bone_global_pose(bone)
 check(displayed.is_equal_approx(head.global_transform),"replay-applied physics frame immediately drives visible head bone")
 check(head.get_node("RiderModel/CrashHat")!=null,"head attachment survives skinned ragdoll handoff")
 var cab: Node3D = load("res://assets/models/taxi.glb").instantiate()
 group.add_child(cab)
 var shell: MeshInstance3D = cab.get_node("Body")
 check(shell.find_blend_shape_by_name("Crumple")>=0,"taxi imports deformation shape")
 for name in ["Wheel_FL","Wheel_FR","Wheel_RL","Wheel_RR"]:check(cab.get_node_or_null(name)!=null,"taxi wheel pivot imports: "+name)
 for style in [1,2]:
  var other := Skater.new()
  group.add_child(other)
  other.set_pose(style)
  other.pose_ride(.2,-.4,13,false)
  other.sync_skin()
  var other_mesh: MeshInstance3D
  for candidate in other.skin.skin_meshes:
   if str(candidate.name)=="HeroSkin":other_mesh=candidate
  var posed: PackedVector3Array = vertices(other_mesh,other.skin.skeleton)
  other.bail(Vector3(0,-2,11),.5)
  var physical: PackedVector3Array = vertices(other_mesh,other.skin.skeleton)
  var discontinuity := 0.0
  for i in posed.size():discontinuity=maxf(discontinuity,posed[i].distance_to(physical[i]))
  check(discontinuity<.0001,"style %d first bail preserves every displayed body vertex" % style)
 # Expose measured outcomes, not a claim of human-rated animation quality.
 print("RIDER_SKIN: ",checks," checks, ",failures," failures; blended vertices ",weighted_vertices,"; bail vertex discontinuity ",biggest_jump)
 group.queue_free()
 await process_frame
 quit(1 if failures else 0)
