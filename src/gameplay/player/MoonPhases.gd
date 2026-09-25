class_name MoonPhases
extends RefCounted
## Лунный Огонёк, класс РИТМ «Фазы Луны» (D18): цикл cycle_s — телеграф (свет сгущается) → Полнолуние
## (радиус +30%, урон ауры +40%) → Новолуние (радиус −20%) → обычный свет. Итоговый множитель радиуса
## (статы × фаза) ограничен radius_cap_mul от базового. Параметры — skins.json → moon.flags.moon_phases.

enum Phase { NORMAL, TELEGRAPH, FULL, NEW }

var cycle_s: float = 20.0
var telegraph_s: float = 1.0
var full_s: float = 6.0
var new_s: float = 6.0
var full_radius: float = 1.3
var full_aura: float = 1.4
var new_radius: float = 0.8
var radius_cap: float = 2.0
var t: float = 0.0


static func from_flags(flags: Dictionary) -> MoonPhases:
	var cfg: Dictionary = flags.get("moon_phases", {}) as Dictionary
	if cfg.is_empty():
		return null
	var m: MoonPhases = MoonPhases.new()
	m.cycle_s = float(cfg.get("cycle_s", 20.0))
	m.telegraph_s = float(cfg.get("telegraph_s", 1.0))
	m.full_s = float(cfg.get("full_s", 6.0))
	m.new_s = float(cfg.get("new_s", 6.0))
	m.full_radius = 1.0 + float(cfg.get("full_radius_pct", 30)) / 100.0
	m.full_aura = 1.0 + float(cfg.get("full_aura_dps_pct", 40)) / 100.0
	m.new_radius = 1.0 + float(cfg.get("new_radius_pct", -20)) / 100.0
	m.radius_cap = float(cfg.get("radius_cap_mul", 2.0))
	return m


func tick(delta: float) -> void:
	t = fmod(t + delta, cycle_s)


func phase() -> Phase:
	if t < telegraph_s:
		return Phase.TELEGRAPH
	if t < telegraph_s + full_s:
		return Phase.FULL
	if t < telegraph_s + full_s + new_s:
		return Phase.NEW
	return Phase.NORMAL


## Множитель радиуса фазы с учётом потолка: stat_mult × фаза ≤ radius_cap.
func radius_mult(stat_mult: float) -> float:
	var m: float = 1.0
	match phase():
		Phase.TELEGRAPH:
			m = 0.95 # свет сгущается перед Полнолунием
		Phase.FULL:
			m = full_radius
		Phase.NEW:
			m = new_radius
	return minf(m, radius_cap / maxf(0.01, stat_mult))


func aura_mult() -> float:
	return full_aura if phase() == Phase.FULL else 1.0


## Пульс энергии света — единственная индикация фазы (без UI в HUD).
func light_energy_mult() -> float:
	match phase():
		Phase.TELEGRAPH:
			return 1.0 + 0.25 * absf(sin(t * TAU * 3.0))
		Phase.FULL:
			return 1.2
		Phase.NEW:
			return 0.8
	return 1.0
