extends Control

const CLICK_SFX = preload("res://src/assets/audio/click_001.ogg")
const ERROR_SFX = preload("res://src/assets/audio/error_008.ogg")

@onready var buy_no_ads_button: Button = $ShopPanel/VBoxContainer/BuyNoAdsButton
@onready var watch_ad_button: Button = $ShopPanel/VBoxContainer/WatchAdButton
@onready var skins_grid: GridContainer = $ShopPanel/VBoxContainer/SkinsGrid

func _ready() -> void:
	CloudManager.sync_completed.connect(_on_cloud_sync_completed)
	StoreManager.purchase_success.connect(_on_purchase_success)
	StoreManager.purchase_failed.connect(_on_purchase_failed)
	AdManager.ad_closed.connect(_on_ad_closed)
	
	buy_no_ads_button.pressed.connect(_on_buy_no_ads_button_pressed)
	watch_ad_button.pressed.connect(_on_watch_ad_button_pressed)

	build_shop()
	update_shop_buttons()

func build_shop() -> void:
	# Очищаем старые тестовые кнопки (если они случайно остались в редакторе)
	for child in skins_grid.get_children():
		child.queue_free()
		
	# Динамически генерируем кнопки на основе базы данных
	for skin_id in StoreManager.SKINS_DB.keys():
		var btn = Button.new()
		btn.name = skin_id
		# Привязываем ID скина к аргументам сигнала
		btn.pressed.connect(_on_skin_button_pressed.bind(skin_id))
		skins_grid.add_child(btn)

func update_shop_buttons() -> void:
	# 1. Товар "Отключение рекламы"
	if GameManager.has_no_ads:
		buy_no_ads_button.text = "ADS are turned off"
		buy_no_ads_button.disabled = true
	else:
		buy_no_ads_button.text = "Turn Off ADS ($1.99)"
		buy_no_ads_button.disabled = false
	
	# 2. Обновление всех сгенерированных кнопок скинов
	for child in skins_grid.get_children():
		if child is Button:
			var skin_id = child.name
			if StoreManager.SKINS_DB.has(skin_id):
				_update_skin_button(skin_id, child)

func _update_skin_button(skin_id: String, button: Button) -> void:
	var data = StoreManager.SKINS_DB[skin_id]
	var display_name = data["name"]
	var price_text = ""
	
	if data["price_usd"] > 0:
		price_text = "$" + str(data["price_usd"])
	elif data["price_sparks"] > 0:
		price_text = str(data["price_sparks"]) + " sparks"
	else:
		price_text = "Available"
		
	if GameManager.owned_skins.has(skin_id):
		if GameManager.equipped_skin == skin_id:
			button.text = "Надето: " + display_name
			button.disabled = true
		else:
			button.text = "Надеть\n" + display_name
			button.disabled = false
	else:
		button.text = display_name + "\n" + price_text
		button.disabled = false

func _on_cloud_sync_completed() -> void:
	update_shop_buttons()

func _on_purchase_success(_item_id: String) -> void:
	update_shop_buttons()

func _on_purchase_failed(_reason: String) -> void:
	update_shop_buttons()

func _on_ad_closed() -> void:
	watch_ad_button.disabled = false
	watch_ad_button.text = "Watch an AD (+50 Sparks)"

func _on_watch_ad_button_pressed() -> void:
	AudioManager.play_sfx(CLICK_SFX)
	watch_ad_button.disabled = true
	watch_ad_button.text = "Watching..."
	AdManager.show_rewarded_ad()

func _on_buy_no_ads_button_pressed() -> void:
	AudioManager.play_sfx(CLICK_SFX)
	StoreManager.buy_item(StoreManager.ITEM_NO_ADS)

func _on_skin_button_pressed(skin_id: String) -> void:
	if GameManager.owned_skins.has(skin_id):
		AudioManager.play_sfx(CLICK_SFX)
		GameManager.equipped_skin = skin_id
		GameManager.save_game()
		update_shop_buttons()
	else:
		var data = StoreManager.SKINS_DB[skin_id]
		
		# Логика покупки за реальные деньги
		if data["condition"] == "store_usd":
			AudioManager.play_sfx(CLICK_SFX)
			# Конструируем ID товара на лету (например: com.forwardmobile.lightinthedark.fire_skin)
			var iap_id = "com.forwardmobile.lightinthedark." + skin_id
			StoreManager.buy_item(iap_id)
			
		# Логика покупки за софт-валюту (Искры)
		elif data["condition"] == "store_sparks":
			var price = data["price_sparks"]
			if GameManager.sparks >= price:
				AudioManager.play_sfx(CLICK_SFX)
				GameManager.add_sparks(-price)
				GameManager.owned_skins.append(skin_id)
				GameManager.equipped_skin = skin_id
				GameManager.save_game()
				CloudManager.save_to_cloud()
				update_shop_buttons()
			else:
				AudioManager.play_sfx(ERROR_SFX)
