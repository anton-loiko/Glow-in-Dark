class_name GooglePlayBillingBackend
extends StoreBackend
## Google Play Billing через godot-google-play-billing 3.x (D16). Работаем с JNI-синглтоном плагина напрямую,
## чтобы код компилировался и без установленного аддона. transaction_id = purchase_token.
## Старт: connect → query_product_details (цены) → query_purchases (незавершённые покупки прошлых сессий).
## Расходуемые → consumePurchase, стартер-пак → acknowledgePurchase (без него Play вернёт деньги через 3 дня).

const SINGLETON: String = "GodotGooglePlayBilling"
const RESPONSE_OK: int = 0
const RESPONSE_USER_CANCELED: int = 1
const RESPONSE_ALREADY_OWNED: int = 7
const STATE_PURCHASED: int = 1
const STATE_PENDING: int = 2

var _plugin: Object
var _skus: Array[String] = []
var _prices: Dictionary = {}
var _restoring: bool = false
var _pending_purchase_sku: String = ""


func initialize(skus: Array[String]) -> void:
	_skus = skus
	if not Engine.has_singleton(SINGLETON):
		return
	_plugin = Engine.get_singleton(SINGLETON)
	_plugin.call(&"initPlugin")
	_plugin.connect(&"connected", _on_connected)
	_plugin.connect(&"connect_error", _on_connect_error)
	_plugin.connect(&"query_product_details_response", _on_product_details)
	_plugin.connect(&"query_purchases_response", _on_purchases)
	_plugin.connect(&"on_purchase_updated", _on_purchase_updated)
	_plugin.call(&"startConnection")


func is_available() -> bool:
	return _plugin != null and bool(_plugin.call(&"isReady"))


func purchase(sku: String) -> void:
	if not is_available():
		purchase_failed.emit(sku, "billing_unavailable")
		return
	_pending_purchase_sku = sku
	var result: Dictionary = _plugin.call(&"purchase", sku, "", "", false) as Dictionary
	var code: int = int(result.get("response_code", -1))
	if code != RESPONSE_OK:
		_pending_purchase_sku = ""
		purchase_failed.emit(sku, _reason(code, str(result.get("debug_message", ""))))


func finish(transaction_id: String, consumable: bool) -> void:
	if _plugin == null:
		return
	_plugin.call(&"consumePurchase" if consumable else &"acknowledgePurchase", transaction_id)


func restore() -> void:
	if _plugin == null:
		return
	_restoring = true
	_plugin.call(&"queryPurchases", "inapp", false)


func get_price_label(sku: String) -> String:
	return str(_prices.get(sku, ""))


func _on_connected() -> void:
	_plugin.call(&"queryProductDetails", PackedStringArray(_skus), "inapp")
	_plugin.call(&"queryPurchases", "inapp", false)


func _on_connect_error(code: int, message: String) -> void:
	push_warning("[Billing] connect error %d: %s" % [code, message])


func _on_product_details(response: Dictionary) -> void:
	if int(response.get("response_code", -1)) != RESPONSE_OK:
		return
	for details: Variant in response.get("product_details", []):
		var d: Dictionary = details as Dictionary
		var offers: Variant = d.get("one_time_purchase_offer_details_list")
		if offers is Array and not (offers as Array).is_empty():
			_prices[str(d.get("product_id", ""))] = str(((offers as Array)[0] as Dictionary).get("formatted_price", ""))
	products_updated.emit(_prices.duplicate())


func _on_purchases(response: Dictionary) -> void:
	if int(response.get("response_code", -1)) != RESPONSE_OK:
		_restoring = false
		return
	for purchase_data: Variant in response.get("purchases", []):
		_process(purchase_data as Dictionary, _restoring)
	_restoring = false


func _on_purchase_updated(response: Dictionary) -> void:
	var code: int = int(response.get("response_code", -1))
	if code != RESPONSE_OK:
		if not _pending_purchase_sku.is_empty():
			purchase_failed.emit(_pending_purchase_sku, _reason(code, str(response.get("debug_message", ""))))
		_pending_purchase_sku = ""
		return
	_pending_purchase_sku = ""
	for purchase_data: Variant in response.get("purchases", []):
		_process(purchase_data as Dictionary, false)


func _process(data: Dictionary, restoring: bool) -> void:
	var skus: Array = data.get("product_ids", [])
	if skus.is_empty():
		return
	var sku: String = str(skus[0])
	var token: String = str(data.get("purchase_token", ""))
	match int(data.get("purchase_state", 0)):
		STATE_PURCHASED:
			# Уже подтверждённая нерасходуемая покупка приходит только при восстановлении.
			if restoring or bool(data.get("is_acknowledged", false)):
				purchase_restored.emit(sku, token)
			else:
				purchase_succeeded.emit(sku, token)
		STATE_PENDING:
			purchase_pending.emit(sku)


func _reason(code: int, message: String) -> String:
	match code:
		RESPONSE_USER_CANCELED:
			return "cancelled"
		RESPONSE_ALREADY_OWNED:
			return "already_owned"
	return "error_%d:%s" % [code, message]
