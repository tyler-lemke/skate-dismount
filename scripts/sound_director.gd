extends Node

var music: AudioStreamPlayer
var roll: AudioStreamPlayer
var pool: Array[AudioStreamPlayer] = []
var sounds: Dictionary = {}
var cursor: int = 0
var last_impact: int = 0
var last_receipt: int = 0
func _ready() -> void:
	# Dummy headless audio has no device to drain playback resources.
	if DisplayServer.get_name()=="headless": return
	for key in ["impact","blast","boost","launch","clack","finish","fracture","receipt","funded"]:
		sounds[key]=load("res://assets/audio/"+key+".wav")
	music=AudioStreamPlayer.new(); music.stream=load("res://assets/audio/cascade.wav"); music.bus="Music"; add_child(music); music.play()
	roll=AudioStreamPlayer.new(); roll.stream=load("res://assets/audio/roll.wav"); roll.bus="SFX"; roll.volume_db=-60; add_child(roll); roll.play()
	for i in 12:
		var player:=AudioStreamPlayer.new(); player.bus="SFX"; add_child(player); pool.append(player)

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
	var player:AudioStreamPlayer=pool[cursor%pool.size()]; cursor+=1
	player.stream=sounds[key]; player.pitch_scale=randf_range(.92,1.08); player.volume_db=-14 if key=="receipt" else (-6 if key=="clack" else -1)
	if key in ["impact","fracture"]: player.pitch_scale*=.78 if Engine.time_scale<.6 else 1.0
	player.play()

func update_roll(speed: float, rolling: bool) -> void:
	if not is_instance_valid(roll): return
	roll.volume_db=lerpf(roll.volume_db,-12+speed*.17 if rolling else -60,.12)
	roll.pitch_scale=.7+speed*.035

func _exit_tree() -> void:
	if is_instance_valid(music): music.stop(); music.stream=null
	if is_instance_valid(roll): roll.stop(); roll.stream=null
	for player in pool:
		if is_instance_valid(player): player.stop(); player.stream=null
	pool.clear(); sounds.clear()
