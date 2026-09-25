class_name ChestService
extends RefCounted
## Сундуки (Gear DS §03): Базовый (500 Искр или ▶, 3 в день), Премиум (150 ◆, ×10 за 1 200 ◆, в десятке
## минимум один синий, гарант легендарного на 60-м открытии), сундук забега (серый/зелёный), эпический (Маяк, тир 7).
## Результат считается и сохраняется ДО анимации открытия (C1): закрытие приложения не теряет предмет.


static func config() -> Dictionary:
	return ConfigDB.get_config("chests")


static func rates(chest: StringName) -> Array:
	return (config().get(String(chest), {}) as Dictionary).get("rates", [100, 0, 0, 0, 0])


static func basic_ads_left(_profile: PlayerProfile) -> int:
	return AdManager.remaining(&"basic_chest")


## Открыть count сундуков типа chest. rng — для тестов; по умолчанию — глобальный.
static func open(profile: PlayerProfile, chest: StringName, count: int = 1, rng: RandomNumberGenerator = null) -> Array[PlayerProfile.GearItem]:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	var cfg: Dictionary = config().get(String(chest), {}) as Dictionary
	var pity_limit: int = int(cfg.get("legendary_pity", 0))
	var rarities: Array[StringName] = []
	for i: int in count:
		var idx: int = _roll(rates(chest), rng)
		if pity_limit > 0:
			profile.premium_pity += 1
			if idx == 4:
				profile.premium_pity = 0
			elif profile.premium_pity >= pity_limit:
				idx = 4
				profile.premium_pity = 0
		rarities.append(GearService.RARITIES[idx])
	# ×10: минимум один предмет редкости x10_min_rarity — подставляется на место последней карты.
	var min_rarity: StringName = StringName(str(cfg.get("x10_min_rarity", "")))
	if count >= 10 and min_rarity != &"":
		var min_idx: int = GearService.RARITIES.find(min_rarity)
		var has_min: bool = false
		for r: StringName in rarities:
			if GearService.RARITIES.find(r) >= min_idx:
				has_min = true
		if not has_min:
			rarities[rarities.size() - 1] = min_rarity
	var items: Array[PlayerProfile.GearItem] = []
	var slot_items: Dictionary = ConfigDB.get_gear_config().get("slot_items", {}) as Dictionary
	var slots: Array = slot_items.keys()
	for rarity: StringName in rarities:
		var slot: String = str(slots[rng.randi_range(0, slots.size() - 1)])
		var bases: Array = slot_items[slot]
		var base_id: StringName = StringName(str(bases[rng.randi_range(0, bases.size() - 1)]))
		var item: PlayerProfile.GearItem = GearService.create_item(base_id, rarity)
		if GearService.is_inventory_full(profile):
			_auto_dismantle_worst(profile)
		GearService.add_item(profile, item)
		items.append(item)
	# Порядок показа ×10: по возрастанию редкости, лучшая — последняя.
	items.sort_custom(func(a: PlayerProfile.GearItem, b: PlayerProfile.GearItem) -> bool: return GearService.RARITIES.find(a.rarity) < GearService.RARITIES.find(b.rarity))
	profile.chests_opened += count
	SaveManager.request_save(true)
	var rarity_names: Array[String] = []
	for it: PlayerProfile.GearItem in items:
		rarity_names.append(String(it.rarity))
	Telemetry.log_event(&"chest_opened", {"type": String(chest), "x": count, "rarities": rarity_names, "pity": profile.premium_pity})
	return items


## Покупка сундука из магазина: списание валюты и открытие одной транзакцией.
static func buy(profile: PlayerProfile, chest: StringName, count: int = 1) -> Array[PlayerProfile.GearItem]:
	var none: Array[PlayerProfile.GearItem] = []
	if GearService.is_inventory_full(profile):
		return none
	var cfg: Dictionary = config().get(String(chest), {}) as Dictionary
	var price: Dictionary = (cfg.get("x10_price", {}) if count >= 10 else cfg.get("price", {})) as Dictionary
	for currency: String in price:
		if not GameManager.spend(StringName(currency), int(price[currency]), StringName("chest_" + chest)):
			return none
	return open(profile, chest, count)


static func _roll(weights: Array, rng: RandomNumberGenerator) -> int:
	var total: float = 0.0
	for w: Variant in weights:
		total += float(w)
	var roll: float = rng.randf() * total
	for i: int in weights.size():
		roll -= float(weights[i])
		if roll < 0.0:
			return i
	return 0


## Инвентарь полон при сундуке забега: худший предмет разбирается автоматически (тост).
static func _auto_dismantle_worst(profile: PlayerProfile) -> void:
	var worst: PlayerProfile.GearItem = null
	for it: PlayerProfile.GearItem in profile.gear_inventory:
		if GearService.is_equipped(profile, it.uid):
			continue
		if worst == null or GearService.RARITIES.find(it.rarity) < GearService.RARITIES.find(worst.rarity) or (it.rarity == worst.rarity and it.level < worst.level):
			worst = it
	if worst != null:
		var refund: int = GearService.dismantle(profile, worst.uid)
		EventBus.toast_requested.emit(TranslationServer.translate("Инвентарь полон: худший предмет разобран (+%d Искр)") % refund, &"gear")
