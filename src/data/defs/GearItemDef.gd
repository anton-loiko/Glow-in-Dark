class_name GearItemDef
extends Resource
## Базовый предмет экипировки (gear_system.md §1, §4). Статы по редкостям:
## { "<rarity>": { "base": float, "step": float } }.

@export var base_id: StringName
@export var slot: StringName
@export var stat: StringName
@export var stats_by_rarity: Dictionary = {}
@export var name_key: String = ""
@export var icon: Texture2D


func apply_dict(d: Dictionary) -> void:
	base_id = StringName(d.get("base_id", base_id))
	slot = StringName(d.get("slot", slot))
	stat = StringName(d.get("stat", stat))
	stats_by_rarity = d.get("stats", stats_by_rarity) as Dictionary
	name_key = str(d.get("name_key", name_key))


## Item_Stat = Base_Stat + Level × Stat_Step.
func stat_value(rarity: StringName, level: int) -> float:
	var entry: Dictionary = stats_by_rarity.get(String(rarity), {}) as Dictionary
	if entry.is_empty():
		return 0.0
	return float(entry.get("base", 0.0)) + level * float(entry.get("step", 0.0))
