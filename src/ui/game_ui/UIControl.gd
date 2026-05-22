extends Control

const CLICK_SFX = preload("res://src/assets/audio/click_001.ogg")

@onready var progress_bar: TextureProgressBar = $TextureProgressBar
@onready var lose_panel: Panel = $LosePanel
@onready var win_panel: Panel = $WinPanel
@onready var sparks_label: Label = %SparksLabel
@onready var reward_label: Label = $WinPanel/VBoxContainer/RewardLabel
@onready var next_button: Button = $WinPanel/VBoxContainer/NextLevelButton
@onready var revive_button: Button = $LosePanel/VBoxContainer/ReviveButton

var sparks_collected_this_level: int = 0
var is_danger_mode: bool = false

func _ready() -> void:
	AdManager.reward_earned.connect(_on_reward_earned)
	sparks_label.text = "Sparks: " + str(GameManager.sparks)
	
	GameManager.sparks_changed.connect(_on_sparks_changed)
	progress_bar.tint_progress = Color.WHITE

func _on_player_light_changed(new_value: float) -> void:
	progress_bar.value = new_value
	
	if new_value < 0.25:
		if not is_danger_mode:
			is_danger_mode = true
			progress_bar.tint_progress = Color(1.0, 0.2, 0.2)
	else:
		if is_danger_mode:
			is_danger_mode = false
			progress_bar.tint_progress = Color.WHITE

func show_game_over() -> void:
	get_tree().paused = true
	lose_panel.show()
	revive_button.show()
	win_panel.hide()

func show_win_screen() -> void:
	get_tree().paused = true
	reward_label.text = "Collected sparks: " + str(sparks_collected_this_level)
	win_panel.show()
	lose_panel.hide()

func _on_reward_earned() -> void:
	var player = get_tree().current_scene.find_child("Player", true, false)
	if player and player.has_method("revive"):
		player.revive()
		
	lose_panel.hide()
	get_tree().paused = false

func _on_sparks_changed(new_amount: int) -> void:
	sparks_label.text = "Sparks: " + str(new_amount)
	sparks_collected_this_level += new_amount 

func _on_restart_button_pressed() -> void:
	AudioManager.play_sfx(CLICK_SFX)
	get_tree().paused = false 
	get_tree().reload_current_scene()

func _on_next_level_button_pressed() -> void:
	AudioManager.play_sfx(CLICK_SFX)
	get_tree().paused = false
	GameManager.next_level()

func _on_revive_button_pressed() -> void:
	AudioManager.play_sfx(CLICK_SFX)
	revive_button.hide()
	AdManager.show_rewarded_ad()


func _on_menu_button_pressed() -> void:
	AudioManager.play_sfx(CLICK_SFX)
	get_tree().paused = false
	GameManager.go_to_main_menu()
