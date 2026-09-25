extends Node
## Магазин: каталог (configs/shop.json), покупки через подменяемый бэкенд и выдача наград.
## Награды выдаются ТОЛЬКО в _grant(); результат покупки — только через EventBus.
## Поток: стор подтвердил → выдача + чек в profile.receipts + критическая запись + облако → finish() в стор.
## Выдача идемпотентна по transaction_id; повторная доставка и незавершённые транзакции прошлых сессий безопасны.
## «Восстановить покупки» возвращает только нерасходуемое (скин стартер-пака), без Кристаллов.

const FREE_GIFT_PLACEMENTS: Array[StringName] = [&"shop_free_gift", &"hub_sparks"]
## Расходуемые гранты: при восстановлении не выдаются повторно.
const CONSUMABLE_GRANTS: Array[String] = ["crystals", "sparks", "chest", "count"]

var backend: StoreBackend
var _prices: Dictionary = {}


func _ready() -> void:
	set_process(false)
	set_backend(_default_backend())
	EventBus.ad_reward_granted.connect(_on_ad_reward)


## Бесплатный дар ▶ (300 Искр раз в 8 ч; общий для Магазина и хаба — лимит ведёт AdManager).
func free_gift_ready() -> bool:
	return AdManager.remaining(&"shop_free_gift") > 0


func free_gift_seconds_left() -> int:
	return AdManager.seconds_until_available(&"shop_free_gift")


## Лимит уже списан AdManager до этого сигнала — здесь только выдача.
func _on_ad_reward(placement: StringName) -> void:
	if not FREE_GIFT_PLACEMENTS.has(placement):
		return
	var grants: Dictionary = AdManager.placement_cfg(&"shop_free_gift").get("grants", {"sparks": 300}) as Dictionary
	var amount: int = int(grants.get("sparks", 300))
	GameManager.grant(GameManager.SPARKS, amount, &"ad_gift")
	EventBus.toast_requested.emit(tr("+%d Искр") % amount, &"sparks")


func set_backend(new_backend: StoreBackend) -> void:
	if backend != null and backend.purchase_succeeded.is_connected(_on_purchase_succeeded):
		backend.products_updated.disconnect(_on_products_updated)
		backend.purchase_succeeded.disconnect(_on_purchase_succeeded)
		backend.purchase_failed.disconnect(_on_purchase_failed)
		backend.purchase_pending.disconnect(_on_purchase_pending)
		backend.purchase_restored.disconnect(_on_purchase_restored)
	backend = new_backend
	backend.products_updated.connect(_on_products_updated)
	backend.purchase_succeeded.connect(_on_purchase_succeeded)
	backend.purchase_failed.connect(_on_purchase_failed)
	backend.purchase_pending.connect(_on_purchase_pending)
	backend.purchase_restored.connect(_on_purchase_restored)
	var skus: Array[String] = []
	for product: ShopProductDef in ConfigDB.get_products():
		if product.is_real_money():
			skus.append(product.store_sku)
	backend.initialize(skus)


## Нативный бэкенд, если плагин платформы подключён; Mock — только в debug (редактор);
## в релизе без плагина покупки недоступны (никаких бесплатных Кристаллов).
func _default_backend() -> StoreBackend:
	if OS.get_name() == "Android" and Engine.has_singleton(GooglePlayBillingBackend.SINGLETON):
		return GooglePlayBillingBackend.new()
	if OS.get_name() == "iOS" and ClassDB.class_exists(AppStoreBackend.STORE_CLASS):
		return AppStoreBackend.new()
	return MockStoreBackend.new() if OS.is_debug_build() else StoreBackend.new()


func get_products() -> Array[ShopProductDef]:
	return ConfigDB.get_products()


## Локализованная цена из стора (DS: цены — только из стора, не хардкод). Пусто — стор ещё не ответил.
func price_label(product_id: StringName) -> String:
	var product: ShopProductDef = ConfigDB.get_product(product_id)
	if product == null:
		return ""
	return str(_prices.get(product.store_sku, backend.get_price_label(product.store_sku)))


# --- Стартер-пак (FOMO-таймер от первого показа, D18) ---

func starter_pack_active() -> bool:
	var profile: PlayerProfile = GameManager.profile
	if profile.starter_pack_bought:
		return false
	return profile.starter_pack_expires_at == 0 or starter_pack_seconds_left() > 0


## Первый показ оффера запускает таймер.
func note_starter_pack_shown() -> void:
	var profile: PlayerProfile = GameManager.profile
	var product: ShopProductDef = ConfigDB.get_product(&"starter_pack")
	if product == null or profile.starter_pack_expires_at != 0 or profile.starter_pack_bought:
		return
	profile.starter_pack_expires_at = int(Time.get_unix_time_from_system()) + int(product.offer_timer_h * 3600.0)
	SaveManager.request_save()
	Telemetry.log_event(&"offer_shown", {"product_id": "starter_pack"})


func starter_pack_seconds_left() -> int:
	var expires: int = GameManager.profile.starter_pack_expires_at
	if expires == 0:
		return 0
	return maxi(0, expires - int(Time.get_unix_time_from_system()))


# --- Покупка ---

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
	_grant(product, false)
	EventBus.purchase_completed.emit(product_id)


func restore_purchases() -> void:
	backend.restore()


func _on_products_updated(prices: Dictionary) -> void:
	_prices.merge(prices, true)
	EventBus.store_prices_updated.emit()


func _on_purchase_succeeded(sku: String, transaction_id: String) -> void:
	var product: ShopProductDef = _product_by_sku(sku)
	if product == null:
		push_error("[StoreManager] unknown sku '%s'" % sku)
		return
	var profile: PlayerProfile = GameManager.profile
	if profile.receipts.has(transaction_id) or (product.one_time and _is_owned(product)):
		backend.finish(transaction_id, not product.one_time)
		return
	profile.receipts.append(transaction_id)
	_grant(product, false)
	SaveManager.flush(true)
	CloudManager.push()
	backend.finish(transaction_id, not product.one_time)
	Telemetry.log_event(&"iap_completed", {"product_id": String(product.id)})
	EventBus.purchase_completed.emit(product.id)


## Восстановление: только нерасходуемое (скин), без повторной выдачи Кристаллов.
func _on_purchase_restored(sku: String, transaction_id: String) -> void:
	var product: ShopProductDef = _product_by_sku(sku)
	if product == null or not product.one_time:
		return
	var profile: PlayerProfile = GameManager.profile
	if not profile.receipts.has(transaction_id):
		profile.receipts.append(transaction_id)
	_grant(product, true)
	SaveManager.request_save(true)
	Telemetry.log_event(&"iap_restored", {"product_id": String(product.id)})
	EventBus.toast_requested.emit(tr("Покупки восстановлены"), &"shop")


func _on_purchase_pending(sku: String) -> void:
	var product: ShopProductDef = _product_by_sku(sku)
	Telemetry.log_event(&"iap_pending", {"product_id": String(product.id) if product != null else sku})
	EventBus.toast_requested.emit(tr("Покупка ожидает подтверждения"), &"shop")


func _on_purchase_failed(sku: String, reason: String) -> void:
	var product: ShopProductDef = _product_by_sku(sku)
	var product_id: StringName = product.id if product != null else StringName(sku)
	Telemetry.log_event(&"iap_failed", {"product_id": String(product_id), "reason": reason})
	EventBus.purchase_failed.emit(product_id, reason)


## Единственная точка выдачи наград покупки. only_permanent — при восстановлении (без расходуемого).
func _grant(product: ShopProductDef, only_permanent: bool) -> void:
	var profile: PlayerProfile = GameManager.profile
	var reason: StringName = &"iap" if product.is_real_money() else StringName("shop_" + product.id)
	for key: String in product.grants:
		if only_permanent and CONSUMABLE_GRANTS.has(key):
			continue
		var value: Variant = product.grants[key]
		match key:
			"crystals":
				GameManager.grant(GameManager.CRYSTALS, int(value), reason)
			"sparks":
				GameManager.grant(GameManager.SPARKS, int(value), reason)
			"skin":
				SkinService.unlock(profile, StringName(str(value)))
			"chest", "count":
				pass # Сундуки магазина открывает ChestService (S10 → S17).
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
