class_name EnemyDef
extends Resource
## Архетип врага (Enemy DS §03, §07). Числа — configs/enemies.json,
## визуал — src/data/enemies/<id>.tres.

@export var id: StringName
@export var enabled: bool = true
@export var size_class: StringName = &"S"
@export var hp: float = 10.0
@export var speed: float = 70.0
@export var contact_damage_pct: float = 0.0
@export var sparks: int = 1
@export var fuel_chance: float = 0.0
@export var embers: int = 6
@export var hit_stop_ms: int = 0
@export var lethal_number_scale: float = 1.0
@export var eye_count: int = 2
@export var telegraph_ms: int = 0
@export var unlock_time_s: float = 0.0
@export var screen_limit: int = 1
@export var pool_size: int = 16
@export var knockback_resist: float = 0.0
@export var attack: Dictionary = {}
@export var sprite_frames: SpriteFrames
@export var normal_map: Texture2D


func apply_dict(d: Dictionary) -> void:
	id = StringName(d.get("id", id))
	enabled = bool(d.get("enabled", enabled))
	size_class = StringName(d.get("size_class", size_class))
	hp = float(d.get("hp", hp))
	speed = float(d.get("speed", speed))
	contact_damage_pct = float(d.get("contact_damage_pct", contact_damage_pct))
	sparks = int(d.get("sparks", sparks))
	fuel_chance = float(d.get("fuel_chance", fuel_chance))
	embers = int(d.get("embers", embers))
	hit_stop_ms = int(d.get("hit_stop_ms", hit_stop_ms))
	lethal_number_scale = float(d.get("lethal_number_scale", lethal_number_scale))
	eye_count = int(d.get("eye_count", eye_count))
	telegraph_ms = int(d.get("telegraph_ms", telegraph_ms))
	unlock_time_s = float(d.get("unlock_time_s", unlock_time_s))
	screen_limit = int(d.get("screen_limit", screen_limit))
	pool_size = int(d.get("pool_size", pool_size))
	knockback_resist = float(d.get("knockback_resist", knockback_resist))
	attack = d.get("attack", attack) as Dictionary
