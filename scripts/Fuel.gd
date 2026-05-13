extends Area2D

# Сколько света восстанавливает одна единица топлива (40% от максимума)
const LIGHT_RESTORE_AMOUNT: float = 0.4
const PICKUP_SFX = preload("res://assets/audio/pickup_impactWood_light_001.ogg")

# Эта функция сработает автоматически, когда кто-то войдет в зону
func _on_body_entered(body: Node2D) -> void:
	# Проверяем, что в зону вошел именно игрок, а не стена или враг
	if body.name == "Player":
		# На всякий случай проверяем, есть ли у объекта функция add_light
		if body.has_method("add_light"):
			# Вызываем функцию игрока и передаем количество топлива
			body.add_light(LIGHT_RESTORE_AMOUNT)
			AudioManager.play_sfx(PICKUP_SFX)
			
			# Безопасно удаляем топливо со сцены и из памяти
			queue_free()
