extends Area2D

const WIN_SFX = preload("res://src/assets/audio/win_zap1.ogg")

func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		# Отключаем повторные срабатывания коллизии
		set_deferred("monitoring", false)
		
		# Останавливаем движение и затухание света у игрока
		body.set_physics_process(false)
		body.set_process(false)
		
		AudioManager.play_sfx(WIN_SFX)
		
		# Сообщаем глобальному менеджеру, что уровень пройден (current_level увеличится на 1)
		GameManager.complete_level()
		
		# Вызываем экран победы в UI
		var ui = get_tree().current_scene.find_child("UIControl", true, false)
		if ui and ui.has_method("show_win_screen"):
			ui.show_win_screen()