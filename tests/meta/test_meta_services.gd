extends GdUnitTestSuite
## Мета task_6: Маяк, экипировка, сундуки.

const TEST_DIR: String = "user://test_saves/meta/"

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


# --- Маяк ------------------------------------------------------------------------

func test_hold_stops_at_tier_boundary() -> void:
	GameManager.grant(GameManager.SPARKS, 100000, &"test")
	for i: int in 20:
		BeaconService.deposit_one(p, 1)
	assert_int(BeaconService.level(p, 1)).is_equal(9)
	assert_bool(BeaconService.is_tier_ready(p, 1)).is_true()
	assert_int(BeaconService.deposit_one(p, 1, true)).is_equal(1)
	assert_int(BeaconService.level(p, 1)).is_equal(10)


func test_deposit_spends_exact_cost_atomically() -> void:
	GameManager.grant(GameManager.SPARKS, 60 + 70, &"test")
	assert_int(BeaconService.deposit_one(p, 1)).is_equal(0)
	assert_int(p.sparks).is_equal(70)
	var cost: int = BeaconService.next_cost(p, 1)
	assert_int(cost).is_equal(ConfigDB.get_beacon_cost(1))
	GameManager.spend(GameManager.SPARKS, p.sparks - cost + 1, &"test")
	assert_int(BeaconService.deposit_one(p, 1)).is_equal(-1)
	assert_int(BeaconService.level(p, 1)).is_equal(1)


func test_tier_rewards_chapter_one() -> void:
	GameManager.grant(GameManager.SPARKS, 1000000, &"test")
	for i: int in 50:
		BeaconService.deposit_one(p, 1, true)
	assert_bool(p.skins_unlocked.has(&"ghost")).is_true()
	assert_bool(p.skins_unlocked.has(&"plasma")).is_true()
	assert_bool(p.skins_unlocked.has(&"blue")).is_true()
	assert_bool(p.gear_slots_unlocked.has(&"amulet_2")).is_true()
	assert_int(p.crystals).is_equal(100)
	assert_int(BeaconService.pending_milestone(p, 1)).is_equal(25)
	BeaconService.mark_cutscene_seen(p, 1, 25, false)
	assert_int(BeaconService.pending_milestone(p, 1)).is_equal(50)


func test_full_beacon_unlocks_next_chapter() -> void:
	GameManager.grant(GameManager.SPARKS, 1000000, &"test")
	for i: int in 100:
		BeaconService.deposit_one(p, 1, true)
	assert_bool(BeaconService.is_max(p, 1)).is_true()
	assert_bool(p.unlocked_chapters.has(2)).is_true()
	assert_bool(p.skins_unlocked.has(&"solar")).is_true()
	assert_int(BeaconService.deposit_one(p, 1, true)).is_equal(-1)


# --- Экипировка ------------------------------------------------------------------

func test_gear_cost_formula_matches_doc() -> void:
	assert_int(GearService.cost_to(&"rare", 2)).is_equal(280)
	assert_int(GearService.cost_to(&"rare", 3)).is_equal(392)
	assert_int(GearService.cost_to(&"rare", 5)).is_equal(768)
	assert_int(GearService.cost_to(&"rare", 10)).is_equal(4132)


func test_item_stat_formula() -> void:
	var item: PlayerProfile.GearItem = GearService.create_item(&"hood_lamplighter", &"rare")
	item.level = 10
	assert_float(GearService.stat_value(item)).is_equal_approx(50.0, 0.001)


func test_level_up_and_dismantle_refund() -> void:
	GameManager.grant(GameManager.SPARKS, 10000, &"test")
	var item: PlayerProfile.GearItem = GearService.create_item(&"moth_boots", &"common")
	GearService.add_item(p, item)
	assert_bool(GearService.level_up(p, item.uid)).is_true()
	assert_bool(GearService.level_up(p, item.uid)).is_true()
	var invested: int = item.sparks_invested
	assert_int(invested).is_equal(GearService.cost_to(&"common", 2) + GearService.cost_to(&"common", 3))
	var before: int = p.sparks
	assert_int(GearService.dismantle(p, item.uid)).is_equal(invested)
	assert_int(p.sparks).is_equal(before + invested)
	assert_int(p.gear_inventory.size()).is_equal(0)


func test_level_capped_by_rarity() -> void:
	GameManager.grant(GameManager.SPARKS, 10000000, &"test")
	var item: PlayerProfile.GearItem = GearService.create_item(&"ember_core", &"common")
	GearService.add_item(p, item)
	for i: int in 30:
		GearService.level_up(p, item.uid)
	assert_int(item.level).is_equal(GearService.max_level(&"common"))


func test_merge_keeps_base_level_and_refunds() -> void:
	var items: Array[String] = []
	for lvl: int in [7, 3, 2]:
		var it: PlayerProfile.GearItem = GearService.create_item(&"hood_lamplighter", &"rare")
		it.level = lvl
		it.sparks_invested = lvl * 100
		GearService.add_item(p, it)
		items.append(it.uid)
	var result: PlayerProfile.GearItem = GearService.merge(p, items)
	assert_object(result).is_not_null()
	assert_str(String(result.rarity)).is_equal("epic")
	assert_int(result.level).is_equal(7)
	assert_int(p.sparks).is_equal(300 + 200)
	assert_int(p.gear_inventory.size()).is_equal(1)


func test_merge_stops_at_epic_and_needs_same_items() -> void:
	var epics: Array[String] = []
	for i: int in 3:
		var it: PlayerProfile.GearItem = GearService.create_item(&"moth_boots", &"epic")
		GearService.add_item(p, it)
		epics.append(it.uid)
	assert_object(GearService.merge(p, epics)).is_null()
	var mixed: Array[String] = [epics[0]]
	var other: PlayerProfile.GearItem = GearService.create_item(&"spark_charm", &"epic")
	GearService.add_item(p, other)
	mixed.append(other.uid)
	mixed.append(epics[1])
	assert_object(GearService.merge(p, mixed)).is_null()


func test_second_amulet_slot_requires_beacon() -> void:
	var a: PlayerProfile.GearItem = GearService.create_item(&"spark_charm", &"common")
	GearService.add_item(p, a)
	assert_bool(GearService.equip(p, a.uid, &"amulet_2")).is_false()
	p.gear_slots_unlocked.append(&"amulet_2")
	assert_bool(GearService.equip(p, a.uid, &"amulet_2")).is_true()


# --- Сундуки ---------------------------------------------------------------------

func test_chest_rates_monte_carlo() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 42
	var counts: Array[int] = [0, 0, 0, 0, 0]
	var n: int = 100000
	var weights: Array = ChestService.rates(&"basic")
	for i: int in n:
		counts[ChestService._roll(weights, rng)] += 1
	assert_float(counts[0] / float(n)).is_equal_approx(0.80, 0.005)
	assert_float(counts[1] / float(n)).is_equal_approx(0.18, 0.005)
	assert_float(counts[2] / float(n)).is_equal_approx(0.02, 0.005)
	assert_int(counts[3] + counts[4]).is_equal(0)


func test_premium_pity_guarantees_legendary_by_60() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	for run: int in 20:
		rng.seed = run
		p.premium_pity = 0
		p.gear_inventory.clear()
		var got_legendary_at: int = -1
		for i: int in 60:
			var items: Array[PlayerProfile.GearItem] = ChestService.open(p, &"premium", 1, rng)
			if items[0].rarity == &"legendary":
				got_legendary_at = i + 1
				break
			if p.gear_inventory.size() > 30:
				p.gear_inventory.clear()
		assert_int(got_legendary_at).is_between(1, 60)


func test_premium_x10_has_rare_or_better() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	for run: int in 200:
		rng.seed = run
		p.gear_inventory.clear()
		var items: Array[PlayerProfile.GearItem] = ChestService.open(p, &"premium", 10, rng)
		var best: int = 0
		for it: PlayerProfile.GearItem in items:
			best = maxi(best, GearService.RARITIES.find(it.rarity))
		assert_int(best).is_greater_equal(2)
		assert_str(String(items.back().rarity)).is_equal(String(GearService.RARITIES[best]))


func test_chest_result_saved_before_animation() -> void:
	var before: int = SaveManager.write_count
	ChestService.open(p, &"basic", 1)
	assert_int(p.gear_inventory.size()).is_equal(1)
	assert_int(SaveManager.write_count).is_greater(before)
