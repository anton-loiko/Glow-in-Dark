class_name Exit
extends Area2D

const WIN_SFX = preload("res://src/assets/audio/win_zap1.ogg")
@onready var animatedSprite = $AnimatedSprite2D

func _ready() -> void:
	animatedSprite.play()
	
	if not body_entered.is_connected:
		body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		set_deferred("monitoring", false)
		
		# Останавливаем игрока, чтобы он не двигался после победы
		body.velocity = Vector2.ZERO
		body.set_physics_process(false)
		body.set_process(false)
		
		AudioManager.play_sfx(WIN_SFX)
		GameManager.complete_level()
		
		var ui = get_tree().current_scene.find_child("UIControl", true, false)
		if ui and ui.has_method("show_win_screen"):
			ui.show_win_screen()
