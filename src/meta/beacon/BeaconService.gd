class_name BeaconService
extends RefCounted
## Маяк (Meta DS §00, §04): 100 уровней на главу, 10 тиров. Внесение — списание + уровень одной транзакцией.
## Последний уровень тира вносится отдельным действием «Зажечь тир» (удержание на нём останавливается),
## после него — награда тира и кат-сцена. Баффы суммируются по всем главам (D5) — их считает StatsResolver.


static func config() -> Dictionary:
	return ConfigDB.get_beacon_config()


static func max_level() -> int:
	return int(config().get("levels", 100))


static func levels_per_tier() -> int:
	return int(config().get("levels_per_tier", 10))


static func level(profile: PlayerProfile, chapter_id: int) -> int:
	return profile.get_beacon(chapter_id).level


static func next_cost(profile: PlayerProfile, chapter_id: int) -> int:
	return ConfigDB.get_beacon_cost(level(profile, chapter_id))


static func is_max(profile: PlayerProfile, chapter_id: int) -> bool:
	return level(profile, chapter_id) >= max_level()


## Следующее внесение завершает тир (9/10 рун) — нужен отдельный тап «Зажечь тир».
static func is_tier_ready(profile: PlayerProfile, chapter_id: int) -> bool:
	var lv: int = level(profile, chapter_id)
	return lv < max_level() and (lv + 1) % levels_per_tier() == 0


static func can_afford_next(profile: PlayerProfile, chapter_id: int) -> bool:
	return not is_max(profile, chapter_id) and profile.sparks >= next_cost(profile, chapter_id)


## Внести один уровень. finish_tier = true разрешает внести последний уровень тира.
## Возвращает номер достигнутого тира (0 — тир не сменился) или -1 при отказе.
static func deposit_one(profile: PlayerProfile, chapter_id: int, finish_tier: bool = false) -> int:
	if is_max(profile, chapter_id) or (is_tier_ready(profile, chapter_id) and not finish_tier):
		return -1
	var cost: int = next_cost(profile, chapter_id)
	if not GameManager.spend(GameManager.SPARKS, cost, &"beacon"):
		return -1
	var state: PlayerProfile.BeaconState = profile.get_beacon(chapter_id)
	state.level += 1
	EventBus.beacon_level_changed.emit(chapter_id, state.level)
	if state.level % levels_per_tier() != 0:
		return 0
	var tier: int = floori(float(state.level) / levels_per_tier())
	state.pending_tier_cutscene = true
	_apply_reward(profile, chapter_id, tier)
	SaveManager.request_save(true)
	EventBus.beacon_tier_reached.emit(chapter_id, tier)
	Telemetry.log_event(&"beacon_tier", {"chapter": chapter_id, "tier": tier, "time_since_install": int(Time.get_unix_time_from_system()) - profile.install_ts})
	return tier


## Вехи 25/50/75/100%, которые уже пройдены уровнем, но ещё не показаны кат-сценой.
static func pending_milestone(profile: PlayerProfile, chapter_id: int) -> int:
	var state: PlayerProfile.BeaconState = profile.get_beacon(chapter_id)
	for milestone: Variant in config().get("milestones", []):
		var m: int = int(milestone)
		if state.level >= m and not state.seen_milestones.has(m):
			return m
	return 0


static func mark_cutscene_seen(profile: PlayerProfile, chapter_id: int, milestone: int, skipped: bool) -> void:
	var state: PlayerProfile.BeaconState = profile.get_beacon(chapter_id)
	state.pending_tier_cutscene = false
	if milestone > 0 and not state.seen_milestones.has(milestone):
		state.seen_milestones.append(milestone)
		Telemetry.log_event(&"beacon_milestone", {"pct": milestone, "skipped": skipped})
	SaveManager.request_save()


static func reward_for(chapter_id: int, tier: int) -> Dictionary:
	var rewards: Dictionary = config().get("rewards", {}) as Dictionary
	return (rewards.get(str(chapter_id), {}) as Dictionary).get(str(tier), {}) as Dictionary


## Бафф тира (одинаков для всех глав).
static func buff_for(tier: int) -> Dictionary:
	for def: BeaconTierDef in ConfigDB.get_beacon_tiers():
		if def.tier == tier:
			return def.buff
	return {}


static func _apply_reward(profile: PlayerProfile, chapter_id: int, tier: int) -> void:
	var reward: Dictionary = reward_for(chapter_id, tier)
	for key: String in reward:
		var value: Variant = reward[key]
		match key:
			"skin":
				SkinService.unlock(profile, StringName(str(value)), tier)
			"crystals":
				GameManager.grant(GameManager.CRYSTALS, int(value), &"beacon_reward")
			"gear_slot":
				var slot: StringName = StringName(str(value))
				if not profile.gear_slots_unlocked.has(slot):
					profile.gear_slots_unlocked.append(slot)
			"chest":
				profile.pending_rewards.append({"chest": str(value), "source": "beacon"})
			"chapter_unlock":
				var next_id: int = int(value)
				if not profile.unlocked_chapters.has(next_id):
					profile.unlocked_chapters.append(next_id)
