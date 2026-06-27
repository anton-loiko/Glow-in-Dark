extends Node

# Сигналы для ответа интерфейсу
signal purchase_success(item_id: String)
signal purchase_failed(reason: String)

# Список товаров (ID, которые ты потом зарегистрируешь в App Store / Google Play)
const ITEM_NO_ADS = "com.forwardmobile.lightinthedark.no_ads"
const ITEM_BLUE_SKIN = "com.forwardmobile.lightinthedark.blue_skin"


const SKINS_DB: Dictionary = {
	"default": {
		"color": Color(1.0, 1.0, 1.0),
		"price_usd": 0.0,
		"price_sparks": 0,
		"condition": "start"
	},
	"blue_flame": {
		"color": Color(0.3, 0.6, 1.0),
		"price_usd": 1.99,
		"price_sparks": 0,
		"condition": "store_usd" 
	},
	"purple_magic": {
		"color": Color(0.8, 0.2, 1.0), 
		"price_usd": 0.0,
		"price_sparks": 150,
		"condition": "store_sparks" 
	}
}


func buy_item(item_id: String) -> void:
	var chance = randf()
	
	# Имитируем не успешную покупку
	if chance < 0.1:
		purchase_failed.emit("Failed just for test")
	
	# Имитируем ожидание ответа от банка/магазина (1.5 секунды)
	await get_tree().create_timer(1.5).timeout
	
	# Имитируем успешную покупку
	purchase_success.emit(item_id)
