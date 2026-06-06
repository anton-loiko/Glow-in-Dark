extends Control

@onready var panel_manager: MarginContainer = %PanelManager
@onready var preloading_screen: MarginContainer = %PreloadingScreen
@onready var loader: AnimatedSprite2D = %Loader

func _ready() -> void:
	panel_manager.show()
	preloading_screen.hide()

	AdManager.reward_earned.connect(_on_reward_earned)
	CloudManager.sync_completed.connect(_on_cloud_sync_completed)
	StoreManager.purchase_success.connect(_on_purchase_success)
	StoreManager.purchase_failed.connect(_on_purchase_failed)
	
	if CloudManager.sync_in_porgress:
		_show_preloading_screen()

func _on_cloud_sync_completed() -> void:
	panel_manager.show()
	preloading_screen.hide()
	loader.stop()

func _on_purchase_failed(reason: String) -> void:
	print("[ERROR]::[_on_purchase_failed]:::: ", reason)

func _on_purchase_success(item_id: String) -> void:
	print("[_on_purchase_success]:::: item_id: ", item_id)

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

func _on_reward_earned(amount: int) -> void:
	# Начисляем валюту
	GameManager.add_sparks(amount)
	
	# Мгновенно синхронизируем с Firebase, чтобы не потерять награду
	CloudManager.save_to_cloud()


func _show_preloading_screen():
	panel_manager.hide()
	preloading_screen.show()
	loader.play('planet')
