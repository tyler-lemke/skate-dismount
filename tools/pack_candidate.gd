extends SceneTree

# Runtime API only: this never requests an editor import or export.
func _initialize() -> void:
	var manifest_path := ""
	var output_path := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--manifest="):
			manifest_path = argument.trim_prefix("--manifest=")
		elif argument.begins_with("--output="):
			output_path = argument.trim_prefix("--output=")
	if not manifest_path.is_absolute_path() or not output_path.is_absolute_path():
		fail("manifest and output must be absolute paths")
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	if not parsed is Dictionary or not parsed.get("files") is Array or parsed["files"].is_empty():
		fail("invalid or empty pack manifest")
		return
	var files: Array = parsed["files"]
	var seen := {}
	var previous := ""
	var checks := 0
	for entry: Variant in files:
		if not entry is Dictionary:
			fail("pack entry must be a dictionary")
			return
		var destination := str(entry.get("path", ""))
		var source := str(entry.get("source", ""))
		if destination.is_empty() or destination.is_absolute_path() or ".." in destination.split("/") or "\\" in destination or seen.has(destination) or destination <= previous:
			fail("unsafe, duplicate, or unsorted destination: " + destination)
			return
		if not source.is_absolute_path() or not FileAccess.file_exists(source):
			fail("missing staged source: " + source)
			return
		if FileAccess.get_sha256(source) != str(entry.get("sha256", "")):
			fail("staged source digest mismatch: " + destination)
			return
		var file := FileAccess.open(source, FileAccess.READ)
		if file == null or file.get_length() != int(entry.get("bytes", -1)):
			fail("staged source size mismatch: " + destination)
			return
		file.close()
		seen[destination] = true
		previous = destination
		checks += 1
	var packer := PCKPacker.new()
	var status := packer.pck_start(output_path)
	checks += 1
	if status != OK:
		fail("pck_start returned " + str(status))
		return
	for entry: Dictionary in files:
		status = packer.add_file("res://" + str(entry["path"]), str(entry["source"]))
		checks += 1
		if status != OK:
			fail("add_file returned " + str(status) + " for " + str(entry["path"]))
			return
	status = packer.flush()
	checks += 1
	if status != OK or not FileAccess.file_exists(output_path):
		fail("flush returned " + str(status))
		return
	print("PACK: %d checks, 0 failures; runtime_pckpacker/from_existing_import_cache" % checks)
	quit(0)

func fail(message: String) -> void:
	printerr("FAIL: PACK: ", message)
	quit(1)
