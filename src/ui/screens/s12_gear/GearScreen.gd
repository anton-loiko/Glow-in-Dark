extends Control
## S12 · Экипировка (DS S12, Gear DS §01, Meta DS §03): «кукла» — Огонёк в текущем скине и слоты 76×76 крестом
## (Шлем сверху, Ядро слева, Амулет справа, Ботинки снизу, «Второй амулет» — после тира 5), лента Огоньков,
## сводка статов (4 плитки), инвентарь: фильтры по слоту + «Слияние» с красным счётчиком, сетка 5 колонок.

const SLOT_POS: Dictionary = {&"head": Vector2(0, -92), &"core": Vector2(-118, 0), &"amulet": Vector2(118, 0), &"feet": Vector2(0, 92), &"amulet_2": Vector2(118, 92)}
const FILTERS: Array[StringName] = [&"", &"head", &"core", &"feet", &"amulet"]
const STAT_TILES: Array[Array] = [
	[&"max_light", "Свет"],
	[&"decay_rate_pct", "Затухание"],
	[&"move_speed_pct", "Скорость"],
	[&"spark_income_pct", "Искры"],
]

var _doll: Control
var _hero: HeroGlyph
var _skins_row: HBoxContainer
var _stats_row: HBoxContainer
var _filter_row: Segmented
var _merge_button: GlowButton
var _inventory_title: Label
var _grid: GridContainer
var _filter: StringName = &""
var _tabs: GlowTabBar


func _ready() -> void:
	var column: VBoxContainer = UIKit.screen_root(self)
	column.add_theme_constant_override(&"separation", UITokens.S3)
	var header: HBoxContainer = UIKit.hbox()
	column.add_child(header)
	var title: Label = UIKit.label(tr("Экипировка"), &"h1")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	# «История Маяка» — пересмотр пройденных вех (Meta DS §01).
	var history: Button = Button.new()
	history.theme_type_variation = &"ButtonQuiet"
	history.icon = load("res://src/assets/ui/icons/tab_beacon.png")
	history.expand_icon = true
	history.custom_minimum_size = Vector2(UITokens.TOUCH_MIN, UITokens.TOUCH_MIN)
	history.add_theme_constant_override(&"icon_max_width", 22)
	history.add_theme_color_override(&"icon_normal_color", UITokens.RUNE)
	history.tooltip_text = tr("История Маяка")
	history.pressed.connect(_open_history)
	header.add_child(history)
	var pill: CurrencyPill = CurrencyPill.new()
	pill.currency = GameManager.SPARKS
	header.add_child(pill)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var body: VBoxContainer = UIKit.vbox(UITokens.S3)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)

	_doll = Control.new()
	_doll.custom_minimum_size = Vector2(0, 270)
	_doll.draw.connect(_draw_doll_bg)
	body.add_child(_doll)
	_hero = HeroGlyph.new()
	_hero.diameter = 62.0
	_hero.custom_minimum_size = Vector2(110, 110)
	_hero.size = Vector2(110, 110)
	_doll.add_child(_hero)

	var skins_scroll: ScrollContainer = ScrollContainer.new()
	skins_scroll.custom_minimum_size = Vector2(0, 76)
	skins_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(skins_scroll)
	_skins_row = UIKit.hbox(UITokens.S2)
	skins_scroll.add_child(_skins_row)

	_stats_row = UIKit.hbox(UITokens.S2)
	body.add_child(_stats_row)

	var inv_head: HBoxContainer = UIKit.hbox()
	body.add_child(inv_head)
	_inventory_title = UIKit.mono("")
	_inventory_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inv_head.add_child(_inventory_title)
	_merge_button = UIKit.button(tr("Слияние"), GlowButton.Variant.SECONDARY, _open_merge)
	_merge_button.custom_minimum_size = Vector2(0, UITokens.TOUCH_MIN)
	_merge_button.draw.connect(_draw_merge_badge)
	inv_head.add_child(_merge_button)
	# Фильтр инвентаря — Segmented DS (подложка ink.600, активный сегмент line.strong).
	var names: PackedStringArray = PackedStringArray()
	for f: StringName in FILTERS:
		names.append(tr("Все") if f == &"" else GearText.slot_name(f))
	_filter_row = Segmented.new(names, 0)
	_filter_row.selected.connect(func(i: int) -> void: _set_filter(FILTERS[i]))
	body.add_child(_filter_row)
	_grid = GridContainer.new()
	_grid.columns = 5
	_grid.add_theme_constant_override(&"h_separation", 10)
	_grid.add_theme_constant_override(&"v_separation", 10)
	body.add_child(_grid)
	body.add_child(UIKit.gap(UITokens.S8)) # последний ряд не прячется под Ember «В БОЙ»

	_tabs = GlowTabBar.new()
	_tabs.active = &"S12"
	column.add_child(_tabs)
	EventBus.inventory_changed.connect(_refresh)
	EventBus.gear_changed.connect(_on_gear_changed)
	EventBus.skin_equipped.connect(_on_skin_equipped)
	EventBus.screen_changed.connect(_on_screen_changed)
	_doll.resized.connect(_layout_doll)
	_refresh()


func _on_gear_changed(_slot: StringName) -> void:
	_refresh()


func _on_skin_equipped(_id: StringName) -> void:
	# Огонёк «кивает» (squash 0.95) при смене скина.
	_hero.squash = 0.95
	UIMotion.tween(_hero).tween_property(_hero, ^"squash", 1.0, UITokens.T_BASE_S).set_custom_interpolator(UIMotion.settle)
	_refresh()


func _on_screen_changed(id: StringName) -> void:
	if id == &"S12":
		_refresh()


func _refresh() -> void:
	if not is_inside_tree():
		return
	var profile: PlayerProfile = GameManager.profile
	var skin: SkinDef = ConfigDB.get_skin(profile.skin_equipped)
	_hero.color = skin.light_color if skin != null else UITokens.LIGHT_500
	_build_doll_slots()
	_build_skins()
	_build_stats()
	_build_inventory()
	var merges: int = GearService.available_merges(profile)
	_merge_button.set_meta(&"count", merges)
	_merge_button.queue_redraw()
	_tabs.refresh_dots()
	_doll.queue_redraw()


# --- Кукла ---

func _build_doll_slots() -> void:
	for child: Node in _doll.get_children():
		if child is GearCell or child is Label:
			child.queue_free()
	var profile: PlayerProfile = GameManager.profile
	for slot: StringName in SLOT_POS:
		if slot == &"amulet_2" and not profile.gear_slots_unlocked.has(slot):
			continue
		var uid: String = GearService.equipped_uid(profile, slot)
		var cell: GearCell = GearCell.new().setup(profile.find_gear(uid) if not uid.is_empty() else null, 76.0)
		cell.slot = slot
		cell.set_meta(&"slot", slot)
		cell.pressed.connect(_on_slot_pressed)
		cell.accepts_drop = true
		cell.item_dropped.connect(_on_item_dropped)
		_doll.add_child(cell)
		var caption: Label = UIKit.mono(GearText.slot_name(slot).to_upper(), UITokens.TEXT_MUTED, HORIZONTAL_ALIGNMENT_CENTER)
		caption.add_theme_font_size_override(&"font_size", 10)
		caption.set_meta(&"slot", slot)
		_doll.add_child(caption)
	_layout_doll()


func _layout_doll() -> void:
	var c: Vector2 = _doll.size * 0.5 - Vector2(0, 12)
	_hero.position = c - _hero.size * 0.5
	for child: Node in _doll.get_children():
		if not child.has_meta(&"slot"):
			continue
		var pos: Vector2 = c + (SLOT_POS[child.get_meta(&"slot")] as Vector2)
		if child is GearCell:
			(child as GearCell).position = pos - Vector2(38, 38)
		elif child is Label:
			var l: Label = child as Label
			l.size = Vector2(100, 14)
			l.position = pos + Vector2(-50, 40)


func _on_slot_pressed(cell: GearCell) -> void:
	if cell.item != null:
		SceneRouter.open_modal(&"S15", {"uid": cell.item.uid})
	else:
		_set_filter(&"amulet" if cell.slot == &"amulet_2" else cell.slot)


func _draw_doll_bg() -> void:
	var c: Vector2 = _doll.size * 0.5 - Vector2(0, 12)
	var skin: SkinDef = ConfigDB.get_skin(GameManager.profile.skin_equipped)
	var color: Color = skin.light_color if skin != null else UITokens.LIGHT_500
	_doll.draw_texture_rect(HeroGlyph.halo_texture(), Rect2(c - Vector2.ONE * 150.0, Vector2.ONE * 300.0), false, Color(color, 0.35))
	# С Легендарным предметом — золотая кайма света.
	for slot: StringName in SLOT_POS:
		var it: PlayerProfile.GearItem = GameManager.profile.find_gear(GearService.equipped_uid(GameManager.profile, slot))
		if it != null and it.rarity == &"legendary":
			_doll.draw_arc(c, 128.0, 0.0, TAU, 64, Color(UITokens.GOLD_300, 0.35), 2.0)
			break


# --- Лента Огоньков ---

func _build_skins() -> void:
	for child: Node in _skins_row.get_children():
		child.queue_free()
	var profile: PlayerProfile = GameManager.profile
	for id: StringName in ConfigDB.get_skin_ids():
		_skins_row.add_child(_skin_tile(id, ConfigDB.get_skin(id), profile))


func _skin_tile(id: StringName, skin: SkinDef, profile: PlayerProfile) -> Control:
	var unlocked: bool = SkinService.is_unlocked(profile, id)
	var equipped: bool = profile.skin_equipped == id
	var tile: Button = Button.new()
	tile.theme_type_variation = &"ButtonQuiet"
	tile.focus_mode = Control.FOCUS_NONE
	tile.custom_minimum_size = Vector2(68, 76)
	tile.pressed.connect(_on_skin_pressed.bind(id))
	var glyph: HeroGlyph = HeroGlyph.new()
	glyph.color = skin.light_color if unlocked else UITokens.TEXT_DISABLED
	glyph.diameter = 24.0
	glyph.glow = UITokens.G1 if equipped else 0
	glyph.breathe = equipped
	glyph.custom_minimum_size = Vector2(68, 46)
	glyph.size = Vector2(68, 46)
	tile.add_child(glyph)
	var caption: String = tr("Надет") if equipped else (tr(SkinService.display_name(id)) if unlocked else _lock_text(skin))
	# Подпись Manrope 11 с многоточием — длинные имена не наезжают на соседей.
	var label: Label = UIKit.label(caption.to_upper() if equipped else caption, &"body_s", skin.light_color if equipped else UITokens.TEXT_MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	label.add_theme_font_size_override(&"font_size", 11)
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.clip_text = true
	label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	label.offset_left = 2
	label.offset_right = -2
	label.offset_top = 54
	label.offset_bottom = 70
	tile.add_child(label)
	tile.draw.connect(_draw_skin_tile.bind(tile, unlocked, equipped, profile.skins_new_badge.has(id), skin.light_color))
	return tile


func _draw_skin_tile(tile: Button, unlocked: bool, equipped: bool, is_new: bool, skin_color: Color) -> void:
	var rect: Rect2 = Rect2(Vector2.ONE, tile.size - Vector2.ONE * 2.0)
	if equipped:
		# Надет — контур цветом скина (DS S12).
		var box: StyleBoxFlat = StyleBoxFlat.new()
		box.bg_color = Color(skin_color, 0.08)
		box.border_color = skin_color
		box.set_border_width_all(1)
		box.set_corner_radius_all(UITokens.R14)
		box.draw(tile.get_canvas_item(), rect)
	elif not unlocked:
		var pts: PackedVector2Array = ButtonFace.rounded_rect(rect, UITokens.R14)
		pts.append(pts[0])
		for i: int in pts.size() - 1:
			tile.draw_dashed_line(pts[i], pts[i + 1], UITokens.LINE_STRONG, 1.0, 5.0)
	if is_new:
		tile.draw_circle(Vector2(rect.end.x - 6, rect.position.y + 6), 4.0, UITokens.THREAT)


func _on_skin_pressed(id: StringName) -> void:
	var profile: PlayerProfile = GameManager.profile
	if SkinService.is_unlocked(profile, id):
		SkinService.equip(profile, id, &"s12")
	else:
		SceneRouter.open_modal(&"S14", {"skin": id, "preview": true})


func _lock_text(skin: SkinDef) -> String:
	if String(skin.unlock.get("type", "")) == "beacon":
		return tr("Маяк %d%%") % (int(skin.unlock.get("tier", 0)) * BeaconService.levels_per_tier())
	return tr("Магазин")


# --- Сводка статов ---

func _build_stats() -> void:
	for child: Node in _stats_row.get_children():
		child.queue_free()
	var totals: Dictionary = {}
	var profile: PlayerProfile = GameManager.profile
	for slot: StringName in profile.gear_equipped:
		var it: PlayerProfile.GearItem = profile.find_gear(profile.gear_equipped[slot])
		if it != null:
			var stat: StringName = GearText.stat_item(it)
			totals[stat] = float(totals.get(stat, 0.0)) + GearService.stat_value(it)
	for entry: Array in STAT_TILES:
		var stat: StringName = entry[0]
		var value: float = float(totals.get(stat, 0.0))
		var tile: PanelContainer = UIKit.panel(&"PanelCard")
		var compact: StyleBoxFlat = StyleBoxFlat.new()
		compact.bg_color = UITokens.INK_700
		compact.set_corner_radius_all(UITokens.R14)
		compact.set_content_margin_all(6)
		tile.add_theme_stylebox_override(&"panel", compact)
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var box: VBoxContainer = UIKit.vbox(0, BoxContainer.ALIGNMENT_CENTER)
		tile.add_child(box)
		box.add_child(UIKit.mono(tr(str(entry[1])).to_upper(), UITokens.TEXT_MUTED, HORIZONTAL_ALIGNMENT_CENTER))
		var text: String = "0"
		if not is_zero_approx(value):
			var magnitude: String = GearText.num(absf(value))
			text = ("−" if value < 0 else "+") + magnitude + ("" if stat == &"max_light" else "%")
		box.add_child(UIKit.label(text, &"number", UITokens.GAIN if not is_zero_approx(value) else UITokens.TEXT_DISABLED, HORIZONTAL_ALIGNMENT_CENTER))
		_stats_row.add_child(tile)


# --- Инвентарь ---

func _set_filter(f: StringName) -> void:
	_filter = f
	_build_inventory()


func _build_inventory() -> void:
	for child: Node in _grid.get_children():
		child.queue_free()
	var profile: PlayerProfile = GameManager.profile
	_inventory_title.text = tr("Инвентарь · %d / %d") % [profile.gear_inventory.size(), GearService.inventory_size()]
	_filter_row.set_current(FILTERS.find(_filter))
	var items: Array[PlayerProfile.GearItem] = []
	for it: PlayerProfile.GearItem in profile.gear_inventory:
		if _filter == &"" or it.slot == _filter:
			items.append(it)
	items.sort_custom(_sort_items)
	for it: PlayerProfile.GearItem in items:
		var cell: GearCell = GearCell.new().setup(it, 62.0)
		cell.equipped = GearService.is_equipped(profile, it.uid)
		cell.badge_up = GearService.can_level_up(profile, it)
		cell.badge_merge = GearService.can_merge_rarity(it.rarity) and GearService.merge_partners(profile, it).size() >= GearService.merge_count()
		cell.pressed.connect(_on_item_pressed)
		cell.long_pressed.connect(_show_compare)
		_grid.add_child(cell)
	if items.is_empty():
		var empty: Label = UIKit.label(tr("Здесь появятся предметы из сундуков"), &"body_s", UITokens.TEXT_MUTED)
		_grid.add_child(empty)


## Сортировка: редкость ↓ → уровень ↓.
func _sort_items(a: PlayerProfile.GearItem, b: PlayerProfile.GearItem) -> bool:
	var ra: int = GearService.RARITIES.find(a.rarity)
	var rb: int = GearService.RARITIES.find(b.rarity)
	if ra != rb:
		return ra > rb
	return a.level > b.level


func _on_item_pressed(cell: GearCell) -> void:
	SceneRouter.open_modal(&"S15", {"uid": cell.item.uid})


func _open_merge() -> void:
	SceneRouter.open_modal(&"S16", {})


func _draw_merge_badge() -> void:
	var count: int = int(_merge_button.get_meta(&"count", 0))
	if count <= 0:
		return
	var c: Vector2 = Vector2(_merge_button.size.x - 4, 4)
	_merge_button.draw_circle(c, 9.0, UITokens.THREAT)
	var font: Font = UIFonts.font(&"number")
	var t: String = str(count)
	var w: float = font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
	_merge_button.draw_string(font, c + Vector2(-w * 0.5, 4), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UITokens.TEXT_PRIMARY)


# --- История Маяка ---

func _open_history() -> void:
	var overlay: Control = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(UITokens.INK_900, 0.8)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(_on_history_dim.bind(overlay))
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
	box.add_child(UIKit.label(tr("История Маяка"), &"h2"))
	var chapter_id: int = GameManager.profile.current_chapter
	var seen: Array[int] = GameManager.profile.get_beacon(chapter_id).seen_milestones
	if seen.is_empty():
		box.add_child(UIKit.label(tr("Вехи появятся на 25% Маяка"), &"body_s", UITokens.TEXT_MUTED))
	for m: int in [25, 50, 75, 100]:
		if seen.has(m):
			var title: String = "%d%% · %s" % [m, tr(BeaconCutscene.MILESTONE_TITLES[m])]
			box.add_child(UIKit.button(title, GlowButton.Variant.SECONDARY, _replay_milestone.bind(overlay, chapter_id, m)))
	UIMotion.appear(panel)


func _replay_milestone(overlay: Control, chapter_id: int, milestone: int) -> void:
	overlay.queue_free()
	var cutscene: BeaconCutscene = BeaconCutscene.new()
	add_child(cutscene)
	cutscene.play(chapter_id, floori(float(milestone) / BeaconService.levels_per_tier()) if milestone % BeaconService.levels_per_tier() == 0 else 0, milestone)


func _on_history_dim(event: InputEvent, overlay: Control) -> void:
	var tapped: bool = (event is InputEventMouseButton and (event as InputEventMouseButton).pressed) \
		or (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed)
	if tapped:
		overlay.queue_free()


# --- Надевание перетаскиванием и сравнение по долгому тапу (Gear DS §01) ---

func _on_item_dropped(slot_cell: GearCell, uid: String) -> void:
	if GearService.equip(GameManager.profile, uid, slot_cell.slot):
		FeedbackManager.cue(&"card_pick")
		_hero.squash = 0.95 # Огонёк «кивает»
		UIMotion.tween(_hero).tween_property(_hero, ^"squash", 1.0, UITokens.T_BASE_S).set_custom_interpolator(UIMotion.settle)


## «+6 Свет»: разница стата предмета с надетым в его слоте.
func _show_compare(cell: GearCell) -> void:
	var it: PlayerProfile.GearItem = cell.item
	var profile: PlayerProfile = GameManager.profile
	var current: PlayerProfile.GearItem = profile.find_gear(GearService.equipped_uid(profile, it.slot))
	var delta: float = GearService.stat_value(it) - (GearService.stat_value(current) if current != null else 0.0)
	var stat: StringName = GearText.stat_item(it)
	var text: String = tr("Надет") if current == it else GearText.stat_text(stat, delta)
	if current != it and delta < 0.0 and stat != &"decay_rate_pct":
		text = "−" + GearText.stat_text(stat, -delta).trim_prefix("+")
	var tip: PanelContainer = UIKit.panel(&"PanelPill")
	var label: Label = UIKit.label(text, &"number", UITokens.GAIN if delta >= 0.0 or stat == &"decay_rate_pct" else UITokens.COLD)
	tip.add_child(label)
	tip.top_level = true
	add_child(tip)
	tip.global_position = cell.global_position + Vector2(-20, -44)
	var t: Tween = UIMotion.tween(tip)
	t.tween_interval(1.4)
	t.tween_property(tip, ^"modulate:a", 0.0, UITokens.T_FAST_S)
	t.tween_callback(tip.queue_free)
