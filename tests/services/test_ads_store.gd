extends GdUnitTestSuite
## task_7: плейсменты RV с лимитами, изоляция наград, идемпотентность покупок.

const TEST_DIR: String = "user://test_saves/ads_store/"

var _prev_profile: PlayerProfile
var _prev_dir: String
var _prev_ads: AdsBackend
var _prev_store: StoreBackend
var ads: MockAdsBackend
var store: MockStoreBackend
var p: PlayerProfile
var granted: Array[StringName] = []


func before_test() -> void:
	_prev_profile = GameManager.profile
	_prev_dir = SaveManager.save_dir
	_prev_ads = AdManager.backend
	_prev_store = StoreManager.backend
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEST_DIR))
	SaveManager.save_dir = TEST_DIR
	p = PlayerProfile.new()
	GameManager.set_profile(p)
	ads = MockAdsBackend.new()
	ads.delay_s = 0.0
	AdManager.set_backend(ads)
	store = MockStoreBackend.new()
	StoreManager.set_backend(store)
	granted.clear()
	EventBus.ad_reward_granted.connect(_on_granted)


func after_test() -> void:
	EventBus.ad_reward_granted.disconnect(_on_granted)
	if GameManager.current_run != null:
		GameManager.current_run = null
	AdManager.set_backend(_prev_ads)
	StoreManager.set_backend(_prev_store)
	SaveManager.save_dir = _prev_dir
	GameManager.set_profile(_prev_profile)


func _on_granted(placement: StringName) -> void:
	granted.append(placement)


func test_each_placement_rewards_only_itself() -> void:
	GameManager.start_run(1, 3)
	var sparks_before: int = p.sparks
	AdManager.show_rewarded(&"skill_reroll")
	assert_array(granted).contains_exactly([&"skill_reroll"])
	assert_bool(GameManager.current_run.revive_used).is_false()
	assert_int(p.sparks).is_equal(sparks_before)


func test_per_run_limit_resets_with_new_run() -> void:
	GameManager.start_run(1, 3)
	assert_int(AdManager.remaining(&"run_x3")).is_equal(1)
	AdManager.show_rewarded(&"run_x3")
	assert_int(AdManager.remaining(&"run_x3")).is_equal(0)
	assert_bool(AdManager.is_rewarded_ready(&"run_x3")).is_false()
	AdManager.show_rewarded(&"run_x3")
	assert_int(granted.size()).is_equal(1)
	GameManager.current_run = null
	GameManager.start_run(1, 4)
	assert_int(AdManager.remaining(&"run_x3")).is_equal(1)


func test_basic_chest_three_per_day() -> void:
	for i: int in 5:
		AdManager.show_rewarded(&"basic_chest")
	assert_int(granted.size()).is_equal(3)
	assert_int(AdManager.remaining(&"basic_chest")).is_equal(0)
	p.ads_day_stamp -= 1 # наступил новый день
	assert_int(AdManager.remaining(&"basic_chest")).is_equal(3)


func test_hub_and_shop_share_gift_cooldown() -> void:
	AdManager.show_rewarded(&"hub_sparks")
	assert_int(p.sparks).is_equal(300)
	assert_bool(StoreManager.free_gift_ready()).is_false()
	assert_int(AdManager.remaining(&"shop_free_gift")).is_equal(0)
	assert_int(AdManager.seconds_until_available(&"shop_free_gift")).is_greater(8 * 3600 - 5)
	AdManager.show_rewarded(&"shop_free_gift")
	assert_int(p.sparks).is_equal(300)
	p.ad_cooldowns["shop_free_gift"] -= 8 * 3600
	assert_bool(StoreManager.free_gift_ready()).is_true()


func test_duplicate_backend_callback_is_ignored() -> void:
	ads.loaded = true
	ads.delay_s = 0.0
	AdManager.show_rewarded(&"daily_x2")
	ads.rewarded_finished.emit(&"daily_x2", true) # повторная доставка
	assert_array(granted).contains_exactly([&"daily_x2"])


func test_not_loaded_blocks_with_reason() -> void:
	ads.loaded = false
	assert_bool(AdManager.is_rewarded_ready(&"revive")).is_false()
	assert_str(AdManager.blocked_reason(&"revive")).is_equal(tr("Реклама недоступна"))


func test_legacy_ad_counters_migrate() -> void:
	var migrated: PlayerProfile = PlayerProfile.from_dict({
		"chests": {"basic_ads_today": 2, "ads_day_stamp": 100},
		"daily": {"free_gift_ts": 12345},
	})
	assert_int(migrated.ads_today["basic_chest"]).is_equal(2)
	assert_int(migrated.ads_day_stamp).is_equal(100)
	assert_int(migrated.ad_cooldowns["shop_free_gift"]).is_equal(12345)


func test_purchase_is_granted_once_per_transaction() -> void:
	StoreManager.purchase(&"crystals_80")
	assert_int(p.crystals).is_equal(80)
	var tx: String = p.receipts[0]
	store.purchase_succeeded.emit("crystals_80", tx) # повторная доставка
	assert_int(p.crystals).is_equal(80)


func test_restore_returns_starter_skin_without_crystals() -> void:
	StoreManager.purchase(&"starter_pack")
	assert_bool(p.starter_pack_bought).is_true()
	var crystals: int = p.crystals
	var fresh: PlayerProfile = PlayerProfile.new()
	GameManager.set_profile(fresh)
	StoreManager.restore_purchases()
	assert_bool(fresh.skins_unlocked.has(&"moon")).is_true()
	assert_int(fresh.crystals).is_equal(0)
	assert_int(crystals).is_greater(0)


func test_cancelled_purchase_grants_nothing() -> void:
	store.next_outcome = MockStoreBackend.Outcome.CANCEL
	StoreManager.purchase(&"crystals_280")
	assert_int(p.crystals).is_equal(0)
	assert_array(p.receipts).is_empty()
