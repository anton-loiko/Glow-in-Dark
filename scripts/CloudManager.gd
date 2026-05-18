extends Node

signal login_success
signal sync_completed

# Этот метод мы будем вызывать из MainMenu при первом запуске
func authenticate_player() -> void:
	print("1. Запрос OS токена (Game Center / Play Games)...")
	# await os_plugin.get_auth_token()
	
	print("2. Отправка токена в Облако (Firebase)...")
	# await firebase.auth_with_custom_token(token)
	
	print("3. Игрок авторизован.")
	login_success.emit()
	
	# Сразу запускаем синхронизацию данных
	sync_data()

func sync_data() -> void:
	print("Синхронизация локальных сохранений с облаком...")
	# Логика:
	# 1. Скачать документ игрока из базы данных (Firestore).
	# 2. Сравнить unlocked_level: взять то число, которое больше (локальное или облачное).
	# 3. Объединить (Merge) массивы owned_skins: добавить локальные покупки в облако и наоборот.
	# 4. Перезаписать GameManager локально и отправить обновленный документ обратно в облако.
	
	sync_completed.emit()
