extends GdUnitTestSuite
## Миграция сейва MVP (user://save_data.cfg) в профиль v1.

const TEST_DIR: String = "user://test_saves/legacy/"

var _prev_dir: String
var _prev_profile: PlayerProfile


func before_test() -> void:
	_prev_dir = SaveManager.save_dir
	_prev_profile = GameManager.profile
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEST_DIR))
	for f: String in DirAccess.get_files_at(TEST_DIR):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_DIR + f))
	SaveManager.save_dir = TEST_DIR


func after_test() -> void:
	SaveManager.save_dir = _prev_dir
	SaveManager.bind_profile(_prev_profile)


func _legacy_config() -> ConfigFile:
	var c: ConfigFile = ConfigFile.new()
	c.set_value("progress", "unlocked_level", 7)
	c.set_value("purchases", "has_no_ads", true)
	c.set_value("inventory", "sparks", 250)
	c.set_value("inventory", "owned_skins", ["default", "pink_flame", "fire_skin"])
	c.set_value("inventory", "equipped_skin", "pink_flame")
	c.set_value("settings", "sound_enabled", false)
	c.set_value("settings", "music_enabled", true)
	c.set_value("settings", "vibration_enabled", false)
	return c


func test_migrate_maps_fields() -> void:
	var p: PlayerProfile = LegacySaveMigration.migrate(_legacy_config())
	assert_int(p.sparks).is_equal(250)
	assert_bool(p.skins_unlocked.has(&"base")).is_true()
	assert_bool(p.skins_unlocked.has(&"pink")).is_true()
	assert_str(String(p.skin_equipped)).is_equal("pink")
	# fire_skin в V1 нет → компенсация Кристаллами.
	assert_int(p.crystals).is_equal(LegacySaveMigration.COMPENSATION_CRYSTALS_PER_SKIN)
	assert_bool(p.settings.sfx).is_false()
	assert_bool(p.settings.music).is_true()
	assert_bool(p.settings.vibration).is_false()


func test_save_manager_migrates_legacy_file_once() -> void:
	_legacy_config().save(TEST_DIR + "save_data.cfg")
	var p: PlayerProfile = SaveManager.load_profile()
	assert_int(p.sparks).is_equal(250)
	assert_bool(FileAccess.file_exists(TEST_DIR + "profile.json")).is_true()
	assert_bool(FileAccess.file_exists(TEST_DIR + "save_data.cfg")).is_false()
	assert_bool(FileAccess.file_exists(TEST_DIR + "save_data.cfg.migrated")).is_true()
	# Повторная загрузка читает уже новый формат.
	var again: PlayerProfile = SaveManager.load_profile()
	assert_int(again.sparks).is_equal(250)
