extends Area2D

const WIN_SFX = preload("res://src/assets/audio/win_zap1.ogg")


# Эта функция сработает, когда кто-то зайдет в зону выхода
func _on_body_entered(body: Node2D) -> void:
	# Проверяем, что это именно Игрок
	if body.name == "Player":
		AudioManager.play_sfx(WIN_SFX)
		# Чтобы нельзя было задеть выход дважды, отключаем коллизию у самого Area2D
		set_deferred("monitoring", false)
		
		# --- ИЗМЕНЕННАЯ СТРОКА ---
		get_tree().call_group("UI", "show_win_screen")
		#get_tree().reload_current_scene()
