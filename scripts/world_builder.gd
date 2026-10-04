class_name WreckWorld
extends RefCounted

const PROP_SCENES: Dictionary = {
	"domino": preload("res://assets/models/domino.glb"), "barrel": preload("res://assets/models/barrel.glb"),
	"crate": preload("res://assets/models/crate.glb"), "cart": preload("res://assets/models/cart.glb"),
	"taxi": preload("res://assets/models/taxi.glb"), "cone": preload("res://assets/models/cone.glb"),
	"barrier": preload("res://assets/models/barrier.glb")
}
var root: Node3D
var game: Node
var level: Dictionary
var index: int
var props: Array[CrashProp] = []
var traffic: Array[TrafficCar] = []
var mats: Dictionary = {}
var decor_rng := RandomNumberGenerator.new()

func build(parent: Node3D, level_index: int, owner_game: Node) -> void:
	root = parent
	game = owner_game
	index = level_index
	level = WreckRules.LEVELS[index]
	decor_rng.seed = 7411 + index * 100
	mats = {
		"concrete": mat(Color("d0cebe") if index == 0 else Color("4b5964")),
		"riser": mat(Color("a6b2ac") if index == 0 else Color("313d48")),
		"ink": mat(Color("182b37")), "steel": mat(Color("6d8991"), .5),
		"accent": mat(level.color), "white": mat(Color("e8f2e9")),
		"orange": mat(Color("fd6843")), "window": mat(Color("8eeace"), .0, .7),
		"pink": mat(Color("ff70b7"), .0, .7), "yellow": mat(Color("ffd26c"), .0, .5),
		"asphalt": mat(Color("263e46")), "water": mat(Color("216374"), .5),
		"wood": mat(Color("8e6344"))
	}
	setup_lighting()
	var h: float = level.steps * level.rise
	var length: float = level.steps * level.run
	var width: float = level.width
	static_box("World foundation",Vector3(0,-1.5,10),Vector3(140,2.5,170),"asphalt")
	static_box("Launch deck",Vector3(0,(h-.5)*.5,-14.0),Vector3(width,h+.5,28),"concrete")
	# Each tread is a genuine box collider; the ragdoll tumbles down real risers.
	for i in level.steps:
		var y: float = h - (i + 1) * level.rise
		var z: float = (i + .5) * level.run
		static_box("Tread_%02d" % i,Vector3(0,(y-.5)*.5,z),Vector3(width,y+.5,level.run),"concrete")
		box(Vector3(0,y-.06,z-level.run*.5+.035),Vector3(width,.11,.055),"riser")
		# Painted stair noses and central lane marks give speed and scale cues.
		for x in [-width*.5+.12,width*.5-.12]:
			box(Vector3(x,y+.013,z),Vector3(.10,.02,level.run-.02),"accent")
		if i % 3 == 0:
			box(Vector3(0,y+.015,z),Vector3(.15,.024,.45),"white")
	for side in [-1,1]:
		var x: float = side*(width*.5+.35)
		for i in level.steps:
			var edge_y: float=h-(i+1)*level.rise
			static_box("Terrace edge",Vector3(x,edge_y-.65,(i+.5)*level.run),Vector3(.55,1.3,level.run),"ink")
		static_box("Launch edge",Vector3(x,h-.65,-14),Vector3(.55,1.3,28),"ink")
		for j in range(-4, level.steps+1,3):
			var z: float = j*level.run
			var sy: float = WreckRules.surface_y(level,z)
			box(Vector3(x,sy+.7,z),Vector3(.09,1.4,.09),"steel")
		beam(Vector3(x,h+1.4,0),Vector3(x,1.4,length),.075,"steel")
		beam(Vector3(x,h+.85,0),Vector3(x,.85,length),.04,"accent")
	static_box("Crash plaza",Vector3(0,-.25,length+9),Vector3(34,.5,18),"concrete")
	# Flat cross-road continues through genuine curb openings; no invisible wrap.
	static_box("Traffic cross road",Vector3(0,-.25,length+6.5),Vector3(76,.5,10),"asphalt")
	static_box("Containment at end",Vector3(0,4.0,length+18),Vector3(36,8.0,.8),"ink")
	label_3d("END OF THE LINE",Vector3(0,5.5,length+17.58),.75,level.color,Vector3(0,PI,0))
	label_3d("THANK YOU FOR YOUR COLLATERAL",Vector3(0,4.3,length+17.57),.26,Color("eff5ec"),Vector3(0,PI,0))
	for x in [-15.5,15.5]:
		static_box("Plaza upper curb",Vector3(x,.45,length+.65),Vector3(.5,.9,1.3),"ink")
		static_box("Plaza lower curb",Vector3(x,.45,length+15),Vector3(.5,.9,6),"ink")
	for x in range(-30,31,4):
		box(Vector3(x,.015,length+5.35),Vector3(1.6,.025,.08),"yellow")
	for lane_z in [3.7,7.0]:
		label_3d("TRAFFIC  >>>",Vector3(9,.035,length+lane_z),.18,level.color,Vector3(-PI/2,0,0))
	# Start-line runway, arrow inlays, and readable track branding.
	for z in [-14,-10,-6,-2]:
		for x in [-2.5,0,2.5]:
			var a: MeshInstance3D = box(Vector3(x-.15,h+.02,z),Vector3(.10,.025,.7),"accent")
			a.rotation.y = -.5
			var b: MeshInstance3D = box(Vector3(x+.15,h+.02,z),Vector3(.10,.025,.7),"accent")
			b.rotation.y = .5
	box(Vector3(0,h+.025,-.9),Vector3(width,.035,.20),"orange")
	for x in [-width*.5-1,width*.5+1]:
		box(Vector3(x,h+2,-26),Vector3(.25,4,.25),"ink")
	box(Vector3(0,h+4,-26),Vector3(width+2,.65,.3),"ink")
	label_3d("STAIR // WRECK",Vector3(0,h+4,-25.81),.34,Color("84efbc"))
	label_3d("COMMIT TO THE CASCADE",Vector3(0,h+.08,-7),.19,Color("182b37"),Vector3(-PI/2,0,0))
	populate_props()
	populate_traffic()
	if index == 0: civic_scenery(h,length)
	elif index == 1: market_scenery(h,length)
	else: port_scenery(h,length)
	for j in range(4):
		var z: float = 3.0 + j*(length/4.0)
		var sy: float = WreckRules.surface_y(level,z)
		for side in [-1,1]:
			var x: float = side*(width*.5+1.6)
			box(Vector3(x,sy+2,z),Vector3(.11,4,.11),"steel")
			box(Vector3(x,sy+4,z),Vector3(.7,.13,.35),"white")
			if index == 1:
				var light := OmniLight3D.new()
				root.add_child(light); light.position = Vector3(x,sy+3.4,z)
				light.light_color = level.color; light.light_energy = 1.0; light.omni_range = 9.0

	batch_static_decor()

func setup_lighting() -> void:
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("adc7c3") if index == 0 else (Color("152335") if index == 1 else Color("8daeb6"))
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("afccd0")
	env.ambient_light_energy = .55 if index == 1 else .7
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = env.background_color
	env.fog_density = .0035
	environment.environment = env; root.add_child(environment)
	var sun := DirectionalLight3D.new()
	root.add_child(sun)
	sun.rotation_degrees = Vector3(-48,-32,0)
	sun.light_color = Color("fff0ce") if index != 1 else Color("9ec6ed")
	sun.light_energy = 1.6 if index == 0 else 1.25
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 110

func populate_props() -> void:
	# Each lane has its own entry, transfer and finale. Gaps reward an aimed second act.
	if index == 0:
		for step in range(4,13): spawn("domino",-3.3,step*level.run+.5)
		for step in [8,12,16]: spawn("cart",0,step*level.run+.5)
		spawn("taxi",3.3,7*level.run+.7)
		# A finite-mass taxi transfers to nearby light props instead of requiring
		# the old mass-scaled launch to cross a seven-metre empty gap.
		for step in range(9,14): spawn("domino",3.3,step*level.run+.5)
		for step in [14,20]:
			for side in [-1,1]:
				for layer in range(3):
					for offset in [-.52,.52]: spawn("crate",side*3.25+offset,step*level.run+.5,layer*1.05)
		for step in [17,23]:
			for x in [-3.25,0,3.25]: spawn("barrel",x,step*level.run+.5)
	elif index == 1:
		for step in [4,8,12,17,22]: spawn("cart",-3.3,step*level.run+.55)
		for step in range(5,16): spawn("domino",3.3,step*level.run+.5)
		for step in [9,16,24]:
			for layer in range(3):
				for x in [-.55,.55]: spawn("crate",x,step*level.run+.4,layer*1.05)
		for step in [19,27]:
			for x in [-3.7,-1.2,1.2,3.7]: spawn("barrel",x,step*level.run+.5)
		# Delivery bay is beside the turn, not inside its swept hull.
		for x in [6.0,7.7,9.4]: spawn("cart",x,level.steps*level.run+.7)
	else:
		for step in [5,13,23,32]:
			for layer in range(3):
				for offset in [-.55,.55]: spawn("crate",-3.25+offset,step*level.run+.5,layer*1.05)
		for step in range(4,11): spawn("domino",0,step*level.run+.5)
		spawn("taxi",3.4,8*level.run+.9)
		for step in [16,25,34]:
			for x in [0,3.4]:
				for layer in range(3): spawn("crate",x,step*level.run+.5,layer*1.05)
		for step in [14,21,29,36]:
			for x in [-3.3,0,3.3]: spawn("barrel",x,step*level.run+.5)
		for x in [-5.2,-2.6,0,2.6,5.2]: spawn("barrel",x,level.steps*level.run+2)
	# Leave the outside approach strips clear, including the launch apron.
	for x in [-2.0,2.0]: spawn("cone",x,-1.4)
	for x in [-5.6,5.6]: spawn("barrier",x,level.steps*level.run+11)
	# Physical lane signs preview the choice before any button press.
	var routes: Array = [["DOMINO RUN","BODY + CARTS","PREMIUM TAXI"],["CART SLALOM","CARGO DROP","FUSE RUN"],["TOWER FALL","DRUM AVALANCHE","HEAVY HITTER"]][index]
	var h: float=level.steps*level.rise
	for lane in 3:
		var x: float=(lane-1)*3.3
		label_3d(routes[lane],Vector3(x,h+.10,-3.4),.12,level.color,Vector3(-PI/2,0,0))
		box(Vector3(x,h+.026,-2.6),Vector3(2.2,.035,.08),"accent")
	label_3d("SKATE TO TRAFFIC",Vector3(-level.width*.5+.82,h+.10,-4.8),.11,level.color,Vector3(-PI/2,0,0))

func spawn(kind: String, x: float, z: float, stack: float = 0) -> CrashProp:
	var prop := CrashProp.new()
	prop.game = game; prop.kind = kind
	prop.name = "%s_%03d" % [kind,props.size()]
	prop.stable_id = prop.name.to_upper()
	prop.set_meta("slot",props.size())
	prop.freeze = true
	var size: Vector3
	var y: float = .5
	match kind:
		"domino": size=Vector3(.92,2.12,.26); y=1.06; prop.mass=4.0; prop.value=600; prop.threshold=1.1
		"barrel": size=Vector3(.8,1.04,.8); y=.52; prop.mass=8.0; prop.value=1800; prop.explosive=true; prop.threshold=2.2
		"crate": size=Vector3(1.04,1.04,1.04); y=.52; prop.mass=5.0; prop.value=1100; prop.threshold=1.9
		"cart": size=Vector3(1.35,1.0,1.10); y=.46; prop.mass=7.0; prop.value=1400; prop.threshold=1.7
		"taxi": size=Vector3(1.85,1.45,3.3); y=.76; prop.mass=180.0; prop.value=9000; prop.threshold=2.0
		"cone": size=Vector3(.6,.85,.6); y=.43; prop.mass=1.4; prop.value=250; prop.threshold=1.1
		_: size=Vector3(1.66,1.0,.65); y=.55; prop.mass=4.0; prop.value=550; prop.threshold=1.5
	prop.nominal_radius = maxf(size.x,size.z)*.5
	var collider := CollisionShape3D.new()
	if kind == "barrel":
		var shape := CylinderShape3D.new(); shape.radius=.4; shape.height=1.04; collider.shape=shape
	else:
		var shape := BoxShape3D.new(); shape.size=size; collider.shape=shape
	prop.add_child(collider)
	var model: Node3D = PROP_SCENES[kind].instantiate()
	prop.add_child(model); prop.visual=model
	prop.position=Vector3(x,WreckRules.surface_y(level,z)+y+stack+.03,z)
	root.add_child(prop)
	prop.wrecked.connect(game.prop_wrecked)
	props.append(prop)
	return prop

func populate_traffic() -> void:
	var length: float = level.steps * level.run
	# Finite launch-relative fleet. Waiting in READY never advances these encounters.
	# Civic: passing lanes and a staggered rank. Market: an authored turning lane.
	# Port: a diagonal approach and narrow terminal gate. All retain physical momentum.
	var specs: Array = [
		[{"x":-19.0,"z":3.7,"speed":5.5,"dir":1},{"x":-20.0,"z":7.0,"speed":6.0,"dir":1},{"x":4.0,"z":9.0,"speed":0.0,"dir":1}],
		[{"x":-18.0,"z":3.7,"speed":4.2,"dir":1},{"x":-27.0,"z":7.0,"speed":7.0,"dir":1},{"x":1.5,"z":10.0,"speed":0.0,"dir":1,"yaw":.35}],
		[{"x":-25.0,"z":2.5,"speed":5.8,"dir":1},{"x":-27.0,"z":7.0,"speed":6.5,"dir":1},{"x":3.0,"z":10.0,"speed":0.0,"dir":1,"yaw":PI*.25}]
	][index]
	for spec in specs:
		var car := TrafficCar.new()
		car.game=game; car.kind="taxi"; car.value=9000; car.mass=180.0; car.nominal_radius=1.65
		car.name="traffic_%d_%d" % [index,traffic.size()]
		car.stable_id=car.name; car.set_meta("traffic",true); car.set_meta("slot",props.size())
		car.paint_color=[Color("ffc54e"),Color("84efbc"),Color("eff4d4")][traffic.size()]
		car.route_direction=Vector3.RIGHT*float(spec.dir)
		car.cruise_speed=float(spec.speed); car.queued=car.cruise_speed==0.0
		car.position=Vector3(float(spec.x),.755,length+float(spec.z))
		car.rotation.y=PI*.5*float(spec.dir); car.freeze=true
		if spec.has("yaw"):
			car.rotation.y=float(spec.yaw)
			car.route_direction=Vector3(sin(car.rotation.y),0,cos(car.rotation.y))
		if traffic.is_empty() and index==1:
			car.route_points.assign([Vector3(-6,.755,length+3.7),Vector3(1,.755,length+2.5),Vector3(34,.755,length+2.5)])
		elif traffic.is_empty() and index==2:
			car.route_points.assign([Vector3(-8,.755,length+3.7),Vector3(34,.755,length+3.7)])
		var collider:=CollisionShape3D.new(); var shape:=BoxShape3D.new(); shape.size=Vector3(1.85,1.45,3.3); collider.shape=shape
		car.add_child(collider)
		car.visual=PROP_SCENES.taxi.instantiate(); car.add_child(car.visual)
		root.add_child(car); car.wrecked.connect(game.prop_wrecked)
		traffic.append(car); props.append(car)
	if index==1:
		label_3d("TURNING TAXIS",Vector3(-2,.035,length+1.7),.18,level.color,Vector3(-PI/2,0,0))
	elif index==2:
		for z in [length+2.0,length+5.4]:
			static_box("Terminal traffic gate",Vector3(8,1.0,z),Vector3(.35,2.0,.35),"yellow")
		label_3d("TERMINAL MERGE",Vector3(-9,.035,length+1.5),.18,level.color,Vector3(-PI/2,0,0))

func start_traffic() -> void:
	for car in traffic: car.start_driver(traffic)

func traffic_has_motion() -> bool:
	for car in traffic:
		if car.has_causal_motion(): return true
	return false

func traffic_pending_contact(horizon: float = 1.5) -> bool:
	for car in traffic:
		if car.imminent_contact(horizon): return true
	return false

func civic_scenery(h: float, length: float) -> void:
	for side in [-1,1]:
		for i in range(5):
			var x: float = side*(24.0+decor_rng.randf_range(0,5))
			var z: float = -10+i*12.0
			building(Vector3(x,0,z),Vector3(9,decor_rng.randf_range(10,23),8),i%2)
		for i in range(7):
			var z: float = -10+i*8.0
			var sy: float = maxf(0,WreckRules.surface_y(level,z))
			tree(Vector3(side*8.1,sy,z))
	label_3d("CASCADE / CITY",Vector3(-10,h+2,5),.75,Color("182b37"),Vector3(0,PI/2,0))
	for i in range(7):
		box(Vector3(-12+i*4.0,.02,length+12),Vector3(2.6,.03,.2),"white")

func market_scenery(h: float, length: float) -> void:
	for side in [-1,1]:
		for i in range(7):
			var z: float = -9+i*8.0
			var sy: float = maxf(0,WreckRules.surface_y(level,z))
			var x: float = side*9
			box(Vector3(x,sy+1.0,z),Vector3(3,2.0,3.8),"ink")
			box(Vector3(x,sy+2.7,z),Vector3(3.7,.20,4.4),"pink" if i%2==0 else "accent")
			for dx in [-1.4,1.4]: box(Vector3(x+dx,sy+1.75,z+1.6),Vector3(.1,3.5,.1),"steel")
			label_3d(["NOODLES","99¢","NIGHT OWL","FRESH","OPEN LATE","HOT!","MARKET"][i],Vector3(x,sy+2.25,z+1.94),.31,level.color)
			building(Vector3(side*24,0,z),Vector3(8,decor_rng.randf_range(15,28),7),1)
	for i in range(7):
		var z: float = -4+i*7.0
		var sy: float = WreckRules.surface_y(level,z)
		beam(Vector3(-9,sy+6,z),Vector3(9,sy+6,z),.03,"steel")
		for x in [-7,-4,-1,2,5,8]:
			var globe := MeshInstance3D.new(); var sphere := SphereMesh.new(); sphere.radius=.23; sphere.height=.60
			globe.mesh=sphere; globe.material_override=mats.yellow; root.add_child(globe); globe.position=Vector3(x,sy+5.75,z)

func port_scenery(h: float, length: float) -> void:
	box(Vector3(38,-.10,length*.5),Vector3(40,.12,110),"water")
	for side in [-1,1]:
		for i in range(6):
			var x: float = side*12.0
			var z: float = -8+i*11
			var sy: float = maxf(0,WreckRules.surface_y(level,z))
			for layer in range(2):
				box(Vector3(x,sy+1.5+layer*3.1,z),Vector3(5,3,8),"orange" if i%2==0 else "ink")
				for rib in range(11): box(Vector3(x-side*2.53,sy+1.5+layer*3.1,z-3.8+rib*.76),Vector3(.07,2.8,.08),"steel")
			label_3d("TERMINAL 09",Vector3(x,sy+1.8,z+4.03),.35,level.color)
	for z in [-18.0,length+18.0]:
		for x in [-18,20]: box(Vector3(x,18,z),Vector3(.8,36,.8),"yellow")
		box(Vector3(1,35,z),Vector3(40,.9,.9),"yellow")
		beam(Vector3(12,35,z),Vector3(12,12,z),.055,"steel")
		box(Vector3(12,11.7,z),Vector3(2.5,.5,2.5),"ink")

func building(at: Vector3, size: Vector3, style: int) -> void:
	var m := StandardMaterial3D.new(); m.albedo_color=Color("859a95") if style==0 else Color("263d4a"); m.roughness=.95
	var mesh := MeshInstance3D.new(); var shape := BoxMesh.new(); shape.size=size; mesh.mesh=shape; mesh.material_override=m; root.add_child(mesh); mesh.position=at+Vector3(0,size.y*.5,0)
	box(at+Vector3(0,size.y+.22,0),Vector3(size.x+.3,.45,size.z+.3),"ink")
	for y in range(2,int(size.y)-1,3):
		for x in [-2.7,0,2.7]:
			box(at+Vector3(x,y,size.z*.5+.03),Vector3(1.3,1.3,.06),"window" if decor_rng.randf()>.25 else "ink")
		for z in [-2.5,0,2.5]:
			box(at+Vector3(-signf(at.x)*size.x*.5,y,z),Vector3(.05,1.3,1.2),"window")

func tree(at: Vector3) -> void:
	box(at+Vector3(0,.18,0),Vector3(1.8,.35,1.8),"ink")
	box(at+Vector3(0,1.5,0),Vector3(.25,3,.25),"wood")
	var mesh := MeshInstance3D.new(); var sphere := SphereMesh.new(); sphere.radius=1.35; sphere.height=2.7; sphere.radial_segments=12; sphere.rings=6
	mesh.mesh=sphere; mesh.material_override=mats.accent; root.add_child(mesh); mesh.position=at+Vector3(0,3.1,0)

func mat(color: Color, metallic: float = 0, emission: float = 0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new(); m.albedo_color=color; m.roughness=.75; m.metallic=metallic
	if emission>0: m.emission_enabled=true; m.emission=color; m.emission_energy_multiplier=emission
	return m

func box(at: Vector3, size: Vector3, material_key: String) -> MeshInstance3D:
	var mesh := MeshInstance3D.new(); var cube := BoxMesh.new(); cube.size=size; mesh.mesh=cube; mesh.material_override=mats[material_key]; root.add_child(mesh); mesh.position=at
	mesh.set_meta("decor_material",material_key)
	return mesh

func static_box(body_name: String, at: Vector3, size: Vector3, material_key: String) -> void:
	var body := StaticBody3D.new(); body.name=body_name; body.collision_layer=1; body.collision_mask=7; root.add_child(body); body.position=at
	var col := CollisionShape3D.new(); var shape := BoxShape3D.new(); shape.size=size; col.shape=shape; body.add_child(col)
	var mesh := MeshInstance3D.new(); var cube := BoxMesh.new(); cube.size=size; mesh.mesh=cube; mesh.material_override=mats[material_key]; body.add_child(mesh)

func beam(a: Vector3, b: Vector3, radius: float, material_key: String) -> void:
	var mesh := MeshInstance3D.new(); var cylinder := CylinderMesh.new(); cylinder.top_radius=radius; cylinder.bottom_radius=radius; cylinder.height=a.distance_to(b); cylinder.radial_segments=8
	mesh.mesh=cylinder; mesh.material_override=mats[material_key]; root.add_child(mesh); mesh.position=(a+b)*.5
	var direction: Vector3 = (b-a).normalized()
	mesh.quaternion=Quaternion(Vector3.UP,direction)

func label_3d(text: String, at: Vector3, size: float, color: Color, rot: Vector3 = Vector3.ZERO) -> void:
	var label := Label3D.new(); label.text=text; label.font_size=64; label.pixel_size=size/45.0; label.modulate=color; label.outline_size=0; label.no_depth_test=false; root.add_child(label); label.position=at; label.rotation=rot

func batch_static_decor() -> void:
	# Painted inlays, skyline windows, stalls, and containers share eight draw batches.
	# Physics bodies and detailed Blender assets retain their independent nodes.
	var batches: Dictionary={}
	for node in root.get_children():
		if node is MeshInstance3D and node.has_meta("decor_material"):
			var key: String=node.get_meta("decor_material")
			if not batches.has(key):batches[key]=[]
			var transform:Transform3D=node.transform
			transform.basis=transform.basis*Basis.from_scale(node.mesh.size)
			batches[key].append(transform)
			root.remove_child(node);node.queue_free()
	for key in batches:
		var renderer:=MultiMeshInstance3D.new()
		var multimesh:=MultiMesh.new();multimesh.transform_format=MultiMesh.TRANSFORM_3D
		var unit:=BoxMesh.new();unit.size=Vector3.ONE;multimesh.mesh=unit
		multimesh.instance_count=batches[key].size()
		for i in batches[key].size():multimesh.set_instance_transform(i,batches[key][i])
		renderer.multimesh=multimesh;renderer.material_override=mats[key]
		renderer.name="Decor_"+key;renderer.set_meta("validation_transforms",batches[key]);root.add_child(renderer)
