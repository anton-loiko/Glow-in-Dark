class_name GameServicesBackend
extends RefCounted
## Интерфейс гейм-центра: Game Center (GodotApplePlugins) / Play Games (godot-play-game-services) — task_7, D13, D16.

signal sign_in_finished(success: bool)


func sign_in_silently() -> void:
	sign_in_finished.emit(false)


func is_signed_in() -> bool:
	return false


func get_player_id() -> String:
	return ""


func get_display_name() -> String:
	return ""


## Данные для привязки к Firebase (подпись Game Center / server auth code Play Games).
func get_auth_credential() -> Dictionary:
	return {}
