class_name Spark
extends Area2D

const PICKUP_SFX = preload("res://src/assets/audio/pickup_coin_powerUp9.ogg")
const SPARK_VALUE: int = 1

func _ready() -> void:
	if not body_entered.is_connected:
		body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		set_deferred("monitoring", false)
		
		GameManager.add_sparks(SPARK_VALUE)
		AudioManager.play_sfx(PICKUP_SFX)
		
		var tween = create_tween()
		if has_node("Sprite2D"):
			tween.tween_property($Sprite2D, "modulate:a", 0.0, 0.2)
			tween.parallel().tween_property($Sprite2D, "position:y", position.y - 20, 0.2)
		
		tween.tween_callback(queue_free)
