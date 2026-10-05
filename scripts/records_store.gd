extends RefCounted
## The primary is authoritative on startup. A .bak is offered for explicit
## recovery; sibling .tmp.* files are never promoted into secured funding.
## Success means a checked rename followed by matching, validated readback.
## Godot exposes no directory fsync; this is not a power-loss durability claim.

const SCORE_MAX: int = 999999999
var selected_path: String
var treatment_goal: int
var load_state: String = "missing"
var records_status: String = "missing"
var diagnostic_code: String = ""
var protected_original_path: String = ""
var quarantine_path: String = ""
var backup_candidate: Dictionary = {}
var durable_snapshot: Dictionary = empty_candidate()
var session_candidate: Dictionary = empty_candidate()
var pending_candidate: Dictionary = {}
var pending_save: bool = false
## Deterministic, opt-in IO failure seams. Normal callers leave this empty.
var failure_injections: Dictionary = {}
var _sequence: int = 0
var _muted_edited: bool = false
var _hat_edited: bool = false
var _uncertain: bool = false
var _attempt_candidate: Dictionary = {}
var _attempt_baseline: Dictionary = {}
var _recovery_authorized: bool = false
var _recovery_baseline: Dictionary = {}
var _events: Array[Dictionary] = []

func _init(path: String, goal: int = 600000) -> void:
	selected_path = ProjectSettings.globalize_path(path)
	treatment_goal = goal

static func empty_candidate() -> Dictionary:
	return {"version":2, "best_scores":[0,0,0], "legacy_scores":[0,0,0], "muted":false, "hat":0}

static func _valid_integer(value: Variant, maximum: int) -> bool:
	if typeof(value) not in [TYPE_INT, TYPE_FLOAT]: return false
	var number: float = float(value)
	return is_finite(number) and number >= 0 and number <= maximum and floor(number) == number

static func _scores(value: Variant) -> Dictionary:
	if not value is Array or value.size() != 3: return {"ok":false}
	var result: Array[int] = []
	for score in value:
		if not _valid_integer(score, SCORE_MAX): return {"ok":false}
		result.append(int(score))
	return {"ok":true, "scores":result}

static func validate(data: Variant) -> Dictionary:
	if not data is Dictionary: return {"ok":false, "state":"corrupt", "code":"root_not_object"}
	var version: Variant = data.get("version", 1)
	if not _valid_integer(version, SCORE_MAX): return {"ok":false, "state":"corrupt", "code":"invalid_version"}
	var version_number: int = int(version)
	if version_number not in [1, 2]: return {"ok":false, "state":"unsupported", "code":"unsupported_version"}
	var required: Dictionary = _scores(data.get("best_scores"))
	if not required.ok: return {"ok":false, "state":"corrupt", "code":"invalid_best_scores"}
	var candidate: Dictionary = empty_candidate()
	if version_number == 1:
		candidate.legacy_scores = required.scores
	else:
		candidate.best_scores = required.scores
		var historical: Dictionary = _scores(data.get("legacy_scores"))
		if historical.ok: candidate.legacy_scores = historical.scores
	if typeof(data.get("muted")) == TYPE_BOOL: candidate.muted = data.muted
	if _valid_integer(data.get("hat"), 2): candidate.hat = int(data.hat)
	return {"ok":true, "state":"loaded", "code":"", "candidate":candidate}

func inject_failure(stage: String, count: int = 1) -> void:
	failure_injections[stage] = count

func _fails(stage: String) -> bool:
	var remaining: int = int(failure_injections.get(stage, 0))
	if remaining == 0: return false
	if remaining > 0: failure_injections[stage] = remaining - 1
	return true

func _read(path: String, stage: String = "") -> Dictionary:
	if not stage.is_empty() and _fails(stage): return {"ok":false, "state":"inaccessible", "code":stage+"_failed"}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		var error: int = FileAccess.get_open_error()
		var missing: bool = error == ERR_FILE_NOT_FOUND and DirAccess.dir_exists_absolute(path.get_base_dir()) and not DirAccess.dir_exists_absolute(path)
		return {"ok":false, "state":"missing" if missing else "inaccessible", "code":"missing" if missing else "read_open_"+str(error)}
	var length: int = file.get_length()
	var bytes: PackedByteArray = file.get_buffer(length)
	var error: int = file.get_error()
	file.close()
	if bytes.size() != length or error not in [OK, ERR_FILE_EOF]: return {"ok":false, "state":"inaccessible", "code":"read_failed"}
	var json := JSON.new()
	if json.parse(bytes.get_string_from_utf8()) != OK: return {"ok":false, "state":"corrupt", "code":"invalid_json", "bytes":bytes}
	var result: Dictionary = validate(json.data)
	result["bytes"] = bytes
	return result

func load_records() -> Dictionary:
	var primary: Dictionary = _read(selected_path, "primary_read")
	var backup: Dictionary = _read(selected_path+".bak")
	backup_candidate = backup.candidate.duplicate(true) if backup.ok else {}
	durable_snapshot = empty_candidate()
	if primary.ok: durable_snapshot = primary.candidate.duplicate(true)
	session_candidate = durable_snapshot.duplicate(true)
	pending_candidate = {}; pending_save = false
	_uncertain = false; _recovery_authorized = false
	_attempt_candidate = {}; _attempt_baseline = {}; _recovery_baseline = {}
	_muted_edited = false; _hat_edited = false; _events.clear()
	protected_original_path = ""; quarantine_path = ""
	load_state = primary.state
	if primary.state in ["corrupt", "missing"] and backup.ok: load_state = "recoverable"
	if primary.state in ["corrupt", "inaccessible", "unsupported"]: protected_original_path = selected_path
	records_status = load_state
	diagnostic_code = primary.code
	return _result(primary.ok or load_state == "missing")

func fund_total() -> int:
	return _total(durable_snapshot)

func session_fund_total() -> int:
	return _total(session_candidate)

static func _total(candidate: Dictionary) -> int:
	var amount: int = 0
	for score in candidate.best_scores: amount += int(score)
	return amount

static func _merged(base: Dictionary, earned: Dictionary) -> Dictionary:
	var candidate: Dictionary = base.duplicate(true)
	for route in 3: candidate.best_scores[route] = maxi(int(base.best_scores[route]), int(earned.best_scores[route]))
	return candidate

func _with_session(base: Dictionary) -> Dictionary:
	var candidate: Dictionary = _merged(base, session_candidate)
	if _muted_edited: candidate.muted = session_candidate.muted
	if _hat_edited: candidate.hat = session_candidate.hat
	return candidate

func record_claim(route: int, score: int) -> Dictionary:
	if route < 0 or route >= 3 or not _valid_integer(score, SCORE_MAX): return _result(false, "invalid_claim")
	var candidate: Dictionary = session_candidate.duplicate(true)
	var improvement: int = maxi(0, score - int(candidate.best_scores[route]))
	candidate.best_scores[route] = maxi(score, int(candidate.best_scores[route]))
	var result: Dictionary = commit(candidate)
	result["session_improvement"] = improvement
	return result

func set_preferences(muted: bool, hat: int) -> Dictionary:
	var candidate: Dictionary = session_candidate.duplicate(true)
	candidate.muted = muted; candidate.hat = hat
	return commit(candidate)

func commit(candidate: Dictionary) -> Dictionary:
	var checked: Dictionary = validate(candidate)
	if not checked.ok or candidate.get("version") != 2: return _result(false, "invalid_candidate")
	var canonical: Dictionary = checked.candidate
	_muted_edited = _muted_edited or canonical.muted != session_candidate.muted
	_hat_edited = _hat_edited or canonical.hat != session_candidate.hat
	session_candidate = _merged(canonical, session_candidate)
	pending_candidate = session_candidate.duplicate(true); pending_save = true
	if _uncertain or load_state == "inaccessible": return retry()
	if load_state in ["unsupported", "corrupt", "recoverable"] and not _recovery_authorized:
		return _failure("profile_"+load_state, load_state)
	return _write_pending(durable_snapshot)

func retry() -> Dictionary:
	if not pending_save: return _result(true)
	var primary: Dictionary = _read(selected_path, "primary_read")
	var backup: Dictionary = _read(selected_path+".bak")
	backup_candidate = backup.candidate.duplicate(true) if backup.ok else {}
	if primary.ok:
		if _uncertain and primary.candidate == _attempt_candidate:
			var remaining: Dictionary = pending_candidate.duplicate(true)
			_acknowledge(primary.candidate, _attempt_baseline)
			if remaining == primary.candidate: return _result(true)
			_muted_edited = remaining.muted != durable_snapshot.muted
			_hat_edited = remaining.hat != durable_snapshot.hat
			session_candidate = _merged(remaining, durable_snapshot)
			pending_candidate = session_candidate.duplicate(true); pending_save = true
		else:
			# Newly accessible storage contributes a baseline, never new earnings.
			durable_snapshot = primary.candidate.duplicate(true)
			session_candidate = _with_session(primary.candidate)
			pending_candidate = session_candidate.duplicate(true)
			_uncertain = false; _recovery_authorized = false; _recovery_baseline = {}
		load_state = "loaded"; protected_original_path = ""
	elif primary.state == "unsupported":
		load_state = "unsupported"; protected_original_path = selected_path
		return _failure(primary.code, "unsupported")
	elif primary.state == "inaccessible":
		load_state = "inaccessible"; protected_original_path = selected_path
		return _failure(primary.code, "inaccessible")
	elif primary.state == "corrupt" and not _recovery_authorized:
		load_state = "recoverable" if backup.ok else "corrupt"; protected_original_path = selected_path
		return _failure(primary.code, load_state)
	elif primary.state == "missing" and backup.ok and load_state != "loaded" and not _recovery_authorized:
		load_state = "recoverable"
		return _failure("backup_recovery_required", "recoverable")
	elif primary.state == "missing" and not _recovery_authorized:
		load_state = "missing"
	var baseline: Dictionary = _recovery_baseline if _recovery_authorized else durable_snapshot
	return _write_pending(baseline)

func recover_backup() -> Dictionary:
	if load_state not in ["recoverable", "corrupt"]: return _result(false, "backup_recovery_unavailable")
	var backup: Dictionary = _read(selected_path+".bak")
	if not backup.ok: return _failure("backup_invalid", load_state)
	backup_candidate = backup.candidate.duplicate(true)
	return _recover(backup_candidate)

func recover_fresh() -> Dictionary:
	if load_state != "corrupt": return _result(false, "fresh_recovery_unavailable")
	var backup: Dictionary = _read(selected_path+".bak")
	if backup.ok: return _result(false, "backup_recovery_required")
	return _recover(empty_candidate())

func _recover(baseline: Dictionary) -> Dictionary:
	var primary: Dictionary = _read(selected_path, "primary_read")
	if primary.state == "unsupported": return _failure("unsupported_version", "unsupported")
	if primary.state == "inaccessible": return _failure(primary.code, "inaccessible")
	if primary.ok: return _result(false, "profile_changed_retry")
	if primary.has("bytes"):
		var preserved: String = _unique_path("quarantine")
		if _fails("quarantine_copy") or DirAccess.copy_absolute(selected_path, preserved) != OK: return _failure("quarantine_copy_failed", load_state)
		var copied: Dictionary = _read(preserved, "quarantine_verify")
		if not copied.has("bytes") or copied.bytes != primary.bytes: return _failure("quarantine_verify_failed", load_state)
		quarantine_path = preserved
	_recovery_authorized = true; _recovery_baseline = baseline.duplicate(true)
	session_candidate = _with_session(baseline)
	pending_candidate = session_candidate.duplicate(true); pending_save = true
	return _write_pending(baseline)

func _write_pending(baseline: Dictionary) -> Dictionary:
	# Recheck the selected destination immediately before writes. Never rotate a
	# corrupt primary into the valid backup or overwrite a future-version profile.
	var old: Dictionary = _read(selected_path, "primary_read")
	if old.state in ["unsupported", "inaccessible"]: return _failure(old.code, old.state)
	if old.state == "corrupt" and not _recovery_authorized: return _failure(old.code, "corrupt")
	if old.ok:
		# A complete reread is the contribution baseline even if another client
		# restored newer money/preferences after this session originally loaded.
		baseline = old.candidate.duplicate(true)
		durable_snapshot = old.candidate.duplicate(true)
		session_candidate = _with_session(old.candidate)
		pending_candidate = session_candidate.duplicate(true)
	var candidate: Dictionary = pending_candidate.duplicate(true)
	var temp: String = _unique_path("tmp")
	if _fails("temp_open"): return _failure("temp_open_failed")
	var file: FileAccess = FileAccess.open(temp, FileAccess.WRITE)
	if file == null: return _failure("temp_open_"+str(FileAccess.get_open_error()))
	var serialized: PackedByteArray = JSON.stringify(candidate).to_utf8_buffer()
	var stored: bool = file.store_buffer(serialized.slice(0, serialized.size()/2) if _fails("temp_write") else serialized)
	file.flush()
	var write_error: int = file.get_error()
	file.close()
	if not stored or write_error != OK: return _failure("temp_write_failed")
	var verified: Dictionary = _read(temp, "temp_verify")
	if not verified.ok or verified.candidate != candidate: return _failure("temp_verify_failed")
	if _fails("after_temp_verify"): return _failure("after_temp_verify_failed")
	if old.ok:
		var backup_temp: String = _unique_path("backup_tmp")
		if _fails("backup_copy") or DirAccess.copy_absolute(selected_path, backup_temp) != OK: return _failure("backup_copy_failed")
		var backup_verified: Dictionary = _read(backup_temp)
		if not backup_verified.ok or backup_verified.bytes != old.bytes: return _failure("backup_verify_failed")
		if _fails("backup_replace") or DirAccess.rename_absolute(backup_temp, selected_path+".bak") != OK: return _failure("backup_replace_failed")
		var backup: Dictionary = _read(selected_path+".bak", "backup_readback")
		if not backup.ok or backup.bytes != old.bytes: return _failure("backup_readback_failed")
		backup_candidate = backup.candidate.duplicate(true)
	if _fails("replace"): return _failure("replace_failed")
	# No delete-primary step. On this tested runtime, rename replaces an existing
	# file; failure leaves primary/backup available. Any post-rename failure is uncertain.
	var replacement_error: int = DirAccess.rename_absolute(temp, selected_path)
	_attempt_candidate = candidate.duplicate(true); _attempt_baseline = baseline.duplicate(true)
	if replacement_error != OK:
		_uncertain = true
		return _failure("replace_"+str(replacement_error), "uncertain")
	var committed: Dictionary = _read(selected_path, "readback")
	if not committed.ok or committed.candidate != candidate:
		_uncertain = true
		return _failure("readback_failed", "uncertain")
	_acknowledge(committed.candidate, baseline)
	return _result(true)

func _acknowledge(candidate: Dictionary, baseline: Dictionary) -> void:
	var contribution: int = 0
	for route in 3: contribution += maxi(0, int(candidate.best_scores[route]) - int(baseline.best_scores[route]))
	var total: int = _total(candidate)
	if contribution > 0:
		_events.append({"amount":contribution, "goal_crossed":_total(baseline) < treatment_goal and total >= treatment_goal, "durable_total":total})
	durable_snapshot = candidate.duplicate(true); session_candidate = candidate.duplicate(true)
	pending_candidate = {}; pending_save = false; _uncertain = false
	_attempt_candidate = {}; _attempt_baseline = {}; _recovery_authorized = false; _recovery_baseline = {}
	_muted_edited = false; _hat_edited = false
	load_state = "loaded"; records_status = "loaded"; diagnostic_code = ""; protected_original_path = ""

func consume_contribution_event() -> Dictionary:
	return {} if _events.is_empty() else _events.pop_front()

func _unique_path(kind: String) -> String:
	while true:
		_sequence += 1
		var path: String = selected_path+"."+kind+"."+str(OS.get_process_id())+"."+str(Time.get_ticks_usec())+"."+str(_sequence)
		if not FileAccess.file_exists(path) and not DirAccess.dir_exists_absolute(path): return path
	return ""

func _failure(code: String, status: String = "pending") -> Dictionary:
	records_status = status; diagnostic_code = code
	if status in ["unsupported", "inaccessible", "corrupt", "recoverable"]:
		load_state = status
		if status != "recoverable": protected_original_path = selected_path
	return _result(false)

func _result(ok: bool, code: String = "") -> Dictionary:
	return {"ok":ok, "status":records_status, "load_state":load_state, "diagnostic_code":diagnostic_code if code.is_empty() else code,
		"durable_snapshot":durable_snapshot.duplicate(true), "candidate":session_candidate.duplicate(true),
		"pending_candidate":pending_candidate.duplicate(true), "pending_save":pending_save,
		"protected_original_path":protected_original_path, "backup_candidate":backup_candidate.duplicate(true), "quarantine_path":quarantine_path}
