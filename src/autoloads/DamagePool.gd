extends Node

const POOL_SIZE: int = 40
var damage_number_scene: PackedScene = preload("res://src/core_loop/HUD/game_ui/DamageNumber.tscn")
var pool: Array[Node2D] = []
var world_container: Node = null

# Эту функцию нужно будет вызывать на _ready() в скрипте уровня (например, в LevelRoot.gd)
func init_pool(container: Node) -> void:
	world_container = container
	pool.clear()
	for i in range(POOL_SIZE):
		var number_instance = damage_number_scene.instantiate()
		world_container.add_child(number_instance)
		pool.append(number_instance)

func show_damage(amount: int, global_pos: Vector2, is_lethal: bool) -> void:
	if not world_container or not is_instance_valid(world_container):
		return
		
	for number in pool:
		if not number.visible:
			number.play(amount, global_pos, is_lethal)
			return
	
	var new_number = damage_number_scene.instantiate()
	world_container.add_child(new_number)
	pool.append(new_number)
	new_number.play(amount, global_pos, is_lethal)
