extends GdUnitTestSuite
## PlayerProfile: сериализация и значения по умолчанию.


func test_roundtrip_preserves_all_sections() -> void:
	var p: PlayerProfile = PlayerProfile.create_new()
	p.sparks = 1240
	p.crystals = 340
	p.unlocked_chapters.append(2)
	p.best_time_s[1] = 408.5
	p.get_beacon(1).level = 57
	p.get_beacon(1).seen_milestones.append(25)
	p.skins_unlocked.append(&"ghost")
	p.skin_equipped = &"ghost"
	var item: PlayerProfile.GearItem = PlayerProfile.GearItem.new()
	item.uid = "u1"
	item.base_id = &"hood_lamplighter"
	item.slot = &"head"
	item.rarity = &"rare"
	item.level = 7
	p.gear_inventory.append(item)
	p.gear_equipped[&"head"] = "u1"
	p.settings.no_flashes = true
	p.receipts.append("tx-1")

	var copy: PlayerProfile = PlayerProfile.from_dict(JSON.parse_string(JSON.stringify(p.to_dict())))

	assert_int(copy.sparks).is_equal(1240)
	assert_int(copy.crystals).is_equal(340)
	assert_array(copy.unlocked_chapters).contains_exactly([1, 2])
	assert_float(copy.best_time_s[1]).is_equal_approx(408.5, 0.001)
	assert_int(copy.get_beacon(1).level).is_equal(57)
	assert_array(copy.get_beacon(1).seen_milestones).contains_exactly([25])
	assert_bool(copy.skins_unlocked.has(&"ghost")).is_true()
	assert_str(String(copy.skin_equipped)).is_equal("ghost")
	assert_str(copy.gear_equipped[&"head"]).is_equal("u1")
	assert_int(copy.find_gear("u1").level).is_equal(7)
	assert_bool(copy.settings.no_flashes).is_true()
	assert_array(copy.receipts).contains_exactly(["tx-1"])


func test_missing_keys_get_defaults() -> void:
	var p: PlayerProfile = PlayerProfile.from_dict({})
	assert_int(p.sparks).is_equal(0)
	assert_str(String(p.skin_equipped)).is_equal("base")
	assert_array(p.unlocked_chapters).contains_exactly([1])
	assert_bool(p.settings.music).is_true()
	assert_int(p.gear_equipped.size()).is_equal(PlayerProfile.GEAR_SLOTS.size())
