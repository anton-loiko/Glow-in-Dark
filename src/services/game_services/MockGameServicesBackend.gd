class_name MockGameServicesBackend
extends GameServicesBackend
## Гейм-центр для тестов: исход входа задаётся succeed.

var succeed: bool = true
var player_id: String = "mock-player"
var display_name: String = "Огонёк"
var _signed_in: bool = false


func platform() -> String:
	return "mock"


func sign_in_silently() -> void:
	_signed_in = succeed
	sign_in_finished.emit(succeed)


func is_signed_in() -> bool:
	return _signed_in


func get_player_id() -> String:
	return player_id if _signed_in else ""


func get_display_name() -> String:
	return display_name if _signed_in else ""


func request_auth_credential() -> void:
	auth_credential_ready.emit({"provider": "mock", "player_id": player_id} if _signed_in else {})
