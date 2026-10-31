extends SceneTree

const TestFixtures = preload("res://tests/test_fixtures.gd")
var fixtures = TestFixtures.new("test_playability")

var checks: int = 0
var failures: int = 0
var game: Node3D
var reports: Array[Dictionary] = []
var report: Dictionary = {"purpose":"Objective physical playability proxies; not evidence of human enjoyment.","routes":[],"poses":[],"boosts":{},"checks":0,"failures":0}

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: ",message)

func frames(count: int) -> void:
	for frame in count: await physics_frame

func key(code: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	game._unhandled_input(event)

func held_key(code: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _initialize() -> void:
	call_deferred("run")

func first_events(kind: String) -> Array[String]:
	var result: Array[String] = []
	for event in game.claim_events:
		if kind.is_empty() or event.type == kind:
			result.append(str(event.type)+":"+str(event.part))
			if result.size() == 5: break
	return result

func physical_run(route: int, lane: float, pose: int, player_input: bool = false) -> Dictionary:
	game._replace_route(route)
	game.start_ready()
	if player_input:
		held_key(KEY_1+pose,true); held_key(KEY_1+pose,false)
		var lane_key: int=KEY_A if lane<game.skater.position.x else KEY_D
		held_key(lane_key,true)
		var lane_ticks: int=0
		while absf(game.skater.position.x-lane)>.05 and lane_ticks<250:
			await frames(1); lane_ticks+=1
		held_key(lane_key,false)
		check(absf(game.skater.position.x-lane)<=.05,"player keys select the chosen mastery lane")
		held_key(KEY_W,true); held_key(KEY_SPACE,true)
		var charge_ticks: int=0
		while game.charge<.999 and charge_ticks<200:
			await frames(1); charge_ticks+=1
		check(game.charge>=.999 and game.space_armed,"held Space reaches full charge through actual input")
		held_key(KEY_SPACE,false)
		check(game.phase==game.Phase.RUN,"matched Space release launches the actual player attempt")
	else:
		game.set_pose(pose)
		game.skater.position.x = lane
		game.charge = .75
	var bank_before: int = game.fund_total()
	var best_before: int = game.best_scores[route]
	if not player_input: game.launch()
	var ticks: int = 0
	while game.phase == game.Phase.RUN and ticks < 700:
		await frames(1)
		ticks += 1
	check(game.phase == game.Phase.CRASH,"physical obstacle triggers crash route %d lane %.1f pose %d" % [route,lane,pose])
	if player_input:
		held_key(KEY_W,false)
		check(game.push_count>0,"held W creates actual run-up kicks in the mastery attempt")
	var angle: float = game.skater.torso.rotation.x if game.skater.ragdoll else 0.0
	var crash_frames: int = 0
	while game.phase == game.Phase.CRASH and crash_frames < 3000:
		await frames(1)
		crash_frames += 1
	check(game.phase == game.Phase.RESULTS,"physical run finishes without input route %d lane %.1f pose %d" % [route,lane,pose])
	check(game.rules.property_damage > 0 and game.rules.rider_damage > 0,"both physical property and injury claims exist")
	check(game.claim_events.size() >= 5,"physical run exposes at least five causal claim events")
	check(game.crash_real_clock >= 5.0 and game.crash_real_clock <= 34.2,"crash pacing spans at least five frame-clock seconds and respects the 34-second ceiling")
	check(game.rules.score == game.rules.property_damage + game.rules.rider_damage,"measured physical payout ledger balances")
	check(game.last_money_secured == maxi(0,game.rules.score-best_before),"bank secures only improvement over prior route claim")
	check(game.fund_total() == bank_before + game.last_money_secured,"campaign balance receives the settlement exactly once")
	check(not game.rules.limb_damage.has("board") and not game.skater.damage_states.has("board"),"physical skateboard impacts stay out of injury records")
	for limb in game.rules.limb_damage:
		check(game.rules.limb_damage[limb] >= 0 and game.rules.limb_damage[limb] <= 100,"physical severity remains bounded for "+limb)
	var item: Dictionary = {"route":route+1,"lane":lane,"pose":pose,"score":game.rules.score,"property":game.rules.property_damage,"injury":game.rules.rider_damage,"wrecks":game.rules.destroyed,"explosions":game.rules.explosions,"simulation_seconds":game.crash_clock,"frame_clock_seconds":game.crash_real_clock,"physics_frames":crash_frames,"first_five":first_events(""),"property_first_five":first_events("property"),"injury_first_five":first_events("injury"),"initial_torso_angle":angle,"limbs":game.rules.limb_damage.duplicate(),"secured":game.last_money_secured}
	item["controls"]={"actual_player_input":player_input,"charge":1.0 if player_input else .75,"pushes":game.push_count,"breaker_uses":game.breaker_events.size()}
	var stair_regions: Dictionary = {}
	var stair_times: Array[float] = []
	var stair_sources: Array[String] = []
	for event in game.claim_events:
		var source: String = str(event.get("source", ""))
		if event.type == "injury" and source.begins_with("Tread_"):
			stair_regions[str(event.part)] = true
			stair_times.append(float(event.time))
			stair_sources.append(source)
	var region_names: Array = stair_regions.keys()
	region_names.sort()
	item["stair_injury_regions"] = region_names
	item["stair_impacts"] = stair_times.size()
	item["stair_impact_times"] = stair_times
	item["stair_impact_sources"] = stair_sources
	reports.append(item)
	return item

func replay_and_bank_checks() -> void:
	var final_limbs: Dictionary = game.rules.limb_damage.duplicate()
	var bank: int = game.fund_total()
	var final_score: int = game.rules.score
	check(game.replay_frames.size() > 20,"physical crash records a replay sequence")
	var changed: bool = false
	var first: Dictionary = game.replay_frames[0].limbs
	for frame in game.replay_frames:
		check(frame.has("limbs") and frame.limbs.size() == 11,"replay frame carries complete injury state")
		if frame.limbs != first: changed = true
	check(changed,"injuries evolve across recorded crash frames")
	game.start_replay()
	await frames(20)
	check(game.phase == game.Phase.REPLAY,"recorded crash enters replay")
	var cursor: int=0
	for index in game.replay_frames.size():
		if float(game.replay_frames[index].time)<=game.replay_clock: cursor=index
	check(game.replay_presentation.rider.damage_states == game.replay_frames[cursor].limbs,"isolated replay injury appearance matches its actual recorded timestamp")
	check(game.skater.damage_states == final_limbs,"replay never changes live final limb state")
	var ticks: int = 0
	while game.phase == game.Phase.REPLAY and ticks < 3000:
		await frames(1)
		ticks += 1
	check(game.phase == game.Phase.RESULTS and game.skater.damage_states == final_limbs,"replay returns to final injury appearance")
	check(game.rules.score == final_score and game.fund_total() == bank,"watching recorded claims cannot farm treatment funding")
	game.finish_run()
	check(game.fund_total() == bank,"finishing the same claim twice cannot bank twice")
	game.save_records()
	game.best_scores.assign([0,0,0])
	game.load_records()
	check(game.fund_total() == bank,"campaign best claims survive persistence round trip")
	key(KEY_R,true)
	check(game.phase == game.Phase.READY and not game.skater.ragdoll and game.rules.score == 0,"retry restores play on the same input frame")
	check(game.replay_frames.is_empty() and game.claim_events.is_empty(),"retry clears prior playback and causal events")

func boost_checks() -> void:
	var changes: Array[float] = []
	for side in [-1,1]:
		game._replace_route(0)
		game.start_ready()
		game.set_pose(1)
		game.charge = .5
		game.launch()
		game.bail_out()
		await frames(2)
		held_key(KEY_A if side < 0 else KEY_D,true)
		var direction: Vector3 = game.boost_direction()
		check(direction.is_finite() and direction.x*side > .5,"keyboard aim points toward selected side")
		var before: Vector3 = game.skater.torso.linear_velocity
		key(KEY_SHIFT,true)
		check(game.boosts == 0 and game.breaker_events.size()==1,"first aimed boost consumes the single charge")
		key(KEY_SHIFT,true)
		check(game.boosts == 0 and game.breaker_events.size()==1,"spent resource prevents same-frame boost spam")
		await frames(2)
		var after: Vector3 = game.skater.torso.linear_velocity
		changes.append(after.x-before.x)
		check(after.is_finite() and (after.x-before.x)*side > 2.0,"aim materially changes physical torso velocity toward target side")
		held_key(KEY_A if side < 0 else KEY_D,false)
		await frames(120)
		key(KEY_SHIFT,true)
		check(game.boosts == 0 and game.breaker_events.size()==1,"time and subsequent collisions cannot refill a spent crashbreaker")
		await frames(1)
		var exhausted: Vector3 = game.skater.torso.linear_velocity
		key(KEY_SHIFT,true)
		check(game.boosts == 0 and game.skater.torso.linear_velocity == exhausted,"exhausted boost cannot alter momentum")
		key(KEY_SHIFT,false)
	report.boosts = {"left_velocity_delta":changes[0],"right_velocity_delta":changes[1],"difference":changes[1]-changes[0]}
	check(changes[1]-changes[0] > 4.0,"opposite target choices produce meaningfully different physical impulses")

func run() -> void:
	game = fixtures.create_game(root)
	if game == null: return
	game.best_scores.assign([0,0,0])
	for route in range(3):
		var outcomes: Array[Dictionary] = []
		var scores: Array[int] = []
		var signatures: Dictionary = {}
		var property_signatures: Dictionary = {}
		for lane in [-3.3,0.0,3.3]:
			var outcome: Dictionary = await physical_run(route,lane,0)
			if route == 0 and is_equal_approx(lane, -3.3):
				check(outcome.stair_injury_regions.size() >= 4,"recommended Civic TUCK launch injures at least four body regions against actual stair tread colliders")
				var impact_span: float = 0.0
				if outcome.stair_impact_times.size() >= 2:
					impact_span = float(outcome.stair_impact_times.max()) - float(outcome.stair_impact_times.min())
				check(impact_span > .15,"recommended Civic launch produces successive stair impacts more than 0.15 simulation seconds apart")
				report["stair_reference"] = {"route":1,"lane":lane,"pose":0,"charge":.75,"boosts_used":0,"regions":outcome.stair_injury_regions,"impacts":outcome.stair_impacts,"impact_span_simulation_seconds":impact_span}
			outcomes.append(outcome)
			scores.append(outcome.score)
			signatures[JSON.stringify(outcome.first_five)] = true
			property_signatures[JSON.stringify(outcome.property_first_five)] = true
		var variation: float = float(scores.max()-scores.min())/maxf(1,float(scores.max()))
		check(signatures.size() >= 2,"starting lane changes the first five causal events on route "+str(route+1))
		check(property_signatures.size() >= 2,"starting lane changes the physical property handoff sequence on route "+str(route+1))
		check(variation >= .15,"starting lane changes payout by at least fifteen percent on route "+str(route+1))
		report.routes.append({"route":route+1,"payout_variation":variation,"distinct_event_sequences":signatures.size(),"runs":outcomes})
	report["coasting_best_claim_sum"] = game.fund_total()
	var mastery: Array[Dictionary]=[]
	for route in 3: mastery.append(await physical_run(route,0.0,1 if route==0 else 0,true))
	report["mastery_runs"]=mastery
	report["full_charge_best_claim_sum"] = game.fund_total()
	var poses: Array[Dictionary] = []
	for pose in range(3): poses.append(await physical_run(0,0.0,pose))
	for a in range(3):
		for b in range(a+1,3):
			check(absf(poses[a].initial_torso_angle-poses[b].initial_torso_angle) > .05,"bail poses have distinct physical torso orientations %d vs %d" % [a,b])
	var injury_patterns: Dictionary = {}
	for pose in poses: injury_patterns[JSON.stringify(pose.limbs)] = true
	check(injury_patterns.size() >= 2,"pose selection changes measured body-region injuries on the same launch line")
	var injury_difference: float = 0.0
	for limb in poses[0].limbs:
		injury_difference += absf(float(poses[0].limbs[limb])-float(poses[1].limbs[limb]))
	check(injury_difference >= 20.0,"tuck versus starfish redistributes at least twenty measured injury-severity points")
	report["tuck_starfish_injury_difference"] = injury_difference
	report.poses = poses
	# All demonstrated unassisted choices count toward route mastery. A partial
	# charge with a different pose can beat the full-charge approach above.
	var unassisted_best_sum: int = game.fund_total()
	report["unassisted_best_claim_sum"] = unassisted_best_sum
	report["treatment_goal"] = WreckRules.TREATMENT_GOAL
	check(unassisted_best_sum >= WreckRules.TREATMENT_GOAL,"measured unassisted route claims can reach treatment funding")
	await replay_and_bank_checks()
	await boost_checks()
	report.checks = checks
	report.failures = failures
	var file := FileAccess.open(fixtures.artifact_path("playability_report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	game.unpause()
	game.queue_free()
	await process_frame
	await process_frame
	game = null
	print("PLAYABILITY: ",checks," checks, ",failures," failures; report ",fixtures.artifact_path("playability_report.json"))
	quit(1 if failures else 0)
