extends SkillBehavior
## ■ Замораживающий свет: враги в свете замедлены на 10–25% (с другими источниками — максимум);
## ур.5 — оцепенение 0.8 с при первом входе в свет (элита 0.4 с, Гаситель иммунен).


func modify_stats(stats: StatBlock, _base: StatBlock) -> void:
	stats.aura_slow_pct = maxf(stats.aura_slow_pct, float(param("slow_pct", 0)))
	stats.light_entry_freeze_s = float(param("stupor_s", 0.0))
