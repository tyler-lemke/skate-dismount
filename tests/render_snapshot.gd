# Exports actual Godot scene geometry and GUI layout for Blender validation on machines without a native display.
extends SceneTree
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

func walk(node: Node) -> void:
	if node is MultiMeshInstance3D and node.multimesh:
		var proxy:=MeshInstance3D.new();proxy.mesh=node.multimesh.mesh;proxy.material_override=node.material_override;game.level_root.add_child(proxy)
		for i in node.multimesh.instance_count:
			proxy.global_transform=node.global_transform*node.get_meta("validation_transforms")[i];walk(proxy)
		proxy.free();return
	if node is MeshInstance3D and node.mesh:
		var id: String=str(node.mesh.get_instance_id())
		if not meshes.has(id):
			var surfaces: Array[Dictionary]=[]
			for i in node.mesh.get_surface_count():
				var arrays:Array=node.mesh.surface_get_arrays(i)
				var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
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
				var emission:float=material.emission_energy_multiplier if material is StandardMaterial3D and material.emission_enabled else 0.0
				surfaces.append({"vertices":coords,"faces":faces,"color":rgba(color),"emission":emission,"smooth":node.mesh is SphereMesh or node.mesh is CylinderMesh})
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
		gui.append({"type":"text","text":node.text,"pos":[node.global_position.x,node.global_position.y],"size":[node.size.x,node.size.y],"font":node.get_theme_font_size("font_size"),"color":rgba(node.get_theme_color("font_color")*node.modulate*node.self_modulate),"center":node.horizontal_alignment==HORIZONTAL_ALIGNMENT_CENTER})
	elif node is Button:
		var style:StyleBox=node.get_theme_stylebox("normal")
		gui.append({"type":"button","text":node.text,"pos":[node.global_position.x,node.global_position.y],"size":[node.size.x,node.size.y],"font":node.get_theme_font_size("font_size"),"color":rgba(style.bg_color),"text_color":rgba(node.get_theme_color("font_color")*node.modulate*node.self_modulate),"center":node.alignment==HORIZONTAL_ALIGNMENT_CENTER})
	elif node is ProgressBar:
		gui.append({"type":"bar","pos":[node.global_position.x,node.global_position.y],"size":[node.size.x,node.size.y],"value":node.value,"color":rgba(WreckHUD.MINT)})
	for child in node.get_children(): walk_gui(child)

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--level="):level=int(arg.split("=")[1])
		if arg.begins_with("--mode="):mode=arg.split("=")[1]
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.test_mode=true;game.save_path="res://builds/snapshot_records.json"
	game.select_route(level)
	if mode!="menu":
		game.start_ready()
		if mode in ["crash","results"]:
			game.charge=1;game.automate=true;game.launch()
			var ticks:int=0
			while game.phase!=game.Phase.RESULTS and ticks<2300:
				await physics_frame;ticks+=1
				if mode=="crash" and game.phase==game.Phase.CRASH and game.crash_clock>3.9:break
	else:
		await process_frame
	# Let layout settle, then freeze and collect exact instantiated meshes.
	await process_frame
	if mode=="ready":
		game.camera.position=game.skater.focus_position()+Vector3(7,4.5,-9);game.camera.look_at(game.skater.focus_position()+Vector3(0,-.4,4))
	elif mode=="menu":
		game.camera.position=game.overview_position();game.camera.look_at(game.camera_target)
	game.hud.update_game(game.rules,game.Phase.keys()[game.phase],game.skater.speed() if game.skater.ragdoll else game.run_speed,game.charge,game.boosts,19.0-game.crash_clock,false)
	walk(game.level_root);walk_gui(game.hud.root)
	var env:Environment=game.world.root.find_children("*","WorldEnvironment",true,false)[0].environment
	var data:Dictionary={"meshes":meshes,"instances":instances,"gui":gui,"camera":matrix(game.camera.global_transform),"fov":game.camera.fov,"width":1440,"height":900,"background":rgba(env.background_color),"level":level,"mode":mode,"score":game.rules.score,"renderer":"Blender validation of exported Godot scene"}
	var file:=FileAccess.open("res://builds/scene_%d_%s.json"%[level+1,mode],FileAccess.WRITE);file.store_string(JSON.stringify(data));file.close()
	print("SCENE_EXPORT: ",level+1," ",mode," ",instances.size()," instances")
	game.queue_free();await process_frame;await process_frame;game=null
	quit()
