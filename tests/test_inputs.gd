extends SceneTree

var checks: int = 0
var failures: int = 0
var game: Node3D
const RECORD_PATH: String = "res://builds/input_test_records.json"

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: ",message)

func dispatch(code: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await process_frame
	await process_frame

func tap(code: int) -> void:
	await dispatch(code,true)
	await dispatch(code,false)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.test_mode = true
	game.save_path = RECORD_PATH
	game.best_scores.assign([0,0,0])
	game.legacy_scores.assign([0,0,0])
	game.select_route(0)
	game.start_ready()
	await process_frame
	await process_frame
	var pose_button: Button = game.hud.pose_buttons[1]
	check(pose_button.is_visible_in_tree(),"pose selector is visible before focused-input regression")
	pose_button.grab_focus()
	check(root.get_viewport().gui_get_focus_owner() == pose_button,"actual Godot GUI gives pose button keyboard focus")
	for choice in range(3):
		await tap(KEY_1+choice)
		check(game.pose_index == choice and game.skater.pose_index == choice,"actual keyboard dispatch selects pose "+str(choice+1))
	await tap(KEY_1)
	pose_button.grab_focus()
	var selected_pose: int = game.pose_index
	await dispatch(KEY_SPACE,true)
	check(game.phase == game.Phase.READY and game.charging,"Space reaches launch charging through a focused pose button")
	for frame in range(12): await physics_frame
	check(game.charge > 0,"focused Space hold accumulates launch charge")
	await dispatch(KEY_SPACE,false)
	check(game.phase == game.Phase.RUN and not game.charging,"focused Space release launches through the real event dispatcher")
	check(game.pose_index == selected_pose,"Space does not activate focused pose button while launching")
	await tap(KEY_SPACE)
	check(game.phase == game.Phase.CRASH and game.skater.ragdoll,"actual Space input bails from riding")
	root.get_viewport().gui_release_focus()
	await tap(KEY_ENTER)
	check(game.phase == game.Phase.RESULTS,"actual Enter input files a crash claim")
	var all_frozen: bool = true
	for limb in game.skater.limbs: all_frozen = all_frozen and limb.freeze
	for prop in game.world.props:
		if is_instance_valid(prop): all_frozen = all_frozen and prop.freeze
	check(all_frozen,"filing a claim freezes physical rider and property actors")
	await tap(KEY_R)
	check(game.phase == game.Phase.READY and not game.skater.ragdoll,"actual R dispatch immediately resets the run")
	await process_frame
	game.hud.pose_buttons[0].grab_focus()
	await tap(KEY_ESCAPE)
	check(game.is_paused,"actual Escape dispatch pauses")
	await tap(KEY_SPACE)
	check(game.phase == game.Phase.READY and not game.charging and not game.skater.ragdoll,"Space cannot charge or launch while paused")
	root.get_viewport().gui_release_focus()
	await tap(KEY_ESCAPE)
	check(not game.is_paused,"actual Escape dispatch resumes")
	await tap(KEY_H)
	check(game.hud.help_panel.visible,"actual H dispatch opens crash help")
	await tap(KEY_SPACE)
	check(game.phase == game.Phase.READY and not game.charging,"Space cannot charge or launch while help is visible")
	root.get_viewport().gui_release_focus()
	await tap(KEY_ESCAPE)
	check(not game.hud.help_panel.visible and not game.is_paused,"Escape closes help and resumes the prior run")
	await process_frame
	game.hud.pose_buttons[0].grab_focus()
	var previous_hat: int = game.selected_hat
	await tap(KEY_F)
	check(game.selected_hat == (previous_hat+1)%3 and game.skater.hat_index == game.selected_hat,"actual F dispatch cycles the worn hat through a focused pose control")
	check(game.skater.visuals.head.get_node_or_null("CrashHat") != null,"selected hat is physically attached to the visible rider model")
	var saved_hat: int = game.selected_hat
	var seen_hats: Dictionary = {saved_hat:true}
	for cycle in range(3):
		await tap(KEY_F)
		seen_hats[game.selected_hat] = true
		check(game.skater.hat_index == game.selected_hat and game.skater.visuals.head.get_node_or_null("CrashHat") != null,"actual F dispatch replaces the worn model through hat cycle "+str(cycle))
	check(seen_hats.size() == 3 and game.selected_hat == saved_hat,"actual F dispatch cycles all three hats and wraps to the starting selection")
	game.selected_hat = (saved_hat+1)%3
	game.load_records()
	check(game.selected_hat == saved_hat,"actual F selection was persisted without a separate manual save")
	game.select_route(1)
	check(game.skater.hat_index == saved_hat and game.skater.visuals.head.get_node_or_null("CrashHat") != null,"route recreation retains the selected worn hat")
	var fixture := FileAccess.open(RECORD_PATH,FileAccess.WRITE)
	fixture.store_string(JSON.stringify({"version":1,"best_scores":[700000,800000,900000],"muted":true}))
	fixture.close()
	game.load_records()
	check(game.best_scores == [0,0,0] and game.fund_total() == 0,"version-one arcade scores above the treatment goal cannot fund the new campaign")
	check(game.legacy_scores == [700000,800000,900000],"migration preserves historical arcade records separately")
	check(game.muted,"legacy sound preference survives migration")
	game.best_scores.assign([120000,180000,220000])
	game.selected_hat = saved_hat
	game.save_records()
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(RECORD_PATH))
	check(int(saved.version) == 2 and saved.legacy_scores.size() == 3 and int(saved.legacy_scores[0]) == 700000 and int(saved.legacy_scores[1]) == 800000 and int(saved.legacy_scores[2]) == 900000,"version-two save retains migrated legacy records")
	game.best_scores.assign([0,0,0])
	game.legacy_scores.assign([0,0,0])
	game.selected_hat = 0
	game.muted = false
	game.load_records()
	check(game.best_scores == [120000,180000,220000] and game.fund_total() == 520000,"version-two treatment claims round trip independently")
	check(game.legacy_scores == [700000,800000,900000] and game.selected_hat == saved_hat and game.muted,"legacy records, worn hat and sound preference round trip together")
	game.select_route(2)
	check(game.skater.hat_index == saved_hat,"loaded hat preference is applied to a new route rider")
	var reopened: Node3D = load("res://scenes/main.tscn").instantiate()
	root.add_child(reopened)
	reopened.test_mode = true
	reopened.save_path = RECORD_PATH
	reopened.load_records()
	reopened.select_route(0)
	check(reopened.fund_total() == 520000 and reopened.legacy_scores == [700000,800000,900000],"fresh game instance reloads treatment and historical records independently")
	check(reopened.selected_hat == saved_hat and reopened.skater.hat_index == saved_hat and reopened.skater.visuals.head.get_node_or_null("CrashHat") != null,"fresh game instance reloads and wears the persisted hat")
	reopened.queue_free()
	await process_frame
	await process_frame
	game.unpause()
	game.queue_free()
	await process_frame
	await process_frame
	game = null
	print("INPUTS: ",checks," checks, ",failures," failures; real Input.parse_input_event dispatch")
	quit(1 if failures else 0)
