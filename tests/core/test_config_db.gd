extends GdUnitTestSuite
## ConfigDB: все конфиги загружены, определения собраны, цена Маяка по Meta DS §00.


func test_defs_are_built() -> void:
	assert_int(ConfigDB.get_skill_ids().size()).is_equal(12)
	assert_object(ConfigDB.get_skill(&"magnet")).is_not_null()
	assert_str(String(ConfigDB.get_skill(&"pulsar").category)).is_equal("attack")
	assert_object(ConfigDB.get_enemy(&"whisper")).is_not_null()
	assert_bool(ConfigDB.get_enemy(&"mourner").enabled).is_false()
	assert_int(ConfigDB.get_skin_ids().size()).is_equal(8)
	assert_object(ConfigDB.get_chapter(3)).is_not_null()
	assert_int(ConfigDB.get_beacon_tiers().size()).is_equal(10)
	assert_object(ConfigDB.get_product(&"starter_pack")).is_not_null()


func test_beacon_cost_control_points() -> void:
	assert_int(ConfigDB.get_beacon_cost(0)).is_equal(60)
	assert_int(ConfigDB.get_beacon_cost(10)).is_equal(90)
	assert_int(ConfigDB.get_beacon_cost(50)).is_equal(430)
	assert_int(ConfigDB.get_beacon_cost(90)).is_equal(2050)
	assert_int(ConfigDB.get_beacon_cost(99)).is_equal(2920)


func test_beacon_total_is_about_74k() -> void:
	var total: int = 0
	for level: int in 100:
		total += ConfigDB.get_beacon_cost(level)
	assert_int(total).is_equal(74720)
