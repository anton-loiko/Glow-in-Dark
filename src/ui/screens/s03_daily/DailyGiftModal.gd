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
	var note_text: String = tr("Серия прервётся, если пропустить день") + " · " + tr("до сброса %d ч") % ceili(_seconds_to_midnight() / 3600.0)
	var note: Label = UIKit.label(note_text, &"body_s", UITokens.TEXT_MUTED)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(note)
	# Две строки: дни 1–4 и 5–6 + широкий эпический день 7 (DS S03).
	var rows: Array[HBoxContainer] = [UIKit.hbox(UITokens.S2), UIKit.hbox(UITokens.S2)]
	for row: HBoxContainer in rows:
		content.add_child(row)
	var days: Array = DailyGiftService.days()
	for i: int in days.size():
		var day: int = i + 1
		var state: StringName = &"future"
		if day < today_day or (day == today_day and claimed_today):
			state = &"done"
		elif day == today_day:
			state = &"now"
		var tile: Control = _tile(day, days[i] as Dictionary, state, day == days.size())
		rows[0 if i < 4 else 1].add_child(tile)
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


const ICONS: Dictionary = {
	"sparks": preload("res://src/assets/ui/icons/cur_spark.png"),
	"crystals": preload("res://src/assets/ui/icons/cur_crystal.png"),
	"item": preload("res://src/assets/ui/gear/hood_lamplighter.png"),
	"chest": preload("res://src/assets/chests/chest_epic_closed.png"),
}


## Прошлый день — заливка + ✓ · текущий — свечение + «СЕЙЧАС» · будущий — пунктир (правило 6 DS).
func _tile(day: int, reward: Dictionary, state: StringName, epic: bool) -> Control:
	var tile: PanelContainer = PanelContainer.new()
	var box_style: StyleBoxFlat = StyleBoxFlat.new()
	box_style.set_corner_radius_all(UITokens.R16)
	box_style.set_content_margin_all(6)
	box_style.anti_aliasing = true
	var accent: Color = (UITokens.RARITY[&"epic"] as Dictionary)["300"] if epic else UITokens.LIGHT_500
	match state:
		&"done":
			box_style.bg_color = Color(UITokens.LIGHT_900, 0.35)
		&"now":
			box_style.bg_color = Color(UITokens.LIGHT_500, 0.14)
			box_style.border_color = UITokens.LIGHT_500
			box_style.set_border_width_all(1)
			box_style.shadow_color = Color(UITokens.LIGHT_500, 0.3)
			box_style.shadow_size = 8
		_:
			box_style.bg_color = Color((UITokens.RARITY[&"epic"] as Dictionary)["bg"], 0.8) if epic else Color(0, 0, 0, 0)
			tile.draw.connect(_draw_dashed.bind(tile, Color(accent, 0.5) if epic else UITokens.LINE_STRONG))
	tile.add_theme_stylebox_override(&"panel", box_style)
	tile.custom_minimum_size = Vector2(0, 88)
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile.size_flags_stretch_ratio = 2.1 if epic else 1.0
	var box: VBoxContainer = UIKit.vbox(4, BoxContainer.ALIGNMENT_CENTER)
	tile.add_child(box)
	var eyebrow: String = tr("Сейчас") if state == &"now" else (tr("День %d · эпик") % day if epic else tr("День %d") % day)
	var eyebrow_color: Color = UITokens.LIGHT_500 if state == &"now" else (accent if epic else UITokens.TEXT_MUTED)
	box.add_child(UIKit.mono(eyebrow, eyebrow_color, HORIZONTAL_ALIGNMENT_CENTER))
	var kind: String = ""
	for key: String in ICONS:
		if reward.has(key):
			kind = key
	var icon: TextureRect = TextureRect.new()
	icon.texture = ICONS.get(kind, null)
	icon.custom_minimum_size = Vector2(26, 26) if kind in ["sparks", "crystals"] else Vector2(34, 30)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.modulate = {"sparks": UITokens.SPARK, "crystals": UITokens.CRYSTAL_500}.get(kind, Color.WHITE)
	if state == &"future":
		icon.modulate = Color(icon.modulate, 0.35) if not epic else icon.modulate
	elif state == &"done":
		icon.modulate = Color(icon.modulate, 0.55)
	box.add_child(icon)
	var value: String = "✓" if state == &"done" else _reward_text(reward)
	var value_color: Color = UITokens.TEXT_PRIMARY if state == &"now" else (accent if epic else UITokens.TEXT_MUTED)
	var value_label: Label = UIKit.label(value, &"number" if not epic else &"body_s", value_color, HORIZONTAL_ALIGNMENT_CENTER)
	value_label.add_theme_font_size_override(&"font_size", 12)
	box.add_child(value_label)
	return tile


func _draw_dashed(tile: Control, color: Color) -> void:
	var pts: PackedVector2Array = ButtonFace.rounded_rect(Rect2(Vector2.ONE, tile.size - Vector2.ONE * 2.0), UITokens.R16)
	pts.append(pts[0])
	for i: int in pts.size() - 1:
		tile.draw_dashed_line(pts[i], pts[i + 1], color, 1.0, 5.0)


func _reward_text(reward: Dictionary) -> String:
	if reward.has("sparks"):
		return UIKit.format_number(int(reward["sparks"]))
	if reward.has("crystals"):
		return str(int(reward["crystals"]))
	return tr(str(reward.get("label", "")))
