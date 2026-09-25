extends Control
## S10 · Магазин (DS S10, Gear DS §03): порядок блоков фиксирован — стартер-пак (пока не куплен) →
## бесплатный дар ▶ → сундуки → матрица Кристаллов. Кристаллы — единственный холодный неон в игре.
## Сундуки: Базовый 500 ✦ или ▶ (3/день), Премиум 150 ◆ / ×10 1 200 ◆, «i» — шансы (требование сторов).
## Результат сундука считается и сохраняется до анимации S17. Цены сторов и таймер оффера — task_7.

var _gift: GlowButton
var _basic_sparks: GlowButton
var _basic_ad: GlowButton
var _premium: GlowButton
var _premium_x10: GlowButton
var _full_hint: GlowButton


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

	_build_chests(list)

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
	EventBus.currency_changed.connect(_on_currency_changed)
	EventBus.inventory_changed.connect(_refresh_chests)
	EventBus.ad_reward_granted.connect(_on_ad_reward)
	_refresh_chests()


func _on_currency_changed(_currency: StringName, _total: int, _delta: int) -> void:
	_refresh_gift()
	_refresh_chests()


func _build_chests(list: VBoxContainer) -> void:
	var head: HBoxContainer = UIKit.hbox()
	list.add_child(head)
	var title: Label = UIKit.mono(tr("Сундуки"), UITokens.TEXT_MUTED)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	head.add_child(UIKit.button("i", GlowButton.Variant.ICON, _show_rates))
	var basic: PanelContainer = _card(list)
	var basic_box: VBoxContainer = basic.get_child(0) as VBoxContainer
	basic_box.add_child(UIKit.label(tr("Базовый сундук"), &"h2"))
	basic_box.add_child(UIKit.label(tr("Обычные и необычные предметы, изредка редкие"), &"body_s", UITokens.TEXT_SECONDARY))
	var basic_row: HBoxContainer = UIKit.hbox(UITokens.S2)
	basic_box.add_child(basic_row)
	var price: int = _basic_price()
	_basic_sparks = UIKit.button("%s ✦" % UIKit.format_number(price), GlowButton.Variant.SECONDARY, _buy.bind(&"basic", 1))
	_basic_sparks.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	basic_row.add_child(_basic_sparks)
	_basic_ad = UIKit.button("", GlowButton.Variant.SECONDARY, AdManager.show_rewarded.bind(&"basic_chest"))
	_basic_ad.ad = true
	_basic_ad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	basic_row.add_child(_basic_ad)
	var premium: PanelContainer = _card(list)
	var premium_box: VBoxContainer = premium.get_child(0) as VBoxContainer
	premium_box.add_child(UIKit.label(tr("Премиум-сундук"), &"h2", UITokens.CRYSTAL_300))
	premium_box.add_child(UIKit.label(tr("Шанс Легендарного · гарант за 60 открытий"), &"body_s", UITokens.TEXT_SECONDARY))
	var premium_row: HBoxContainer = UIKit.hbox(UITokens.S2)
	premium_box.add_child(premium_row)
	var premium_cfg: Dictionary = ChestService.config().get("premium", {}) as Dictionary
	var p1: int = int((premium_cfg.get("price", {}) as Dictionary).get("crystals", 150))
	var p10: int = int((premium_cfg.get("x10_price", {}) as Dictionary).get("crystals", 1200))
	_premium = UIKit.button("◆ %s" % UIKit.format_number(p1), GlowButton.Variant.CRYSTAL, _buy.bind(&"premium", 1))
	_premium.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	premium_row.add_child(_premium)
	_premium_x10 = UIKit.button("×10 · ◆ %s" % UIKit.format_number(p10), GlowButton.Variant.CRYSTAL, _buy.bind(&"premium", 10))
	_premium_x10.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	premium_row.add_child(_premium_x10)
	premium_box.add_child(UIKit.mono(tr("×10: минимум один Редкий"), UITokens.TEXT_MUTED))
	_full_hint = UIKit.button(tr("Слить или разобрать"), GlowButton.Variant.SECONDARY, SceneRouter.go.bind(&"S12"))
	list.add_child(_full_hint)


func _refresh_chests() -> void:
	if _basic_sparks == null:
		return
	var profile: PlayerProfile = GameManager.profile
	var full: bool = GearService.is_inventory_full(profile)
	_full_hint.visible = full
	var full_text: String = tr("Инвентарь полон")
	var basic_price: int = _basic_price()
	_basic_sparks.set_blocked(full or profile.sparks < basic_price, full_text if full else tr("Нужно ещё %s ✦") % UIKit.format_number(basic_price - profile.sparks))
	var ads_left: int = ChestService.basic_ads_left(profile)
	_basic_ad.set_label(tr("Бесплатно · %d/3") % ads_left)
	if full:
		_basic_ad.set_blocked(true, full_text)
	elif ads_left <= 0:
		_basic_ad.set_blocked(true, tr("Завтра снова"))
	else:
		_basic_ad.set_blocked(not AdManager.is_rewarded_ready(&"basic_chest"), tr("Реклама недоступна"))
	var premium_cfg: Dictionary = ChestService.config().get("premium", {}) as Dictionary
	var p1: int = int((premium_cfg.get("price", {}) as Dictionary).get("crystals", 150))
	var p10: int = int((premium_cfg.get("x10_price", {}) as Dictionary).get("crystals", 1200))
	_premium.set_blocked(full or profile.crystals < p1, full_text if full else tr("Нужно ◆ %d") % p1)
	var room: bool = profile.gear_inventory.size() + 10 <= GearService.inventory_size()
	_premium_x10.set_blocked(not room or profile.crystals < p10, full_text if not room else tr("Нужно ◆ %s") % UIKit.format_number(p10))


func _basic_price() -> int:
	var basic_cfg: Dictionary = ChestService.config().get("basic", {}) as Dictionary
	return int((basic_cfg.get("price", {}) as Dictionary).get("sparks", 500))


func _buy(chest: StringName, count: int) -> void:
	var items: Array[PlayerProfile.GearItem] = ChestService.buy(GameManager.profile, chest, count)
	_show_chest(chest, items)


func _on_ad_reward(placement: StringName) -> void:
	if placement != &"basic_chest" or ChestService.basic_ads_left(GameManager.profile) <= 0:
		return
	ChestService.note_basic_ad(GameManager.profile)
	_show_chest(&"basic", ChestService.open(GameManager.profile, &"basic", 1))


func _show_chest(chest: StringName, items: Array[PlayerProfile.GearItem]) -> void:
	if items.is_empty():
		return
	var uids: Array[String] = []
	for it: PlayerProfile.GearItem in items:
		uids.append(it.uid)
	SceneRouter.open_modal(&"S17", {"chest": chest, "items": uids})
	_refresh_chests()


## «i» — шансы выпадения обоих сундуков (требование App Store / Google Play для лутбоксов).
func _show_rates() -> void:
	var overlay: Control = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(UITokens.INK_900, 0.8)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(_on_rates_input.bind(overlay))
	overlay.add_child(dim)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(center)
	var panel: PanelContainer = UIKit.panel(&"PanelModal")
	panel.custom_minimum_size = Vector2(320, 0)
	center.add_child(panel)
	var box: VBoxContainer = UIKit.vbox(UITokens.S2)
	panel.add_child(box)
	box.add_child(UIKit.label(tr("Шансы выпадения"), &"h2"))
	for chest: StringName in [&"basic", &"premium"]:
		box.add_child(UIKit.mono(tr("Базовый сундук") if chest == &"basic" else tr("Премиум-сундук"), UITokens.SPARK))
		var rates: Array = ChestService.rates(chest)
		for i: int in rates.size():
			if float(rates[i]) <= 0.0:
				continue
			var row: HBoxContainer = UIKit.hbox()
			var name_label: Label = UIKit.label(GearText.rarity_name(GearService.RARITIES[i]), &"body_s", GearText.rarity_color(GearService.RARITIES[i]))
			name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(name_label)
			row.add_child(UIKit.label("%s%%" % GearText.num(float(rates[i])), &"number"))
			box.add_child(row)
	box.add_child(UIKit.mono(tr("Премиум: Легендарный гарантирован за 60 открытий"), UITokens.TEXT_MUTED))
	UIMotion.appear(panel)


func _on_rates_input(event: InputEvent, overlay: Control) -> void:
	var tapped: bool = (event is InputEventMouseButton and (event as InputEventMouseButton).pressed) \
		or (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed)
	if tapped:
		overlay.queue_free()


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
