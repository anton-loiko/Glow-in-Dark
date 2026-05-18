extends Node

# В качестве очков (Score) мы будем использовать максимальный пройденный уровень
func submit_score(score: int) -> void:
	print("Связь с сервером Game Center / Play Games...")
	print("Отправлен новый рекорд: Уровень ", score)
	# Позже здесь будет код плагина: 
	# leaderboard_plugin.submit_score("my_leaderboard_id", score)

func show_leaderboard() -> void:
	print("Открытие системного UI списка лидеров Apple/Google")
	# Позже здесь будет код плагина: 
	# leaderboard_plugin.show_leaderboard("my_leaderboard_id")
