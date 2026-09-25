class_name StoreBackend
extends RefCounted
## Интерфейс платёжного бэкенда. Реализации: Google Play Billing, StoreKit 2 (task_7, D16).

## Покупка подтверждена магазином; transaction_id — для идемпотентной выдачи.
@warning_ignore("unused_signal")
signal purchase_succeeded(sku: String, transaction_id: String)
@warning_ignore("unused_signal")
signal purchase_failed(sku: String, reason: String)
@warning_ignore("unused_signal")
signal purchase_restored(sku: String, transaction_id: String)


func is_available() -> bool:
	return false


func purchase(_sku: String) -> void:
	pass


## Сообщить магазину, что награда выдана (acknowledge / finish transaction).
func finish(_transaction_id: String) -> void:
	pass


func restore() -> void:
	pass


## Локализованная цена из стора; пустая строка, если неизвестна.
func get_price_label(_sku: String) -> String:
	return ""
