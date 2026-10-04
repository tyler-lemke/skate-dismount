class_name RiderSkin
extends Node3D

const HERO = preload("res://assets/models/hero.glb")
const DAMAGE_SHADER = preload("res://scripts/rider_skin.gdshader")
var skeleton: Skeleton3D
var region_materials: Dictionary = {}
var bone_ids: Dictionary = {}
var corrections: Dictionary = {}
var skin_meshes: Array[MeshInstance3D] = []

func setup(rest_centers: Dictionary) -> void:
 var model: Node3D = HERO.instantiate()
 add_child(model)
 skeleton = model.find_children("*", "Skeleton3D", true, false)[0]
 for key in rest_centers:
  if key == "board": continue
  var bone: int = skeleton.find_bone(key)
  assert(bone >= 0, "Hero is missing physical region " + key)
  bone_ids[key] = bone
  # Anatomical model rest centers may differ from the physical standby pose.
  # Preserve the imported bone axes, but place every bone origin on its body frame.
  corrections[key] = Transform3D(skeleton.get_bone_global_rest(bone).basis, Vector3.ZERO)
 for node in model.find_children("*", "MeshInstance3D", true, false):
  var mesh: MeshInstance3D = node
  skin_meshes.append(mesh)
  # The rig stays under the launch root while its bones follow the physical crash.
  mesh.custom_aabb = AABB(Vector3(-300,-300,-300), Vector3(600,600,600))
  for surface in mesh.mesh.get_surface_count():
   var source: Material = mesh.get_active_material(surface)
   if source == null: continue
   var key: String = source.resource_name.split("__")[0]
   if not bone_ids.has(key): continue
   var damaged := ShaderMaterial.new()
   damaged.shader = DAMAGE_SHADER
   damaged.resource_name = source.resource_name
   damaged.set_shader_parameter("base_color", source.albedo_color)
   damaged.set_shader_parameter("roughness_value", source.roughness)
   damaged.set_shader_parameter("severity", 0.0)
   mesh.set_surface_override_material(surface, damaged)
   if not region_materials.has(key): region_materials[key] = []
   region_materials[key].append(damaged)

func sync_parts(parts: Dictionary) -> void:
 if skeleton == null: return
 var desired: Dictionary = {}
 var to_skeleton: Transform3D = skeleton.global_transform.affine_inverse()
 for key in bone_ids:
  if parts.has(key) and is_instance_valid(parts[key]):
   desired[bone_ids[key]] = to_skeleton * parts[key].global_transform * corrections[key]
 # Parent-relative poses avoid global-pose overrides and expose the exact final poses to replay/export.
 for bone in range(skeleton.get_bone_count()):
  if not desired.has(bone): continue
  var parent: int = skeleton.get_bone_parent(bone)
  var local_pose: Transform3D = desired[bone]
  if desired.has(parent): local_pose = desired[parent].affine_inverse() * local_pose
  skeleton.set_bone_pose(bone, local_pose)
 skeleton.force_update_all_bone_transforms()

func set_damage(region: String, severity: float) -> void:
 for material in region_materials.get(region, []):
  material.set_shader_parameter("severity", clampf(severity, 0.0, 100.0))
