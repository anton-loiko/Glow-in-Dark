class_name BaseEnemy
extends CharacterBody2D

@export var max_health: float = 100.0
@export var base_damage: float = 0.2
@export var max_light_radius: float = 150.0
@export var spark_scene: PackedScene = preload("res://src/core_loop/entities/interactables/spark/Spark.tscn")
@export var hit_sfx: AudioStream = preload("res://src/assets/audio/error_008.ogg")

signal on_damage_tick(amount: int, global_pos: Vector2, is_lethal: bool)

var accumulated_damage: float = 0.0
var damage_number_timer: float = 0.0
const DAMAGE_NUMBER_INTERVAL: float = 0.35
var is_dead: bool = false # <-- Новый флаг защиты

var health: float
var player: Node2D

@onready var hitbox: Area2D = $Hitbox

func _ready() -> void:
	health = max_health
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	
	if hitbox and not hitbox.body_entered.is_connected(_on_hitbox_body_entered):
		hitbox.body_entered.connect(_on_hitbox_body_entered)
		
	player = get_tree().get_first_node_in_group("Player")
	if not player:
		player = get_parent().find_child("Player", true, false)
		
	if not on_damage_tick.is_connected(DamagePool.show_damage):
		on_damage_tick.connect(DamagePool.show_damage)
		
	_enemy_ready()

# Виртуальный метод для инициализации в дочерних классах
func _enemy_ready() -> void:
	pass

func _physics_process(delta: float) -> void:
	if not player or not is_instance_valid(player):
		_enemy_physics_process(delta)
		_process_damage_numbers(delta)
		return
		
	_handle_light_burn(delta)
	_enemy_physics_process(delta)
	_process_damage_numbers(delta)

func _process_damage_numbers(delta: float) -> void:
	if accumulated_damage > 0:
		damage_number_timer += delta
		if damage_number_timer >= DAMAGE_NUMBER_INTERVAL:
			_emit_damage_number(false)

func _emit_damage_number(is_lethal: bool) -> void:
	if accumulated_damage <= 0:
		return
		
	# Округляем урон вверх для красивых целых чисел
	var display_amount = int(ceil(accumulated_damage))
	on_damage_tick.emit(display_amount, global_position, is_lethal)
	
	accumulated_damage = 0.0
	damage_number_timer = 0.0

# Виртуальный метод для логики перемещения (State Machine) в дочерних классах
func _enemy_physics_process(_delta: float) -> void:
	pass

func _handle_light_burn(delta: float) -> void:
	var dist_to_player = global_position.distance_to(player.global_position)
	var player_light_health = player.get("current_light_health") if player.get("current_light_health") != null else 0.5
	var current_radius = player_light_health * max_light_radius
	
	if dist_to_player < current_radius:
		var burn_rate = (current_radius / 100.0) * 80.0 
		var has_burn_skill = GameManager.active_skills.has("shadow_burn")
		
		if has_burn_skill:
			burn_rate *= SkillsManager.SKILL_SHADOW_BURN_MULT 
			
		take_damage(burn_rate * delta)
		
		if Engine.get_frames_drawn() % 4 < 2:
			modulate = Color(1.0, 0.2, 0.2) if has_burn_skill else Color(1.2, 0.8, 0.2)
		else:
			modulate = Color.WHITE
	else:
		_update_visuals()

# Виртуальный метод для обновления цвета/анимации вне зоны горения
func _update_visuals() -> void:
	modulate = Color.WHITE

func take_damage(amount: float) -> void:
	if is_dead:
		return
		
	health -= amount
	accumulated_damage += amount
	
	if health <= 0:
		is_dead = true
		_emit_damage_number(true)
		die()

func die() -> void:
	if spark_scene:
		var spark = spark_scene.instantiate()
		spark.global_position = global_position
		get_parent().call_deferred("add_child", spark)
	queue_free()

func _on_hitbox_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player") or body.name == "Player":
		if body.has_method("take_damage"):
			var damage_dealt = body.take_damage(base_damage)
			if damage_dealt:
				if AudioManager.has_method("play_sfx") and hit_sfx:
					AudioManager.play_sfx(hit_sfx)
				_on_player_hit(body)

# Виртуальный метод для реакции на успешный удар (например, отскок)
func _on_player_hit(_body: Node2D) -> void:
	pass
