class_name ShadowEnemy
extends BaseEnemy

enum State { WANDER, FLEE, ATTACK }

const SPEED: float = 70.0
const ATTACK_SPEED: float = 90.0
const FLEE_SPEED: float = 80.0

var direction: Vector2
var current_state: State = State.WANDER

func _enemy_ready() -> void:
	# Настраиваем базовые параметры, унаследованные от BaseEnemy
	max_health = 100.0
	base_damage = 0.2
	max_light_radius = 150.0
	hit_sfx = preload("res://src/assets/audio/error_008.ogg")
	spark_scene = preload("res://src/core_loop/entities/interactables/spark/Spark.tscn")
	
	# Обязательно обновляем текущее здоровье после изменения max_health
	health = max_health
	
	var dirs: Array[Vector2] = [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]
	direction = dirs.pick_random()

func _enemy_physics_process(delta: float) -> void:
	if not player or not is_instance_valid(player):
		_wander(delta)
		return
		
	var dist_to_player = global_position.distance_to(player.global_position)
	var player_light_health = player.get("current_light_health") if player.get("current_light_health") != null else 0.5
	var current_radius = player_light_health * max_light_radius
	
	# Логика принятия решений (State Machine)
	if current_radius > 100.0:
		current_state = State.FLEE
	elif current_radius < 40.0:
		current_state = State.ATTACK
	else:
		current_state = State.WANDER
		
	match current_state:
		State.WANDER:
			_wander(delta)
		State.FLEE:
			_flee(delta)
		State.ATTACK:
			_attack(delta)

func _update_visuals() -> void:
	if current_state == State.ATTACK:
		modulate = Color(1.0, 0.2, 0.2) 
	elif current_state == State.FLEE:
		modulate = Color(0.3, 0.3, 0.5, 0.8) 
	else:
		modulate = Color.WHITE

func _wander(delta: float) -> void:
	var collision = move_and_collide(direction * SPEED * delta)
	if collision:
		direction = direction.bounce(collision.get_normal())
		direction = direction.rotated(randf_range(-0.2, 0.2)).normalized()

func _flee(_delta: float) -> void:
	var dir_away = (global_position - player.global_position).normalized()
	velocity = dir_away * FLEE_SPEED
	move_and_slide()

func _attack(_delta: float) -> void:
	var dir_to_player = (player.global_position - global_position).normalized()
	velocity = dir_to_player * ATTACK_SPEED
	move_and_slide()

func _on_player_hit(body: Node2D) -> void:
	# Уникальная реакция Теневого Врага на успешный удар — отскок в противоположную сторону
	direction = (global_position - body.global_position).normalized()
