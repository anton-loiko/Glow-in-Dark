class_name TelemetryBackend
extends RefCounted
## Интерфейс бэкенда аналитики: FirebaseAnalyticsBackend (godot-x/firebase, D16) или DebugTelemetryBackend.


func log_event(_name: StringName, _params: Dictionary) -> void:
	pass


func set_user_property(_name: StringName, _value: String) -> void:
	pass


## Согласие пользователя на сбор (GDPR / Consent Mode v2).
func set_consent(_granted: bool) -> void:
	pass
