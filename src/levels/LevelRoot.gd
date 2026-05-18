extends Node2D

@onready var level_container: Node2D = $LevelContainer
@onready var ui: CanvasLayer = $UI # Или Node, в зависимости от корня твоего UI

func _ready() -> void:
	# 1. Формируем путь к текущему уровню
	var level_path = "res://src/levels/Level_" + str(GameManager.current_level) + ".tscn"
	
	# 2. Проверяем, есть ли такой файл
	if ResourceLoader.exists(level_path):
		# 3. Загружаем и создаем уровень
		var level_resource = load(level_path)
		var level_instance = level_resource.instantiate()
		
		# 4. Вставляем уровень в контейнер
		level_container.add_child(level_instance)
		
		# 5. Ищем игрока в только что загруженном уровне
		var player = level_instance.find_child("Player", true, false)
		
		# 6. Подключаем свет игрока к UI (раньше это делал сам UI в своем _ready)
		if player and ui.has_method("_on_player_light_changed"):
			player.light_changed.connect(ui._on_player_light_changed)
	else:
		print("Ошибка: Уровень не найден по пути ", level_path)
