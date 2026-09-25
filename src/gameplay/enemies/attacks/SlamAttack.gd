class_name SlamAttack
extends EnemyAttack
## Пожиратель: «вдох» +12% и красный круг 1.5 размера (700 мс), затем удар по площади.

func marker_kind() -> StringName:
	return &"circle"


func slam_radius(enemy: Enemy) -> float:
	return enemy.radius * float(params.get("radius_mul", 1.5))


func can_start(enemy: Enemy, to_player: Vector2) -> bool:
	return cooldown_left <= 0.0 and to_player.length() <= slam_radius(enemy) * 0.9


func on_telegraph(enemy: Enemy, _to_player: Vector2, marker: TelegraphMarker) -> void:
	marker.show_circle(enemy.global_position, slam_radius(enemy))


func execute(enemy: Enemy, manager: EnemyManager) -> void:
	cooldown_left = float(params.get("cooldown_s", 3.0))
	if enemy.global_position.distance_to(manager.player_position()) <= slam_radius(enemy):
		manager.hit_player(enemy, &"slam")
