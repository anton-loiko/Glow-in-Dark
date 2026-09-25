extends SkillBehavior
## ▲ Базовая Аура: усиливает врождённый DoT светом (+20…+100%), тик 200 мс с ур.3,
## ур.5 — раз в 3 с тройной тик. Визуал — кольцо «жара» на кромке света.

var _triple_t: float = 0.0


func modify_stats(stats: StatBlock, p_base: StatBlock) -> void:
	stats.aura_dps = p_base.aura_dps * (1.0 + float(param("dps_pct", 0)) / 100.0)
	stats.aura_tick_s = float(param("tick_s", p_base.aura_tick_s))


func _physics_process(delta: float) -> void:
	global_position = host.player.global_position
	var every: float = float(param("triple_every_s", 0.0))
	if every > 0.0:
		_triple_t += delta
		if _triple_t >= every:
			_triple_t = 0.0
			var stats: StatBlock = host.player.stats
			host.enemies.damage_in_light(stats.aura_dps * stats.aura_tick_s * 2.0)
	queue_redraw()


func _draw() -> void:
	var r: float = host.player.light_radius()
	var width: float = 9.0 if level >= 3 else 6.0
	var pulse: float = 1.0 + 0.04 * sin(Time.get_ticks_msec() / 250.0 * PI)
	var color: Color = host.player.visual.light_color
	draw_arc(Vector2.ZERO, r * pulse, 0.0, TAU, 64, Color(color, 0.18 + 0.05 * level), width)
