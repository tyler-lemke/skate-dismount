extends SceneTree
var checks:int=0
var failures:int=0
func check(condition:bool,message:String) -> void:
	checks+=1
	if not condition:failures+=1;printerr("FAIL: ",message)
func _initialize() -> void:
	for name in ["cascade","roll","impact","blast","boost","launch","clack","finish"]:
		var stream:AudioStreamWAV=load("res://assets/audio/"+name+".wav")
		check(stream!=null,"audio imports: "+name)
		if stream==null:continue
		check(stream.get_length()>.1,"audio has nonzero duration: "+name)
		check(stream.data.size()>100,"audio contains sample data: "+name)
		var expected:int=AudioStreamWAV.LOOP_FORWARD if name in ["cascade","roll"] else AudioStreamWAV.LOOP_DISABLED
		check(stream.loop_mode==expected,"correct loop mode: "+name)
	print("AUDIO: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
