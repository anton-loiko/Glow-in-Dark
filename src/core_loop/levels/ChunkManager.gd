extends Node2D
class_name ChunkManager

@export var chunk_scenes: Array[PackedScene] = []
@export var exit_scene: PackedScene = preload("res://src/core_loop/entities/exit/Exit.tscn")

var player: Node2D
var spawned_chunks: Array[Node2D] = []
var next_spawn_y: float = 480.0 # Начальная точка спавна
var chunks_spawned: int = 0
var is_finished: bool = false
var chunks_to_win: int = 0

func _ready() -> void:
	# Берем настройки из глобального менеджера
	chunks_to_win = GameManager.get_chunks_to_win()
	
	_find_player()
	
	# Спавним первые чанки заранее
	for i in range(3): 
		_spawn_random_chunk()

func _find_player() -> void:
	player = get_tree().get_first_node_in_group("Player")
	if not player:
		player = get_parent().find_child("Player", true, false)

func _process(_delta: float) -> void:
	if not player or is_finished:
		return
		
	# Если игрок приблизился к краю последнего чанка — спавним новый
	# Используем высоту чанка из GameManager
	if player.global_position.y < next_spawn_y + (GameManager.CHUNK_SIZE_Y * 1.5):
		_spawn_random_chunk()
		_clear_old_chunks()

func _spawn_random_chunk() -> void:
	if chunk_scenes.is_empty() or is_finished:
		return
		
	if chunks_spawned >= chunks_to_win:
		_spawn_exit()
		return
	
	var random_index: int = randi() % chunk_scenes.size()
	var chunk_instance: Node2D = chunk_scenes[random_index].instantiate() as Node2D
	
	# Позиционируем чанк ровно над предыдущим
	chunk_instance.global_position = Vector2(0, next_spawn_y - GameManager.CHUNK_SIZE_Y)
	add_child(chunk_instance)
	spawned_chunks.append(chunk_instance)
	
	next_spawn_y -= GameManager.CHUNK_SIZE_Y
	chunks_spawned += 1

func _spawn_exit() -> void:
	is_finished = true
	if exit_scene:
		var exit_instance: Node2D = exit_scene.instantiate() as Node2D
		# Ставим выход в верхней части последнего чанка
		exit_instance.global_position = Vector2(135, next_spawn_y + 100.0)
		add_child(exit_instance)

func _clear_old_chunks() -> void:
	# Удаляем чанки, которые остались далеко внизу (больше 4-х штук назад)
	if spawned_chunks.size() > 4:
		var old_chunk: Node2D = spawned_chunks[0]
		if old_chunk.global_position.y > player.global_position.y + GameManager.CHUNK_SIZE_Y:
			spawned_chunks.pop_front()
			old_chunk.queue_free()
