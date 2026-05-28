extends Node

# Сигналы для ответа интерфейсу
signal purchase_success(item_id: String)
signal purchase_failed(reason: String)

# Список товаров (ID, которые ты потом зарегистрируешь в App Store / Google Play)
const ITEM_NO_ADS = "com.forwardmobile.lightinthedark.no_ads"
const ITEM_BLUE_SKIN = "com.forwardmobile.lightinthedark.blue_skin"

func buy_item(item_id: String) -> void:
	
	# Имитируем ожидание ответа от банка/магазина (1.5 секунды)
	await get_tree().create_timer(1.5).timeout
	
	# Имитируем успешную покупку
	purchase_success.emit(item_id)
