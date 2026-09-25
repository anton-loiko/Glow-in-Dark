extends GdUnitTestSuite
## Мета task_6, UI-слой: CTA Маяка, очередь сундуков, S14/S17.

const TEST_DIR: String = "user://test_saves/meta_ui/"

var _prev_profile: PlayerProfile
var _prev_dir: String
var p: PlayerProfile


func before_test() -> void:
	_prev_profile = GameManager.profile
	_prev_dir = SaveManager.save_dir
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEST_DIR))
	SaveManager.save_dir = TEST_DIR
	p = PlayerProfile.new()
	GameManager.set_profile(p)


func after_test() -> void:
	SaveManager.save_dir = _prev_dir
	GameManager.set_profile(_prev_profile)


func _cta() -> BeaconCTA:
	var cta: BeaconCTA = auto_free(BeaconCTA.new())
	cta.chapter_id = 1
	add_child(cta)
	return cta


func test_cta_states_follow_wallet_and_tier() -> void:
	var cta: BeaconCTA = _cta()
	assert_int(cta.state).is_equal(BeaconCTA.State.DISABLED)
	assert_int(cta.sparks_missing()).is_equal(60)
	GameManager.grant(GameManager.SPARKS, 100000, &"test")
	cta.refresh()
	assert_int(cta.state).is_equal(BeaconCTA.State.ACTIVE)
	p.get_beacon(1).level = 9
	cta.refresh()
	assert_int(cta.state).is_equal(BeaconCTA.State.TIER_READY)
	p.get_beacon(1).level = 100
	cta.refresh()
	assert_int(cta.state).is_equal(BeaconCTA.State.MAXED)
	cta.syncing = true
	cta.refresh()
	assert_int(cta.state).is_equal(BeaconCTA.State.SYNCING)


func test_cta_hold_never_crosses_tier_boundary() -> void:
	GameManager.grant(GameManager.SPARKS, 100000, &"test")
	var cta: BeaconCTA = _cta()
	cta._on_down()
	for i: int in 400:
		cta._process(0.05)
	assert_int(BeaconService.level(p, 1)).is_equal(9)
	assert_int(cta.state).is_equal(BeaconCTA.State.TIER_READY)
	# Отдельный тап «Зажечь тир».
	var lit: Array[int] = []
	cta.tier_lit.connect(func(t: int) -> void: lit.append(t))
	cta._on_down()
	assert_array(lit).contains_exactly([1])
	assert_bool(p.get_beacon(1).pending_tier_cutscene).is_true()


func test_cta_syncing_blocks_input() -> void:
	GameManager.grant(GameManager.SPARKS, 100000, &"test")
	var cta: BeaconCTA = _cta()
	cta.syncing = true
	cta.refresh()
	cta._on_down()
	assert_int(BeaconService.level(p, 1)).is_equal(0)


func test_hold_interval_ramps_from_start_to_min() -> void:
	var cta: BeaconCTA = _cta()
	cta._held_s = BeaconCTA.HOLD_DELAY_S
	assert_float(cta._interval_s()).is_equal_approx(0.6, 0.001)
	cta._held_s = BeaconCTA.HOLD_DELAY_S + 5.0
	assert_float(cta._interval_s()).is_equal_approx(0.15, 0.001)


func test_run_chests_are_queued_as_pending_rewards() -> void:
	GameManager.start_run(1, 7)
	GameManager.current_run.run_chests.append(&"run")
	GameManager.current_run.run_chests.append(&"run")
	var result: RunResult = RunResult.new()
	result.time_s = 30.0
	result.chests = GameManager.current_run.run_chests.duplicate()
	GameManager.current_run.result = result
	GameManager.apply_run_rewards(1)
	assert_int(p.pending_rewards.size()).is_equal(2)
	assert_str(str(p.pending_rewards[0]["chest"])).is_equal("run")


func test_pending_chests_open_as_one_batch() -> void:
	p.pending_rewards.append({"chest": "run", "source": "run"})
	p.pending_rewards.append({"chest": "run", "source": "run"})
	p.pending_rewards.append({"chest": "epic", "source": "beacon"})
	var modal: Control = auto_free(load("res://src/ui/screens/s17_chest_open/ChestOpenModal.gd").new())
	modal.call("_take_pending", p)
	assert_int(p.gear_inventory.size()).is_equal(2)
	assert_int(p.pending_rewards.size()).is_equal(1)
	assert_str(str(p.pending_rewards[0]["chest"])).is_equal("epic")
	modal.call("_take_pending", p)
	assert_int(p.gear_inventory.size()).is_equal(3)
	assert_str(String(p.gear_inventory[2].rarity)).is_equal("epic")
	assert_bool(p.pending_rewards.is_empty()).is_true()


func test_skin_reveal_is_consumed_on_close() -> void:
	SkinService.unlock(p, &"ghost", 1)
	assert_array(p.skins_to_reveal).contains_exactly([&"ghost"])
	var modal: Control = load("res://src/ui/screens/s14_skin_unlock/SkinUnlockModal.gd").new()
	add_child(modal)
	modal.call("on_screen_enter", {"skin": &"ghost"})
	remove_child(modal)
	modal.free()
	assert_bool(p.skins_to_reveal.is_empty()).is_true()
	assert_array(p.skins_new_badge).contains_exactly([&"ghost"]) # «Позже» — бейдж остаётся


func test_gear_stat_text_signs() -> void:
	assert_str(GearText.stat_text(&"decay_rate_pct", -3.4)).is_equal(tr("−%s%% затухания") % "3.4")
	assert_str(GearText.stat_text(&"max_light", 12.0)).is_equal(tr("+%s макс. яркости") % "12")
