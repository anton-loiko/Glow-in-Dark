extends Node

# --- Настройки навыков ---
const SKILL_CHOICE_TRIGGERED_TRASHHOLD  = 2 # 15
const SKILL_MAGNET_RADIUS: float = 120.0
const SKILL_MAGNET_SPEED: float = 200.0
const SKILL_SHADOW_BURN_MULT: float = 2.5
const SKILL_SHIELD_DAMAGE_REDUCTION: float = 0.5 # Снижение урона на 50%
# ------------------------------

# --- Roguelike База Навыков ---
var SKILLS_DB: Dictionary = {
	"magnet": {
		"title": "+"+ str(SKILL_MAGNET_RADIUS) + " MAGNET RADIUS",
		"icon": "res://src/assets/images/skills/skill_magnet.png",
		"bg_color": Color(0.281, 0.353, 0.676, 0.75), # Синий (Утилиты)
		"price_sparks": 1,
		"max": 1,
	},
	"light_shield": {
		"title": "+"+str(SKILL_SHIELD_DAMAGE_REDUCTION)+" REDUCTION",
		"icon": "res://src/assets/images/skills/skill_shield.png",
		"bg_color": Color(0.957, 0.773, 0.031, 0.749), # Желтый (Свет/Защита)
		"price_sparks": 1,
		"max": -1,
	},
	"shadow_burn": {
		"title": "+"+ str(SKILL_SHADOW_BURN_MULT)+" BURN",
		"icon": "res://src/assets/images/skills/skill_fire.png",
		"bg_color": Color(0.605, 0.049, 0.057, 0.75),
		"price_sparks": 1,
		"max": 2,
	}
}
