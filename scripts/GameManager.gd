extends Node

const SAVE_PATH: String = "user://save_data.cfg"

# --- НОВАЯ СИСТЕМА СКИНОВ ---
# База данных всех существующих скинов в игре
const SKINS_DB: Dictionary = {
	"default": {
		"color": Color(1.0, 1.0, 1.0), # Белый
		"price": 0.0,
		"condition": "start" # Доступен изначально
	},
	"blue_flame": {
		"color": Color(0.3, 0.6, 1.0), # Синий
		"price": 1.99,
		"condition": "store" # Покупается за деньги
	},
	"halloween_ghost": {
		"color": Color(0.5, 1.0, 0.5), # Токсично-зеленый
		"price": 0.0,
		"condition": "event_october" # Выдается сервером во время ивента
	}
}



var has_no_ads: bool = false

var current_level: int = 1
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
	],
	[
		[1, 1, 1, 1, 1, 1, 1],
		[1, 9, 0, 0, 1, 3, 1], 
		[1, 1, 1, 0, 0, 0, 1], 
		[1, 1, 1, 1, 1, 1, 1]
	]
]


# Инвентарь игрока
var owned_skins: Array = ["default"]
# Текущий надетый скин
var equipped_skin: String = "default"


func _ready() -> void:
	load_game()

func save_game() -> void:
	var config = ConfigFile.new()
	
	config.set_value("progress", "unlocked_level", unlocked_level)
	config.set_value("purchases", "has_no_ads", has_no_ads)
	
	# Сохраняем массив строк (ID скинов) и текущий выбор
	config.set_value("inventory", "owned_skins", owned_skins)
	config.set_value("inventory", "equipped_skin", equipped_skin)
	
	# Физически записываем файл в зашифрованную или изолированную папку приложения на телефоне
	var error = config.save(SAVE_PATH)
	if error != OK:
		print("Не удалось сохранить игру. Код ошибки: ", error)

func load_game() -> void:
	var config = ConfigFile.new()
	
	# Пробуем прочитать файл с диска
	var error = config.load(SAVE_PATH)
	
	# ERR_FILE_NOT_FOUND равен коду 7. Если файла нет (первый запуск игры), прерываем функцию
	if error != OK:
		print("Файл сохранения отсутствует, используются значения по умолчанию.")
		return
		
	# Читаем значения. Третий параметр — это дефолтное значение, если ключ будет удален или поврежден
	unlocked_level = config.get_value("progress", "unlocked_level", 1)
	has_no_ads = config.get_value("purchases", "has_no_ads", false)
	
	# Загружаем массив. Третий параметр — значение по умолчанию
	owned_skins = config.get_value("inventory", "owned_skins", ["default"])
	equipped_skin = config.get_value("inventory", "equipped_skin", "default")


# Функция перехода на следующий уровень
func complete_level():
	current_level += 1
	if current_level > unlocked_level:
		unlocked_level = current_level
		LeaderboardManager.submit_score(unlocked_level)
		save_game()
	
	# Проверяем, не закончились ли уровни
	if current_level <= levels_data.size():
		get_tree().change_scene_to_file("res://scenes/Level.tscn")
	else:
		# Если уровни кончились — возвращаемся в меню
		get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
		

# Вспомогательная функция для безопасного получения цвета скина
func get_equipped_skin_color() -> Color:
	if SKINS_DB.has(equipped_skin):
		return SKINS_DB[equipped_skin]["color"]
	return SKINS_DB["default"]["color"]
