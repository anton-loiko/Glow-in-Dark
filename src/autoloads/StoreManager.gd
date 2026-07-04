extends Node

# Сигналы для ответа интерфейсу
signal purchase_success(item_id: String)
signal purchase_failed(reason: String)

# Список товаров (ID, которые ты потом зарегистрируешь в App Store / Google Play)
const ITEM_NO_ADS = "com.forwardmobile.lightinthedark.no_ads"
const ITEM_FIRE_SKIN = "com.forwardmobile.lightinthedark.fire_skin"
const ITEM_PINK_FLAME = "com.forwardmobile.lightinthedark.pink_flame"

const SKINS_DB: Dictionary = {
	"default": {
		"name": "Циановый огонек",
		"color": Color(0.0, 1.0, 1.0),
		"price_usd": 0.0,
		"price_sparks": 0,
		"condition": "start"
	},
	"fire_skin": {
		"name": "Скин Огонь",
		"color": Color(1.0, 0.5, 0.0),
		"price_usd": 1.99,
		"price_sparks": 0,
		"condition": "store_usd" 
	},
	"magnet_skin": {
		"name": "Скин Магнит",
		"color": Color(0.8, 0.2, 1.0), 
		"price_usd": 0.0,
		"price_sparks": 150,
		"condition": "store_sparks" 
	},
	"pink_flame": {
		"name": "Розовое пламя",
		"color": Color(1.0, 0.07, 0.57), 
		"price_usd": 2.99,
		"price_sparks": 0,
		"condition": "store_usd" 
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
