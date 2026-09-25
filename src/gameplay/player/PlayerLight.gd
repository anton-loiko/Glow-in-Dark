class_name PlayerLight
extends Node
## Модель света Огонька (GDD 3.1, task_2 §1): свет = HP = радиус оружия.
## Мягкое затухание (decay), урон касаний в % от максимума, лечение топливом, неуязвимость.
## Публикует EventBus.player_light_changed / player_damaged / player_light_depleted.

signal depleted

var max_value: float = 100.0
var current: float = 100.0
var decay_rate: float = 0.6
var contact_damage_mult: float = 1.0
var fuel_efficiency: float = 1.0
var danger_threshold: float = 0.25

## Последний шанс (Энергоёмкость ур.5, task_4): вернуть true, чтобы пережить смертельный удар.
var lethal_guard: Callable

var _invulnerable_left: float = 0.0
var _depleted: bool = false
var _last_emitted: float = -1.0


func setup(stats: StatBlock, balance: Dictionary) -> void:
	max_value = stats.max_light
	current = max_value
	decay_rate = stats.decay_rate
	contact_damage_mult = stats.contact_damage_mult
	fuel_efficiency = stats.fuel_efficiency
	danger_threshold = float((balance.get("player", {}) as Dictionary).get("danger_threshold_pct", 0.25))
	_depleted = false
	_emit_changed()


func _physics_process(delta: float) -> void:
	if _depleted:
		return
	if _invulnerable_left > 0.0:
		_invulnerable_left = maxf(0.0, _invulnerable_left - delta)
	_set_current(current - decay_rate * delta)


func ratio() -> float:
	return 0.0 if max_value <= 0.0 else current / max_value


func is_in_danger() -> bool:
	return ratio() < danger_threshold


func is_depleted() -> bool:
	return _depleted


func is_invulnerable() -> bool:
	return _invulnerable_left > 0.0


func grant_invulnerability(seconds: float) -> void:
	_invulnerable_left = maxf(_invulnerable_left, seconds)


## Урон касания в процентах от максимального света. Возвращает фактически снятый свет.
func apply_damage(amount_pct_of_max: float, source: StringName) -> float:
	if _depleted or is_invulnerable() or amount_pct_of_max <= 0.0:
		return 0.0
	var amount: float = max_value * amount_pct_of_max / 100.0 * contact_damage_mult
	if current - amount <= 0.0 and lethal_guard.is_valid() and bool(lethal_guard.call()):
		amount = maxf(0.0, current - 1.0)
	_set_current(current - amount)
	EventBus.player_damaged.emit(amount, source)
	return amount


## Лечение (топливо). Эффективность топлива учитывается здесь.
func heal_fuel(base_amount: float) -> float:
	return heal(base_amount * fuel_efficiency)


func heal(amount: float) -> float:
	if _depleted or amount <= 0.0:
		return 0.0
	var before: float = current
	_set_current(current + amount)
	return current - before


## Новый максимум (Энергоёмкость); свет растёт вместе с максимумом.
func set_max(value: float) -> void:
	var delta_max: float = value - max_value
	max_value = maxf(1.0, value)
	_set_current(current + maxf(0.0, delta_max))


## Воскрешение: свет = pct от максимума.
func revive(pct: float) -> void:
	_depleted = false
	_set_current(max_value * pct)


func _set_current(value: float) -> void:
	current = clampf(value, 0.0, max_value)
	_emit_changed()
	if current <= 0.0 and not _depleted:
		_depleted = true
		depleted.emit()
		EventBus.player_light_depleted.emit()


func _emit_changed() -> void:
	if is_equal_approx(current, _last_emitted):
		return
	_last_emitted = current
	EventBus.player_light_changed.emit(current, max_value)
