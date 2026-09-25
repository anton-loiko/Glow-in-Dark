class_name StoreBackend
extends RefCounted
## Интерфейс платёжного бэкенда (D16): Google Play Billing (Android), StoreKit 2 через GodotApplePlugins (iOS),
## Mock — редактор и тесты. Бэкенд только сообщает факты; выдачу делает StoreManager.

## Цены загружены: { sku: "локализованная цена" }.
@warning_ignore("unused_signal")
signal products_updated(prices: Dictionary)
## Покупка подтверждена магазином; transaction_id — для идемпотентной выдачи.
@warning_ignore("unused_signal")
signal purchase_succeeded(sku: String, transaction_id: String)
@warning_ignore("unused_signal")
signal purchase_failed(sku: String, reason: String)
## Оплата отложена (Play: PENDING — наличные, семейное одобрение); выдача придёт позже через purchase_succeeded.
@warning_ignore("unused_signal")
signal purchase_pending(sku: String)
@warning_ignore("unused_signal")
signal purchase_restored(sku: String, transaction_id: String)


## Подключение к стору и запрос цен. Незавершённые транзакции прошлых сессий приходят через purchase_succeeded.
func initialize(_skus: Array[String]) -> void:
	pass


func is_available() -> bool:
	return false


func purchase(_sku: String) -> void:
	pass


## Сообщить магазину, что награда выдана: consume (расходуемые) / acknowledge / finish transaction.
func finish(_transaction_id: String, _consumable: bool) -> void:
	pass


func restore() -> void:
	pass


## Локализованная цена из стора; пустая строка, если неизвестна.
func get_price_label(_sku: String) -> String:
	return ""
