class_name AdsBackend
extends RefCounted
## Интерфейс рекламного бэкенда: AppodealBackend (своя обёртка над Appodeal SDK, D17) или MockAdsBackend.

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


## Форма настроек конфиденциальности (GDPR) — кнопка в S13, если требуется.
func show_privacy_options() -> void:
	pass


func privacy_options_required() -> bool:
	return false
