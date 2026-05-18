extends Node2D

# Предварительно загружаем сцены объектов в память
# Это как импорт модулей: мы подготавливаем чертежи, чтобы быстро создавать копии
const PLAYER_SCENE = preload("res://scenes/Player.tscn")
const FUEL_SCENE = preload("res://scenes/Fuel.tscn")
const EXIT_SCENE = preload("res://scenes/Exit.tscn")

@onready var tile_map: TileMapLayer = $TileMapLayer

func _ready() -> void:
	generate_level()

func generate_level() -> void:
	# Берем данные текущего уровня из нашего глобального менеджера
	var level_index = GameManager.current_level - 1
	var map_data = GameManager.levels_data[level_index]
	
	# Очищаем старую карту, если она была
	#tile_map.clear()
	
	# Проходим циклом по каждой строке массива (Y)
	for y in range(map_data.size()):
		# Проходим циклом по каждому числу в строке (X)
		for x in range(map_data[y].size()):
			var cell_type = map_data[y][x]
			
			# Определяем позицию в мировых координатах (пикселях)
			# map_to_local берет номер клетки (например 2,3) и превращает в пиксели (например 128, 192)
			var pos = tile_map.map_to_local(Vector2i(x, y))
			
			match cell_type:
				1: # СТЕНА
					# Рисуем тайл в сетке. 
					# 0 — это ID твоего TileSet, Vector2i(0,0) — координаты картинки в атласе
					#tile_map.set_cell(Vector2i(x, y), 0, Vector2i(0, 0))
					pass
				0: # ПУСТОТА
					pass # Ничего не делаем
				
				2: # ТОПЛИВО
					spawn_object(FUEL_SCENE,  Vector2(12.0, 200.0))
				
				3: # ВЫХОД
					spawn_object(EXIT_SCENE,  Vector2(430.0, 220.0))
				
				9: # ИГРОК (добавим 9 как ID для старта игрока)
					spawn_object(PLAYER_SCENE, Vector2(235.0, 10.0))

# Вспомогательная функция для создания объекта
func spawn_object(scene: PackedScene, pos: Vector2) -> void:
	var instance = scene.instantiate()
	instance.global_position = pos
	add_child(instance)
