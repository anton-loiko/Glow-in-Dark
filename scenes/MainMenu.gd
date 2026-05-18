extends Control

const CLICK_SFX = preload("res://assets/audio/click_001.ogg")

@onready var continue_button: Button = $VBoxContainer/ContinueButton
@onready var shop_panel: ColorRect = $ShopPanel
@onready var buy_no_ads_button: Button = $ShopPanel/VBoxContainer/BuyNoAdsButton
@onready var buy_skin_button: Button = $ShopPanel/VBoxContainer/BuySkinButton
@onready var watch_ad_button: Button = $ShopPanel/VBoxContainer/WatchAdButton
@onready var menu_sparks_label: Label = $MenuSparksLabel
@onready var buy_purple_skin_button: Button = $ShopPanel/VBoxContainer/BuyPurpleSkinButton

func _ready() -> void:
	CloudManager.sync_completed.connect(_on_cloud_sync_completed)
	StoreManager.purchase_success.connect(_on_purchase_success)
	AdManager.reward_earned.connect(_on_reward_earned)
	AdManager.ad_closed.connect(_on_ad_closed)
	GameManager.sparks_changed.connect(_on_sparks_changed)
	
	if GameManager.unlocked_level <= 1:
		continue_button.hide()
	else:
		continue_button.show()

	update_shop_buttons()
	
	CloudManager.authenticate_player()
# Подписываемся на события рекламы и баланса

	
	_on_sparks_changed(GameManager.sparks)

func update_shop_buttons() -> void:
	# 1. Товар "Отключение рекламы" (уникальная логика, так как это не скин)
	if GameManager.has_no_ads:
		buy_no_ads_button.text = "Реклама отключена"
		buy_no_ads_button.disabled = true
	
	# 2. Обновление всех кнопок скинов
	# Мы просто передаем: ID скина, саму кнопку, красивое имя, строку с ценой
	_update_skin_button("blue_flame", buy_skin_button, "Синее пламя", "$1.99")
	
	var purple_price = str(GameManager.SKINS_DB["purple_magic"]["price_sparks"]) + " Искр"
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
	# Когда данные скачаются, обновляем кнопки (вдруг из облака пришел отключенный скин/реклама или новый уровень)
	update_shop_buttons()
	
	if GameManager.unlocked_level > 1:
		continue_button.show()

func _on_purchase_success(item_id: String) -> void:
	if item_id == StoreManager.ITEM_NO_ADS:
		GameManager.has_no_ads = true
		
	elif item_id == StoreManager.ITEM_BLUE_SKIN:
		# Раньше тут было has_blue_skin = true. 
		# Теперь мы добавляем ID скина в массив инвентаря.
		if not GameManager.owned_skins.has("blue_flame"):
			GameManager.owned_skins.append("blue_flame")
			
		# Автоматически надеваем свежекупленный скин
		GameManager.equipped_skin = "blue_flame"
	
	# Жестко фиксируем новые покупки в файле сохранения
	GameManager.save_game()
	
	# Обновляем визуальные кнопки в магазине
	update_shop_buttons()

func _on_sparks_changed(new_amount: int) -> void:
	menu_sparks_label.text = "Sparks: " + str(new_amount)

func _on_reward_earned(amount: int) -> void:
	# Начисляем валюту
	GameManager.add_sparks(amount)
	
	# Мгновенно синхронизируем с Firebase, чтобы не потерять награду
	CloudManager.save_to_cloud()

func _on_ad_closed() -> void:
	# Возвращаем кнопку в исходное состояние
	watch_ad_button.disabled = false
	watch_ad_button.text = "Смотреть рекламу (+50 Искр)"

# ----On Press----

func _on_continue_button_pressed() -> void:
	AudioManager.play_sfx(CLICK_SFX)
	GameManager.current_level = GameManager.unlocked_level
	get_tree().change_scene_to_file("res://scenes/Level.tscn")

func _on_new_game_button_pressed() -> void:
	AudioManager.play_sfx(CLICK_SFX)
	GameManager.current_level = 1
	get_tree().change_scene_to_file("res://scenes/Level.tscn")

func _on_shop_button_pressed() -> void:
	AudioManager.play_sfx(CLICK_SFX)
	shop_panel.show()

func _on_close_shop_button_pressed() -> void:
	AudioManager.play_sfx(CLICK_SFX)
	shop_panel.hide()

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

func _on_leaderboard_button_pressed() -> void:
	AudioManager.play_sfx(CLICK_SFX)
	LeaderboardManager.show_leaderboard()

func _on_watch_ad_button_pressed() -> void:
	AudioManager.play_sfx(CLICK_SFX)
	
	# Блокируем кнопку, чтобы игрок не нажал её 10 раз подряд во время "просмотра"
	watch_ad_button.disabled = true
	watch_ad_button.text = "Смотрим видео..."
	
	AdManager.show_rewarded_ad()

func _on_buy_purple_skin_button_pressed() -> void:
	if GameManager.owned_skins.has("purple_magic"):
		# Скин уже куплен, просто надеваем его
		AudioManager.play_sfx(CLICK_SFX)
		GameManager.equipped_skin = "purple_magic"
		
		GameManager.save_game()
		update_shop_buttons()
	else:
		# Скин не куплен, пытаемся провести транзакцию
		var price = GameManager.SKINS_DB["purple_magic"]["price_sparks"]
		
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
			print("Ошибка: Недостаточно Искр!")
			# Здесь позже можно проиграть звук ошибки:
			# AudioManager.play_sfx(preload("res://assets/audio/error.wav"))ы
