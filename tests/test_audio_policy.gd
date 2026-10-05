extends SceneTree
const Fixtures=preload("res://tests/test_fixtures.gd")
var fixture=Fixtures.new("test_audio_policy")
var checks: int=0
var failures: int=0
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures+=1; printerr("FAIL: "+message)
func player(parent: Node, key: String) -> AudioStreamPlayer:
	var node:=AudioStreamPlayer.new()
	node.stream=load("res://assets/audio/"+key+".wav")
	parent.add_child(node)
	return node
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game: Node3D=fixture.create_game(root)
	if game==null: return
	var sound: Node=game.sound
	# Real AudioStreamPlayer nodes exercise pause/replay policy even with a dummy
	# output device. This does not claim audibility or mix quality.
	sound.music=player(sound,"cascade")
	sound.roll=player(sound,"roll")
	sound.traffic_engine=player(sound,"engine")
	for i in 3: sound.pool.append(player(sound,"receipt"))
	sound.sounds.receipt=load("res://assets/audio/receipt.wav")
	sound.music.play(); sound.roll.play(); sound.traffic_engine.play()
	for node in sound.pool: node.play()
	game.start_ready(); game.toggle_pause()
	await process_frame; await process_frame
	check(sound.roll.stream_paused and sound.traffic_engine.stream_paused,"pause suspends both active action loops")
	for node in sound.pool: check(node.stream_paused,"pause suspends every active one-shot")
	check(not sound.music.stream_paused,"chosen pause policy keeps music independent")
	game.resume(); await process_frame
	check(not sound.roll.stream_paused and not sound.traffic_engine.stream_paused,"resume restores action loops")
	for node in sound.pool: check(not node.stream_paused,"resume restores one-shot pause state")
	sound.set_replay_audio(true)
	check(not sound.roll.playing and not sound.traffic_engine.playing,"replay stops prior rolling and traffic loops")
	for node in sound.pool: check(not node.playing,"replay stops prior action one-shots")
	var cursor: int=sound.cursor
	sound.play("receipt"); sound.update_roll(28,true); sound.update_traffic(game.world.traffic,Vector3.ZERO)
	check(sound.cursor==cursor and not sound.roll.playing and not sound.traffic_engine.playing,"replay cannot restart action sound categories")
	check(sound.music.playing,"replay preserves music playback")
	sound.set_replay_audio(false); sound.update_roll(14,true)
	check(sound.roll.playing,"leaving replay permits rolling loop to restart")
	sound.set_muted(true); check(AudioServer.is_bus_mute(0),"mute applies to master bus")
	sound.set_muted(false); check(not AudioServer.is_bus_mute(0),"unmute restores master bus")
	game.queue_free(); await process_frame; await process_frame; await process_frame
	# Allow the real dummy audio mixer thread to retire stopped playback objects.
	await create_timer(.2,true,false,true).timeout
	print("AUDIO_POLICY: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
