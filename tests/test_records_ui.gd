extends SceneTree

const Fixtures = preload("res://tests/test_fixtures.gd")
var fixture = Fixtures.new("test_records_ui")
var checks:int=0
var failures:int=0
var game:Node3D
var retry_requests:int=0
var recover_requests:int=0
var layouts:Array[Dictionary]=[]
var observations:Array[Dictionary]=[]

func _initialize() -> void: call_deferred("run")
func check(value:bool,message:String) -> void:
	checks+=1
	if not value: failures+=1; printerr("FAIL: "+message)
func frame(count:int=2) -> void:
	for index in count: await process_frame
func key(code:int,pressed:bool,shift:bool=false) -> void:
	var event:=InputEventKey.new()
	event.keycode=code; event.physical_keycode=code; event.pressed=pressed; event.shift_pressed=shift
	Input.parse_input_event(event)
func tap(code:int,shift:bool=false) -> void:
	key(code,true,shift); await frame(1); key(code,false,shift); await frame(2)
func candidate(scores:Array,muted:bool=false) -> Dictionary:
	return {"version":2,"best_scores":scores,"legacy_scores":[0,0,0],"muted":muted,"hat":0}
func write_bytes(path:String,bytes:PackedByteArray) -> void:
	var file:=FileAccess.open(path,FileAccess.WRITE)
	check(file!=null,"fixture bytes open inside selected suite directory")
	if file!=null: file.store_buffer(bytes); file.close()
func fresh(data:Dictionary,raw:PackedByteArray=PackedByteArray(),backup:Dictionary={}) -> void:
	if is_instance_valid(game):
		game.queue_free(); await frame(3)
	for path in [fixture.records_path,fixture.records_path+".bak"]:
		if FileAccess.file_exists(path): check(DirAccess.remove_absolute(path)==OK,"previous selected fixture removed before cold ready")
	check(fixture.write_records(data),"known records fixture prepared before ready")
	if not raw.is_empty(): write_bytes(fixture.records_path,raw)
	if not backup.is_empty(): write_bytes(fixture.records_path+".bak",JSON.stringify(backup).to_utf8_buffer())
	game=fixture.create_game(root,fixture.EMPTY_RECORD,true)
	if game==null: return
	game.hud.retry_save_requested.connect(func(): retry_requests+=1)
	game.hud.recover_requested.connect(func(_use_backup:bool): recover_requests+=1)
	await frame(3)
func settle(score:int,route:int=0,fail:bool=false) -> void:
	if game.phase==game.Phase.RESULTS: game.retry()
	else: game._replace_route(route); game.start_ready()
	game.charge=.5; game.launch(); game.bail_out()
	for index in 180: await physics_frame
	check(game.phase==game.Phase.CRASH,"actual controller enters crash before arranged settlement candidate")
	game.rules.score=score
	if fail: game.records_store.inject_failure("replace")
	game.finish_run(); await frame(3)
func independently_read() -> Dictionary:
	var file:=FileAccess.open(fixture.records_path,FileAccess.READ)
	check(file!=null,"independent selected records reopen")
	if file==null: return {}
	var text:String=file.get_as_text(); file.close()
	var result:Variant=JSON.parse_string(text)
	check(result is Dictionary,"independent selected JSON parses")
	return result if result is Dictionary else {}
func observed(name:String) -> void:
	var facts:Dictionary=game.hud.records_presentation()
	observations.append({"case":name,"facts":facts,"title":game.hud.result_title.text,"improvement":game.hud.result_improvement.text,"note":game.hud.result_note.text,"last_secured":game.last_money_secured,"goal_crossed":game.last_goal_crossed,"retry_requests":retry_requests,"recover_requests":recover_requests})
func label_fit(control:Label) -> void:
	if not control.is_visible_in_tree() or control.text.is_empty(): return
	if control.clip_text and control.text_overrun_behavior==TextServer.OVERRUN_TRIM_ELLIPSIS:
		check(control.size.x>0,"long title has deliberate ellipsis bounds")
	elif control.autowrap_mode==TextServer.AUTOWRAP_OFF:
		for line in control.text.split("\n"):
			var width:float=control.get_theme_font("font").get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,control.get_theme_font_size("font_size")).x
			check(width<=control.size.x+1,"long label fits width: "+line)
	else:
		var count:int=control.get_line_count()
		var height:float=count*control.get_line_height()+maxi(0,count-1)*control.get_theme_constant("line_spacing")
		check(height<=control.size.y+1,"wrapped records copy fits height: "+control.text.left(32))
func inspect_layout(raw_size:Vector2i,state:String) -> void:
	root.size=raw_size
	await frame(3)
	var visible_buttons:Array[Button]=[]
	var rectangles:Array[Dictionary]=[]
	for control in game.hud.root.find_children("*","Control",true,false):
		if not control.is_visible_in_tree(): continue
		var rect:Rect2=control.get_global_rect()
		if control is Label: label_fit(control)
		if control is Button:
			if not game.hud.get_parent().hud_owner_allowed(control): continue
			visible_buttons.append(control)
			check(Rect2(0,0,1440,900).encloses(rect),"action inside logical letterboxed canvas: "+control.text)
			check(control.focus_mode==Control.FOCUS_ALL,"action keyboard focus remains available: "+control.text)
			rectangles.append({"text":control.text,"x":rect.position.x,"y":rect.position.y,"w":rect.size.x,"h":rect.size.y})
	for left in visible_buttons.size():
		for right in range(left+1,visible_buttons.size()):
			check(not visible_buttons[left].get_global_rect().intersects(visible_buttons[right].get_global_rect()),"visible actions do not overlap")
	layouts.append({"requested_window":[raw_size.x,raw_size.y],"retained_window":[root.size.x,root.size.y],"logical_visible_rect":str(root.get_visible_rect()),"canvas_transform":str(root.get_canvas_transform()),"state":state,"actions":rectangles,"evidence_scope":"headless retained raw viewport and control bounds; no native typography or high-DPI claim"})

func run() -> void:
	# Independent known 100000 -> 150000 boundary, with a genuine failed atomic
	# replacement. Physical scoring is covered by GAME/PLAYABILITY, not inferred here.
	await fresh(candidate([100000,0,0]))
	var original:PackedByteArray=FileAccess.get_file_as_bytes(fixture.records_path)
	await settle(150000,0,true)
	check(game.fund_total()==100000 and game.records_store.session_fund_total()==150000,"failed claim separates banked fund from known session maximum")
	check(game.last_claim_improvement==50000 and game.last_money_secured==0,"claim improvement is retained without inventing a secured event")
	check(game.hud.records_amount.text=="UNBANKED  +$50,000" and game.hud.result_note.text.contains("unbanked"),"persistent status and report expose the pending 50000")
	check(game.hud.result_fund.text.contains("$100,000") and not game.hud.result_title.text.contains("TREATMENT FUNDED"),"report shows durable fund and withholds funded ending")
	check(game.hud.retry_save_button.is_visible_in_tree(),"failed save has a persistent retry action")
	check(FileAccess.get_file_as_bytes(fixture.records_path)==original,"failed report preserves independent original bytes")
	observed("pending-50000")
	var callbacks:int=retry_requests
	game.start_replay(); await frame(20)
	check(game.phase==game.Phase.REPLAY and game.records_store.pending_save,"actual playback retains the pending candidate")
	check(game.hud.records_amount.text=="UNBANKED  +$50,000" and not game.hud.retry_save_button.is_visible_in_tree(),"replay keeps warning without an ineligible save action")
	check(retry_requests==callbacks and FileAccess.get_file_as_bytes(fixture.records_path)==original,"replay invokes no save callback or record write")
	for index in 120:
		if game.phase!=game.Phase.REPLAY: break
		await frame(1)
	check(game.phase==game.Phase.RESULTS,"actual replay returns to report without save callback")
	await settle(120000,0,true)
	check(game.best_scores[0]==150000 and game.fund_total()==100000 and game.hud.records_amount.text=="UNBANKED  +$50,000","weaker claim preserves prior pending maximum")
	game.hud.retry_save_button.grab_focus()
	await tap(KEY_TAB)
	check(root.gui_get_focus_owner().text=="RUN IT BACK","pending save joins explicit results primary-action focus order")
	await tap(KEY_TAB,true)
	check(root.gui_get_focus_owner()==game.hud.retry_save_button,"reverse Tab returns to pending-save action")
	await tap(KEY_H)
	check(game.hud.help_panel.visible,"actual H covers pending retry with HELP")
	await tap(KEY_TAB)
	check(game.hud.help_panel.is_ancestor_of(root.gui_get_focus_owner()),"actual Tab stays in HELP over recovery actions")
	await tap(KEY_ESCAPE)
	check(root.gui_get_focus_owner()==game.hud.retry_save_button,"HELP restores a valid pending-save control")
	await tap(KEY_ENTER)
	check(game.fund_total()==150000 and not game.records_store.pending_save and game.last_money_secured==50000,"actual Retry Save banks pending maximum exactly once")
	check(retry_requests==callbacks+1 and not game.hud.retry_save_button.is_visible_in_tree(),"successful retry removes its action and dispatches one request")
	observed("retry-acknowledged")
	var reopened:Dictionary=independently_read()
	check(int(reopened.best_scores[0])==150000,"independent JSON contains committed 150000")
	game.retry_records(); await frame(2)
	check(game.last_money_secured==0 and not game.last_goal_crossed and game.fund_total()==150000,"repeat ordinary retry emits no duplicate contribution")
	observed("retry-committed-once")

	await fresh(candidate([400000,0,0]))
	await settle(200000,1,true)
	check(game.fund_total()==400000 and game.records_store.session_fund_total()==600000,"session-only goal crossing remains unbanked")
	check(game.hud.result_title.text!="TREATMENT FUNDED" and not game.last_goal_crossed,"failed goal cannot unlock secured story ending")
	game.hud.retry_save_button.grab_focus(); await tap(KEY_ENTER)
	check(game.fund_total()==600000 and game.last_goal_crossed and game.hud.result_title.text=="TREATMENT FUNDED","successful UI retry shows committed ending")
	observed("goal-acknowledged")
	game.retry_records(); await frame(2)
	check(not game.last_goal_crossed and game.last_money_secured==0,"repeat retry cannot repeat ending event")
	observed("goal-committed-once")

	await fresh(candidate([400000,0,0]))
	await settle(200000,1,true)
	await tap(KEY_M)
	check(game.fund_total()==600000 and game.last_money_secured==200000 and game.last_goal_crossed,"actual preference commit acknowledges pending goal contribution")
	check(game.hud.result_title.text=="TREATMENT FUNDED" and game.hud.result_fund.text.contains("$600,000"),"preference commit refreshes the acknowledged RESULTS ending and banked amount")
	check(not game.hud.result_note.text.contains("unbanked") and not game.hud.retry_save_button.is_visible_in_tree(),"preference commit removes stale pending result copy and action")
	reopened=independently_read()
	check(int(reopened.best_scores[0])==400000 and int(reopened.best_scores[1])==200000 and bool(reopened.muted),"independent preference commit contains funded claims and current mute")
	observed("pending-result-continued-by-preference")
	await tap(KEY_M)
	check(game.last_money_secured==0 and not game.last_goal_crossed,"second preference commit emits no repeated funded event")

	var future:PackedByteArray='{"version":99,"best_scores":[9,8,7],"unknown":{"keep":"exact"}}\n'.to_utf8_buffer()
	await fresh(candidate([0,0,0]),future)
	await tap(KEY_M)
	check(game.muted and game.records_store.pending_save,"protected profile preference applies in session")
	check(game.hud.records_title.text=="NEWER SAVE PROTECTED" and not game.hud.retry_save_button.visible and not game.hud.restore_backup_button.visible and not game.hud.fresh_records_button.visible,"future version offers no overwrite action")
	await tap(KEY_H); await tap(KEY_ESCAPE)
	check(FileAccess.get_file_as_bytes(fixture.records_path)==future,"ordinary future-profile UI navigation preserves exact unknown bytes")
	game.retry_records(); game.recover_records(false); game.recover_records(true)
	check(FileAccess.get_file_as_bytes(fixture.records_path)==future,"all guarded records APIs preserve future bytes")
	observed("future-protected")

	var damaged:PackedByteArray="damaged original / preserve me\n".to_utf8_buffer()
	await fresh(candidate([0,0,0]),damaged,candidate([100000,0,0]))
	check(game.hud.restore_backup_button.is_visible_in_tree() and not game.hud.fresh_records_button.visible,"corrupt backup recovery requires the explicit backup choice")
	check(game.fund_total()==0 and root.gui_get_focus_owner()==game.hud.restore_backup_button,"protected cold startup focuses recovery and invents no banked backup")
	await tap(KEY_TAB)
	check(root.gui_get_focus_owner()==game.hud.route_buttons[0],"recovery joins explicit ordinary menu focus order")
	await tap(KEY_TAB,true)
	check(root.gui_get_focus_owner()==game.hud.restore_backup_button,"reverse Tab restores the explicit recovery choice")
	await tap(KEY_H); await tap(KEY_ESCAPE)
	check(root.gui_get_focus_owner()==game.hud.restore_backup_button,"HELP returns to explicit backup recovery focus")
	var recover_before:int=recover_requests
	game.records_store.inject_failure("temp_open")
	await tap(KEY_ENTER)
	check(game.records_store.recovery_pending() and game.fund_total()==0,"chosen backup remains unbanked when recovery write fails")
	check(game.hud.records_title.text=="BACKUP RECOVERY / SAVE PENDING" and game.hud.retry_save_button.is_visible_in_tree() and not game.hud.restore_backup_button.visible,"failed chosen backup exposes persistent Retry Save rather than another recovery choice")
	check(root.gui_get_focus_owner()==game.hud.retry_save_button,"pending recovery keeps focus on its safe retry action")
	check(FileAccess.get_file_as_bytes(game.records_store.quarantine_path)==damaged,"failed backup commit still independently preserves exact original")
	observed("backup-recovery-pending")
	await tap(KEY_ENTER)
	check(recover_requests==recover_before+1 and game.fund_total()==100000,"actual Restore Backup dispatches and commits validated backup")
	check(FileAccess.get_file_as_bytes(game.records_store.quarantine_path)==damaged,"backup recovery independently preserves exact damaged original")
	check(game.hud.records_title.text=="BACKUP RESTORED / SAVED" and not game.hud.restore_backup_button.visible,"persistent recovery status acknowledges saved backup")
	check(root.gui_get_focus_owner()!=null and root.gui_get_focus_owner().is_visible_in_tree(),"recovery completion restores valid ordinary focus")
	reopened=independently_read(); check(int(reopened.best_scores[0])==100000,"independent restored JSON matches known backup")
	observed("backup-recovered")

	await fresh(candidate([0,0,0]),damaged)
	check(game.hud.fresh_records_button.is_visible_in_tree() and not game.hud.restore_backup_button.visible,"no backup exposes explicit fresh-save recovery")
	check(root.gui_get_focus_owner()==game.hud.fresh_records_button and game.fund_total()==0,"fresh recovery starts session-only with focused choice")
	await tap(KEY_M)
	game.records_store.inject_failure("readback")
	await tap(KEY_ENTER)
	check(game.records_store.recovery_pending() and game.hud.records_title.text=="FRESH RECOVERY / SAVE PENDING","uncertain fresh readback stays visibly pending")
	check(game.hud.retry_save_button.is_visible_in_tree() and root.gui_get_focus_owner()==game.hud.retry_save_button,"fresh readback retry uses explicit focused save action")
	observed("fresh-recovery-pending")
	await tap(KEY_ENTER)
	check(game.hud.records_title.text=="FRESH SAVE / SAVED" and not game.records_store.pending_save,"explicit fresh choice commits active session preferences")
	check(FileAccess.get_file_as_bytes(game.records_store.quarantine_path)==damaged,"fresh recovery independently preserves original bytes")
	reopened=independently_read(); check(bool(reopened.muted),"independent fresh JSON preserves session preference")
	observed("fresh-recovered")

	# A recovery continuation may originate from an ordinary UI action, not just
	# Retry Save. Restored 600000 is already-funded baseline, never new earnings.
	await fresh(candidate([0,0,0]),damaged,candidate([600000,0,0]))
	game.records_store.inject_failure("temp_open")
	await tap(KEY_ENTER)
	check(game.records_store.recovery_pending() and game.fund_total()==0,"already-funded selected backup remains pending after pre-write failure")
	await tap(KEY_M)
	check(game.fund_total()==600000 and game.muted and not game.records_store.pending_save,"actual M commits the selected recovery and current preference")
	check(game.last_money_secured==0 and not game.last_goal_crossed,"ordinary preference recovery acknowledges no restored-money contribution or new ending")
	reopened=independently_read()
	check(int(reopened.best_scores[0])==600000 and bool(reopened.muted),"independent preference continuation contains already-funded backup and active mute")
	check(FileAccess.get_file_as_bytes(game.records_store.quarantine_path)==damaged,"ordinary preference continuation preserves rejected bytes")
	observed("backup-continued-by-preference")

	await fresh(candidate([0,0,0]),damaged,candidate([600000,0,0]))
	game.records_store.inject_failure("temp_open")
	await tap(KEY_ENTER)
	check(game.records_store.recovery_pending(),"new claim begins from a pending already-funded recovery")
	await settle(42,1)
	check(game.fund_total()==600042 and game.last_money_secured==42 and not game.last_goal_crossed,"actual claim continuation credits only new 42 above restored funded baseline")
	check(game.hud.result_title.text!="TREATMENT FUNDED" and game.hud.result_note.text.contains("Treatment starts tomorrow"),"restored funded campaign remains available without replaying new-funded ending")
	reopened=independently_read()
	check(int(reopened.best_scores[0])==600000 and int(reopened.best_scores[1])==42,"independent new-claim continuation contains exact backed-up and earned values")
	game.retry_records()
	check(game.last_money_secured==0 and not game.last_goal_crossed and game.fund_total()==600042,"repeated recovered-claim retry emits no duplicate event")
	check(FileAccess.get_file_as_bytes(game.records_store.quarantine_path)==damaged,"new-claim continuation preserves original damaged bytes")
	observed("backup-continued-by-new-claim")

	# Retained raw viewport cases validate the actual layout tree under project
	# canvas_items/keep. macOS glyph rendering and high-DPI remain R14 acceptance.
	await fresh(candidate([999999999,999999999,999999999]))
	var sizes:Array[Vector2i]=[Vector2i(960,600),Vector2i(1280,800),Vector2i(1440,900),Vector2i(1024,768),Vector2i(1920,1080)]
	game.hud.route_title.text="A VERY LONG ROUTE TITLE WITH SEVERAL EXTRA WORDS THAT REQUIRE DELIBERATE ELLIPSIS"
	for size in sizes: await inspect_layout(size,"MENU")
	game.start_ready(); game.hud.update_game(game.rules,"READY",0,0,1,19,false)
	for size in sizes: await inspect_layout(size,"READY")
	game.charge=.5; game.launch(); game.bail_out(); await frame(2)
	game.rules.score=999999999; game.rules.property_damage=999999999; game.rules.rider_damage=999999999
	for limb in WreckHUD.LIMB_NAMES: game.rules.limb_damage[limb]=100.0; game.rules.limb_payout[limb]=999999999
	game.hud.update_game(game.rules,"CRASH",20,0,1,19,false)
	game.hud.claim_event("EXTREMELY LONG RIGHT UPPER ARM RECEIPT / ROTATED TRAFFIC CASCADE AND MANY EXTRA WORDS",999999999,true)
	check(game.hud.claim_lines[0].text.contains("…") and game.hud.claim_lines[0].text.ends_with("+$999,999,999"),"long receipt deliberately abbreviates name while preserving full amount")
	for size in sizes: await inspect_layout(size,"CRASH")
	game.finish_run(); await frame(70)
	game.hud.result_title.text="AN EXTREMELY LONG CLAIM TITLE THAT REQUIRES DELIBERATE ELLIPSIS IN ITS ALLOTTED SPACE"
	for size in sizes: await inspect_layout(size,"RESULTS")
	game.toggle_help(); await frame(2)
	for size in sizes: await inspect_layout(size,"HELP")
	game.close_help(); game.retry(); game.toggle_pause(); await frame(2)
	for size in sizes: await inspect_layout(size,"PAUSE")
	var artifact:=FileAccess.open(fixture.artifact_path("records_ui_report.json"),FileAccess.WRITE)
	check(artifact!=null,"records UI evidence report opens inside suite fixture")
	if artifact!=null: artifact.store_string(JSON.stringify({"observations":observations,"layouts":layouts,"checks":checks,"failures":failures},"\t")); artifact.close()
	paused=false
	game.queue_free(); await frame(3)
	print("RECORDS_UI: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
