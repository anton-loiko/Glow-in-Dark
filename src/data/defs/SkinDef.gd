class_name SkinDef
extends Resource
## Огонёк-класс (Meta DS §03). mods — проценты от базовых статов, flags — особые механики.

@export var id: StringName
@export var light_color: Color = Color("#FFB547")
@export var rim_color: Color = Color("#FFB547")
@export var class_key: String = ""
@export var plus: String = ""
@export var minus: String = ""
@export var class_title: String = ""
@export var unlock: Dictionary = {}
@export var mods: Dictionary = {}
@export var flags: Dictionary = {}
@export var sprite_frames: SpriteFrames


func apply_dict(d: Dictionary) -> void:
	id = StringName(d.get("id", id))
	light_color = DefUtil.color_or(d.get("light"), light_color)
	rim_color = DefUtil.color_or(d.get("rim"), light_color)
	class_key = str(d.get("class_key", class_key))
	plus = str(d.get("plus", plus))
	minus = str(d.get("minus", minus))
	class_title = str(d.get("class_name", class_title))
	unlock = d.get("unlock", unlock) as Dictionary
	mods = d.get("mods", mods) as Dictionary
	flags = d.get("flags", flags) as Dictionary
