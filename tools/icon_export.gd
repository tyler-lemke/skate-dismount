extends SceneTree
func _initialize() -> void:
	var source:Image=Image.load_from_file("res://assets/icon.svg")
	DirAccess.make_dir_recursive_absolute("res://assets/stairwreck.iconset")
	for size in [16,32,128,256,512]:
		for factor in [1,2]:
			var image:Image=source.duplicate();image.resize(size*factor,size*factor,Image.INTERPOLATE_LANCZOS)
			image.save_png("res://assets/stairwreck.iconset/icon_%dx%d%s.png"%[size,size,"@2x" if factor==2 else ""])
	quit()
