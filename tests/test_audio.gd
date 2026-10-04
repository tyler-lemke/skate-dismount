extends SceneTree
var checks:int=0
var failures:int=0
const TRAFFIC: Array[String] = ["engine","squeal","metal_crash","horn"]
func check(condition:bool,message:String) -> void:
	checks+=1
	if not condition:failures+=1;printerr("FAIL: ",message)
func _initialize() -> void:
	call_deferred("run")

func sample(bytes: PackedByteArray, index: int) -> int:
	var raw: int=int(bytes[index*2]) | (int(bytes[index*2+1])<<8)
	return raw-65536 if raw>=32768 else raw

func run() -> void:
	for name in ["cascade","roll","impact","blast","boost","launch","clack","finish","fracture","receipt","funded","engine","squeal","metal_crash","horn"]:
		var stream:AudioStreamWAV=load("res://assets/audio/"+name+".wav")
		check(stream!=null,"audio imports: "+name)
		if stream==null:continue
		check(stream.get_length()>.1,"audio has nonzero duration: "+name)
		check(stream.data.size()>100,"audio contains sample data: "+name)
		var expected:int=AudioStreamWAV.LOOP_FORWARD if name in ["cascade","roll","engine"] else AudioStreamWAV.LOOP_DISABLED
		check(stream.loop_mode==expected,"correct loop mode: "+name)
		if name in TRAFFIC:
			check(stream.format==AudioStreamWAV.FORMAT_16_BITS and stream.mix_rate==22050 and stream.stereo==false,"original traffic sample has 22.05 kHz mono 16-bit PCM: "+name)
			var count:int=stream.data.size()/2
			var peak:int=0
			var energy:float=0.0
			for i in count:
				var value:int=sample(stream.data,i)
				peak=maxi(peak,absi(value))
				energy+=float(value)*float(value)
			var rms:float=sqrt(energy/maxf(1,count))/32768.0
			check(peak<31000 and peak>1000,"traffic waveform has bounded non-silent peak: "+name)
			check(rms>.025 and rms<.55,"traffic waveform has useful non-clipping RMS: "+name)
			if name=="engine":
				var seam:float=absf(float(sample(stream.data,0)-sample(stream.data,count-1)))/32768.0
				check(seam<.04,"engine loop boundary is click-free at sample seam")
	var sound:Node=load("res://scripts/sound_director.gd").new()
	root.add_child(sound)
	await process_frame
	check(sound.process_mode==Node.PROCESS_MODE_ALWAYS,"sound controller keeps observing scene pause and resume")
	sound.update_traffic([],Vector3.ZERO)
	sound.play("metal_crash")
	if DisplayServer.get_name()=="headless":
		check(sound.traffic_engine==null and sound.pool.is_empty(),"headless audio creates no playback objects")
		paused=true
		await process_frame
		check(sound.roll==null and sound.traffic_engine==null,"paused headless process does not allocate rolling or traffic loops")
		paused=false
		await process_frame
		check(sound.roll==null and sound.traffic_engine==null,"resumed headless process remains allocation-free")
	sound.queue_free()
	await process_frame
	print("AUDIO: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
