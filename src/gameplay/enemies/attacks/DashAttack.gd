class_name DashAttack
extends EnemyAttack
## Жнец: подкрадывается до approach_pt, замирает, телеграф-линия 500 мс, рывок dash_pt по прямой, КД 3 с.

var _dir: Vector2 = Vector2.ZERO
var _dash_left: float = 0.0


func marker_kind() -> StringName:
	return &"line"


func hunt_velocity(enemy: Enemy, to_player: Vector2, _light_radius: float) -> Vector2:
	if to_player.length() <= float(params.get("approach_pt", 200.0)) and cooldown_left > 0.0:
		return Vector2.ZERO
	return to_player.normalized() * enemy.current_speed()


func can_start(_enemy: Enemy, to_player: Vector2) -> bool:
	return cooldown_left <= 0.0 and to_player.length() <= float(params.get("approach_pt", 200.0))


func on_telegraph(enemy: Enemy, to_player: Vector2, marker: TelegraphMarker) -> void:
	_dir = to_player.normalized()
	marker.show_line(enemy.global_position, _dir * float(params.get("dash_pt", 180.0)), enemy.radius * 2.0)


func execute(_enemy: Enemy, _manager: EnemyManager) -> void:
	_dash_left = float(params.get("dash_pt", 180.0)) / float(params.get("dash_speed", 320.0))
	cooldown_left = float(params.get("cooldown_s", 3.0))


func tick_active(enemy: Enemy, delta: float) -> bool:
	if _dash_left <= 0.0:
		return false
	_dash_left -= delta
	enemy.velocity = _dir * float(params.get("dash_speed", 320.0))
	return true
