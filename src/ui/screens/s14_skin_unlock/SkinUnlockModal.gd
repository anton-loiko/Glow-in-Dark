extends Control
## S14 · Новый Огонёк (Meta DS §03): метка → герой 92pt с G3 → имя → бейдж класса → «+» (gain) и «−» (cold,
## не красный) → статы с отметкой Базового → «НАДЕТЬ» / «Позже». U1–U6: 0 / 400 / 900 / 1500 / 1900 / 2700 мс.
## params: skin (id), preview (true — закрытый скин: кнопка Disabled с условием открытия).

const STEPS_S: Array[float] = [0.0, 0.4, 0.9, 1.5, 1.9, 2.7]
## Статы: ключ мода → подпись. «Защита» — урон от касаний с обратным знаком.
const STATS: Array[Array] = [
	["light_radius_pct", "Свет"],
	["decay_rate_pct", "Затухание"],
	["contact_damage_pct", "Защита"],
	["aura_dps_pct", "Урон"],
]

var _skin_id: StringName = &"base"
var _preview: bool = false


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
	# Весь экран окрашивается светом нового Огонька (Meta DS §03) — полноэкранная сцена, не карточка.
	var column: VBoxContainer = UIKit.screen_root(self, UITokens.INK_900)
	var tint: TextureRect = TextureRect.new()
	tint.texture = HeroGlyph.halo_texture()
	tint.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tint.modulate = Color(skin.light_color, 0.7)
	tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tint.set_anchors_preset(Control.PRESET_TOP_WIDE)
	tint.offset_left = -160
	tint.offset_right = 160
	tint.offset_top = -40
	tint.offset_bottom = 640
	add_child(tint)
	move_child(tint, 1)
	column.alignment = BoxContainer.ALIGNMENT_BEGIN
	var steps: Array[Control] = []
	var tier: int = int(skin.unlock.get("tier", 0))
	var eyebrow: String = tr("Предпросмотр") if _preview else tr("Новый Огонёк")
	if String(skin.unlock.get("type", "")) == "beacon" and tier > 0:
		eyebrow = tr("Маяк %d%%") % (tier * BeaconService.levels_per_tier()) + " · " + eyebrow
	column.add_child(UIKit.gap(UITokens.S6))
	var eyebrow_label: Label = UIKit.mono(eyebrow, skin.light_color, HORIZONTAL_ALIGNMENT_CENTER)
	column.add_child(eyebrow_label)
	steps.append(eyebrow_label)
	var hero: HeroGlyph = HeroGlyph.new()
	hero.color = skin.light_color
	hero.diameter = 92.0
	hero.glow = UITokens.G3
	hero.custom_minimum_size = Vector2(0, 200)
	column.add_child(hero)
	steps.append(hero)
	var head: VBoxContainer = UIKit.vbox(UITokens.S2)
	head.add_child(UIKit.label(tr("%s Огонёк") % tr(SkinService.display_name(_skin_id)), &"h1", UITokens.TEXT_PRIMARY, HORIZONTAL_ALIGNMENT_CENTER))
	var class_text: String = tr(skin.class_title) if not skin.class_title.is_empty() else tr("Классический")
	head.add_child(_class_badge(tr("Класс") + " · " + class_text, skin.light_color))
	column.add_child(head)
	steps.append(head)
	var traits: VBoxContainer = UIKit.vbox(UITokens.S2)
	if not skin.plus.is_empty():
		traits.add_child(_trait("+", tr(skin.plus), UITokens.GAIN))
	if not skin.minus.is_empty():
		traits.add_child(_trait("−", tr(skin.minus), UITokens.COLD))
	column.add_child(traits)
	steps.append(traits)
	var stats: VBoxContainer = UIKit.vbox(UITokens.S2)
	for row: Array in STATS:
		var key: String = str(row[0])
		var pct: int = int(skin.mods.get(key, 0))
		stats.add_child(_stat_bar(tr(str(row[1])), -pct if key == "contact_damage_pct" else pct, key == "decay_rate_pct", skin.light_color))
	column.add_child(stats)
	steps.append(stats)
	column.add_child(UIKit.spacer())
	var buttons: VBoxContainer = UIKit.vbox(UITokens.S2)
	column.add_child(buttons)
	steps.append(buttons)
	if _preview:
		var locked: GlowButton = UIKit.button(tr("Надеть"), GlowButton.Variant.PRIMARY, Callable())
		locked.set_blocked(true, _lock_reason(skin))
		buttons.add_child(locked)
		buttons.add_child(UIKit.button(tr("Закрыть"), GlowButton.Variant.QUIET, _close))
	else:
		buttons.add_child(UIKit.button(tr("Надеть"), GlowButton.Variant.PRIMARY, _equip))
		buttons.add_child(UIKit.button(tr("Позже"), GlowButton.Variant.QUIET, _close))
	for k: int in steps.size():
		UIMotion.appear(steps[k], UITokens.T_SLOW_S, STEPS_S[mini(k, STEPS_S.size() - 1)])
	if not _preview:
		FeedbackManager.haptic(&"success")


func _class_badge(text: String, color: Color) -> Control:
	var holder: HBoxContainer = UIKit.hbox(0, BoxContainer.ALIGNMENT_CENTER)
	var pill: PanelContainer = PanelContainer.new()
	var st: StyleBoxFlat = StyleBoxFlat.new()
	st.bg_color = Color(color, 0.08)
	st.border_color = Color(color, 0.8)
	st.set_border_width_all(1)
	st.set_corner_radius_all(UITokens.R8)
	st.content_margin_left = 10
	st.content_margin_right = 10
	st.content_margin_top = 3
	st.content_margin_bottom = 3
	pill.add_theme_stylebox_override(&"panel", st)
	pill.add_child(UIKit.mono(text, UITokens.TEXT_PRIMARY))
	holder.add_child(pill)
	return holder


## Плюс и минус крупно (Meta DS §03): карточка ink.700, знак цветом gain / cold (не красный).
func _trait(mark: String, text: String, color: Color) -> Control:
	var card: PanelContainer = PanelContainer.new()
	var st: StyleBoxFlat = StyleBoxFlat.new()
	st.bg_color = Color(UITokens.INK_700, 0.9)
	st.set_corner_radius_all(UITokens.R14)
	st.content_margin_left = UITokens.S4
	st.content_margin_right = UITokens.S4
	st.content_margin_top = UITokens.S3
	st.content_margin_bottom = UITokens.S3
	card.add_theme_stylebox_override(&"panel", st)
	var row: HBoxContainer = UIKit.hbox(UITokens.S3)
	card.add_child(row)
	row.add_child(UIKit.label(mark, &"h2", color))
	var label: Label = UIKit.label(text, &"body", UITokens.TEXT_PRIMARY)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	return card


## Стат относительно Базового: полоса с отметкой Базового посередине; лучше — gain, хуже — cold.
func _stat_bar(title: String, pct: int, lower_is_better: bool, skin_color: Color) -> Control:
	var row: HBoxContainer = UIKit.hbox(UITokens.S3)
	var name_label: Label = UIKit.label(title, &"body_s", UITokens.TEXT_SECONDARY)
	name_label.custom_minimum_size.x = 120
	row.add_child(name_label)
	var bar: Control = Control.new()
	bar.custom_minimum_size = Vector2(0, 16)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var good: bool = (pct < 0) == lower_is_better
	var color: Color = skin_color if pct == 0 else (UITokens.GAIN if good else UITokens.COLD)
	bar.draw.connect(func() -> void:
		var y: float = bar.size.y * 0.5
		var track: StyleBoxFlat = StyleBoxFlat.new()
		track.bg_color = UITokens.INK_600
		track.set_corner_radius_all(3)
		bar.draw_style_box(track, Rect2(Vector2(0, y - 3), Vector2(bar.size.x, 6)))
		var k: float = clampf(0.5 * (1.0 + pct / 100.0), 0.05, 1.0)
		var fill: StyleBoxFlat = StyleBoxFlat.new()
		fill.bg_color = color
		fill.set_corner_radius_all(3)
		bar.draw_style_box(fill, Rect2(Vector2(0, y - 3), Vector2(bar.size.x * k, 6)))
		bar.draw_line(Vector2(bar.size.x * 0.5, y - 7), Vector2(bar.size.x * 0.5, y + 7), UITokens.TEXT_PRIMARY, 2.0))
	row.add_child(bar)
	return row


func _lock_reason(skin: SkinDef) -> String:
	if String(skin.unlock.get("type", "")) == "beacon":
		return tr("Откроется на %d%%") % (int(skin.unlock.get("tier", 0)) * BeaconService.levels_per_tier())
	return tr("Эксклюзив стартового набора")


func _equip() -> void:
	SkinService.equip(GameManager.profile, _skin_id, &"s14")
	_close()


func _close() -> void:
	SceneRouter.close_top()


## Показ засчитан при любом закрытии (включая «назад»): «Позже» оставляет бейдж на вкладке Экипировка.
func _exit_tree() -> void:
	if not _preview and GameManager.profile.skins_to_reveal.has(_skin_id):
		GameManager.profile.skins_to_reveal.erase(_skin_id)
		SaveManager.request_save()
