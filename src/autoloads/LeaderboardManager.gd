extends Node
# Сигнал сработает, когда данные успешно скачаются из интернета
signal leaderboard_loaded(leaderboard_data: Array)

func fetch_top_players() -> void:
	# 1. Создаем бланк запроса
	var query = FirestoreQuery.new()
	
	# 2. Указываем коллекцию (таблицу), откуда брать файлы
	query.from("users")
	
	# 3. Приказываем отсортировать по переменной unlocked_level 
	# DIRECTION.DESCENDING означает "от большего к меньшему" (сначала топ-игроки)
	query.order_by("unlocked_level", FirestoreQuery.DIRECTION.DESCENDING)
	
	# 4. Просим вернуть только первые 10 строк, чтобы не тратить мобильный интернет
	query.limit(10)
	
	# 5. Отправляем бланк на сервер Google и ждем ответ
	var query_result = await Firebase.Firestore.query(query)
	
	var leaderboard_list: Array = []
	# 6. Если сервер ответил и прислал нам массив документов
	if query_result != null and not query_result.is_empty():
		for doc in query_result:
			var doc_data = doc.document
			
			var player_name = "Player"
			var player_level = 1
			
			# Распаковываем число уровня из REST API формата Firebase
			if doc_data.has("unlocked_level") and doc_data["unlocked_level"].has("integerValue"):
				player_level = int(doc_data["unlocked_level"]["integerValue"])
			
			# Чтобы не раскрывать чужие скрытые email, мы делаем имя из ID документа.
			# doc.doc_name — это уникальный буквенно-цифровой код аккаунта.
			# left(6) обрезает его, оставляя первые 6 символов (например, Player_a84f1d)
			if doc.doc_name != "":
				player_name = "Player_" + doc.doc_name.left(6)
			
			# Кладим чистые данные в наш итоговый список
			leaderboard_list.append({
				"name": player_name,
				"level": player_level
			})
	
	# 7. Громко объявляем, что список готов, и отдаем его графическому интерфейсу
	leaderboard_loaded.emit(leaderboard_list)
