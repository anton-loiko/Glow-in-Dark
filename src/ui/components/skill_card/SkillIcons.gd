class_name SkillIcons
extends RefCounted
## Иконки навыков (tools/brand/make_skill_icons.py → src/assets/ui/skills/<id>.png, 128px, белые под modulate).

static var _cache: Dictionary = {}


static func texture(id: StringName) -> Texture2D:
	if _cache.has(id):
		return _cache[id]
	var path: String = "res://src/assets/ui/skills/%s.png" % id
	var tex: Texture2D = load(path) as Texture2D if ResourceLoader.exists(path) else null
	_cache[id] = tex
	return tex
