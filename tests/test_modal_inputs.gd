extends SceneTree

const Fixtures = preload("res://tests/test_fixtures.gd")
var fixtures = Fixtures.new("test_modal_inputs")
var game: Node3D
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: ",message)

func key(code: int, down: bool, backwards: bool = false, echo: bool = false) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = down
	event.shift_pressed = backwards
	event.echo = echo
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await process_frame
	await process_frame

func tap(code: int, backwards: bool = false) -> void:
	await key(code,true,backwards)
	await key(code,false,backwards)

func click(button: Button) -> void:
	var point: Vector2 = button.get_global_rect().get_center()
	for down in [true,false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = point
		event.global_position = point
		event.pressed = down
		root.push_input(event,true)
		await process_frame
	await process_frame

func named(parent: Node, title: String) -> Button:
	for node in parent.find_children("*","Button",true,false):
		if node.text == title: return node
	return null

func fresh(target: int) -> void:
	game.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	game._replace_route(0)
	if target != game.Phase.MENU: game.start_ready()
	if target in [game.Phase.RUN,game.Phase.CRASH,game.Phase.RESULTS,game.Phase.REPLAY]:
		game.charge = .35
		game.launch()
	if target in [game.Phase.CRASH,game.Phase.RESULTS,game.Phase.REPLAY]:
		game.bail_out()
	if target in [game.Phase.RESULTS,game.Phase.REPLAY]:
		for frame in 18: await physics_frame
		game.finish_run()
	if target == game.Phase.REPLAY: game.start_replay()
	await process_frame
	check(game.phase == target,"fixture enters its specified phase through valid phase methods")

func state() -> Array:
	return [game.phase,game.pose_index,game.selected_hat,game.boosts,game.fund_total(),game.rules.score,game.run_serial]

func modal(kind: int, paused_state: bool, message: String) -> void:
	check(game.modal_kind == kind and game.effective_modal() == kind,message+" has one authoritative modal")
	check(game.hud.help_panel.visible == (kind == game.Modal.HELP) and game.hud.pause_panel.visible == (kind == game.Modal.PAUSE),message+" shows only its owning panel")
	check(game.is_paused == paused_state and paused == paused_state,message+" agrees with game and SceneTree suspension")

func cycle_focus(help: bool) -> void:
	var panel: Control = game.hud.help_panel if help else game.hud.pause_panel
	var controls: Array[Button] = game.hud.modal_buttons(help)
	var first: Control = root.gui_get_focus_owner()
	check(not controls.is_empty() and panel.is_ancestor_of(first),"modal entry owns a visible enabled button")
	for backwards in [false,true]:
		for step in controls.size()*2:
			await tap(KEY_TAB,backwards)
			var owner: Control = root.gui_get_focus_owner()
			check(owner != null and panel.is_ancestor_of(owner) and controls.has(owner),"Tab navigation stays inside the visible modal")
		check(root.gui_get_focus_owner() == first,"two complete modal Tab cycles return to the same owner")

func underlying_controls() -> void:
	await fresh(game.Phase.MENU)
	var play: Button = named(game.hud.menu,"FILE A CLAIM     →")
	play.grab_focus()
	var before: Array = state()
	await tap(KEY_H)
	modal(game.Modal.HELP,false,"MENU help")
	check(root.gui_get_focus_owner() != play,"opening help transfers focus away from underlying Play")
	await cycle_focus(true)
	play.grab_focus()
	check(game.hud.help_panel.is_ancestor_of(root.gui_get_focus_owner()),"an underlying grab_focus cannot escape the modal trap")
	await tap(KEY_ENTER)
	check(state() == before,"Enter under MENU help closes help without activating underlying Play")
	modal(game.Modal.NONE,false,"MENU help close")
	check(root.gui_get_focus_owner() == play,"closing help restores a still-visible prior focus")
	await click(named(game.hud.menu,"HOW TO WRECK"))
	modal(game.Modal.HELP,false,"real HOW TO WRECK button")
	await click(named(game.hud.help_panel,"LET'S FILE IT  →"))
	check(game.phase == game.Phase.MENU,"real help button close preserves MENU")

	await fresh(game.Phase.READY)
	game.set_pose(0)
	game.hud.pose_buttons[2].grab_focus()
	before = state()
	await tap(KEY_H)
	modal(game.Modal.HELP,true,"READY help")
	await tap(KEY_ENTER)
	check(state() == before,"Enter under READY help cannot select the underlying third pose")
	game.hud.pose_buttons[2].grab_focus()
	await tap(KEY_ESCAPE)
	modal(game.Modal.PAUSE,true,"READY pause")
	await cycle_focus(false)
	game.hud.pose_buttons[2].grab_focus()
	check(game.hud.pause_panel.is_ancestor_of(root.gui_get_focus_owner()),"pause rejects an underlying pose focus request")
	await tap(KEY_ENTER)
	check(state() == before,"Enter on the pause owner resumes without selecting the underlying pose")
	modal(game.Modal.NONE,false,"READY resume")

func direct_guards() -> void:
	for phase in [game.Phase.MENU,game.Phase.READY,game.Phase.RUN,game.Phase.CRASH,game.Phase.RESULTS,game.Phase.REPLAY]:
		await fresh(phase)
		await tap(KEY_H)
		var before: Array = state()
		game.start_ready(); game.set_pose(2); game.select_route(2)
		game.launch(); game.bail_out(); game.crashbreaker(); game.finish_run()
		game.start_replay(); game.retry(); game.next_route(); game.back_to_menu(); game.unpause(); game.resume()
		check(state() == before,"public phase methods cannot bypass HELP eligibility in phase "+str(phase))
		modal(game.Modal.HELP,phase in [game.Phase.READY,game.Phase.RUN,game.Phase.CRASH,game.Phase.REPLAY],"guarded HELP phase "+str(phase))
		await tap(KEY_H)
		check(game.phase == phase,"closing HELP restores its original phase "+str(phase))

func ordinary_gui_navigation() -> void:
	await fresh(game.Phase.MENU)
	var play: Button = named(game.hud.menu,"FILE A CLAIM     →")
	play.grab_focus()
	await tap(KEY_TAB)
	check(root.gui_get_focus_owner() != play and game.hud.menu.is_ancestor_of(root.gui_get_focus_owner()),"ordinary MENU Tab retains accessible GUI navigation")
	await tap(KEY_TAB,true)
	check(root.gui_get_focus_owner() == play,"ordinary MENU Shift-Tab returns to the previous owner")
	await tap(KEY_ENTER)
	check(game.phase == game.Phase.READY,"ordinary MENU Enter activates the focused Play control")
	await fresh(game.Phase.RESULTS)
	var replay: Button = named(game.hud.results,"WATCH REPLAY")
	replay.grab_focus()
	await tap(KEY_TAB)
	check(game.hud.results.is_ancestor_of(root.gui_get_focus_owner()),"ordinary RESULTS Tab stays in available result controls")
	replay.grab_focus()
	var bank: int = game.fund_total()
	await key(KEY_ENTER,true)
	await key(KEY_ENTER,false)
	check(game.phase == game.Phase.REPLAY and game.fund_total() == bank,"ordinary RESULTS Enter starts the focused replay without adding funding; phase=%d frames=%d clock=%.4f" % [game.phase,game.replay_frames.size(),game.replay_clock])

func pause_actions() -> void:
	for title in ["KEEP WRECKING","RESTART RUN","ROUTE SELECT","TOGGLE SOUND"]:
		await fresh(game.Phase.READY)
		await tap(KEY_ESCAPE)
		var original_mute: bool = game.muted
		var bank: int = game.fund_total()
		named(game.hud.pause_panel,title).grab_focus()
		await tap(KEY_ENTER)
		if title == "TOGGLE SOUND":
			modal(game.Modal.PAUSE,true,"pause mute action")
			check(game.muted != original_mute and game.phase == game.Phase.READY,"Enter on pause SOUND changes only its preference")
			await tap(KEY_ESCAPE)
		elif title == "ROUTE SELECT":
			modal(game.Modal.NONE,false,"pause route-select action")
			check(game.phase == game.Phase.MENU,"Enter on pause ROUTE SELECT returns to MENU")
		else:
			modal(game.Modal.NONE,false,"pause resume/restart action")
			check(game.phase == game.Phase.READY,"Enter on pause resume/restart produces READY")
		check(game.fund_total() == bank,"visible pause actions cannot bank a new claim")
	await fresh(game.Phase.RUN)
	await tap(KEY_ESCAPE)
	await tap(KEY_H)
	modal(game.Modal.HELP,true,"HELP nested over existing PAUSE")
	await tap(KEY_H)
	modal(game.Modal.PAUSE,true,"HELP returns to existing PAUSE")
	await tap(KEY_ESCAPE)
	modal(game.Modal.NONE,false,"explicit Resume after nested HELP")

func live_slow_and_mute() -> void:
	for phase in [game.Phase.RUN,game.Phase.CRASH]:
		await fresh(phase)
		var buttons: Array = game.hud.live_chrome.find_children("*","Button",true,false)
		buttons.append(null)
		for button in buttons:
			if button == null: root.gui_release_focus()
			else: button.grab_focus()
			game.impact_left = 0.0
			await key(KEY_TAB,true)
			check(game.slow_motion and is_equal_approx(game.time_rate,.25),"held Tab engages before every live GUI focus owner")
			await key(KEY_TAB,false)
			check(not game.slow_motion and is_equal_approx(game.time_rate,.55 if phase == game.Phase.CRASH else 1.0),"Tab release restores the phase base rate promptly")
	for phase in [game.Phase.READY,game.Phase.RUN,game.Phase.CRASH]:
		for mode in [game.Modal.NONE,game.Modal.PAUSE,game.Modal.HELP]:
			await fresh(phase)
			if mode == game.Modal.PAUSE: await tap(KEY_ESCAPE)
			elif mode == game.Modal.HELP: await tap(KEY_H)
			var before: Array = state()
			var original_mute: bool = game.muted
			var original_charge: float = game.charge
			if mode == game.Modal.NONE: named(game.hud.live_chrome,"II").grab_focus()
			await key(KEY_M,true)
			check(game.muted != original_mute and state() == before and is_equal_approx(game.charge,original_charge),"one focused M press changes only mute in each live/modal state")
			await key(KEY_M,true)
			await key(KEY_M,true,false,true)
			check(game.muted != original_mute,"held/non-echo duplicate and echo M cannot toggle twice")
			await key(KEY_M,false)
			await tap(KEY_M)
			check(game.muted == original_mute,"a fresh release/repress permits the next mute action")
			if mode == game.Modal.PAUSE: await tap(KEY_ESCAPE)
			elif mode == game.Modal.HELP: await tap(KEY_H)

func charge_latches() -> void:
	await fresh(game.Phase.READY)
	await key(KEY_SPACE,false)
	check(game.phase == game.Phase.READY,"Space release without an eligible press cannot launch")
	game.charge = .43
	await key(KEY_SPACE,true)
	await tap(KEY_H)
	var accumulated: float = game.charge
	check(not game.charging and not game.space_armed,"modal entry clears charging and matching-press latches")
	await tap(KEY_H)
	await key(KEY_SPACE,false)
	check(game.phase == game.Phase.READY and is_equal_approx(game.charge,accumulated),"release after HELP preserves accumulated charge without launching")
	await tap(KEY_H)
	await key(KEY_SPACE,true)
	await tap(KEY_H)
	await key(KEY_SPACE,false)
	check(game.phase == game.Phase.READY,"Space pressed under HELP cannot arm a later release")
	await key(KEY_SPACE,true)
	await tap(KEY_R)
	await key(KEY_SPACE,false)
	check(game.phase == game.Phase.READY and not game.charging,"retry invalidates a prior charge press")
	var serial: int = game.run_serial
	await key(KEY_SPACE,true)
	await key(KEY_SPACE,false)
	check(game.phase == game.Phase.RUN and game.run_serial == serial+1,"a fresh eligible Space pair launches exactly once")
	await key(KEY_SPACE,false)
	check(game.run_serial == serial+1,"a duplicate Space release cannot launch twice")

func held_movement_transitions() -> void:
	await fresh(game.Phase.READY)
	await key(KEY_D,true)
	await key(KEY_W,true)
	await key(KEY_SPACE,true)
	for frame in 12: await physics_frame
	await key(KEY_SPACE,false)
	check(game.phase == game.Phase.RUN and game.steering() > .9,"held steering remains eligible across natural charge/launch")
	var speed: float = game.run_speed
	for frame in 36: await physics_frame
	check(game.push_count >= 1 and game.run_speed > speed+1.0,"a held push key begins a real kick after natural launch without release/repress")
	await key(KEY_SPACE,true)
	check(game.phase == game.Phase.CRASH and game.steering() > .9 and game.boost_direction().x > .5,"held steering remains eligible for aftertouch across natural bail")
	await key(KEY_SPACE,false)
	await key(KEY_W,false)
	await key(KEY_D,false)

func focus_suspension() -> void:
	for phase in [game.Phase.READY,game.Phase.RUN,game.Phase.CRASH,game.Phase.REPLAY]:
		for closing in ["H","ESC","BUTTON"]:
			await fresh(phase)
			await key(KEY_D,true)
			if phase == game.Phase.READY: await key(KEY_SPACE,true)
			await tap(KEY_H)
			var before: Array = state()
			var run_time: float = game.run_clock
			var crash_time: float = game.crash_clock
			var replay_time: float = game.replay_clock
			var position: Vector3 = game.skater.position
			game.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
			game.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
			check(game.window_focused and game.focus_suspended,"focus gain retains the explicit live suspension latch")
			if closing == "H": await tap(KEY_H)
			elif closing == "ESC": await tap(KEY_ESCAPE)
			else: await click(named(game.hud.help_panel,"LET'S FILE IT  →"))
			modal(game.Modal.PAUSE,true,"focus loss during HELP returns to PAUSE via "+closing)
			for frame in 5: await process_frame
			check(state() == before and game.skater.position == position,"focus suspension preserves phase, actor, resources, and funding")
			check(is_equal_approx(game.run_clock,run_time) and is_equal_approx(game.crash_clock,crash_time) and is_equal_approx(game.replay_clock,replay_time),"focus suspension freezes all active phase clocks")
			await click(named(game.hud.pause_panel,"KEEP WRECKING"))
			modal(game.Modal.NONE,false,"explicit resume after focus suspension")
			check(not game.focus_suspended and is_zero_approx(game.steering()),"Resume does not reactivate the still-held movement key")
			if phase == game.Phase.READY:
				await key(KEY_SPACE,false)
				check(game.phase == game.Phase.READY,"stale Space release after focus loss and Resume cannot launch")
			await key(KEY_D,false)
			await key(KEY_D,true)
			check(game.steering() > .9 if phase != game.Phase.REPLAY else is_zero_approx(game.steering()),"movement requires a fresh release/repress and stays ineligible during REPLAY")
			await key(KEY_D,false)
	for phase in [game.Phase.MENU,game.Phase.RESULTS]:
		await fresh(phase)
		await tap(KEY_H)
		game.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
		game.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
		await tap(KEY_H)
		check(game.phase == phase and not game.focus_suspended,"MENU/RESULTS help focus loss retains ordinary return context")
		modal(game.Modal.NONE,false,"non-live help close after focus loss")
	await fresh(game.Phase.READY)
	await key(KEY_SPACE,true)
	game.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	modal(game.Modal.PAUSE,true,"direct READY focus loss")
	game.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	modal(game.Modal.PAUSE,true,"focus gain never resumes automatically")
	await tap(KEY_ESCAPE)
	await key(KEY_SPACE,false)
	check(game.phase == game.Phase.READY,"direct focus loss also invalidates the old charge release")
	for phase in [game.Phase.RUN,game.Phase.CRASH,game.Phase.REPLAY]:
		await fresh(phase)
		await key(KEY_D,true)
		game.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
		modal(game.Modal.PAUSE,true,"direct live focus loss phase "+str(phase))
		await tap(KEY_ESCAPE)
		check(not game.window_focused and game.is_paused,"unfocused synthetic Escape cannot resume a live phase")
		game.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
		modal(game.Modal.PAUSE,true,"direct live focus gain phase "+str(phase))
		await click(named(game.hud.pause_panel,"KEEP WRECKING"))
		check(game.phase == phase and is_zero_approx(game.steering()),"Resume preserves the suspended live phase and blocks held movement")
		await key(KEY_D,false)
	await fresh(game.Phase.READY)
	game.hud.pose_buttons[2].grab_focus()
	await tap(KEY_ESCAPE)
	await tap(KEY_H)
	game.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	game.notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	game.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	await tap(KEY_H)
	modal(game.Modal.PAUSE,true,"focus loss during HELP over an existing PAUSE")
	await click(named(game.hud.pause_panel,"KEEP WRECKING"))
	check(root.gui_get_focus_owner() == game.hud.pose_buttons[2],"duplicate focus notifications retain the valid focus saved before the original pause")

func one_use_across_modals() -> void:
	await fresh(game.Phase.CRASH)
	await tap(KEY_H)
	await key(KEY_SHIFT,true)
	await tap(KEY_H)
	await key(KEY_SHIFT,true)
	check(game.boosts == 1 and game.breaker_events.is_empty(),"a Shift press beginning under HELP cannot spend on a stale held press after close")
	await key(KEY_SHIFT,false)
	await tap(KEY_SHIFT)
	check(game.boosts == 0 and game.breaker_events.size() == 1,"a fresh Shift release/repress after HELP spends exactly once")
	await fresh(game.Phase.CRASH)
	await key(KEY_SHIFT,true)
	check(game.boosts == 0 and game.breaker_events.size() == 1,"real Shift spends one charge before modal transitions")
	await tap(KEY_H)
	await key(KEY_SHIFT,true,false,true)
	await tap(KEY_H)
	await tap(KEY_ESCAPE)
	await key(KEY_SHIFT,true)
	await tap(KEY_ESCAPE)
	await key(KEY_SHIFT,false)
	await tap(KEY_SHIFT)
	check(game.boosts == 0 and game.breaker_events.size() == 1,"hold/repeat/release across HELP/PAUSE never restores a spent charge")
	for frame in 18: await physics_frame
	game.finish_run()
	var bank: int = game.fund_total()
	game.start_replay()
	await tap(KEY_SHIFT)
	check(game.phase == game.Phase.REPLAY and game.boosts == 0 and game.breaker_events.size() == 1 and game.fund_total() == bank,"replay input cannot restore an intervention or create funding")

func quit_control() -> void:
	var script_path: String = fixtures.artifact_path("quit_control.gd")
	var file := FileAccess.open(script_path,FileAccess.WRITE)
	file.store_string("""extends SceneTree
const Fixtures=preload("res://tests/test_fixtures.gd")
var fixtures=Fixtures.new("quit-control")
func _initialize(): call_deferred("run")
func key(code,down):
 var event=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=down
 Input.parse_input_event(event);Input.flush_buffered_events();await process_frame
func run():
 var game=fixtures.create_game(root);game.start_ready()
 await key(KEY_ESCAPE,true);await key(KEY_ESCAPE,false)
 for button in game.hud.pause_panel.find_children("*","Button",true,false):
  if button.text=="QUIT GAME":button.grab_focus()
 print("QUIT_ACTION_READY")
 await key(KEY_ENTER,true)
 await process_frame
 printerr("FAIL: visible Quit did not exit the engine")
 quit(1)
""")
	file.close()
	var child_dir: String = fixtures.directory.path_join("quit-case")
	DirAccess.make_dir_recursive_absolute(child_dir)
	var command := PackedStringArray(["--headless","--path",ProjectSettings.globalize_path("res://"),"--fixed-fps","60","--script",script_path,"--log-file",child_dir.path_join("engine.log"),"--","--test-mode","--records-path="+child_dir.path_join("records.json")])
	var output: Array = []
	var code: int = OS.execute(OS.get_executable_path(),command,output,true)
	var transcript: String = ""
	for fragment in output: transcript += str(fragment)
	var log := FileAccess.open(child_dir.path_join("output.log"),FileAccess.WRITE)
	log.store_string(transcript); log.close()
	print(transcript)
	check(code == 0 and transcript.contains("QUIT_ACTION_READY") and not transcript.contains("FAIL:"),"Enter on the visible pause Quit control actually exits a fresh engine process")

func run() -> void:
	game = fixtures.create_game(root)
	if game == null: return
	await underlying_controls()
	await direct_guards()
	await ordinary_gui_navigation()
	await pause_actions()
	await live_slow_and_mute()
	await charge_latches()
	await held_movement_transitions()
	await focus_suspension()
	await one_use_across_modals()
	await quit_control()
	game._replace_route(0)
	game.queue_free()
	await process_frame
	await process_frame
	print("MODAL_INPUTS: ",checks," checks, ",failures," failures; actual parsed input, focus and synthetic focus notifications")
	quit(1 if failures else 0)
