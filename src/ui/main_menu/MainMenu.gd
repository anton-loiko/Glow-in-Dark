extends Control


const LEVEL_ROOT_SCENE_PATH = "res://src/levels/LevelRoot.tscn"
const CLICK_SFX = preload("res://src/assets/audio/click_001.ogg")
const ERROR_SFX = preload("res://src/assets/audio/error_008.ogg")

@onready var continue_button: Button = $VBoxContainer/ContinueButton
@onready var menu_sparks_label: Label = $MenuSparksLabel


func _ready() -> void:
	CloudManager.sync_completed.connect(_on_cloud_sync_completed)
	StoreManager.purchase_success.connect(_on_purchase_success)
	AdManager.reward_earned.connect(_on_reward_earned)
	GameManager.sparks_changed.connect(_on_sparks_changed)

	if GameManager.unlocked_level <= 1 or not GameManager.is_level_exists(GameManager.unlocked_level):
		continue_button.hide()
	else:
		continue_button.show()
	
	CloudManager.authenticate_player()	
	
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

# ----On Press----

func _on_continue_button_pressed() -> void:
	AudioManager.play_sfx(CLICK_SFX)
	GameManager.current_level = GameManager.unlocked_level
	get_tree().change_scene_to_file(LEVEL_ROOT_SCENE_PATH)

func _on_new_game_button_pressed() -> void:
	AudioManager.play_sfx(CLICK_SFX)
	GameManager.current_level = 1
	get_tree().change_scene_to_file(LEVEL_ROOT_SCENE_PATH)

func _on_settings_button_pressed() -> void:
	$SettingsMenu.show()
