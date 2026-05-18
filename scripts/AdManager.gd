extends Node

signal reward_earned(amount: int)
signal ad_closed

# Имитация запроса к рекламной сети
func show_rewarded_ad() -> void:
	print("Связь с рекламной сетью. Запуск видеоролика...")
	
	# Имитируем время просмотра рекламы (например, 2 секунды для тестов)
	await get_tree().create_timer(2.0).timeout
	
	print("Реклама просмотрена до конца. Выдаем награду!")
	# Выдаем 50 искр за просмотр
	reward_earned.emit(50)
	
	# Сигнал о том, что окно рекламы закрылось (чтобы разблокировать интерфейс)
	ad_closed.emit()
