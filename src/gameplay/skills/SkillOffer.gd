class_name SkillOffer
extends RefCounted
## Одна карточка оффера левел-апа (Skills DS §01–§04).

var skill_id: StringName
var level_to: int = 1
var weight: float = 0.0
var probability: float = 0.0
var is_new: bool = true
var is_max: bool = false
var has_synergy: bool = false
var is_fallback: bool = false


func to_telemetry() -> Dictionary:
	return {
		"id": String(skill_id),
		"level_to": level_to,
		"weight": snappedf(weight, 0.01),
		"p": snappedf(probability, 0.0001),
	}
