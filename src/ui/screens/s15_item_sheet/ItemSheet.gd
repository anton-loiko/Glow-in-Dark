extends Control
## S15 · Лист предмета (Gear DS §02): bottom sheet 640pt, r26. Primary «УЛУЧШИТЬ · Ур. N · цена» (удержание
## 500 → 150 мс за 2 с), «Надеть»/«Снять», «Слияние · k/3», «Разобрать · +N ✦» (подтверждение, если надет или ур. 10+).
## L-анимации: вспышка рамки 120 мс и «+Δ» (gain) над статом на каждый уровень, кольцо-волна каждые 5 ур.
## params: uid.

const SHEET_H: float = 640.0

var _uid: String = ""
var _panel: PanelContainer
var _cell: GearCell
var _title: Label
var _meta: Label
var _stat: Label
var _next: Label
var _upgrade: GlowButton
var _equip: GlowButton
var _merge: GlowButton
var _dismantle: GlowButton
var _dismantle_armed: bool = false
var _holding: bool = false
var _held_s: float = 0.0
var _next_step_s: float = 0.0


func on_screen_enter(params: Dictionary) -> void:
	_uid = str(params.get("uid", ""))
	var item: PlayerProfile.GearItem = GameManager.profile.find_gear(_uid)
	if item == null:
		SceneRouter.close_top.call_deferred()
		return
	if item.is_new:
		item.is_new = false
		SaveManager.request_save()
	_build()
	_refresh()


func _build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(UITokens.INK_900, 0.7)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(_on_dim_input)
	add_child(dim)
	_panel = PanelContainer.new()
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = UITokens.INK_700
	style.border_color = UITokens.LINE_STRONG
	style.border_width_top = 1
	style.corner_radius_top_left = 26
	style.corner_radius_top_right = 26
	style.content_margin_left = UITokens.S5
	style.content_margin_right = UITokens.S5
	style.content_margin_top = UITokens.S3
	style.content_margin_bottom = UITokens.S5 + UITokens.SAFE_BOTTOM
	_panel.add_theme_stylebox_override(&"panel", style)
	_panel.anchor_left = 0.0
	_panel.anchor_right = 1.0
	_panel.anchor_top = 1.0
	_panel.anchor_bottom = 1.0
	_panel.offset_top = -SHEET_H
	add_child(_panel)
	var box: VBoxContainer = UIKit.vbox(UITokens.S3)
	_panel.add_child(box)
	var grabber: Control = Control.new()
	grabber.custom_minimum_size = Vector2(0, 8)
	grabber.draw.connect(_draw_grabber.bind(grabber))
	box.add_child(grabber)
	var head: HBoxContainer = UIKit.hbox(UITokens.S4)
	box.add_child(head)
	var item: PlayerProfile.GearItem = GameManager.profile.find_gear(_uid)
	_cell = GearCell.new().setup(item, 96.0)
	head.add_child(_cell)
	var titles: VBoxContainer = UIKit.vbox(UITokens.S1, BoxContainer.ALIGNMENT_CENTER)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(titles)
	_meta = UIKit.mono("")
	titles.add_child(_meta)
	_title = UIKit.label("", &"h2")
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	titles.add_child(_title)
	var close: Button = Button.new()
	close.theme_type_variation = &"ButtonQuiet"
	close.text = "✕"
	close.custom_minimum_size = Vector2(32, 32)
	close.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	close.pressed.connect(SceneRouter.close_top)
	head.add_child(close)

	var stat_card: PanelContainer = UIKit.panel(&"PanelCard")
	box.add_child(stat_card)
	var stat_box: VBoxContainer = UIKit.vbox(UITokens.S1)
	stat_card.add_child(stat_box)
	stat_box.add_child(UIKit.mono(tr("Бонус")))
	_stat = UIKit.label("", &"h2", UITokens.TEXT_PRIMARY)
	stat_box.add_child(_stat)
	_next = UIKit.label("", &"body_s", UITokens.TEXT_MUTED)
	stat_box.add_child(_next)
	box.add_child(UIKit.spacer())

	_upgrade = UIKit.button(tr("Улучшить"), GlowButton.Variant.PRIMARY, Callable())
	_upgrade.button_down.connect(_on_upgrade_down)
	_upgrade.button_up.connect(_on_upgrade_up)
	box.add_child(_upgrade)
	var row: HBoxContainer = UIKit.hbox(UITokens.S2)
	box.add_child(row)
	_equip = UIKit.button(tr("Надеть"), GlowButton.Variant.SECONDARY, _toggle_equip)
	_equip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_equip)
	_merge = UIKit.button(tr("Слияние"), GlowButton.Variant.SECONDARY, _open_merge)
	_merge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_merge)
	_dismantle = UIKit.button(tr("Разобрать"), GlowButton.Variant.QUIET, _on_dismantle)
	box.add_child(_dismantle)
	_panel.position.y += SHEET_H
	var t: Tween = UIMotion.tween(_panel)
	t.tween_property(_panel, ^"position:y", _panel.position.y - SHEET_H, UITokens.T_SLOW_S).set_custom_interpolator(UIMotion.settle)


func _draw_grabber(grabber: Control) -> void:
	var cx: float = grabber.size.x * 0.5
	grabber.draw_line(Vector2(cx - 20, 3), Vector2(cx + 20, 3), UITokens.LINE_STRONG, 4.0)


func _refresh() -> void:
	var profile: PlayerProfile = GameManager.profile
	var item: PlayerProfile.GearItem = profile.find_gear(_uid)
	if item == null:
		return
	var max_lv: int = GearService.max_level(item.rarity)
	_meta.text = ("%s · %s" % [GearText.rarity_name(item.rarity), GearText.slot_name(item.slot)]).to_upper()
	_meta.add_theme_color_override(&"font_color", GearText.rarity_color(item.rarity))
	_title.text = GearText.item_name(item)
	var stat: StringName = GearText.stat_item(item)
	_stat.text = GearText.stat_text(stat, GearService.stat_value(item))
	if item.level < max_lv:
		_next.text = tr("Ур. %d / %d · на ур. %d: %s") % [item.level, max_lv, item.level + 1, GearText.stat_text(stat, GearService.stat_value(item, item.level + 1))]
		var cost: int = GearService.cost_to(item.rarity, item.level + 1)
		_upgrade.set_label(tr("Улучшить · Ур. %d · %s ✦") % [item.level + 1, UIKit.format_number(cost)])
		if profile.sparks < cost:
			_upgrade.set_blocked(true, tr("Нужно ещё %s ✦") % UIKit.format_number(cost - profile.sparks))
		else:
			_upgrade.set_blocked(false)
	else:
		_next.text = tr("Ур. %d / %d · максимум редкости") % [item.level, max_lv]
		_upgrade.set_blocked(true, tr("Нужно слияние для ур. %d") % (max_lv + 1))
	_equip.set_label(tr("Снять") if GearService.is_equipped(profile, _uid) else tr("Надеть"))
	var partners: int = GearService.merge_partners(profile, item).size()
	if GearService.can_merge_rarity(item.rarity):
		_merge.set_label(tr("Слияние · %d/%d") % [mini(partners, GearService.merge_count()), GearService.merge_count()])
		_merge.set_blocked(false)
	else:
		_merge.set_blocked(true, tr("Слияние недоступно"))
	var refund: int = item.sparks_invested
	if _dismantle_armed:
		_dismantle.set_label(tr("Точно разобрать? +%s ✦") % UIKit.format_number(refund))
	else:
		_dismantle.set_label(tr("Разобрать · +%s ✦") % UIKit.format_number(refund))
	_cell.item = item
	_cell.equipped = GearService.is_equipped(profile, _uid)
	_cell.queue_redraw()


func _process(delta: float) -> void:
	if not _holding:
		return
	_held_s += delta
	_next_step_s -= delta
	if _next_step_s <= 0.0:
		_next_step_s += _interval_s()
		if not _level_up_once():
			_holding = false


func _interval_s() -> float:
	var hold: Dictionary = GearService.config().get("hold", {}) as Dictionary
	var k: float = clampf(_held_s * 1000.0 / float(hold.get("ramp_ms", 2000)), 0.0, 1.0)
	return lerpf(float(hold.get("start_ms", 500)), float(hold.get("min_ms", 150)), k) / 1000.0


func _on_upgrade_down() -> void:
	if _upgrade.disabled:
		return
	_holding = true
	_held_s = 0.0
	_next_step_s = _interval_s()
	_level_up_once()


func _on_upgrade_up() -> void:
	if _holding:
		SaveManager.request_save()
	_holding = false


func _level_up_once() -> bool:
	var item: PlayerProfile.GearItem = GameManager.profile.find_gear(_uid)
	if item == null:
		return false
	var before: float = GearService.stat_value(item)
	if not GearService.level_up(GameManager.profile, _uid):
		return false
	FeedbackManager.haptic(&"light")
	_float_delta(GearService.stat_value(item) - before)
	_flash_frame(item.level % 5 == 0)
	_refresh()
	return not _upgrade.disabled


## «+Δ» (gain) всплывает над статом.
func _float_delta(delta: float) -> void:
	var label: Label = UIKit.label(("+" if delta >= 0.0 else "−") + GearText.num(absf(delta)), &"number", UITokens.GAIN)
	label.top_level = true
	add_child(label)
	label.global_position = _stat.global_position + Vector2(_stat.size.x * 0.6, -4)
	var t: Tween = UIMotion.tween(label)
	t.tween_property(label, ^"global_position:y", label.global_position.y - 28, 0.5)
	t.parallel().tween_property(label, ^"modulate:a", 0.0, 0.5)
	t.tween_callback(label.queue_free)


## Вспышка рамки 120 мс; каждые 5 уровней — кольцо-волна.
func _flash_frame(ring: bool) -> void:
	_cell.modulate = Color(1.6, 1.6, 1.6)
	var t: Tween = UIMotion.tween(_cell)
	t.tween_property(_cell, ^"modulate", Color.WHITE, 0.12)
	if ring:
		_cell.pivot_offset = _cell.size * 0.5
		var r: Tween = UIMotion.tween(_cell)
		r.tween_property(_cell, ^"scale", Vector2.ONE * 1.08, 0.1)
		r.tween_property(_cell, ^"scale", Vector2.ONE, 0.2).set_custom_interpolator(UIMotion.settle)
		FeedbackManager.haptic(&"medium")


func _toggle_equip() -> void:
	var profile: PlayerProfile = GameManager.profile
	if GearService.is_equipped(profile, _uid):
		for slot: StringName in profile.gear_equipped:
			if profile.gear_equipped[slot] == _uid:
				GearService.unequip(profile, slot)
				break
	else:
		GearService.equip(profile, _uid)
	_refresh()


func _open_merge() -> void:
	SceneRouter.close_top()
	SceneRouter.open_modal(&"S16", {"uid": _uid})


func _on_dismantle() -> void:
	var profile: PlayerProfile = GameManager.profile
	var item: PlayerProfile.GearItem = profile.find_gear(_uid)
	if item == null:
		return
	var needs_confirm: bool = GearService.is_equipped(profile, _uid) or item.level >= 10
	if needs_confirm and not _dismantle_armed:
		_dismantle_armed = true
		_refresh()
		return
	var refund: int = GearService.dismantle(profile, _uid)
	EventBus.toast_requested.emit(tr("Разобрано: +%s Искр") % UIKit.format_number(refund), &"sparks")
	SceneRouter.close_top()


func _on_dim_input(event: InputEvent) -> void:
	var tapped: bool = (event is InputEventMouseButton and (event as InputEventMouseButton).pressed) \
		or (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed)
	if tapped:
		SceneRouter.close_top()
