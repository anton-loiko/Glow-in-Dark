class_name HubDiorama
extends Control
## Город главы за Маяком (Meta DS §01): hi-res диорама src/assets/beacon/hub_diorama_ch<N>.png (780×1100, 2×),
## масштаб «по ширине» и сдвиг так, чтобы островок (0.5, 0.8 текстуры) оказался под постаментом.
## Проявление светом хаба и «дневная» палитра тира 10 — шейдер hub_reveal.

const SHADER: Shader = preload("res://src/ui/theme/shaders/hub_reveal.gdshader")
const ISLAND_UV: Vector2 = Vector2(0.5, 0.8)

var anchor_point: Vector2 = Vector2.ZERO ## точка под постаментом в координатах узла
var _tex: Texture2D
var _mat: ShaderMaterial


func setup(chapter_id: int) -> bool:
	var path: String = "res://src/assets/beacon/hub_diorama_ch%d.png" % chapter_id
	if not ResourceLoader.exists(path):
		path = "res://src/assets/beacon/hub_diorama_ch1.png" # главы 2–3 — своя диорама в бэклоге
	if not ResourceLoader.exists(path):
		return false
	_tex = load(path)
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	material = _mat
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	return true


func set_light(radius_px: float, day_mix: float, breath: float, color: Color = UITokens.LIGHT_500) -> void:
	if _mat == null:
		return
	_mat.set_shader_parameter(&"warm", color)
	_mat.set_shader_parameter(&"center_px", anchor_point)
	_mat.set_shader_parameter(&"radius_px", radius_px)
	_mat.set_shader_parameter(&"day_mix", day_mix)
	_mat.set_shader_parameter(&"breath", breath)
	queue_redraw()


func _draw() -> void:
	if _tex == null:
		return
	var k: float = size.x / float(_tex.get_width()) * 1.15
	var draw_size: Vector2 = Vector2(_tex.get_width(), _tex.get_height()) * k
	var pos: Vector2 = anchor_point - draw_size * ISLAND_UV
	draw_texture_rect(_tex, Rect2(pos, draw_size), false)
