class_name ChapterDef
extends Resource
## Глава (GDD 3.2): биом, длительность забега, условие открытия.

@export var id: int = 1
@export var name_key: String = ""
@export var biome: StringName
@export var duration_s: float = 600.0
@export var unlock: Dictionary = {}
@export var chunk_scenes: Array[PackedScene] = []


func apply_dict(d: Dictionary) -> void:
	id = int(d.get("id", id))
	name_key = str(d.get("name_key", name_key))
	biome = StringName(d.get("biome", biome))
	duration_s = float(d.get("duration_s", duration_s))
	unlock = d.get("unlock", unlock) as Dictionary
