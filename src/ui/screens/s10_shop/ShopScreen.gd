extends Control
## S10 · Магазин (DS S10, Gear DS §03): порядок блоков фиксирован — стартер-пак (пока не куплен) →
## бесплатный дар ▶ → сундуки → матрица Кристаллов. Кристаллы — единственный холодный неон в игре.
## Каркас: сундуки (task_6), цены сторов, лимиты и таймер оффера (task_7). Ember здесь 62pt без свечения.

var _gift: GlowButton


func _ready() -> void:
	var column: VBoxContainer = UIKit.screen_root(self)
	var top: HBoxContainer = UIKit.hbox(UITokens.S2)
	column.add_child(top)
	top.add_child(UIKit.label(tr("Магазин"), &"h1"))
	top.add_child(UIKit.spacer(false))
	for currency: StringName in [GameManager.SPARKS, GameManager.CRYSTALS]:
		var pill: CurrencyPill = CurrencyPill.new()
		pill.currency = currency
		top.add_child(pill)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var list: VBoxContainer = UIKit.vbox(UITokens.S3)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)

	var starter: ShopProductDef = ConfigDB.get_product(&"starter_pack")
	if starter != null and not GameManager.profile.starter_pack_bought:
		var card: PanelContainer = _card(list)
		var box: VBoxContainer = card.get_child(0) as VBoxContainer
		box.add_child(UIKit.mono(tr("Только один раз"), UITokens.THREAT))
		box.add_child(UIKit.label(tr("Набор Первого Света"), &"h2"))
		box.add_child(UIKit.label(tr("Скин «Лунный Огонёк» · 500 кристаллов"), &"body_s", UITokens.TEXT_SECONDARY))
		box.add_child(UIKit.button(StoreManager.backend.get_price_label(starter.store_sku), GlowButton.Variant.CRYSTAL, StoreManager.purchase.bind(&"starter_pack")))

	var gift_card: PanelContainer = _card(list)
	var gift_box: VBoxContainer = gift_card.get_child(0) as VBoxContainer
	gift_box.add_child(UIKit.label(tr("Бесплатный дар"), &"h2"))
	gift_box.add_child(UIKit.label(tr("300 искр · 1 раз в 8 ч"), &"body_s", UITokens.TEXT_SECONDARY))
	_gift = UIKit.button(tr("Взять"), GlowButton.Variant.SECONDARY, AdManager.show_rewarded.bind(&"shop_free_gift"))
	_gift.ad = true
	gift_box.add_child(_gift)

	var chests: PanelContainer = _card(list)
	var chest_box: VBoxContainer = chests.get_child(0) as VBoxContainer
	chest_box.add_child(UIKit.label(tr("Сундуки"), &"h2"))
	var chest_button: GlowButton = UIKit.button(tr("Базовый сундук"), GlowButton.Variant.SECONDARY, Callable())
	chest_box.add_child(chest_button)
	chest_button.set_blocked(true, tr("Скоро · экипировка"))

	list.add_child(UIKit.mono(tr("Кристаллы света"), UITokens.CRYSTAL_500))
	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override(&"h_separation", UITokens.S3)
	grid.add_theme_constant_override(&"v_separation", UITokens.S3)
	list.add_child(grid)
	for id: StringName in [&"crystals_80", &"crystals_280", &"crystals_550", &"crystals_2600"]:
		var product: ShopProductDef = ConfigDB.get_product(id)
		if product == null:
			continue
		var tile: PanelContainer = UIKit.panel(&"PanelCard")
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var tile_box: VBoxContainer = UIKit.vbox(UITokens.S2, BoxContainer.ALIGNMENT_CENTER)
		tile.add_child(tile_box)
		if product.badge == &"hit":
			tile_box.add_child(UIKit.mono(tr("Хит"), UITokens.LIGHT_500, HORIZONTAL_ALIGNMENT_CENTER))
		tile_box.add_child(UIKit.label("◆ " + UIKit.format_number(int(product.grants.get("crystals", 0))), &"h2", UITokens.CRYSTAL_500, HORIZONTAL_ALIGNMENT_CENTER))
		tile_box.add_child(UIKit.button(StoreManager.backend.get_price_label(product.store_sku), GlowButton.Variant.CRYSTAL, StoreManager.purchase.bind(id)))
		grid.add_child(tile)

	var tabs: GlowTabBar = GlowTabBar.new()
	tabs.active = &"S10"
	column.add_child(tabs)
	_refresh_gift()
	EventBus.currency_changed.connect(func(_c: StringName, _t: int, _d: int) -> void: _refresh_gift())


func _refresh_gift() -> void:
	if StoreManager.free_gift_ready():
		_gift.set_blocked(not AdManager.is_rewarded_ready(&"shop_free_gift"), tr("Реклама недоступна"))
	else:
		var left: int = StoreManager.free_gift_seconds_left()
		_gift.set_blocked(true, tr("Через %d ч %d мин") % [floori(left / 3600.0), floori((left % 3600) / 60.0)])


func _card(parent: Control) -> PanelContainer:
	var card: PanelContainer = UIKit.panel(&"PanelCard")
	card.add_child(UIKit.vbox(UITokens.S2))
	parent.add_child(card)
	return card
