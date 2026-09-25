class_name StatBlock
extends RefCounted
## Итоговые статы Огонька на старт забега. Собирается StatsResolver из базы (balance.json),
## Маяков, экипировки и скина-класса. Навыки забега меняют копию в рантайме (task_4).

var max_light: float = 100.0
var light_radius_mult: float = 1.0
var decay_rate: float = 0.6
var contact_damage_mult: float = 1.0
var move_speed: float = 110.0
var magnet_radius: float = 60.0
var fuel_efficiency: float = 1.0
var spark_income_mult: float = 1.0
var aura_dps: float = 20.0
var aura_slow_pct: float = 0.0
var area_scale: float = 1.0
var cooldown_mult: float = 1.0
var revive_light_pct: float = 0.5
var spawn_rate_mult: float = 1.0
var start_sparks: int = 0
var burn_after_exit_s: float = 0.0
var contact_instant_burn: bool = false
var skin_flags: Dictionary = {}


func duplicate_block() -> StatBlock:
	var copy: StatBlock = StatBlock.new()
	for prop: Dictionary in get_property_list():
		if prop["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE:
			var value: Variant = get(prop["name"])
			if value is Dictionary:
				var dict_value: Dictionary = value
				value = dict_value.duplicate(true)
			copy.set(prop["name"], value)
	return copy
