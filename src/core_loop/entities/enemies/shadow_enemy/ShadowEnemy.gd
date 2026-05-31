class_name ShadowEnemy
extends CharacterBody2D

const SPEED: float = 70.0
const LIGHT_DAMAGE: float = 0.2
const HIT_SFX = preload("res://src/assets/audio/error_008.ogg")

var direction: Vector2

@onready var hitbox: Area2D = $Hitbox

func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	
	var dirs: Array[Vector2] = [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]
	direction = dirs.pick_random()
	
	if not hitbox.body_entered.is_connected:
		hitbox.body_entered.connect(_on_hitbox_body_entered)

func _physics_process(delta: float) -> void:
	var collision = move_and_collide(direction * SPEED * delta)
	
	if collision:
		direction = direction.bounce(collision.get_normal())

func _on_hitbox_body_entered(body: Node2D) -> void:
	if body is Player:
		if body.has_method("take_damage"):
			var damage_dealt = body.take_damage(LIGHT_DAMAGE)
			
			if damage_dealt:
				AudioManager.play_sfx(HIT_SFX)
				direction = (global_position - body.global_position).normalized()
