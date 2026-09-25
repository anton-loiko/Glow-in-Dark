class_name EnemyVisuals
extends RefCounted
## Банк визуалов врагов (task_8 §1–2): на архетип — CanvasTexture (альбедо + normal map) из src/assets/enemies/<id>/
## и один общий ShaderMaterial (enemy_body.gdshader) — все враги архетипа батчатся в один draw call.
## Нет ассета → null, враг рисуется процедурно (запасной путь).

const FRAMES: Dictionary = {&"whisper": 6, &"reaper": 6, &"devourer": 6, &"extinguisher": 8, &"mourner": 6}
const FPS: float = 8.0
const SHADER: Shader = preload("res://src/gameplay/shaders/enemy_body.gdshader")

static var _textures: Dictionary = {}
static var _materials: Dictionary = {}


static func texture_for(id: StringName) -> CanvasTexture:
	if _textures.has(id):
		return _textures[id]
	var base: String = "res://src/assets/enemies/%s/%s" % [id, id]
	var tex: CanvasTexture = null
	if ResourceLoader.exists(base + ".png"):
		tex = CanvasTexture.new()
		tex.diffuse_texture = load(base + ".png")
		if ResourceLoader.exists(base + "_n.png"):
			tex.normal_texture = load(base + "_n.png")
		tex.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_textures[id] = tex
	return tex


static func material_for(id: StringName) -> ShaderMaterial:
	if _materials.has(id):
		return _materials[id]
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = SHADER
	var mask: String = "res://src/assets/enemies/%s/%s_mask.png" % [id, id]
	if ResourceLoader.exists(mask):
		mat.set_shader_parameter(&"mask_tex", load(mask))
	_materials[id] = mat
	return mat


static func frame_count(id: StringName) -> int:
	return int(FRAMES.get(id, 1))
