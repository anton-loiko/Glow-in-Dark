extends Node


var has_no_ads: bool = false
var has_blue_skin: bool = false

# Храним текущий уровень
var current_level: int = 1
# Максимальный достигнутый уровень (для кнопки "Продолжить")
var unlocked_level: int = 1

# Структура уровней (3D Массив: [Уровень][Строка][Столбец])
# 0 = Пусто (пол), 1 = Стена, 2 = Топливо, 3 = Выход
var levels_data = [
	# Уровень 1
[
		[1, 1, 1, 1, 1, 1, 1],
		[1, 9, 0, 0, 0, 2, 1], # 9 — игрок стартует здесь
		[1, 1, 1, 0, 1, 1, 1],
		[1, 2, 0, 0, 0, 3, 1], # 3 — выход здесь
		[1, 1, 1, 1, 1, 1, 1]
	]
]

func save_game():
	# Позже здесь будет логика сохранения в файл (JSON или ConfigFile)
	pass

func load_game():
	# Позже здесь будет загрузка прогресса
	pass

# Функция перехода на следующий уровень
func complete_level():
	current_level += 1
	if current_level > unlocked_level:
		unlocked_level = current_level
	
	# Проверяем, не закончились ли уровни
	if current_level <= levels_data.size():
		get_tree().change_scene_to_file("res://scenes/Level.tscn")
	else:
		# Если уровни кончились — возвращаемся в меню
		get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
