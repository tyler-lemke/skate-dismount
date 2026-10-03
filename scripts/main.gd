extends Node3D

const Rules = preload("res://scripts/game_rules.gd")
const World = preload("res://scripts/world_builder.gd")
const Rider = preload("res://scripts/rider.gd")
const HUD = preload("res://scripts/game_hud.gd")
const Sound = preload("res://scripts/sound_director.gd")
enum Phase { MENU, READY, RUN, CRASH, RESULTS, REPLAY }
var phase: Phase = Phase.MENU
var level_index: int = 0
var level_root: Node3D
var world: WreckWorld
var skater: Skater
var hud: WreckHUD
var sound: Node
var camera: Camera3D
var rules := WreckRules.new()
var run_speed: float = 0.0
var lateral_speed: float = 0.0
var charge: float = 0.0
var charging: bool = false
var boosts: int = 3
var run_clock: float = 0.0
var crash_clock: float = 0.0
var idle_clock: float = 0.0
var camera_style: int = 0
var camera_shake: float = 0.0
var camera_target: Vector3 = Vector3.ZERO
var is_paused: bool = false
var paused_for_help: bool = false
var slow_motion: bool = false
var best_scores: Array[int] = [0,0,0]
var muted: bool = false
var save_path: String = "user://records.json"
var particles: Array[Dictionary] = []
var replay_frames: Array[Dictionary] = []
var replay_actors: Array[Node3D] = []
var self_check: bool = false
var record_clock: float = 0.0
var replay_clock: float = 0.0
var result_was_best: bool = false
var rng := RandomNumberGenerator.new()
var test_mode: bool = false
var automate: bool = false
var capture_mode: bool = false
var capture_dir: String = "res://docs/screenshots"
var capture_flags: Dictionary = {}
var pending_level: int = 0
var run_serial: int = 0

func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	rng.seed=90210
	for arg in OS.get_cmdline_user_args():
		if arg=="--test-mode": test_mode=true; save_path="res://builds/test_records.json"
		if arg=="--demo": automate=true
		if arg=="--self-check": automate=true;self_check=true
		if arg=="--capture": capture_mode=true; automate=true
		if arg.begins_with("--level="): pending_level=clampi(int(arg.split("=")[1]),0,2)
	if capture_mode: save_path="res://builds/capture_records.json"
	if self_check: save_path=OS.get_executable_path().get_base_dir()+"/self_check_records.json"
	load_records()
	camera=Camera3D.new(); camera.fov=58; camera.near=.15; camera.far=250; add_child(camera); camera.current=true
	hud=HUD.new(); hud.process_mode=Node.PROCESS_MODE_ALWAYS; add_child(hud)
	hud.play_requested.connect(start_ready)
	hud.route_requested.connect(select_route)
	hud.retry_requested.connect(retry)
	hud.next_requested.connect(next_route)
	hud.menu_requested.connect(back_to_menu)
	hud.resume_requested.connect(toggle_pause)
	hud.replay_requested.connect(start_replay)
	hud.mute_requested.connect(toggle_mute)
	hud.quit_requested.connect(func(): get_tree().quit())
	hud.help_closed.connect(func():
		if paused_for_help: paused_for_help=false; unpause()
	)
	sound=Sound.new(); add_child(sound); sound.set_muted(muted)
	select_route(pending_level)
	if automate: start_ready()

func load_records() -> void:
	if not FileAccess.file_exists(save_path): return
	var data: Variant=JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if not data is Dictionary: return
	var scores: Variant=data.get("best_scores",[])
	if scores is Array and scores.size()==3:
		for i in 3: best_scores[i]=clampi(int(scores[i]),0,999999999)
	muted=bool(data.get("muted",false))

func save_records() -> void:
	var file:=FileAccess.open(save_path,FileAccess.WRITE)
	if file: file.store_string(JSON.stringify({"version":1,"best_scores":best_scores,"muted":muted}))

func select_route(index: int) -> void:
	unpause()
	level_index=clampi(index,0,2)
	rules.reset(); replay_frames.clear(); replay_actors.clear(); particles.clear()
	if is_instance_valid(level_root):
		remove_child(level_root); level_root.queue_free()
	level_root=Node3D.new(); level_root.name="Route"; level_root.process_mode=Node.PROCESS_MODE_PAUSABLE; add_child(level_root)
	world=World.new(); world.build(level_root,level_index,self)
	skater=Rider.new(); skater.game=self; level_root.add_child(skater)
	var l:Dictionary=Rules.LEVELS[level_index]
	skater.position=Vector3(0,l.steps*l.rise+.23,-13)
	phase=Phase.MENU; charge=0; charging=false; run_speed=0; boosts=3; run_clock=0; crash_clock=0; camera_shake=0
	camera_target=Vector3(-5,l.steps*l.rise*.45,l.steps*l.run*.40)
	camera.position=overview_position()
	camera.look_at(camera_target)
	hud.set_route(level_index,best_scores[level_index]); hud.show_menu()

func start_ready() -> void:
	if phase!=Phase.MENU: return
	phase=Phase.READY; hud.show_game(); charge=0; charging=false
	hud.toast(Rules.LEVELS[level_index].name)

func retry() -> void:
	select_route(level_index); start_ready()

func next_route() -> void:
	select_route((level_index+1)%3); start_ready()

func back_to_menu() -> void:
	select_route(level_index)

func unpause() -> void:
	get_tree().paused=false; is_paused=false; paused_for_help=false; Engine.time_scale=1.0; slow_motion=false
	if is_instance_valid(hud): hud.pause_panel.visible=false

func toggle_pause() -> void:
	if phase==Phase.MENU: return
	if phase==Phase.RESULTS: back_to_menu(); return
	is_paused=not is_paused; get_tree().paused=is_paused; hud.pause_panel.visible=is_paused
	slow_motion=false;Engine.time_scale=1.0

func toggle_mute() -> void:
	muted=not muted; sound.set_muted(muted); save_records()
	if hud.hud.visible: hud.toast("SOUND OFF" if muted else "SOUND ON")
	else: hud.best_label.text="SOUND OFF" if muted else "SOUND ON"

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or event.echo: return
	var key: int=event.physical_keycode
	if key==KEY_ESCAPE and event.pressed:
		if hud.help_panel.visible: hud.close_help()
		else: toggle_pause()
		return
	if key==KEY_M and event.pressed: toggle_mute(); return
	if is_paused or hud.help_panel.visible: return
	if event.pressed:
		if key==KEY_R and phase!=Phase.MENU: retry(); return
		if key==KEY_C: camera_style=(camera_style+1)%3; return
		if key==KEY_H:
			if phase in [Phase.READY,Phase.RUN,Phase.CRASH,Phase.REPLAY]:
				paused_for_help=true;toggle_pause();hud.pause_panel.visible=false
			hud.help_panel.visible=true;return
		if key==KEY_V and phase==Phase.RESULTS: start_replay(); return
		if key==KEY_ENTER and phase==Phase.MENU: start_ready(); return
		if key==KEY_ENTER and phase==Phase.RESULTS: retry(); return
		if key==KEY_SHIFT and phase==Phase.CRASH: crashbreaker(); return
	if key==KEY_SPACE:
		if phase==Phase.READY:
			if event.pressed: charging=true
			elif charging: launch()
		elif phase==Phase.RUN and event.pressed: bail_out()
	if key==KEY_TAB and phase in [Phase.RUN,Phase.CRASH]:
		slow_motion=event.pressed; Engine.time_scale=.32 if slow_motion else 1.0

func steering() -> float:
	return float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT))-float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT))

func launch() -> void:
	if phase!=Phase.READY: return
	phase=Phase.RUN; charging=false; run_speed=6.5+charge*12.0; run_clock=0; lateral_speed=0; run_serial+=1
	for prop in world.props:
		prop.freeze=false; prop.grace=.65; prop.origin=prop.global_position
	hud.toast("COMMIT TO THE CASCADE",WreckHUD.ORANGE); sound.play("launch")

func is_live() -> bool:
	return phase==Phase.RUN or phase==Phase.CRASH

func _physics_process(delta: float) -> void:
	if is_paused or not is_instance_valid(skater): return
	if phase==Phase.READY:
		if charging: charge=minf(1.0,charge+delta*.65)
		skater.position.x=clampf(skater.position.x+steering()*delta*3.5,-4.5,4.5)
		skater.pose_ride(run_clock,steering())
		if automate:
			charge=minf(1,charge+delta*.9)
			if charge>=1: launch()
	elif phase==Phase.RUN:
		run_clock+=delta
		rules.tick(delta)
		var pushing: bool=Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP) or automate
		run_speed=minf(31.0,run_speed+delta*(5.2 if pushing else 1.5)+(delta*5.0 if skater.position.z>0 else 0.0))
		lateral_speed=move_toward(lateral_speed,steering()*6.8,delta*14)
		skater.position.x=clampf(skater.position.x+lateral_speed*delta,-Rules.LEVELS[level_index].width*.5+.8,Rules.LEVELS[level_index].width*.5-.8)
		skater.position.z+=run_speed*delta
		var desired_y: float=Rules.surface_y(Rules.LEVELS[level_index],skater.position.z)+.23
		skater.position.y=move_toward(skater.position.y,desired_y,delta*9)
		skater.pose_ride(run_clock,steering())
		rules.peak_speed=maxf(rules.peak_speed,run_speed)
		for prop in world.props:
			if not is_instance_valid(prop) or prop.broken: continue
			var d: Vector3=prop.global_position-skater.global_position
			if absf(d.x)<prop.nominal_radius+.30 and absf(d.z)<prop.nominal_radius+.3 and d.y>-.4 and d.y<2.6:
				prop.activate(Vector3(lateral_speed*.7,2.0,run_speed)*prop.mass*1.3)
				bail_out(); break
		if phase==Phase.RUN and skater.position.z>Rules.LEVELS[level_index].steps*Rules.LEVELS[level_index].run+5: bail_out()
	elif phase==Phase.CRASH:
		crash_clock+=delta; rules.tick(delta)
		skater.aftertouch(Vector3(steering(),0,0),false,delta)
		rules.peak_speed=maxf(rules.peak_speed,skater.speed())
		var movement: float=skater.speed()
		for prop in world.props:
			if is_instance_valid(prop) and prop.armed: movement=maxf(movement,prop.linear_velocity.length())
		idle_clock=idle_clock+delta if movement<1.0 else 0.0
		if automate and crash_clock>2.2 and boosts>0 and crash_clock>2.2+(3-boosts)*2.8: crashbreaker()
		if (crash_clock>7 and idle_clock>2.0) or crash_clock>=19.0 or skater.focus_position().y < -8.0: finish_run()
	if is_live():
		record_clock+=delta
		if record_clock>=.05: record_clock=0; record_frame()

func bail_out() -> void:
	if phase!=Phase.RUN: return
	phase=Phase.CRASH; crash_clock=0; idle_clock=0
	skater.bail(Vector3(lateral_speed,-1.4,run_speed),2.3)
	replay_actors.clear()
	for prop in world.props: replay_actors.append(prop)
	for body in skater.limbs: replay_actors.append(body)
	replay_frames.clear()
	hud.toast("BAIL!   SHIFT = CRASHBREAKER",WreckHUD.ORANGE)
	sound.play("impact"); camera_shake=.25

func crashbreaker() -> void:
	if phase!=Phase.CRASH or boosts<=0: return
	boosts-=1; skater.aftertouch(Vector3.ZERO,true,0)
	var position: Vector3=skater.focus_position()
	burst(position,Color("84efbc"),25,7.0)
	hud.toast("CRASHBREAKER!",WreckHUD.MINT); sound.play("boost"); camera_shake=.35
	# The shockwave can move nearby objects; damage still requires actual motion or contact.
	for prop in world.props:
		if not is_instance_valid(prop): continue
		var offset: Vector3=prop.global_position-position
		var distance: float=offset.length()
		if distance<4.8:
			var direction: Vector3=(offset+Vector3(0,1.5,3)).normalized()
			prop.activate(direction*prop.mass*(9.0-distance))

func prop_wrecked(prop: CrashProp, explosive: bool) -> void:
	if not is_live(): return
	var points: int=rules.hit_prop(prop.get_instance_id(),prop.value,explosive)
	if points==0: return
	if explosive:
		burst(prop.global_position,Color("ff9548"),35,11.0)
		burst(prop.global_position,Color("ffd278"),14,6.0)
		sound.play("blast"); hud.flash(); camera_shake=minf(.8,camera_shake+.28)
		var at: Vector3=prop.global_position
		for other in world.props:
			if not is_instance_valid(other) or other==prop: continue
			var offset: Vector3=other.global_position-at
			var distance: float=offset.length()
			if distance<5.2:
				other.activate((offset+Vector3(0,.6,1.8)).normalized()*other.mass*(12.0-distance*1.8))
		for body in skater.limbs:
			if is_instance_valid(body) and body.global_position.distance_to(at)<5.2:
				body.apply_central_impulse((body.global_position-at+Vector3(0,.3,1.5)).normalized()*body.mass*3.5*(1.0-body.global_position.distance_to(at)/5.2))
	else:
		burst(prop.global_position,Rules.LEVELS[level_index].color,7,4.0)
		sound.play("clack")
	if rules.combo % 5==0 or explosive:
		hud.toast(("DRUM DETONATION" if explosive else "%d OBJECT CASCADE" % rules.combo)+"   ×%d" % rules.multiplier(),WreckHUD.ORANGE if explosive else WreckHUD.MINT)

func rider_hit(limb: String, force: float, at: Vector3) -> void:
	if phase!=Phase.CRASH: return
	var id: String="%d:%s:%d" % [run_serial,limb,int(crash_clock*4)]
	var points: int=rules.hit_rider(id,force)
	if points>150:
		burst(at,Color("f4e1b2"),4,3.0)
		camera_shake=minf(.6,camera_shake+force*.004)
		if force>7: sound.play("impact")

func finish_run() -> void:
	if phase!=Phase.CRASH: return
	phase=Phase.RESULTS; Engine.time_scale=1.0; slow_motion=false
	result_was_best=rules.score>best_scores[level_index]
	if result_was_best:
		best_scores[level_index]=rules.score
		if not self_check: save_records()
	freeze_actors()
	hud.show_results(rules,level_index,result_was_best); sound.play("finish")
	if self_check:
		print("SELF_CHECK: level=",level_index+1," score=",rules.score," wrecks=",rules.destroyed," explosions=",rules.explosions," frames=",replay_frames.size())
		get_tree().quit(0 if rules.destroyed>=4 and rules.score>3000 else 1)

func freeze_actors() -> void:
	for prop in world.props:
		if is_instance_valid(prop): prop.freeze=true
	for body in skater.limbs:
		if is_instance_valid(body): body.freeze=true

func record_frame() -> void:
	if phase!=Phase.CRASH: return
	var transforms: Array[Transform3D] = []
	var damage_states: Array[bool] = []
	for prop in world.props: damage_states.append(prop.broken if is_instance_valid(prop) else true)
	for actor in replay_actors:
		transforms.append(actor.global_transform if is_instance_valid(actor) else Transform3D.IDENTITY)
	replay_frames.append({"transforms":transforms,"camera":camera.global_transform,"score":rules.score,"speed":skater.speed(),"damage":damage_states})

func start_replay() -> void:
	if phase!=Phase.RESULTS or replay_frames.size()<2: return
	phase=Phase.REPLAY; replay_clock=0; hud.results.visible=false; hud.replay_banner.visible=true
	hud.power_panel.visible=false; freeze_actors()
	hud.toast("CINEMATIC REPLAY")

func _process(delta: float) -> void:
	if is_paused or not is_instance_valid(skater): return
	if phase==Phase.REPLAY:
		replay_clock+=delta*.72
		var cursor: float=replay_clock/.05
		var i: int=int(cursor)
		if i>=replay_frames.size()-1:
			phase=Phase.RESULTS; hud.replay_banner.visible=false; hud.show_results(rules,level_index,result_was_best)
			for prop in world.props:
				if is_instance_valid(prop): prop.set_damaged_visual(prop.broken)
		else:
			var a:Dictionary=replay_frames[i]; var b:Dictionary=replay_frames[i+1]; var t:float=cursor-i
			for j in replay_actors.size():
				if is_instance_valid(replay_actors[j]):
					replay_actors[j].global_transform=a.transforms[j].interpolate_with(b.transforms[j],t)
					if replay_actors[j] is CrashProp: replay_actors[j].set_damaged_visual(a.damage[j])
			camera.global_transform=a.camera.interpolate_with(b.camera,t)
			hud.update_game(rules,"REPLAY",a.speed,0,boosts,0,false); hud.score_label.text=Rules.money(a.score)
		return
	update_camera(delta)
	update_particles(delta)
	var speed:float=skater.speed() if skater.ragdoll else run_speed
	hud.update_game(rules,Phase.keys()[phase],speed,charge,boosts,19.0-crash_clock,slow_motion)
	sound.update_roll(speed,phase==Phase.RUN)
	if capture_mode: capture_progress()

func overview_position() -> Vector3:
	var l:Dictionary=Rules.LEVELS[level_index]
	return Vector3(23,l.steps*l.rise+27,l.steps*l.run*.58+18)

func update_camera(delta: float) -> void:
	if phase==Phase.MENU:
		camera.position=overview_position()+Vector3(sin(Time.get_ticks_msec()*.00014)*1.8,0,0)
		camera.look_at(camera_target); return
	var target:Vector3=skater.focus_position()
	var desired:Vector3
	var focus:Vector3=target+Vector3(0,0,3.5)
	if phase==Phase.READY:
		desired=target+Vector3(7,4.5,-9)
		focus=target+Vector3(0,-.4,4.0)
	elif camera_style==0:
		desired=target+Vector3(8.0,6.5,-10.5)
	elif camera_style==1:
		desired=target+Vector3(17.0,10.0,8.0); focus=target
	else:
		desired=target+Vector3(0,22,4); focus=target
	if phase==Phase.RESULTS:
		desired=target+Vector3(12,10,-14); focus=target
	var blend:float=1.0-exp(-delta*4.0)
	camera.position=camera.position.lerp(desired,blend)
	camera_target=camera_target.lerp(focus,blend)
	camera_shake=move_toward(camera_shake,0,delta*.65)
	var shake:Vector3=Vector3(rng.randf_range(-1,1),rng.randf_range(-1,1),0)*camera_shake
	camera.look_at(camera_target+shake)
	camera.fov=lerpf(camera.fov,58+clampf(run_speed,0,31)*.34 if phase==Phase.RUN else 58,blend)

func burst(at: Vector3, color: Color, count: int, speed: float) -> void:
	if test_mode or DisplayServer.get_name()=="headless": return
	for i in count:
		var mesh:=MeshInstance3D.new(); var shape:=BoxMesh.new(); shape.size=Vector3.ONE*rng.randf_range(.05,.16); mesh.mesh=shape
		var mat:=StandardMaterial3D.new(); mat.albedo_color=color; mat.emission_enabled=true; mat.emission=color; mat.emission_energy_multiplier=.4; mesh.material_override=mat
		level_root.add_child(mesh); mesh.global_position=at
		var velocity:Vector3=Vector3(rng.randf_range(-1,1),rng.randf_range(.1,1.3),rng.randf_range(-1,1)).normalized()*rng.randf_range(speed*.5,speed)
		particles.append({"mesh":mesh,"velocity":velocity,"life":rng.randf_range(.4,1.1)})

func update_particles(delta: float) -> void:
	for i in range(particles.size()-1,-1,-1):
		var p:Dictionary=particles[i]
		p.life-=delta
		if p.life<=0 or not is_instance_valid(p.mesh):
			if is_instance_valid(p.mesh): p.mesh.queue_free()
			particles.remove_at(i); continue
		p.velocity.y-=12*delta
		p.mesh.position+=p.velocity*delta
		p.mesh.rotation+=Vector3(3,1,2)*delta
		p.mesh.scale=Vector3.ONE*minf(1,p.life*4)

func capture_progress() -> void:
	var name:String=""
	if phase==Phase.READY and charge>.25: name="level_%d_ready" % (level_index+1)
	if phase==Phase.RUN and skater.position.z>0: name="level_%d_run" % (level_index+1)
	if phase==Phase.CRASH and crash_clock>4: name="level_%d_crash" % (level_index+1)
	if phase==Phase.RESULTS: name="level_%d_results" % (level_index+1)
	if name!="" and not capture_flags.has(name):
		capture_flags[name]=true
		capture_frame.call_deferred(name)
		if phase==Phase.RESULTS:
			print("CAPTURE_RESULT ",level_index," ",rules.score," props=",rules.destroyed," explosions=",rules.explosions)
			get_tree().create_timer(.7).timeout.connect(func(): get_tree().quit())

func capture_frame(filename: String) -> void:
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(capture_dir))
	var image:Image=get_viewport().get_texture().get_image()
	image.save_png(capture_dir+"/"+filename+".png")
