extends Area2D

const PICKUP_COIN_SFX = preload("res://src/assets/audio/pickup_coin_powerUp9.ogg")

@export var spark_value: int = 5 

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		# Отключаем коллизию, чтобы игрок не смог "собрать" искру дважды за время анимации
		set_deferred("monitoring", false)
		
		GameManager.add_sparks(spark_value)
		AudioManager.play_sfx(PICKUP_COIN_SFX)
		
		# Создаем аниматор
		var tween = create_tween()
		
		# Увеличиваем размер спрайта в 2 раза за 0.2 секунды
		tween.tween_property($Sprite2D, "scale", Vector2(0.04, 0.04), 0.2)
		# Параллельно делаем спрайт полностью прозрачным (альфа-канал = 0)
		tween.parallel().tween_property($Sprite2D, "modulate:a", 0.0, 0.2)
		
		# Как только обе анимации завершатся, удаляем объект из памяти
		tween.tween_callback(queue_free)
