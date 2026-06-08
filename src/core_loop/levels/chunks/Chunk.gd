extends Node2D
class_name Chunk

@export var spawn_points: Array[Marker2D] = []
@export var fuel_scene: PackedScene = preload("res://src/core_loop/entities/interactables/fuel/Fuel.tscn")
@export var spark_scene: PackedScene = preload("res://src/core_loop/entities/interactables/spark/Spark.tscn")
@export var enemy_scene: PackedScene = preload("res://src/core_loop/entities/enemies/shadow_enemy/ShadowEnemy.tscn")

func _ready() -> void:
	_populate_chunk()

func _populate_chunk() -> void:
	for point in spawn_points:
		var r: float = randf()
		
		# Спавн врага (наивысший приоритет, иначе будет легко)
		if r <= GameManager.get_enemy_spawn_chance() and enemy_scene:
			_spawn_entity(enemy_scene, point.position)
			continue
			
		r = randf()
		# Спавн топлива
		if r <= GameManager.get_fuel_spawn_chance() and fuel_scene:
			_spawn_entity(fuel_scene, point.position)
			continue
			
		r = randf()
		# Спавн искры
		if r <= GameManager.get_spark_spawn_chance() and spark_scene:
			_spawn_entity(spark_scene, point.position)

func _spawn_entity(scene: PackedScene, local_pos: Vector2) -> void:
	var entity: Node2D = scene.instantiate() as Node2D
	entity.position = local_pos
	add_child(entity)
