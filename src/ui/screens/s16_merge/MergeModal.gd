extends Control
## S16 · Слияние 3 → 1 (Gear DS §02, gear_system.md §3): три одинаковых предмета одной редкости → редкость выше.
## Основа — предмет с максимальным уровнем (уровень сохраняется), Искры двух других возвращаются 100%.
## «Заполнить автоматически» не трогает надетый. Подтверждение — если участвует надетый или ур. 10+.
## M1–M6 (2.2 с): подъём → спираль к центру → hit-stop + белое ядро → смена рамки + частицы → штамп → «было → стало».
## params: uid (необязательно) — предмет, с которого начать.

var _frame: ModalFrame
var _content: VBoxContainer
var _slots_row: HBoxContainer
var _grid: GridContainer
var _merge_button: GlowButton
var _auto_button: GlowButton
var _picked: Array[String] = []
var _armed: bool = false
var _stage: Control
var _busy: bool = false


func on_screen_enter(params: Dictionary) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_frame = ModalFrame.new()
	add_child(_frame)
	_content = _frame.build(tr("Слияние"), true, tr("3 → 1"))
	var uid: String = str(params.get("uid", ""))
	var item: PlayerProfile.GearItem = GameManager.profile.find_gear(uid)
	if item != null:
		_picked = GearService.auto_pick(GameManager.profile, item)
		if not _picked.has(uid) and _picked.size() < GearService.merge_count():
			_picked.push_front(uid)
	_stage = Control.new()
	_stage.custom_minimum_size = Vector2(0, 110)
	_content.add_child(_stage)
	_slots_row = UIKit.hbox(UITokens.S4, BoxContainer.ALIGNMENT_CENTER)
	_slots_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stage.add_child(_slots_row)
	var hint: Label = UIKit.label(tr("Основа — предмет с высшим уровнем. Искры двух других вернутся."), &"body_s", UITokens.TEXT_MUTED)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size.x = 300
	_content.add_child(hint)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 200)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_content.add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = 4
	_grid.add_theme_constant_override(&"h_separation", 10)
	_grid.add_theme_constant_override(&"v_separation", 10)
	scroll.add_child(_grid)
	_auto_button = UIKit.button(tr("Заполнить автоматически"), GlowButton.Variant.SECONDARY, _auto_fill)
	_content.add_child(_auto_button)
	_merge_button = UIKit.button(tr("Слить"), GlowButton.Variant.PRIMARY, _on_merge)
	_content.add_child(_merge_button)
	_refresh()


func _refresh() -> void:
	var profile: PlayerProfile = GameManager.profile
	for child: Node in _slots_row.get_children():
		child.queue_free()
	for i: int in GearService.merge_count():
		var it: PlayerProfile.GearItem = profile.find_gear(_picked[i]) if i < _picked.size() else null
		var cell: GearCell = GearCell.new().setup(it, 76.0)
		if it == null and not _picked.is_empty():
			cell.slot = profile.find_gear(_picked[0]).slot
		cell.pressed.connect(_on_slot_pressed)
		_slots_row.add_child(cell)
	for child: Node in _grid.get_children():
		child.queue_free()
	var anchor: PlayerProfile.GearItem = profile.find_gear(_picked[0]) if not _picked.is_empty() else null
	var candidates: Array[PlayerProfile.GearItem] = []
	for it: PlayerProfile.GearItem in profile.gear_inventory:
		if not GearService.can_merge_rarity(it.rarity):
			continue
		if anchor != null and (it.base_id != anchor.base_id or it.rarity != anchor.rarity):
			continue
		if anchor == null and GearService.merge_partners(profile, it).size() < GearService.merge_count():
			continue
		candidates.append(it)
	for it: PlayerProfile.GearItem in candidates:
		var cell: GearCell = GearCell.new().setup(it, 62.0)
		cell.selected = _picked.has(it.uid)
		cell.equipped = GearService.is_equipped(profile, it.uid)
		cell.pressed.connect(_on_candidate_pressed)
		_grid.add_child(cell)
	if candidates.is_empty():
		var empty: Label = UIKit.label(tr("Нужно 3 одинаковых предмета одной редкости"), &"body_s", UITokens.TEXT_MUTED)
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.custom_minimum_size.x = 280
		_grid.add_child(empty)
	var is_full: bool = _picked.size() == GearService.merge_count()
	_auto_button.visible = anchor != null and not is_full
	if not is_full:
		_merge_button.set_blocked(true, tr("Выберите %d/%d") % [_picked.size(), GearService.merge_count()])
	else:
		_merge_button.set_blocked(false)
		var to: StringName = GearService.RARITIES[GearService.RARITIES.find(anchor.rarity) + 1]
		var label: String = tr("Слить → %s") % GearText.rarity_name(to)
		if _armed:
			label = tr("Точно слить? Участвует надетый или ур. 10+")
		_merge_button.set_label(label)


func _on_candidate_pressed(cell: GearCell) -> void:
	if _busy:
		return
	_armed = false
	if _picked.has(cell.item.uid):
		_picked.erase(cell.item.uid)
	elif _picked.size() < GearService.merge_count():
		_picked.append(cell.item.uid)
	_refresh()


func _on_slot_pressed(cell: GearCell) -> void:
	if _busy or cell.item == null:
		return
	_armed = false
	_picked.erase(cell.item.uid)
	_refresh()


func _auto_fill() -> void:
	var anchor: PlayerProfile.GearItem = GameManager.profile.find_gear(_picked[0]) if not _picked.is_empty() else null
	if anchor == null:
		return
	_picked = GearService.auto_pick(GameManager.profile, anchor)
	_refresh()


func _needs_confirm() -> bool:
	for uid: String in _picked:
		var it: PlayerProfile.GearItem = GameManager.profile.find_gear(uid)
		if GearService.is_equipped(GameManager.profile, uid) or (it != null and it.level >= 10):
			return true
	return false


func _on_merge() -> void:
	if _busy or _picked.size() != GearService.merge_count():
		return
	if _needs_confirm() and not _armed:
		_armed = true
		_refresh()
		return
	var profile: PlayerProfile = GameManager.profile
	var from_rarity: StringName = profile.find_gear(_picked[0]).rarity
	var from_max: int = GearService.max_level(from_rarity)
	var sparks_before: int = profile.sparks
	var cells: Array[GearCell] = []
	for child: Node in _slots_row.get_children():
		cells.append(child as GearCell)
	var result: PlayerProfile.GearItem = GearService.merge(profile, _picked.duplicate())
	if result == null:
		return
	_busy = true
	_merge_button.visible = false
	_auto_button.visible = false
	await _animate(cells, result)
	_show_result(result, from_rarity, from_max, profile.sparks - sparks_before)


## M1–M5: подъём → спираль к центру → hit-stop + белое ядро → новая рамка со штампом.
func _animate(cells: Array[GearCell], result: PlayerProfile.GearItem) -> void:
	var center: Vector2 = _stage.size * 0.5
	# Карты уходят из HBox в свободный слой, чтобы контейнер не перераскладывал их во время полёта.
	for cell: GearCell in cells:
		cell.reparent(_stage)
		cell.pivot_offset = cell.size * 0.5
	var t: Tween = UIMotion.tween(self)
	t.set_parallel(true)
	for cell: GearCell in cells:
		t.tween_property(cell, ^"position:y", cell.position.y - 10.0, 0.3)
	t.chain().tween_interval(0.0)
	t.set_parallel(true)
	for cell: GearCell in cells:
		var target: Vector2 = center - cell.size * 0.5
		t.tween_property(cell, ^"position", target, 0.7).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		t.tween_property(cell, ^"rotation", TAU * 0.75, 0.7).set_ease(Tween.EASE_IN)
		t.tween_property(cell, ^"scale", Vector2.ONE * 0.4, 0.7).set_ease(Tween.EASE_IN)
	await t.finished
	FeedbackManager.haptic(&"heavy")
	for cell: GearCell in cells:
		cell.visible = false
	var core: ColorRect = ColorRect.new()
	core.color = Color(UITokens.LIGHT_500, 0.4) if GameManager.profile.settings.no_flashes else Color.WHITE
	core.size = Vector2(40, 40)
	core.position = center - core.size * 0.5
	core.pivot_offset = core.size * 0.5
	_stage.add_child(core)
	await get_tree().create_timer(0.06, true, false, true).timeout # hit-stop 60 мс
	var fx: Tween = UIMotion.tween(core)
	fx.tween_property(core, ^"scale", Vector2.ONE * 3.0, 0.08)
	fx.parallel().tween_property(core, ^"modulate:a", 0.0, 0.3)
	fx.tween_callback(core.queue_free)
	var new_cell: GearCell = GearCell.new().setup(result, 96.0)
	new_cell.position = center - Vector2(48, 48)
	new_cell.pivot_offset = Vector2(48, 48)
	new_cell.scale = Vector2.ONE * 0.2
	_stage.add_child(new_cell)
	var appear: Tween = UIMotion.tween(new_cell)
	appear.tween_property(new_cell, ^"scale", Vector2.ONE, 0.4).set_custom_interpolator(UIMotion.settle)
	await appear.finished
	FeedbackManager.haptic(&"success")


## M6: таблица «было → стало» и возврат Искр.
func _show_result(result: PlayerProfile.GearItem, from_rarity: StringName, from_max: int, refund: int) -> void:
	(_grid.get_parent() as Control).visible = false
	var table: VBoxContainer = UIKit.vbox(UITokens.S1)
	var stamp: Label = UIKit.label(GearText.rarity_name(result.rarity).to_upper(), &"h2", GearText.rarity_color(result.rarity), HORIZONTAL_ALIGNMENT_CENTER)
	table.add_child(stamp)
	table.add_child(_row(tr("Редкость"), GearText.rarity_name(from_rarity), GearText.rarity_name(result.rarity)))
	table.add_child(_row(tr("Уровень"), str(result.level), str(result.level)))
	table.add_child(_row(tr("Макс. уровень"), str(from_max), str(GearService.max_level(result.rarity))))
	if refund > 0:
		table.add_child(_row(tr("Возврат Искр"), "", "+" + UIKit.format_number(refund) + " ✦"))
	_content.add_child(table)
	_content.move_child(table, 2)
	UIMotion.appear(table)
	var done: GlowButton = UIKit.button(tr("Готово"), GlowButton.Variant.PRIMARY, _frame.close_modal)
	_content.add_child(done)
	UIMotion.appear(done, UITokens.T_BASE_S, 0.6)


func _row(title: String, before: String, after: String) -> Control:
	var row: HBoxContainer = UIKit.hbox()
	var name_label: Label = UIKit.label(title, &"body_s", UITokens.TEXT_SECONDARY)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	if not before.is_empty() and before != after:
		row.add_child(UIKit.label(before + "  →", &"body_s", UITokens.TEXT_MUTED))
	row.add_child(UIKit.label(after, &"number", UITokens.GAIN))
	return row
