class_name BeaconCutscene
extends Control
## Кат-сцена тира и вех (Meta DS §01): UI уходит → вспышка («Без белых вспышек» — янтарь 40%) →
## волна света → карточка баффа и награды. Тап ускоряет ×3, второй тап — сразу к карточке, третий — закрыть.
## Реклама и IAP в кат-сцену никогда не встраиваются.

signal finished(skipped: bool)
## Пик вспышки: диорама переключается на новый тир (параметры не интерполируются).
signal flash_peak

const MILESTONE_TITLES: Dictionary = {25: "Первое пламя", 50: "Руны", 75: "Луч", 100: "Абсолютный Свет"}

var _card: PanelContainer
var _flash: ColorRect
var _taps: int = 0
var _tween: Tween
var _done: bool = false
var _finish_skip: bool = false
var _milestone: int = 0


func play(chapter_id: int, tier: int, milestone: int) -> void:
	_milestone = milestone
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(UITokens.INK_900, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	_flash = ColorRect.new()
	var no_flashes: bool = GameManager.profile.settings.no_flashes
	_flash.color = Color(UITokens.LIGHT_500, 0.4) if no_flashes else Color(1, 1, 1, 0.9)
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.modulate.a = 0.0
	add_child(_flash)
	_card = _build_card(chapter_id, tier, milestone)
	_card.modulate.a = 0.0
	add_child(_card)
	FeedbackManager.cue(&"beacon_milestone" if milestone > 0 else &"beacon_tier")
	var cfg: Dictionary = BeaconService.config().get("cutscene", {}) as Dictionary
	var total: float = float((cfg.get("milestone_s", {}) as Dictionary).get(str(milestone), cfg.get("tier_s", 2.4))) if milestone > 0 else float(cfg.get("tier_s", 2.4))
	_tween = UIMotion.tween(self)
	_tween.tween_interval(total * 0.25)
	_tween.tween_property(_flash, ^"modulate:a", 1.0, 0.08)
	_tween.tween_callback(finished_flash)
	_tween.tween_property(_flash, ^"modulate:a", 0.0, total * 0.3)
	_tween.tween_property(_card, ^"modulate:a", 1.0, 0.3)
	_tween.tween_interval(total * 0.2)
	await _tween.finished
	_taps = maxi(_taps, 2)


func finished_flash() -> void:
	flash_peak.emit()
	var cutscene_cfg: Dictionary = BeaconService.config().get("cutscene", {}) as Dictionary
	var shake_cfg: Dictionary = cutscene_cfg.get("shake_pt", {}) as Dictionary
	if GameManager.profile.settings.camera_shake and get_parent() is Control:
		var pt: float = float(shake_cfg.get(str(_milestone), shake_cfg.get("tier", 2)))
		var target: Control = get_parent() as Control
		var t: Tween = UIMotion.tween(target)
		for i: int in 4:
			t.tween_property(target, ^"position:x", pt * (1.0 if i % 2 == 0 else -1.0) * (1.0 - i / 4.0), 0.05)
		t.tween_property(target, ^"position:x", 0.0, 0.05)


func _gui_input(event: InputEvent) -> void:
	var tapped: bool = (event is InputEventMouseButton and (event as InputEventMouseButton).pressed) or (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed)
	if not tapped or _done:
		return
	accept_event()
	_taps += 1
	if _taps == 1 and _tween != null and _tween.is_valid():
		_tween.set_speed_scale(3.0)
	elif _taps == 2 and _tween != null and _tween.is_valid():
		_tween.custom_step(60.0)
		_finish_skip = true
	elif _taps >= 3:
		_finish(_finish_skip)



func _finish(skipped: bool) -> void:
	_done = true
	finished.emit(skipped)
	queue_free()


func _build_card(chapter_id: int, tier: int, milestone: int) -> PanelContainer:
	var card: PanelContainer = UIKit.panel(&"PanelModal")
	card.anchor_left = 0.5
	card.anchor_right = 0.5
	card.anchor_top = 1.0
	card.anchor_bottom = 1.0
	card.offset_left = -165.0
	card.offset_right = 165.0
	card.offset_top = -340.0
	card.offset_bottom = -180.0
	card.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var box: VBoxContainer = UIKit.vbox(UITokens.S2)
	card.add_child(box)
	var pct: int = milestone if milestone > 0 else tier * BeaconService.levels_per_tier()
	box.add_child(UIKit.mono(tr("Маяк %d%%") % pct, UITokens.RUNE))
	var title: String = tr(MILESTONE_TITLES.get(milestone, "")) if milestone > 0 else tr("Тир %d зажжён") % tier
	box.add_child(UIKit.label(title, &"h1"))
	if milestone > 0 and tier > 0:
		box.add_child(UIKit.label(tr("Тир %d зажжён") % tier, &"body", UITokens.TEXT_SECONDARY))
	if tier <= 0:
		box.add_child(UIKit.mono(tr("Нажмите, чтобы продолжить"), UITokens.TEXT_MUTED))
		return card
	var buff_text: String = BeaconBuffText.buff(BeaconService.buff_for(tier))
	if not buff_text.is_empty():
		box.add_child(UIKit.label(buff_text, &"body", UITokens.GAIN))
	var reward_text: String = BeaconBuffText.reward(BeaconService.reward_for(chapter_id, tier))
	if not reward_text.is_empty():
		box.add_child(UIKit.label(reward_text, &"body", UITokens.LIGHT_500))
	box.add_child(UIKit.mono(tr("Нажмите, чтобы продолжить"), UITokens.TEXT_MUTED))
	return card
