extends Control
## S03 · Дар дня (DS S03): прошлые дни — заливка + ✓, текущий — свечение + «СЕЙЧАС», будущие — пунктир.
## «Забрать» (Primary) и «▶ Забрать ×2» (Secondary, RV-плейсмент daily_x2). После выдачи модал закрывается.

var _frame: ModalFrame
var _claim: GlowButton
var _double: GlowButton


func _ready() -> void:
	_frame = ModalFrame.new()
	add_child(_frame)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var content: VBoxContainer = _frame.build(tr("Дар дня"), true, tr("7 дней света"))
	var profile: PlayerProfile = GameManager.profile
	var today_day: int = DailyGiftService.current_day(profile)
	var claimed_today: bool = not DailyGiftService.is_available(profile)
	var note_text: String = tr("Серия прервётся, если пропустить день")
	if claimed_today:
		note_text += " · " + tr("до сброса %d ч") % ceili(_seconds_to_midnight() / 3600.0)
	var note: Label = UIKit.label(note_text, &"body_s", UITokens.TEXT_MUTED)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(note)
	var grid: GridContainer = GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override(&"h_separation", UITokens.S2)
	grid.add_theme_constant_override(&"v_separation", UITokens.S2)
	content.add_child(grid)
	var days: Array = DailyGiftService.days()
	for i: int in days.size():
		var day: int = i + 1
		var state: StringName = &"future"
		if day < today_day or (day == today_day and claimed_today):
			state = &"done"
		elif day == today_day:
			state = &"now"
		grid.add_child(_tile(day, days[i] as Dictionary, state))
	_claim = UIKit.button(tr("Забрать"), GlowButton.Variant.PRIMARY, _claim_reward.bind(1))
	_double = UIKit.ad_button(tr("Забрать ×2"), GlowButton.Variant.SECONDARY, &"daily_x2")
	content.add_child(_claim)
	content.add_child(_double)
	if claimed_today:
		_claim.set_blocked(true, tr("Уже получено сегодня"))
		_double.visible = false
	EventBus.ad_reward_granted.connect(_on_ad_reward)


## День считается по локальной полуночи (DailyGiftService.today).
func _seconds_to_midnight() -> int:
	var now: Dictionary = Time.get_datetime_dict_from_system()
	return 86400 - (int(now["hour"]) * 3600 + int(now["minute"]) * 60 + int(now["second"]))


func _on_ad_reward(placement: StringName) -> void:
	if placement == &"daily_x2":
		_claim_reward(2)


func _claim_reward(multiplier: int) -> void:
	var reward: Dictionary = DailyGiftService.claim(GameManager.profile, multiplier)
	if reward.is_empty():
		return
	FeedbackManager.haptic(&"success")
	_frame.close_modal()


func _tile(day: int, reward: Dictionary, state: StringName) -> Control:
	var tile: PanelContainer = UIKit.panel(&"PanelCard")
	var compact: StyleBoxFlat = StyleBoxFlat.new()
	compact.bg_color = UITokens.INK_600
	compact.set_corner_radius_all(UITokens.R16)
	compact.set_content_margin_all(6)
	tile.add_theme_stylebox_override(&"panel", compact)
	tile.custom_minimum_size = Vector2(72, 84)
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box: VBoxContainer = UIKit.vbox(UITokens.S1, BoxContainer.ALIGNMENT_CENTER)
	tile.add_child(box)
	var eyebrow: String = tr("Сейчас") if state == &"now" else tr("День %d") % day
	box.add_child(UIKit.mono(eyebrow, UITokens.LIGHT_500 if state == &"now" else UITokens.TEXT_MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	var value: String = "✓" if state == &"done" else _reward_text(reward)
	var value_label: Label = UIKit.label(value, &"number", UITokens.TEXT_PRIMARY, HORIZONTAL_ALIGNMENT_CENTER)
	value_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	value_label.custom_minimum_size.x = 58
	value_label.add_theme_font_size_override(&"font_size", 12)
	box.add_child(value_label)
	if state == &"now":
		var glow: StyleBoxFlat = StyleBoxFlat.new()
		glow.bg_color = Color(UITokens.LIGHT_500, 0.14)
		glow.border_color = UITokens.LIGHT_500
		glow.set_border_width_all(1)
		glow.set_corner_radius_all(UITokens.R16)
		glow.set_content_margin_all(6)
		glow.shadow_color = Color(UITokens.LIGHT_500, 0.3)
		glow.shadow_size = 8
		tile.add_theme_stylebox_override(&"panel", glow)
	elif state == &"future":
		tile.modulate.a = 0.6
	return tile


func _reward_text(reward: Dictionary) -> String:
	if reward.has("sparks"):
		return "● " + UIKit.format_number(int(reward["sparks"]))
	if reward.has("crystals"):
		return "◆ " + str(int(reward["crystals"]))
	return tr(str(reward.get("label", "")))
