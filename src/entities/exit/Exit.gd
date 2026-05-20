extends Area2D

const WIN_SFX = preload("res://src/assets/audio/win_zap1.ogg")


# Эта функция сработает, когда кто-то зайдет в зону выхода
func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		AudioManager.play_sfx(WIN_SFX)
		
		# Чтобы нельзя было задеть выход дважды, отключаем коллизию у самого Area2D
		set_deferred("monitoring", false)

		GameManager.complete_level()

		var ui = get_tree().current_scene.find_child("UIControl", true, false)

		if ui and ui.has_method("show_win_screen"):
			ui.show_win_screen()
