class_name GameServicesBackend
extends RefCounted
## Интерфейс гейм-центра (D13, D16): Game Center через GodotApplePlugins, Play Games через godot-play-game-services 3.x.
## Базовая реализация — «не подключено» (редактор, десктоп). Вход никогда не блокирует игру.

@warning_ignore("unused_signal")
signal sign_in_finished(success: bool)
## Данные для входа в Firebase: {"provider": "gamecenter"|"playgames", ...} или {} при ошибке.
@warning_ignore("unused_signal")
signal auth_credential_ready(credential: Dictionary)


func platform() -> String:
	return "none"


func sign_in_silently() -> void:
	sign_in_finished.emit.call_deferred(false)


## Явный вход по кнопке «Подключить» в S13 (может показать системный UI).
func sign_in_interactive() -> void:
	sign_in_silently()


func is_signed_in() -> bool:
	return false


func get_player_id() -> String:
	return ""


func get_display_name() -> String:
	return ""


## Запросить подпись Game Center / server auth code Play Games → auth_credential_ready.
func request_auth_credential() -> void:
	auth_credential_ready.emit.call_deferred({})
