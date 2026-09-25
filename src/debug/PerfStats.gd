class_name PerfStats
extends RefCounted
## Замер времени систем (task_8 §5): скользящее среднее мс на кадр по имени системы.
## Стоит микросекунды; в релизе включено так же (данные читает только PerfOverlay в debug).

static var _start_us: Dictionary = {}
static var _avg_ms: Dictionary = {}


static func begin(system: StringName) -> void:
	_start_us[system] = Time.get_ticks_usec()


static func end(system: StringName) -> void:
	var start: int = int(_start_us.get(system, 0))
	if start == 0:
		return
	var ms: float = (Time.get_ticks_usec() - start) / 1000.0
	_avg_ms[system] = lerpf(float(_avg_ms.get(system, ms)), ms, 0.1)


static func avg_ms(system: StringName) -> float:
	return float(_avg_ms.get(system, 0.0))


static func systems() -> Array:
	return _avg_ms.keys()


static func reset() -> void:
	_start_us.clear()
	_avg_ms.clear()
