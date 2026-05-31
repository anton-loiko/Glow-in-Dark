class_name GameUI
extends Control

const CLICK_SFX = preload("res://src/assets/audio/click_001.ogg")

@onready var progress_bar: TextureProgressBar = %TextureProgressBar
@onready var lose_panel: Panel = %LosePanel
@onready var win_panel: Panel = %WinPanel
@onready var sparks_label: Label = %SparksLabel
@onready var reward_label: Label = %WinPanel/VBoxContainer/RewardLabel
@onready var next_button: Button = %WinPanel/VBoxContainer/NextLevelButton
@onready var revive_button: Button = %LosePanel/VBoxContainer/ReviveButton
@onready var virtual_joystick: VirtualJoystick = %"Virtual Joystick"

var sparks_at_level_start: int = 0
var is_danger_mode: bool = false

func _ready() -> void:
	virtual_joystick.show()
	
	# Запоминаем кол-во искр на старте уровня для экрана победы
	sparks_at_level_start = GameManager.sparks
	sparks_label.text = "Sparks: " + str(GameManager.sparks)
	
	AdManager.reward_earned.connect(_on_reward_earned)
	GameManager.sparks_changed.connect(_on_sparks_changed)
	
	# Явно настраиваем диапазоны прогресс-бара света
	progress_bar.max_value = 1.0 
	progress_bar.step = 0.01
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
	virtual_joystick.hide()
	lose_panel.show()
	revive_button.show()
	win_panel.hide()

func show_win_screen() -> void:
	get_tree().paused = true
	virtual_joystick.hide()
	var collected = GameManager.sparks - sparks_at_level_start
	reward_label.text = "Collected sparks: " + str(collected)
	win_panel.show()
	lose_panel.hide()

func _on_reward_earned() -> void:
	# Избавляемся от find_child, обращаемся через группу
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0 and players[0].has_method("revive"):
		players[0].revive()
		
	lose_panel.hide()
	get_tree().paused = false

func _on_sparks_changed(new_amount: int) -> void:
	sparks_label.text = "Sparks: " + str(new_amount)

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
