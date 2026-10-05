extends SceneTree

# External bookkeeping fixture: load the candidate's real scene/service as res://.
# It uses ordinary startup and selected isolated storage, never test/self-check mode.
var checks := 0
var failures := 0
var probe_case := ""
var selected_records := ""

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--probe-case="):
			probe_case = argument.trim_prefix("--probe-case=")
		elif argument.begins_with("--records-path="):
			selected_records = argument.trim_prefix("--records-path=")
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: packaged records: ", message)

func run() -> void:
	check(selected_records.is_absolute_path(), "isolated absolute records override supplied")
	var scene: PackedScene = load("res://scenes/main.tscn")
	check(scene != null, "real main scene loads from candidate PCK")
	if scene == null:
		finish()
		return
	var game: Node = scene.instantiate()
	root.add_child(game)
	check(not game.test_mode and not game.self_check and not game.automate and not game.capture_mode, "ordinary presentation/storage startup remains selected")
	check(game.records_path_source == "cli" and game.startup_records_read_path == selected_records, "first real startup read uses selected isolated override")
	check(game.records_store.selected_path == selected_records, "packaged record service uses selected override")
	match probe_case:
		"write":
			check(game.fund_total() == 0 and not game.records_store.pending_save, "fresh normal startup has no invented funding/pending state")
			game.best_scores[0] = 100000
			game.muted = true
			game.selected_hat = 2
			check(game.save_records(), "controlled claim/preferences commit to actual selected storage")
			check(game.fund_total() == 100000 and game.last_money_secured == 100000, "durable contribution acknowledges exact controlled claim")
			check(not game.records_store.pending_save and game.records_store.session_candidate == game.records_store.durable_snapshot, "successful snapshot has no pending candidate")
		"verify":
			verify_state(game, [100000, 0, 0], [0, 0, 0], 100000, true, 2)
		"failed-retry":
			check(not DirAccess.dir_exists_absolute(selected_records.get_base_dir()), "failure destination has a genuinely missing parent")
			game.best_scores[1] = 150000
			game.muted = true
			game.selected_hat = 2
			check(not game.save_records(), "actual missing parent rejects write")
			check(game.records_store.pending_save and game.best_scores == [0,150000,0], "complete controlled claim remains available in pending session")
			check(game.fund_total() == 0 and game.last_money_secured == 0 and not game.last_goal_crossed, "failed storage acknowledges no secured money or funded event")
			check(not FileAccess.file_exists(selected_records), "failed write creates no authoritative profile")
			check(DirAccess.make_dir_recursive_absolute(selected_records.get_base_dir()) == OK, "repair only selected isolated parent")
			game.retry_records()
			check(game.fund_total() == 150000 and game.last_money_secured == 150000, "one explicit retry commits exactly one contribution")
			check(not game.records_store.pending_save, "retry clears pending after durable readback")
			game.retry_records()
			check(game.last_money_secured == 0 and game.fund_total() == 150000, "second retry cannot duplicate contribution")
		"verify-failed-retry":
			verify_state(game, [0,150000,0], [0,0,0], 150000, true, 2)
		"migrate":
			verify_state(game, [0,0,0], [111,222,333], 0, true, 1)
			game.best_scores[2] = 250000
			check(game.save_records(), "normal packaged v1 migration commits v2 upon explicit changed candidate")
			check(game.fund_total() == 250000 and game.last_money_secured == 250000, "legacy receipts are never credited as current contribution")
		"verify-migrate":
			verify_state(game, [0,0,250000], [111,222,333], 250000, true, 1)
		"unsupported":
			var preserved := FileAccess.get_file_as_bytes(selected_records)
			check(game.records_store.load_state == "unsupported" and game.fund_total() == 0, "future profile remains protected without invented money")
			game.muted = true
			game.selected_hat = 2
			check(not game.save_records() and game.records_store.pending_save, "future profile keeps preferences usable and pending")
			check(FileAccess.get_file_as_bytes(selected_records) == preserved, "future profile bytes survive normal packaged save request exactly")
		_:
			check(false, "known probe case required")
	print("PACKAGED_RECORDS_STATE: ", JSON.stringify({"case":probe_case,"selected_path":game.records_store.selected_path,
		"read_path":game.startup_records_read_path,"best_scores":game.best_scores,"legacy_scores":game.legacy_scores,
		"durable_total":game.fund_total(),"session_total":game.records_store.session_fund_total(),
		"pending":game.records_store.pending_save,"muted":game.muted,"hat":game.selected_hat,
		"status":game.records_store.records_status,"test_mode":game.test_mode,"self_check":game.self_check}))
	game.queue_free()
	await process_frame
	await process_frame
	finish()

func verify_state(game: Node, scores: Array, legacy: Array, total: int, muted: bool, hat: int) -> void:
	check(game.best_scores == scores and game.legacy_scores == legacy, "cold packaged startup loads actual durable current/legacy route scores")
	check(game.fund_total() == total and game.records_store.session_fund_total() == total, "cold durable/session totals agree")
	check(not game.records_store.pending_save and game.records_store.pending_candidate.is_empty(), "cold startup has no fabricated pending state")
	check(game.muted == muted and game.selected_hat == hat, "cold packaged startup restores actual mute/hat preferences")
	check(game.last_money_secured == 0 and not game.last_goal_crossed, "restart cannot acknowledge old contribution as newly secured")

func finish() -> void:
	print("PACKAGED_RECORDS: %d checks, %d failures; case=%s; external bookkeeping fixture" % [checks, failures, probe_case])
	quit(1 if failures else 0)
