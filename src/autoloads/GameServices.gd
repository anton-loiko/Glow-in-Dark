extends Node
## Фасад нативных гейм-центров (D13). Отказ или ошибка входа не блокируют игру.

signal signed_in_changed(signed_in: bool)

var backend: GameServicesBackend = GameServicesBackend.new()


func _ready() -> void:
	set_process(false)
	backend.sign_in_finished.connect(_on_sign_in_finished)


func sign_in_silently() -> void:
	backend.sign_in_silently()


func is_signed_in() -> bool:
	return backend.is_signed_in()


func get_display_name() -> String:
	return backend.get_display_name()


func _on_sign_in_finished(success: bool) -> void:
	Telemetry.log_event(&"game_services_sign_in", {"platform": OS.get_name(), "result": success})
	signed_in_changed.emit(success)
