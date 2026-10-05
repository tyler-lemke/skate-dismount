extends SceneTree
const Fixtures = preload("res://tests/test_fixtures.gd")
var fixture = Fixtures.new("test_records_game")
var checks: int = 0
var failures: int = 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures += 1; printerr("FAIL: " + message)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var initial: Dictionary = {"version":2,"best_scores":[400000,0,0],"legacy_scores":[0,0,0],"muted":false,"hat":0}
	var game: Node3D = fixture.create_game(root,initial)
	if game == null: return
	game._replace_route(1)
	game.start_ready(); game.charge = .5; game.launch(); game.bail_out()
	var old_bytes: PackedByteArray = FileAccess.get_file_as_bytes(fixture.records_path)
	# The settlement boundary is isolated here; physical scoring has its own real
	# crash suites. This known candidate tests withholding a funded ending on IO failure.
	game.rules.score = 200000
	game.records_store.inject_failure("replace")
	game.finish_run()
	check(game.phase == game.Phase.RESULTS, "save failure still produces a reviewable run report")
	check(game.fund_total() == 400000 and game.best_scores == [400000,200000,0], "session improvement and secured funding are separate")
	check(game.last_money_secured == 0 and not game.last_goal_crossed, "failed write acknowledges no contribution or funded event")
	check(game.records_store.pending_save, "failed complete candidate remains pending")
	check(FileAccess.get_file_as_bytes(fixture.records_path) == old_bytes, "failed replacement preserves primary bytes")
	check(not game.hud.result_title.text.contains("TREATMENT FUNDED"), "failed goal crossing cannot show funded ending")
	game.retry_records()
	check(game.fund_total() == 600000 and game.last_money_secured == 200000 and game.last_goal_crossed, "explicit retry acknowledges the successful goal contribution once")
	check(not game.records_store.pending_save and game.hud.result_title.text == "TREATMENT FUNDED", "acknowledged retry refreshes truthful campaign presentation")
	game.retry_records()
	check(game.last_money_secured == 0 and not game.last_goal_crossed and game.fund_total() == 600000, "repeated retry cannot duplicate contribution or goal crossing")
	game.queue_free()
	await process_frame; await process_frame
	var future: PackedByteArray = '{"version":99,"best_scores":[1,2,3],"unknown":{"keep":"exact"}}\n'.to_utf8_buffer()
	var file := FileAccess.open(fixture.records_path,FileAccess.WRITE)
	file.store_buffer(future); file.close()
	game = fixture.create_game(root,fixture.EMPTY_RECORD,true)
	if game == null: return
	check(game.records_store.load_state == "unsupported" and game.fund_total() == 0, "future-version game boots with protected profile and no invented secured money")
	game.toggle_mute()
	check(game.muted and game.records_store.pending_save, "preference remains usable and pending for protected storage")
	check(FileAccess.get_file_as_bytes(fixture.records_path) == future, "game preference cannot overwrite future profile")
	game.queue_free()
	await process_frame; await process_frame
	print("RECORDS_GAME: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
