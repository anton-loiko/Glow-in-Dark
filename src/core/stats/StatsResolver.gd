class_name StatsResolver
extends RefCounted
## Сборка StatBlock из всех источников (task_1 §7):
## база → Маяки всех глав (суммируются, D5) → экипировка → скин-класс.
## Все проценты складываются и берутся от БАЗОВОГО значения, а не цепочкой (Meta DS §00):
## value = base × (1 + Σpct / 100) + Σflat.

## Ключи процентных модификаторов → поле StatBlock.
const PCT_KEYS: Dictionary = {
	"max_light_pct": "max_light",
	"light_radius_pct": "light_radius_mult",
	"decay_rate_pct": "decay_rate",
	"contact_damage_pct": "contact_damage_mult",
	"move_speed_pct": "move_speed",
	"magnet_radius_pct": "magnet_radius",
	"fuel_efficiency_pct": "fuel_efficiency",
	"spark_income_pct": "spark_income_mult",
	"aura_dps_pct": "aura_dps",
	"spawn_rate_pct": "spawn_rate_mult",
}
const LEVELS_PER_TIER: int = 10

## Плоские прибавки (например «+10 макс. яркости»).
const FLAT_KEYS: Array[String] = ["max_light", "move_speed", "magnet_radius", "aura_dps"]


## Удобная обёртка над текущими конфигами.
static func build_for(profile: PlayerProfile) -> StatBlock:
	var skin: SkinDef = ConfigDB.get_skin(profile.skin_equipped)
	return build(profile, ConfigDB.get_balance(), ConfigDB.get_beacon_tiers(), skin, ConfigDB.get_gear_config())


static func build(profile: PlayerProfile, balance: Dictionary, tiers: Array[BeaconTierDef], skin: SkinDef, gear_cfg: Dictionary) -> StatBlock:
	var base: Dictionary = balance.get("player", {}) as Dictionary
	var pct: Dictionary = {}
	var flat: Dictionary = {}

	# Маяки всех глав: баффы всех достигнутых тиров суммируются.
	var levels_per_tier: int = LEVELS_PER_TIER
	for chapter_id: int in profile.beacons:
		var reached: int = floori(float(profile.beacons[chapter_id].level) / levels_per_tier)
		for tier_def: BeaconTierDef in tiers:
			if tier_def.tier <= reached:
				_accumulate(tier_def.buff, pct, flat, balance)

	# Экипировка: Item_Stat = Base_Stat + Level × Stat_Step — плоская прибавка к стату предмета.
	var item_defs: Dictionary = {}
	for entry: Variant in gear_cfg.get("items", []):
		var def: GearItemDef = GearItemDef.new()
		def.apply_dict(entry as Dictionary)
		item_defs[def.base_id] = def
	for slot: StringName in profile.gear_equipped:
		var uid: String = profile.gear_equipped[slot]
		if uid.is_empty():
			continue
		var item: PlayerProfile.GearItem = profile.find_gear(uid)
		if item == null or not item_defs.has(item.base_id):
			continue
		var item_def: GearItemDef = item_defs[item.base_id]
		_add(flat, String(item_def.stat), item_def.stat_value(item.rarity, item.level))

	# Скин-класс.
	if skin != null:
		_accumulate(skin.mods, pct, flat, balance)

	var block: StatBlock = StatBlock.new()
	block.max_light = _resolve(float(base.get("max_light", 100.0)), "max_light", pct, flat)
	block.light_radius_mult = _resolve(1.0, "light_radius_mult", pct, flat)
	block.decay_rate = _resolve(float(base.get("decay_per_s", 0.6)), "decay_rate", pct, flat)
	block.contact_damage_mult = _resolve(1.0, "contact_damage_mult", pct, flat)
	block.move_speed = _resolve(float(base.get("move_speed", 110.0)), "move_speed", pct, flat)
	block.magnet_radius = _resolve(float(base.get("magnet_radius", 60.0)), "magnet_radius", pct, flat)
	block.fuel_efficiency = _resolve(1.0, "fuel_efficiency", pct, flat)
	block.spark_income_mult = _resolve(1.0, "spark_income_mult", pct, flat)
	block.aura_dps = _resolve(float(base.get("aura_dps", 20.0)), "aura_dps", pct, flat)
	block.spawn_rate_mult = _resolve(1.0, "spawn_rate_mult", pct, flat)
	block.revive_light_pct = float(base.get("revive_light_pct", 0.5))
	block.aura_tick_s = float(base.get("aura_tick_s", 0.25))

	if skin != null:
		block.skin_flags = skin.flags.duplicate(true)
		block.start_sparks = int(skin.flags.get("start_sparks", 0))
		block.burn_after_exit_s = float(skin.flags.get("burn_after_exit_s", 0.0))
		block.aura_slow_pct = float(skin.flags.get("aura_slow_pct", 0.0))
		block.contact_instant_burn = bool(skin.flags.get("contact_instant_burn", false))
	return block


static func _accumulate(mods: Dictionary, pct: Dictionary, flat: Dictionary, balance: Dictionary) -> void:
	for key: String in mods:
		if key.begins_with("_"):
			continue
		var value: float = float(mods[key])
		if key == "all_stats_pct":
			for stat_key: Variant in balance.get("all_stats_keys", []):
				_add(pct, str(stat_key), value)
		elif PCT_KEYS.has(key):
			_add(pct, PCT_KEYS[key], value)
		elif FLAT_KEYS.has(key):
			_add(flat, key, value)
		else:
			push_warning("[StatsResolver] unknown modifier '%s'" % key)


static func _resolve(base_value: float, field: String, pct: Dictionary, flat: Dictionary) -> float:
	return base_value * (1.0 + float(pct.get(field, 0.0)) / 100.0) + float(flat.get(field, 0.0))


static func _add(target: Dictionary, key: String, value: float) -> void:
	target[key] = float(target.get(key, 0.0)) + value
