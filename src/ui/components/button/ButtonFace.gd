class_name ButtonFace
extends Control
## «Лицо» заливных кнопок DS §02 (Primary, Crystal): градиент 300 → 500 → 700 сверху вниз, цоколь 4pt цвета 900,
## мягкое свечение G2 (только Primary). Нажатие: цоколь 0, тело смещается на +4pt.
## Рисуется за текстом кнопки (show_behind_parent) — StyleBoxFlat градиент не умеет.

const PLINTH: float = 4.0

## Палитры: верх, середина, низ тела, цоколь, свечение (альфа 0 — без свечения).
const PRIMARY: Array[Color] = [UITokens.LIGHT_300, UITokens.LIGHT_500, UITokens.LIGHT_700, UITokens.LIGHT_900, Color(UITokens.LIGHT_500, 0.35)]
const CRYSTAL: Array[Color] = [UITokens.CRYSTAL_300, UITokens.CRYSTAL_500, UITokens.CRYSTAL_700, Color("#1B6C78"), Color(UITokens.CRYSTAL_500, 0.0)]
## Инверсия S09: чернильная кнопка на янтарном фоне.
const INVERTED: Array[Color] = [Color("#3A2410"), Color("#2A1606"), Color("#1E0F04"), Color("#120902"), Color(0, 0, 0, 0.18)]

var palette: Array[Color] = PRIMARY
var _button: BaseButton
var _base_box: StyleBoxFlat = StyleBoxFlat.new()


func _ready() -> void:
	_button = get_parent() as BaseButton
	show_behind_parent = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_base_box.set_corner_radius_all(UITokens.R14)
	_base_box.anti_aliasing = true
	for sig: Signal in [_button.button_down, _button.button_up, _button.mouse_entered, _button.mouse_exited]:
		sig.connect(queue_redraw)


func set_palette(value: Array[Color]) -> void:
	palette = value
	queue_redraw()


func _draw() -> void:
	if _button == null or _button.disabled:
		return
	var pressed: bool = _button.get_draw_mode() == BaseButton.DRAW_PRESSED or _button.get_draw_mode() == BaseButton.DRAW_HOVER_PRESSED
	_base_box.bg_color = palette[3]
	_base_box.shadow_color = palette[4]
	_base_box.shadow_size = 12 if palette[4].a > 0.0 and not pressed else 0
	draw_style_box(_base_box, Rect2(Vector2(0, PLINTH if pressed else 0.0), size - Vector2(0, PLINTH if pressed else 0.0)))
	var body: Rect2 = Rect2(Vector2(0, PLINTH if pressed else 0.0), Vector2(size.x, size.y - PLINTH))
	var points: PackedVector2Array = rounded_rect(body, UITokens.R14)
	var colors: PackedColorArray = PackedColorArray()
	for p: Vector2 in points:
		colors.append(_gradient((p.y - body.position.y) / body.size.y))
	draw_polygon(points, colors)
	var outline: PackedVector2Array = points.duplicate()
	outline.append(points[0])
	var outline_colors: PackedColorArray = colors.duplicate()
	outline_colors.append(colors[0])
	draw_polyline_colors(outline, outline_colors, 1.0, true)
	# Тёплый блик 1pt сверху — кнопка освещена Огоньком.
	draw_line(body.position + Vector2(UITokens.R14, 1.0), body.position + Vector2(body.size.x - UITokens.R14, 1.0), Color(1, 1, 1, 0.35), 1.0, true)


func _gradient(t: float) -> Color:
	t = clampf(t, 0.0, 1.0)
	return palette[0].lerp(palette[1], t / 0.5) if t < 0.5 else palette[1].lerp(palette[2], (t - 0.5) / 0.5 * 0.6)


## Скруглённый прямоугольник полигоном (по 8 сегментов на угол).
static func rounded_rect(rect: Rect2, radius: float) -> PackedVector2Array:
	var r: float = minf(radius, minf(rect.size.x, rect.size.y) * 0.5)
	var points: PackedVector2Array = PackedVector2Array()
	var centers: Array[Vector2] = [rect.position + Vector2(rect.size.x - r, r), rect.end - Vector2(r, r),
		rect.position + Vector2(r, rect.size.y - r), rect.position + Vector2(r, r)]
	for corner: int in 4:
		var start: float = -PI * 0.5 + PI * 0.5 * corner
		for i: int in 9:
			points.append(centers[corner] + Vector2.from_angle(start + PI * 0.5 * i / 8.0) * r)
	return points
