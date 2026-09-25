class_name MockStoreBackend
extends StoreBackend
## Бэкенд для редактора и тестов: исход покупки задаётся next_outcome.

enum Outcome { SUCCESS, CANCEL, ERROR }

var next_outcome: Outcome = Outcome.SUCCESS
var delay_s: float = 0.0
var owned_skus: Array[String] = []
var _counter: int = 0


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


func restore() -> void:
	for sku: String in owned_skus:
		purchase_restored.emit(sku, "mock-restore-%s" % sku)


func get_price_label(_sku: String) -> String:
	return "$0.99"
