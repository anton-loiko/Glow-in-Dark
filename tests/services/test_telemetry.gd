extends GdUnitTestSuite
## task_7 §7: словарь событий и приведение параметров к лимитам Firebase.


func _dictionary() -> Dictionary:
	var names: Dictionary = {}
	var regex: RegEx = RegEx.create_from_string("^\\| `([a-z_]+)` \\|")
	for line: String in FileAccess.get_file_as_string("res://docs/analytics_events.md").split("\n"):
		var m: RegExMatch = regex.search(line)
		if m != null:
			names[m.get_string(1)] = true
	return names


func test_every_logged_event_is_in_dictionary() -> void:
	var known: Dictionary = _dictionary()
	assert_int(known.size()).is_greater(30)
	var regex: RegEx = RegEx.create_from_string("log_event\\(&\"([a-z_]+)\"")
	var missing: Array[String] = []
	for path: String in _scripts("res://src"):
		for m: RegExMatch in regex.search_all(FileAccess.get_file_as_string(path)):
			if not known.has(m.get_string(1)):
				missing.append("%s (%s)" % [m.get_string(1), path.get_file()])
	for implicit: String in ["earn_virtual_currency", "spend_virtual_currency", "screen_view"]:
		if not known.has(implicit):
			missing.append(implicit)
	assert_array(missing).is_empty()


func test_event_names_fit_firebase_limit() -> void:
	for event_name: String in _dictionary():
		assert_int(event_name.length()).is_less_equal(40)


func test_sanitize_params() -> void:
	var out: Dictionary = FirebaseAnalyticsBackend.sanitize({"ok": true, "n": 3, "s": "x".repeat(150), "arr": ["a", "b"]})
	assert_int(out["ok"]).is_equal(1)
	assert_int(out["n"]).is_equal(3)
	assert_int(str(out["s"]).length()).is_equal(100)
	assert_str(out["arr"]).is_equal("a,b")


func _scripts(dir: String) -> Array[String]:
	var out: Array[String] = []
	for f: String in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for d: String in DirAccess.get_directories_at(dir):
		out.append_array(_scripts(dir.path_join(d)))
	return out
