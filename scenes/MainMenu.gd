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


func update_shop_buttons() -> void:
	if GameManager.has_no_ads:
		buy_no_ads_button.text = "Реклама отключена"
		buy_no_ads_button.disabled = true # Делаем кнопку неактивной
	if GameManager.has_blue_skin:
		buy_skin_button.text = "Куплено (Синее пламя)"
		buy_skin_button.disabled = true


# Слушатель успешной покупки
func _on_purchase_success(item_id: String) -> void:
	if item_id == StoreManager.ITEM_NO_ADS:
		GameManager.has_no_ads = true
	elif item_id == StoreManager.ITEM_BLUE_SKIN:
		GameManager.has_blue_skin = true
	
	GameManager.save_game()
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
	StoreManager.buy_item(StoreManager.ITEM_BLUE_SKIN)

func _on_leaderboard_button_pressed() -> void:
	AudioManager.play_sfx(CLICK_SFX)
	LeaderboardManager.show_leaderboard()
