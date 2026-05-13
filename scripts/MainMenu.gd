extends Control

const CLICK_SFX = preload("res://assets/audio/click_001.ogg")

@onready var continue_button: Button = $VBoxContainer/ContinueButton



func _ready() -> void:
	if GameManager.unlocked_level <= 1:
		continue_button.hide()
	else:
		continue_button.show()

func _on_continue_button_pressed() -> void:
	AudioManager.play_sfx(CLICK_SFX)
	GameManager.current_level = GameManager.unlocked_level
	get_tree().change_scene_to_file("res://scenes/Level.tscn")

func _on_new_game_button_pressed() -> void:
	AudioManager.play_sfx(CLICK_SFX)
	GameManager.current_level = 1
	get_tree().change_scene_to_file("res://scenes/Level.tscn")
