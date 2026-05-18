extends Control

const CLICK_SFX = preload("res://assets/audio/click_001.ogg")

@onready var continue_button: Button = $VBoxContainer/ContinueButton
@onready var shop_panel: ColorRect = $ShopPanel
@onready var buy_no_ads_button: Button = $ShopPanel/VBoxContainer/BuyNoAdsButton
@onready var buy_skin_button: Button = $ShopPanel/VBoxContainer/BuySkinButton

func _ready() -> void:
	if GameManager.unlocked_level <= 1:
		continue_button.hide()
	else:
		continue_button.show()

	StoreManager.purchase_success.connect(_on_purchase_success)
	update_shop_buttons()
	
	CloudManager.sync_completed.connect(_on_cloud_sync_completed)
	CloudManager.authenticate_player()



func update_shop_buttons() -> void:
	# 1. Проверка рекламы (осталась без изменений)
	if GameManager.has_no_ads:
		buy_no_ads_button.text = "Реклама отключена"
		buy_no_ads_button.disabled = true
	
	# 2. Проверка скина через новый массив owned_skins
	# Сначала проверяем, есть ли строка "blue_flame" в инвентаре игрока
	if GameManager.owned_skins.has("blue_flame"):
		# Если скин куплен, проверяем, надет ли он прямо сейчас
		if GameManager.equipped_skin == "blue_flame":
			buy_skin_button.text = "Надето: Синее пламя"
			buy_skin_button.disabled = true # Уже надето, нажимать нет смысла
		else:
			buy_skin_button.text = "Надеть Синее пламя"
			buy_skin_button.disabled = false # Можно нажать, чтобы экипировать
	else:
		# Если скина нет в массиве, значит он еще продается
		buy_skin_button.text = "Синее пламя - $1.99"
		buy_skin_button.disabled = false



# --- НОВАЯ ФУНКЦИЯ ---
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
