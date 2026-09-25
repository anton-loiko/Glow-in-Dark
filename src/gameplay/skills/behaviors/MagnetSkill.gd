extends SkillBehavior
## ● Магнит Искр: радиус сбора +40…+160%, с ур.3 полёт ×1.3, с ур.4 тянет Топливо,
## ур.5 — «Всасывание» раз в 20 с: все искры на экране летят к игроку.

var _vacuum_t: float = 0.0


func modify_stats(stats: StatBlock, p_base: StatBlock) -> void:
	stats.magnet_radius = p_base.magnet_radius * (1.0 + float(param("radius_pct", 0)) / 100.0)
	host.pickups.fly_speed = host.pickups.fly_speed_base * float(param("fly_mul", 1.0))
	host.pickups.magnet_pulls_fuel = bool(param("pulls_fuel", false))


func _physics_process(delta: float) -> void:
	var every: float = float(param("vacuum_every_s", 0.0))
	if every <= 0.0:
		return
	_vacuum_t += delta
	if _vacuum_t >= every:
		_vacuum_t = 0.0
		host.pickups.attract_all(get_viewport_rect().size.length())
