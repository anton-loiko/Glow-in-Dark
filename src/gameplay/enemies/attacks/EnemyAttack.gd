class_name EnemyAttack
extends RefCounted
## Атака архетипа (Enemy DS §03, §06). Базовая версия — только касание (Шёпот).
## Цикл: can_start → телеграф (≥ 400 мс, метка на полу) → execute → tick_active до завершения → кулдаун.

var params: Dictionary = {}
var cooldown_left: float = 0.0


func _init(p_params: Dictionary = {}) -> void:
	params = p_params


static func create(p_params: Dictionary) -> EnemyAttack:
	match str(p_params.get("id", "contact")):
		"dash":
			return DashAttack.new(p_params)
		"slam":
			return SlamAttack.new(p_params)
		"dark_aura":
			return DarkAuraAttack.new(p_params)
	return EnemyAttack.new(p_params)


## Вид метки: none | line | circle | zone.
func marker_kind() -> StringName:
	return &"none"


func tick_cooldown(delta: float) -> void:
	cooldown_left = maxf(0.0, cooldown_left - delta)


## Желаемая скорость в состоянии охоты.
func hunt_velocity(enemy: Enemy, to_player: Vector2, _light_radius: float) -> Vector2:
	return to_player.normalized() * enemy.current_speed()


func can_start(_enemy: Enemy, _to_player: Vector2) -> bool:
	return false


## Телеграф начался: настроить метку (marker может быть null для атак без метки).
func on_telegraph(_enemy: Enemy, _to_player: Vector2, _marker: TelegraphMarker) -> void:
	pass


## Конец телеграфа — удар. manager даёт доступ к игроку.
func execute(_enemy: Enemy, _manager: EnemyManager) -> void:
	pass


## Активная фаза после удара (рывок). Вернуть false, когда атака закончилась.
func tick_active(_enemy: Enemy, _delta: float) -> bool:
	return false


## Пассивный эффект каждый кадр (аура Гасителя).
func tick_passive(_enemy: Enemy, _delta: float, _manager: EnemyManager) -> void:
	pass
