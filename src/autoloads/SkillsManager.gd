extends Node
## Реестр рогалик-навыков и точка входа в выборку оферов (Skills DS).
## Логика весов W(s) и применение навыков реализуются в task_4; здесь — контракт API.

func _ready() -> void:
	set_process(false)


func get_def(id: StringName) -> SkillDef:
	return ConfigDB.get_skill(id)


func all_ids() -> Array[StringName]:
	return ConfigDB.get_skill_ids()


func get_tuning() -> Dictionary:
	return ConfigDB.get_skill_tuning()


## Три карточки для левел-апа. Реализация — task_4 (OfferGenerator).
func draw_offer(_run: RunContext) -> Array[SkillOffer]:
	push_warning("[SkillsManager] draw_offer is implemented in task_4")
	return []


## Перетасовать текущий оффер. Реализация — task_4.
func reroll(_run: RunContext) -> Array[SkillOffer]:
	push_warning("[SkillsManager] reroll is implemented in task_4")
	return []


## Применить выбранный навык: уровень в RunContext + сигнал для SkillHost на игроке.
func apply(run: RunContext, skill_id: StringName) -> void:
	var def: SkillDef = get_def(skill_id)
	if def == null:
		push_error("[SkillsManager] unknown skill '%s'" % skill_id)
		return
	var level_to: int = mini(run.skill_level(skill_id) + 1, def.max_level)
	run.skills[skill_id] = level_to
	EventBus.skill_selected.emit(skill_id, level_to)
