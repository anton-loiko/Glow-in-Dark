extends GdUnitTestSuite
## GameManager: единственная точка изменения валют.

const TEST_DIR: String = "user://test_saves/economy/"

var _prev_profile: PlayerProfile
var _prev_dir: String


func before_test() -> void:
	_prev_profile = GameManager.profile
	_prev_dir = SaveManager.save_dir
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEST_DIR))
	SaveManager.save_dir = TEST_DIR
	GameManager.set_profile(PlayerProfile.new())


func after_test() -> void:
	SaveManager.set_run_active(false)
	SaveManager.save_dir = _prev_dir
	GameManager.set_profile(_prev_profile)


func test_spend_fails_without_funds() -> void:
	GameManager.grant(GameManager.SPARKS, 100, &"test")
	assert_bool(GameManager.spend(GameManager.SPARKS, 150, &"test")).is_false()
	assert_int(GameManager.get_balance(GameManager.SPARKS)).is_equal(100)
	assert_bool(GameManager.spend(GameManager.SPARKS, 60, &"test")).is_true()
	assert_int(GameManager.get_balance(GameManager.SPARKS)).is_equal(40)


func test_negative_amounts_are_rejected() -> void:
	GameManager.grant(GameManager.CRYSTALS, -50, &"test")
	assert_int(GameManager.get_balance(GameManager.CRYSTALS)).is_equal(0)
	assert_bool(GameManager.spend(GameManager.CRYSTALS, -10, &"test")).is_false()


func test_currency_change_is_announced() -> void:
	var monitor: GdUnitSignalAssert = assert_signal(monitor_signals(EventBus, false))
	GameManager.grant(GameManager.CRYSTALS, 80, &"test")
	await monitor.is_emitted("currency_changed", [GameManager.CRYSTALS, 80, 80])


func test_crystal_spend_is_saved_even_during_run() -> void:
	GameManager.grant(GameManager.CRYSTALS, 100, &"test")
	SaveManager.set_run_active(true)
	var before: int = SaveManager.write_count
	GameManager.spend(GameManager.SPARKS, 0, &"test")
	assert_int(SaveManager.write_count).is_equal(before)
	GameManager.spend(GameManager.CRYSTALS, 30, &"revive")
	assert_int(SaveManager.write_count).is_equal(before + 1)


func test_every_literal_economy_reason_is_known() -> void:
	var regex: RegEx = RegEx.create_from_string("(?:grant|spend)\\([^\\n]*, &\"([a-z_0-9]+)\"\\)")
	var unknown: Array[String] = []
	for path: String in _all_scripts("res://src"):
		for m: RegExMatch in regex.search_all(FileAccess.get_file_as_string(path)):
			if not GameManager.is_known_reason(StringName(m.get_string(1))):
				unknown.append(m.get_string(1))
	assert_array(unknown).is_empty()
	assert_bool(GameManager.is_known_reason(&"shop_crystals_80")).is_true()
	assert_bool(GameManager.is_known_reason(&"free_money")).is_false()


func _all_scripts(dir: String) -> Array[String]:
	var out: Array[String] = []
	for f: String in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for d: String in DirAccess.get_directories_at(dir):
		out.append_array(_all_scripts(dir.path_join(d)))
	return out
