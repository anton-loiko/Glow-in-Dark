class_name FloatingJoystick
extends Control
## Плавающий джойстик (DS S05): появляется в точке касания в нижних 60% экрана, 96pt,
## исчезает за 150 мс после отпускания. Выставляет действия move_* с силой наклона —
## Player читает их через Input.get_vector, как и клавиатуру.
## Работает через _input (touch и мышь): ведёт первый нажатый указатель, остальные игнорирует.

const ACTIONS: Dictionary = {
	&"move_left": Vector2.LEFT,
	&"move_right": Vector2.RIGHT,
	&"move_up": Vector2.UP,
	&"move_down": Vector2.DOWN,
}
const MOUSE_POINTER: int = -1
const NO_POINTER: int = -100

@export var zone_top_ratio: float = 0.4
@export var diameter: float = 96.0
@export var tip_diameter: float = 40.0
@export var fade_out_s: float = 0.15

var _pointer: int = NO_POINTER
var _origin: Vector2
var _vector: Vector2 = Vector2.ZERO
var _fade: Tween


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	modulate.a = 0.0
	set_process(false)


func _exit_tree() -> void:
	_release_actions()


## Текущий наклон (для тестов и отладки).
func vector() -> Vector2:
	return _vector


func _input(raw_event: InputEvent) -> void:
	# Координаты окна → локальные координаты этого Control (он растянут на весь вьюпорт).
	var event: InputEvent = make_input_local(raw_event)
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event
		if touch.pressed:
			_on_press(touch.index, touch.position)
		else:
			_on_release(touch.index)
	elif event is InputEventScreenDrag:
		var drag: InputEventScreenDrag = event
		_on_move(drag.index, drag.position)
	elif event is InputEventMouseButton:
		var button: InputEventMouseButton = event
		if button.button_index == MOUSE_BUTTON_LEFT:
			if button.pressed:
				_on_press(MOUSE_POINTER, button.position)
			else:
				_on_release(MOUSE_POINTER)
	elif event is InputEventMouseMotion:
		var motion: InputEventMouseMotion = event
		_on_move(MOUSE_POINTER, motion.position)


func _on_press(pointer: int, pos: Vector2) -> void:
	if _pointer != NO_POINTER or pos.y < size.y * zone_top_ratio:
		return
	_pointer = pointer
	_origin = pos
	_vector = Vector2.ZERO
	if _fade != null and _fade.is_valid():
		_fade.kill()
	modulate.a = 1.0
	queue_redraw()


func _on_move(pointer: int, pos: Vector2) -> void:
	if pointer != _pointer:
		return
	var radius: float = diameter * 0.5
	_vector = (pos - _origin).limit_length(radius) / radius
	_apply_actions()
	queue_redraw()


func _on_release(pointer: int) -> void:
	if pointer != _pointer:
		return
	_pointer = NO_POINTER
	_vector = Vector2.ZERO
	_release_actions()
	_fade = create_tween().set_ignore_time_scale(true)
	_fade.tween_property(self, ^"modulate:a", 0.0, fade_out_s)


func _apply_actions() -> void:
	for action: StringName in ACTIONS:
		var strength: float = maxf(0.0, _vector.dot(ACTIONS[action]))
		if strength > 0.0:
			Input.action_press(action, strength)
		else:
			Input.action_release(action)


func _release_actions() -> void:
	for action: StringName in ACTIONS:
		Input.action_release(action)


func _draw() -> void:
	var radius: float = diameter * 0.5
	draw_circle(_origin, radius, Color(UITokens.INK_600, 0.55))
	draw_arc(_origin, radius, 0.0, TAU, 48, Color(UITokens.LIGHT_500, 0.35), 1.5)
	draw_circle(_origin + _vector * radius, tip_diameter * 0.5, Color(UITokens.LIGHT_500, 0.8))
