class_name SkinService
extends RefCounted
## Огоньки-классы (Meta DS §03): открытие (Маяк, магазин), надевание, очередь показа экрана S14.


static func is_unlocked(profile: PlayerProfile, id: StringName) -> bool:
	return profile.skins_unlocked.has(id)


static func unlock(profile: PlayerProfile, id: StringName, source_tier: int = 0) -> bool:
	if ConfigDB.get_skin(id) == null or is_unlocked(profile, id):
		return false
	profile.skins_unlocked.append(id)
	profile.skins_new_badge.append(id)
	profile.skins_to_reveal.append(id)
	SaveManager.request_save()
	EventBus.skin_unlocked.emit(id)
	Telemetry.log_event(&"skin_unlocked", {"id": String(id), "tier": source_tier})
	return true


static func equip(profile: PlayerProfile, id: StringName, source: StringName) -> bool:
	if not is_unlocked(profile, id) or profile.skin_equipped == id:
		return false
	profile.skin_equipped = id
	profile.skins_new_badge.erase(id)
	SaveManager.request_save()
	EventBus.skin_equipped.emit(id)
	Telemetry.log_event(&"skin_equipped", {"id": String(id), "source": String(source)})
	return true


static func display_name(id: StringName) -> String:
	return {&"base": "Базовый", &"ghost": "Призрачный", &"plasma": "Плазменный", &"blue": "Синее Пламя",
		&"pink": "Розовое Пламя", &"inferno": "Инферно", &"solar": "Солнечный", &"moon": "Лунный"}.get(id, String(id))
