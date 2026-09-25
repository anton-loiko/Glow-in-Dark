class_name DailyGiftService
extends RefCounted
## Дар дня (DS S03): 7 дней подряд, пропуск дня сбрасывает серию на день 1. День — по локальной дате.
## «▶ ×2» удваивает Искры и Кристаллы дня. Предметы и сундуки ставятся в profile.pending_rewards (task_6).


static func today() -> int:
	var now: Dictionary = Time.get_datetime_dict_from_system()
	return roundi(Time.get_unix_time_from_datetime_dict({"year": now["year"], "month": now["month"], "day": now["day"]}) / 86400.0)


static func days() -> Array:
	return ConfigDB.get_config("daily").get("days", [])


static func is_available(profile: PlayerProfile) -> bool:
	return profile.daily_last_claim_day != today()


## Номер дня серии (1–7), который будет выдан сегодня.
static func current_day(profile: PlayerProfile) -> int:
	if profile.daily_last_claim_day == today():
		return profile.daily_streak_day
	if profile.daily_last_claim_day == today() - 1 and profile.daily_streak_day < days().size():
		return profile.daily_streak_day + 1
	return 1


## Выдать награду дня. multiplier = 2 после рекламы.
static func claim(profile: PlayerProfile, multiplier: int = 1) -> Dictionary:
	if not is_available(profile):
		return {}
	var day: int = current_day(profile)
	var reward: Dictionary = (days()[day - 1] as Dictionary).duplicate()
	for currency: String in ["sparks", "crystals"]:
		if reward.has(currency):
			GameManager.grant(StringName(currency), int(reward[currency]) * multiplier, &"daily")
	if reward.has("item") or reward.has("chest"):
		profile.pending_rewards.append(reward)
	profile.daily_streak_day = day
	profile.daily_last_claim_day = today()
	SaveManager.request_save()
	Telemetry.log_event(&"daily_claimed", {"day": day, "multiplier": multiplier})
	return reward
