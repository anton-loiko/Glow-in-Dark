class_name GameUI
extends Control

const CLICK_SFX = preload("res://src/assets/audio/click_001.ogg")
const GAME_OVER_SFX = preload("res://src/assets/audio/lose_powerUp10.ogg")

@onready var progress_bar: TextureProgressBar = %TextureProgressBar
@onready var lose_panel: Panel = %LosePanel
@onready var win_panel: Panel = %WinPanel
@onready var sparks_label: Label = %SparksLabel
@onready var reward_label: Label = %WinPanel/VBoxContainer/RewardLabel
@onready var next_button: Button = %WinPanel/VBoxContainer/NextLevelButton
@onready var revive_button: Button = %LosePanel/VBoxContainer/ReviveButton
@onready var virtual_joystick: VirtualJoystick = %"Virtual Joystick"

@onready var vignette_rect: ColorRect = %VignetteRect

var sparks_at_level_start: int = 0
var is_danger_mode: bool = false
var current_light: float = 1.0

func _ready() -> void:
	virtual_joystick.show()
	
	sparks_at_level_start = GameManager.sparks
	sparks_label.text = "Sparks: " + str(GameManager.sparks)
	
	AdManager.reward_earned.connect(_on_reward_earned)
	GameManager.sparks_changed.connect(_on_sparks_changed)
	
	progress_bar.max_value = 1.0 
	progress_bar.step = 0.01
	progress_bar.tint_progress = Color.WHITE
	
	if vignette_rect and vignette_rect.material:
		vignette_rect.material.set_shader_parameter("intensity", 0.0)

func _process(delta: float) -> void:
	if not vignette_rect or not vignette_rect.material or get_tree().paused:
		return
		
	if current_light < 0.05:
		vignette_rect.material.set_shader_parameter("intensity", 0.0)
		return
	
	# Непрерывная пульсация, если света меньше 25%
	if is_danger_mode:
		var pulse = (sin(Time.get_ticks_msec() * 0.01) + 1.0) / 2.0 
		vignette_rect.material.set_shader_parameter("intensity", 0.4 + (pulse * 0.6))
	else:
		# Плавное затухание виньетки, если игрок восстановил свет (но не перебиваем вспышку урона)
		var current_intensity = vignette_rect.material.get_shader_parameter("intensity")
		if current_intensity > 0.0 and current_intensity < 0.9: 
			vignette_rect.material.set_shader_parameter("intensity", lerpf(current_intensity, 0.0, 5.0 * delta))

func _on_player_light_changed(new_value: float) -> void:
	# Определяем получение урона: если свет упал мгновенно больше чем на 5% за кадр
	if current_light - new_value > 0.05 and vignette_rect and vignette_rect.material:
		_flash_vignette()
		
	current_light = new_value
	progress_bar.value = new_value
	
	if new_value < 0.25:
		if not is_danger_mode:
			is_danger_mode = true
			progress_bar.tint_progress = Color(1.0, 0.2, 0.2)
	else:
		if is_danger_mode:
			is_danger_mode = false
			progress_bar.tint_progress = Color.WHITE

func _flash_vignette() -> void:
	var tween = create_tween()
	tween.tween_method(_set_vignette_intensity, 0.0, 1.0, 0.1)
	tween.tween_method(_set_vignette_intensity, 1.0, 0.0, 0.3)

func _set_vignette_intensity(val: float) -> void:
	if vignette_rect and vignette_rect.material:
		vignette_rect.material.set_shader_parameter("intensity", val)

func show_game_over() -> void:
	get_tree().paused = true
	virtual_joystick.hide()
	lose_panel.show()
	AudioManager.play_sfx(GAME_OVER_SFX)
	win_panel.hide()

func show_win_screen() -> void:
	get_tree().paused = true
	virtual_joystick.hide()
	var collected = GameManager.sparks - sparks_at_level_start
	reward_label.text = "Collected sparks: " + str(collected)
	win_panel.show()
	lose_panel.hide()

func _on_reward_earned() -> void:
	var players = get_tree().get_nodes_in_group("player")
	
	if players.size() > 0 and players[0].has_method("revive"):
		players[0].revive()
	
	revive_button.hide()
	lose_panel.hide()
	virtual_joystick.show()
	get_tree().paused = false

func _on_sparks_changed(new_amount: int) -> void:
	sparks_label.text = "Sparks: " + str(new_amount)
	
	sparks_label.pivot_offset = sparks_label.size / 2.0
	
	var tween = create_tween().set_parallel(true)
	
	sparks_label.scale = Vector2(1.4, 1.4)
	sparks_label.modulate = Color(0.8, 0.2, 1.0) 
	
	tween.tween_property(sparks_label, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tween.tween_property(sparks_label, "modulate", Color.WHITE, 0.3)

func _on_next_level_button_pressed() -> void:
	AudioManager.play_sfx(CLICK_SFX)
	get_tree().paused = false
	GameManager.next_level()

func _on_revive_button_pressed() -> void:
	AudioManager.play_sfx(CLICK_SFX)
	revive_button.disabled = true
	AdManager.show_rewarded_ad()

func _on_menu_button_pressed() -> void:
	AudioManager.play_sfx(CLICK_SFX)
	get_tree().paused = false
	GameManager.go_to_main_menu()
