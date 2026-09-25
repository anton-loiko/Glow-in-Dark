class_name LevelUpScreen
extends Control
## S06 · Левел-ап (Skills DS §01): три карточки сверху вниз ▲ → ■ → ●, Primary нет — тап по карте и есть выбор.
## Раздача с шагом 60 мс, ввод заблокирован 400 мс после раздачи. «Обновить»: 50 Искр забега → ▶ (1 раз за забег)
## → 10 ◆. «▶ Взять все три» — 1 раз за забег. Мир на паузе (SceneRouter), анимации в unscaled time.

const DEAL_STEP_S: float = 0.06
const FLIP_S: float = 0.32
const CHOSEN_S: float = 0.36

var run: RunContext
var _cards: Array[SkillCard] = []
var _cards_box: VBoxContainer
var _slots_label: Label
var _reroll_button: GlowButton
var _take_all_button: GlowButton
var _actions: HBoxContainer
var _slots: Control
var _title: Label
var _shown_at_ms: int = 0
var _busy: bool = false
var _rerolls_this_level: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	EventBus.ad_reward_granted.connect(_on_ad_reward)


func on_screen_enter(_params: Dictionary) -> void:
	run = GameManager.current_run
	if run == null:
		SceneRouter.close_top()
		return
	FeedbackManager.cue(&"level_up")
	_title.text = (tr("Уровень %d") % run.player_level).to_upper()
	_show_offer(SkillsManager.draw_offer(run))


func _build() -> void:
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(UITokens.INK_900, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var column: VBoxContainer = VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override(&"separation", UITokens.S4)
	add_child(column)
	_title = UIKit.mono("", UITokens.SPARK, HORIZONTAL_ALIGNMENT_CENTER)
	column.add_child(_title)
	column.add_child(UIKit.label(tr("Выбери усиление"), &"h1", UITokens.TEXT_PRIMARY, HORIZONTAL_ALIGNMENT_CENTER))
	_cards_box = VBoxContainer.new()
	_cards_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_cards_box.add_theme_constant_override(&"separation", 12)
	_cards_box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(_cards_box)
	column.add_child(_collected_row())
	var actions: HBoxContainer = HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override(&"separation", 12)
	column.add_child(actions)
	_actions = actions
	_reroll_button = _button(actions, _on_reroll_pressed, GlowButton.Variant.SECONDARY)
	_take_all_button = _button(actions, _on_take_all_pressed, GlowButton.Variant.SECONDARY)
	_take_all_button.ad = true
	_take_all_button.set_label(tr("Взять все три"))


func _show_offer(offer: Array[SkillOffer]) -> void:
	for card: SkillCard in _cards:
		card.queue_free()
	_cards.clear()
	for i: int in offer.size():
		var card: SkillCard = SkillCard.new()
		card.setup(offer[i], run.skill_level(offer[i].skill_id))
		card.modulate.a = 0.0
		card.chosen.connect(_on_card_chosen)
		_cards_box.add_child(card)
		_cards.append(card)
		var tween: Tween = create_tween().set_ignore_time_scale(true)
		tween.tween_interval(i * DEAL_STEP_S)
		tween.tween_property(card, ^"modulate:a", 1.0, FLIP_S).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var lock_s: float = offer.size() * DEAL_STEP_S + FLIP_S + float(SkillsManager.get_tuning().get("input_lock_ms", 400)) / 1000.0
	_shown_at_ms = Time.get_ticks_msec()
	get_tree().create_timer(lock_s, true, false, true).timeout.connect(_unlock_cards)
	_refresh_controls()


func _unlock_cards() -> void:
	for card: SkillCard in _cards:
		if is_instance_valid(card):
			card.locked = false


func _refresh_controls() -> void:
	var max_slots: int = int(SkillsManager.get_tuning().get("max_slots", 6))
	var used: int = run.slots_used()
	_slots_label.text = tr("Полный билд") if used >= max_slots else tr("Собрано")
	_slots.queue_redraw()
	_take_all_button.visible = not run.take_all_used
	if _take_all_button.visible:
		_take_all_button.set_blocked(not AdManager.is_rewarded_ready(&"skill_take_all"), tr("Реклама недоступна"))
		AdManager.note_opportunity(&"skill_take_all")
	# DS S06: 50 Искр → ▶ → 10 ◆ (кнопка становится Crystal).
	match _reroll_cost_type():
		&"sparks":
			var cost: int = _reroll_cfg("sparks", 50)
			_set_reroll(GlowButton.Variant.SECONDARY, false, tr("Обновить · %d ✦") % cost)
			_reroll_button.set_blocked(run.run_sparks < cost, tr("Нужно %d ✦") % cost)
		&"ad":
			_set_reroll(GlowButton.Variant.SECONDARY, true, tr("Обновить"))
			_reroll_button.set_blocked(not AdManager.is_rewarded_ready(&"skill_reroll"), tr("Реклама недоступна"))
			AdManager.note_opportunity(&"skill_reroll")
		_:
			var crystals: int = _reroll_cfg("crystals", 10)
			_set_reroll(GlowButton.Variant.CRYSTAL, false, tr("Обновить · %d ◆") % crystals)
			_reroll_button.set_blocked(not GameManager.can_afford(GameManager.CRYSTALS, crystals), tr("Нужно %d ◆") % crystals)


## Меняет вес кнопки «Обновить» пересозданием (вес задаётся при входе в дерево).
func _set_reroll(variant: GlowButton.Variant, ad: bool, text: String) -> void:
	if _reroll_button.variant != variant or _reroll_button.ad != ad:
		var index: int = _reroll_button.get_index()
		_reroll_button.queue_free()
		_reroll_button = _button(_actions, _on_reroll_pressed, variant)
		_reroll_button.ad = ad
		_actions.move_child(_reroll_button, index)
	_reroll_button.set_label(text)


## «Собрано»: пилюля с 6 слотами — занятые обведены цветом категории навыка, свободные — пунктир (DS S06).
func _collected_row() -> Control:
	var pill: PanelContainer = PanelContainer.new()
	var st: StyleBoxFlat = StyleBoxFlat.new()
	st.bg_color = UITokens.INK_700
	st.set_corner_radius_all(UITokens.R14)
	st.content_margin_left = UITokens.S3
	st.content_margin_right = UITokens.S3
	st.content_margin_top = UITokens.S2
	st.content_margin_bottom = UITokens.S2
	pill.add_theme_stylebox_override(&"panel", st)
	pill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var row: HBoxContainer = UIKit.hbox(UITokens.S3)
	pill.add_child(row)
	_slots_label = UIKit.mono("", UITokens.TEXT_MUTED)
	_slots_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_slots_label)
	_slots = Control.new()
	_slots.custom_minimum_size = Vector2(6 * 26 - 4, 22)
	_slots.draw.connect(_draw_slots)
	row.add_child(_slots)
	return pill


func _draw_slots() -> void:
	var ids: Array = run.skills.keys()
	for i: int in 6:
		var rect: Rect2 = Rect2(Vector2(i * 26, 0), Vector2(22, 22))
		if i < ids.size():
			var def: SkillDef = SkillsManager.get_def(StringName(str(ids[i])))
			var cat: Dictionary = UITokens.CATEGORY.get(def.category if def != null else &"utility", UITokens.CATEGORY[&"utility"])
			var box: StyleBoxFlat = StyleBoxFlat.new()
			box.bg_color = cat["bg"]
			box.border_color = cat["500"]
			box.set_border_width_all(1)
			box.set_corner_radius_all(6)
			_slots.draw_style_box(box, rect)
		else:
			var pts: PackedVector2Array = ButtonFace.rounded_rect(rect, 6)
			pts.append(pts[0])
			for k: int in pts.size() - 1:
				_slots.draw_dashed_line(pts[k], pts[k + 1], UITokens.LINE_STRONG, 1.0, 3.0)


func _reroll_cost_type() -> StringName:
	if _rerolls_this_level == 0:
		return &"sparks"
	if not run.ad_reroll_used:
		return &"ad"
	return &"crystals"


func _reroll_cfg(key: String, fallback: int) -> int:
	return int((SkillsManager.get_tuning().get("reroll", {}) as Dictionary).get(key, fallback))


func _on_reroll_pressed() -> void:
	if _busy:
		return
	match _reroll_cost_type():
		&"sparks":
			var cost: int = _reroll_cfg("sparks", 50)
			if run.run_sparks < cost:
				return
			run.run_sparks -= cost
			EventBus.run_sparks_changed.emit(run.run_sparks, -cost)
			_do_reroll(&"sparks")
		&"ad":
			AdManager.show_rewarded(&"skill_reroll")
		_:
			if GameManager.spend(GameManager.CRYSTALS, _reroll_cfg("crystals", 10), &"skill_reroll"):
				_do_reroll(&"crystal")


func _do_reroll(cost_type: StringName) -> void:
	_rerolls_this_level += 1
	_show_offer(SkillsManager.reroll(run, cost_type))


func _on_take_all_pressed() -> void:
	if not _busy and not run.take_all_used:
		AdManager.show_rewarded(&"skill_take_all")


func _on_ad_reward(placement: StringName) -> void:
	if not is_inside_tree() or run == null:
		return
	match placement:
		&"skill_reroll":
			run.ad_reroll_used = true
			_do_reroll(&"ad")
		&"skill_take_all":
			_busy = true
			SkillsManager.take_all(run)
			_finish()


func _on_card_chosen(card: SkillCard, focus_used: bool) -> void:
	if _busy:
		return
	_busy = true
	FeedbackManager.cue(&"card_pick")
	var position_idx: int = _cards.find(card)
	var decision_ms: int = Time.get_ticks_msec() - _shown_at_ms
	for other: SkillCard in _cards:
		other.locked = true
		var tween: Tween = create_tween().set_ignore_time_scale(true)
		if other == card:
			tween.tween_property(other, ^"scale", Vector2.ONE * 1.06, CHOSEN_S * 0.4)
			tween.tween_property(other, ^"modulate:a", 0.0, CHOSEN_S * 0.6)
		else:
			tween.tween_property(other, ^"modulate:a", 0.0, 0.24)
	await get_tree().create_timer(CHOSEN_S, true, false, true).timeout
	SkillsManager.choose(run, card.offer, position_idx, decision_ms, focus_used)
	_finish()


func _finish() -> void:
	SceneRouter.close_top()


func _button(parent: Control, action: Callable, variant: GlowButton.Variant) -> GlowButton:
	var button: GlowButton = UIKit.button("", variant, action)
	button.custom_minimum_size = Vector2(170, UITokens.BUTTON_H)
	parent.add_child(button)
	return button
