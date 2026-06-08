class_name ShadowEnemy
extends CharacterBody2D

enum State { WANDER, FLEE, ATTACK }

const SPEED: float = 70.0
const ATTACK_SPEED: float = 90.0
const FLEE_SPEED: float = 80.0
const LIGHT_DAMAGE: float = 0.2
const MAX_LIGHT_RADIUS: float = 150.0 
const HIT_SFX = preload("res://src/assets/audio/error_008.ogg")

@export var spark_scene: PackedScene = preload("res://src/core_loop/entities/interactables/spark/Spark.tscn")

var direction: Vector2
var current_state: State = State.WANDER
var player: Node2D
var health: float = 100.0

@onready var hitbox: Area2D = $Hitbox

func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	
	var dirs: Array[Vector2] = [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]
	direction = dirs.pick_random()
	
	if not hitbox.body_entered.is_connected(_on_hitbox_body_entered):
		hitbox.body_entered.connect(_on_hitbox_body_entered)
		
	player = get_tree().get_first_node_in_group("Player")
	if not player:
		player = get_parent().find_child("Player", true, false)

func _physics_process(delta: float) -> void:
	if not player or not is_instance_valid(player):
		_wander(delta)
		return
		
	var dist_to_player = global_position.distance_to(player.global_position)
	var player_light_health = player.get("current_light_health") if player.get("current_light_health") != null else 0.5
	var current_radius = player_light_health * MAX_LIGHT_RADIUS
	
	# Определение состояния AI на основе света
	if current_radius > 100.0:
		current_state = State.FLEE
	elif current_radius < 40.0:
		current_state = State.ATTACK
	else:
		current_state = State.WANDER
		
	# Получение урона от света, если враг внутри радиуса
	if dist_to_player < current_radius:
		# Чем больше радиус, тем быстрее сгорает враг
		var burn_rate = (current_radius / 100.0) * 80.0 
		health -= burn_rate * delta
		
		# Мерцание при получении урона
		modulate = Color(1.2, 0.8, 0.2) if Engine.get_frames_drawn() % 4 < 2 else Color.WHITE
		
		if health <= 0:
			_die()
			return
	else:
		_update_visuals()

	# Выполнение движения
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

func _die() -> void:
	if spark_scene:
		var spark = spark_scene.instantiate()
		spark.global_position = global_position
		# Используем call_deferred, так как спавн происходит во время просчета физики
		get_parent().call_deferred("add_child", spark)
	queue_free()

func _on_hitbox_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player") or body.name == "Player":
		if body.has_method("take_damage"):
			var damage_dealt = body.take_damage(LIGHT_DAMAGE)
			if damage_dealt:
				if AudioManager.has_method("play_sfx"):
					AudioManager.play_sfx(HIT_SFX)
				direction = (global_position - body.global_position).normalized()
