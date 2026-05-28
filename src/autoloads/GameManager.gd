extends Node

const SAVE_PATH: String = "user://save_data.cfg"

signal sparks_changed(new_amount: int)
var sparks: int = 0

const SKINS_DB: Dictionary = {
	"default": {
		"color": Color(1.0, 1.0, 1.0),
		"price_usd": 0.0,
		"price_sparks": 0,
		"condition": "start"
	},
	"blue_flame": {
		"color": Color(0.3, 0.6, 1.0),
		"price_usd": 1.99,
		"price_sparks": 0,
		"condition": "store_usd" 
	},
	"purple_magic": {
		"color": Color(0.8, 0.2, 1.0), 
		"price_usd": 0.0,
		"price_sparks": 150,
		"condition": "store_sparks" 
	}
}

var has_no_ads: bool = false
var current_level: int = 1
var unlocked_level: int = 1
var owned_skins: Array = ["default"]
var equipped_skin: String = "default"

func _ready() -> void:
	load_game()

func save_game() -> void:
	var config = ConfigFile.new()
	
	config.set_value("progress", "unlocked_level", unlocked_level)
	config.set_value("purchases", "has_no_ads", has_no_ads)
	
	config.set_value("inventory", "owned_skins", owned_skins)
	config.set_value("inventory", "equipped_skin", equipped_skin)
	config.set_value("inventory", "sparks", sparks)
	
	var error = config.save(SAVE_PATH)
	if error != OK:
		print(error)

func load_game() -> void:
	var config = ConfigFile.new()
	var error = config.load(SAVE_PATH)
	
	if error != OK:
		save_game() 
		return
		
	unlocked_level = config.get_value("progress", "unlocked_level", 1)
	has_no_ads = config.get_value("purchases", "has_no_ads", false)
	owned_skins = config.get_value("inventory", "owned_skins", ["default"])
	equipped_skin = config.get_value("inventory", "equipped_skin", "default")
	sparks = config.get_value("inventory", "sparks", 0)

func complete_level():
	current_level += 1
	if current_level > unlocked_level:
		unlocked_level = current_level
		save_game()
		CloudManager.save_to_cloud()

func next_level() -> void:
	# current_level уже увеличен в complete_level()
	load_level(current_level) 

func load_level(level_number: int) -> void:
	current_level = level_number
	
	if is_level_exists(level_number):
		# Загружаем главную сцену. Она сама прочитает current_level и вставит нужный лабиринт
		get_tree().change_scene_to_file("res://src/levels/LevelRoot.tscn")
	else:
		go_to_main_menu()



func is_level_exists(level_number: int) -> bool:
	var level_path = "res://src/levels/Level_" + str(level_number) + ".tscn"
	return ResourceLoader.exists(level_path)

func go_to_main_menu() -> void:
	get_tree().change_scene_to_file("res://src/ui/main_menu/MainMenu.tscn")

func get_equipped_skin_color() -> Color:
	if SKINS_DB.has(equipped_skin):
		return SKINS_DB[equipped_skin]["color"]
	return SKINS_DB["default"]["color"]

func add_sparks(amount: int) -> void:
	sparks += amount
	sparks_changed.emit(sparks)
	save_game()
