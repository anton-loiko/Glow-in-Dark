class_name DamageNumber
extends Node2D
## Цифра урона (Design System §02, §05): вылет по дуге вверх на 24pt за 600 мс,
## затухание последние 200 мс. Три стиля: обычный, крупный тик, смертельный (×1.5, «!»).

signal finished(number: DamageNumber)

enum Style { NORMAL, BIG_TICK, LETHAL }

const COLORS: Dictionary = {
	Style.NORMAL: Color("#FFF1D0"),
	Style.BIG_TICK: Color("#FFD166"),
	Style.LETHAL: Color("#FF3B5C"),
}
const FONT_SIZES: Dictionary = {
	Style.NORMAL: 20,
	Style.BIG_TICK: 26,
	Style.LETHAL: 34,
}
const RISE_PT: float = 24.0
const FLIGHT_S: float = 0.6
const FADE_S: float = 0.2

var _label: Label
var _tween: Tween
var _start: Vector2
var _side: float = 0.0


func _init() -> void:
	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_color_override(&"font_shadow_color", Color(0.0, 0.0, 0.0, 0.6))
	_label.add_theme_constant_override(&"shadow_offset_y", 3)
	var unshaded: CanvasItemMaterial = CanvasItemMaterial.new()
	unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_label.material = unshaded
	add_child(_label)


func _ready() -> void:
	set_process(false)


func play(amount: int, world_pos: Vector2, style: Style, size_scale: float = 1.0) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_label.text = str(amount) + ("!" if style == Style.LETHAL else "")
	_label.add_theme_color_override(&"font_color", COLORS[style])
	_label.add_theme_font_size_override(&"font_size", roundi(FONT_SIZES[style] * size_scale))
	_label.reset_size()
	_label.position = -_label.size * 0.5
	z_index = 10 if style == Style.LETHAL else 5
	global_position = world_pos
	modulate.a = 1.0
	scale = Vector2.ONE

	_side = randf_range(-12.0, 12.0)
	_start = world_pos
	_tween = create_tween()
	_tween.tween_method(_arc_step, 0.0, 1.0, FLIGHT_S).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_property(self, ^"modulate:a", 0.0, FADE_S).set_delay(FLIGHT_S - FADE_S)
	_tween.tween_callback(func() -> void: finished.emit(self))


func _arc_step(t: float) -> void:
	global_position = _start + Vector2(_side * t, -RISE_PT * sin(t * PI * 0.5))


func pool_released() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
