extends Control


const LEVEL_ROOT_SCENE_PATH = "res://src/levels/LevelRoot.tscn"
const CLICK_SFX = preload("res://src/assets/audio/click_001.ogg")
const ERROR_SFX = preload("res://src/assets/audio/error_008.ogg")

@onready var continue_button: Button = $VBoxContainer/ContinueButton
@onready var menu_sparks_label: Label = $MenuSparksLabel
@onready var leaderboard_panel: Panel = $LeaderboardPanel
@onready var leaderboard_list_container: VBoxContainer = $LeaderboardPanel/VBoxContainer/LeaderboardScroll/LeaderboardList
@onready var leaderboard_close_button:Button = $LeaderboardPanel/VBoxContainer/LeaderboardClose
@onready var leaderboard_status_label:Label = $LeaderboardPanel/VBoxContainer/LeaderboardStatusLabel

func _ready() -> void:
	CloudManager.sync_completed.connect(_on_cloud_sync_completed)
	StoreManager.purchase_success.connect(_on_purchase_success)
	AdManager.reward_earned.connect(_on_reward_earned)
	GameManager.sparks_changed.connect(_on_sparks_changed)
	LeaderboardManager.leaderboard_loaded.connect(_on_leaderboard_data_received)

	if GameManager.unlocked_level <= 1 or not GameManager.is_level_exists(GameManager.unlocked_level):
		continue_button.hide()
	else:
		continue_button.show()
	
	CloudManager.authenticate_player()
	
	leaderboard_panel.hide()
	
	# Подписываемся на сигнал менеджера: когда данные скачаются, сработает наша функция
# Подписываемся на события рекламы и баланса

	
	_on_sparks_changed(GameManager.sparks)

func _on_cloud_sync_completed() -> void:
	if GameManager.unlocked_level > 1 and GameManager.is_level_exists(GameManager.unlocked_level):
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

func _on_sparks_changed(new_amount: int) -> void:
	menu_sparks_label.text = "Sparks: " + str(new_amount)

func _on_reward_earned(amount: int) -> void:
	# Начисляем валюту
	GameManager.add_sparks(amount)
	
	# Мгновенно синхронизируем с Firebase, чтобы не потерять награду
	CloudManager.save_to_cloud()

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

func _on_leaderboard_close_pressed() -> void:
	AudioManager.play_sfx(CLICK_SFX)
	leaderboard_panel.hide()

func _on_settings_button_pressed() -> void:
	$SettingsMenu.show()
