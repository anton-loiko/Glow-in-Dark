class_name TelemetryBackend
extends RefCounted
## Интерфейс бэкенда аналитики. Реализация Firebase Analytics — task_7 (godot-x/firebase, D16).


func log_event(_name: StringName, _params: Dictionary) -> void:
	pass


func set_user_property(_name: StringName, _value: String) -> void:
	pass
