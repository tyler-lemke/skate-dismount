extends SceneTree

const TestFixtures = preload("res://tests/test_fixtures.gd")
var fixtures = TestFixtures.new("test_startup")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	if not fixtures.error.is_empty():
		quit(1)
		return
	var arguments := PackedStringArray([
		ProjectSettings.globalize_path("res://tests/startup_cases.py"),
		"--engine",OS.get_executable_path(),
		"--project",ProjectSettings.globalize_path("res://"),
		"--fixture-directory",fixtures.directory,
	])
	var output: Array = []
	var code: int = OS.execute("python3",arguments,output,true)
	for fragment in output: print(str(fragment))
	quit(1 if code != 0 else 0)
