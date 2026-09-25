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
var _starter: StarterPackCard
var _price_buttons: Dictionary = {} ## product_id -> GlowButton


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

	if ConfigDB.get_product(&"starter_pack") != null and StoreManager.starter_pack_active():
		_starter = StarterPackCard.new()
		list.add_child(_starter)

	var gift_card: PanelContainer = _card(list)
	var gift_box: VBoxContainer = gift_card.get_child(0) as VBoxContainer
	gift_box.add_child(UIKit.label(tr("Бесплатный дар"), &"h2"))
	gift_box.add_child(UIKit.label(tr("300 искр · 1 раз в 8 ч"), &"body_s", UITokens.TEXT_SECONDARY))
	_gift = UIKit.ad_button(tr("Взять"), GlowButton.Variant.SECONDARY, &"shop_free_gift")
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
		var icon: Control = Control.new()
		icon.custom_minimum_size = Vector2(0, 56)
		icon.draw.connect(_draw_crystal_pile.bind(icon, grid.get_child_count()))
		tile_box.add_child(icon)
		tile_box.add_child(UIKit.label("◆ " + UIKit.format_number(int(product.grants.get("crystals", 0))), &"h2", UITokens.CRYSTAL_500, HORIZONTAL_ALIGNMENT_CENTER))
		var buy: GlowButton = UIKit.button("", GlowButton.Variant.CRYSTAL, StoreManager.purchase.bind(id))
		_price_buttons[id] = buy
		tile_box.add_child(buy)
		grid.add_child(tile)

	var tabs: GlowTabBar = GlowTabBar.new()
	tabs.active = &"S10"
	column.add_child(tabs)
	_refresh_gift()
	EventBus.currency_changed.connect(_on_currency_changed)
	EventBus.inventory_changed.connect(_refresh_chests)
	EventBus.ad_reward_granted.connect(_on_ad_reward)
	EventBus.store_prices_updated.connect(_refresh_prices)
	EventBus.purchase_completed.connect(_on_purchase_completed)
	_refresh_chests()
	_refresh_prices()


## Цены — только локализованные строки стора (не хардкод). Пока стор не ответил — «…» и Disabled.
func _refresh_prices() -> void:
	for id: StringName in _price_buttons:
		var price: String = StoreManager.price_label(id)
		var b: GlowButton = _price_buttons[id]
		b.set_label(price if not price.is_empty() else "…")
		b.set_blocked(price.is_empty(), tr("Магазин недоступен"))
	if _starter != null:
		_starter.refresh()


func _on_purchase_completed(product_id: StringName) -> void:
	if product_id == &"starter_pack" and _starter != null:
		_starter.refresh()
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
	_add_chest_art(basic_box, &"basic")
	basic_box.add_child(UIKit.label(tr("Базовый сундук"), &"h2"))
	basic_box.add_child(UIKit.label(tr("Обычные и необычные предметы, изредка редкие"), &"body_s", UITokens.TEXT_SECONDARY))
	var basic_row: HBoxContainer = UIKit.hbox(UITokens.S2)
	basic_box.add_child(basic_row)
	var price: int = _basic_price()
	_basic_sparks = UIKit.button("%s ✦" % UIKit.format_number(price), GlowButton.Variant.SECONDARY, _buy.bind(&"basic", 1))
	_basic_sparks.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	basic_row.add_child(_basic_sparks)
	_basic_ad = UIKit.ad_button("", GlowButton.Variant.SECONDARY, &"basic_chest")
	_basic_ad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	basic_row.add_child(_basic_ad)
	var premium: PanelContainer = _card(list)
	var premium_box: VBoxContainer = premium.get_child(0) as VBoxContainer
	_add_chest_art(premium_box, &"premium")
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


func _add_chest_art(box: VBoxContainer, chest: StringName) -> void:
	var tex: Texture2D = load("res://src/assets/chests/chest_%s_closed.png" % chest) as Texture2D
	if tex == null:
		return
	var art: TextureRect = TextureRect.new()
	art.texture = tex
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.custom_minimum_size = Vector2(0, 72)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(art)


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
	_basic_ad.ad_extra_reason = full_text if full else (tr("Завтра снова") if ads_left <= 0 else "")
	_basic_ad.refresh_ad()
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
	if placement != &"basic_chest":
		return
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
	_gift.refresh_ad()


## Иконка пакета растёт с номиналом: один кристалл → друза (DS S10); $19.99 — «сокровище» с ореолом.
func _draw_crystal_pile(icon: Control, tier: int) -> void:
	var c: Vector2 = Vector2(icon.size.x * 0.5, icon.size.y - 6)
	var count: int = [1, 2, 4, 7][clampi(tier, 0, 3)]
	if tier >= 3:
		for i: int in 4:
			icon.draw_circle(c - Vector2(0, 20), 30.0 - i * 6, Color(UITokens.CRYSTAL_500, 0.06))
	for i: int in count:
		var angle: float = (float(i) / maxf(1.0, count - 1) - 0.5) * 1.6 if count > 1 else 0.0
		var h: float = 34.0 - absf(angle) * 10.0 + (4.0 if i % 2 == 0 else 0.0)
		var base: Vector2 = c + Vector2(angle * 26.0, 0)
		var tip: Vector2 = base + Vector2.from_angle(-PI * 0.5 + angle * 0.5) * h
		var side: Vector2 = Vector2(7, 0)
		icon.draw_colored_polygon(PackedVector2Array([base - side, tip, base + side]), UITokens.CRYSTAL_700.lerp(UITokens.CRYSTAL_300, float(i % 3) / 2.0))


func _card(parent: Control) -> PanelContainer:
	var card: PanelContainer = UIKit.panel(&"PanelCard")
	card.add_child(UIKit.vbox(UITokens.S2))
	parent.add_child(card)
	return card
