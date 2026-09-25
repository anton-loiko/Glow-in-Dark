class_name SettingsMenu
extends Control

const CLICK_SFX = preload("res://src/assets/audio/click_001.ogg")

@onready var sound_button: CheckButton = %SoundButton
@onready var music_button: CheckButton = %MusicButton
@onready var vibration_button: CheckButton = %VibrationButton
@onready var reset_button: Button = %ResetButton
@onready var close_button: Button = %CloseButton

func _ready() -> void:
	# Синхронизируем интерфейс с реальными настройками при открытии меню
	sound_button.button_pressed = GameManager.sound_enabled
	music_button.button_pressed = GameManager.music_enabled
	vibration_button.button_pressed = GameManager.vibration_enabled

	sound_button.toggled.connect(_on_sound_toggled)
	music_button.toggled.connect(_on_music_toggled)
	vibration_button.toggled.connect(_on_vibration_toggled)
	reset_button.pressed.connect(_on_reset_pressed)
	close_button.pressed.connect(_on_close_pressed)

func _on_sound_toggled(toggled_on: bool) -> void:
	GameManager.sound_enabled = toggled_on
	GameManager.save_game()
	if toggled_on:
		AudioManager.play_sfx(CLICK_SFX)

func _on_music_toggled(toggled_on: bool) -> void:
	GameManager.music_enabled = toggled_on
	GameManager.save_game()
	AudioManager.apply_settings()
	AudioManager.play_sfx(CLICK_SFX)

func _on_vibration_toggled(toggled_on: bool) -> void:
	GameManager.vibration_enabled = toggled_on
	GameManager.save_game()
	AudioManager.play_sfx(CLICK_SFX)
	if toggled_on:
		AudioManager.vibrate()

func _on_reset_pressed() -> void:
	AudioManager.play_sfx(CLICK_SFX)
	GameManager.reset_progress()
	
	# Для наглядности можно скрыть меню после сброса, чтобы игрок увидел обнуленный интерфейс главного меню
	hide()

func _on_close_pressed() -> void:
	AudioManager.play_sfx(CLICK_SFX)
	hide()
