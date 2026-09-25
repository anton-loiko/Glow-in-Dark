class_name LegacySaveMigration
extends RefCounted
## Миграция v0 → v1: чтение сейва MVP (user://save_data.cfg, ConfigFile) в PlayerProfile.
## has_no_ads игнорируется (D15, реальных покупок в MVP не было), уровни MVP не переносятся —
## в V1 их заменили главы.

## Скины MVP → Огоньки V1. Не перенесённые скины компенсируются Кристаллами.
const SKIN_MAP: Dictionary = {
	"default": &"base",
	"pink_flame": &"pink",
}
const COMPENSATION_CRYSTALS_PER_SKIN: int = 100


static func migrate(config: ConfigFile) -> PlayerProfile:
	var p: PlayerProfile = PlayerProfile.create_new()
	p.sparks = maxi(0, int(config.get_value("inventory", "sparks", 0)))

	var owned: Variant = config.get_value("inventory", "owned_skins", ["default"])
	if owned is Array:
		for legacy_id: Variant in owned:
			var key: String = str(legacy_id)
			if SKIN_MAP.has(key):
				var new_id: StringName = SKIN_MAP[key]
				if not p.skins_unlocked.has(new_id):
					p.skins_unlocked.append(new_id)
			else:
				p.crystals += COMPENSATION_CRYSTALS_PER_SKIN

	var equipped: String = str(config.get_value("inventory", "equipped_skin", "default"))
	p.skin_equipped = SKIN_MAP.get(equipped, &"base")

	p.settings.sfx = bool(config.get_value("settings", "sound_enabled", true))
	p.settings.music = bool(config.get_value("settings", "music_enabled", true))
	p.settings.vibration = bool(config.get_value("settings", "vibration_enabled", true))
	return p
