extends Node

signal login_success
signal sync_completed

var cloud_user_id: String = ""
var users_collection: FirestoreCollection
var current_document: FirestoreDocument

func authenticate_player() -> void:
	print("1. Загрузка конфигурации Firebase...")
	
	var firebase_config: Dictionary = _load_config()
	
	if firebase_config.is_empty():
		print("КРИТИЧЕСКАЯ ОШИБКА: Конфигурация Firebase не найдена ни в JSON, ни в .env!")
		sync_completed.emit()
		return
		
	# --- ИСПРАВЛЕННАЯ СТРОКА ---
	# Напрямую записываем наш распарсенный словарь в переменную плагина
	Firebase.config = firebase_config
	
	# Подключаем сигналы только если они еще не подключены, 
	# чтобы избежать ошибки двойного подключения при перезапусках
	if not Firebase.Auth.login_succeeded.is_connected(_on_login_succeeded):
		Firebase.Auth.login_succeeded.connect(_on_login_succeeded)
	if not Firebase.Auth.login_failed.is_connected(_on_login_failed):
		Firebase.Auth.login_failed.connect(_on_login_failed)
	
	Firebase.Auth.login_anonymous()

# --- НОВАЯ ФУНКЦИЯ ЧТЕНИЯ И ПАРСИНГА КОНФИГОВ ---
func _load_config() -> Dictionary:
	var json_path: String = "res://firebase.json"
	var env_path: String = "res://.env"
	
	# Попытка 1: Читаем firebase.json
	if FileAccess.file_exists(json_path):
		var file = FileAccess.open(json_path, FileAccess.READ)
		var content = file.get_as_text()
		
		# Превращаем текст в объекты Godot (Словарь)
		var parsed = JSON.parse_string(content)
		
		# Проверяем, что парсинг прошел успешно и мы получили именно словарь
		if typeof(parsed) == TYPE_DICTIONARY:
			print("Конфиг успешно загружен из firebase.json")
			return parsed
		else:
			print("Ошибка: firebase.json имеет неверный формат. Переход к резервному варианту.")
			
	# Попытка 2: Читаем .env (Фолбэк)
	if FileAccess.file_exists(env_path):
		print("firebase.json не найден. Парсим .env файл...")
		var env_dict: Dictionary = {}
		var file = FileAccess.open(env_path, FileAccess.READ)
		
		# Читаем файл строка за строкой, пока не дойдем до конца
		while not file.eof_reached():
			# Берем строку и отрезаем лишние пробелы по краям
			var line = file.get_line().strip_edges()
			
			# Игнорируем пустые строки и комментарии
			if line.is_empty() or line.begins_with("#"):
				continue
				
			# Разрезаем строку по знаку "равно" на две части (ключ и значение)
			var parts = line.split("=", true, 1)
			if parts.size() == 2:
				var key = parts[0].strip_edges()
				# Очищаем значение от возможных кавычек
				var val = parts[1].strip_edges().replace("\"", "")
				env_dict[key] = val
		
		if not env_dict.is_empty():
			print("Конфиг успешно загружен из .env")
			return env_dict

	# Если оба файла отсутствуют или пусты, возвращаем пустой словарь
	return {}

func _on_login_succeeded(auth_info) -> void:
	cloud_user_id = auth_info.localid
	print("2. Игрок авторизован. Cloud ID: ", cloud_user_id)
	
	users_collection = Firebase.Firestore.collection("users")
	
	login_success.emit()
	sync_data()

func _on_login_failed(error_code, message) -> void:
	print("Ошибка авторизации: ", message)
	sync_completed.emit()

func sync_data() -> void:
	print("3. Скачивание документа из Firestore...")
	
	current_document = await users_collection.get_doc(cloud_user_id)
	
	if current_document != null:
		print("4. Облачное сохранение найдено. Слияние данных...")
		var cloud_data = current_document.doc_fields
		var need_cloud_update: bool = false
		
		if cloud_data.has("unlocked_level"):
			if cloud_data["unlocked_level"] > GameManager.unlocked_level:
				GameManager.unlocked_level = cloud_data["unlocked_level"]
			elif GameManager.unlocked_level > cloud_data["unlocked_level"]:
				need_cloud_update = true
		
		if cloud_data.has("owned_skins"):
			var cloud_skins = cloud_data["owned_skins"]
			for skin in cloud_skins:
				if not GameManager.owned_skins.has(skin):
					GameManager.owned_skins.append(skin)
			
			if GameManager.owned_skins.size() > cloud_skins.size():
				need_cloud_update = true
					
		if cloud_data.has("has_no_ads") and cloud_data["has_no_ads"] == true:
			GameManager.has_no_ads = true
		elif GameManager.has_no_ads and not (cloud_data.has("has_no_ads") and cloud_data["has_no_ads"] == true):
			need_cloud_update = true
		
		GameManager.save_game()
		
		if need_cloud_update:
			await save_to_cloud()
	else:
		print("4. Новый профиль. Отправка стартовых данных в облако...")
		await save_to_cloud()
		
	sync_completed.emit()

func save_to_cloud() -> void:
	if cloud_user_id == "": 
		return 
		
	var data = {
		"unlocked_level": GameManager.unlocked_level,
		"owned_skins": GameManager.owned_skins,
		"has_no_ads": GameManager.has_no_ads
	}
	
	current_document = await users_collection.add(cloud_user_id, data)
	
	if current_document != null:
		print("5. Облако успешно обновлено!")
