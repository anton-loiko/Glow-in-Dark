extends Node

signal login_success
signal sync_completed

var cloud_user_id: String = ""
var users_collection: FirestoreCollection
var current_document: FirestoreDocument

func authenticate_player() -> void:
	print("1. Подключение к Firebase...")
	
	# Плагин GodotFirebase уже автоматически загрузил конфиг из своего .env файла.
	# Мы просто подписываемся на события и вызываем логин.
	
	if not Firebase.Auth.login_succeeded.is_connected(_on_login_succeeded):
		Firebase.Auth.login_succeeded.connect(_on_login_succeeded)
	if not Firebase.Auth.login_failed.is_connected(_on_login_failed):
		Firebase.Auth.login_failed.connect(_on_login_failed)
	
	Firebase.Auth.login_anonymous()

func _on_login_succeeded(auth_info) -> void:
	cloud_user_id = auth_info.localid
	print("2. Игрок авторизован. Cloud ID: ", cloud_user_id)
	
	users_collection = Firebase.Firestore.collection("users")
	
	login_success.emit()
	sync_data()

func _on_login_failed(error_code, message) -> void:
	print("Ошибка авторизации! Код: ", error_code, " | Причина: ", message)
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
		
		# СРАВНЕНИЕ ВАЛЮТЫ (ИСКР)
		if cloud_data.has("sparks"):
			# Если в облаке денег больше, берем оттуда (чтобы предотвратить потерю при смене телефона)
			# В реальном продакшене логика сложнее, но для старта берем максимальное значение
			if cloud_data["sparks"] > GameManager.sparks:
				GameManager.sparks = cloud_data["sparks"]
			elif GameManager.sparks > cloud_data["sparks"]:
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
		"has_no_ads": GameManager.has_no_ads,
		"sparks": GameManager.sparks
	}
	
	current_document = await users_collection.add(cloud_user_id, data)
	
	if current_document != null:
		print("5. Облако успешно обновлено!")
