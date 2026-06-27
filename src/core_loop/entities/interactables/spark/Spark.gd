class_name Spark
extends Area2D

const PICKUP_SFX = preload("res://src/assets/audio/pickup_coin_powerUp9.ogg")
const SPARK_VALUE: int = 1

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var particles: CPUParticles2D = $CPUParticles2D

var is_collected: bool = false
var player_ref: Node2D

func _ready() -> void:
	if animated_sprite:
		animated_sprite.play()
	
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
		
	player_ref = get_tree().get_first_node_in_group("Player")
	if not player_ref:
		player_ref = get_parent().find_child("Player", true, false)

func _process(delta: float) -> void:
	if is_collected or not player_ref or not is_instance_valid(player_ref):
		return
		
	if GameManager.active_skills.has("magnet"):
		if global_position.distance_to(player_ref.global_position) < SkillsManager.SKILL_MAGNET_RADIUS:
			var dir = (player_ref.global_position - global_position).normalized()
			global_position += dir * SkillsManager.SKILL_MAGNET_SPEED * delta

func _on_body_entered(body: Node2D) -> void:
	if is_collected: return
	
	if body.is_in_group("Player") or body.name == "Player":
		is_collected = true
		set_deferred("monitoring", false)
		
		#GameManager.add_sparks(SPARK_VALUE)
		GameManager.sparks_picked_up.emit(SPARK_VALUE)
		
		if AudioManager.has_method("play_sfx"):
			AudioManager.play_sfx(PICKUP_SFX)
		
		if particles:
			particles.emitting = true
		
		var tween = create_tween()
		if animated_sprite:
			tween.tween_property(animated_sprite, "modulate:a", 0.0, 0.2)
			tween.parallel().tween_property(animated_sprite, "position:y", position.y - 20, 0.2)
		
		tween.tween_callback(func():
			await get_tree().create_timer(0.6).timeout
			queue_free()
		)
