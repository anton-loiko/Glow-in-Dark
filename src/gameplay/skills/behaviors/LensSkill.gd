extends SkillBehavior
## ● Фокусная Линза: масштаб всех световых атак и видимости +10% за уровень; камера отъезжает на 1.5%/ур.


func modify_stats(stats: StatBlock, p_base: StatBlock) -> void:
	stats.area_scale = p_base.area_scale * (1.0 + float(param("scale_pct", 0)) / 100.0)
