extends GdUnitTestSuite
## Слияние локального и облачного профиля без потери прогресса и без дюпа валюты.


func _profile(updated_at: int, sparks: int) -> PlayerProfile:
	var p: PlayerProfile = PlayerProfile.new()
	p.updated_at = updated_at
	p.sparks = sparks
	return p


func test_wallet_comes_from_newer_profile() -> void:
	var local: PlayerProfile = _profile(100, 5000)
	var remote: PlayerProfile = _profile(200, 300)
	assert_int(ProfileMerge.merge(local, remote).sparks).is_equal(300)
	assert_int(ProfileMerge.merge(remote, local).sparks).is_equal(300)


func test_progress_is_never_lost() -> void:
	var local: PlayerProfile = _profile(200, 0)
	local.get_beacon(1).level = 40
	local.skins_unlocked.append(&"ghost")
	local.premium_pity = 5
	var remote: PlayerProfile = _profile(100, 0)
	remote.get_beacon(1).level = 57
	remote.get_beacon(2).level = 3
	remote.skins_unlocked.append(&"plasma")
	remote.premium_pity = 12
	remote.unlocked_chapters.append(2)
	remote.starter_pack_bought = true
	var item: PlayerProfile.GearItem = PlayerProfile.GearItem.new()
	item.uid = "remote-item"
	remote.gear_inventory.append(item)

	var merged: PlayerProfile = ProfileMerge.merge(local, remote)
	assert_int(merged.get_beacon(1).level).is_equal(57)
	assert_int(merged.get_beacon(2).level).is_equal(3)
	assert_bool(merged.skins_unlocked.has(&"ghost")).is_true()
	assert_bool(merged.skins_unlocked.has(&"plasma")).is_true()
	assert_int(merged.premium_pity).is_equal(12)
	assert_array(merged.unlocked_chapters).contains_exactly([1, 2])
	assert_bool(merged.starter_pack_bought).is_true()
	assert_object(merged.find_gear("remote-item")).is_not_null()
	assert_int(merged.updated_at).is_equal(200)


func test_ad_limits_cannot_be_reset_by_other_device() -> void:
	var local: PlayerProfile = _profile(200, 0)
	local.ads_day_stamp = 10
	local.ads_today["basic_chest"] = 1
	local.ad_cooldowns["shop_free_gift"] = 1000
	var remote: PlayerProfile = _profile(100, 0)
	remote.ads_day_stamp = 10
	remote.ads_today["basic_chest"] = 3
	remote.ad_cooldowns["shop_free_gift"] = 5000
	var merged: PlayerProfile = ProfileMerge.merge(local, remote)
	assert_int(merged.ads_today["basic_chest"]).is_equal(3)
	assert_int(merged.ad_cooldowns["shop_free_gift"]).is_equal(5000)


func test_newer_ads_day_wins() -> void:
	var local: PlayerProfile = _profile(200, 0)
	local.ads_day_stamp = 9
	local.ads_today["basic_chest"] = 3
	var remote: PlayerProfile = _profile(100, 0)
	remote.ads_day_stamp = 10
	remote.ads_today["basic_chest"] = 1
	var merged: PlayerProfile = ProfileMerge.merge(local, remote)
	assert_int(merged.ads_day_stamp).is_equal(10)
	assert_int(merged.ads_today["basic_chest"]).is_equal(1)


func test_starter_timer_keeps_earliest_and_slots_union() -> void:
	var local: PlayerProfile = _profile(200, 0)
	local.starter_pack_expires_at = 9000
	var remote: PlayerProfile = _profile(100, 0)
	remote.starter_pack_expires_at = 5000
	remote.gear_slots_unlocked.append(&"amulet_2")
	var merged: PlayerProfile = ProfileMerge.merge(local, remote)
	assert_int(merged.starter_pack_expires_at).is_equal(5000)
	assert_bool(merged.gear_slots_unlocked.has(&"amulet_2")).is_true()


func test_two_devices_do_not_duplicate_currency() -> void:
	# Устройство А потратило, устройство Б не знало — кошелёк берётся целиком из свежего, без сложения.
	var a: PlayerProfile = _profile(300, 100)
	a.crystals = 20
	var b: PlayerProfile = _profile(250, 900)
	b.crystals = 500
	var merged: PlayerProfile = ProfileMerge.merge(a, b)
	assert_int(merged.sparks).is_equal(100)
	assert_int(merged.crystals).is_equal(20)


func test_legacy_cloud_takes_max_sparks_and_skins() -> void:
	var p: PlayerProfile = _profile(100, 700)
	CloudManager.apply_legacy_cloud(p, 1200, ["default", "pink_flame", "fire_skin"])
	assert_int(p.sparks).is_equal(1200)
	assert_bool(p.skins_unlocked.has(&"pink")).is_true()
	CloudManager.apply_legacy_cloud(p, 300, null)
	assert_int(p.sparks).is_equal(1200)


func test_corrupted_remote_is_ignored() -> void:
	assert_object(CloudManager.parse_remote("{not json")).is_null()
	assert_object(CloudManager.parse_remote(JSON.stringify(PlayerProfile.new().to_dict()))).is_not_null()
