extends SkillBehavior
## ■ Щит: урон касаний −10…−30% (естественное затухание не трогает); ур.5 — +1 света каждые 5 с.

var _regen_t: float = 0.0


func modify_stats(stats: StatBlock, p_base: StatBlock) -> void:
	stats.contact_damage_mult = p_base.contact_damage_mult * (1.0 - float(param("reduction_pct", 0)) / 100.0)


func _physics_process(delta: float) -> void:
	var regen: float = float(param("regen_per_5s", 0))
	if regen <= 0.0:
		return
	_regen_t += delta
	if _regen_t >= 5.0:
		_regen_t = 0.0
		host.player.light_model.heal(regen)
