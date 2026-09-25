class_name TelegraphMarker
extends Node2D
## Метка атаки на полу (Enemy DS §06): линия (рывок), круг (удар), зона тьмы (аура).
## Заливка растёт за время телеграфа; метки не освещаются и видны во тьме. Пул — 6 штук.

const THREAT: Color = Color("#FF3B5C")
const ELITE: Color = Color("#B07CFF")

var kind: StringName = &"none"
var progress: float = 0.0
var _vector: Vector2
var _width: float = 0.0
var _radius: float = 0.0
var _fade_out: float = 0.0


func _init() -> void:
	var unshaded: CanvasItemMaterial = CanvasItemMaterial.new()
	unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = unshaded
	z_index = -5


func _ready() -> void:
	set_process(false)


func show_line(origin: Vector2, vector: Vector2, width: float) -> void:
	kind = &"line"
	global_position = origin
	_vector = vector
	_width = width
	_start()


func show_circle(origin: Vector2, radius: float) -> void:
	kind = &"circle"
	global_position = origin
	_radius = radius
	_start()


func show_zone(origin: Vector2, radius: float) -> void:
	kind = &"zone"
	global_position = origin
	_radius = radius
	_start()


## Враг умер во время телеграфа — метка гаснет за 120 мс.
func cancel() -> void:
	_fade_out = 0.12


func is_finished() -> bool:
	return _fade_out < 0.0


func tick(delta: float, p_progress: float) -> void:
	progress = clampf(p_progress, 0.0, 1.0)
	if _fade_out > 0.0:
		_fade_out -= delta
		modulate.a = maxf(0.0, _fade_out / 0.12)
		if _fade_out <= 0.0:
			_fade_out = -1.0
	queue_redraw()


func _start() -> void:
	progress = 0.0
	_fade_out = 0.0
	modulate.a = 1.0
	queue_redraw()


func _draw() -> void:
	match kind:
		&"line":
			var normal: Vector2 = _vector.orthogonal().normalized() * _width * 0.5
			var outline: PackedVector2Array = PackedVector2Array([normal, _vector + normal, _vector - normal, -normal, normal])
			draw_polyline(outline, THREAT, 1.5)
			var fill: Vector2 = _vector * progress
			draw_colored_polygon(PackedVector2Array([normal, fill + normal, fill - normal, -normal]), Color(THREAT, 0.28))
		&"circle":
			draw_arc(Vector2.ZERO, _radius, 0.0, TAU, 48, THREAT, 1.5)
			draw_circle(Vector2.ZERO, _radius * progress, Color(THREAT, 0.28))
		&"zone":
			draw_circle(Vector2.ZERO, _radius, Color(0.02, 0.02, 0.04, 0.45))
			for i: int in 24:
				var a: float = TAU * i / 24.0
				draw_arc(Vector2.ZERO, _radius, a, a + TAU / 48.0, 4, ELITE, 1.5)
