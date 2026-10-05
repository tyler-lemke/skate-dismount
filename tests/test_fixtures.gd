extends RefCounted

# One destination per suite process. CLI storage also wins in main.gd, so a
# subcase rewrites this file before startup or uses a separate child process.
const EMPTY_RECORD: Dictionary = {"version":2,"best_scores":[0,0,0],"legacy_scores":[0,0,0],"muted":false,"hat":0}
const OBSERVATION_PREFIX: String = "STARTUP_OBSERVATION: "
var records_path: String = ""
var directory: String = ""
var error: String = ""

func _init(suite: String) -> void:
	var overrides: Array[String] = []
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--records-path="):
			overrides.append(argument.trim_prefix("--records-path="))
		elif argument == "--records-path":
			error = "Test fixture requires --records-path=<absolute filename>"
	if overrides.size() > 1:
		error = "Test fixture accepts one --records-path override per process"
	elif overrides.size() == 1:
		records_path = overrides[0]
		if records_path.is_empty() or not records_path.is_absolute_path() or records_path.begins_with("user://") or records_path.begins_with("res://") or records_path.ends_with("/"):
			error = "Test fixture requires an absolute isolated record filename"
	else:
		directory = ProjectSettings.globalize_path("res://builds/test_runs/direct-%d-%d/%s" % [OS.get_process_id(),Time.get_ticks_usec(),suite])
		records_path = directory.path_join("records.json")
	if error.is_empty():
		directory = records_path.get_base_dir()
		var result: Error = DirAccess.make_dir_recursive_absolute(directory)
		if result != OK:
			error = "Cannot create test fixture directory %s: %s" % [directory,error_string(result)]
	if not error.is_empty():
		push_error(error)

func artifact_path(filename: String) -> String:
	assert(not filename.is_empty() and filename == filename.get_file(), "Artifacts belong directly to this suite's fixture directory")
	return directory.path_join(filename)

func missing_parent_records_path() -> String:
	# Intentionally do not create this parent. R02 uses it for save-open failure.
	return directory.path_join("deliberately_missing_parent/records.json")

static func inject(game: Node, path: String, is_test_mode: bool = true) -> void:
	game.test_mode = is_test_mode
	game.save_path = path

func write_records(data: Dictionary = EMPTY_RECORD) -> bool:
	if not error.is_empty(): return false
	var file := FileAccess.open(records_path,FileAccess.WRITE)
	if file == null:
		push_error("Cannot write suite fixture %s: %s" % [records_path,error_string(FileAccess.get_open_error())])
		return false
	file.store_string(JSON.stringify(data))
	file.close()
	return true

func prepare(game: Node, data: Dictionary = EMPTY_RECORD, preserve_existing: bool = false) -> bool:
	if not error.is_empty(): return false
	if not preserve_existing and not write_records(data): return false
	inject(game,records_path)
	return true

func create_game(parent: Node, data: Dictionary = EMPTY_RECORD, preserve_existing: bool = false) -> Node3D:
	var game: Node3D = load("res://scenes/main.tscn").instantiate()
	if not prepare(game,data,preserve_existing):
		game.free()
		parent.get_tree().quit(1)
		return null
	parent.add_child(game)
	return game

# A real fresh Godot process observes _ready's first load. It does not call
# load_records() manually or derive expected values from the loader.
func observe_startup(arguments: PackedStringArray = PackedStringArray()) -> Dictionary:
	var command := PackedStringArray(["--headless","--path",ProjectSettings.globalize_path("res://"),"--script","res://tests/startup_case.gd","--log-file",artifact_path("cold-start-engine.log"),"--","--records-path="+records_path,"--test-mode"])
	command.append_array(arguments)
	var output: Array = []
	var code: int = OS.execute(OS.get_executable_path(),command,output,true)
	var output_text: String = ""
	for fragment in output: output_text += str(fragment)
	var result: Dictionary = {"exit_code":code,"output":output_text,"observation":{}}
	var observations: int = 0
	for line in str(result.output).split("\n"):
		if line.begins_with(OBSERVATION_PREFIX):
			observations += 1
			var parsed: Variant = JSON.parse_string(line.trim_prefix(OBSERVATION_PREFIX))
			if parsed is Dictionary: result.observation = parsed
	if observations != 1: result.observation = {}
	var transcript := FileAccess.open(artifact_path("cold-start-output.log"),FileAccess.WRITE)
	if transcript != null:
		transcript.store_string(output_text)
		transcript.close()
	else:
		push_error("Cannot write cold-start transcript inside suite fixture directory")
	print(output_text)
	return result
