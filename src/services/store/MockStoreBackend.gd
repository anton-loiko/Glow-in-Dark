class_name MockStoreBackend
extends StoreBackend
## Бэкенд для редактора и тестов: исход покупки задаётся next_outcome.

enum Outcome { SUCCESS, CANCEL, ERROR, PENDING }

const MOCK_PRICES: Dictionary = {"starter_pack": "$0.99", "crystals_80": "$0.99", "crystals_280": "$2.99", "crystals_550": "$4.99", "crystals_2600": "$19.99"}

var next_outcome: Outcome = Outcome.SUCCESS
var delay_s: float = 0.0
var owned_skus: Array[String] = []
var finished: Array[String] = []
var _counter: int = 0
var _prices: Dictionary = {}


func initialize(skus: Array[String]) -> void:
	for sku: String in skus:
		for key: String in MOCK_PRICES:
			if sku.ends_with(key):
				_prices[sku] = MOCK_PRICES[key]
	products_updated.emit(_prices.duplicate())


func is_available() -> bool:
	return true


func purchase(sku: String) -> void:
	if delay_s > 0.0:
		var tree: SceneTree = Engine.get_main_loop() as SceneTree
		await tree.create_timer(delay_s, true, false, true).timeout
	match next_outcome:
		Outcome.SUCCESS:
			_counter += 1
			owned_skus.append(sku)
			purchase_succeeded.emit(sku, "mock-%d-%d" % [Time.get_ticks_usec(), _counter])
		Outcome.CANCEL:
			purchase_failed.emit(sku, "cancelled")
		Outcome.ERROR:
			purchase_failed.emit(sku, "error")
		Outcome.PENDING:
			purchase_pending.emit(sku)


func finish(transaction_id: String, _consumable: bool) -> void:
	finished.append(transaction_id)


func restore() -> void:
	for sku: String in owned_skus:
		purchase_restored.emit(sku, "mock-restore-%s" % sku)


func get_price_label(sku: String) -> String:
	return str(_prices.get(sku, "$0.99"))
