extends Area2D

const PICKUP_COIN_SFX = preload("res://assets/audio/pickup_coin_powerUp9.ogg")

@export var spark_value: int = 5 # Сколько искр дает одна монетка

func _ready() -> void:
	# Подписываемся на сигнал пересечения физических тел
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	# Проверяем, что коснулся именно игрок
	if body.name == "Player":
		# Добавляем валюту через глобальный менеджер
		GameManager.add_sparks(spark_value)
		
		# Можно добавить звук сбора
		# AudioManager.play_sfx(preload("res://assets/audio/coin.wav"))
		AudioManager.play_sfx(PICKUP_COIN_SFX)
		
		# Удаляем искру с уровня
		queue_free()
