extends Control

@onready var level_container: Node2D = %LevelContainer
@onready var ui: CanvasLayer = %UI 

func _ready() -> void:
	# Всегда загружаем Level_1 как универсальный шаблон для генерации
	var level_path = "res://src/core_loop/levels/Level_1.tscn"
	
	if ResourceLoader.exists(level_path):
		var level_resource = load(level_path)
		var level_instance = level_resource.instantiate()
		
		level_container.add_child(level_instance)
		
		var player = level_instance.find_child("Player", true, false)
		var ui_control = ui.get_node("%UIControl")
		
		if player and ui_control:
			if ui_control.has_method("_on_player_light_changed"):
				player.light_changed.connect(ui_control._on_player_light_changed)
			if ui_control.has_method("show_game_over"):
				player.died.connect(ui_control.show_game_over)
			
		_setup_camera_limits(level_instance, player)
	else:
		print("[ERROR]:::: Level Template not found")
		GameManager.go_to_main_menu()

func _setup_camera_limits(level: Node, player: Node) -> void:
	if not player or not player.has_node("Camera2D"):
		return
		
	var camera: Camera2D = player.get_node("Camera2D")
	var map_rect := Rect2i()
	var tile_size := Vector2i.ZERO
	var found_map := false
	
	for child in level.get_children():
		if child is TileMapLayer:
			var r = child.get_used_rect()
			if not found_map:
				map_rect = r
				tile_size = child.tile_set.tile_size
				found_map = true
			else:
				map_rect = map_rect.merge(r)
				
	if found_map:
		camera.limit_left = map_rect.position.x * tile_size.x
		camera.limit_right = map_rect.end.x * tile_size.x
		camera.limit_top = -20000000 
		camera.limit_bottom = map_rect.end.y * tile_size.y
	else:
		camera.limit_left = 0
		camera.limit_right = 270 
		camera.limit_top = -20000000 
		camera.limit_bottom = 480
