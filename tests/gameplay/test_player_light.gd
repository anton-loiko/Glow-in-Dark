extends GdUnitTestSuite
## PlayerLight: урон в % от максимума, неуязвимость, топливо, «последний шанс», одно истощение.

var _light: PlayerLight


func before_test() -> void:
	_light = auto_free(PlayerLight.new())
	add_child(_light)
	var stats: StatBlock = StatBlock.new()
	stats.max_light = 100.0
	stats.decay_rate = 0.0
	stats.contact_damage_mult = 1.0
	stats.fuel_efficiency = 1.2
	_light.setup(stats, ConfigDB.get_balance())


func test_damage_is_percent_of_max_with_multiplier() -> void:
	_light.contact_damage_mult = 0.7 # Призрачный
	assert_float(_light.apply_damage(10.0, &"test")).is_equal_approx(7.0, 0.001)
	assert_float(_light.current).is_equal_approx(93.0, 0.001)


func test_invulnerability_blocks_damage() -> void:
	_light.grant_invulnerability(1.5)
	assert_float(_light.apply_damage(50.0, &"test")).is_equal(0.0)
	assert_float(_light.current).is_equal_approx(100.0, 0.001)


func test_fuel_heal_uses_efficiency_and_caps_at_max() -> void:
	_light.apply_damage(50.0, &"test")
	assert_float(_light.heal_fuel(20.0)).is_equal_approx(24.0, 0.001)
	assert_float(_light.heal_fuel(100.0)).is_equal_approx(26.0, 0.001)


func test_depleted_emitted_once() -> void:
	var monitor: GdUnitSignalAssert = assert_signal(monitor_signals(_light, false))
	_light.apply_damage(150.0, &"test")
	_light.apply_damage(10.0, &"test")
	await monitor.is_emitted("depleted")
	assert_bool(_light.is_depleted()).is_true()


func test_lethal_guard_saves_once() -> void:
	var uses: Array[int] = [0]
	_light.lethal_guard = func() -> bool:
		uses[0] += 1
		return uses[0] == 1
	_light.apply_damage(150.0, &"test")
	assert_bool(_light.is_depleted()).is_false()
	assert_float(_light.current).is_equal_approx(1.0, 0.001)
	_light.apply_damage(150.0, &"test")
	assert_bool(_light.is_depleted()).is_true()


func test_revive_restores_percent() -> void:
	_light.apply_damage(200.0, &"test")
	_light.revive(0.5)
	assert_bool(_light.is_depleted()).is_false()
	assert_float(_light.current).is_equal_approx(50.0, 0.001)
