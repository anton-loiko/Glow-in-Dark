extends SkillBehavior
## ■ Энергоёмкость: +10% максимального света за уровень (радиус Ауры растёт вместе с ним);
## ур.5 — одно спасение от смертельного удара.

var _saves_left: int = 0


func set_level(p_level: int) -> void:
	super.set_level(p_level)
	if int(param("lethal_saves", 0)) > 0 and _saves_left == 0 and not host.player.light_model.lethal_guard.is_valid():
		_saves_left = int(param("lethal_saves", 1))
		host.player.light_model.lethal_guard = _on_lethal


func modify_stats(stats: StatBlock, p_base: StatBlock) -> void:
	stats.max_light = p_base.max_light * (1.0 + float(param("max_light_pct", 0)) / 100.0)


func _on_lethal() -> bool:
	if _saves_left <= 0:
		return false
	_saves_left -= 1
	host.player.light_model.grant_invulnerability(1.0)
	FeedbackManager.haptic(&"heavy")
	return true
