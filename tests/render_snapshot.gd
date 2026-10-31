# Exports actual Godot scene geometry and GUI layout for Blender validation on machines without a native display.
extends SceneTree

const TestFixtures = preload("res://tests/test_fixtures.gd")
var fixtures = TestFixtures.new("render_snapshot")
var game: Node3D
var meshes: Dictionary={}
var instances: Array[Dictionary]=[]
var gui: Array[Dictionary]=[]
var mode: String="menu"
var level: int=0

func _initialize() -> void:
	call_deferred("run")

func matrix(t: Transform3D) -> Array:
	return [[t.basis.x.x,t.basis.y.x,t.basis.z.x,t.origin.x],[t.basis.x.y,t.basis.y.y,t.basis.z.y,t.origin.y],[t.basis.x.z,t.basis.y.z,t.basis.z.z,t.origin.z],[0,0,0,1]]
func rgba(c: Color) -> Array:
	return [c.r,c.g,c.b,c.a]

func displayed_label_text(node: Label) -> String:
	if node.autowrap_mode == TextServer.AUTOWRAP_OFF: return node.text
	# Preserve word wrapping in the fallback renderer using the runtime font metrics.
	var font: Font = node.get_theme_font("font")
	var font_size: int = node.get_theme_font_size("font_size")
	var lines: PackedStringArray = []
	for paragraph in node.text.split("\n"):
		var line: String = ""
		for word in paragraph.split(" "):
			var candidate: String = word if line.is_empty() else line + " " + word
			if not line.is_empty() and font.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > node.size.x:
				lines.append(line)
				line = word
			else: line = candidate
		lines.append(line)
	return "\n".join(lines)

func posed_vertices(node: MeshInstance3D, surface: int, arrays: Array) -> PackedVector3Array:
	var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX].duplicate()
	if node.mesh is ArrayMesh and node.mesh.get_blend_shape_count()>0:
		var morphs: Array=node.mesh.surface_get_blend_shape_arrays(surface)
		for shape in morphs.size():
			var weight: float=node.get_blend_shape_value(shape)
			if absf(weight)<.00001: continue
			var deltas: PackedVector3Array=morphs[shape][Mesh.ARRAY_VERTEX]
			for v in vertices.size():
				vertices[v]+=deltas[v]*weight if node.mesh.blend_shape_mode==Mesh.BLEND_SHAPE_MODE_RELATIVE else (deltas[v]-arrays[Mesh.ARRAY_VERTEX][v])*weight
	if node.skin==null or node.skeleton.is_empty(): return vertices
	var skeleton: Skeleton3D=node.get_node_or_null(node.skeleton)
	if skeleton==null: return vertices
	var bones: Variant=arrays[Mesh.ARRAY_BONES]
	var weights: Variant=arrays[Mesh.ARRAY_WEIGHTS]
	if bones==null or weights==null: return vertices
	var palette: Array[Transform3D]=[]
	for bind in node.skin.get_bind_count():
		var bone: int=node.skin.get_bind_bone(bind)
		if bone<0: bone=skeleton.find_bone(node.skin.get_bind_name(bind))
		palette.append(skeleton.get_bone_global_pose(bone)*node.skin.get_bind_pose(bind))
	var influences: int=bones.size()/maxi(1,vertices.size())
	var skeleton_to_mesh: Transform3D=node.global_transform.affine_inverse()*skeleton.global_transform
	for v in vertices.size():
		var posed: Vector3=Vector3.ZERO
		for slot in influences:
			var at: int=v*influences+slot
			var weight: float=weights[at]
			if weight>0: posed+=(palette[bones[at]]*vertices[v])*weight
		vertices[v]=skeleton_to_mesh*posed
	return vertices

func shader_colors(material: ShaderMaterial, arrays: Array) -> Array:
	var base: Color=material.get_shader_parameter("base_color")
	var severity: float=float(material.get_shader_parameter("severity"))/100.0
	var uvs: PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV]
	var colors: Array=[]
	for uv in uvs:
		var grain: float=sin(uv.x*73+sin(uv.y*29)*4)*sin(uv.y*57)
		var patch: float=smoothstep(.22,.76,sin(uv.x*12)*cos(uv.y*9)+grain*.18)
		var bruise: Color=Color(.34,.055,.09).lerp(Color(.16,.035,.12),severity)
		colors.append(rgba(base.lerp(bruise,patch*severity*.84)))
	return colors

func walk(node: Node) -> void:
	if node is Node3D and not node.is_visible_in_tree(): return
	if node is MultiMeshInstance3D and node.multimesh:
		var proxy:=MeshInstance3D.new();proxy.mesh=node.multimesh.mesh;proxy.material_override=node.material_override;game.level_root.add_child(proxy)
		for i in node.multimesh.instance_count:
			proxy.global_transform=node.global_transform*node.get_meta("validation_transforms")[i];walk(proxy)
		proxy.free();return
	if node is MeshInstance3D and node.mesh:
		var id: String=str(node.mesh.get_instance_id())
		# Skin poses and morph coefficients are per-instance, not shared mesh state.
		if node.skin!=null or (node.mesh is ArrayMesh and node.mesh.get_blend_shape_count()>0): id+=":posed:"+str(node.get_instance_id())
		for surface in node.mesh.get_surface_count():
			var active: Material=node.get_active_material(surface)
			if active: id+=":"+str(active.get_instance_id())
		if node.material_overlay: id+=":overlay:"+str(node.material_overlay.get_instance_id())
		if not meshes.has(id):
			var surfaces: Array[Dictionary]=[]
			for i in node.mesh.get_surface_count():
				var arrays:Array=node.mesh.surface_get_arrays(i)
				var vertices:PackedVector3Array=posed_vertices(node,i,arrays)
				var coords:Array=[]
				for v in vertices: coords.append([v.x,v.y,v.z])
				var faces:Array=[]
				var indices:Variant=arrays[Mesh.ARRAY_INDEX]
				if indices!=null and indices.size()>0:
					for j in range(0,indices.size(),3): faces.append([indices[j],indices[j+1],indices[j+2]])
				else:
					for j in range(0,vertices.size(),3): faces.append([j,j+1,j+2])
				var material:Material=node.get_active_material(i)
				var color:Color=material.albedo_color if material is StandardMaterial3D else Color.WHITE
				var vertex_colors: Array=[]
				if material is ShaderMaterial:
					color=material.get_shader_parameter("base_color")
					vertex_colors=shader_colors(material,arrays)
				if node.material_overlay is StandardMaterial3D:
					var overlay: Color=node.material_overlay.albedo_color
					color=color.lerp(Color(overlay.r,overlay.g,overlay.b,1),overlay.a)
				var emission:float=material.emission_energy_multiplier if material is StandardMaterial3D and material.emission_enabled else 0.0
				surfaces.append({"vertices":coords,"faces":faces,"color":rgba(color),"vertex_colors":vertex_colors,"emission":emission,"smooth":node.mesh is ArrayMesh or node.mesh is SphereMesh or node.mesh is CylinderMesh,"metallic":material.metallic if material is StandardMaterial3D else 0.0,"roughness":material.roughness if material is StandardMaterial3D else float(material.get_shader_parameter("roughness_value"))})
			meshes[id]=surfaces
		instances.append({"mesh":id,"matrix":matrix(node.global_transform)})
	if node is Label3D:
		instances.append({"text":node.text,"matrix":matrix(node.global_transform),"size":node.font_size*node.pixel_size,"color":rgba(node.modulate)})
	for child in node.get_children(): walk(child)

func walk_gui(node: Node) -> void:
	if node is Control and (not node.is_visible_in_tree() or node.modulate.a<.02): return
	if node is Panel:
		var style:StyleBox=node.get_theme_stylebox("panel")
		if style is StyleBoxFlat:
			gui.append({"type":"panel","pos":[node.global_position.x,node.global_position.y],"size":[node.size.x,node.size.y],"color":rgba(style.bg_color),"radius":style.corner_radius_top_left})
	elif node is Label:
		gui.append({"type":"text","text":displayed_label_text(node),"pos":[node.global_position.x,node.global_position.y],"size":[node.size.x,node.size.y],"font":node.get_theme_font_size("font_size"),"color":rgba(node.get_theme_color("font_color")*node.modulate*node.self_modulate),"center":node.horizontal_alignment==HORIZONTAL_ALIGNMENT_CENTER})
	elif node is Button:
		var style:StyleBox=node.get_theme_stylebox("normal")
		gui.append({"type":"button","text":node.text,"pos":[node.global_position.x,node.global_position.y],"size":[node.size.x,node.size.y],"font":node.get_theme_font_size("font_size"),"color":rgba(style.bg_color),"text_color":rgba(node.get_theme_color("font_color")*node.modulate*node.self_modulate),"center":node.alignment==HORIZONTAL_ALIGNMENT_CENTER})
	elif node is ProgressBar:
		var fill: StyleBox=node.get_theme_stylebox("fill")
		gui.append({"type":"bar","pos":[node.global_position.x,node.global_position.y],"size":[node.size.x,node.size.y],"value":node.value/maxf(node.max_value,.001),"color":rgba(fill.bg_color if fill is StyleBoxFlat else WreckHUD.MINT)})
	for child in node.get_children(): walk_gui(child)

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--level="):level=int(arg.split("=")[1])
		if arg.begins_with("--mode="):mode=arg.split("=")[1]
	game=fixtures.create_game(root)
	if game == null: return
	game.best_scores.assign([0,0,0]);game.legacy_scores.assign([0,0,0]);game._replace_route(level)
	if mode=="results" and level==2:
		# Earn the earlier chapters through complete runs; never invent a funded save.
		for chapter in [0,1]:
			game._replace_route(chapter);game.start_ready();game.charge=1.0;game.automate=true;game.launch()
			var budget: int=0
			while game.phase!=game.Phase.RESULTS and budget<4500:
				await physics_frame;budget+=1
			if game.phase!=game.Phase.RESULTS:
				printerr("FAIL: campaign capture requires actual settled earlier chapters");quit(1);return
		game._replace_route(level)
	if mode!="menu":
		game.start_ready()
		if mode in ["crash","results","traffic"]:
			# Crash preview uses the measured, unassisted stair-tumble scenario.
			game.charge=.75 if mode in ["crash","traffic"] else 1.0
			game.automate=mode=="results"
			if mode=="traffic": game.skater.position.x=-game.world.level.width*.5+.8
			game.launch()
			var ticks:int=0
			while game.phase!=game.Phase.RESULTS and ticks<4500:
				await physics_frame;ticks+=1
				if mode=="crash" and game.phase==game.Phase.CRASH and game.crash_clock>1.3:break
				if mode=="traffic":
					if game.phase==game.Phase.RUN and game.skater.position.z>=game.world.level.steps*game.world.level.run-2: game.bail_out()
					if game.phase==game.Phase.CRASH and game.crash_clock>=.5 and game.boosts>0: game.crashbreaker()
					if game.world.traffic.all(func(car): return car.broken): break
			if mode=="results" and game.phase!=game.Phase.RESULTS:
				printerr("FAIL: results snapshot must show a completed physical run");quit(1);return
			if mode=="traffic" and not game.world.traffic.all(func(car): return car.broken):
				printerr("FAIL: traffic snapshot must show three actual damaged cars");quit(1);return
	else:
		await process_frame
	if mode=="results":
		# Capture the settled claim after its short presentation-clock count-up.
		var reveal_ticks: int=0
		while game.hud.result_reveal_active and reveal_ticks<150:
			await process_frame
			reveal_ticks+=1
		if game.hud.result_reveal_active:
			printerr("FAIL: result payout reveal must finish before capture");quit(1);return
	# Let layout settle, then freeze and collect exact instantiated meshes.
	await process_frame
	if mode=="ready":
		game.camera.position=game.skater.focus_position()+Vector3(7,4.5,-9);game.camera.look_at(game.skater.focus_position()+Vector3(0,-.4,4))
	elif mode=="menu":
		game.camera.position=game.overview_position();game.camera.look_at(game.camera_target)
	game.hud.update_game(game.rules,game.Phase.keys()[game.phase],game.skater.speed() if game.skater.ragdoll else game.run_speed,game.charge,game.boosts,16.0-game.crash_clock,false)
	game.skater.sync_skin()
	walk(game.level_root);walk_gui(game.hud.root)
	var env:Environment=game.world.root.find_children("*","WorldEnvironment",true,false)[0].environment
	var data:Dictionary={"meshes":meshes,"instances":instances,"gui":gui,"camera":matrix(game.camera.global_transform),"fov":game.camera.fov,"width":1440,"height":900,"background":rgba(env.background_color),"level":level,"mode":mode,"score":game.rules.score,"renderer":"Blender validation of exported Godot scene"}
	var file:=FileAccess.open(fixtures.artifact_path("scene_%d_%s.json"%[level+1,mode]),FileAccess.WRITE);file.store_string(JSON.stringify(data));file.close()
	print("SCENE_EXPORT: ",level+1," ",mode," ",instances.size()," instances; ",fixtures.artifact_path("scene_%d_%s.json"%[level+1,mode]))
	game.queue_free();await process_frame;await process_frame;game=null
	quit()
