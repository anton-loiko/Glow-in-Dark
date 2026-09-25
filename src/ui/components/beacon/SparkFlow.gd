class_name SparkFlow
extends Control
## Поток искр из пилюли в кристалл при внесении (Meta DS §01): искры летят по кривой Безье 500 мс,
## чем дольше удержание — тем гуще поток. Рисуются примитивами в собственном _draw (без текстур).

const FLIGHT_S: float = 0.5
const MAX_SPARKS: int = 120

var _sparks: Array[Dictionary] = [] ## {from, ctrl, to, t}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)


## Выпустить count искр от точки from к точке to (координаты узла).
func emit(from: Vector2, to: Vector2, count: int) -> void:
	for i: int in count:
		if _sparks.size() >= MAX_SPARKS:
			break
		var mid: Vector2 = from.lerp(to, 0.5)
		var ctrl: Vector2 = mid + Vector2(randf_range(-90, 90), randf_range(-60, 20))
		_sparks.append({"from": from + Vector2(randf_range(-6, 6), randf_range(-4, 4)), "ctrl": ctrl, "to": to, "t": -i * 0.03})
	set_process(true)


func _process(delta: float) -> void:
	for i: int in range(_sparks.size() - 1, -1, -1):
		var spark: Dictionary = _sparks[i]
		spark["t"] = float(spark["t"]) + delta / FLIGHT_S
		if float(spark["t"]) >= 1.0:
			_sparks.remove_at(i)
	if _sparks.is_empty():
		set_process(false)
	queue_redraw()


func _draw() -> void:
	for s: Dictionary in _sparks:
		var t: float = float(s["t"])
		if t < 0.0:
			continue
		var e: float = t * t * (3.0 - 2.0 * t)
		var a: Vector2 = (s["from"] as Vector2).lerp(s["ctrl"], e)
		var b: Vector2 = (s["ctrl"] as Vector2).lerp(s["to"], e)
		var p: Vector2 = a.lerp(b, e)
		draw_circle(p, 4.0, Color(UITokens.SPARK, 0.25))
		draw_circle(p, 2.0, UITokens.SPARK_FLASH)
