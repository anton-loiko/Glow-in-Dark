extends SceneTree
## Строгая проверка: компилирует все res://src/**/*.gd, поднимая включённые предупреждения GDScript
## до ошибок. Запуск: godot --headless --script res://tools/check_scripts.gd
## Код выхода 1, если хотя бы один файл не прошёл.


func _init() -> void:
	for prop: Dictionary in ProjectSettings.get_property_list():
		var key: String = prop["name"]
		if key.begins_with("debug/gdscript/warnings/") and ProjectSettings.get_setting(key) is int and int(ProjectSettings.get_setting(key)) == 1:
			ProjectSettings.set_setting(key, 2)
	await process_frame
	var files: Array[String] = []
	_collect("res://src", files)
	var failed: int = 0
	for path: String in files:
		var script: GDScript = GDScript.new()
		script.source_code = FileAccess.get_file_as_string(path)
		script.resource_path = path
		if script.reload() != OK:
			failed += 1
			print("FAIL ", path)
	print("CHECKED %d, FAILED %d" % [files.size(), failed])
	quit(1 if failed > 0 else 0)


func _collect(dir: String, out: Array[String]) -> void:
	for file_name: String in DirAccess.get_files_at(dir):
		if file_name.ends_with(".gd"):
			out.append(dir.path_join(file_name))
	for sub: String in DirAccess.get_directories_at(dir):
		_collect(dir.path_join(sub), out)
