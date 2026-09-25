class_name GearText
extends RefCounted
## Подписи предметов и статов экипировки.

const SLOT_NAMES: Dictionary = {&"head": "Шлем", &"core": "Ядро", &"feet": "Ботинки", &"amulet": "Амулет", &"amulet_2": "Второй амулет"}


static func slot_name(slot: StringName) -> String:
	return TranslationServer.translate(SLOT_NAMES.get(slot, String(slot)))


static func item_name(item: PlayerProfile.GearItem) -> String:
	var def: GearItemDef = ConfigDB.get_gear_item(item.base_id)
	return TranslationServer.translate(def.name_key if def != null else String(item.base_id))


static func rarity_name(rarity: StringName) -> String:
	var tokens: Dictionary = UITokens.RARITY.get(rarity, {}) as Dictionary
	return TranslationServer.translate(str(tokens.get("name", String(rarity))))


static func rarity_color(rarity: StringName) -> Color:
	var tokens: Dictionary = UITokens.RARITY.get(rarity, UITokens.RARITY[&"common"]) as Dictionary
	return tokens["300"]


## «+12 макс. яркости», «−6% затухания» и т. п.
static func stat_text(stat: StringName, value: float) -> String:
	var v: String = num(value)
	match stat:
		&"max_light":
			return TranslationServer.translate("+%s макс. яркости") % v
		&"decay_rate_pct":
			return TranslationServer.translate("−%s%% затухания") % num(absf(value))
		&"move_speed_pct":
			return TranslationServer.translate("+%s%% скорости") % v
		&"spark_income_pct":
			return TranslationServer.translate("+%s%% дохода Искр") % v
		&"magnet_radius_pct":
			return TranslationServer.translate("+%s%% радиуса магнита") % v
	return "+%s %s" % [v, String(stat)]


static func stat_item(item: PlayerProfile.GearItem) -> StringName:
	var def: GearItemDef = ConfigDB.get_gear_item(item.base_id)
	return def.stat if def != null else &""


static func num(value: float) -> String:
	return str(int(value)) if is_equal_approx(value, roundf(value)) else "%.1f" % value
