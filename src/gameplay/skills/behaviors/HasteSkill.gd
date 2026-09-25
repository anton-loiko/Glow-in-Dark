extends SkillBehavior
## ● Ускорение: скорость +5…+25%, stretch +4% за уровень; ур.5 — иммунитет к замедлению окружения.


func modify_stats(stats: StatBlock, p_base: StatBlock) -> void:
	stats.move_speed = p_base.move_speed * (1.0 + float(param("speed_pct", 0)) / 100.0)
	stats.env_slow_immune = bool(param("env_slow_immune", false))
	host.player.visual.stretch_bonus = 0.04 * level
