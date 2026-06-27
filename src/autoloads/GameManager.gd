extends Node

const SAVE_PATH: String = "user://save_data.cfg"

var sparks: int = 0
var active_skills: Dictionary = {}

var current_level: int = 1
var unlocked_level: int = 1

var owned_skins: Array = ["default"]
var equipped_skin: String = "default"
var has_no_ads: bool = false

var sound_enabled: bool = true
var music_enabled: bool = true
var vibration_enabled: bool = true

func _ready() -> void:
	load_game()
	if Engine.has_singleton("CloudManager"):
		CloudManager.authenticate_player()
	current_level = unlocked_level

func save_game() -> void:
	var config = ConfigFile.new()
	
	config.set_value("progress", "unlocked_level", unlocked_level)
	config.set_value("purchases", "has_no_ads", has_no_ads)
	
	config.set_value("inventory", "owned_skins", owned_skins)
	config.set_value("inventory", "equipped_skin", equipped_skin)
	config.set_value("inventory", "sparks", sparks)
	
	config.set_value("settings", "sound_enabled", sound_enabled)
	config.set_value("settings", "music_enabled", music_enabled)
	config.set_value("settings", "vibration_enabled", vibration_enabled)
	
	var error = config.save(SAVE_PATH)
	if error != OK:
		print("The game could not be saved. Error code: ", error)

func load_game() -> void:
	var config = ConfigFile.new()
	var error = config.load(SAVE_PATH)
	
	if error != OK:
		print("Локальный файл не найден. Создаем базовый профиль на телефоне...")
		save_game() 
		return
		
	unlocked_level = config.get_value("progress", "unlocked_level", 1)
	has_no_ads = config.get_value("purchases", "has_no_ads", false)
	owned_skins = config.get_value("inventory", "owned_skins", ["default"])
	equipped_skin = config.get_value("inventory", "equipped_skin", "default")
	sparks = config.get_value("inventory", "sparks", 0)
	
	sound_enabled = config.get_value("settings", "sound_enabled", true)
	music_enabled = config.get_value("settings", "music_enabled", true)
	vibration_enabled = config.get_value("settings", "vibration_enabled", true)

func complete_level():
	current_level += 1
	if current_level > unlocked_level:
		unlocked_level = current_level
		save_game()
		if Engine.has_singleton("CloudManager"):
			CloudManager.save_to_cloud()

func next_level() -> void:
	load_level(current_level) 

func load_level(level_number: int) -> void:
	current_level = level_number
	reset_run_state()
	get_tree().change_scene_to_file("res://src/core_loop/levels/LevelRoot.tscn")

func reset_run_state() -> void:
	#active_skills.clear()
	# TODO: move to special Level_state manager.s
	active_skills = {}

func is_level_exists(_level_number: int) -> bool:
	return true

func go_to_main_menu() -> void:
	get_tree().change_scene_to_file("res://src/ui/main_menu/MainMenu.tscn")

func get_equipped_skin_color() -> Color:
	if StoreManager.SKINS_DB.has(equipped_skin):
		return StoreManager.SKINS_DB[equipped_skin]["color"]
	return StoreManager.SKINS_DB["default"]["color"]

func add_sparks(amount: int) -> void:
	sparks += amount
	EventBus.sparks_changed.emit(sparks)
	
	save_game()

func withdraw_sparks(amount: int) -> void:
	sparks -= amount
	EventBus.sparks_changed.emit(sparks)
	
	save_game()

func apply_skill(skill_id: String) -> void:
	EventBus.skill_applied.emit(skill_id)
	
	if  active_skills.has(skill_id):
		var cur = active_skills[skill_id]
		cur.count += 1
		active_skills[skill_id] = cur
	else:
		active_skills[skill_id] = {
			"count": 1,
		}

func reset_progress() -> void:
	unlocked_level = 1
	current_level = 1
	sparks = 0
	save_game()
	if Engine.has_singleton("CloudManager"):
		CloudManager.save_to_cloud()
