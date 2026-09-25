class_name ToggleSwitch
extends Control
## Тоггл DS §02: 48×28, вкл — light.500. Переключается тапом, анимация t.fast.

signal toggled(on: bool)

var on: bool = false
var _knob: float = 0.0


func set_on(value: bool) -> void:
	on = value
	_knob = 1.0 if on else 0.0
	queue_redraw()


func _ready() -> void:
	custom_minimum_size = Vector2(48, 28)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_STOP


func _gui_input(event: InputEvent) -> void:
	var tapped: bool = (event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT) \
		or (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed)
	if not tapped:
		return
	accept_event()
	on = not on
	FeedbackManager.haptic(&"selection")
	var t: Tween = UIMotion.tween(self)
	t.tween_method(_set_knob, _knob, 1.0 if on else 0.0, UITokens.T_FAST_S)
	toggled.emit(on)


func _set_knob(value: float) -> void:
	_knob = value
	queue_redraw()


func _draw() -> void:
	var track: StyleBoxFlat = StyleBoxFlat.new()
	track.bg_color = UITokens.LINE_STRONG.lerp(UITokens.LIGHT_500, _knob)
	track.set_corner_radius_all(14)
	draw_style_box(track, Rect2(Vector2.ZERO, custom_minimum_size))
	draw_circle(Vector2(14 + 20 * _knob, 14), 10.0, UITokens.TEXT_PRIMARY)
