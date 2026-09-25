class_name SkillBehavior
extends Node2D
## Поведение навыка в забеге. Создаётся SkillHost при первом выборе, уровень растёт при повторных.
## Активные навыки (▲) тикают сами; пассивы меняют статы через SkillHost.recompute_stats().

var host: SkillHost
var def: SkillDef
var level: int = 0


func setup(p_host: SkillHost, p_def: SkillDef) -> void:
	host = p_host
	def = p_def
	z_index = 4
	set_process(false)


func set_level(p_level: int) -> void:
	level = p_level


func param(key: String, fallback: Variant = 0) -> Variant:
	return def.param(level, key, fallback)


## Перезарядка сброшена (Перезарядка ур.5 после Взрыва Света).
func reset_cooldown() -> void:
	pass


## Модификация статов пассивом; base — неизменный снимок статов на старт забега.
func modify_stats(_stats: StatBlock, _base: StatBlock) -> void:
	pass


func cooldown(base_s: float) -> float:
	return base_s * host.player.stats.cooldown_mult
