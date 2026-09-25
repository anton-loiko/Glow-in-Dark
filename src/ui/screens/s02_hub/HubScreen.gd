extends Control
## S02 · Хаб (DS S02, Meta DS §02): сверху вниз — статус · валюта · глава · Маяк · прогресс · CTA · навигация.
## Каркас экрана; диорама Маяка, кнопка «Внести Искры» и кат-сцены — task_6.

var _beacon_label: Label
var _daily_button: GlowButton
var _tab_bar: GlowTabBar


func _ready() -> void:
	var column: VBoxContainer = UIKit.screen_root(self)
	var top: HBoxContainer = UIKit.hbox(UITokens.S2)
	column.add_child(top)
	var settings: GlowButton = UIKit.button("⚙", GlowButton.Variant.ICON, SceneRouter.go.bind(&"S13"))
	top.add_child(settings)
	top.add_child(UIKit.spacer(false))
	top.add_child(_pill(GameManager.SPARKS))
	top.add_child(_pill(GameManager.CRYSTALS))

	var chapter_row: HBoxContainer = UIKit.hbox(UITokens.S2, BoxContainer.ALIGNMENT_CENTER)
	column.add_child(chapter_row)
	chapter_row.add_child(UIKit.button("‹", GlowButton.Variant.QUIET, SceneRouter.go.bind(&"S04")))
	var chapter: ChapterDef = ConfigDB.get_chapter(GameManager.profile.current_chapter)
	var chapter_title: Button = Button.new()
	chapter_title.theme_type_variation = &"ButtonQuiet"
	chapter_title.text = (tr("Глава %d · %s") % [chapter.id, tr(chapter.name_key)]).to_upper()
	UIFonts.apply(chapter_title, &"label", UITokens.TEXT_MUTED)
	chapter_title.pressed.connect(SceneRouter.go.bind(&"S04"))
	chapter_row.add_child(chapter_title)
	chapter_row.add_child(UIKit.button("›", GlowButton.Variant.QUIET, SceneRouter.go.bind(&"S04")))
	column.add_child(UIKit.label(tr("Маяк"), &"display", UITokens.TEXT_PRIMARY, HORIZONTAL_ALIGNMENT_CENTER))

	var stage: Control = Control.new()
	stage.custom_minimum_size = Vector2(0, 300)
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage.draw.connect(_draw_beacon.bind(stage))
	column.add_child(stage)
	_daily_button = UIKit.button(tr("Дар дня"), GlowButton.Variant.QUIET, SceneRouter.open_modal.bind(&"S03"))
	_daily_button.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_daily_button.position = Vector2(0, -56)
	stage.add_child(_daily_button)

	var level: int = GameManager.profile.get_beacon(chapter.id).level
	_beacon_label = UIKit.label(tr("Маяк восстановлен на %d%%") % level, &"body_s", UITokens.TEXT_SECONDARY, HORIZONTAL_ALIGNMENT_CENTER)
	column.add_child(_beacon_label)
	var bar: ProgressBar = ProgressBar.new()
	bar.show_percentage = false
	bar.max_value = 100
	bar.value = level
	bar.custom_minimum_size = Vector2(0, 10)
	column.add_child(bar)
	column.add_child(UIKit.gap(UITokens.S6))

	_tab_bar = GlowTabBar.new()
	_tab_bar.active = &"S02"
	column.add_child(_tab_bar)
	_refresh_daily()
	EventBus.screen_changed.connect(_on_screen_changed)


func on_screen_enter(params: Dictionary) -> void:
	if bool(params.get("open_daily", false)):
		SceneRouter.open_modal.call_deferred(&"S03")


func _on_screen_changed(_id: StringName) -> void:
	_refresh_daily()


func _refresh_daily() -> void:
	var available: bool = DailyGiftService.is_available(GameManager.profile)
	_daily_button.set_label(("● " if available else "") + tr("Дар дня"))


func _pill(currency: StringName) -> CurrencyPill:
	var pill: CurrencyPill = CurrencyPill.new()
	pill.currency = currency
	return pill


## Временный Маяк до диорамы task_6: кристалл и постамент, яркость по прогрессу.
func _draw_beacon(stage: Control) -> void:
	var c: Vector2 = Vector2(stage.size.x * 0.5, stage.size.y * 0.5)
	var level: float = GameManager.profile.get_beacon(GameManager.profile.current_chapter).level / 100.0
	var breath: float = TimeService.breath_phase()
	for i: int in 6:
		stage.draw_circle(c, (60.0 + 90.0 * level) * (1.0 - i / 6.0), Color(UITokens.LIGHT_500, (0.02 + 0.05 * level) * (1.0 + 0.2 * breath)))
	var crystal: Color = UITokens.LIGHT_500.lerp(UITokens.LIGHT_300, 0.5) * Color(1, 1, 1, 0.35 + 0.65 * level)
	stage.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -80), c + Vector2(34, -20), c + Vector2(0, 30), c + Vector2(-34, -20)]), crystal)
	stage.draw_rect(Rect2(c + Vector2(-60, 60), Vector2(120, 26)), UITokens.INK_600)
	stage.draw_rect(Rect2(c + Vector2(-44, 44), Vector2(88, 18)), UITokens.LINE_STRONG)
	stage.queue_redraw()
