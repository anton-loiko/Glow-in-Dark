extends Control


const LEVEL_ROOT_SCENE_PATH = "res://src/levels/LevelRoot.tscn"
const CLICK_SFX = preload("res://src/assets/audio/click_001.ogg")
const ERROR_SFX = preload("res://src/assets/audio/error_008.ogg")

@onready var continue_button: Button = $VBoxContainer/ContinueButton
@onready var shop_panel: ColorRect = $ShopPanel
@onready var buy_no_ads_button: Button = $ShopPanel/VBoxContainer/BuyNoAdsButton
@onready var buy_skin_button: Button = $ShopPanel/VBoxContainer/BuySkinButton
@onready var watch_ad_button: Button = $ShopPanel/VBoxContainer/WatchAdButton
@onready var menu_sparks_label: Label = $MenuSparksLabel
@onready var buy_purple_skin_button: Button = $ShopPanel/VBoxContainer/BuyPurpleSkinButton

@onready var leaderboard_panel: Panel = $LeaderboardPanel
@onready var leaderboard_list_container: VBoxContainer = $LeaderboardPanel/VBoxContainer/LeaderboardScroll/LeaderboardList
@onready var leaderboard_close_button:Button = $LeaderboardPanel/VBoxContainer/LeaderboardClose
@onready var leaderboard_status_label:Label = $LeaderboardPanel/VBoxContainer/LeaderboardStatusLabel

func _ready() -> void:
	CloudManager.sync_completed.connect(_on_cloud_sync_completed)
	StoreManager.purchase_success.connect(_on_purchase_success)
	AdManager.reward_earned.connect(_on_reward_earned)
	AdManager.ad_closed.connect(_on_ad_closed)
	GameManager.sparks_changed.connect(_on_sparks_changed)
	LeaderboardManager.leaderboard_loaded.connect(_on_leaderboard_data_received)

	if GameManager.unlocked_level <= 1:
		continue_button.hide()
	else:
		continue_button.show()

	update_shop_buttons()
	
	CloudManager.authenticate_player()
	
	leaderboard_panel.hide()
	
	# Подписываемся на сигнал менеджера: когда данные скачаются, сработает наша функция
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

func _on_leaderboard_data_received(players: Array) -> void:
	# Удаляем надпись "Загрузка..."
	if not leaderboard_status_label.hidden:
		leaderboard_status_label.text = ""
		leaderboard_status_label.hide()
	
	# Если массив пустой (интернета нет или в базе никого нет)
	if players.is_empty():
		leaderboard_status_label.show()
		leaderboard_status_label.text = "Не удалось загрузить топ"
		return
		
	# Перебираем массив игроков, полученный из LeaderboardManager
	var place = 1
	for player_info in players:
		# Создаем новый узел текста для каждой строчки таблицы
		var player_row = Label.new()
		
		player_row.add_theme_color_override("font_color",Color(0,0,0))

		# Формируем красивую строку, например: "1. Игрок_a3d8f1 — Уровень: 12"
		player_row.text = str(place) + ". " + player_info["name"] + " — Уровень: " + str(player_info["level"])
		
		# Настраиваем размер шрифта, чтобы текст был читаемым
		player_row.add_theme_font_size_override("font_size", 18)
		
		# Выделяем первые три призовых места золотым цветом
		if place == 1:
			player_row.modulate = Color(1.0, 0.85, 0.2) # Золото
		elif place == 2:
			player_row.modulate = Color(0.75, 0.75, 0.75) # Серебро
		elif place == 3:
			player_row.modulate = Color(0.6, 0.4, 0.2) # Бронза
			
		# Добавляем готовую строчку внутрь вертикального списка на экране
		leaderboard_list_container.add_child(player_row)
		
		place += 1

# ----On Press----

func _on_continue_button_pressed() -> void:
	AudioManager.play_sfx(CLICK_SFX)
	GameManager.current_level = GameManager.unlocked_level
	get_tree().change_scene_to_file(LEVEL_ROOT_SCENE_PATH)

func _on_new_game_button_pressed() -> void:
	AudioManager.play_sfx(CLICK_SFX)
	GameManager.current_level = 1
	get_tree().change_scene_to_file(LEVEL_ROOT_SCENE_PATH)

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
	leaderboard_panel.show()
	
	# Очищаем контейнер от старых надписей перед новым запросом
	for child in leaderboard_list_container.get_children():
		child.queue_free()
		
	leaderboard_status_label.show()
	leaderboard_status_label.text = "Загрузка данных..."

	
	# Запускаем скачивание из Firebase
	LeaderboardManager.fetch_top_players()

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
			AudioManager.play_sfx(ERROR_SFX)

func _on_leaderboard_close_pressed() -> void:
	AudioManager.play_sfx(CLICK_SFX)
	leaderboard_panel.hide()
