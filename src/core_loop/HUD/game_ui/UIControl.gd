class_name GameUI
extends Control

const CLICK_SFX = preload("res://src/assets/audio/click_001.ogg")
const GAME_OVER_SFX = preload("res://src/assets/audio/lose_powerUp10.ogg")

@onready var progress_bar: TextureProgressBar = %TextureProgressBar
@onready var lose_panel: Panel = %LosePanel
@onready var win_panel: Panel = %WinPanel
@onready var soft_currency: SoftCurrency = %SoftCurrency
@onready var reward_label: Label = %WinPanel/VBoxContainer/RewardLabel
@onready var next_button: Button = %WinPanel/VBoxContainer/NextLevelButton
@onready var virtual_joystick: VirtualJoystick = %"Virtual Joystick"

@onready var vignette_rect: ColorRect = %VignetteRect

@onready var safe_area_container: MarginContainer = %SafeAreaContainer
@onready var pause_button_reserved_place: MarginContainer = %PauseIconReservedPlace
@onready var pause_button: Button = %PauseButton
@onready var pause_menu: PauseMenu = %PauseMenu

var sparks_at_level: int = 0
var is_danger_mode: bool = false
var current_light: float = 1.0
var counter_to_show_skill_choice: int = 0

func _ready() -> void:
	virtual_joystick.show()
	pause_button.show()

	
	soft_currency.set_amount(sparks_at_level)
	
	AdManager.reward_earned.connect(_on_reward_earned)
	GameManager.sparks_picked_up.connect(_on_sparks_picked_up)
	GameManager.skill_applied.connect(_on_skill_applied)
	pause_button.pressed.connect(_on_pause_button_pressed)

	progress_bar.max_value = 1.0
	progress_bar.step = 0.01
	progress_bar.tint_progress = Color.WHITE
	
	if vignette_rect and vignette_rect.material:
		vignette_rect.material.set_shader_parameter("intensity", 0.0)
	
	await get_tree().process_frame
	
	var safe_area_container_top_margin: int = safe_area_container.get_theme_constant("margin_top")
	var pause_button_reserved_place_pos: Vector2 = pause_button_reserved_place.position
	
	pause_button.position = Vector2(pause_button_reserved_place_pos.x + (pause_button.size.x / 2), pause_button_reserved_place_pos.y + safe_area_container_top_margin)

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
	GameManager.add_sparks(sparks_at_level)
	get_tree().paused = true
	virtual_joystick.hide()
	pause_button.hide()
	lose_panel.show()
	AudioManager.play_sfx(GAME_OVER_SFX)
	win_panel.hide()


func show_win_screen() -> void:
	get_tree().paused = true
	virtual_joystick.hide()
	pause_button.hide()

	GameManager.add_sparks(sparks_at_level)
	reward_label.text = "+" + str(sparks_at_level) + " sparks"
	
	win_panel.show()
	lose_panel.hide()
	
	

func _on_reward_earned() -> void:
	var players = get_tree().get_nodes_in_group("player")
	
	if players.size() > 0 and players[0].has_method("revive"):
		players[0].revive()
	
	lose_panel.hide()
	virtual_joystick.show()
	pause_button.show()
	get_tree().paused = false

func _on_skill_applied(skill_id: String) -> void:
	var price = GameManager.SKILLS_DB[skill_id].price_sparks
	
	sparks_at_level -= price
	soft_currency.set_amount(sparks_at_level)
	
func _on_sparks_picked_up(amount: int) -> void:
	sparks_at_level += amount
	counter_to_show_skill_choice += 1
	
	soft_currency.set_amount(sparks_at_level)
	
	if sparks_at_level >=  GameManager.SKILL_CHOICE_TRIGGERED_TRASHHOLD:
		GameManager.skill_choice_triggered.emit()
		counter_to_show_skill_choice = 0
	
	var currency_label = soft_currency.get_node("%Currency")
	currency_label.pivot_offset = currency_label.size / 2.0
	
	var tween = create_tween().set_parallel(true)
	
	currency_label.scale = Vector2(1.4, 1.4)
	currency_label.modulate = Color(0.8, 0.2, 1.0)
	
	tween.tween_property(currency_label, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tween.tween_property(currency_label, "modulate", Color.WHITE, 0.3)

func _on_next_level_button_pressed() -> void:
	AudioManager.play_sfx(CLICK_SFX)
	get_tree().paused = false
	GameManager.next_level()


func _on_menu_button_pressed() -> void:
	AudioManager.play_sfx(CLICK_SFX)
	get_tree().paused = false
	GameManager.go_to_main_menu()

func _on_pause_button_pressed() -> void:
	AudioManager.play_sfx(CLICK_SFX)
	pause_menu.open_pause()
