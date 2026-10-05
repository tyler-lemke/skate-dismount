extends Node3D

const CrashCameraPolicy=preload("res://scripts/crash_camera.gd")

const Rules = preload("res://scripts/game_rules.gd")
const World = preload("res://scripts/world_builder.gd")
const Rider = preload("res://scripts/rider.gd")
const HUD = preload("res://scripts/game_hud.gd")
const Sound = preload("res://scripts/sound_director.gd")
const CRASHBREAKER_USES: int = 1
const PULSE_RADIUS: float = 2.2
const PULSE_BUDGET: float = 90.0
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
var boosts: int = CRASHBREAKER_USES
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
var legacy_scores: Array[int] = [0,0,0]
var muted: bool = false
const DEFAULT_RECORDS_PATH: String = "user://records.json"
var save_path: String = DEFAULT_RECORDS_PATH
var records_path_source: String = "user-default"
var startup_error: String = ""
var startup_records_read_path: String = ""
var particles: Array[Dictionary] = []
var replay_frames: Array[Dictionary] = []
var replay_actors: Array[Node3D] = []
var self_check: bool = false
var record_clock: float = 0.0
var replay_clock: float = 0.0
var result_was_best: bool = false
var rng := RandomNumberGenerator.new()
var test_mode: bool = false
var traffic_cue: bool = false
var automate: bool = false
var capture_mode: bool = false
var capture_dir: String = "res://docs/screenshots"
var capture_flags: Dictionary = {}
var pending_level: int = 0
var run_serial: int = 0
var pose_index: int = 0
var time_rate: float = 1.0
var impact_left: float = 0.0
var impact_cooldown: float = 0.0
var boost_cooldown: float = 0.0
var crash_real_clock: float = 0.0
var last_money_secured: int = 0
var claim_events: Array[Dictionary] = []
var cascade_focus: Vector3 = Vector3.ZERO
var cascade_focus_left: float = 0.0
var aim_marker: Node3D
var selected_hat: int = 0
var traffic_edges: Array[Dictionary] = []
var traffic_final_states: Array[Dictionary] = []
var breaker_events: Array[Dictionary] = []
var cascade_grace: float = 0.0
var push_clock: float = 0.0
var push_active: bool = false
var push_count: int = 0
var heading: float = 0.0

func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	rng.seed=90210
	if not configure_startup(OS.get_cmdline_user_args()):
		push_error("STARTUP: "+startup_error)
		get_tree().quit(2)
		return
	startup_records_read_path = save_path
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
	hud.pose_requested.connect(set_pose)
	sound=Sound.new(); add_child(sound); sound.set_muted(muted)
	select_route(pending_level)
	if automate: start_ready()

func configure_startup(arguments: PackedStringArray) -> bool:
	# Resolve the selected profile before the first read. Test modes never replace it.
	var explicit_path: String = ""
	var explicit_count: int = 0
	startup_error = ""
	for arg in arguments:
		if arg == "--test-mode": test_mode = true
		if arg == "--demo": automate = true
		if arg == "--self-check": automate = true; self_check = true
		if arg == "--capture": capture_mode = true; automate = true
		if arg.begins_with("--level="):
			pending_level = clampi(int(arg.get_slice("=",1)),0,2)
		if arg == "--records-path":
			startup_error = "Use --records-path=<absolute filename>."
			return false
		if arg.begins_with("--records-path="):
			explicit_count += 1
			explicit_path = arg.trim_prefix("--records-path=")
			if explicit_path.is_empty() or not explicit_path.is_absolute_path() or explicit_path.begins_with("res://") or explicit_path.begins_with("user://") or explicit_path.get_file().is_empty():
				startup_error = "Records override must be an absolute filename."
				return false
	if explicit_count > 1:
		startup_error = "Only one records override is allowed."
		return false
	if explicit_count == 1:
		save_path = explicit_path.simplify_path()
		records_path_source = "cli"
	elif save_path != DEFAULT_RECORDS_PATH and not save_path.is_empty():
		records_path_source = "injected"
	elif test_mode or capture_mode or self_check:
		var mode: String = "selfcheck" if self_check else ("capture" if capture_mode else "test")
		var directory: String = ProjectSettings.globalize_path("res://builds/test_runs/direct-%s-%s-%s" % [mode,OS.get_process_id(),Time.get_ticks_usec()])
		var error: Error = DirAccess.make_dir_recursive_absolute(directory)
		if error != OK:
			startup_error = "Cannot create isolated records directory (error %s)." % error
			return false
		save_path = directory.path_join("records.json")
		records_path_source = mode+"-default"
	else:
		save_path = DEFAULT_RECORDS_PATH
		records_path_source = "user-default"
	return true

func load_records() -> void:
	if not FileAccess.file_exists(save_path): return
	var data: Variant=JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if not data is Dictionary: return
	var scores: Variant=data.get("best_scores",[])
	if scores is Array and scores.size()==3:
		for i in 3:
			if int(data.get("version",1))>=2: best_scores[i]=clampi(int(scores[i]),0,999999999)
			else: legacy_scores[i]=clampi(int(scores[i]),0,999999999); best_scores[i]=0
	var legacy: Variant=data.get("legacy_scores",[])
	if legacy is Array and legacy.size()==3:
		for i in 3: legacy_scores[i]=clampi(int(legacy[i]),0,999999999)
	muted=bool(data.get("muted",false))
	selected_hat=clampi(int(data.get("hat",0)),0,2)

func save_records() -> void:
	var file:=FileAccess.open(save_path,FileAccess.WRITE)
	if file: file.store_string(JSON.stringify({"version":2,"best_scores":best_scores,"legacy_scores":legacy_scores,"muted":muted,"hat":selected_hat}))

func fund_total() -> int:
	return best_scores.reduce(func(total: int, amount: int): return total+amount,0)

func set_pose(index: int) -> void:
	if phase not in [Phase.MENU,Phase.READY]: return
	pose_index=clampi(index,0,2)
	skater.set_pose(pose_index)
	skater.set_hat(selected_hat)
	hud.toast(Rules.POSES[pose_index].name)

func boost_direction() -> Vector3:
	var side: float=steering()
	var uphill: bool=Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)
	return Vector3(side*1.5,0,-1.0 if uphill else 1.0).normalized()

func apply_time_rate() -> void:
	time_rate=1.0
	if not is_paused:
		if phase==Phase.CRASH: time_rate=.55
		if slow_motion and phase in [Phase.RUN,Phase.CRASH]: time_rate=.25
		if impact_left>0 and phase==Phase.CRASH: time_rate=.18
	Engine.time_scale=time_rate

func select_route(index: int) -> void:
	unpause()
	level_index=clampi(index,0,2)
	rules.reset(); replay_frames.clear(); replay_actors.clear(); particles.clear(); claim_events.clear()
	traffic_edges.clear(); traffic_final_states.clear(); breaker_events.clear(); cascade_grace=0
	push_clock=0; push_active=false; push_count=0; heading=0
	traffic_cue=false
	if is_instance_valid(level_root):
		remove_child(level_root); level_root.queue_free()
	level_root=Node3D.new(); level_root.name="Route"; level_root.process_mode=Node.PROCESS_MODE_PAUSABLE; add_child(level_root)
	world=World.new(); world.build(level_root,level_index,self)
	skater=Rider.new(); skater.game=self; level_root.add_child(skater)
	skater.set_pose(pose_index)
	skater.set_hat(selected_hat)
	var l:Dictionary=Rules.LEVELS[level_index]
	# Lead the first run into the readable domino chain; other routes open at their cargo/drum line.
	skater.position=Vector3(-3.3 if level_index==0 else 0.0,l.steps*l.rise+.23,-13)
	phase=Phase.MENU; charge=0; charging=false; run_speed=0; boosts=CRASHBREAKER_USES; run_clock=0; crash_clock=0; camera_shake=0
	impact_left=0; impact_cooldown=0; boost_cooldown=0; crash_real_clock=0; cascade_focus_left=0; aim_marker=null
	apply_time_rate()
	camera_target=Vector3(-5,l.steps*l.rise*.45,l.steps*l.run*.40)
	camera.position=overview_position()
	camera.look_at(camera_target)
	hud.set_route(level_index,best_scores[level_index]); hud.update_campaign(); hud.show_menu()

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
	get_tree().paused=false; is_paused=false; paused_for_help=false; slow_motion=false; apply_time_rate()
	if is_instance_valid(hud): hud.pause_panel.visible=false

func toggle_pause() -> void:
	if phase==Phase.MENU: return
	if phase==Phase.RESULTS: back_to_menu(); return
	is_paused=not is_paused; get_tree().paused=is_paused; hud.pause_panel.visible=is_paused
	if is_paused: charging=false
	slow_motion=false;apply_time_rate()

func toggle_mute() -> void:
	muted=not muted; sound.set_muted(muted); save_records()
	if hud.hud.visible: hud.toast("SOUND OFF" if muted else "SOUND ON")
	else: hud.best_label.text="SOUND OFF" if muted else "SOUND ON"

func _input(event: InputEvent) -> void:
	# Launch and bail take priority over a pose button's default Space/ui_accept.
	if event is InputEventKey and event.physical_keycode==KEY_SPACE and not event.echo and phase in [Phase.READY,Phase.RUN] and not is_paused and not hud.help_panel.visible:
		_unhandled_input(event)
		get_viewport().set_input_as_handled()

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
		if key==KEY_F and phase==Phase.READY:
			selected_hat=(selected_hat+1)%3; skater.set_hat(selected_hat); save_records(); hud.toast(["CLOCKWORK CROWN","PAPER CRANE","TRAFFIC CONE"][selected_hat]); return
		if key in [KEY_1,KEY_2,KEY_3] and phase==Phase.READY: set_pose(key-KEY_1); return
		if key==KEY_ENTER and phase==Phase.CRASH: finish_run(); return
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
		slow_motion=event.pressed; apply_time_rate()

func steering() -> float:
	return float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT))-float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT))

func launch() -> void:
	if phase!=Phase.READY: return
	phase=Phase.RUN; charging=false; run_speed=6.5+charge*12.0; run_clock=0; lateral_speed=0; run_serial+=1
	for prop in world.props:
		if prop.get_meta("traffic",false): continue
		prop.freeze=false; prop.grace=.65; prop.origin=prop.global_position
	world.start_traffic()
	hud.toast("CHASE THE BIGGEST CLAIM",WreckHUD.ORANGE); sound.play("launch")

func is_live() -> bool:
	return phase==Phase.RUN or phase==Phase.CRASH

func _physics_process(delta: float) -> void:
	if is_paused or not is_instance_valid(skater): return
	if phase==Phase.READY:
		if charging: charge=minf(1.0,charge+delta*.65)
		var lane_limit: float=Rules.LEVELS[level_index].width*.5-.8
		skater.position.x=clampf(skater.position.x+steering()*delta*3.5,-lane_limit,lane_limit)
		skater.pose_ride(run_clock,steering(),0,false)
		if automate:
			charge=minf(1,charge+delta*.9)
			if charge>=1: launch()
	elif phase==Phase.RUN:
		run_clock+=delta
		rules.tick(delta)
		var pushing: bool=(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP) or automate) and skater.position.z<0
		# A rear-foot stroke adds one kick; coasting no longer accelerates itself.
		run_speed=move_toward(run_speed,0,delta*.28)
		if pushing:
			if not push_active: push_clock=0
			var before_kick: int=int(floor((push_clock+.324)/.72))
			push_clock+=delta
			var kicks: int=int(floor((push_clock+.324)/.72))-before_kick
			if kicks>0:
				run_speed+=2.1*kicks; push_count+=kicks
		else: push_clock=0
		push_active=pushing
		if skater.position.z>0: run_speed+=delta*5.0
		run_speed=minf(31.0,run_speed)
		heading=move_toward(heading,steering()*.28,delta*1.4)
		lateral_speed=sin(heading)*run_speed
		skater.position.x=clampf(skater.position.x+lateral_speed*delta,-Rules.LEVELS[level_index].width*.5+.8,Rules.LEVELS[level_index].width*.5-.8)
		skater.position.z+=cos(heading)*run_speed*delta
		skater.rotation.y=heading
		var desired_y: float=Rules.surface_y(Rules.LEVELS[level_index],skater.position.z)+.23
		skater.position.y=move_toward(skater.position.y,desired_y,delta*9)
		skater.set_push_phase(fmod(push_clock,.72)/.72)
		skater.pose_ride(run_clock,steering(),run_speed,pushing)
		var stairs_end: float=Rules.LEVELS[level_index].steps*Rules.LEVELS[level_index].run
		if not traffic_cue and skater.position.z>stairs_end-7:
			traffic_cue=true
			hud.toast("TRAFFIC AHEAD  /  SPACE TO BAIL",WreckHUD.MINT)
		rules.peak_speed=maxf(rules.peak_speed,run_speed)
		for prop in world.props:
			if not is_instance_valid(prop) or prop.broken or prop.get_meta("traffic",false): continue
			var d: Vector3=prop.global_position-skater.global_position
			if absf(d.x)<prop.nominal_radius+.30 and absf(d.z)<prop.nominal_radius+.3 and d.y>-.4 and d.y<2.6:
				var strike: Vector3=Vector3(lateral_speed*.7,2.0,run_speed)*prop.mass*1.3
				if prop.kind=="taxi":
					var effective_mass: float=35.0*prop.mass/(35.0+prop.mass)
					strike=Vector3(lateral_speed,0,run_speed)*effective_mass
				prop.activate(strike)
				bail_out(); break
		if phase==Phase.RUN and skater.position.z>Rules.LEVELS[level_index].steps*Rules.LEVELS[level_index].run-.35: bail_out()
	elif phase==Phase.CRASH:
		crash_clock+=delta; rules.tick(delta)
		skater.aftertouch(Vector3(steering(),0,0),false,delta)
		rules.peak_speed=maxf(rules.peak_speed,skater.speed())
		var movement: float=skater.speed()
		for prop in world.props:
			if is_instance_valid(prop) and prop.armed: movement=maxf(movement,prop.linear_velocity.length())
		var pending_fuse: bool = false
		for prop in world.props:
			if is_instance_valid(prop) and prop.armed and prop.fuse>0 and not prop.broken: pending_fuse=true
		cascade_grace=maxf(0,cascade_grace-delta)
		var pending: bool = pending_fuse or cascade_grace>0 or world.traffic_pending_contact(1.5)
		idle_clock=idle_clock+delta if movement<1.0 and not pending else 0.0
		if automate and crash_clock>2.2 and boosts>0: crashbreaker()
		if (crash_clock>3 and idle_clock>1.25) or crash_clock>=16.0 or crash_real_clock>=34.0:
			finish_run()
	if is_live():
		record_clock+=delta
		if record_clock>=.05: record_clock=0; record_frame()

func bail_out() -> void:
	if phase!=Phase.RUN: return
	phase=Phase.CRASH; crash_clock=0; idle_clock=0
	# The board's obstacle strike keeps full approach momentum. The rider falls
	# into the stair noses instead of sailing above them to the taxi plaza.
	skater.bail(Vector3(lateral_speed*.9,-2.2,run_speed*.72),.5)
	apply_time_rate()
	build_aim_marker()
	replay_actors.clear()
	for prop in world.props: replay_actors.append(prop)
	for body in skater.limbs: replay_actors.append(body)
	replay_frames.clear()
	hud.toast(Rules.POSES[pose_index].name+"   /   AIM A D + SHIFT",WreckHUD.ORANGE)
	sound.play("launch"); camera_shake=.12

func crashbreaker() -> void:
	if phase!=Phase.CRASH or boosts<=0 or is_paused or hud.help_panel.visible: return
	# Consume before any callbacks: exactly one activation even under repeated input.
	boosts=0; boost_cooldown=0; idle_clock=0; cascade_grace=1.5
	var aim: Vector3 = boost_direction()
	skater.launch_impulse(aim,8.5)
	var position: Vector3=skater.focus_position()
	breaker_events.append({"time":crash_clock,"aim":aim,"at":position})
	burst(position,Color("84efbc"),18,4.0)
	hud.toast("CRASHBREAKER!",WreckHUD.MINT); sound.play("boost"); camera_shake=.35
	var pulses: Array[Dictionary] = []
	var total: float = 0.0
	for prop in world.props:
		if not is_instance_valid(prop): continue
		var offset: Vector3=prop.global_position-position
		var distance: float=offset.length()
		var horizontal: Vector3=Vector3(offset.x,0,offset.z)
		if distance>=PULSE_RADIUS or horizontal.length_squared()<.001: continue
		var alignment: float=horizontal.normalized().dot(aim)
		if alignment<cos(deg_to_rad(35)): continue
		var query:=PhysicsRayQueryParameters3D.create(position,prop.global_position,3)
		query.exclude=[]
		for body in skater.limbs: query.exclude.append(body.get_rid())
		var obstruction: Dictionary=get_world_3d().direct_space_state.intersect_ray(query)
		if not obstruction.is_empty() and obstruction.collider!=prop: continue
		var falloff: float=pow(1.0-distance/PULSE_RADIUS,2.0)*alignment
		var amount: float=minf(60.0,minf(prop.mass*4.0,60.0*falloff))
		var direction: Vector3=(aim+Vector3.UP*.18).normalized()
		pulses.append({"prop":prop,"impulse":direction*amount})
		total+=amount
	var scale: float=minf(1,PULSE_BUDGET/maxf(total,.001))
	for pulse in pulses: pulse.prop.apply_shove(pulse.impulse*scale,"CRASHBREAKER")

func traffic_contact(car: CrashProp, other: Object, strength: float, at: Vector3) -> void:
	if not is_live() or not car.armed: return
	var source: String = "RIDER"
	if other is CrashProp:
		source=other.stable_id if not other.stable_id.is_empty() else other.name.to_upper()
	var destination: String=car.stable_id if not car.stable_id.is_empty() else car.name.to_upper()
	traffic_edges.append({"time":run_clock+crash_clock,"source":source,"destination":destination,"strength":strength,"at":at})
	if strength>=car.threshold: sound.play("metal_crash")
	cascade_focus=at; cascade_focus_left=1.4; cascade_grace=1.5

func traffic_braked(car: CrashProp) -> void:
	if not is_live() or car.global_position.distance_to(skater.focus_position())>24: return
	sound.play("squeal")
	sound.play("horn")

func receipt_label(identity: String) -> String:
	if identity.begins_with("traffic_"):
		return "CAR "+char(65+int(identity.get_slice("_",2)))
	if Rules.LIMB_WEIGHTS.has(identity): return "RIDER"
	return identity.replace("_"," ").to_upper()

func prop_wrecked(prop: CrashProp, explosive: bool) -> void:
	if not is_live(): return
	var points: int=rules.hit_prop(prop.get_instance_id(),prop.value,explosive)
	if points==0: return
	var source_label: String = prop.cause_label
	var receipt: String = prop.kind.to_upper()
	if prop.get_meta("traffic",false): receipt=receipt_label(source_label)+" → "+receipt_label(prop.stable_id)
	claim_events.append({"time":crash_clock,"type":"property","part":prop.kind,"payout":points,"at":prop.global_position,"source":source_label})
	hud.claim_event(receipt,points)
	sound.play("receipt")
	cascade_focus=prop.global_position; cascade_focus_left=.8
	if explosive:
		burst(prop.global_position,Color("ff9548"),35,11.0)
		burst(prop.global_position,Color("ffd278"),14,6.0)
		sound.play("blast"); hud.flash(); camera_shake=minf(.8,camera_shake+.28)
		var at: Vector3=prop.global_position
		for other in world.props:
			if not is_instance_valid(other) or other==prop: continue
			var offset: Vector3=other.global_position-at
			var distance: float=offset.length()
			if distance<3.4:
				var impulse: Vector3=(offset+Vector3(0,.5,1.0)).normalized()*minf(other.mass*(8.5-distance*1.5),85.0 if other.get_meta("traffic",false) else 10000.0)
				if other.get_meta("traffic",false): other.apply_shove(impulse,prop.name.to_upper())
				else: other.activate(impulse)
		for body in skater.limbs:
			if is_instance_valid(body) and body.global_position.distance_to(at)<5.2:
				body.apply_central_impulse((body.global_position-at+Vector3(0,.3,1.5)).normalized()*body.mass*3.5*(1.0-body.global_position.distance_to(at)/5.2))
	else:
		burst(prop.global_position,Rules.LEVELS[level_index].color,7,4.0)
		sound.play("clack")
	if rules.combo % 5==0 or explosive:
		hud.toast(("DRUM DETONATION" if explosive else "%d OBJECT CASCADE" % rules.combo)+"   ×%d" % rules.multiplier(),WreckHUD.ORANGE if explosive else WreckHUD.MINT)

func rider_hit(limb: String, force: float, at: Vector3, source: String = "") -> void:
	if phase!=Phase.CRASH: return
	var id: String="%d:%s:%d" % [run_serial,limb,int(crash_clock*4)]
	var old_stage: String=Rules.injury_stage(rules.limb_damage.get(limb,0.0))
	var points: int=rules.hit_rider(id,force,limb)
	if points<=0: return
	skater.set_limb_damage(limb,rules.limb_damage.get(limb,0.0))
	claim_events.append({"time":crash_clock,"type":"injury","part":limb,"payout":points,"at":at,"source":source})
	hud.claim_event(Rules.limb_title(limb)+(" / STEP" if source.begins_with("Tread_") else ""),points,true)
	var new_stage: String=Rules.injury_stage(rules.limb_damage.get(limb,0.0))
	if new_stage=="FRACTURED" and old_stage!=new_stage: sound.play("fracture")
	if force>=8 and impact_cooldown<=0:
		impact_left=.28; impact_cooldown=1.1; apply_time_rate()
	if points>150:
		burst(at,Color("f4e1b2"),4,3.0)
		camera_shake=minf(.6,camera_shake+force*.004)
		if force>7: sound.play("impact")

func finish_run() -> void:
	if phase!=Phase.CRASH: return
	record_frame()
	traffic_final_states.clear()
	for car in world.traffic: traffic_final_states.append(car.snapshot())
	phase=Phase.RESULTS; Engine.time_scale=1.0; slow_motion=false
	time_rate=1; impact_left=0
	if is_instance_valid(aim_marker): aim_marker.visible=false
	last_money_secured=maxi(0,rules.score-best_scores[level_index])
	result_was_best=rules.score>best_scores[level_index]
	if result_was_best:
		best_scores[level_index]=rules.score
		if not self_check: save_records()
	freeze_actors()
	hud.update_campaign(last_money_secured); hud.show_results(rules,level_index,result_was_best); sound.play("funded" if fund_total()>=Rules.TREATMENT_GOAL and fund_total()-last_money_secured<Rules.TREATMENT_GOAL else "finish")
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
	var traffic_states: Array[Dictionary] = []
	for car in world.traffic: traffic_states.append(car.snapshot())
	for prop in world.props: damage_states.append(prop.broken if is_instance_valid(prop) else true)
	for actor in replay_actors:
		transforms.append(actor.global_transform if is_instance_valid(actor) else Transform3D.IDENTITY)
	replay_frames.append({"transforms":transforms,"camera":camera.global_transform,"score":rules.score,"speed":skater.speed(),"damage":damage_states,"limbs":rules.limb_damage.duplicate(),"traffic":traffic_states,"boosts":boosts})

func start_replay() -> void:
	if phase!=Phase.RESULTS or replay_frames.size()<2: return
	phase=Phase.REPLAY; replay_clock=0; hud.results.visible=false; hud.replay_banner.visible=true
	Engine.time_scale=1.0; time_rate=1
	hud.power_panel.visible=false; freeze_actors()
	hud.toast("CINEMATIC REPLAY")

func _process(delta: float) -> void:
	if is_paused or not is_instance_valid(skater): return
	var real_delta: float=delta/maxf(.01,Engine.time_scale)
	impact_left=maxf(0,impact_left-real_delta); impact_cooldown=maxf(0,impact_cooldown-real_delta)
	boost_cooldown=maxf(0,boost_cooldown-real_delta); cascade_focus_left=maxf(0,cascade_focus_left-real_delta)
	if phase==Phase.CRASH: crash_real_clock+=real_delta
	apply_time_rate()
	if phase==Phase.REPLAY:
		replay_clock+=delta*.72
		var cursor: float=replay_clock/.05
		var i: int=int(cursor)
		if i>=replay_frames.size()-1:
			phase=Phase.RESULTS; hud.replay_banner.visible=false; hud.show_results(rules,level_index,result_was_best)
			var last: Dictionary = replay_frames.back()
			for j in replay_actors.size():
				if is_instance_valid(replay_actors[j]): replay_actors[j].global_transform=last.transforms[j]
			for prop in world.props:
				if is_instance_valid(prop): prop.set_damaged_visual(prop.broken)
			for j in world.traffic.size(): world.traffic[j].apply_snapshot(traffic_final_states[j])
			skater.apply_damage_states(rules.limb_damage)
			skater.sync_skin()
		else:
			var a:Dictionary=replay_frames[i]; var b:Dictionary=replay_frames[i+1]; var t:float=cursor-i
			for j in replay_actors.size():
				if is_instance_valid(replay_actors[j]):
					replay_actors[j].global_transform=a.transforms[j].interpolate_with(b.transforms[j],t)
					if replay_actors[j] is CrashProp: replay_actors[j].set_damaged_visual(a.damage[j])
			for j in world.traffic.size(): world.traffic[j].apply_snapshot(a.traffic[j])
			camera.global_transform=a.camera.interpolate_with(b.camera,t)
			skater.apply_damage_states(a.limbs)
			skater.sync_skin()
			hud.update_game(rules,"REPLAY",a.speed,0,a.boosts,0,false); hud.score_label.text="$"+Rules.money(a.score)
		return
	update_camera(real_delta)
	update_aim_marker()
	update_particles(delta)
	var speed:float=skater.speed() if skater.ragdoll else run_speed
	hud.update_game(rules,Phase.keys()[phase],speed,charge,boosts,16.0-crash_clock,slow_motion)
	sound.update_roll(speed,phase==Phase.RUN)
	sound.update_traffic(world.traffic if is_live() else [],skater.focus_position())
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
	if phase==Phase.CRASH and camera_style==0:
		focus=target+Vector3(0,-.25,1)
		desired=target+Vector3(5.8,3.4,-6.8)
		if cascade_focus_left>0 and target.distance_to(cascade_focus)<10:
			focus=focus.lerp(cascade_focus,.25)
		if impact_left>0: desired=target+Vector3(4.8,2.8,-5.8)
		# The second act follows a verified traffic handoff, never random traffic.
		var end_z: float = Rules.LEVELS[level_index].steps*Rules.LEVELS[level_index].run
		if cascade_focus_left>0 and cascade_focus.z>end_z and not traffic_edges.is_empty():
			focus=target.lerp(cascade_focus,.72)
			desired=focus+Vector3(8.5,6.2,-11)
		elif target.z>end_z-6 and boosts>0:
			focus=target+Vector3(0,.2,5)
			desired=target+Vector3(7.0,5.8,-9)
	if phase==Phase.RESULTS:
		desired=target+Vector3(12,10,-14); focus=target
	if phase==Phase.CRASH and camera_style==0 and not (cascade_focus_left>0 and not traffic_edges.is_empty() and cascade_focus.z>Rules.LEVELS[level_index].steps*Rules.LEVELS[level_index].run):
		desired=CrashCameraPolicy.choose_position(get_world_3d().direct_space_state,target,desired,Rules.surface_y(Rules.LEVELS[level_index],desired.z))
	var blend:float=1.0-exp(-delta*4.0)
	camera.position=camera.position.lerp(desired,blend)
	camera_target=camera_target.lerp(focus,blend)
	camera_shake=move_toward(camera_shake,0,delta*.65)
	var shake:Vector3=Vector3(rng.randf_range(-1,1),rng.randf_range(-1,1),0)*camera_shake
	camera.look_at(camera_target+shake)
	camera.fov=lerpf(camera.fov,58+clampf(run_speed,0,31)*.34 if phase==Phase.RUN else 52,blend)
	# Keep the lens above the stair surface when a body rolls behind a riser.
	camera.position.y=maxf(camera.position.y,Rules.surface_y(Rules.LEVELS[level_index],camera.position.z)+1.0)

func build_aim_marker() -> void:
	aim_marker=Node3D.new(); level_root.add_child(aim_marker)
	for i in 5:
		var mesh:=MeshInstance3D.new(); var ball:=SphereMesh.new(); ball.radius=.10+i*.018; ball.height=ball.radius*2; mesh.mesh=ball
		var mat:=StandardMaterial3D.new(); mat.albedo_color=WreckHUD.MINT; mat.emission_enabled=true; mat.emission=WreckHUD.MINT; mat.emission_energy_multiplier=.7; mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED; mesh.material_override=mat
		aim_marker.add_child(mesh)

func update_aim_marker() -> void:
	if not is_instance_valid(aim_marker): return
	aim_marker.visible=phase==Phase.CRASH and boosts>0
	if not aim_marker.visible: return
	var start: Vector3=skater.focus_position()
	var direction: Vector3=boost_direction()
	for i in aim_marker.get_child_count():
		var t: float=(i+1)*.42
		aim_marker.get_child(i).global_position=start+direction*t*3.0+Vector3(0,.9+sin(t)*.9,0)

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
