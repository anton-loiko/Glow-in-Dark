extends Node
## Магазин: каталог (configs/shop.json), покупки через подменяемый бэкенд и выдача наград.
## Награды выдаются ТОЛЬКО в _grant(); результат покупки — только через EventBus.
## Выдача идемпотентна: transaction_id сохраняется в profile.receipts.

var backend: StoreBackend = MockStoreBackend.new()


func _ready() -> void:
	set_process(false)
	set_backend(backend)


func set_backend(new_backend: StoreBackend) -> void:
	if backend != null and backend.purchase_succeeded.is_connected(_on_purchase_succeeded):
		backend.purchase_succeeded.disconnect(_on_purchase_succeeded)
		backend.purchase_failed.disconnect(_on_purchase_failed)
		backend.purchase_restored.disconnect(_on_purchase_succeeded)
	backend = new_backend
	backend.purchase_succeeded.connect(_on_purchase_succeeded)
	backend.purchase_failed.connect(_on_purchase_failed)
	backend.purchase_restored.connect(_on_purchase_succeeded)


func get_products() -> Array[ShopProductDef]:
	return ConfigDB.get_products()


func purchase(product_id: StringName) -> void:
	var product: ShopProductDef = ConfigDB.get_product(product_id)
	if product == null:
		EventBus.purchase_failed.emit(product_id, "unknown_product")
		return
	if product.one_time and _is_owned(product):
		EventBus.purchase_failed.emit(product_id, "already_owned")
		return
	if product.is_real_money():
		Telemetry.log_event(&"iap_started", {"product_id": String(product_id)})
		backend.purchase(product.store_sku)
		return
	# Внутриигровая цена (Искры / Кристаллы).
	for currency: String in product.price:
		if not GameManager.spend(StringName(currency), int(product.price[currency]), StringName("shop_" + product_id)):
			EventBus.purchase_failed.emit(product_id, "not_enough_" + currency)
			return
	_grant(product)
	EventBus.purchase_completed.emit(product_id)


func restore_purchases() -> void:
	backend.restore()


func _on_purchase_succeeded(sku: String, transaction_id: String) -> void:
	var product: ShopProductDef = _product_by_sku(sku)
	if product == null:
		push_error("[StoreManager] unknown sku '%s'" % sku)
		return
	var profile: PlayerProfile = GameManager.profile
	if profile.receipts.has(transaction_id) or (product.one_time and _is_owned(product)):
		backend.finish(transaction_id)
		return
	profile.receipts.append(transaction_id)
	_grant(product)
	SaveManager.flush(true)
	backend.finish(transaction_id)
	Telemetry.log_event(&"iap_completed", {"product_id": String(product.id)})
	EventBus.purchase_completed.emit(product.id)


func _on_purchase_failed(sku: String, reason: String) -> void:
	var product: ShopProductDef = _product_by_sku(sku)
	var product_id: StringName = product.id if product != null else StringName(sku)
	Telemetry.log_event(&"iap_failed", {"product_id": String(product_id), "reason": reason})
	EventBus.purchase_failed.emit(product_id, reason)


## Единственная точка выдачи наград покупки.
func _grant(product: ShopProductDef) -> void:
	var profile: PlayerProfile = GameManager.profile
	var reason: StringName = StringName("shop_" + product.id)
	for key: String in product.grants:
		var value: Variant = product.grants[key]
		match key:
			"crystals":
				GameManager.grant(GameManager.CRYSTALS, int(value), reason)
			"sparks":
				GameManager.grant(GameManager.SPARKS, int(value), reason)
			"skin":
				var skin_id: StringName = StringName(str(value))
				if not profile.skins_unlocked.has(skin_id):
					profile.skins_unlocked.append(skin_id)
					profile.skins_new_badge.append(skin_id)
					EventBus.skin_unlocked.emit(skin_id)
			"chest", "count":
				pass # Открытие сундуков — ChestService (task_6).
			_:
				push_warning("[StoreManager] unknown grant '%s'" % key)
	if product.id == &"starter_pack":
		profile.starter_pack_bought = true


func _is_owned(product: ShopProductDef) -> bool:
	return product.id == &"starter_pack" and GameManager.profile.starter_pack_bought


func _product_by_sku(sku: String) -> ShopProductDef:
	for product: ShopProductDef in ConfigDB.get_products():
		if product.store_sku == sku:
			return product
	return null
