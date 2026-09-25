class_name AppStoreBackend
extends StoreBackend
## StoreKit 2 через GodotApplePlugins (D16, iOS 17+). Классы GDExtension берутся через ClassDB,
## чтобы код компилировался без аддона. transaction_id = StoreTransaction.transactionId.
## start() сам поднимает незавершённые транзакции (включая расходуемые, купленные вне приложения).
## Восстановление: AppStore.sync() → текущие права (только нерасходуемые) приходят как purchase_restored.

const STORE_CLASS: StringName = &"StoreKitManager"
const STATUS_OK: int = 0
const STATUS_USER_CANCELLED: int = 4
const STATUS_PENDING: int = 5
const RESTORE_WINDOW_MS: int = 10000

var _manager: Object
var _products: Dictionary = {} ## sku -> StoreProduct
var _prices: Dictionary = {}
var _open: Dictionary = {} ## transaction_id -> StoreTransaction (до finish)
var _restore_until_ms: int = 0
var _pending_purchase_sku: String = ""


func initialize(skus: Array[String]) -> void:
	if not ClassDB.class_exists(STORE_CLASS):
		return
	_manager = ClassDB.instantiate(STORE_CLASS)
	_manager.connect(&"products_request_completed", _on_products)
	_manager.connect(&"purchase_completed", _on_purchase_completed)
	_manager.connect(&"transaction_updated", _on_transaction_updated)
	_manager.connect(&"restore_completed", _on_restore_completed)
	_manager.call(&"start")
	_manager.call(&"request_products", PackedStringArray(skus))


func is_available() -> bool:
	return _manager != null and not _products.is_empty()


func purchase(sku: String) -> void:
	var product: Object = _products.get(sku) as Object
	if _manager == null or product == null:
		purchase_failed.emit(sku, "product_unavailable")
		return
	_pending_purchase_sku = sku
	_manager.call(&"purchase", product)


func finish(transaction_id: String, _consumable: bool) -> void:
	var tx: Object = _open.get(transaction_id) as Object
	if tx != null:
		tx.call(&"finish")
		_open.erase(transaction_id)


func restore() -> void:
	if _manager == null:
		return
	_restore_until_ms = Time.get_ticks_msec() + RESTORE_WINDOW_MS
	_manager.call(&"restore_purchases")


func get_price_label(sku: String) -> String:
	return str(_prices.get(sku, ""))


func _on_products(products: Array, status: int) -> void:
	if status != STATUS_OK:
		return
	for product: Variant in products:
		var p: Object = product as Object
		if p == null:
			continue
		var sku: String = str(p.get(&"productId"))
		_products[sku] = p
		_prices[sku] = str(p.get(&"displayPrice"))
	products_updated.emit(_prices.duplicate())


func _on_purchase_completed(transaction: Object, status: int, message: String) -> void:
	var sku: String = _pending_purchase_sku
	_pending_purchase_sku = ""
	match status:
		STATUS_OK:
			if transaction != null:
				_deliver(transaction, false)
		STATUS_PENDING:
			purchase_pending.emit(sku)
		STATUS_USER_CANCELLED:
			purchase_failed.emit(sku, "cancelled")
		_:
			purchase_failed.emit(sku, "error_%d:%s" % [status, message])


func _on_transaction_updated(transaction: Object) -> void:
	if transaction != null:
		_deliver(transaction, Time.get_ticks_msec() < _restore_until_ms)


func _on_restore_completed(status: int, _message: String) -> void:
	if status == STATUS_OK:
		_manager.call(&"fetch_current_entitlements")
	else:
		_restore_until_ms = 0


func _deliver(transaction: Object, restoring: bool) -> void:
	var tx_id: String = str(transaction.get(&"transactionId"))
	var sku: String = str(transaction.get(&"productID"))
	_open[tx_id] = transaction
	if restoring:
		purchase_restored.emit(sku, tx_id)
	else:
		purchase_succeeded.emit(sku, tx_id)
