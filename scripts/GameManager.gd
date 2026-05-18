extends Node

const SAVE_PATH: String = "user://save_data.cfg"

# 1. ДОБАВИТЬ ЭТИ СТРОКИ В НАЧАЛО ФАЙЛА (после has_no_ads)
signal sparks_changed(new_amount: int) # Сигнал для обновления UI
var sparks: int = 0

# 2. ПОЛНОСТЬЮ ЗАМЕНИТЬ СЛОВАРЬ SKINS_DB
const SKINS_DB: Dictionary = {
	"default": {
		"color": Color(1.0, 1.0, 1.0),
		"price_usd": 0.0,
		"price_sparks": 0,
		"condition": "start"
	},
	"blue_flame": {
		"color": Color(0.3, 0.6, 1.0),
		"price_usd": 1.99,
		"price_sparks": 0,
		"condition": "store_usd" # Покупка через банк
	},
	"purple_magic": {
		"color": Color(0.8, 0.2, 1.0), # Фиолетовый цвет
		"price_usd": 0.0,
		"price_sparks": 150,
		"condition": "store_sparks" # Покупка за игровую валюту
	}
}


var has_no_ads: bool = false

var current_level: int = 1
var unlocked_level: int = 1

# Структура уровней (3D Массив: [Уровень][Строка][Столбец])
# 0 = Пол, 1 = Стена, 2 = Топливо, 3 = Выход, 4 = Искра, 9 = Игрок
var levels_data = [
	# Уровень 1
	[
		[1, 1, 1, 1, 1, 1, 1],
		[1, 9, 0, 0, 0, 2, 1], # 9 — игрок стартует здесь
		[1, 1, 1, 0, 1, 1, 1],
		[1, 2, 4, 0, 4, 3, 1], # 3 — выход здесь
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
	config.set_value("inventory", "sparks", sparks)
	
	
	
	# Физически записываем файл в зашифрованную или изолированную папку приложения на телефоне
	var error = config.save(SAVE_PATH)
	if error != OK:
		print("Не удалось сохранить игру. Код ошибки: ", error)
	else:
		# Функция save_to_cloud() внутри использует await, но здесь мы можем вызвать её 
		# напрямую без await, чтобы интерфейс не замирал в ожидании ответа от сервера.
		# Она соберет новый массив скинов и флаг рекламы и тихо отправит их в Firestore в фоне.
		print("Игра сохранась успешно. Вызываем: CloudManager.save_to_cloud.")

		CloudManager.save_to_cloud()


func load_game() -> void:
	var config = ConfigFile.new()
	var error = config.load(SAVE_PATH)
	
	# Если файла на диске нет (самый первый запуск в жизни)
	if error != OK:
		print("Локальный файл не найден. Создаем базовый профиль на телефоне...")
		# Сразу вызываем сохранение текущих стартовых переменных
		save_game() 
		return
		
	unlocked_level = config.get_value("progress", "unlocked_level", 1)
	has_no_ads = config.get_value("purchases", "has_no_ads", false)
	owned_skins = config.get_value("inventory", "owned_skins", ["default"])
	equipped_skin = config.get_value("inventory", "equipped_skin", "default")
	sparks = config.get_value("inventory", "sparks", 0)

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

func add_sparks(amount: int) -> void:
	sparks += amount
	sparks_changed.emit(sparks)
	save_game() # Сразу сохраняем на диск, чтобы не потерять деньги
 
