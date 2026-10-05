extends Node3D

const CrashCameraPolicy=preload("res://scripts/crash_camera.gd")
const ContactPolicy=preload("res://scripts/skating_contacts.gd")
const Settlement=preload("res://scripts/crash_settlement.gd")
const ReplayTimeline=preload("res://scripts/replay_timeline.gd")
const ReplayPresentation=preload("res://scripts/replay_presentation.gd")
var camera_policy=CrashCameraPolicy.new()
var skating_contacts=ContactPolicy.new()
var replay_timeline=ReplayTimeline.new()
var replay_presentation=ReplayPresentation.new()
var replay_catalog: Dictionary={}
var replay_sample: Dictionary={}
var replay_events: Array[Dictionary]=[]
var replay_receipt_cursor: int=0
var replay_live_camera: Dictionary={}
var replay_live_claims: Array[Dictionary]=[]
var replay_visibility: Dictionary={}
var camera_diagnostic: Dictionary={}
var last_camera_sample: Dictionary={}
var crash_start_time: float=0.0
var finish_reason: String=""
var settlement_activity: Dictionary={}
var accepted_contact: Dictionary={}

const Rules = preload("res://scripts/game_rules.gd")
const World = preload("res://scripts/world_builder.gd")
const Rider = preload("res://scripts/rider.gd")
const HUD = preload("res://scripts/game_hud.gd")
const Sound = preload("res://scripts/sound_director.gd")
const RecordsStore = preload("res://scripts/records_store.gd")
const GameClock = preload("res://scripts/game_clock.gd")
var records_store: RefCounted
var wall_clock = GameClock.new()
var presentation_delta: float = 0.0
var last_goal_crossed: bool = false
const CRASHBREAKER_USES: int = 1
const PULSE_RADIUS: float = 2.2
const PULSE_BUDGET: float = 90.0
enum Phase { MENU, READY, RUN, CRASH, RESULTS, REPLAY }
enum Modal { NONE, PAUSE, HELP }
# Phase/action policy. Visible modal controls additionally own their action source.
# MENU: play, route, help, mute. READY: pose, hat, move, charge, camera, retry.
# RUN: move/push, bail, slow, camera, retry. CRASH: move, breaker, slow, file, camera, retry.
# RESULTS: retry, next, route, replay, menu, camera, help, mute.
# REPLAY: camera, retry, pause, help, mute; never live impulses or filing.
const ACTION_PHASES: Dictionary = {
 "play":[Phase.MENU], "route":[Phase.MENU,Phase.RESULTS], "records":[Phase.MENU,Phase.READY,Phase.RESULTS],
 "pose":[Phase.READY], "hat":[Phase.READY],
 "move":[Phase.READY,Phase.RUN,Phase.CRASH], "push":[Phase.RUN],
 "charge":[Phase.READY], "bail":[Phase.RUN], "slow":[Phase.RUN,Phase.CRASH],
 "breaker":[Phase.CRASH], "file":[Phase.CRASH], "replay":[Phase.RESULTS],
 "retry":[Phase.READY,Phase.RUN,Phase.CRASH,Phase.RESULTS,Phase.REPLAY],
 "next":[Phase.RESULTS], "menu":[Phase.RESULTS],
 "camera":[Phase.READY,Phase.RUN,Phase.CRASH,Phase.RESULTS,Phase.REPLAY],
 "pause":[Phase.READY,Phase.RUN,Phase.CRASH,Phase.REPLAY],
}
const HELD_GAME_KEYS: Array[int] = [KEY_SPACE,KEY_TAB,KEY_SHIFT,KEY_W,KEY_UP,KEY_A,KEY_LEFT,KEY_D,KEY_RIGHT,KEY_S,KEY_DOWN]
var modal_kind: Modal = Modal.NONE
var help_return_modal: Modal = Modal.NONE
var saved_focus: Control
var help_saved_focus: Control
var window_focused: bool = true
var focus_suspended: bool = false
var pressed_keys: Dictionary = {}
var blocked_keys: Dictionary = {}
var space_armed: bool = false
var input_generation: int = 0
var space_generation: int = -1
var restoring_modal_focus: bool = false
var phase: Phase = Phase.MENU
var level_index: int = 0
var level_root: Node3D
var world: WreckWorld
var skater: Skater
var hud: WreckHUD
var sound: Node
var camera: Camera3D
var rules := WreckRules.new()
var run_speed: float = 0.0
var lateral_speed: float = 0.0
var charge: float = 0.0
var charging: bool = false
var boosts: int = CRASHBREAKER_USES
var run_clock: float = 0.0
var crash_clock: float = 0.0
var idle_clock: float = 0.0
var camera_style: int = 0
var camera_shake: float = 0.0
var camera_target: Vector3 = Vector3.ZERO
var is_paused: bool = false
var paused_for_help: bool = false
var slow_motion: bool = false
var best_scores: Array[int] = [0,0,0]
var legacy_scores: Array[int] = [0,0,0]
var muted: bool = false
const DEFAULT_RECORDS_PATH: String = "user://records.json"
var save_path: String = DEFAULT_RECORDS_PATH
var records_path_source: String = "user-default"
var startup_error: String = ""
var startup_records_read_path: String = ""
var particles: Array[Dictionary] = []
var replay_frames: Array[Dictionary] = []
var replay_actors: Array[Node3D] = []
var self_check: bool = false
var record_clock: float = 0.0
var replay_clock: float = 0.0
var result_was_best: bool = false
var rng := RandomNumberGenerator.new()
var test_mode: bool = false
var traffic_cue: bool = false
var automate: bool = false
var capture_mode: bool = false
var capture_dir: String = "res://docs/screenshots"
var capture_flags: Dictionary = {}
var pending_level: int = 0
var run_serial: int = 0
var pose_index: int = 0
var time_rate: float = 1.0
var impact_left: float = 0.0
var impact_cooldown: float = 0.0
var boost_cooldown: float = 0.0
var crash_real_clock: float = 0.0
var last_money_secured: int = 0
var last_claim_improvement: int = 0
var claim_events: Array[Dictionary] = []
var cascade_focus: Vector3 = Vector3.ZERO
var cascade_focus_left: float = 0.0
var aim_marker: Node3D
var selected_hat: int = 0
var traffic_edges: Array[Dictionary] = []
var traffic_final_states: Array[Dictionary] = []
var breaker_events: Array[Dictionary] = []
var cascade_grace: float = 0.0
var push_clock: float = 0.0
var push_active: bool = false
var push_count: int = 0
var heading: float = 0.0

func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	rng.seed=90210
	if not configure_startup(OS.get_cmdline_user_args()):
		push_error("STARTUP: "+startup_error)
		get_tree().quit(2)
		return
	startup_records_read_path = save_path
	load_records()
	get_window().min_size=Vector2i(960,600)
	camera=Camera3D.new(); camera.physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF; camera.fov=58; camera.near=.15; camera.far=250; add_child(camera); camera.current=true
	hud=HUD.new(); hud.process_mode=Node.PROCESS_MODE_ALWAYS; add_child(hud)
	hud.play_requested.connect(start_ready)
	hud.route_requested.connect(select_route)
	hud.retry_requested.connect(retry)
	hud.next_requested.connect(next_route)
	hud.menu_requested.connect(back_to_menu)
	hud.resume_requested.connect(resume)
	hud.replay_requested.connect(start_replay)
	hud.mute_requested.connect(toggle_mute)
	hud.quit_requested.connect(request_quit)
	hud.help_requested.connect(toggle_help)
	hud.pause_requested.connect(toggle_pause)
	hud.help_closed.connect(close_help)
	get_viewport().gui_focus_changed.connect(_on_gui_focus_changed)
	hud.pose_requested.connect(set_pose)
	hud.retry_save_requested.connect(retry_records)
	hud.recover_requested.connect(recover_records)
	sound=Sound.new(); add_child(sound); sound.set_muted(muted)
	_replace_route(pending_level)
	if automate: start_ready()

func configure_startup(arguments: PackedStringArray) -> bool:
	# Resolve the selected profile before the first read. Test modes never replace it.
	var explicit_path: String = ""
	var explicit_count: int = 0
	startup_error = ""
	for arg in arguments:
		if arg == "--test-mode": test_mode = true
		if arg == "--demo": automate = true
		if arg == "--self-check": automate = true; self_check = true
		if arg == "--capture": capture_mode = true; automate = true
		if arg.begins_with("--level="):
			pending_level = clampi(int(arg.get_slice("=",1)),0,2)
		if arg == "--records-path":
			startup_error = "Use --records-path=<absolute filename>."
			return false
		if arg.begins_with("--records-path="):
			explicit_count += 1
			explicit_path = arg.trim_prefix("--records-path=")
			if explicit_path.is_empty() or not explicit_path.is_absolute_path() or explicit_path.begins_with("res://") or explicit_path.begins_with("user://") or explicit_path.get_file().is_empty():
				startup_error = "Records override must be an absolute filename."
				return false
	if explicit_count > 1:
		startup_error = "Only one records override is allowed."
		return false
	if explicit_count == 1:
		save_path = explicit_path.simplify_path()
		records_path_source = "cli"
	elif save_path != DEFAULT_RECORDS_PATH and not save_path.is_empty():
		records_path_source = "injected"
	elif test_mode or capture_mode or self_check:
		var mode: String = "selfcheck" if self_check else ("capture" if capture_mode else "test")
		var directory: String = ProjectSettings.globalize_path("res://builds/test_runs/direct-%s-%s-%s" % [mode,OS.get_process_id(),Time.get_ticks_usec()])
		var error: Error = DirAccess.make_dir_recursive_absolute(directory)
		if error != OK:
			startup_error = "Cannot create isolated records directory (error %s)." % error
			return false
		save_path = directory.path_join("records.json")
		records_path_source = mode+"-default"
	else:
		save_path = DEFAULT_RECORDS_PATH
		records_path_source = "user-default"
	return true

func load_records() -> void:
	records_store = RecordsStore.new(save_path, Rules.TREATMENT_GOAL)
	records_store.load_records()
	sync_records_state()

func sync_records_state() -> void:
	var candidate: Dictionary = records_store.session_candidate
	best_scores.assign(candidate.best_scores)
	legacy_scores.assign(candidate.legacy_scores)
	muted = candidate.muted
	selected_hat = candidate.hat
	if is_instance_valid(sound): sound.set_muted(muted)

func consume_secured_events() -> void:
	last_money_secured = 0
	last_goal_crossed = false
	var event: Dictionary = records_store.consume_contribution_event()
	while not event.is_empty():
		last_money_secured += int(event.amount)
		last_goal_crossed = last_goal_crossed or bool(event.goal_crossed)
		event = records_store.consume_contribution_event()

func save_records() -> bool:
	var result: Dictionary = records_store.commit({"version":2,"best_scores":best_scores,"legacy_scores":legacy_scores,"muted":muted,"hat":selected_hat})
	sync_records_state()
	consume_secured_events()
	if is_instance_valid(hud):
		hud.update_campaign(last_money_secured)
		if phase==Phase.RESULTS: hud.show_results(rules,level_index,result_was_best)
	if last_goal_crossed and is_instance_valid(sound): sound.play("funded")
	return result.ok

func retry_records() -> void:
	if not action_allowed("records"): return
	records_store.retry()
	sync_records_state()
	consume_secured_events()
	if is_instance_valid(hud):
		hud.update_campaign(last_money_secured)
		if phase == Phase.RESULTS: hud.show_results(rules,level_index,result_was_best)
	if last_goal_crossed: sound.play("funded")

func recover_records(use_backup: bool) -> void:
	if not action_allowed("records"): return
	if use_backup: records_store.recover_backup()
	else: records_store.recover_fresh()
	sync_records_state()
	consume_secured_events()
	if is_instance_valid(hud):
		hud.update_campaign(last_money_secured)
		if phase == Phase.RESULTS: hud.show_results(rules,level_index,result_was_best)
	if last_goal_crossed: sound.play("funded")

func fund_total() -> int:
	return records_store.fund_total() if records_store != null else 0

func set_pose(index: int) -> void:
	if not action_allowed("pose"): return
	pose_index=clampi(index,0,2)
	skater.set_pose(pose_index)
	skater.set_hat(selected_hat)
	hud.toast(Rules.POSES[pose_index].name)

func boost_direction() -> Vector3:
	var side: float=steering()
	var uphill: bool=gameplay_key_pressed(KEY_S) or gameplay_key_pressed(KEY_DOWN)
	return Vector3(side*1.5,0,-1.0 if uphill else 1.0).normalized()

func apply_time_rate() -> void:
	time_rate=1.0
	if not is_paused:
		if phase==Phase.CRASH: time_rate=.55
		if slow_motion and phase in [Phase.RUN,Phase.CRASH]: time_rate=.25
		if impact_left>0 and phase==Phase.CRASH: time_rate=.18
	Engine.time_scale=time_rate

func select_route(index: int) -> void:
	if not action_allowed("route"): return
	_replace_route(index)

# Trusted scene construction primitive for startup, accepted retry/route actions,
# and explicit physical fixture setup. HUD never connects to this primitive.
func _replace_route(index: int) -> void:
	focus_suspended = false
	_set_modal(Modal.NONE)
	_cancel_held_actions()
	level_index=clampi(index,0,2)
	dispose_replay()
	ReplayPresentation.dispose_catalog(replay_catalog)
	replay_timeline.begin({})
	camera_policy.reset(); last_camera_sample.clear(); replay_sample.clear(); replay_events.clear(); replay_receipt_cursor=0
	finish_reason=""; last_claim_improvement=0; settlement_activity.clear(); accepted_contact.clear()
	wall_clock.rebase(); presentation_delta=0; record_clock=0
	sound.set_replay_audio(false)
	rules.reset(); replay_frames.clear(); replay_actors.clear(); particles.clear(); claim_events.clear()
	traffic_edges.clear(); traffic_final_states.clear(); breaker_events.clear(); cascade_grace=0
	push_clock=0; push_active=false; push_count=0; heading=0
	traffic_cue=false
	if is_instance_valid(level_root):
		remove_child(level_root); level_root.queue_free()
	level_root=Node3D.new(); level_root.name="Route"; level_root.process_mode=Node.PROCESS_MODE_PAUSABLE; add_child(level_root)
	world=World.new(); world.build(level_root,level_index,self)
	skater=Rider.new(); skater.game=self; level_root.add_child(skater)
	skater.set_pose(pose_index)
	skater.set_hat(selected_hat)
	var l:Dictionary=Rules.LEVELS[level_index]
	# Lead the first run into the readable domino chain; other routes open at their cargo/drum line.
	skater.position=Vector3(-3.3 if level_index==0 else 0.0,l.steps*l.rise+.23,-13)
	phase=Phase.MENU; charge=0; charging=false; run_speed=0; boosts=CRASHBREAKER_USES; run_clock=0; crash_clock=0; camera_shake=0
	impact_left=0; impact_cooldown=0; boost_cooldown=0; crash_real_clock=0; cascade_focus_left=0; aim_marker=null
	apply_time_rate()
	camera_target=Vector3(-5,l.steps*l.rise*.45,l.steps*l.run*.40)
	camera.position=overview_position()
	camera.look_at(camera_target)
	hud.set_route(level_index,best_scores[level_index]); hud.update_campaign(); hud.show_menu()

func effective_modal() -> Modal:
	if is_instance_valid(hud):
		if hud.help_panel.visible: return Modal.HELP
		if hud.pause_panel.visible: return Modal.PAUSE
	return modal_kind

func action_allowed(action: String) -> bool:
	if action in ["mute","help"]: return true
	if not window_focused: return false
	var modal: Modal = effective_modal()
	if modal == Modal.HELP: return action == "close_help"
	if modal == Modal.PAUSE: return action in ["resume","retry","menu","quit"]
	return phase in ACTION_PHASES.get(action,[])

func hud_owner_allowed(button: Button) -> bool:
	if not button.is_visible_in_tree() or button.disabled: return false
	var modal: Modal = effective_modal()
	if modal == Modal.NONE: return true
	var panel: Control = hud.help_panel if modal == Modal.HELP else hud.pause_panel
	return panel.is_ancestor_of(button)

func _cancel_held_actions(block_current_keys: bool = true) -> void:
	input_generation += 1
	space_armed = false
	space_generation = -1
	charging = false
	slow_motion = false
	push_active = false
	if block_current_keys:
		for key in HELD_GAME_KEYS:
			if pressed_keys.has(key) or Input.is_physical_key_pressed(key): blocked_keys[key] = true
	apply_time_rate()

func _set_modal(kind: Modal) -> void:
	_cancel_held_actions()
	modal_kind = kind
	wall_clock.rebase()
	presentation_delta = 0.0
	var live_phase: bool = phase in [Phase.READY,Phase.RUN,Phase.CRASH,Phase.REPLAY]
	is_paused = kind == Modal.PAUSE or (kind == Modal.HELP and (live_phase or help_return_modal == Modal.PAUSE))
	paused_for_help = kind == Modal.HELP and live_phase and help_return_modal == Modal.NONE
	get_tree().paused = is_paused
	if is_instance_valid(hud):
		hud.pause_panel.visible = kind == Modal.PAUSE
		hud.help_panel.visible = kind == Modal.HELP
		if kind != Modal.NONE: hud.focus_modal(kind == Modal.HELP)
	apply_time_rate()

func _restore_focus(previous: Control) -> void:
	if is_instance_valid(previous) and previous.is_visible_in_tree() and previous.focus_mode != Control.FOCUS_NONE and (not previous is BaseButton or not previous.disabled):
		previous.grab_focus()
	elif is_instance_valid(hud):
		hud.focus_phase(phase == Phase.MENU,phase == Phase.RESULTS)

func _on_gui_focus_changed(control: Control) -> void:
	if restoring_modal_focus or not is_instance_valid(hud) or effective_modal() == Modal.NONE: return
	var panel: Control = hud.help_panel if effective_modal() == Modal.HELP else hud.pause_panel
	if control != null and panel.is_ancestor_of(control): return
	restoring_modal_focus = true
	hud.focus_modal(effective_modal() == Modal.HELP)
	restoring_modal_focus = false

func start_ready() -> void:
	if not action_allowed("play"): return
	_cancel_held_actions()
	phase=Phase.READY; hud.show_game(); charge=0; charging=false
	hud.toast(Rules.LEVELS[level_index].name)

func retry() -> void:
	if not action_allowed("retry"): return
	_replace_route(level_index)
	start_ready()

func next_route() -> void:
	if not action_allowed("next"): return
	_replace_route((level_index+1)%3)
	start_ready()

func back_to_menu() -> void:
	if not action_allowed("menu"): return
	_replace_route(level_index)

func resume() -> void:
	if not action_allowed("resume"): return
	focus_suspended = false
	_set_modal(Modal.NONE)
	_restore_focus(saved_focus)

func unpause() -> void:
	if effective_modal() == Modal.HELP: return
	if effective_modal() == Modal.PAUSE:
		resume()
	else:
		_set_modal(Modal.NONE)

func toggle_pause() -> void:
	if effective_modal() == Modal.HELP: return
	if effective_modal() == Modal.PAUSE:
		resume()
	elif phase == Phase.RESULTS:
		back_to_menu()
	elif action_allowed("pause"):
		saved_focus = get_viewport().gui_get_focus_owner()
		_set_modal(Modal.PAUSE)

func toggle_help() -> void:
	if effective_modal() == Modal.HELP:
		close_help()
		return
	if not action_allowed("help"): return
	help_return_modal = effective_modal()
	help_saved_focus = get_viewport().gui_get_focus_owner()
	_set_modal(Modal.HELP)

func close_help() -> void:
	if effective_modal() != Modal.HELP: return
	var return_modal: Modal = Modal.PAUSE if focus_suspended or help_return_modal == Modal.PAUSE else Modal.NONE
	_set_modal(return_modal)
	if return_modal == Modal.PAUSE:
		if is_instance_valid(help_saved_focus) and hud.pause_panel.is_ancestor_of(help_saved_focus): _restore_focus(help_saved_focus)
	else:
		_restore_focus(help_saved_focus)
	help_return_modal = Modal.NONE

func request_quit() -> void:
	if action_allowed("quit"): get_tree().quit()

func toggle_mute() -> void:
	if not action_allowed("mute"): return
	muted=not muted; sound.set_muted(muted); save_records()
	if hud.hud.visible: hud.toast("SOUND OFF" if muted else "SOUND ON")
	else: hud.best_label.text="SOUND OFF" if muted else "SOUND ON"

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		window_focused = false
		if not is_instance_valid(hud): return
		_cancel_held_actions()
		if phase in [Phase.READY,Phase.RUN,Phase.CRASH,Phase.REPLAY]:
			focus_suspended = true
			if effective_modal() == Modal.NONE:
				saved_focus = get_viewport().gui_get_focus_owner()
				_set_modal(Modal.PAUSE)
			elif effective_modal() == Modal.HELP:
				help_return_modal = Modal.PAUSE
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN or what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		window_focused = true

func _owns_key(key: int) -> bool:
	if key in [KEY_M,KEY_H,KEY_ESCAPE]: return true
	if key in [KEY_ENTER,KEY_KP_ENTER] and pressed_keys.has(key): return true
	if effective_modal() != Modal.NONE:
		return key in [KEY_TAB,KEY_ENTER,KEY_KP_ENTER,KEY_SPACE] or key in HELD_GAME_KEYS or key in [KEY_R,KEY_C,KEY_V,KEY_F,KEY_1,KEY_2,KEY_3]
	if blocked_keys.has(key): return true
	if key == KEY_SPACE: return phase in [Phase.READY,Phase.RUN]
	if key == KEY_TAB: return phase in [Phase.RUN,Phase.CRASH]
	if key in HELD_GAME_KEYS: return phase in [Phase.READY,Phase.RUN,Phase.CRASH,Phase.REPLAY]
	if key in [KEY_1,KEY_2,KEY_3,KEY_F]: return phase == Phase.READY
	if key in [KEY_R,KEY_C,KEY_V]: return phase != Phase.MENU
	if key in [KEY_ENTER,KEY_KP_ENTER]: return phase == Phase.CRASH
	return false

func _input(event: InputEvent) -> void:
	if event is InputEventKey and _owns_key(event.physical_keycode):
		_dispatch_key(event)
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	# The direct-test seam shares exactly the same dispatch policy. MENU/RESULTS
	# Enter reaches this only when ordinary GUI navigation did not consume it.
	if not event is InputEventKey: return
	if event.physical_keycode in [KEY_ENTER,KEY_KP_ENTER] and phase in [Phase.MENU,Phase.RESULTS] and effective_modal() == Modal.NONE:
		# Buttons may defer acceptance until key-up. Do not replace their focused
		# action with the phase's fallback on the earlier unhandled key-down.
		var owner: Control = get_viewport().gui_get_focus_owner()
		if owner != null and owner.is_visible_in_tree() and owner.focus_mode != Control.FOCUS_NONE: return
	_dispatch_key(event)

func _dispatch_key(event: InputEventKey) -> void:
	var key: int = event.physical_keycode
	if event.echo: return
	if not event.pressed:
		pressed_keys.erase(key)
		var was_blocked: bool = blocked_keys.has(key)
		blocked_keys.erase(key)
		if key == KEY_TAB:
			slow_motion = false
			apply_time_rate()
		if key == KEY_SPACE:
			var matched: bool = space_armed and space_generation == input_generation
			space_armed = false
			charging = false
			if not was_blocked and matched and action_allowed("charge"): launch()
		return
	if pressed_keys.has(key): return
	pressed_keys[key] = true
	if blocked_keys.has(key): return
	if key == KEY_M: toggle_mute(); return
	if key == KEY_H: toggle_help(); return
	if key == KEY_ESCAPE:
		if effective_modal() == Modal.HELP: close_help()
		else: toggle_pause()
		return
	if effective_modal() != Modal.NONE:
		if key == KEY_TAB: hud.cycle_modal_focus(effective_modal() == Modal.HELP,event.shift_pressed)
		elif key in [KEY_ENTER,KEY_KP_ENTER]: hud.activate_modal_focus(effective_modal() == Modal.HELP)
		elif key in HELD_GAME_KEYS: blocked_keys[key] = true
		return
	if not window_focused: return
	if key == KEY_SPACE:
		if action_allowed("charge"):
			space_armed = true; space_generation = input_generation; charging = true
		elif action_allowed("bail"): bail_out()
	elif key == KEY_TAB and action_allowed("slow"):
		slow_motion = true; apply_time_rate()
	elif key == KEY_SHIFT: crashbreaker()
	elif key in [KEY_1,KEY_2,KEY_3]: set_pose(key-KEY_1)
	elif key == KEY_F and action_allowed("hat"):
		selected_hat=(selected_hat+1)%3; skater.set_hat(selected_hat); save_records(); hud.toast(["CLOCKWORK CROWN","PAPER CRANE","TRAFFIC CONE"][selected_hat])
	elif key == KEY_R: retry()
	elif key == KEY_C and action_allowed("camera"): camera_style=(camera_style+1)%(4 if phase==Phase.REPLAY else 3); camera_policy.reset()
	elif key == KEY_V: start_replay()
	elif key in [KEY_ENTER,KEY_KP_ENTER]:
		if action_allowed("file"): finish_run()
		elif action_allowed("play"): start_ready()
		elif phase == Phase.RESULTS: retry()

func gameplay_key_pressed(key: int) -> bool:
	return action_allowed("move") and not blocked_keys.has(key) and Input.is_physical_key_pressed(key)

func steering() -> float:
	return float(gameplay_key_pressed(KEY_D) or gameplay_key_pressed(KEY_RIGHT))-float(gameplay_key_pressed(KEY_A) or gameplay_key_pressed(KEY_LEFT))

func launch() -> void:
	if not action_allowed("charge"): return
	_cancel_held_actions(false)
	phase=Phase.RUN; charging=false; run_speed=6.5+charge*12.0; run_clock=0; lateral_speed=0; run_serial+=1
	for prop in world.props:
		if prop.get_meta("traffic",false): continue
		prop.freeze=false; prop.grace=.65; prop.origin=prop.global_position
	world.start_traffic()
	hud.toast("CHASE THE BIGGEST CLAIM",WreckHUD.ORANGE); sound.play("launch")

func is_live() -> bool:
	return phase==Phase.RUN or phase==Phase.CRASH

func _physics_process(delta: float) -> void:
	if is_paused or not is_instance_valid(skater): return
	if phase==Phase.READY:
		if charging: charge=minf(1.0,charge+delta*.65)
		var lane_limit: float=Rules.LEVELS[level_index].width*.5-.8
		skater.position.x=clampf(skater.position.x+steering()*delta*3.5,-lane_limit,lane_limit)
		skater.pose_ride(run_clock,steering(),0,false)
		if automate:
			charge=minf(1,charge+delta*.9)
			if charge>=1: launch()
	elif phase==Phase.RUN:
		var previous_root: Transform3D=skater.global_transform
		var previous_proxies: Array=skating_contacts.capture_proxies(skater)
		var previous_anchors: Dictionary=skater.pose_anchors.duplicate()
		run_clock+=delta
		rules.tick(delta)
		var pushing: bool=(gameplay_key_pressed(KEY_W) or gameplay_key_pressed(KEY_UP) or automate) and skater.position.z<0
		# A rear-foot stroke adds one kick; coasting no longer accelerates itself.
		run_speed=move_toward(run_speed,0,delta*.28)
		if pushing:
			if not push_active: push_clock=0
			var before_kick: int=int(floor((push_clock+.324)/.72))
			push_clock+=delta
			var kicks: int=int(floor((push_clock+.324)/.72))-before_kick
			if kicks>0:
				run_speed+=2.1*kicks; push_count+=kicks
		else: push_clock=0
		push_active=pushing
		if skater.position.z>0: run_speed+=delta*5.0
		run_speed=minf(31.0,run_speed)
		heading=move_toward(heading,steering()*.28,delta*1.4)
		lateral_speed=sin(heading)*run_speed
		skater.position.x=clampf(skater.position.x+lateral_speed*delta,-Rules.LEVELS[level_index].width*.5+.8,Rules.LEVELS[level_index].width*.5-.8)
		skater.position.z+=cos(heading)*run_speed*delta
		skater.rotation.y=heading
		skater.position.y=ContactPolicy.grounded_height(Rules.LEVELS[level_index],skater.position.z)
		skater.set_push_phase(fmod(push_clock,.72)/.72)
		skater.pose_ride(run_clock,steering(),run_speed,pushing)
		var stairs_end: float=Rules.LEVELS[level_index].steps*Rules.LEVELS[level_index].run
		if not traffic_cue and skater.position.z>stairs_end-7:
			traffic_cue=true
			hud.toast("TRAFFIC AHEAD  /  SPACE TO BAIL",WreckHUD.MINT)
		rules.peak_speed=maxf(rules.peak_speed,run_speed)
		var proposed_proxies: Array=skating_contacts.capture_proxies(skater)
		var contact: Dictionary=skating_contacts.find_obstruction(get_world_3d().direct_space_state,previous_root,skater.global_transform,previous_proxies,world.props,proposed_proxies)
		if not contact.is_empty():
			var fraction: float=contact.fraction
			skater.global_transform=contact.transform
			for index in previous_proxies.size():
				var key: String=previous_proxies[index].id
				skater.visuals[key].transform=previous_proxies[index].part_transform.interpolate_with(proposed_proxies[index].part_transform,fraction)
			for key in previous_anchors:
				skater.pose_anchors[key]=previous_anchors[key].lerp(skater.pose_anchors[key],fraction)
			var prop: CrashProp=contact.collider
			accepted_contact={"id":prop.stable_id,"time":run_clock,"fraction":fraction,"part":contact.proxy_id,"at":contact.at,"normal":contact.normal,"error_bound":contact.error_bound}
			var strike: Vector3=Vector3(lateral_speed*.7,2.0,run_speed)*prop.mass*1.3
			if prop.kind=="taxi":
				var effective_mass: float=35.0*prop.mass/(35.0+prop.mass)
				strike=Vector3(lateral_speed,0,run_speed)*effective_mass
			prop.activate(strike)
			bail_out()
		if phase==Phase.RUN and skater.position.z>Rules.LEVELS[level_index].steps*Rules.LEVELS[level_index].run-.35: bail_out()
	elif phase==Phase.CRASH:
		crash_clock+=delta; rules.tick(delta)
		skater.aftertouch(Vector3(steering(),0,0),false,delta)
		rules.peak_speed=maxf(rules.peak_speed,skater.speed())
		settlement_activity=Settlement.measure(skater.limbs,world.props)
		var pending_fuse: bool = false
		for prop in world.props:
			if is_instance_valid(prop) and prop.armed and prop.fuse>0 and not prop.broken: pending_fuse=true
		cascade_grace=maxf(0,cascade_grace-delta)
		var pending: bool = pending_fuse or cascade_grace>0 or world.traffic_pending_contact(1.5)
		idle_clock=idle_clock+delta if not settlement_activity.active and not pending else 0.0
		if automate and crash_clock>2.2 and boosts>0: crashbreaker()
		var reason: String=Settlement.finish_reason(crash_clock,crash_real_clock,idle_clock,pending)
		if not reason.is_empty(): finish_run(reason)
	if phase==Phase.CRASH:
		record_clock+=delta
		if record_clock>=.05:
			record_clock=fmod(record_clock,.05)
			record_frame()

func bail_out() -> void:
	if not action_allowed("bail"): return
	_cancel_held_actions(false)
	phase=Phase.CRASH; crash_clock=0; idle_clock=0; crash_real_clock=0; wall_clock.rebase()
	# The board's obstacle strike keeps full approach momentum. The rider falls
	# into the stair noses instead of sailing above them to the taxi plaza.
	skater.bail(Vector3(lateral_speed*.9,-2.2,run_speed*.72),.5)
	apply_time_rate()
	build_aim_marker()
	replay_actors.clear()
	for prop in world.props: replay_actors.append(prop)
	for body in skater.limbs: replay_actors.append(body)
	replay_frames.clear(); record_clock=0
	ReplayPresentation.dispose_catalog(replay_catalog)
	replay_catalog=ReplayPresentation.capture_catalog(world.props,skater)
	crash_start_time=run_clock
	replay_timeline.begin({"level":level_index,"pose":pose_index,"hat":selected_hat,"attempt":run_serial,"actors":replay_catalog.keys()})
	if not last_camera_sample.is_empty():
		replay_timeline.capture_camera(last_camera_sample.time-crash_start_time,last_camera_sample.transform,last_camera_sample.fov,"bail",0.0)
	else:
		replay_timeline.capture_camera(0,camera.global_transform,camera.fov,"bail",0)
	record_frame()
	hud.toast(Rules.POSES[pose_index].name+"   /   AIM A D + SHIFT",WreckHUD.ORANGE)
	sound.play("launch"); camera_shake=.12

func crashbreaker() -> void:
	if not action_allowed("breaker") or boosts<=0: return
	# Consume before any callbacks: exactly one activation even under repeated input.
	boosts=0; boost_cooldown=0; idle_clock=0; cascade_grace=1.5
	var aim: Vector3 = boost_direction()
	skater.launch_impulse(aim,8.5)
	var position: Vector3=skater.focus_position()
	breaker_events.append({"time":crash_clock,"aim":aim,"at":position})
	burst(position,Color("84efbc"),18,4.0)
	hud.toast("CRASHBREAKER!",WreckHUD.MINT); sound.play("boost"); camera_shake=.35
	var pulses: Array[Dictionary] = []
	var total: float = 0.0
	for prop in world.props:
		if not is_instance_valid(prop): continue
		var offset: Vector3=prop.global_position-position
		var distance: float=offset.length()
		var horizontal: Vector3=Vector3(offset.x,0,offset.z)
		if distance>=PULSE_RADIUS or horizontal.length_squared()<.001: continue
		var alignment: float=horizontal.normalized().dot(aim)
		if alignment<cos(deg_to_rad(35)): continue
		var query:=PhysicsRayQueryParameters3D.create(position,prop.global_position,3)
		query.exclude=[]
		for body in skater.limbs: query.exclude.append(body.get_rid())
		var obstruction: Dictionary=get_world_3d().direct_space_state.intersect_ray(query)
		if not obstruction.is_empty() and obstruction.collider!=prop: continue
		var falloff: float=pow(1.0-distance/PULSE_RADIUS,2.0)*alignment
		var amount: float=minf(60.0,minf(prop.mass*4.0,60.0*falloff))
		var direction: Vector3=(aim+Vector3.UP*.18).normalized()
		pulses.append({"prop":prop,"impulse":direction*amount})
		total+=amount
	var scale: float=minf(1,PULSE_BUDGET/maxf(total,.001))
	for pulse in pulses: pulse.prop.apply_shove(pulse.impulse*scale,"CRASHBREAKER")

func traffic_contact(car: CrashProp, other: Object, strength: float, at: Vector3) -> void:
	if not is_live() or not car.armed: return
	var source: String = "RIDER"
	if other is CrashProp:
		source=other.stable_id if not other.stable_id.is_empty() else other.name.to_upper()
	var destination: String=car.stable_id if not car.stable_id.is_empty() else car.name.to_upper()
	traffic_edges.append({"time":run_clock+crash_clock,"source":source,"destination":destination,"strength":strength,"at":at})
	if strength>=car.threshold: sound.play("metal_crash")
	cascade_focus=at; cascade_focus_left=1.4; cascade_grace=1.5

func traffic_braked(car: CrashProp) -> void:
	if not is_live() or car.global_position.distance_to(skater.focus_position())>24: return
	sound.play("squeal")
	sound.play("horn")

func receipt_label(identity: String) -> String:
	if identity.begins_with("traffic_"):
		return "CAR "+char(65+int(identity.get_slice("_",2)))
	if Rules.LIMB_WEIGHTS.has(identity): return "RIDER"
	return identity.replace("_"," ").to_upper()

func prop_wrecked(prop: CrashProp, explosive: bool) -> void:
	if not is_live(): return
	var points: int=rules.hit_prop(prop.get_instance_id(),prop.value,explosive)
	if points==0: return
	var source_label: String = prop.cause_label
	var receipt: String = prop.kind.to_upper()
	if prop.get_meta("traffic",false): receipt=receipt_label(source_label)+" → "+receipt_label(prop.stable_id)
	claim_events.append({"time":crash_clock,"type":"property","part":prop.kind,"payout":points,"at":prop.global_position,"source":source_label})
	hud.claim_event(receipt,points)
	sound.play("receipt")
	cascade_focus=prop.global_position; cascade_focus_left=.8
	if explosive:
		burst(prop.global_position,Color("ff9548"),35,11.0)
		burst(prop.global_position,Color("ffd278"),14,6.0)
		sound.play("blast"); hud.flash(); camera_shake=minf(.8,camera_shake+.28)
		var at: Vector3=prop.global_position
		for other in world.props:
			if not is_instance_valid(other) or other==prop: continue
			var offset: Vector3=other.global_position-at
			var distance: float=offset.length()
			if distance<3.4:
				var impulse: Vector3=(offset+Vector3(0,.5,1.0)).normalized()*minf(other.mass*(8.5-distance*1.5),85.0 if other.get_meta("traffic",false) else 10000.0)
				if other.get_meta("traffic",false): other.apply_shove(impulse,prop.name.to_upper())
				else: other.activate(impulse)
		for body in skater.limbs:
			if is_instance_valid(body) and body.global_position.distance_to(at)<5.2:
				body.apply_central_impulse((body.global_position-at+Vector3(0,.3,1.5)).normalized()*body.mass*3.5*(1.0-body.global_position.distance_to(at)/5.2))
	else:
		burst(prop.global_position,Rules.LEVELS[level_index].color,7,4.0)
		sound.play("clack")
	if rules.combo % 5==0 or explosive:
		hud.toast(("DRUM DETONATION" if explosive else "%d OBJECT CASCADE" % rules.combo)+"   ×%d" % rules.multiplier(),WreckHUD.ORANGE if explosive else WreckHUD.MINT)

func rider_hit(limb: String, force: float, at: Vector3, source: String = "") -> void:
	if phase!=Phase.CRASH: return
	var id: String="%d:%s:%d" % [run_serial,limb,int(crash_clock*4)]
	var old_stage: String=Rules.injury_stage(rules.limb_damage.get(limb,0.0))
	var points: int=rules.hit_rider(id,force,limb)
	if points<=0: return
	skater.set_limb_damage(limb,rules.limb_damage.get(limb,0.0))
	claim_events.append({"time":crash_clock,"type":"injury","part":limb,"payout":points,"at":at,"source":source})
	hud.claim_event(Rules.limb_title(limb)+(" / STEP" if source.begins_with("Tread_") else ""),points,true)
	var new_stage: String=Rules.injury_stage(rules.limb_damage.get(limb,0.0))
	if new_stage=="FRACTURED" and old_stage!=new_stage: sound.play("fracture")
	if force>=8 and impact_cooldown<=0:
		impact_left=.28; impact_cooldown=1.1; apply_time_rate()
	if points>150:
		burst(at,Color("f4e1b2"),4,3.0)
		camera_shake=minf(.6,camera_shake+force*.004)
		if force>7: sound.play("impact")

func finish_run(reason: String="manual") -> void:
	if not action_allowed("file"): return
	finish_reason=reason
	record_frame()
	if not last_camera_sample.is_empty(): replay_timeline.capture_camera(last_camera_sample.time-crash_start_time,last_camera_sample.transform,last_camera_sample.fov,"final",crash_clock)
	replay_events=claim_events.duplicate(true)
	replay_timeline.seal(crash_clock)
	traffic_final_states.clear()
	for car in world.traffic: traffic_final_states.append(car.snapshot())
	_cancel_held_actions()
	phase=Phase.RESULTS; Engine.time_scale=1.0; slow_motion=false
	time_rate=1; impact_left=0
	if is_instance_valid(aim_marker): aim_marker.visible=false
	result_was_best = rules.score > best_scores[level_index]
	last_claim_improvement=maxi(0,rules.score-int(records_store.durable_snapshot.best_scores[level_index]))
	records_store.record_claim(level_index, rules.score)
	sync_records_state()
	consume_secured_events()
	freeze_actors()
	hud.update_campaign(last_money_secured); hud.show_results(rules,level_index,result_was_best); sound.play("funded" if last_goal_crossed else "finish")
	if self_check:
		print("SELF_CHECK: level=",level_index+1," score=",rules.score," wrecks=",rules.destroyed," explosions=",rules.explosions," frames=",replay_frames.size())
		get_tree().quit(0 if rules.destroyed>=4 and rules.score>3000 else 1)

func freeze_actors() -> void:
	for prop in world.props:
		if is_instance_valid(prop): prop.freeze=true; prop.reset_physics_interpolation()
	for body in skater.limbs:
		if is_instance_valid(body): body.freeze=true; body.reset_physics_interpolation()
	skater.sync_skin()

func record_frame() -> void:
	if phase!=Phase.CRASH: return
	var transforms: Array[Transform3D]=[]
	var damage_states: Array[bool]=[]
	var traffic_states: Array[Dictionary]=[]
	var actors: Dictionary={}
	var present: Dictionary={}
	var visual: Dictionary={}
	for id in replay_catalog: present[id]=false
	for prop in world.props:
		if not is_instance_valid(prop): damage_states.append(true); continue
		damage_states.append(prop.broken)
		actors[prop.stable_id]=prop.global_transform; present[prop.stable_id]=true
		visual[prop.stable_id]={"damage":prop.broken,"visible":prop.visible,"fuse_glow":prop.fuse_material.emission_energy_multiplier if prop.fuse_material != null and prop.fuse>0 else 0.0}
		if prop is TrafficCar:
			traffic_states.append(prop.snapshot())
			visual[prop.stable_id].wheel_phase=prop.wheel_phase
			visual[prop.stable_id].brake_lights=prop.brake_lights
	for key in skater.body_parts:
		var body: Node3D=skater.body_parts[key]
		if not is_instance_valid(body): continue
		var id: String="rider/"+str(key)
		actors[id]=body.global_transform; present[id]=true
	for actor in replay_actors: transforms.append(actor.global_transform if is_instance_valid(actor) else Transform3D.IDENTITY)
	var state: Dictionary={"actors":actors,"present":present,"visual":visual,"transforms":transforms,"camera":camera.global_transform,"fov":camera.fov,"time":crash_clock,"score":rules.score,"speed":skater.speed(),"damage":damage_states,"limbs":rules.limb_damage.duplicate(),"traffic":traffic_states,"boosts":boosts}
	if replay_timeline.capture_actors(crash_clock,state):
		if not replay_frames.is_empty() and is_equal_approx(float(replay_frames.back().time),crash_clock): replay_frames[replay_frames.size()-1]=state
		else: replay_frames.append(state)

func start_replay() -> void:
	if not action_allowed("replay") or not replay_timeline.can_play(): return
	_cancel_held_actions()
	replay_live_camera={"transform":camera.global_transform,"fov":camera.fov,"style":camera_style,"target":camera_target,"shake":camera_shake,"policy":camera_policy}
	replay_live_claims=hud.claim_entries.duplicate(true)
	replay_receipt_cursor=0; hud.claim_entries.clear()
	phase=Phase.REPLAY; replay_clock=0; camera_style=0; camera_policy=CrashCameraPolicy.new()
	hud.results.visible=false; hud.live_chrome.visible=true; hud.replay_banner.visible=true
	Engine.time_scale=1.0; time_rate=1
	hud.power_panel.visible=false; freeze_actors()
	replay_visibility.clear()
	for prop in world.props:
		if is_instance_valid(prop): replay_visibility[prop]=prop.visible; prop.visible=false
	for particle in particles:
		if is_instance_valid(particle.mesh): replay_visibility[particle.mesh]=particle.mesh.visible; particle.mesh.visible=false
	replay_visibility[skater]=skater.visible; skater.visible=false; skater.set_process(false)
	replay_presentation.create(level_root,replay_catalog,{"hat_index":selected_hat,"offsets":skater.offsets})
	replay_sample=replay_timeline.sample_actors(0); replay_presentation.apply(replay_sample)
	sound.set_replay_audio(true)
	hud.toast("CINEMATIC REPLAY / C CHANGE VIEW")

func dispose_replay() -> void:
	if not replay_live_camera.is_empty() and is_instance_valid(camera):
		camera.global_transform=replay_live_camera.transform; camera.fov=replay_live_camera.fov
		camera_style=replay_live_camera.style; camera_target=replay_live_camera.target; camera_shake=replay_live_camera.shake
		camera_policy=replay_live_camera.policy
		if is_instance_valid(hud): hud.claim_entries=replay_live_claims.duplicate(true)
	replay_live_camera.clear(); replay_live_claims.clear()
	replay_presentation.dispose()
	for actor in replay_visibility:
		if is_instance_valid(actor): actor.visible=bool(replay_visibility[actor])
	replay_visibility.clear(); replay_sample.clear()
	if is_instance_valid(skater): skater.set_process(true)
	if is_instance_valid(sound): sound.set_replay_audio(false)

func _exit_tree() -> void:
	dispose_replay()
	ReplayPresentation.dispose_catalog(replay_catalog)
	Engine.time_scale=1.0

func _process(delta: float) -> void:
	presentation_delta = wall_clock.sample(is_paused)
	if is_paused or not is_instance_valid(skater): return
	var real_delta: float = presentation_delta
	impact_left=maxf(0,impact_left-real_delta); impact_cooldown=maxf(0,impact_cooldown-real_delta)
	boost_cooldown=maxf(0,boost_cooldown-real_delta); cascade_focus_left=maxf(0,cascade_focus_left-real_delta)
	if phase==Phase.CRASH: crash_real_clock+=real_delta
	apply_time_rate()
	if phase==Phase.REPLAY:
		replay_clock+=real_delta*.72
		if replay_clock>=replay_timeline.duration:
			_cancel_held_actions(); dispose_replay()
			phase=Phase.RESULTS; hud.replay_banner.visible=false; hud.show_results(rules,level_index,result_was_best)
		else:
			replay_sample=replay_timeline.sample_actors(replay_clock)
			replay_presentation.apply(replay_sample)
			if camera_style==0:
				var recorded: Dictionary=replay_timeline.sample_camera(replay_clock)
				camera.global_transform=recorded.transform; camera.fov=recorded.fov
			else: update_camera(real_delta)
			hud.update_game(rules,"REPLAY",replay_sample.speed,0,replay_sample.boosts,0,false)
			while replay_receipt_cursor<replay_events.size() and float(replay_events[replay_receipt_cursor].time)<=replay_clock:
				var event: Dictionary=replay_events[replay_receipt_cursor]
				var label: String=Rules.limb_title(event.part) if event.type=="injury" else str(event.part).to_upper()
				hud.claim_event(label,event.payout,event.type=="injury")
				replay_receipt_cursor+=1
			hud.score_label.text="$"+Rules.money(replay_sample.score)
		return
	update_camera(real_delta)
	update_aim_marker()
	update_particles(delta)
	var speed:float=skater.speed() if skater.ragdoll else run_speed
	hud.update_game(rules,Phase.keys()[phase],speed,charge,boosts,16.0-crash_clock,slow_motion)
	sound.update_roll(speed,phase==Phase.RUN)
	sound.update_traffic(world.traffic if is_live() else [],skater.focus_position())
	if capture_mode: capture_progress()

func overview_position() -> Vector3:
	var l:Dictionary=Rules.LEVELS[level_index]
	return Vector3(23,l.steps*l.rise+27,l.steps*l.run*.58+18)

func update_camera(delta: float) -> void:
	if phase==Phase.MENU:
		camera.position=overview_position()+Vector3(sin(Time.get_ticks_msec()*.00014)*1.8,0,0)
		camera.look_at(camera_target); return
	var target:Vector3=replay_presentation.focus_position() if phase==Phase.REPLAY else skater.presentation_focus_position()
	var view: int=camera_style-1 if phase==Phase.REPLAY else camera_style
	var desired:Vector3
	var focus:Vector3=target+Vector3(0,0,3.5)
	if phase==Phase.READY:
		desired=target+Vector3(7,4.5,-9)
		focus=target+Vector3(0,-.4,4.0)
	elif view==0:
		desired=target+Vector3(8.0,6.5,-10.5)
	elif view==1:
		desired=target+Vector3(17.0,10.0,8.0); focus=target
	else:
		desired=target+Vector3(0,22,4); focus=target
	if phase==Phase.CRASH and view==0:
		focus=target+Vector3(0,-.25,1)
		desired=target+Vector3(5.8,3.4,-6.8)
		if cascade_focus_left>0 and target.distance_to(cascade_focus)<10:
			focus=focus.lerp(cascade_focus,.25)
		if impact_left>0: desired=target+Vector3(4.8,2.8,-5.8)
		# The second act follows a verified traffic handoff, never random traffic.
		var end_z: float = Rules.LEVELS[level_index].steps*Rules.LEVELS[level_index].run
		if cascade_focus_left>0 and cascade_focus.z>end_z and not traffic_edges.is_empty():
			focus=target.lerp(cascade_focus,.72)
			desired=focus+Vector3(8.5,6.2,-11)
		elif target.z>end_z-6 and boosts>0:
			focus=target+Vector3(0,.2,5)
			desired=target+Vector3(7.0,5.8,-9)
	if phase==Phase.RESULTS:
		desired=target+Vector3(12,10,-14); focus=target
	var context: Dictionary={"space":get_world_3d().direct_space_state,"mask":3,"floor_height":camera_floor}
	if phase==Phase.REPLAY: context=replay_presentation.query_context(get_world_3d().direct_space_state,camera_floor)
	camera_shake=move_toward(camera_shake,0,delta*.65)
	var shake:Vector3=Vector3(rng.randf_range(-1,1),rng.randf_range(-1,1),0)*camera_shake if phase!=Phase.REPLAY else Vector3.ZERO
	var placement: Dictionary=camera_policy.update(Phase.keys()[phase],view,focus,desired,delta,context,camera.global_transform,camera.fov,58+clampf(run_speed,0,31)*.34 if phase==Phase.RUN else 52,shake)
	camera.global_transform=placement.transform; camera.fov=placement.fov; camera_target=placement.target
	camera_diagnostic=placement.diagnostic; camera_diagnostic.safe=placement.safe
	if phase in [Phase.RUN,Phase.CRASH]:
		last_camera_sample={"time":run_clock+crash_clock,"transform":camera.global_transform,"fov":camera.fov}
		if phase==Phase.CRASH: replay_timeline.capture_camera(crash_clock,camera.global_transform,camera.fov)

func camera_floor(at: Vector3) -> float:
	return Rules.surface_y(Rules.LEVELS[level_index],at.z)

func build_aim_marker() -> void:
	aim_marker=Node3D.new(); level_root.add_child(aim_marker)
	for i in 5:
		var mesh:=MeshInstance3D.new(); var ball:=SphereMesh.new(); ball.radius=.10+i*.018; ball.height=ball.radius*2; mesh.mesh=ball
		var mat:=StandardMaterial3D.new(); mat.albedo_color=WreckHUD.MINT; mat.emission_enabled=true; mat.emission=WreckHUD.MINT; mat.emission_energy_multiplier=.7; mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED; mesh.material_override=mat
		aim_marker.add_child(mesh)

func update_aim_marker() -> void:
	if not is_instance_valid(aim_marker): return
	aim_marker.visible=phase==Phase.CRASH and boosts>0
	if not aim_marker.visible: return
	var start: Vector3=skater.focus_position()
	var direction: Vector3=boost_direction()
	for i in aim_marker.get_child_count():
		var t: float=(i+1)*.42
		aim_marker.get_child(i).global_position=start+direction*t*3.0+Vector3(0,.9+sin(t)*.9,0)

func burst(at: Vector3, color: Color, count: int, speed: float) -> void:
	if test_mode or DisplayServer.get_name()=="headless": return
	for i in count:
		var mesh:=MeshInstance3D.new(); var shape:=BoxMesh.new(); shape.size=Vector3.ONE*rng.randf_range(.05,.16); mesh.mesh=shape
		var mat:=StandardMaterial3D.new(); mat.albedo_color=color; mat.emission_enabled=true; mat.emission=color; mat.emission_energy_multiplier=.4; mesh.material_override=mat
		level_root.add_child(mesh); mesh.global_position=at
		var velocity:Vector3=Vector3(rng.randf_range(-1,1),rng.randf_range(.1,1.3),rng.randf_range(-1,1)).normalized()*rng.randf_range(speed*.5,speed)
		particles.append({"mesh":mesh,"velocity":velocity,"life":rng.randf_range(.4,1.1)})

func update_particles(delta: float) -> void:
	for i in range(particles.size()-1,-1,-1):
		var p:Dictionary=particles[i]
		p.life-=delta
		if p.life<=0 or not is_instance_valid(p.mesh):
			if is_instance_valid(p.mesh): p.mesh.queue_free()
			particles.remove_at(i); continue
		p.velocity.y-=12*delta
		p.mesh.position+=p.velocity*delta
		p.mesh.rotation+=Vector3(3,1,2)*delta
		p.mesh.scale=Vector3.ONE*minf(1,p.life*4)

func capture_progress() -> void:
	var name:String=""
	if phase==Phase.READY and charge>.25: name="level_%d_ready" % (level_index+1)
	if phase==Phase.RUN and skater.position.z>0: name="level_%d_run" % (level_index+1)
	if phase==Phase.CRASH and crash_clock>4: name="level_%d_crash" % (level_index+1)
	if phase==Phase.RESULTS: name="level_%d_results" % (level_index+1)
	if name!="" and not capture_flags.has(name):
		capture_flags[name]=true
		capture_frame.call_deferred(name)
		if phase==Phase.RESULTS:
			print("CAPTURE_RESULT ",level_index," ",rules.score," props=",rules.destroyed," explosions=",rules.explosions)
			get_tree().create_timer(.7).timeout.connect(func(): get_tree().quit())

func capture_frame(filename: String) -> void:
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(capture_dir))
	var image:Image=get_viewport().get_texture().get_image()
	image.save_png(capture_dir+"/"+filename+".png")
