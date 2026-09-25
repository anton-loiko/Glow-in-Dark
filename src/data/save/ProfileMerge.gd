class_name ProfileMerge
extends RefCounted
## Слияние локального и облачного профиля (task_1 §4). Прогресс не теряется,
## а валюта не дюпается: кошелёк берётся целиком из более свежего профиля.


static func merge(local: PlayerProfile, remote: PlayerProfile) -> PlayerProfile:
	var local_is_newer: bool = local.updated_at >= remote.updated_at
	var newer: PlayerProfile = local if local_is_newer else remote
	var older: PlayerProfile = remote if local_is_newer else local
	var result: PlayerProfile = newer.duplicate_profile()

	# Маяки: максимальный уровень по каждой главе, вехи объединяются.
	for chapter_id: int in older.beacons:
		var theirs: PlayerProfile.BeaconState = older.beacons[chapter_id]
		var ours: PlayerProfile.BeaconState = result.get_beacon(chapter_id)
		if theirs.level > ours.level:
			ours.level = theirs.level
			ours.pending_tier_cutscene = theirs.pending_tier_cutscene
		for m: int in theirs.seen_milestones:
			if not ours.seen_milestones.has(m):
				ours.seen_milestones.append(m)

	# Главы: объединение открытых, лучшее время — максимум.
	for id: int in older.unlocked_chapters:
		if not result.unlocked_chapters.has(id):
			result.unlocked_chapters.append(id)
	result.unlocked_chapters.sort()
	for id: int in older.best_time_s:
		result.best_time_s[id] = maxf(result.best_time_s.get(id, 0.0), older.best_time_s[id])

	# Скины и архив навыков: объединение.
	_union_names(result.skins_unlocked, older.skins_unlocked)
	_union_names(result.skins_new_badge, older.skins_new_badge)
	_union_names(result.skills_seen, older.skills_seen)

	# Инвентарь: объединение по uid, при совпадении — версия из свежего профиля.
	for item: PlayerProfile.GearItem in older.gear_inventory:
		if result.find_gear(item.uid) == null:
			result.gear_inventory.append(PlayerProfile.GearItem.from_dict(item.to_dict()))

	_union_names(result.gear_slots_unlocked, older.gear_slots_unlocked)

	# Лимиты рекламы: не даём обойти «3 в день» / «раз в 8 ч» сменой устройства.
	for key: String in older.ad_cooldowns:
		result.ad_cooldowns[key] = maxi(result.ad_cooldowns.get(key, 0), older.ad_cooldowns[key])
	if older.ads_day_stamp > result.ads_day_stamp:
		result.ads_day_stamp = older.ads_day_stamp
		result.ads_today = older.ads_today.duplicate()
	elif older.ads_day_stamp == result.ads_day_stamp:
		for key: String in older.ads_today:
			result.ads_today[key] = maxi(result.ads_today.get(key, 0), older.ads_today[key])

	# FOMO-таймер стартер-пака — самый ранний показ.
	if older.starter_pack_expires_at > 0 and (result.starter_pack_expires_at == 0 or older.starter_pack_expires_at < result.starter_pack_expires_at):
		result.starter_pack_expires_at = older.starter_pack_expires_at

	# Гарант сундука — максимум (не даём сбросить прогресс гаранта откатом).
	result.premium_pity = maxi(result.premium_pity, older.premium_pity)

	# Покупки: нерасходуемые покупки не теряются, чеки объединяются.
	result.starter_pack_bought = result.starter_pack_bought or older.starter_pack_bought
	for r: String in older.receipts:
		if not result.receipts.has(r):
			result.receipts.append(r)

	if older.install_ts > 0 and (result.install_ts == 0 or older.install_ts < result.install_ts):
		result.install_ts = older.install_ts
	result.updated_at = maxi(local.updated_at, remote.updated_at)
	result.device_id = local.device_id
	return result


static func _union_names(target: Array[StringName], source: Array[StringName]) -> void:
	for n: StringName in source:
		if not target.has(n):
			target.append(n)
