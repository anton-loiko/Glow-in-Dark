extends Control
## S09 · Итоги забега · инверсия (DS S09): единственный экран с тёплым фоном (правило 9).
## Primary инвертирован (чернильный на янтаре): «▶ ЗАБРАТЬ ×3 · N» 64pt (плейсмент run_x3);
## «Забрать N» — Quiet, появляется через 1.2 с. «Назад» игнорируется.

const QUIET_DELAY_S: float = 1.2

var _claimed: bool = false
var _pile: Control
var _pile_coins: float = 0.0


func _ready() -> void:
	var run: RunContext = GameManager.current_run
	var column: VBoxContainer = UIKit.screen_root(self, UITokens.LIGHT_500)
	# Инверсия = награда: тёплый свет растекается из центра (крем → янтарь → тёмный янтарь к низу).
	var light: TextureRect = TextureRect.new()
	light.texture = _warm_light()
	light.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	light.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	light.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(light)
	move_child(light, 1)
	if run == null or run.result == null:
		column.add_child(UIKit.button(tr("В хаб"), GlowButton.Variant.QUIET, SceneRouter.go.bind(&"S02")))
		return
	var result: RunResult = run.result
	var chapter: ChapterDef = ConfigDB.get_chapter(run.chapter_id)
	var cleared: bool = result.reason == RunResult.REASON_CHAPTER_CLEARED
	column.add_child(UIKit.mono(tr("Глава %d · %s") % [chapter.id, tr(chapter.name_key)], UITokens.TEXT_ON_LIGHT))
	column.add_child(UIKit.label(tr("Глава пройдена") if cleared else tr("Забег окончен"), &"h1", UITokens.TEXT_ON_LIGHT))
	var stats: HBoxContainer = UIKit.hbox(UITokens.S3)
	column.add_child(stats)
	stats.add_child(_stat(tr("Время"), UIKit.format_time(result.time_s), tr("★ рекорд") if result.is_record else ""))
	stats.add_child(_stat(tr("Сожжено"), UIKit.format_number(result.kills)))
	stats.add_child(_stat(tr("Уровень"), str(result.player_level)))
	column.add_child(UIKit.spacer())
	_pile = Control.new()
	_pile.custom_minimum_size = Vector2(0, 110)
	_pile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pile.draw.connect(_draw_pile)
	column.add_child(_pile)
	column.add_child(UIKit.label(UIKit.format_number(result.run_sparks), &"display", UITokens.TEXT_ON_LIGHT, HORIZONTAL_ALIGNMENT_CENTER))
	column.add_child(UIKit.mono(tr("Искр собрано"), UITokens.TEXT_ON_LIGHT, HORIZONTAL_ALIGNMENT_CENTER))
	column.add_child(UIKit.spacer())
	var triple: GlowButton = UIKit.ad_button(tr("Забрать ×3 · %s") % UIKit.format_number(result.run_sparks * 3), GlowButton.Variant.PRIMARY, &"run_x3")
	triple.custom_minimum_size.y = 64
	_invert(triple)
	column.add_child(triple)
	var single: GlowButton = UIKit.button(tr("Забрать %s") % UIKit.format_number(result.run_sparks), GlowButton.Variant.QUIET, _claim.bind(1))
	single.add_theme_color_override(&"font_color", UITokens.TEXT_ON_LIGHT)
	single.modulate.a = 0.0
	column.add_child(single)
	UIMotion.appear(single, UITokens.T_BASE_S, QUIET_DELAY_S)
	_pile_coins = clampf(3.0 + result.run_sparks / 300.0, 3.0, 5.0)
	EventBus.ad_reward_granted.connect(_on_ad_reward)


func _on_ad_reward(placement: StringName) -> void:
	if placement == &"run_x3":
		_claim(3)


func _claim(multiplier: int) -> void:
	if _claimed:
		return
	_claimed = true
	if multiplier > 1:
		var tween: Tween = create_tween().set_ignore_time_scale(true)
		tween.tween_method(func(v: float) -> void:
			_pile_coins = v
			_pile.queue_redraw(), _pile_coins, minf(15.0, _pile_coins * 3.0), 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		await tween.finished
	GameManager.apply_run_rewards(multiplier)
	SceneRouter.go(&"S02")


func _stat(title: String, value: String, note: String = "") -> Control:
	var tile: PanelContainer = PanelContainer.new()
	var st: StyleBoxFlat = StyleBoxFlat.new()
	st.bg_color = Color(1, 1, 1, 0.2)
	st.set_corner_radius_all(UITokens.R14)
	st.set_content_margin_all(UITokens.S3)
	tile.add_theme_stylebox_override(&"panel", st)
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box: VBoxContainer = UIKit.vbox(UITokens.S1)
	tile.add_child(box)
	box.add_child(UIKit.mono(title, UITokens.TEXT_ON_LIGHT))
	box.add_child(UIKit.label(value, &"h2", UITokens.TEXT_ON_LIGHT))
	if not note.is_empty():
		box.add_child(UIKit.label(note, &"body_s", Color(UITokens.TEXT_ON_LIGHT, 0.8)))
	return tile


static func _warm_light() -> GradientTexture2D:
	var g: Gradient = Gradient.new()
	g.set_color(0, Color("#FFE8C2"))
	g.set_color(1, Color("#9A560F"))
	g.add_point(0.35, UITokens.LIGHT_300)
	g.add_point(0.7, UITokens.LIGHT_500)
	var tex: GradientTexture2D = GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.32)
	tex.fill_to = Vector2(0.5, 1.15)
	tex.width = 128
	tex.height = 256
	return tex


## Горка искр: число монет растёт с добычей; после ×3 физически утраивается за 600 мс (DS S09).
func _draw_pile() -> void:
	var base: Vector2 = Vector2(_pile.size.x * 0.5, _pile.size.y - 16)
	_pile.draw_set_transform(base, 0.0, Vector2(1.0, 0.28))
	_pile.draw_circle(Vector2.ZERO, 64.0 + 10.0 * _pile_coins / 15.0, Color(UITokens.LIGHT_900, 0.25), true, -1.0, true)
	_pile.draw_set_transform(Vector2.ZERO)
	var shown: int = floori(_pile_coins)
	# Пирамида: нижний ряд w монет, выше w-1 …; w — наименьшее с w(w+1)/2 ≥ shown.
	var bottom: int = 1
	while bottom * (bottom + 1) / 2.0 < shown:
		bottom += 1
	for i: int in shown:
		var row: int = 0
		var left: int = i
		var width: int = bottom
		while left >= width and width > 1:
			left -= width
			width -= 1
			row += 1
		var x: float = (left - (width - 1) * 0.5) * 24.0
		var c: Vector2 = base + Vector2(x, -12.0 - row * 17.0)
		_pile.draw_circle(c, 12.0, UITokens.LIGHT_700, true, -1.0, true)
		_pile.draw_circle(c, 10.5, UITokens.SPARK, true, -1.0, true)
		_pile.draw_circle(c + Vector2(-3, -3), 4.0, Color(UITokens.SPARK_FLASH, 0.8), true, -1.0, true)


## Инверсия Primary: чернильная кнопка на янтарном фоне.
func _invert(button: GlowButton) -> void:
	button.set_face_palette(ButtonFace.INVERTED)
	for key: StringName in [&"font_color", &"font_hover_color", &"font_pressed_color", &"font_focus_color"]:
		button.add_theme_color_override(key, UITokens.LIGHT_500)
