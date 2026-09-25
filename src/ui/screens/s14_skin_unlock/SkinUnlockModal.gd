extends Control
## S14 · Новый Огонёк (Meta DS §03): метка → герой 92pt с G3 → имя → бейдж класса → «+» (gain) и «−» (cold,
## не красный) → статы с отметкой Базового → «НАДЕТЬ» / «Позже». U1–U6: 0 / 400 / 900 / 1500 / 1900 / 2700 мс.
## params: skin (id), preview (true — закрытый скин: кнопка Disabled с условием открытия).

const STEPS_S: Array[float] = [0.0, 0.4, 0.9, 1.5, 1.9, 2.7]
## Статы карточки: ключ мода → подпись. Отметка «= Базовый», если мода нет.
const STATS: Array[Array] = [
	["light_radius_pct", "Радиус света"],
	["contact_damage_pct", "Урон от касаний"],
	["decay_rate_pct", "Скорость затухания"],
	["aura_dps_pct", "Урон ауры"],
]

var _skin_id: StringName = &"base"
var _preview: bool = false
var _frame: ModalFrame


func on_screen_enter(params: Dictionary) -> void:
	_skin_id = StringName(str(params.get("skin", "base")))
	_preview = bool(params.get("preview", false))
	_build()


func _build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var skin: SkinDef = ConfigDB.get_skin(_skin_id)
	if skin == null:
		SceneRouter.close_top.call_deferred()
		return
	_frame = ModalFrame.new()
	add_child(_frame)
	var eyebrow: String = tr("Предпросмотр") if _preview else tr("Новый Огонёк")
	var content: VBoxContainer = _frame.build(tr(SkinService.display_name(_skin_id)), false, eyebrow)
	var steps: Array[Control] = []
	var hero: HeroGlyph = HeroGlyph.new()
	hero.color = skin.light_color
	hero.diameter = 92.0
	hero.glow = UITokens.G3
	hero.custom_minimum_size = Vector2(0, 150)
	content.add_child(hero)
	steps.append(hero)
	var badge: Label = UIKit.mono(tr(skin.class_title).to_upper() if not skin.class_title.is_empty() else tr("Классический"), skin.light_color, HORIZONTAL_ALIGNMENT_CENTER)
	content.add_child(badge)
	steps.append(badge)
	var traits: VBoxContainer = UIKit.vbox(UITokens.S1)
	if not skin.plus.is_empty():
		traits.add_child(_wrap(UIKit.label("+ " + tr(skin.plus), &"body", UITokens.GAIN)))
	if not skin.minus.is_empty():
		traits.add_child(_wrap(UIKit.label("− " + tr(skin.minus), &"body", UITokens.COLD)))
	content.add_child(traits)
	steps.append(traits)
	var stats: VBoxContainer = UIKit.vbox(UITokens.S1)
	for row: Array in STATS:
		stats.add_child(_stat_row(tr(str(row[1])), int(skin.mods.get(str(row[0]), 0)), str(row[0]) in ["contact_damage_pct", "decay_rate_pct"]))
	content.add_child(stats)
	steps.append(stats)
	var hint: Label = UIKit.mono(tr("Сравнение с Базовым"), UITokens.TEXT_MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	content.add_child(hint)
	steps.append(hint)
	var buttons: VBoxContainer = UIKit.vbox(UITokens.S2)
	content.add_child(buttons)
	steps.append(buttons)
	if _preview:
		var locked: GlowButton = UIKit.button(tr("Надеть"), GlowButton.Variant.PRIMARY, Callable())
		locked.set_blocked(true, _lock_reason(skin))
		buttons.add_child(locked)
		buttons.add_child(UIKit.button(tr("Закрыть"), GlowButton.Variant.QUIET, _close))
	else:
		buttons.add_child(UIKit.button(tr("Надеть"), GlowButton.Variant.PRIMARY, _equip))
		buttons.add_child(UIKit.button(tr("Позже"), GlowButton.Variant.QUIET, _close))
	for i: int in steps.size():
		UIMotion.appear(steps[i], UITokens.T_SLOW_S, STEPS_S[i])
	if not _preview:
		FeedbackManager.haptic(&"success")


func _stat_row(title: String, pct: int, lower_is_better: bool) -> Control:
	var row: HBoxContainer = UIKit.hbox()
	var name_label: Label = UIKit.label(title, &"body_s", UITokens.TEXT_SECONDARY)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	var value: String = tr("= Базовый")
	var color: Color = UITokens.TEXT_MUTED
	if pct != 0:
		value = "%+d%%" % pct
		var good: bool = (pct < 0) == lower_is_better
		color = UITokens.GAIN if good else UITokens.COLD
	row.add_child(UIKit.label(value, &"number", color))
	return row


func _wrap(label: Label) -> Label:
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 300
	return label


func _lock_reason(skin: SkinDef) -> String:
	if String(skin.unlock.get("type", "")) == "beacon":
		return tr("Откроется на %d%%") % (int(skin.unlock.get("tier", 0)) * BeaconService.levels_per_tier())
	return tr("Эксклюзив стартового набора")


func _equip() -> void:
	SkinService.equip(GameManager.profile, _skin_id, &"s14")
	_close()


func _close() -> void:
	_frame.close_modal()


## Показ засчитан при любом закрытии (включая «назад»): «Позже» оставляет бейдж на вкладке Экипировка.
func _exit_tree() -> void:
	if not _preview and GameManager.profile.skins_to_reveal.has(_skin_id):
		GameManager.profile.skins_to_reveal.erase(_skin_id)
		SaveManager.request_save()
