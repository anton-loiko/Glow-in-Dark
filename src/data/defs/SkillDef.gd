class_name SkillDef
extends Resource
## Определение рогалик-навыка. Числа приходят из configs/skills_config.json,
## визуал (иконка, превью) — из необязательного src/data/skills/<id>.tres.

@export var id: StringName
@export var display_name: String = ""
@export var label: String = ""
@export var category: StringName ## attack | defense | utility
@export var type: StringName ## active | passive
@export var max_level: int = 5
@export var base_weight: float = 100.0
@export var synergies: Array[StringName] = []
@export var tags: Array[StringName] = []
@export var levels: Array[Dictionary] = []
@export var icon: Texture2D
@export var preview_scene: PackedScene


func apply_dict(d: Dictionary) -> void:
	id = StringName(d.get("id", id))
	display_name = str(d.get("name", display_name))
	label = str(d.get("label", label))
	category = StringName(d.get("category", category))
	type = StringName(d.get("type", type))
	max_level = int(d.get("max_level", max_level))
	base_weight = float(d.get("base_weight", base_weight))
	synergies = DefUtil.to_string_names(d.get("synergies", synergies))
	tags = DefUtil.to_string_names(d.get("tags", tags))
	var raw_levels: Array = d.get("levels", [])
	levels.clear()
	for entry: Variant in raw_levels:
		levels.append(entry as Dictionary)


func is_active() -> bool:
	return type == &"active"


## Параметры уровня 1..max_level (пустой словарь для 0).
func level_params(level: int) -> Dictionary:
	if level <= 0 or level > levels.size():
		return {}
	return levels[level - 1]


func param(level: int, key: String, fallback: Variant = 0) -> Variant:
	return level_params(level).get(key, fallback)


## Короткое значение уровня для карточки («+40%», «2 луча»).
func level_value(level: int) -> String:
	return str(level_params(level).get("value", ""))


func level_note(level: int) -> String:
	return str(level_params(level).get("note", ""))
