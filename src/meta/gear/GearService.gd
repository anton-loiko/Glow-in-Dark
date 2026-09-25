class_name GearService
extends RefCounted
## Экипировка (gear_system.md, Gear DS): прокачка за Искры Cost = ROUND(Base_Cost × 1.4^(L−1)),
## слияние 3 одинаковых → редкость выше (уровень основы сохраняется, Искры двух других возвращаются 100%),
## разбор — возврат 100% вложенных Искр. Инвентарь 40 мест.

const RARITIES: Array[StringName] = [&"common", &"uncommon", &"rare", &"epic", &"legendary"]
const MAIN_SLOTS: Array[StringName] = [&"head", &"core", &"feet", &"amulet"]


static func config() -> Dictionary:
	return ConfigDB.get_gear_config()


static func rarity_cfg(rarity: StringName) -> Dictionary:
	return (config().get("rarity", {}) as Dictionary).get(String(rarity), {}) as Dictionary


static func max_level(rarity: StringName) -> int:
	return int(rarity_cfg(rarity).get("max_lv", 10))


## Стоимость перехода на уровень target_level.
static func cost_to(rarity: StringName, target_level: int) -> int:
	var base: float = float(rarity_cfg(rarity).get("base_cost", 50))
	return roundi(base * pow(float(config().get("cost_multiplier", 1.4)), target_level - 1))


static func inventory_size() -> int:
	return int(config().get("inventory_size", 40))


static func is_inventory_full(profile: PlayerProfile) -> bool:
	return profile.gear_inventory.size() >= inventory_size()


static func new_uid() -> String:
	return "g%x%04x" % [Time.get_ticks_usec(), randi() & 0xFFFF]


static func create_item(base_id: StringName, rarity: StringName) -> PlayerProfile.GearItem:
	var def: GearItemDef = ConfigDB.get_gear_item(base_id)
	var item: PlayerProfile.GearItem = PlayerProfile.GearItem.new()
	item.uid = new_uid()
	item.base_id = base_id
	item.slot = def.slot if def != null else &"head"
	item.rarity = rarity
	item.level = 1
	item.is_new = true
	return item


static func add_item(profile: PlayerProfile, item: PlayerProfile.GearItem) -> void:
	profile.gear_inventory.append(item)
	EventBus.inventory_changed.emit()


static func stat_value(item: PlayerProfile.GearItem, level_override: int = -1) -> float:
	var def: GearItemDef = ConfigDB.get_gear_item(item.base_id)
	return 0.0 if def == null else def.stat_value(item.rarity, item.level if level_override < 0 else level_override)


## Слоты, куда можно надеть предмет: амулет — в «Амулет» и открытый Маяком «Второй амулет».
static func slots_for(profile: PlayerProfile, item: PlayerProfile.GearItem) -> Array[StringName]:
	var slots: Array[StringName] = [item.slot]
	if item.slot == &"amulet" and profile.gear_slots_unlocked.has(&"amulet_2"):
		slots.append(&"amulet_2")
	return slots


static func equipped_uid(profile: PlayerProfile, slot: StringName) -> String:
	return profile.gear_equipped.get(slot, "")


static func is_equipped(profile: PlayerProfile, uid: String) -> bool:
	return profile.gear_equipped.values().has(uid)


static func equip(profile: PlayerProfile, uid: String, slot: StringName = &"") -> bool:
	var item: PlayerProfile.GearItem = profile.find_gear(uid)
	if item == null:
		return false
	var allowed: Array[StringName] = slots_for(profile, item)
	if slot == &"":
		slot = allowed[0]
		for candidate: StringName in allowed:
			if equipped_uid(profile, candidate).is_empty():
				slot = candidate
				break
	if not allowed.has(slot):
		return false
	for s: StringName in profile.gear_equipped:
		if profile.gear_equipped[s] == uid:
			profile.gear_equipped[s] = ""
	var previous_power: float = stat_value(profile.find_gear(equipped_uid(profile, slot))) if not equipped_uid(profile, slot).is_empty() else 0.0
	profile.gear_equipped[slot] = uid
	item.is_new = false
	SaveManager.request_save()
	EventBus.gear_changed.emit(slot)
	Telemetry.log_event(&"item_equipped", {"slot": String(slot), "power_delta": snappedf(stat_value(item) - previous_power, 0.1)})
	return true


static func unequip(profile: PlayerProfile, slot: StringName) -> void:
	if equipped_uid(profile, slot).is_empty():
		return
	profile.gear_equipped[slot] = ""
	SaveManager.request_save()
	EventBus.gear_changed.emit(slot)


static func can_level_up(profile: PlayerProfile, item: PlayerProfile.GearItem) -> bool:
	return item.level < max_level(item.rarity) and profile.sparks >= cost_to(item.rarity, item.level + 1)


static func level_up(profile: PlayerProfile, uid: String) -> bool:
	var item: PlayerProfile.GearItem = profile.find_gear(uid)
	if item == null or item.level >= max_level(item.rarity):
		return false
	var cost: int = cost_to(item.rarity, item.level + 1)
	if not GameManager.spend(GameManager.SPARKS, cost, &"gear_levelup"):
		return false
	item.level += 1
	item.sparks_invested += cost
	EventBus.inventory_changed.emit()
	Telemetry.log_event(&"item_levelup", {"base_id": String(item.base_id), "rarity": String(item.rarity), "to": item.level, "cost": cost})
	return true


static func dismantle(profile: PlayerProfile, uid: String) -> int:
	var item: PlayerProfile.GearItem = profile.find_gear(uid)
	if item == null:
		return 0
	for s: StringName in profile.gear_equipped:
		if profile.gear_equipped[s] == uid:
			profile.gear_equipped[s] = ""
			EventBus.gear_changed.emit(s)
	var refund: int = roundi(item.sparks_invested * float(config().get("dismantle_refund_pct", 100)) / 100.0)
	profile.gear_inventory.erase(item)
	GameManager.grant(GameManager.SPARKS, refund, &"dismantle")
	EventBus.inventory_changed.emit()
	Telemetry.log_event(&"item_dismantled", {"rarity": String(item.rarity), "level": item.level, "refund": refund})
	SaveManager.request_save()
	return refund


static func merge_count() -> int:
	return int((config().get("merge", {}) as Dictionary).get("count", 3))


static func merge_max_result() -> StringName:
	return StringName(str((config().get("merge", {}) as Dictionary).get("max_result", "epic")))


## Может ли редкость слиться выше (слияние заканчивается на Эпическом).
static func can_merge_rarity(rarity: StringName) -> bool:
	return RARITIES.find(rarity) < RARITIES.find(merge_max_result())


## Кандидаты для слияния с предметом: тот же base_id и редкость.
static func merge_partners(profile: PlayerProfile, item: PlayerProfile.GearItem) -> Array[PlayerProfile.GearItem]:
	var result: Array[PlayerProfile.GearItem] = []
	for other: PlayerProfile.GearItem in profile.gear_inventory:
		if other.base_id == item.base_id and other.rarity == item.rarity:
			result.append(other)
	return result


## «Заполнить автоматически»: основа — с максимальным уровнем, остальные — с минимальным, надетый не трогаем.
static func auto_pick(profile: PlayerProfile, item: PlayerProfile.GearItem) -> Array[String]:
	var partners: Array[PlayerProfile.GearItem] = merge_partners(profile, item)
	partners.sort_custom(func(a: PlayerProfile.GearItem, b: PlayerProfile.GearItem) -> bool: return a.level > b.level)
	var picked: Array[String] = []
	if partners.is_empty():
		return picked
	picked.append(partners[0].uid)
	var rest: Array[PlayerProfile.GearItem] = partners.slice(1)
	rest.sort_custom(func(a: PlayerProfile.GearItem, b: PlayerProfile.GearItem) -> bool: return a.level < b.level)
	for candidate: PlayerProfile.GearItem in rest:
		if picked.size() >= merge_count():
			break
		if not is_equipped(profile, candidate.uid):
			picked.append(candidate.uid)
	return picked


## Слить предметы. Возвращает результат или null. Основа — предмет с максимальным уровнем.
static func merge(profile: PlayerProfile, uids: Array[String]) -> PlayerProfile.GearItem:
	if uids.size() != merge_count():
		return null
	var items: Array[PlayerProfile.GearItem] = []
	for uid: String in uids:
		var it: PlayerProfile.GearItem = profile.find_gear(uid)
		if it == null or items.has(it):
			return null
		items.append(it)
	for it: PlayerProfile.GearItem in items:
		if it.base_id != items[0].base_id or it.rarity != items[0].rarity:
			return null
	if not can_merge_rarity(items[0].rarity):
		return null
	items.sort_custom(func(a: PlayerProfile.GearItem, b: PlayerProfile.GearItem) -> bool: return a.level > b.level)
	var base: PlayerProfile.GearItem = items[0]
	var refund: int = 0
	for it: PlayerProfile.GearItem in items.slice(1):
		refund += it.sparks_invested
		for s: StringName in profile.gear_equipped:
			if profile.gear_equipped[s] == it.uid:
				profile.gear_equipped[s] = ""
		profile.gear_inventory.erase(it)
	var from_rarity: StringName = base.rarity
	base.rarity = RARITIES[RARITIES.find(from_rarity) + 1]
	base.level = mini(base.level, max_level(base.rarity))
	base.is_new = true
	GameManager.grant(GameManager.SPARKS, refund, &"merge_refund")
	EventBus.inventory_changed.emit()
	Telemetry.log_event(&"item_merged", {"base_id": String(base.base_id), "to_rarity": String(base.rarity), "refund": refund})
	SaveManager.request_save()
	return base


## Сколько слияний сейчас доступно (для красного счётчика на кнопке «Слияние»).
static func available_merges(profile: PlayerProfile) -> int:
	var groups: Dictionary = {}
	for it: PlayerProfile.GearItem in profile.gear_inventory:
		if can_merge_rarity(it.rarity):
			var key: String = "%s/%s" % [it.base_id, it.rarity]
			groups[key] = int(groups.get(key, 0)) + 1
	var count: int = 0
	for n: Variant in groups.values():
		count += floori(float(n) / merge_count())
	return count
