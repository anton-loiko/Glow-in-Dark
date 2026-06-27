extends Control

const CLICK_SFX = preload("res://src/assets/audio/click_001.ogg")
const ERROR_SFX = preload("res://src/assets/audio/error_008.ogg")

@onready var buy_no_ads_button: Button = $ShopPanel/VBoxContainer/BuyNoAdsButton
@onready var buy_skin_button: Button = $ShopPanel/VBoxContainer/BuySkinButton
@onready var watch_ad_button: Button = $ShopPanel/VBoxContainer/WatchAdButton
@onready var buy_purple_skin_button: Button = $ShopPanel/VBoxContainer/BuyPurpleSkinButton

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	CloudManager.sync_completed.connect(_on_cloud_sync_completed)
	StoreManager.purchase_success.connect(_on_purchase_success)
	StoreManager.purchase_failed.connect(_on_purchase_failed)

	AdManager.ad_closed.connect(_on_ad_closed)
	
	buy_no_ads_button.pressed.connect(_on_buy_no_ads_button_pressed)
	watch_ad_button.pressed.connect(_on_watch_ad_button_pressed)
	buy_skin_button.pressed.connect(_on_buy_skin_button_pressed)
	buy_purple_skin_button.pressed.connect(_on_buy_purple_skin_button_pressed)

	update_shop_buttons()


func update_shop_buttons() -> void:
	# 1. Товар "Отключение рекламы" (уникальная логика, так как это не скин)
	if GameManager.has_no_ads:
		buy_no_ads_button.text = "Реклама отключена"
		buy_no_ads_button.disabled = true
	
	# 2. Обновление всех кнопок скинов
	# Мы просто передаем: ID скина, саму кнопку, красивое имя, строку с ценой
	_update_skin_button("blue_flame", buy_skin_button, "Синее пламя", "$1.99")
	
	var purple_price = str(StoreManager.SKINS_DB["purple_magic"]["price_sparks"]) + " Искр"
	_update_skin_button("purple_magic", buy_purple_skin_button, "Фиолетовая магия", purple_price)

func _update_skin_button(skin_id: String, button: Button, display_name: String, price_text: String) -> void:
	# Проверяем, есть ли скин в инвентаре
	if GameManager.owned_skins.has(skin_id):
		# Если скин куплен, проверяем, надет ли он
		if GameManager.equipped_skin == skin_id:
			button.text = "Надето: " + display_name
			button.disabled = true
		else:
			button.text = "Надеть " + display_name
			button.disabled = false
	else:
		# Если скина нет в инвентаре, выводим его цену
		button.text = display_name + " - " + price_text
		button.disabled = false

func _on_cloud_sync_completed() -> void:
	update_shop_buttons()

func _on_purchase_success(_item_id: String) -> void:
	update_shop_buttons()

func _on_purchase_failed(_reason: String) -> void:
	update_shop_buttons()

func _on_ad_closed() -> void:
	# Возвращаем кнопку в исходное состояние
	watch_ad_button.disabled = false
	watch_ad_button.text = "Смотреть рекламу (+50 Искр)"

##
## pressed
##
func _on_watch_ad_button_pressed() -> void:
	AudioManager.play_sfx(CLICK_SFX)
	
	# Блокируем кнопку, чтобы игрок не нажал её 10 раз подряд во время "просмотра"
	watch_ad_button.disabled = true
	watch_ad_button.text = "Смотрим видео..."
	
	AdManager.show_rewarded_ad()

func _on_buy_no_ads_button_pressed() -> void:
	AudioManager.play_sfx(CLICK_SFX)
	StoreManager.buy_item(StoreManager.ITEM_NO_ADS)

func _on_buy_skin_button_pressed() -> void:
	AudioManager.play_sfx(CLICK_SFX)
	
	# Проверяем, что именно хочет сделать игрок: надеть или купить?
	if GameManager.owned_skins.has("blue_flame"):
		# Скин уже куплен, значит игрок нажал "Надеть Синее пламя"
		GameManager.equipped_skin = "blue_flame"
		GameManager.save_game()   # Сразу сохраняем выбор на жесткий диск
		update_shop_buttons()     # Обновляем текст кнопки на "Надето"
	else:
		# Скин не куплен, запускаем запрос к банковской системе
		StoreManager.buy_item(StoreManager.ITEM_BLUE_SKIN)
		
func _on_buy_purple_skin_button_pressed() -> void:
	if GameManager.owned_skins.has("purple_magic"):
		# Скин уже куплен, просто надеваем его
		AudioManager.play_sfx(CLICK_SFX)
		GameManager.equipped_skin = "purple_magic"
		
		GameManager.save_game()
		update_shop_buttons()
	else:
		# Скин не куплен, пытаемся провести транзакцию
		var price = StoreManager.SKINS_DB["purple_magic"]["price_sparks"]
		
		# Проверяем, хватает ли денег на балансе
		if GameManager.sparks >= price:
			AudioManager.play_sfx(CLICK_SFX)
			
			# 1. Списываем Искры. 
			# Передаем отрицательное число. Функция add_sparks сама обновит UI и вызовет save_game()
			GameManager.add_sparks(-price)
			
			# 2. Выдаем товар
			GameManager.owned_skins.append("purple_magic")
			GameManager.equipped_skin = "purple_magic"
			
			# 3. Фиксируем изменения на диске и в облаке
			GameManager.save_game()
			CloudManager.save_to_cloud()
			
			# 4. Обновляем визуальные кнопки
			update_shop_buttons()
		else:
			# Денег не хватает
			# Здесь позже можно проиграть звук ошибки:
			AudioManager.play_sfx(ERROR_SFX)
