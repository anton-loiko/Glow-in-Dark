class_name FogLayer
extends Node2D
## Туман главы (task_8 §2): квад на весь кадр, следует за камерой; шум сдвигается с параллаксом 0.8×,
## поэтому клубы «отстают» от пола и дают глубину. Слой идёт сразу после пола — под пикапами и врагами.

const SHADER: Shader = preload("res://src/gameplay/shaders/fog.gdshader")

var camera: Camera2D
var _rect: ColorRect
var _mat: ShaderMaterial


func setup(p_camera: Camera2D, color: Color, density: float) -> void:
	camera = p_camera
	_rect = ColorRect.new()
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_mat.set_shader_parameter(&"color", color)
	_mat.set_shader_parameter(&"density", density)
	_rect.material = _mat
	add_child(_rect)


func _process(_delta: float) -> void:
	if camera == null:
		return
	var view: Vector2 = get_viewport_rect().size / camera.zoom * 1.2
	var center: Vector2 = camera.get_screen_center_position()
	_rect.size = view
	_rect.position = center - view * 0.5
	# Координата тумана = мир − 20% смещения камеры → параллакс 0.8×.
	_mat.set_shader_parameter(&"world_offset", _rect.position - center * 0.2)
