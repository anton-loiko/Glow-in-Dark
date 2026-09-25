extends Node
## Слой данных: читает configs/*.json, проверяет обязательные ключи и собирает Def-ресурсы.
## Числа баланса живут только в JSON; визуал — в необязательных .tres (src/data/<kind>/<id>.tres).

const CONFIG_DIR: String = "res://configs/"
const DATA_DIR: String = "res://src/data/"

## Обязательные ключи верхнего уровня для каждого файла.
const REQUIRED_KEYS: Dictionary = {
	"balance": ["player", "all_stats_keys", "xp_curve", "run", "damage_numbers"],
	"skills_config": ["base_weight", "owned_mul", "magnet_mul", "max_slots", "max_level", "skills"],
	"enemies": ["scaling_per_minute", "elite", "enemies"],
	"waves": ["loop", "limits"],
	"beacon_config": ["levels", "levels_per_tier", "cost", "hold", "milestones", "tiers", "rewards"],
	"gear_config": ["slots", "rarities", "rarity", "cost_multiplier", "items"],
	"chests": ["basic", "premium", "run"],
	"shop": ["products"],
	"chapters": ["chapters"],
	"skins": ["skins"],
	"ads": ["placements"],
}

var _raw: Dictionary = {}
var _skills: Dictionary = {} ## StringName -> SkillDef
var _enemies: Dictionary = {} ## StringName -> EnemyDef
var _skins: Dictionary = {} ## StringName -> SkinDef
var _chapters: Dictionary = {} ## int -> ChapterDef
var _products: Dictionary = {} ## StringName -> ShopProductDef
var _gear_items: Dictionary = {} ## StringName -> GearItemDef
var _beacon_tiers: Array[BeaconTierDef] = []


func _ready() -> void:
	set_process(false)
	reload()


## Перечитывает все конфиги (используется и в тестах).
func reload() -> void:
	_raw.clear()
	for file_name: String in REQUIRED_KEYS.keys():
		_raw[file_name] = _load_json(file_name)
	_build_defs()


func get_config(file_name: String) -> Dictionary:
	return _raw.get(file_name, {}) as Dictionary


func get_balance() -> Dictionary:
	return get_config("balance")


func get_skill_tuning() -> Dictionary:
	return get_config("skills_config")


func get_beacon_config() -> Dictionary:
	return get_config("beacon_config")


func get_gear_config() -> Dictionary:
	return get_config("gear_config")


func get_skill(id: StringName) -> SkillDef:
	return _skills.get(id) as SkillDef


func get_skill_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	ids.assign(_skills.keys())
	return ids


func get_enemy(id: StringName) -> EnemyDef:
	return _enemies.get(id) as EnemyDef


func get_skin(id: StringName) -> SkinDef:
	return _skins.get(id) as SkinDef


func get_skin_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	ids.assign(_skins.keys())
	return ids


func get_chapter(id: int) -> ChapterDef:
	return _chapters.get(id) as ChapterDef


func get_product(id: StringName) -> ShopProductDef:
	return _products.get(id) as ShopProductDef


func get_products() -> Array[ShopProductDef]:
	var list: Array[ShopProductDef] = []
	list.assign(_products.values())
	return list


func get_gear_item(base_id: StringName) -> GearItemDef:
	return _gear_items.get(base_id) as GearItemDef


func get_beacon_tiers() -> Array[BeaconTierDef]:
	return _beacon_tiers


## Цена перехода с уровня level на level + 1: ceil10(base × growth^level) (Meta DS §00).
func get_beacon_cost(level: int) -> int:
	var cost_cfg: Dictionary = get_beacon_config().get("cost", {}) as Dictionary
	var base: float = float(cost_cfg.get("base", 60))
	var growth: float = float(cost_cfg.get("growth", 1.04))
	var rounding: int = int(cost_cfg.get("round", 10))
	var raw: float = base * pow(growth, level)
	return int(ceil(raw / rounding - 0.000001)) * rounding


func _load_json(file_name: String) -> Dictionary:
	var path: String = CONFIG_DIR + file_name + ".json"
	if not FileAccess.file_exists(path):
		_fail("Config not found: %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		_fail("Config is not a JSON object: %s" % path)
		return {}
	var data: Dictionary = parsed
	for key: String in REQUIRED_KEYS[file_name]:
		if not data.has(key):
			_fail("Config %s is missing required key '%s'" % [path, key])
	return data


func _build_defs() -> void:
	_skills.clear()
	var tuning: Dictionary = get_skill_tuning()
	for entry: Dictionary in tuning.get("skills", []):
		var skill: SkillDef = _load_visual("skills", str(entry.get("id")), SkillDef.new()) as SkillDef
		skill.base_weight = float(tuning.get("base_weight", 100))
		skill.max_level = int(tuning.get("max_level", 5))
		skill.apply_dict(entry)
		_skills[skill.id] = skill

	_enemies.clear()
	for entry: Dictionary in get_config("enemies").get("enemies", []):
		var enemy: EnemyDef = _load_visual("enemies", str(entry.get("id")), EnemyDef.new()) as EnemyDef
		enemy.apply_dict(entry)
		_enemies[enemy.id] = enemy

	_skins.clear()
	for entry: Dictionary in get_config("skins").get("skins", []):
		var skin: SkinDef = _load_visual("skins", str(entry.get("id")), SkinDef.new()) as SkinDef
		skin.apply_dict(entry)
		_skins[skin.id] = skin

	_chapters.clear()
	for entry: Dictionary in get_config("chapters").get("chapters", []):
		var chapter: ChapterDef = _load_visual("chapters", str(entry.get("id")), ChapterDef.new()) as ChapterDef
		chapter.apply_dict(entry)
		_chapters[chapter.id] = chapter

	_products.clear()
	for entry: Dictionary in get_config("shop").get("products", []):
		var product: ShopProductDef = ShopProductDef.new()
		product.apply_dict(entry)
		_products[product.id] = product

	_gear_items.clear()
	for entry: Dictionary in get_gear_config().get("items", []):
		var item: GearItemDef = _load_visual("gear", str(entry.get("base_id")), GearItemDef.new()) as GearItemDef
		item.apply_dict(entry)
		_gear_items[item.base_id] = item

	_beacon_tiers.clear()
	for entry: Dictionary in get_beacon_config().get("tiers", []):
		var tier: BeaconTierDef = BeaconTierDef.new()
		tier.apply_dict(entry)
		_beacon_tiers.append(tier)


## Если есть src/data/<kind>/<id>.tres — берём его (там визуал), иначе пустой Def.
func _load_visual(kind: String, id: String, fallback: Resource) -> Resource:
	var path: String = "%s%s/%s.tres" % [DATA_DIR, kind, id]
	if ResourceLoader.exists(path):
		var res: Resource = load(path)
		if res != null:
			return res.duplicate()
	return fallback


func _fail(message: String) -> void:
	push_error("[ConfigDB] " + message)
	assert(false, message)
