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
