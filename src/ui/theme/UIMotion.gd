class_name UIMotion
extends RefCounted
## Моушен DS §05: ease.settle = cubic-bezier(0.34, 1.12, 0.64, 1) — появление с перелётом 12%;
## ease.exit = cubic-bezier(0.4, 0, 1, 1) — уход на 30% быстрее входа. Все UI-твины — в unscaled time.


static func settle(t: float) -> float:
	return _bezier(t, 0.34, 1.12, 0.64, 1.0)


static func exit(t: float) -> float:
	return _bezier(t, 0.4, 0.0, 1.0, 1.0)


## Твин UI: игнорирует time_scale и работает при паузе мира.
static func tween(node: Node) -> Tween:
	return node.create_tween().set_ignore_time_scale(true).set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)


static func appear(node: CanvasItem, duration: float = UITokens.T_BASE_S, delay: float = 0.0) -> Tween:
	node.modulate.a = 0.0
	var t: Tween = tween(node)
	t.tween_interval(delay)
	t.tween_property(node, ^"modulate:a", 1.0, duration).set_custom_interpolator(settle)
	return t


## Покачивание 3pt — тап по Disabled (DS §02).
static func shake(control: Control) -> void:
	var start: float = control.position.x
	var t: Tween = tween(control)
	for offset: float in [3.0, -3.0, 2.0, 0.0]:
		t.tween_property(control, ^"position:x", start + offset, 0.04)


## Кубическая Безье с концами (0,0) и (1,1): находим параметр по x Ньютоном, возвращаем y.
static func _bezier(x: float, x1: float, y1: float, x2: float, y2: float) -> float:
	if x <= 0.0:
		return 0.0
	if x >= 1.0:
		return 1.0
	var t: float = x
	for i: int in 6:
		var cx: float = 3.0 * x1 * t * (1.0 - t) * (1.0 - t) + 3.0 * x2 * t * t * (1.0 - t) + t * t * t - x
		var dx: float = 3.0 * x1 * (1.0 - t) * (1.0 - 3.0 * t) + 3.0 * x2 * t * (2.0 - 3.0 * t) + 3.0 * t * t
		if absf(dx) < 0.00001:
			break
		t = clampf(t - cx / dx, 0.0, 1.0)
	return 3.0 * y1 * t * (1.0 - t) * (1.0 - t) + 3.0 * y2 * t * t * (1.0 - t) + t * t * t
