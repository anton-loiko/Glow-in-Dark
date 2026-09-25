extends Control
## S17 · Открытие сундука (Gear DS §03). Результат уже посчитан и сохранён ДО анимации (C1): экран только показывает.
## C1 падение 400 мс → C2 три толчка 2/4/6pt, шов светится цветом лучшей редкости внутри → C3 взрыв крышки →
## C4 вылет карт рубашкой вверх → C5 флип (240/280/320/480/900 мс по редкости) → C6 итог, кнопки через 600 мс.
## ×10: веер 2×5 по возрастанию редкости; «Открыть все» — шаг 120 мс, стоп на Эпическом+. Тап в C1–C4 — ускорение ×3.
## params: items (Array[String] uid) + chest — или pending = true (сундук из profile.pending_rewards).

const FLIP_S: Dictionary = {&"common": 0.24, &"uncommon": 0.28, &"rare": 0.32, &"epic": 0.48, &"legendary": 0.9}

var _items: Array[PlayerProfile.GearItem] = []
var _chest: StringName = &"basic"
var _stage: Control
var _chest_box: Control
var _cards_root: Control
var _cards: Array[Control] = []
var _buttons: VBoxContainer
var _open_all: GlowButton
var _intro: Tween
var _seam_color: Color = UITokens.LIGHT_500
var _shake_x: float = 0.0
var _lid_open: bool = false
var _revealing: bool = false


func on_screen_enter(params: Dictionary) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var profile: PlayerProfile = GameManager.profile
	if bool(params.get("pending", false)):
		_take_pending(profile)
	else:
		_chest = StringName(str(params.get("chest", "basic")))
		for uid: Variant in params.get("items", []):
			var it: PlayerProfile.GearItem = profile.find_gear(str(uid))
			if it != null:
				_items.append(it)
	if _items.is_empty():
		SceneRouter.close_top.call_deferred()
		return
	_build()
	_play_intro()


## Сундук из pending_rewards: сначала убираем из очереди, затем open() — он сохраняет обе правки критической записью.
## Несколько сундуков одного типа (например, 3 сундука забега) открываются одним показом ×N.
func _take_pending(profile: PlayerProfile) -> void:
	var count: int = 0
	var i: int = 0
	while i < profile.pending_rewards.size():
		var reward: Dictionary = profile.pending_rewards[i]
		if reward.has("chest") and (count == 0 or StringName(str(reward["chest"])) == _chest):
			_chest = StringName(str(reward["chest"]))
			count += int(reward.get("count", 1))
			profile.pending_rewards.remove_at(i)
		else:
			i += 1
	if count > 0:
		_items = ChestService.open(profile, _chest, count)


func _build() -> void:
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(UITokens.INK_900, 0.94)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.gui_input.connect(_on_bg_input)
	add_child(bg)
	var safe: SafeAreaContainer = SafeAreaContainer.new()
	safe.side_margin = UITokens.S5
	safe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(safe)
	var column: VBoxContainer = UIKit.vbox(UITokens.S4)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	safe.add_child(column)
	var title: String = {&"basic": "Базовый сундук", &"premium": "Премиум-сундук", &"run": "Сундук забега", &"epic": "Эпический сундук"}.get(_chest, "Сундук")
	var eyebrow: Label = UIKit.mono(("×%d" % _items.size()) if _items.size() > 1 else tr("Открытие"), UITokens.SPARK, HORIZONTAL_ALIGNMENT_CENTER)
	column.add_child(eyebrow)
	column.add_child(UIKit.label(tr(title), &"h1", UITokens.TEXT_PRIMARY, HORIZONTAL_ALIGNMENT_CENTER))
	_stage = Control.new()
	_stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_stage)
	_chest_box = Control.new()
	_chest_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chest_box.draw.connect(_draw_chest)
	_stage.add_child(_chest_box)
	_cards_root = Control.new()
	_cards_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cards_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stage.add_child(_cards_root)
	_buttons = UIKit.vbox(UITokens.S2)
	column.add_child(_buttons)
	_open_all = UIKit.button(tr("Открыть все"), GlowButton.Variant.SECONDARY, _reveal_all)
	_open_all.visible = false
	_buttons.add_child(_open_all)
	var best: StringName = &"common"
	for it: PlayerProfile.GearItem in _items:
		if GearService.RARITIES.find(it.rarity) > GearService.RARITIES.find(best):
			best = it.rarity
	_seam_color = GearText.rarity_color(best)


# --- C1–C4 ---

func _play_intro() -> void:
	await get_tree().process_frame
	_chest_box.size = Vector2(160, 120)
	_chest_box.pivot_offset = _chest_box.size * 0.5
	var rest: Vector2 = Vector2((_stage.size.x - _chest_box.size.x) * 0.5, _stage.size.y * 0.5 - 40.0)
	_chest_box.position = rest - Vector2(0, 260)
	_intro = UIMotion.tween(self)
	_intro.tween_property(_chest_box, ^"position", rest, 0.4).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	for pt: float in [2.0, 4.0, 6.0]:
		_intro.tween_callback(FeedbackManager.haptic.bind(&"light"))
		_intro.tween_method(_set_shake.bind(pt), 0.0, 1.0, 0.18)
		_intro.tween_interval(0.12)
	_intro.tween_callback(_burst)
	_intro.tween_interval(0.25)
	await _intro.finished
	_deal_cards()


func _set_shake(k: float, pt: float) -> void:
	_shake_x = sin(k * TAU * 2.0) * pt * (1.0 - k)
	_chest_box.queue_redraw()


func _burst() -> void:
	_lid_open = true
	FeedbackManager.cue(&"chest_burst")
	_chest_box.queue_redraw()
	var column: ColorRect = ColorRect.new()
	column.color = Color(_seam_color, 0.5) if not GameManager.profile.settings.no_flashes else Color(UITokens.LIGHT_500, 0.3)
	column.size = Vector2(60, _stage.size.y)
	column.position = Vector2(_stage.size.x * 0.5 - 30, 0)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(column)
	var t: Tween = UIMotion.tween(column)
	t.tween_property(column, ^"modulate:a", 0.0, 0.5)
	t.tween_callback(column.queue_free)


## Спрайт сундука (tools/art/gen_sprites.lua): src/assets/chests/chest_<тип>_<closed|open>.png, 320×240 → 160×120pt.
static func chest_texture(chest: StringName, open: bool) -> Texture2D:
	var path: String = "res://src/assets/chests/chest_%s_%s.png" % [chest, "open" if open else "closed"]
	return load(path) as Texture2D if ResourceLoader.exists(path) else null


func _draw_chest() -> void:
	var s: Vector2 = _chest_box.size
	var o: Vector2 = Vector2(_shake_x, 0)
	var tex: Texture2D = chest_texture(_chest, _lid_open)
	if tex != null:
		if _lid_open:
			_chest_box.draw_circle(o + Vector2(s.x * 0.5, s.y * 0.42), s.x * 0.34, Color(_seam_color, 0.28))
		_chest_box.draw_texture_rect(tex, Rect2(o, s), false)
		if not _lid_open:
			# Шов светится цветом лучшей редкости внутри (C2).
			var lid_y: float = s.y * 0.467
			_chest_box.draw_line(o + Vector2(s.x * 0.14, lid_y), o + Vector2(s.x * 0.86, lid_y), Color(_seam_color, 0.9), 3.0)
			_chest_box.draw_line(o + Vector2(s.x * 0.14, lid_y), o + Vector2(s.x * 0.86, lid_y), Color(_seam_color, 0.3), 9.0)
		return
	var body: Rect2 = Rect2(o + Vector2(0, s.y * 0.4), Vector2(s.x, s.y * 0.6))
	var color: Color = UITokens.CRYSTAL_700 if _chest == &"premium" else (UITokens.EPIC if _chest == &"epic" else UITokens.GOLD_700)
	_chest_box.draw_rect(body, color.darkened(0.45))
	_chest_box.draw_rect(Rect2(body.position + Vector2(0, 10), Vector2(s.x, 8)), color)
	var seam_y: float = s.y * 0.4
	if _lid_open:
		_chest_box.draw_colored_polygon(PackedVector2Array([o + Vector2(-10, seam_y - 30), o + Vector2(s.x * 0.4, seam_y - 60), o + Vector2(s.x * 0.45, seam_y - 40), o + Vector2(0, seam_y - 10)]), color.darkened(0.3))
		_chest_box.draw_circle(o + Vector2(s.x * 0.5, seam_y), 40.0, Color(_seam_color, 0.25))
	else:
		_chest_box.draw_rect(Rect2(o + Vector2(0, 0), Vector2(s.x, seam_y)), color.darkened(0.3))
		_chest_box.draw_line(o + Vector2(0, seam_y), o + Vector2(s.x, seam_y), _seam_color, 3.0)
	_chest_box.draw_rect(Rect2(o + Vector2(s.x * 0.5 - 10, seam_y - 8), Vector2(20, 22)), UITokens.GOLD_300)


# --- C4–C6 ---

func _deal_cards() -> void:
	var n: int = _items.size()
	var card_size: Vector2 = Vector2(120, 160) if n == 1 else Vector2(62, 84)
	var cols: int = 1 if n == 1 else 5
	var gap: float = 8.0
	var rows: int = ceili(float(n) / cols)
	var total: Vector2 = Vector2(cols * card_size.x + (cols - 1) * gap, rows * card_size.y + (rows - 1) * gap)
	var origin: Vector2 = Vector2((_stage.size.x - total.x) * 0.5, _stage.size.y - total.y - 10.0) if n > 1 else (_stage.size - card_size) * 0.5
	var from: Vector2 = _chest_box.position + _chest_box.size * 0.5 - card_size * 0.5
	var t: Tween = UIMotion.tween(self)
	t.set_parallel(true)
	for i: int in n:
		var card: Control = _make_card(_items[i], card_size)
		card.position = from
		card.scale = Vector2.ONE * 0.3
		_cards_root.add_child(card)
		_cards.append(card)
		var target: Vector2 = origin + Vector2((i % cols) * (card_size.x + gap), floori(float(i) / cols) * (card_size.y + gap))
		t.tween_property(card, ^"position", target, 0.45).set_delay(i * 0.04).set_custom_interpolator(UIMotion.settle)
		t.tween_property(card, ^"scale", Vector2.ONE, 0.45).set_delay(i * 0.04)
		t.tween_property(card, ^"rotation", TAU * 1.5, 0.45).from(0.0).set_delay(i * 0.04)
	var fade: Tween = UIMotion.tween(_chest_box)
	fade.tween_property(_chest_box, ^"modulate:a", 0.0 if n > 1 else 0.3, 0.3)
	await t.finished
	for card: Control in _cards:
		card.rotation = 0.0
	if n == 1:
		await _flip(_cards[0])
		_finish()
	else:
		_open_all.visible = true


func _make_card(item: PlayerProfile.GearItem, card_size: Vector2) -> Control:
	var card: Control = Control.new()
	card.size = card_size
	card.pivot_offset = card_size * 0.5
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.set_meta(&"item", item)
	card.set_meta(&"revealed", false)
	card.draw.connect(_draw_card_back.bind(card))
	card.gui_input.connect(_on_card_input.bind(card))
	var cell: GearCell = GearCell.new().setup(item, minf(card_size.x, card_size.y - 20.0))
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.visible = false
	cell.position = Vector2((card_size.x - cell.cell_size) * 0.5, 0)
	cell.name = "Cell"
	card.add_child(cell)
	var caption: Label = UIKit.mono(GearText.rarity_name(item.rarity).to_upper(), GearText.rarity_color(item.rarity), HORIZONTAL_ALIGNMENT_CENTER)
	caption.add_theme_font_size_override(&"font_size", 7 if card_size.x < 100.0 else 11)
	caption.clip_text = true
	caption.position = Vector2(0, card_size.y - 16)
	caption.size = Vector2(card_size.x, 14)
	caption.visible = false
	caption.name = "Caption"
	card.add_child(caption)
	return card


func _draw_card_back(card: Control) -> void:
	if bool(card.get_meta(&"revealed")):
		return
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = UITokens.INK_600
	box.border_color = UITokens.LINE_STRONG
	box.set_border_width_all(1)
	box.set_corner_radius_all(UITokens.R14)
	box.draw(card.get_canvas_item(), Rect2(Vector2.ZERO, card.size))
	var c: Vector2 = card.size * 0.5
	card.draw_arc(c, card.size.x * 0.22, 0.0, TAU, 24, Color(UITokens.RUNE, 0.5), 1.5)
	card.draw_circle(c, 3.0, Color(UITokens.RUNE, 0.7))


func _on_card_input(event: InputEvent, card: Control) -> void:
	var tapped: bool = (event is InputEventMouseButton and (event as InputEventMouseButton).pressed) \
		or (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed)
	if tapped and not bool(card.get_meta(&"revealed")) and not _revealing:
		await _flip(card)
		_check_done()


## C5: флип; длительность и эффект — по редкости.
func _flip(card: Control) -> void:
	var item: PlayerProfile.GearItem = card.get_meta(&"item")
	var d: float = float(FLIP_S.get(item.rarity, 0.24))
	var t: Tween = UIMotion.tween(card)
	t.tween_property(card, ^"scale:x", 0.0, d * 0.5)
	await t.finished
	card.set_meta(&"revealed", true)
	(card.get_node(^"Cell") as Control).visible = true
	(card.get_node(^"Caption") as Control).visible = true
	card.queue_redraw()
	var back: Tween = UIMotion.tween(card)
	back.tween_property(card, ^"scale:x", 1.0, d * 0.5).set_custom_interpolator(UIMotion.settle)
	var rank: int = GearService.RARITIES.find(item.rarity)
	FeedbackManager.haptic(&"heavy" if rank >= 3 else (&"medium" if rank == 2 else &"light"))
	await back.finished


func _reveal_all() -> void:
	if _revealing:
		return
	_revealing = true
	_open_all.visible = false
	for card: Control in _cards:
		if bool(card.get_meta(&"revealed")):
			continue
		await _flip(card)
		await get_tree().create_timer(0.12, true, false, true).timeout
		var item: PlayerProfile.GearItem = card.get_meta(&"item")
		if GearService.RARITIES.find(item.rarity) >= 3 and _has_hidden():
			_open_all.visible = true # стоп на Эпическом+: продолжить — снова «Открыть все»
			break
	_revealing = false
	_check_done()


func _has_hidden() -> bool:
	for card: Control in _cards:
		if not bool(card.get_meta(&"revealed")):
			return true
	return false


func _check_done() -> void:
	if not _has_hidden():
		_finish()


## C6: бейджи «НОВЫЙ», «2/3», «↑» и кнопки через 600 мс.
func _finish() -> void:
	_open_all.visible = false
	var profile: PlayerProfile = GameManager.profile
	for card: Control in _cards:
		var cell: GearCell = card.get_node(^"Cell") as GearCell
		var it: PlayerProfile.GearItem = cell.item
		cell.badge_up = GearService.can_level_up(profile, it)
		cell.badge_merge = GearService.can_merge_rarity(it.rarity) and GearService.merge_partners(profile, it).size() >= GearService.merge_count()
		cell.queue_redraw()
		var partners: int = GearService.merge_partners(profile, it).size()
		if GearService.can_merge_rarity(it.rarity) and partners > 1 and partners < GearService.merge_count():
			var badge: Label = UIKit.mono("%d/%d" % [partners, GearService.merge_count()], UITokens.SPARK)
			badge.position = Vector2(4, -14)
			card.add_child(badge)
	var take: GlowButton = UIKit.button(tr("Забрать"), GlowButton.Variant.PRIMARY, SceneRouter.close_top)
	_buttons.add_child(take)
	var gear: GlowButton = UIKit.button(tr("К экипировке"), GlowButton.Variant.QUIET, _to_gear)
	_buttons.add_child(gear)
	UIMotion.appear(take, UITokens.T_BASE_S, 0.6)
	UIMotion.appear(gear, UITokens.T_BASE_S, 0.6)


func _to_gear() -> void:
	SceneRouter.go(&"S12")


## Тап по фону в C1–C4 — ускорение ×3.
func _on_bg_input(event: InputEvent) -> void:
	var tapped: bool = (event is InputEventMouseButton and (event as InputEventMouseButton).pressed) \
		or (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed)
	if tapped and _intro != null and _intro.is_valid():
		_intro.set_speed_scale(3.0)
