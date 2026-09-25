extends GdUnitTestSuite
## Таблица Android «назад» (DS §04) и стек паузы мира.


func after_test() -> void:
	SceneRouter.close_all_modals()
	TimeService.reset()


func test_back_actions_follow_design_table() -> void:
	var expected: Dictionary = {
		&"S01": &"none", &"S02": &"exit", &"S03": &"close", &"S04": &"hub",
		&"S05": &"pause", &"S06": &"none", &"S07": &"close", &"S08": &"none",
		&"S09": &"none", &"S10": &"hub", &"S11": &"hub", &"S12": &"hub",
		&"S13": &"hub", &"S14": &"close", &"S15": &"close", &"S16": &"close",
	}
	for id: StringName in expected:
		assert_str(String(SceneRouter.resolve_back_action(id))).override_failure_message(String(id)).is_equal(String(expected[id]))


func test_pause_modal_pauses_world_and_back_closes_it() -> void:
	SceneRouter.open_modal(&"S07")
	assert_bool(TimeService.is_world_paused()).is_true()
	assert_str(String(SceneRouter.top_screen_id())).is_equal("S07")
	SceneRouter.handle_back()
	assert_bool(TimeService.is_world_paused()).is_false()
	assert_array(SceneRouter.modal_stack()).is_empty()


func test_back_is_ignored_on_level_up() -> void:
	var stats: StatBlock = StatsResolver.build(PlayerProfile.new(), ConfigDB.get_balance(), ConfigDB.get_beacon_tiers(), null, ConfigDB.get_gear_config())
	GameManager.current_run = RunContext.new(1, 3, stats)
	GameManager.current_run.level_up_idx = 1
	SceneRouter.open_modal(&"S06")
	SceneRouter.handle_back()
	assert_str(String(SceneRouter.top_screen_id())).is_equal("S06")
	GameManager.current_run = null


func test_pause_reasons_stack() -> void:
	TimeService.pause_world(&"level_up")
	TimeService.pause_world(&"ad")
	TimeService.resume_world(&"ad")
	assert_bool(get_tree().paused).is_true()
	TimeService.resume_world(&"level_up")
	assert_bool(get_tree().paused).is_false()
