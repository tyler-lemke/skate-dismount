extends SceneTree

const Store = preload("res://scripts/records_store.gd")
const Fixtures = preload("res://tests/test_fixtures.gd")
var checks: int = 0
var failures: int = 0
var fixture_root: String

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: ", message)

func write_bytes(path: String, bytes: PackedByteArray) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	check(file != null, "fixture opens "+path.get_file())
	if file == null: return
	check(file.store_buffer(bytes), "fixture writes "+path.get_file())
	file.close()

func fixture(name: String, text: String = "") -> String:
	var path: String = fixture_root+"/"+name+".json"
	if not text.is_empty(): write_bytes(path, text.to_utf8_buffer())
	return path

func start(path: String):
	var store = Store.new(path)
	store.load_records()
	return store

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--records-reopen="):
			reopen(arg.trim_prefix("--records-reopen="))
			return
	var fixtures = Fixtures.new("records")
	if not fixtures.error.is_empty():
		check(false, fixtures.error)
		print("RECORDS: ",checks," checks, ",failures," failures")
		quit(1); return
	fixture_root = fixtures.directory.path_join("records_service")
	check(DirAccess.make_dir_recursive_absolute(fixture_root) == OK, "isolated fixture parent exists")
	print("records fixture: ",fixture_root)
	schema_cases()
	protection_cases()
	failure_cases()
	recovery_cases()
	inaccessible_case()
	changed_primary_cases()
	reopen_cases()
	print("RECORDS: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)

func schema_cases() -> void:
	var missing = start(fixture("missing"))
	check(missing.load_state == "missing" and missing.fund_total() == 0, "absent primary is a clean first run")
	var valid = start(fixture("v2", '{"version":2,"best_scores":[123,456,789],"legacy_scores":[9,8,7],"muted":true,"hat":2}'))
	check(valid.durable_snapshot.best_scores == [123,456,789] and valid.fund_total() == 1368, "v2 complete candidate loads independently known scores")
	check(valid.durable_snapshot.legacy_scores == [9,8,7] and valid.session_candidate.muted and valid.session_candidate.hat == 2, "v2 preference and historical values load")
	var legacy = start(fixture("v1", '{"version":1,"best_scores":[700000,800000,900000],"legacy_scores":[4,5,6],"muted":true,"hat":1}'))
	check(legacy.fund_total() == 0 and legacy.durable_snapshot.legacy_scores == [700000,800000,900000], "v1 optional historical field cannot replace migrated bests")
	var implicit = start(fixture("implicit_v1", '{"best_scores":[11.0,22,33]}'))
	check(implicit.load_state == "loaded" and implicit.durable_snapshot.legacy_scores == [11,22,33] and implicit.fund_total() == 0, "missing version is established v1 and numeric integral JSON is accepted")
	var optional = start(fixture("optional", '{"version":2,"best_scores":[0,999999999,12.0],"legacy_scores":[1,{},3],"muted":"yes","hat":[]}'))
	check(optional.durable_snapshot.best_scores == [0,999999999,12] and optional.durable_snapshot.legacy_scores == [0,0,0], "malformed optional legacy does not invalidate boundary current scores")
	check(not optional.session_candidate.muted and optional.session_candidate.hat == 0, "malformed optional preferences safely default")
	var legacy_optional = start(fixture("v1_optional", '{"best_scores":[1,2,3],"legacy_scores":{},"muted":42,"hat":"2"}'))
	check(legacy_optional.durable_snapshot.legacy_scores == [1,2,3] and legacy_optional.fund_total() == 0, "malformed v1 optional data cannot discard historical scores")
	var invalid_values: Array[String] = ['{}','[]','"123"','true','null','1.5','-1','1000000000','1e400']
	for value in invalid_values:
		for position in 3:
			var values: Array[String] = ["123","456","789"]
			values[position] = value
			var bad = start(fixture("score_"+str(invalid_values.find(value))+"_"+str(position), '{"version":2,"best_scores":['+','.join(values)+']}'))
			check(bad.load_state == "corrupt" and bad.durable_snapshot.best_scores == [0,0,0] and bad.durable_snapshot.legacy_scores == [0,0,0], "invalid required score "+value+" at "+str(position)+" never partly loads")
	for version in ['"2"','true','null','{}','2.5']:
		var bad_version = start(fixture("version_"+str(checks), '{"version":'+version+',"best_scores":[1,2,3]}'))
		check(bad_version.load_state == "corrupt", "malformed version never coerces to supported schema")
	for body in ['{"version":2}', '{"version":2,"best_scores":[1,2]}', '{"version":2,"best_scores":[1,2,3,4]}', '[]', '{"version":2,']:
		var malformed = start(fixture("malformed_"+str(checks), body))
		check(malformed.load_state == "corrupt" and malformed.fund_total() == 0, "malformed required candidate is protected")
	var unchanged: Dictionary = valid.durable_snapshot.duplicate(true)
	check(not valid.commit({"version":2,"best_scores":[1,{},3]}).ok and valid.durable_snapshot == unchanged, "invalid complete commit cannot partly mutate active scores")

func protection_cases() -> void:
	var future_text: String = '{"version":99,"best_scores":[123,456,789],"unknown":{"keep":"all bytes"}}\n'
	var future_path: String = fixture("future", future_text)
	var future = start(future_path)
	check(future.load_state == "unsupported" and future.protected_original_path == future_path, "unsupported profile is explicit and protected")
	check(not future.set_preferences(true,2).ok and not future.record_claim(0,200000).ok and not future.retry().ok, "preference, claim, and retry cannot downgrade unsupported data")
	check(not future.recover_fresh().ok and not future.recover_backup().ok, "future data has no reset/recovery operation")
	check(FileAccess.get_file_as_bytes(future_path) == future_text.to_utf8_buffer() and future.pending_save and future.session_fund_total() == 200000 and future.fund_total() == 0, "future bytes stay exact while session progress remains pending")
	var corrupt_path: String = fixture("corrupt", '{"version":2,"best_scores":[123,{},456]}')
	var original: PackedByteArray = FileAccess.get_file_as_bytes(corrupt_path)
	var corrupt = start(corrupt_path)
	check(not corrupt.set_preferences(true,1).ok and not corrupt.record_claim(2,42).ok and not corrupt.retry().ok, "ordinary actions cannot replace corrupt required-score data")
	check(FileAccess.get_file_as_bytes(corrupt_path) == original and corrupt.session_fund_total() == 42 and corrupt.fund_total() == 0, "corrupt original and earned session progress are retained")
	var stale_path: String = fixture("stale")
	write_bytes(stale_path+".tmp.stale", '{"version":2,"best_scores":[600000,0,0]}'.to_utf8_buffer())
	var stale = start(stale_path)
	check(stale.load_state == "missing" and stale.fund_total() == 0, "uncommitted leftover temp is never selected as funding")
	write_bytes(stale_path+".bak", '{"version":2,"best_scores":[100000,0,0]}'.to_utf8_buffer())
	var backup_only = start(stale_path)
	check(backup_only.load_state == "recoverable" and backup_only.fund_total() == 0 and backup_only.backup_candidate.best_scores == [100000,0,0], "missing primary with valid backup requires explicit recovery")

func failure_cases() -> void:
	for stage in ["temp_open","temp_write","temp_verify","after_temp_verify","backup_copy","backup_replace","backup_readback","replace"]:
		var path: String = fixture("failure_"+stage, '{"version":2,"best_scores":[100000,0,0],"muted":false,"hat":0}')
		var original: PackedByteArray = FileAccess.get_file_as_bytes(path)
		var store = start(path)
		store.inject_failure(stage)
		var result: Dictionary = store.record_claim(0,200000)
		check(not result.ok and store.pending_save and result.session_improvement == 100000, stage+" retains earned session improvement")
		check(store.fund_total() == 100000 and store.session_fund_total() == 200000 and store.consume_contribution_event().is_empty(), stage+" withholds acknowledgment and contribution")
		check(FileAccess.get_file_as_bytes(path) == original and start(path).fund_total() == 100000, stage+" leaves independently reloadable old primary exact")
		store.set_preferences(true,2)
		check(store.fund_total() == 200000 and not store.pending_save and store.session_candidate.muted and store.session_candidate.hat == 2, stage+" preference action retries complete pending claim and preferences")
		check(FileAccess.get_file_as_bytes(path+".bak") == original, stage+" successful retry retains exact validated prior primary as backup")
		var event: Dictionary = store.consume_contribution_event()
		check(event.get("amount") == 100000 and not event.get("goal_crossed",true), stage+" emits exactly the earned durable increase")
		check(store.retry().ok and store.retry().ok and store.consume_contribution_event().is_empty(), stage+" repeated retry never credits twice")
		check(start(path).durable_snapshot.best_scores == [200000,0,0] and start(path).session_candidate.muted, stage+" saved state reloads with preferences")
	var uncertain_path: String = fixture("uncertain", '{"version":2,"best_scores":[400000,0,0]}')
	var uncertain = start(uncertain_path)
	uncertain.inject_failure("readback")
	var failed: Dictionary = uncertain.record_claim(1,200000)
	check(not failed.ok and failed.status == "uncertain" and uncertain.fund_total() == 400000 and uncertain.pending_save, "successful replace with failed readback remains uncertain and unacknowledged")
	check(start(uncertain_path).durable_snapshot.best_scores == [400000,200000,0] and FileAccess.file_exists(uncertain_path+".bak"), "uncertain replace leaves complete written primary plus previous backup")
	uncertain.inject_failure("replace",-1)
	check(uncertain.retry().ok and uncertain.fund_total() == 600000 and not uncertain.pending_save, "retry recognizes already written candidate before attempting another replace")
	var crossing: Dictionary = uncertain.consume_contribution_event()
	check(crossing.get("amount") == 200000 and crossing.get("goal_crossed",false), "reconciled goal crossing contributes once")
	check(uncertain.retry().ok and uncertain.consume_contribution_event().is_empty(), "second uncertain retry emits no repeated crossing")
	uncertain.failure_injections.clear()
	check(uncertain.record_claim(1,100000).ok and uncertain.fund_total() == 600000 and uncertain.consume_contribution_event().is_empty(), "weaker later claim never lowers saved maxima or contributes")
	var missing_parent: String = fixture_root+"/absent_parent/record.json"
	var inaccessible = start(missing_parent)
	var pending: Dictionary = inaccessible.record_claim(0,200000)
	check(not pending.ok and inaccessible.load_state == "inaccessible" and inaccessible.fund_total() == 0 and inaccessible.session_fund_total() == 200000, "missing selected parent stays visible, session-only, and does not fall back")
	check(DirAccess.make_dir_recursive_absolute(missing_parent.get_base_dir()) == OK and inaccessible.retry().ok, "repairing selected parent permits explicit retry")
	check(inaccessible.consume_contribution_event().get("amount") == 200000 and inaccessible.retry().ok and inaccessible.consume_contribution_event().is_empty(), "repaired storage acknowledges one pending contribution")
	var edited_path: String = fixture("uncertain_preferences", '{"version":2,"best_scores":[400000,0,0],"hat":0,"muted":false}')
	var edited = start(edited_path)
	edited.inject_failure("readback")
	edited.record_claim(1,200000)
	check(edited.set_preferences(true,2).ok and edited.fund_total() == 600000 and edited.session_candidate.muted and edited.session_candidate.hat == 2, "preference update after uncertain claim acknowledges written money and commits newer preferences")
	check(edited.consume_contribution_event().get("amount") == 200000 and edited.consume_contribution_event().is_empty() and edited.retry().ok, "uncertain preference continuation queues exactly one contribution")

func recovery_cases() -> void:
	var path: String = fixture("recovery", 'truncated primary bytes')
	var original: PackedByteArray = FileAccess.get_file_as_bytes(path)
	var backup_bytes: PackedByteArray = '{"version":2,"best_scores":[500000,0,0],"muted":true,"hat":2}'.to_utf8_buffer()
	write_bytes(path+".bak", backup_bytes)
	var store = start(path)
	check(store.load_state == "recoverable" and not store.recover_fresh().ok, "valid backup is offered without permitting fresh reset")
	store.record_claim(0,550000)
	store.inject_failure("quarantine_copy")
	check(not store.recover_backup().ok and FileAccess.get_file_as_bytes(path) == original and store.fund_total() == 0, "failed preservation prevents backup replacement and acknowledgment")
	store.inject_failure("quarantine_verify")
	check(not store.recover_backup().ok and FileAccess.get_file_as_bytes(path) == original, "unverified preservation prevents replacement")
	store.inject_failure("readback")
	var recovery: Dictionary = store.recover_backup()
	check(not recovery.ok and recovery.status == "uncertain" and store.fund_total() == 0 and store.pending_candidate.best_scores == [550000,0,0], "recovery readback failure retains merged candidate and restored contribution baseline")
	check(FileAccess.get_file_as_bytes(store.quarantine_path) == original and start(path).fund_total() == 550000, "rejected primary is uniquely preserved and replacement is complete")
	check(FileAccess.get_file_as_bytes(path+".bak") == backup_bytes, "recovery never rotates corrupt primary bytes over the valid backup")
	check(store.retry().ok and store.fund_total() == 550000, "uncertain backup recovery reconciles written result")
	var recovered_event: Dictionary = store.consume_contribution_event()
	check(recovered_event.get("amount") == 50000 and not recovered_event.get("goal_crossed",true), "restored 500000 is baseline and only 50000 new earnings contribute")
	check(store.session_candidate.muted and store.session_candidate.hat == 2 and store.retry().ok and store.consume_contribution_event().is_empty(), "backup preferences survive and second recovery retry has no event")
	cold_case(path,"recovery")
	var funded_path: String = fixture("funded_backup", '{bad')
	write_bytes(funded_path+".bak", '{"version":2,"best_scores":[100000,500000,0]}'.to_utf8_buffer())
	var funded = start(funded_path)
	check(funded.recover_backup().ok and funded.fund_total() == 600000 and funded.consume_contribution_event().is_empty(), "already-funded backup restoration emits no new-funded event or earnings")
	cold_case(funded_path,"funded")
	var v1_path: String = fixture("legacy_backup", '{bad')
	write_bytes(v1_path+".bak", '{"version":1,"best_scores":[700000,800000,900000],"muted":true}'.to_utf8_buffer())
	var v1 = start(v1_path)
	v1.record_claim(2,42)
	check(v1.recover_backup().ok and v1.durable_snapshot.best_scores == [0,0,42] and v1.durable_snapshot.legacy_scores == [700000,800000,900000], "v1 backup migration merges session maxima without arcade funding")
	check(v1.consume_contribution_event().get("amount") == 42, "legacy restoration counts only earned current claim")
	cold_case(v1_path,"legacy")
	var fresh_path: String = fixture("fresh", '{"version":2,"best_scores":[{},0,0]}')
	var fresh_original: PackedByteArray = FileAccess.get_file_as_bytes(fresh_path)
	var fresh = start(fresh_path)
	fresh.record_claim(1,123); fresh.set_preferences(true,1)
	check(fresh.recover_fresh().ok and fresh.durable_snapshot.best_scores == [0,123,0] and fresh.session_candidate.muted and fresh.session_candidate.hat == 1, "explicit no-backup fresh recovery retains session claim and preferences")
	check(FileAccess.get_file_as_bytes(fresh.quarantine_path) == fresh_original and fresh.consume_contribution_event().get("amount") == 123, "fresh recovery preserves exact rejected bytes and acknowledges earned contribution")
	check(not fresh.recover_fresh().ok and fresh.retry().ok and fresh.consume_contribution_event().is_empty(), "accepted recovery cannot repeatedly reset or credit")
	cold_case(fresh_path,"fresh")

func inaccessible_case() -> void:
	var path: String = fixture("initially_unreadable", '{"version":2,"best_scores":[100000,500000,0],"legacy_scores":[8,9,10],"muted":true,"hat":2}')
	var store = Store.new(path)
	store.inject_failure("primary_read",-1)
	store.load_records()
	store.record_claim(0,200000)
	check(store.load_state == "inaccessible" and store.fund_total() == 0 and store.session_fund_total() == 200000, "initial read failure preserves session with unknown funding unacknowledged")
	store.failure_injections.clear()
	check(store.retry().ok and store.durable_snapshot.best_scores == [200000,500000,0] and store.fund_total() == 700000, "retry validates newly readable profile before merging session maxima")
	var event: Dictionary = store.consume_contribution_event()
	check(event.get("amount") == 100000 and not event.get("goal_crossed",true), "newly readable already-funded baseline contributes only earned 100000 without new-funded ending")
	check(store.durable_snapshot.legacy_scores == [8,9,10] and store.session_candidate.muted and store.session_candidate.hat == 2, "newly readable preferences and historical data survive untouched defaults")
	check(store.retry().ok and store.consume_contribution_event().is_empty(), "initially inaccessible retry contributes once")

func changed_primary_cases() -> void:
	var path: String = fixture("changed_primary", '{"version":2,"best_scores":[100000,0,0],"legacy_scores":[1,2,3],"muted":false,"hat":0}')
	var store = start(path)
	write_bytes(path, '{"version":2,"best_scores":[500000,0,0],"legacy_scores":[7,8,9],"muted":true,"hat":2}'.to_utf8_buffer())
	check(store.record_claim(0,550000).ok and store.durable_snapshot.best_scores == [550000,0,0], "changed primary is revalidated and merged before committing session claim")
	var event: Dictionary = store.consume_contribution_event()
	check(event.get("amount") == 50000 and not event.get("goal_crossed",true), "newer restored primary is contribution baseline instead of stale loaded 100000")
	check(store.session_candidate.muted and store.session_candidate.hat == 2 and store.durable_snapshot.legacy_scores == [7,8,9], "newer on-disk preferences and historical scores survive when not edited locally")
	var edited_path: String = fixture("changed_primary_edited", '{"version":2,"best_scores":[100000,0,0],"muted":false,"hat":0}')
	var edited = start(edited_path)
	edited.inject_failure("temp_open")
	edited.set_preferences(true,1)
	write_bytes(edited_path, '{"version":2,"best_scores":[100000,500000,0],"muted":false,"hat":2}'.to_utf8_buffer())
	check(edited.record_claim(0,200000).ok and edited.durable_snapshot.best_scores == [200000,500000,0] and edited.session_candidate.muted and edited.session_candidate.hat == 1, "local edited preferences survive newer external funding while route maxima merge")
	var edited_event: Dictionary = edited.consume_contribution_event()
	check(edited_event.get("amount") == 100000 and not edited_event.get("goal_crossed",true), "already-funded changed primary does not produce false newly-funded event")
	var protected_path: String = fixture("changed_primary_corrupt", '{"version":2,"best_scores":[100000,0,0]}')
	var protected = start(protected_path)
	var invalid: PackedByteArray = '{"version":2,"best_scores":[100000,{},0]}'.to_utf8_buffer()
	write_bytes(protected_path, invalid)
	check(not protected.record_claim(0,200000).ok and protected.load_state == "corrupt" and FileAccess.get_file_as_bytes(protected_path) == invalid, "new corruption detected during commit updates recoverable interface and protects original")
	check(protected.recover_fresh().ok and protected.fund_total() == 200000 and FileAccess.get_file_as_bytes(protected.quarantine_path) == invalid, "newly detected corrupt profile can explicitly recover with session claim intact")

func reopen_cases() -> void:
	var path: String = fixture("cold_restart", '{"version":2,"best_scores":[111,222,333],"legacy_scores":[7,8,9],"muted":true,"hat":2}')
	var store = start(path)
	store.inject_failure("replace")
	store.record_claim(2,444)
	cold_case(path,"333")
	check(store.retry().ok and store.consume_contribution_event().get("amount") == 111, "retry commits independent 111 route increase")
	cold_case(path,"444")

func cold_case(path: String, mode: String) -> void:
	var output: Array = []
	var result: int = OS.execute(OS.get_executable_path(), ["--headless","--path",ProjectSettings.globalize_path("res://"),"--log-file",fixture_root+"/cold_"+mode+".log","--script","res://tests/test_records_store.gd","--","--records-reopen="+path+"|"+mode], output, true)
	check(result == 0 and '\n'.join(output).contains("RECORDS_REOPEN: verified "+mode), "fresh process reads independently known "+mode+" scores and preferences without startup earning events")

func reopen(argument: String) -> void:
	var parts: PackedStringArray = argument.split("|")
	if parts.size() != 2:
		quit(1); return
	var store = start(parts[0])
	var correct: bool = store.load_state == "loaded" and not store.pending_save and store.consume_contribution_event().is_empty()
	match parts[1]:
		"333": correct = correct and store.durable_snapshot.best_scores == [111,222,333] and store.durable_snapshot.legacy_scores == [7,8,9] and store.session_candidate.muted and store.session_candidate.hat == 2
		"444": correct = correct and store.durable_snapshot.best_scores == [111,222,444] and store.durable_snapshot.legacy_scores == [7,8,9] and store.session_candidate.muted and store.session_candidate.hat == 2
		"recovery": correct = correct and store.durable_snapshot.best_scores == [550000,0,0] and store.durable_snapshot.legacy_scores == [0,0,0] and store.session_candidate.muted and store.session_candidate.hat == 2
		"funded": correct = correct and store.durable_snapshot.best_scores == [100000,500000,0] and store.durable_snapshot.legacy_scores == [0,0,0] and not store.session_candidate.muted and store.session_candidate.hat == 0
		"legacy": correct = correct and store.durable_snapshot.best_scores == [0,0,42] and store.durable_snapshot.legacy_scores == [700000,800000,900000] and store.session_candidate.muted and store.session_candidate.hat == 0
		"fresh": correct = correct and store.durable_snapshot.best_scores == [0,123,0] and store.durable_snapshot.legacy_scores == [0,0,0] and store.session_candidate.muted and store.session_candidate.hat == 1
		_: correct = false
	if correct: print("RECORDS_REOPEN: verified ",parts[1])
	else: printerr("FAIL: fresh process candidate differed from explicit known values")
	quit(0 if correct else 1)
