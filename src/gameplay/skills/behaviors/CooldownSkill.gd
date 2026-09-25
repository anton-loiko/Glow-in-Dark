extends SkillBehavior
## ● Перезарядка: кулдауны активных навыков −8…−40% (предел −40%); ур.5 — сброс КД после Взрыва Света.

const MIN_MULT: float = 0.6


func modify_stats(stats: StatBlock, p_base: StatBlock) -> void:
	stats.cooldown_mult = maxf(MIN_MULT, p_base.cooldown_mult * (1.0 - float(param("cd_pct", 0)) / 100.0))
