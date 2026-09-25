class_name DarkAuraAttack
extends EnemyAttack
## Гаситель: держится у края света, аура 3× размера «съедает» 30% света, пока игрок внутри.
## Взрыв Света снимает 25% HP и выключает ауру на 3 с.

var disabled_left: float = 0.0


func marker_kind() -> StringName:
	return &"zone"


func aura_radius(enemy: Enemy) -> float:
	return enemy.radius * float(params.get("radius_mul", 3.0))


func hunt_velocity(enemy: Enemy, to_player: Vector2, light_radius: float) -> Vector2:
	var target: float = light_radius + enemy.radius
	var dist: float = to_player.length()
	if absf(dist - target) < 12.0:
		return to_player.orthogonal().normalized() * enemy.current_speed() * 0.5
	return to_player.normalized() * enemy.current_speed() * signf(dist - target)


func tick_cooldown(delta: float) -> void:
	super.tick_cooldown(delta)
	disabled_left = maxf(0.0, disabled_left - delta)


func tick_passive(enemy: Enemy, _delta: float, manager: EnemyManager) -> void:
	if disabled_left > 0.0:
		return
	if enemy.global_position.distance_to(manager.player_position()) <= aura_radius(enemy):
		manager.request_light_drain(1.0 - float(params.get("light_drain_pct", 30)) / 100.0)


func on_light_burst(enemy: Enemy) -> void:
	enemy.take_damage(enemy.max_hp * float(params.get("burst_hp_pct", 25)) / 100.0, false)
	disabled_left = float(params.get("burst_disable_s", 3.0))
