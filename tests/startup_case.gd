extends SceneTree

const TestFixtures = preload("res://tests/test_fixtures.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game: Node3D = load("res://scenes/main.tscn").instantiate()
	var injected_path: String = ""
	var injected_mode: bool = false
	var output_path: String = ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--inject-path="): injected_path = argument.trim_prefix("--inject-path=")
		if argument == "--inject-test-mode": injected_mode = true
		if argument.begins_with("--observation-output="): output_path = argument.trim_prefix("--observation-output=")
	if not injected_path.is_empty(): TestFixtures.inject(game,injected_path,injected_mode)
	root.add_child(game)
	# Observe exactly _ready's first record read; never manually call the loader.
	var rider_hat: int = -1
	var has_hat: bool = false
	if is_instance_valid(game.skater):
		rider_hat = game.skater.hat_index
		has_hat = game.skater.visuals.head.get_node_or_null("CrashHat") != null
	var observation: Dictionary = {
		"pid":OS.get_process_id(),"path":game.save_path,
		"source":game.records_path_source,"error":game.startup_error,
		"best_scores":game.best_scores,"legacy_scores":game.legacy_scores,
		"muted":game.muted,"hat":game.selected_hat,
		"rider_hat":rider_hat,"has_hat":has_hat,
		"test_mode":game.test_mode,"capture":game.capture_mode,
		"self_check":game.self_check,"automate":game.automate,
		"world_built":is_instance_valid(game.skater),
	}
	for property in game.get_property_list():
		if property.name == "startup_records_read_path":
			observation["read_path"] = game.get("startup_records_read_path")
	print(TestFixtures.OBSERVATION_PREFIX+JSON.stringify(observation))
	if not output_path.is_empty():
		var file := FileAccess.open(output_path,FileAccess.WRITE)
		if file == null:
			printerr("FAIL: cannot write cold-start observation ",output_path)
			quit(1)
			return
		file.store_string(JSON.stringify(observation))
		file.close()
	var failed: bool = not game.startup_error.is_empty()
	game.unpause()
	game.queue_free()
	await process_frame
	await process_frame
	quit(2 if failed else 0)
