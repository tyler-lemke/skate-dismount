extends SceneTree
var failures:int=0
var checks:int=0
func _initialize() -> void:call_deferred("run")
func check(condition:bool,message:String) -> void:
	checks+=1
	if not condition:failures+=1;printerr("FAIL: ",message)
func click(at:Vector2) -> void:
	var press:=InputEventMouseButton.new()
	press.button_index=MOUSE_BUTTON_LEFT
	press.position=at
	press.global_position=at
	press.pressed=true
	root.push_input(press,true)
	var release:InputEventMouseButton=press.duplicate()
	release.pressed=false
	root.push_input(release,true)
func verify(node:Node) -> void:
	if node is Control and not node.is_visible_in_tree():return
	if node is Label and node.text!="":
		var font:Font=node.get_theme_font("font")
		var size:int=node.get_theme_font_size("font_size")
		if node.autowrap_mode==TextServer.AUTOWRAP_OFF:
			for line in node.text.split("\n"):
				var width:float=font.get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x
				check(width<=node.size.x+1,"label fits: "+line)
		else:
			var lines:int=node.get_line_count()
			var line_spacing:int=node.get_theme_constant("line_spacing")
			var height:float=lines*node.get_line_height()+maxi(0,lines-1)*line_spacing
			check(lines>0 and height<=node.size.y+1,"wrapped label fits height: "+node.text.left(36))
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
	game.hud.help_panel.visible=true
	await process_frame
	click(Vector2(100,710))
	await process_frame
	check(game.phase==game.Phase.MENU and game.hud.help_panel.visible,"help backdrop blocks the underlying File a Claim button")
	click(Vector2(500,710))
	await process_frame
	check(not game.hud.help_panel.visible and game.phase==game.Phase.MENU,"help close button remains clickable over its backdrop")
	click(Vector2(100,710))
	await process_frame
	check(game.phase==game.Phase.READY,"File a Claim button receives the same click after help closes")
	game.toggle_pause()
	await process_frame
	click(Vector2(1380,150))
	await process_frame
	check(game.is_paused and game.hud.pause_panel.visible,"pause backdrop blocks the underlying HUD pause button")
	click(Vector2(600,337))
	await process_frame
	check(not game.is_paused and not game.hud.pause_panel.visible,"pause resume button remains clickable over its backdrop")
	click(Vector2(1380,150))
	await process_frame
	check(game.is_paused and game.hud.pause_panel.visible,"HUD pause button receives the same click after pause closes")
	click(Vector2(600,337))
	await process_frame
	check(not game.is_paused and not game.hud.pause_panel.visible,"resume button restores gameplay after HUD pause")
	for i in WreckRules.POSES.size():
		game.set_pose(i)
		game.hud.update_game(game.rules,"READY",0,1,1,19,false)
		await process_frame
		check(game.hud.pose_note.text==WreckRules.POSES[i].tip,"ready pose description matches selected pose "+str(i))
		check(game.hud.pose_note.get_line_count()>=2,"ready pose description wraps for pose "+str(i))
		check(game.hud.boost_label.text=="CRASHBREAKER / READY" and not game.hud.boost_label.text.contains("●"),"ready HUD shows exactly one available crashbreaker")
		verify(game.hud.root)
	for limb in WreckRules.LIMB_WEIGHTS:
		game.rules.limb_damage[limb]=100.0
		game.rules.limb_payout[limb]=99999
	await process_frame
	game.hud.update_game(game.rules,"CRASH",26,0,1,11,false)
	check(game.hud.injury_panel.visible,"injury file is visible during a crash")
	check(not game.hud.injury_details.visible and game.hud.injury_panel.size.y==230,"live crash shows a compact anatomy and diagnosis without the row ledger")
	check(game.hud.live_chrome.visible and game.hud.score_label.is_visible_in_tree(),"crash keeps the primary payout visible")
	check(game.hud.anatomy_parts.size()==11,"all eleven body regions have a diagram shape")
	var compact_rect:Rect2=game.hud.injury_panel.get_global_rect()
	for limb in WreckHUD.LIMB_NAMES:
		var part:Control=game.hud.anatomy_parts[limb]
		check(part.is_visible_in_tree() and compact_rect.encloses(part.get_global_rect()),"compact anatomy keeps visible region "+limb)
	check(not game.hud.limb_labels["head"].is_visible_in_tree(),"live crash hides detailed injury rows")
	var breaker_rect:=Rect2(Vector2(1070,727),Vector2(344,145))
	check(breaker_rect.encloses(game.hud.aim_label.get_global_rect()),"aim instruction sits inside the single crashbreaker card")
	for i in range(WreckHUD.LIMB_NAMES.size()-1):
		var bar: ProgressBar=game.hud.limb_bars[WreckHUD.LIMB_NAMES[i]]
		var next_bar: ProgressBar=game.hud.limb_bars[WreckHUD.LIMB_NAMES[i+1]]
		check(bar.get_global_rect().end.y<next_bar.global_position.y,"adjacent severity bars do not overlap")
	for limb in WreckRules.LIMB_WEIGHTS:
		check(game.hud.anatomy_stage[limb]=="FRACTURED","diagram shows maximum severity for "+limb)
	check(game.hud.anatomy_region_label.text=="HEAD" and game.hud.anatomy_payout_label.text=="CLAIM  $99,999","worst-region summary shows the filed limb amount")
	game.hud.claim_event("Right upper arm / STEP",999999,true)
	check(game.hud.claim_panel.visible and game.hud.claim_lines[0].text.contains("RIGHT UPPER ARM / STEP"),"long injury receipt is visible")
	check(game.hud.claim_lines.size()==1 and game.hud.claim_panel.position.x>=900,"one concise receipt stays on the right edge")
	verify(game.hud.root)
	game.hud.claim_event("CAR B → CAR C",9000)
	game.hud.claim_event("Left shin / STEP",650,true)
	check(game.hud.claim_lines[0].text.contains("CAR B → CAR C"),"a fresh vehicle handoff remains legible during rapid injury receipts")
	verify(game.hud.claim_panel)
	game.hud.update_game(game.rules,"CRASH",26,0,0,11,false)
	check(game.hud.boost_label.text=="CRASHBREAKER / SPENT" and game.hud.aim_label.text.contains("CHARGE SPENT"),"spent crashbreaker cannot look ready or recharging")
	game.replay_sample={"limbs":{"shin_r":45.0}}
	game.hud.update_game(game.rules,"REPLAY",26,0,0,11,false)
	check(game.hud.injury_panel.visible,"injury file remains visible in replay")
	check(not game.hud.injury_details.visible and game.hud.injury_panel.size.y==230,"replay retains the compact injury display")
	check(game.hud.hint_label.text=="R retry / C camera\nESC pause" and game.hud.timer_label.text=="REPLAY / ESC PAUSE","replay hints name only available navigation")
	check(game.hud.boost_label.text=="CRASHBREAKER / RECORDED" and game.hud.aim_label.text.contains("NO NEW PAYOUT"),"replay does not offer a live boost or claim")
	for limb in WreckRules.LIMB_WEIGHTS:
		check(game.hud.anatomy_stage[limb]==("STRAINED" if limb=="shin_r" else "OK"),"replay diagram follows snapshot for "+limb)
	check(game.hud.anatomy_region_label.text=="RIGHT SHIN" and game.hud.anatomy_payout_label.text=="REPLAY SNAPSHOT","replay summary shows current injury without future payout")
	verify(game.hud.root)
	game.hud.help_panel.visible=true;verify(game.hud.help_panel);game.hud.help_panel.visible=false
	game.hud.pause_panel.visible=true;verify(game.hud.pause_panel);game.hud.pause_panel.visible=false
	game.rules.score=1234567;game.rules.destroyed=78;game.rules.explosions=17;game.rules.best_combo=78;game.rules.peak_speed=36
	game.phase=game.Phase.RESULTS
	game.hud.show_results(game.rules,2,true)
	game.hud.update_game(game.rules,"RESULTS",0,0,0,0,false)
	check(game.hud.combo_label.text=="CLAIM SETTLED" and game.hud.timer_label.text=="C CAMERA / ESC ROUTES","settled claim shows result navigation")
	check(game.hud.aim_label.text=="CLAIM SETTLED\nV REPLAY / R RETRY" and game.hud.boost_label.text=="CLAIM SETTLED","settled claim does not offer a charge")
	check(game.hud.hint_label.text=="R retry / V replay\nESC route select","settled claim has actionable hints")
	check(game.hud.anatomy_stage["head"]=="FRACTURED" and game.hud.anatomy_payout_label.text=="CLAIM  $99,999","results restore the completed injury file")
	check(game.hud.injury_details.visible and game.hud.injury_panel.size.y==472 and game.hud.limb_labels["shin_r"].is_visible_in_tree(),"result report expands all eleven injury entries")
	var full_rect:Rect2=game.hud.injury_panel.get_global_rect()
	for limb in WreckHUD.LIMB_NAMES:
		check(game.hud.limb_labels[limb].is_visible_in_tree() and full_rect.encloses(game.hud.limb_labels[limb].get_global_rect()),"results contain the complete injury ledger row for "+limb)
	check(not game.hud.live_chrome.visible and not game.hud.score_label.is_visible_in_tree() and game.hud.result_score.is_visible_in_tree(),"results show one payout and hide live controls")
	verify(game.hud.root)
	for i in 90: await process_frame
	check(not game.hud.result_reveal_active and game.hud.result_score.text=="$1,234,567","settled payout reveal reaches the exact formatted total")
	game.queue_free();await process_frame;await process_frame
	print("UI: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
