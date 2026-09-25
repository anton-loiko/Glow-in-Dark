extends GdUnitTestSuite
## SaveManager: атомарная запись, восстановление из бэкапа, запрет записи во время забега.

const TEST_DIR: String = "user://test_saves/save_manager/"

var _prev_dir: String
var _prev_profile: PlayerProfile


func before_test() -> void:
	_prev_dir = SaveManager.save_dir
	_prev_profile = GameManager.profile
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEST_DIR))
	for f: String in DirAccess.get_files_at(TEST_DIR):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_DIR + f))
	SaveManager.save_dir = TEST_DIR
	SaveManager.set_run_active(false)


func after_test() -> void:
	SaveManager.set_run_active(false)
	SaveManager.save_dir = _prev_dir
	SaveManager.bind_profile(_prev_profile)


func test_write_creates_main_and_backup() -> void:
	var p: PlayerProfile = PlayerProfile.create_new()
	SaveManager.bind_profile(p)
	p.sparks = 10
	SaveManager.flush(true)
	p.sparks = 20
	SaveManager.flush(true)
	assert_bool(FileAccess.file_exists(TEST_DIR + "profile.json")).is_true()
	assert_bool(FileAccess.file_exists(TEST_DIR + "profile.bak.json")).is_true()
	assert_bool(FileAccess.file_exists(TEST_DIR + "profile.json.tmp")).is_false()
	assert_int(SaveManager.load_profile().sparks).is_equal(20)


func test_corrupted_main_restores_from_backup() -> void:
	var p: PlayerProfile = PlayerProfile.create_new()
	SaveManager.bind_profile(p)
	p.sparks = 111
	SaveManager.flush(true)
	p.sparks = 222
	SaveManager.flush(true)
	var f: FileAccess = FileAccess.open(TEST_DIR + "profile.json", FileAccess.WRITE)
	f.store_string("{ broken")
	f.close()
	assert_int(SaveManager.load_profile().sparks).is_equal(111)


func test_no_writes_during_run_except_critical() -> void:
	var p: PlayerProfile = PlayerProfile.create_new()
	SaveManager.bind_profile(p)
	SaveManager.set_run_active(true)
	var before: int = SaveManager.write_count
	SaveManager.request_save()
	SaveManager.flush()
	assert_int(SaveManager.write_count).is_equal(before)
	SaveManager.request_save(true)
	assert_int(SaveManager.write_count).is_equal(before + 1)


func test_deferred_save_written_after_run() -> void:
	var p: PlayerProfile = PlayerProfile.create_new()
	SaveManager.bind_profile(p)
	SaveManager.set_run_active(true)
	SaveManager.request_save()
	var before: int = SaveManager.write_count
	SaveManager.set_run_active(false)
	SaveManager.flush()
	assert_int(SaveManager.write_count).is_equal(before + 1)
