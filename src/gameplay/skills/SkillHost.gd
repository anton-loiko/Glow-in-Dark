class_name SkillHost
extends Node2D
## Навыки Огонька в забеге (Skills DS §03). Слушает EventBus.skill_selected, создаёт поведения,
## пересчитывает статы от базового снимка и раздаёт их системам (свет, скорость, магнит, камера).

const BEHAVIORS: Dictionary = {
	&"aura": preload("res://src/gameplay/skills/behaviors/AuraSkill.gd"),
	&"pulsar": preload("res://src/gameplay/skills/behaviors/PulsarSkill.gd"),
	&"trail": preload("res://src/gameplay/skills/behaviors/FireTrailSkill.gd"),
	&"beam": preload("res://src/gameplay/skills/behaviors/LightBeamSkill.gd"),
	&"orbs": preload("res://src/gameplay/skills/behaviors/OrbsSkill.gd"),
	&"capacity": preload("res://src/gameplay/skills/behaviors/CapacitySkill.gd"),
	&"shield": preload("res://src/gameplay/skills/behaviors/ShieldSkill.gd"),
	&"freeze": preload("res://src/gameplay/skills/behaviors/FreezeLightSkill.gd"),
	&"magnet": preload("res://src/gameplay/skills/behaviors/MagnetSkill.gd"),
	&"haste": preload("res://src/gameplay/skills/behaviors/HasteSkill.gd"),
	&"lens": preload("res://src/gameplay/skills/behaviors/LensSkill.gd"),
	&"cooldown": preload("res://src/gameplay/skills/behaviors/CooldownSkill.gd"),
}

var player: Player
var enemies: EnemyManager
var pickups: PickupSystem
var camera: RunCamera
var run: RunContext
var base: StatBlock
var behaviors: Dictionary[StringName, SkillBehavior] = {}


func setup(p_player: Player, p_enemies: EnemyManager, p_pickups: PickupSystem, p_camera: RunCamera, p_run: RunContext) -> void:
	player = p_player
	enemies = p_enemies
	pickups = p_pickups
	camera = p_camera
	run = p_run
	base = run.stats.duplicate_block()
	EventBus.skill_selected.connect(_on_skill_selected)
	EventBus.light_burst_triggered.connect(_on_light_burst)


func level_of(id: StringName) -> int:
	return behaviors[id].level if behaviors.has(id) else 0


func _on_skill_selected(skill_id: StringName, level_to: int) -> void:
	if skill_id == SkillsManager.FALLBACK_LIGHT:
		player.light_model.heal(player.light_model.max_value * 0.3)
		return
	if skill_id == SkillsManager.FALLBACK_SPARKS or not BEHAVIORS.has(skill_id):
		return
	if not behaviors.has(skill_id):
		var behavior: SkillBehavior = (BEHAVIORS[skill_id] as GDScript).new() as SkillBehavior
		behavior.setup(self, SkillsManager.get_def(skill_id))
		add_child(behavior)
		behaviors[skill_id] = behavior
	behaviors[skill_id].set_level(level_to)
	recompute_stats()


## Статы = базовый снимок + все пассивы. Повторный вызов не накапливает эффекты.
func recompute_stats() -> void:
	var stats: StatBlock = player.stats
	stats.max_light = base.max_light
	stats.contact_damage_mult = base.contact_damage_mult
	stats.move_speed = base.move_speed
	stats.magnet_radius = base.magnet_radius
	stats.aura_dps = base.aura_dps
	stats.aura_tick_s = base.aura_tick_s
	stats.aura_slow_pct = base.aura_slow_pct
	stats.area_scale = base.area_scale
	stats.cooldown_mult = base.cooldown_mult
	stats.light_entry_freeze_s = base.light_entry_freeze_s
	stats.env_slow_immune = base.env_slow_immune
	pickups.magnet_pulls_fuel = false
	pickups.fly_speed = pickups.fly_speed_base
	player.visual.stretch_bonus = 0.0
	for behavior: SkillBehavior in behaviors.values():
		behavior.modify_stats(stats, base)
	# Раздача статов системам, которые кэшируют значения.
	if not is_equal_approx(player.light_model.max_value, stats.max_light):
		player.light_model.set_max(stats.max_light)
	player.light_model.contact_damage_mult = stats.contact_damage_mult
	player.move_speed = stats.move_speed
	player.visual.max_speed = stats.move_speed
	pickups.magnet_radius = stats.magnet_radius
	camera.set_lens_level(level_of(&"lens"))


func reset_cooldowns() -> void:
	for behavior: SkillBehavior in behaviors.values():
		behavior.reset_cooldown()


func _on_light_burst(_origin: Vector2) -> void:
	var cd: SkillBehavior = behaviors.get(&"cooldown")
	if cd != null and bool(cd.param("reset_on_burst", false)):
		reset_cooldowns()
