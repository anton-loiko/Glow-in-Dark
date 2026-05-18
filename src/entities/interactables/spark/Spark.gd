extends Area2D

const PICKUP_COIN_SFX = preload("res://src/assets/audio/pickup_coin_powerUp9.ogg")

@export var spark_value: int = 5 # Сколько искр дает одна монетка

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		GameManager.add_sparks(spark_value)
		AudioManager.play_sfx(PICKUP_COIN_SFX)
		
		queue_free()
