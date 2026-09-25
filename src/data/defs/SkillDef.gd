class_name SkillDef
extends Resource
## Определение рогалик-навыка. Числа приходят из configs/skills_config.json,
## визуал (иконка, превью) — из необязательного src/data/skills/<id>.tres.

@export var id: StringName
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
