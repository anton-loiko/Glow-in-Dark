extends GdUnitTestSuite
## D18: Лунный Огонёк — фазы, множители и потолок радиуса ×2.0.


func _moon() -> MoonPhases:
	return MoonPhases.from_flags(ConfigDB.get_skin(&"moon").flags)


func test_cycle_phases_and_multipliers() -> void:
	var m: MoonPhases = _moon()
	assert_object(m).is_not_null()
	m.t = 0.5
	assert_int(m.phase()).is_equal(MoonPhases.Phase.TELEGRAPH)
	m.t = 3.0
	assert_int(m.phase()).is_equal(MoonPhases.Phase.FULL)
	assert_float(m.radius_mult(1.0)).is_equal_approx(1.3, 0.001)
	assert_float(m.aura_mult()).is_equal_approx(1.4, 0.001)
	m.t = 10.0
	assert_int(m.phase()).is_equal(MoonPhases.Phase.NEW)
	assert_float(m.radius_mult(1.0)).is_equal_approx(0.8, 0.001)
	assert_float(m.aura_mult()).is_equal(1.0)
	m.t = 15.0
	assert_int(m.phase()).is_equal(MoonPhases.Phase.NORMAL)


func test_radius_cap_two_times_base() -> void:
	var m: MoonPhases = _moon()
	m.t = 3.0 # Полнолуние
	# Линза + Энергоёмкость уже дают ×1.8 → фаза урезается до ×2.0 / 1.8.
	assert_float(1.8 * m.radius_mult(1.8)).is_equal_approx(2.0, 0.001)


func test_other_skins_have_no_moon() -> void:
	assert_object(MoonPhases.from_flags(ConfigDB.get_skin(&"ghost").flags)).is_null()


func test_cycle_wraps() -> void:
	var m: MoonPhases = _moon()
	m.tick(21.0)
	assert_float(m.t).is_equal_approx(1.0, 0.001)
