extends Node

signal login_success
signal sync_completed

var cloud_user_id: String = ""
var users_collection: FirestoreCollection
var current_document: FirestoreDocument

# Наш собственный файл для хранения "фейкового" аккаунта
const SECRET_AUTH_FILE = "user://secret_auth.cfg"

func authenticate_player() -> void:
	print("Подключение к Firebase...")
	
	if not Firebase.Auth.login_succeeded.is_connected(_on_login_succeeded):
		Firebase.Auth.login_succeeded.connect(_on_login_succeeded)
	if not Firebase.Auth.login_failed.is_connected(_on_login_failed):
		Firebase.Auth.login_failed.connect(_on_login_failed)
		
	# Подключаем сигнал для успешной регистрации
	if not Firebase.Auth.signup_succeeded.is_connected(_on_signup_succeeded):
		Firebase.Auth.signup_succeeded.connect(_on_signup_succeeded)
	
	# Читаем наш файл
	var config = ConfigFile.new()
	var error = config.load(SECRET_AUTH_FILE)
	
	if error == OK:
		# Аккаунт уже был создан ранее. Берем логин и пароль.
		var fake_email = config.get_value("auth", "email", "")
		var fake_pwd = config.get_value("auth", "password", "")
		
		print("Найден локальный профиль. Логинимся как: ", fake_email)
		Firebase.Auth.login_with_email_and_password(fake_email, fake_pwd)
	else:
		# Первый запуск игры! Генерируем случайные данные
		print("Профиля нет. Генерируем скрытый привязанный аккаунт...")
		var random_id = str(Time.get_unix_time_from_system()).replace(".", "") + str(randi() % 10000)
		var fake_email = "player_" + random_id + "@lightinthedark.com"
		var fake_pwd = "Pass" + random_id + "!"
		
		# НАВСЕГДА сохраняем этот email и пароль на телефон игрока
		config.set_value("auth", "email", fake_email)
		config.set_value("auth", "password", fake_pwd)
		config.save(SECRET_AUTH_FILE)
		
		# Отправляем регистрацию в Firebase
		Firebase.Auth.signup_with_email_and_password(fake_email, fake_pwd)

# Если регистрация прошла успешно, мы перенаправляем ее в логин
func _on_signup_succeeded(auth_info) -> void:
	print("--- Скрытый аккаунт успешно зарегистрирован! ---")
	_on_login_succeeded(auth_info)

func _on_login_succeeded(auth_info) -> void:
	cloud_user_id = auth_info.localid
	print("Игрок авторизован. Cloud ID: ", cloud_user_id)
	
	users_collection = Firebase.Firestore.collection("users")
	
	login_success.emit()
	sync_data()

func _on_login_failed(error_code, message) -> void:
	print("Ошибка авторизации! Код: ", error_code, " | Причина: ", message)
	sync_completed.emit()

func sync_data() -> void:
	print("Скачивание документа из Firestore...")
	current_document = await users_collection.get_doc(cloud_user_id)
	
	if current_document != null and current_document.document != null and not current_document.document.is_empty():
		print("Облачное сохранение найдено. Слияние данных...")
		var cloud_data = current_document.document
		var need_cloud_update: bool = false
		
		# --- 1. РАСПАКОВКА УРОВНЯ ---
		if cloud_data.has("unlocked_level"):
			var cloud_lvl: int = 1
			# Ищем внутри коробки ярлык integerValue или doubleValue
			if cloud_data["unlocked_level"].has("integerValue"):
				cloud_lvl = int(cloud_data["unlocked_level"]["integerValue"])
			elif cloud_data["unlocked_level"].has("doubleValue"):
				cloud_lvl = int(cloud_data["unlocked_level"]["doubleValue"])
				
			if cloud_lvl > GameManager.unlocked_level:
				GameManager.unlocked_level = cloud_lvl
			elif GameManager.unlocked_level > cloud_lvl:
				need_cloud_update = true
		
		# --- 2. РАСПАКОВКА СКИНОВ (МАССИВ) ---
		if cloud_data.has("owned_skins"):
			var cloud_skins: Array = []
			# Проверяем сложную структуру массива REST API
			if cloud_data["owned_skins"].has("arrayValue") and cloud_data["owned_skins"]["arrayValue"].has("values"):
				# Перебираем элементы внутри values
				for item in cloud_data["owned_skins"]["arrayValue"]["values"]:
					if item.has("stringValue"):
						cloud_skins.append(item["stringValue"])
						
			for skin in cloud_skins:
				if not GameManager.owned_skins.has(skin):
					GameManager.owned_skins.append(skin)
					
			if GameManager.owned_skins.size() > cloud_skins.size():
				need_cloud_update = true
					
		# --- 3. РАСПАКОВКА РЕКЛАМЫ ---
		if cloud_data.has("has_no_ads"):
			var cloud_ads: bool = false
			if cloud_data["has_no_ads"].has("booleanValue"):
				cloud_ads = bool(cloud_data["has_no_ads"]["booleanValue"])
				
			if cloud_ads == true:
				GameManager.has_no_ads = true
			elif GameManager.has_no_ads and not cloud_ads:
				need_cloud_update = true
				
		# --- 4. РАСПАКОВКА ИСКР (ВАЛЮТЫ) ---
		if cloud_data.has("sparks"):
			var cloud_sparks: int = 0
			if cloud_data["sparks"].has("integerValue"):
				cloud_sparks = int(cloud_data["sparks"]["integerValue"])
			elif cloud_data["sparks"].has("doubleValue"):
				cloud_sparks = int(cloud_data["sparks"]["doubleValue"])
				
			if cloud_sparks > GameManager.sparks:
				GameManager.sparks = cloud_sparks
			elif GameManager.sparks > cloud_sparks:
				need_cloud_update = true
		
		# Фиксируем изменения на жестком диске телефона
		GameManager.save_game()
		
		if need_cloud_update:
			await save_to_cloud()
	else:
		print("Новый профиль. Отправка стартовых данных в облако...")
		await save_to_cloud()
		
	sync_completed.emit()

func save_to_cloud() -> void:
	if cloud_user_id == "": 
		return 
		
	# 1. Сценарий обновления существующего документа (UPDATE)
	if current_document != null and current_document.document != null and not current_document.document.is_empty():
		
		# Вручную упаковываем массив скинов в формат REST API
		var skins_firebase_array: Array = []
		for skin in GameManager.owned_skins:
			skins_firebase_array.append({"stringValue": skin})
			
		# Вручную упаковываем остальные переменные
		var firebase_formatted_data = {
			"unlocked_level": {"integerValue": GameManager.unlocked_level},
			"owned_skins": {"arrayValue": {"values": skins_firebase_array}},
			"has_no_ads": {"booleanValue": GameManager.has_no_ads},
			"sparks": {"integerValue": GameManager.sparks}
		}
		
		# Заменяем внутренности документа на наши правильно упакованные данные
		current_document.document = firebase_formatted_data
		
		# Отправляем готовый документ на сервер
		current_document = await users_collection.update(current_document)
		print("Облако успешно обновлено (UPDATE)!")
		
	# 2. Сценарий создания абсолютно нового профиля (ADD)
	else:
		# Для функции add() плагин умеет сам упаковывать обычный словарь Godot
		var normal_data = {
			"unlocked_level": GameManager.unlocked_level,
			"owned_skins": GameManager.owned_skins,
			"has_no_ads": GameManager.has_no_ads,
			"sparks": GameManager.sparks
		}
		
		current_document = await users_collection.add(cloud_user_id, normal_data)
		print("Облако успешно обновлено (ADD)!")
