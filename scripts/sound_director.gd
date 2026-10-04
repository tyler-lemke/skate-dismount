extends Node

var music: AudioStreamPlayer
var roll: AudioStreamPlayer
var traffic_engine: AudioStreamPlayer
var pool: Array[AudioStreamPlayer] = []
var sounds: Dictionary = {}
var cursor: int = 0
var last_impact: int = -100000
var last_receipt: int = -100000
var last_metal: int = -100000
var last_squeal: int = -100000
var last_horn: int = -100000
func _ready() -> void:
	# The audio controller must observe pause changes even while gameplay nodes stop.
	process_mode=Node.PROCESS_MODE_ALWAYS
	# Dummy headless audio has no device to drain playback resources.
	if DisplayServer.get_name()=="headless": return
	for key in ["impact","blast","boost","launch","clack","finish","fracture","receipt","funded","metal_crash","squeal","horn"]:
		sounds[key]=load("res://assets/audio/"+key+".wav")
	music=AudioStreamPlayer.new(); music.stream=load("res://assets/audio/cascade.wav"); music.bus="Music"; add_child(music); music.play()
	roll=AudioStreamPlayer.new(); roll.stream=load("res://assets/audio/roll.wav"); roll.bus="SFX"; roll.volume_db=-60; add_child(roll); roll.play()
	traffic_engine=AudioStreamPlayer.new(); traffic_engine.stream=load("res://assets/audio/engine.wav"); traffic_engine.bus="SFX"; traffic_engine.volume_db=-60; add_child(traffic_engine); traffic_engine.play()
	for i in 12:
		var player:=AudioStreamPlayer.new(); player.bus="SFX"; add_child(player); pool.append(player)

func _process(_delta: float) -> void:
	var paused: bool=get_tree().paused
	if is_instance_valid(roll): roll.stream_paused=paused
	if is_instance_valid(traffic_engine): traffic_engine.stream_paused=paused

func set_muted(muted: bool) -> void:
	AudioServer.set_bus_mute(0,muted)

func play(key: String) -> void:
	if not sounds.has(key) or pool.is_empty(): return
	var now: int=Time.get_ticks_msec()
	if key=="receipt":
		if now-last_receipt<130: return
		last_receipt=now
	if key in ["impact","clack"]:
		if now-last_impact<65: return
		last_impact=now
	if key=="metal_crash":
		if now-last_metal<180: return
		last_metal=now
	if key=="squeal":
		if now-last_squeal<620: return
		last_squeal=now
	if key=="horn":
		if now-last_horn<1400: return
		last_horn=now
	var player:AudioStreamPlayer=pool[cursor%pool.size()]; cursor+=1
	player.stream=sounds[key]; player.pitch_scale=randf_range(.94,1.06)
	match key:
		"receipt": player.volume_db=-14
		"clack": player.volume_db=-6
		"metal_crash": player.volume_db=-4
		"squeal": player.volume_db=-11
		"horn": player.volume_db=-15
		_: player.volume_db=-1
	if key in ["impact","fracture"]: player.pitch_scale*=.78 if Engine.time_scale<.6 else 1.0
	player.play()

func update_roll(speed: float, rolling: bool) -> void:
	if not is_instance_valid(roll): return
	roll.volume_db=lerpf(roll.volume_db,-12+speed*.17 if rolling else -60,.12)
	roll.pitch_scale=.7+speed*.035

func update_traffic(cars: Array, focus: Vector3) -> void:
	if not is_instance_valid(traffic_engine): return
	var presence: float=0.0
	var closest_speed: float=0.0
	for car in cars:
		if not is_instance_valid(car) or not car is TrafficCar: continue
		if not car.started or car.exited or not car.visible: continue
		if car.driver_state not in [TrafficCar.DriverState.DRIVE,TrafficCar.DriverState.BRAKE]: continue
		var distance: float=car.global_position.distance_to(focus)
		var proximity: float=clampf(1.0-distance/32.0,0.0,1.0)
		var speed: float=car.linear_velocity.length()
		var contribution: float=proximity*clampf(speed/7.0,0.0,1.0)
		if contribution>presence:
			presence=contribution
			closest_speed=speed
	var target_db: float=-60.0 if presence<=.01 else -35.0+presence*15.0
	var step: float=maxf(.001,get_process_delta_time())*35.0
	traffic_engine.volume_db=move_toward(traffic_engine.volume_db,target_db,step)
	traffic_engine.pitch_scale=lerpf(traffic_engine.pitch_scale,clampf(.73+closest_speed*.045,.7,1.2),.10)

func _exit_tree() -> void:
	if is_instance_valid(music): music.stop(); music.stream=null
	if is_instance_valid(roll): roll.stop(); roll.stream=null
	if is_instance_valid(traffic_engine): traffic_engine.stop(); traffic_engine.stream=null
	for player in pool:
		if is_instance_valid(player): player.stop(); player.stream=null
	pool.clear(); sounds.clear()
