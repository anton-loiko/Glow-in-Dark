class_name BeaconTierDef
extends Resource
## Тир Маяка (Meta DS §00, §01). Бафф общий для всех глав, награда — своя у главы.

@export var tier: int = 0
@export var buff: Dictionary = {}
@export var hub_light: float = 0.0


func apply_dict(d: Dictionary) -> void:
	tier = int(d.get("tier", tier))
	buff = d.get("buff", buff) as Dictionary
	hub_light = float(d.get("hub_light", hub_light))
