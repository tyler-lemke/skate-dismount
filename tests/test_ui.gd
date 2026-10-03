extends SceneTree
var failures:int=0
var checks:int=0
func _initialize() -> void:call_deferred("run")
func check(condition:bool,message:String) -> void:
	checks+=1
	if not condition:failures+=1;printerr("FAIL: ",message)
func verify(node:Node) -> void:
	if node is Control and not node.is_visible_in_tree():return
	if node is Label and node.text!="":
		var font:Font=node.get_theme_font("font")
		var size:int=node.get_theme_font_size("font_size")
		if node.autowrap_mode==TextServer.AUTOWRAP_OFF:
			for line in node.text.split("\n"):
				var width:float=font.get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x
				check(width<=node.size.x+1,"label fits: "+line)
		var rect:Rect2=node.get_global_rect()
		check(rect.position.x>=0 and rect.position.y>=0 and rect.end.x<=1440 and rect.end.y<=900,"label remains inside viewport: "+node.text.left(24))
	if node is Button:
		var width:float=node.get_theme_font("font").get_string_size(node.text,HORIZONTAL_ALIGNMENT_LEFT,-1,node.get_theme_font_size("font_size")).x
		check(width<=node.size.x-30,"button text fits: "+node.text)
		check(node.focus_mode==Control.FOCUS_ALL,"button is keyboard focusable: "+node.text)
	for child in node.get_children():verify(child)
func run() -> void:
	var game:Node=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	for i in 3:
		game.select_route(i);await process_frame;verify(game.hud.root)
	game.start_ready();game.hud.update_game(game.rules,"READY",0,1,3,19,false);verify(game.hud.root)
	game.hud.help_panel.visible=true;verify(game.hud.help_panel);game.hud.help_panel.visible=false
	game.hud.pause_panel.visible=true;verify(game.hud.pause_panel);game.hud.pause_panel.visible=false
	game.rules.score=1234567;game.rules.destroyed=78;game.rules.explosions=17;game.rules.best_combo=78;game.rules.peak_speed=36
	game.hud.show_results(game.rules,2,true);verify(game.hud.results)
	game.queue_free();await process_frame;await process_frame
	print("UI: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
