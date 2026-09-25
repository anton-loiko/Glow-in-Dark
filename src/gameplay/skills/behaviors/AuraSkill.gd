extends SkillBehavior
## ▲ Базовая Аура: усиливает врождённый DoT светом (+20…+100%), тик 200 мс с ур.3,
## ур.5 — раз в 3 с тройной тик. Визуал — кольцо «жара» на кромке света.

const RING_SHADER: Shader = preload("res://src/gameplay/shaders/aura_ring.gdshader")

var _triple_t: float = 0.0
var _ring: ColorRect
var _ring_mat: ShaderMaterial


func _ready() -> void:
	_ring = ColorRect.new()
	_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ring_mat = ShaderMaterial.new()
	_ring_mat.shader = RING_SHADER
	_ring.material = _ring_mat
	add_child(_ring)


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
	_update_ring()


## Кольцо жара — квад 2R×2R с шейдером aura_ring; толщина растёт с ур.3.
func _update_ring() -> void:
	var r: float = host.player.light_radius()
	var pulse: float = 1.0 + 0.04 * sin(Time.get_ticks_msec() / 250.0 * PI)
	var size: float = r * pulse * 2.0
	_ring.size = Vector2(size, size)
	_ring.position = -_ring.size * 0.5
	_ring_mat.set_shader_parameter(&"color", host.player.visual.light_color)
	_ring_mat.set_shader_parameter(&"ring_frac", (9.0 if level >= 3 else 6.0) / maxf(1.0, r))
	_ring_mat.set_shader_parameter(&"intensity", 0.35 + 0.08 * level)
