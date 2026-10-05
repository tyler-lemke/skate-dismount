extends RefCounted

# One attempt's isolated display. Catalog templates are detached inert Nodes;
# dispose_catalog releases them when its tape is discarded. Playback owns its
# own mesh/material instances and never calls gameplay snapshot adapters.
const REPLAY_QUERY_LAYER: int = 0x10
const REPLAY_CAMERA_MASK: int = 0x11
var root: Node3D
var actors: Dictionary = {}
var query_bodies: Dictionary = {}
var visual_states: Dictionary = {}
var rider: Skater
var markers: Dictionary = {}

static func capture_catalog(props: Array, skater: Node3D) -> Dictionary:
	var catalog: Dictionary = {}
	for prop in props:
		if not is_instance_valid(prop): continue
		var id: String = str(prop.stable_id)
		if id.is_empty(): continue
		var ignored: Array[Material] = []
		if prop.fuse_material != null: ignored.append(prop.fuse_material)
		if prop.damaged_material != null: ignored.append(prop.damaged_material)
		var template: Node3D = _clone_visual(prop.visual,ignored) if is_instance_valid(prop.visual) else Node3D.new()
		var shapes: Array[Dictionary] = []
		for collision in prop.find_children("*","CollisionShape3D",true,false):
			if collision.shape == null or collision.disabled: continue
			shapes.append({"shape":collision.shape.duplicate(true),"local_transform":prop.global_transform.affine_inverse() * collision.global_transform})
		var lamps: Array[Node3D] = []
		if prop is TrafficCar:
			for lamp in prop.lamps:
				var copy: Node3D = _clone_visual(lamp)
				copy.transform = prop.global_transform.affine_inverse() * lamp.global_transform
				lamps.append(copy)
		catalog[id] = {"kind":prop.kind,"traffic":prop is TrafficCar,"explosive":prop.explosive,"visual_template":template,
			"visual_transform":prop.visual.transform if is_instance_valid(prop.visual) else Transform3D.IDENTITY,
			"spawn_transform":prop.global_transform,"shapes":shapes,"lamp_templates":lamps}
	if is_instance_valid(skater):
		for key in skater.offsets:
			var part: Node3D = skater.body_parts.get(key,skater.visuals.get(key))
			if not is_instance_valid(part): continue
			var id: String = "rider/"+str(key)
			var entry: Dictionary = {"kind":"board" if key == "board" else "rider","part":str(key),"spawn_transform":part.global_transform,"shapes":[],"lamp_templates":[]}
			if key == "board":
				var model: Node3D = part.get_node_or_null("RiderModel") if skater.ragdoll else part
				entry.visual_template = _clone_visual(model) if model != null else Node3D.new()
				entry.visual_transform = model.transform if skater.ragdoll and model != null else Transform3D.IDENTITY
			catalog[id] = entry
	return catalog

static func dispose_catalog(catalog: Dictionary) -> void:
	for entry in catalog.values():
		var template: Node = entry.get("visual_template")
		if is_instance_valid(template): template.free()
		for lamp in entry.get("lamp_templates",[]):
			if is_instance_valid(lamp): lamp.free()
	catalog.clear()

static func _clone_visual(source: Node3D, ignored_overrides: Array[Material] = []) -> Node3D:
	var clone: Node3D = source.duplicate(0)
	_sanitize_clone(clone)
	_isolate_meshes(source,clone,ignored_overrides)
	clone.visible = true
	return clone

static func _sanitize_clone(node: Node) -> void:
	node.set_script(null)
	node.owner = null
	for key in node.get_meta_list(): node.remove_meta(key)
	node.process_mode = Node.PROCESS_MODE_DISABLED
	if node is Node3D: node.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	if node is AnimationPlayer: node.stop()
	for child in node.get_children():
		if child is CollisionObject3D or child is CollisionShape3D or child is Joint3D:
			node.remove_child(child)
			child.free()
		else: _sanitize_clone(child)

static func _isolate_meshes(source: Node, clone: Node, ignored: Array[Material]) -> void:
	if source is MeshInstance3D and clone is MeshInstance3D:
		if source.mesh != null: clone.mesh = source.mesh.duplicate()
		clone.material_override = null
		clone.material_overlay = source.material_overlay.duplicate(true) if source.material_overlay != null else null
		for surface in source.mesh.get_surface_count() if source.mesh != null else 0:
			var material: Material = source.get_active_material(surface)
			if ignored.has(source.material_override):
				material = source.get_surface_override_material(surface)
				if material == null: material = source.mesh.surface_get_material(surface)
			clone.set_surface_override_material(surface,material.duplicate(true) if material != null else null)
	for child in clone.get_children():
		var original: Node = source.get_node_or_null(NodePath(str(child.name)))
		if original != null: _isolate_meshes(original,child,ignored)

func create(parent: Node3D, catalog: Dictionary, rider_metadata: Dictionary = {}) -> void:
	dispose()
	root = Node3D.new()
	root.name = "ReplayPresentation"
	root.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	parent.add_child(root)
	var has_rider: bool = false
	for entry in catalog.values():
		if entry.kind in ["rider","board"]: has_rider = true
	if has_rider:
		rider = Skater.new()
		rider.name = "ReplayRider"
		rider.ragdoll = true
		rider.hat_index = int(rider_metadata.get("hat_index",0))
		if rider_metadata.has("offsets"): rider.offsets = rider_metadata.offsets.duplicate(true)
		root.add_child(rider)
		rider.set_process(false)
		rider.set_physics_process(false)
		rider.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		for part in rider.visuals.values(): part.visible = false
	for id in catalog:
		var entry: Dictionary = catalog[id]
		var actor := Node3D.new()
		actor.name = str(id).replace("/","_")
		actor.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		root.add_child(actor)
		actor.global_transform = entry.get("spawn_transform",Transform3D.IDENTITY)
		actors[id] = actor
		var visual: Node3D
		if entry.get("visual_template") != null and is_instance_valid(entry.visual_template):
			visual = _clone_visual(entry.visual_template)
			actor.add_child(visual)
			visual.transform = entry.get("visual_transform",Transform3D.IDENTITY)
		var lamps: Array[Node3D] = []
		for lamp in entry.get("lamp_templates",[]):
			var copy: Node3D = _clone_visual(lamp)
			actor.add_child(copy)
			copy.transform = lamp.transform
			lamps.append(copy)
		var mesh_states: Array[Dictionary] = []
		var wheels: Array[Node3D] = []
		if visual != null:
			for mesh in visual.find_children("*","MeshInstance3D",true,false): mesh_states.append(_mesh_state(mesh))
			if visual is MeshInstance3D: mesh_states.append(_mesh_state(visual))
			for child in visual.get_children():
				if child is Node3D and str(child.name).begins_with("Wheel_"): wheels.append(child)
		var has_dent: bool = false
		for mesh_state in mesh_states:
			if mesh_state.dent >= 0: has_dent = true
		visual_states[id] = {"meshes":mesh_states,"wheels":wheels,"lamps":lamps,"damage":false,"fuse_glow":-1.0,
			"has_dent":has_dent,"damage_color":Color("c56746") if entry.get("explosive",false) else Color("657c7c")}
		if entry.kind == "rider" and rider != null:
			var part: String = str(entry.get("part",str(id).trim_prefix("rider/")))
			rider.body_parts[part] = actor
			_create_marker(part,actor)
			if part == "head":
				var head := Node3D.new()
				head.name = "RiderModel"
				actor.add_child(head)
				rider.attach_hat(head)
				_isolate_meshes(head,head,[])
		if entry.kind not in ["rider","board"] and not entry.get("shapes",[]).is_empty():
			var body := StaticBody3D.new()
			body.name = "ReplayQuery_"+str(id).replace("/","_")
			body.collision_layer = REPLAY_QUERY_LAYER
			body.collision_mask = 0
			body.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
			root.add_child(body)
			body.global_transform = actor.global_transform
			for description in entry.shapes:
				var collision := CollisionShape3D.new()
				collision.shape = description.shape.duplicate(true)
				body.add_child(collision)
				collision.transform = description.local_transform
				collision.force_update_transform()
			body.force_update_transform()
			query_bodies[id] = body
	if rider != null: rider.sync_skin()

func _mesh_state(mesh: MeshInstance3D) -> Dictionary:
	var base: Array[Material] = []
	for surface in mesh.mesh.get_surface_count() if mesh.mesh != null else 0: base.append(mesh.get_active_material(surface))
	var dent: int = -1
	if mesh.mesh is ArrayMesh:
		for index in mesh.mesh.get_blend_shape_count():
			if mesh.mesh.get_blend_shape_name(index) == "Crumple": dent = index
	var mutable_materials: Array[Material] = []
	for material in base: mutable_materials.append(material.duplicate(true) if material != null else null)
	return {"mesh":mesh,"base_materials":base,"dent":dent,"mutable_materials":mutable_materials}

func _create_marker(part: String, actor: Node3D) -> void:
	var patch := MeshInstance3D.new()
	patch.name = "ReplayInjuryMarker"
	var ring := TorusMesh.new()
	var radius: float = .32 if part == "torso" else (.25 if part in ["head","pelvis"] else .145)
	ring.inner_radius = radius * .72
	ring.outer_radius = radius
	ring.rings = 12
	ring.ring_segments = 8
	patch.mesh = ring
	patch.position.y = -.15 if part not in ["head","pelvis"] else 0.0
	patch.scale.y = .65
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.emission_enabled = true
	material.emission_energy_multiplier = .7
	patch.material_override = material
	patch.visible = false
	actor.add_child(patch)
	markers[part] = patch

func apply(sample: Dictionary) -> void:
	if not is_instance_valid(root): return
	var frames: Dictionary = sample.get("actors",{})
	var present: Dictionary = sample.get("present",{})
	var visual: Dictionary = sample.get("visual",{})
	for id in actors:
		var actor: Node3D = actors[id]
		var state: Dictionary = visual.get(id,{})
		var is_present: bool = bool(present.get(id,frames.has(id)))
		actor.visible = is_present and bool(state.get("visible",true))
		if frames.has(id): actor.global_transform = frames[id]
		if query_bodies.has(id):
			var body: StaticBody3D = query_bodies[id]
			body.global_transform = actor.global_transform
			body.collision_layer = REPLAY_QUERY_LAYER if actor.visible else 0
			body.force_update_transform()
		_apply_visual(visual_states[id],state)
	if rider != null:
		var limb_states: Dictionary = sample.get("limbs",{})
		rider.apply_damage_states(limb_states)
		for part in markers:
			var severity: float = clampf(float(limb_states.get(part,0.0)),0,100)
			var patch: MeshInstance3D = markers[part]
			patch.visible = severity > 0
			var material: StandardMaterial3D = patch.material_override
			material.albedo_color = Color("ffcb57").lerp(Color("ff304f"),severity / 100.0)
			material.emission = material.albedo_color
			patch.scale.x = .85 + severity * .003
			patch.scale.z = patch.scale.x
		rider.visible = actors.has("rider/torso") and actors["rider/torso"].visible
		rider.sync_skin()

func _apply_visual(display: Dictionary, state: Dictionary) -> void:
	var damage: bool = bool(state.get("damage",false))
	var fuse_glow: float = maxf(0.0,float(state.get("fuse_glow",0.0)))
	if damage != display.damage or not is_equal_approx(fuse_glow,float(display.fuse_glow)):
		for entry in display.meshes:
			var mesh: MeshInstance3D = entry.mesh
			if entry.dent >= 0: mesh.set_blend_shape_value(entry.dent,.85 if damage else 0.0)
			for surface in entry.base_materials.size():
				var base: Material = entry.base_materials[surface]
				var material: Material = base
				if base is StandardMaterial3D and (fuse_glow > 0.0 or (damage and not display.has_dent)):
					material = entry.mutable_materials[surface]
					material.albedo_color = base.albedo_color
					material.roughness = base.roughness
					material.emission_enabled = base.emission_enabled
					material.emission = base.emission
					material.emission_energy_multiplier = base.emission_energy_multiplier
					if damage and not display.has_dent:
						material.albedo_color = display.damage_color
						material.roughness = .85
					if fuse_glow > 0.0:
						material.albedo_color = Color("ff8b41")
						material.emission_enabled = true
						material.emission = Color("ff5924")
						material.emission_energy_multiplier = fuse_glow
				mesh.set_surface_override_material(surface,material)
		display.damage = damage
		display.fuse_glow = fuse_glow
	for wheel in display.wheels: wheel.rotation.x = float(state.get("wheel_phase",0.0))
	for lamp in display.lamps: lamp.visible = bool(state.get("brake_lights",false))

func focus_position() -> Vector3:
	if actors.has("rider/torso") and is_instance_valid(actors["rider/torso"]): return actors["rider/torso"].global_position
	return root.global_position if is_instance_valid(root) else Vector3.ZERO

func query_context(space: PhysicsDirectSpaceState3D, floor_height: Callable) -> Dictionary:
	return {"space":space,"mask":REPLAY_CAMERA_MASK,"exclude":[],"floor_height":floor_height}

func dispose() -> void:
	actors.clear()
	query_bodies.clear()
	visual_states.clear()
	markers.clear()
	rider = null
	if is_instance_valid(root): root.free()
	root = null
