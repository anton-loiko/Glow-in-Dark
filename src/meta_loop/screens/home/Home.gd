extends Control

const LEVEL_ROOT_SCENE_PATH = "res://src/core_loop/levels/LevelRoot.tscn"
const CLICK_SFX = preload("res://src/assets/audio/click_001.ogg")
const ERROR_SFX = preload("res://src/assets/audio/error_008.ogg")

@onready var play_button: Button = %PlayButton
@onready var settings_button: Button = %SettingsButton

func _ready() -> void:	
	settings_button.pressed.connect(_on_settings_button_pressed)
	play_button.pressed.connect(_on_play_button_pressed)
	
	_play_button_animation()

# ----On Press----



func _on_play_button_pressed() -> void:
	AudioManager.play_sfx(CLICK_SFX)
	get_tree().change_scene_to_file(LEVEL_ROOT_SCENE_PATH)

func _on_settings_button_pressed() -> void:
	AudioManager.play_sfx(CLICK_SFX)
	$SettingsMenu.show()

#---

func _play_button_animation() -> void:
	const _speed = 0.65
	const _min_shadow = 1
	
	var normal_style: StyleBox = play_button.get_theme_stylebox("normal").duplicate()
	play_button.add_theme_stylebox_override("normal", normal_style)
	
	var original_shadow_size: int = normal_style.shadow_size
	var tween = create_tween()

	tween.set_loops()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	# Действие 1: Уменьшаем тень до 0 за 0.4 секунды
	tween.tween_property(normal_style, "shadow_size", _min_shadow, _speed)
	
	# Действие 2: Увеличиваем тень обратно до original_shadow_size за 0.4 секунды.
	# В Godot 4 эта строчка автоматически начнет работать ТОЛЬКО после 
	# того, как закончится Действие 1.
	tween.tween_property(normal_style, "shadow_size", original_shadow_size, _speed)
