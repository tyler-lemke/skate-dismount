extends SceneTree
func _initialize() -> void:
	var file:=FileAccess.open("res://docs/GODOT_LICENSE.txt",FileAccess.WRITE)
	file.store_string(Engine.get_license_text()+"\n\nTHIRD PARTY COPYRIGHT INFORMATION\n\n"+JSON.stringify(Engine.get_copyright_info(),"\t")+"\n\nTHIRD PARTY LICENSES\n\n")
	var info:Dictionary=Engine.get_license_info()
	for key in info:file.store_string(str(key)+"\n"+str(info[key])+"\n\n")
	file.close();quit()
