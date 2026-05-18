extends Control

const CLICK_SFX = preload("res://assets/audio/click_001.ogg")


@onready var progress_bar: TextureProgressBar = $TextureProgressBar
@onready var overlay: ColorRect = $Overlay
@onready var game_over_menu: VBoxContainer = $Overlay/GameOverMenu
@onready var win_menu: VBoxContainer = $Overlay/WinMenu
@onready var sparks_label: Label = %SparksLabel

func _ready() -> void:
	# Находим игрока в дереве сцен и подписываемся на его сигнал
	# Используем вызов Callable для связи
	var player = get_tree().current_scene.find_child("Player", true, false)
	if player:
		player.light_changed.connect(_on_player_light_changed)

	AdManager.reward_earned.connect(_on_reward_earned)
	
	# --- НОВЫЙ БЛОК ---
	# При запуске уровня сразу пишем текущий баланс
	sparks_label.text = "Sparks: " + str(GameManager.sparks)
	
	# Подписываемся на изменения баланса в будущем
	GameManager.sparks_changed.connect(_on_sparks_changed)

func _on_player_light_changed(new_value: float) -> void:
	# Обновляем значение полоски
	progress_bar.value = new_value


func _on_restart_button_pressed() -> void:
	AudioManager.play_sfx(CLICK_SFX)
	get_tree().paused = false # Обязательно снимаем с паузы перед перезагрузкой
	get_tree().reload_current_scene()

func _on_next_level_button_pressed() -> void:
	AudioManager.play_sfx(CLICK_SFX)
	get_tree().paused = false
	GameManager.complete_level()


func show_game_over() -> void:
	# Ставим всю игру (кроме UI) на паузу
	get_tree().paused = true
	overlay.show()
	game_over_menu.show()
	win_menu.hide()
	
	$Overlay/GameOverMenu/ReviveButton.show()

func show_win_screen() -> void:
	get_tree().paused = true
	overlay.show()
	win_menu.show()
	game_over_menu.hide()


func _on_reward_earned() -> void:
	# Ищем игрока на уровне
	var player = get_tree().current_scene.find_child("Player", true, false)
	if player and player.has_method("revive"):
		player.revive() # Вызываем новую функцию у игрока
		
	# Прячем экран проигрыша и снимаем игру с паузы
	game_over_menu.hide()
	overlay.hide()
	get_tree().paused = false

func _on_revive_button_pressed() -> void:
	AudioManager.play_sfx(CLICK_SFX)
	
	# Прячем кнопку воскрешения, чтобы игрок не нажал её дважды
	$Overlay/GameOverMenu/ReviveButton.hide()
	
	# Запрашиваем показ рекламы
	AdManager.show_rewarded_ad()



func _on_sparks_changed(new_amount: int) -> void:
	sparks_label.text = "Sparks: " + str(new_amount)
