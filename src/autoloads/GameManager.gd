extends Node

# --- Параметры баланса игры ---
const BASE_CHUNKS_TO_WIN: int = 5
const CHUNKS_PER_LEVEL_STEP: int = 2
const CHUNK_SIZE_Y: float = 480.0

const BASE_FUEL_CHANCE: float = 0.15
const BASE_SPARK_CHANCE: float = 0.65  # Увеличено с 0.3 (теперь 65% шанс спавна на точке)
const BASE_ENEMY_CHANCE: float = 0.4  # Увеличено с 0.1 (теперь 40% шанс спавна на точке)

# --- Настройки навыков ---
const SKILL_CHOICE_TRIGGERED_TRASHHOLD  = 1 # 15
const SKILL_MAGNET_RADIUS: float = 120.0
const SKILL_MAGNET_SPEED: float = 200.0
const SKILL_SHADOW_BURN_MULT: float = 2.5
const SKILL_SHIELD_DAMAGE_REDUCTION: float = 0.5 # Снижение урона на 50%
# ------------------------------

func get_chunks_to_win() -> int:
	return BASE_CHUNKS_TO_WIN + (current_level * CHUNKS_PER_LEVEL_STEP)

func get_enemy_spawn_chance() -> float:
	# Шанс врагов растет на 4% с каждым уровнем (максимум 85%)
	return min(BASE_ENEMY_CHANCE + (current_level * 0.04), 0.85)

func get_fuel_spawn_chance() -> float:
	# Шанс топлива падает с ростом уровня (минимум 5%)
	return max(BASE_FUEL_CHANCE - (current_level * 0.005), 0.05)

func get_spark_spawn_chance() -> float:
	return BASE_SPARK_CHANCE
# ------------------------------

# --- Roguelike База Навыков ---
var SKILLS_DB: Dictionary = {
	"magnet": {
		"title": "+"+ str(SKILL_MAGNET_RADIUS) + " MAGNET RADIUS",
		"icon": "res://src/assets/images/skills/skill_magnet.png", 
		"bg_color": Color(0.281, 0.353, 0.676, 0.75), # Синий (Утилиты)
		"price_sparks": 1,
	},
	"light_shield": {
		"title": "+"+str(SKILL_SHIELD_DAMAGE_REDUCTION)+" REDUCTION",
		"icon": "res://src/assets/images/skills/skill_shield.png",
		"bg_color": Color(0.957, 0.773, 0.031, 0.749), # Желтый (Свет/Защита)
		"price_sparks": 1,
	},
	"shadow_burn": {
		"title": "+"+ str(SKILL_SHADOW_BURN_MULT)+" BURN",
		"icon": "res://src/assets/images/skills/skill_fire.png",
		"bg_color": Color(0.605, 0.049, 0.057, 0.75),
		"price_sparks": 1,
	}
}

signal sparks_picked_up(amount: int)
signal sparks_changed(new_amount: int)
signal skill_choice_triggered
signal skill_applied(skill_id: String)

var sparks: int = 0
var active_skills: Array[String] = [] 
# ------------------------------

const SAVE_PATH: String = "user://save_data.cfg"

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
	active_skills.clear()

func is_level_exists(_level_number: int) -> bool:
	return true

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

func withdraw_sparks(amount: int) -> void:
	sparks -= amount
	sparks_changed.emit(sparks)
	
	save_game()

func apply_skill(skill_id: String) -> void:
	skill_applied.emit(skill_id)
	
	if not active_skills.has(skill_id):
		active_skills.append(skill_id)

func reset_progress() -> void:
	unlocked_level = 1
	current_level = 1
	sparks = 0
	save_game()
	if Engine.has_singleton("CloudManager"):
		CloudManager.save_to_cloud()
