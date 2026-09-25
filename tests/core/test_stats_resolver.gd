extends GdUnitTestSuite
## StatsResolver: проценты от базы (не цепочкой), Маяки всех глав, экипировка, скин.

var _balance: Dictionary
var _tiers: Array[BeaconTierDef]
var _gear: Dictionary


func before() -> void:
	_balance = ConfigDB.get_balance()
	_tiers = ConfigDB.get_beacon_tiers()
	_gear = ConfigDB.get_gear_config()


func _base(key: String) -> float:
	return float((_balance["player"] as Dictionary)[key])


func test_new_profile_equals_base() -> void:
	var s: StatBlock = StatsResolver.build(PlayerProfile.new(), _balance, _tiers, null, _gear)
	assert_float(s.max_light).is_equal_approx(_base("max_light"), 0.001)
	assert_float(s.move_speed).is_equal_approx(_base("move_speed"), 0.001)
	assert_float(s.decay_rate).is_equal_approx(_base("decay_per_s"), 0.0001)
	assert_float(s.contact_damage_mult).is_equal_approx(1.0, 0.0001)


func test_beacon_tiers_add_from_base() -> void:
	var p: PlayerProfile = PlayerProfile.new()
	p.get_beacon(1).level = 50 # тиры 1–5
	var s: StatBlock = StatsResolver.build(p, _balance, _tiers, null, _gear)
	assert_float(s.max_light).is_equal_approx(_base("max_light") + 25.0, 0.001)
	assert_float(s.fuel_efficiency).is_equal_approx(1.10, 0.0001)
	assert_float(s.decay_rate).is_equal_approx(_base("decay_per_s") * 0.95, 0.0001)
	assert_float(s.magnet_radius).is_equal_approx(_base("magnet_radius") * 1.15, 0.001)


func test_tier_10_all_stats_is_percent_of_base_not_chained() -> void:
	var p: PlayerProfile = PlayerProfile.new()
	p.get_beacon(1).level = 100
	var s: StatBlock = StatsResolver.build(p, _balance, _tiers, null, _gear)
	# Магнит: +15% (тир 4) и +30% (тир 10) складываются → ×1.45, а не ×1.15×1.30.
	assert_float(s.magnet_radius).is_equal_approx(_base("magnet_radius") * 1.45, 0.001)
	# Макс. яркость: +30% от базы и плоские +10 +15.
	assert_float(s.max_light).is_equal_approx(_base("max_light") * 1.30 + 25.0, 0.001)
	assert_float(s.spark_income_mult).is_equal_approx(1.30, 0.0001)


func test_beacons_of_all_chapters_stack() -> void:
	var p: PlayerProfile = PlayerProfile.new()
	p.get_beacon(1).level = 10
	p.get_beacon(2).level = 10
	var s: StatBlock = StatsResolver.build(p, _balance, _tiers, null, _gear)
	assert_float(s.max_light).is_equal_approx(_base("max_light") + 20.0, 0.001)


func test_gear_uses_item_stat_formula() -> void:
	var p: PlayerProfile = PlayerProfile.new()
	var item: PlayerProfile.GearItem = PlayerProfile.GearItem.new()
	item.uid = "hood"
	item.base_id = &"hood_lamplighter"
	item.slot = &"head"
	item.rarity = &"rare"
	item.level = 10
	p.gear_inventory.append(item)
	p.gear_equipped[&"head"] = "hood"
	var s: StatBlock = StatsResolver.build(p, _balance, _tiers, null, _gear)
	# gear_system.md: Синий шлем ур.10 = 30 + 10 × 2 = 50.
	assert_float(s.max_light).is_equal_approx(_base("max_light") + 50.0, 0.001)


func test_ghost_skin_modifiers_sum_with_beacon() -> void:
	var p: PlayerProfile = PlayerProfile.new()
	p.get_beacon(1).level = 70 # decay −5% (тир 3) и −10% (тир 7)
	var ghost: SkinDef = ConfigDB.get_skin(&"ghost")
	var s: StatBlock = StatsResolver.build(p, _balance, _tiers, ghost, _gear)
	assert_float(s.contact_damage_mult).is_equal_approx(0.70, 0.0001)
	assert_float(s.decay_rate).is_equal_approx(_base("decay_per_s") * 1.10, 0.0001)


func test_skin_flags_are_copied() -> void:
	var s: StatBlock = StatsResolver.build(PlayerProfile.new(), _balance, _tiers, ConfigDB.get_skin(&"pink"), _gear)
	assert_int(s.start_sparks).is_equal(50)
