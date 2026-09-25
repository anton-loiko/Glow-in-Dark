class_name AdsBackend
extends RefCounted
## Интерфейс рекламного бэкенда. Реализация — своя обёртка над Appodeal SDK (task_7, D17).

@warning_ignore("unused_signal")
signal rewarded_finished(placement: StringName, rewarded: bool)
@warning_ignore("unused_signal")
signal rewarded_failed(placement: StringName, reason: String)


func initialize() -> void:
	pass


func is_rewarded_ready() -> bool:
	return false


func show_rewarded(_placement: StringName) -> void:
	pass
