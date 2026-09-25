extends Control
## S09 · Итоги забега · инверсия (DS S09): единственный экран с тёплым фоном (правило 9).
## Primary инвертирован (чернильный на янтаре): «▶ ЗАБРАТЬ ×3 · N» 64pt (плейсмент run_x3);
## «Забрать N» — Quiet, появляется через 1.2 с. «Назад» игнорируется.

const QUIET_DELAY_S: float = 1.2

var _claimed: bool = false


func _ready() -> void:
	var run: RunContext = GameManager.current_run
	var column: VBoxContainer = UIKit.screen_root(self, UITokens.LIGHT_500)
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
	stats.add_child(_stat(tr("Время"), UIKit.format_time(result.time_s) + (" ★" if result.is_record else "")))
	stats.add_child(_stat(tr("Сожжено"), UIKit.format_number(result.kills)))
	stats.add_child(_stat(tr("Уровень"), str(result.player_level)))
	column.add_child(UIKit.spacer())
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
	EventBus.ad_reward_granted.connect(_on_ad_reward)


func _on_ad_reward(placement: StringName) -> void:
	if placement == &"run_x3":
		_claim(3)


func _claim(multiplier: int) -> void:
	if _claimed:
		return
	_claimed = true
	GameManager.apply_run_rewards(multiplier)
	SceneRouter.go(&"S02")


func _stat(title: String, value: String) -> Control:
	var box: VBoxContainer = UIKit.vbox(UITokens.S1)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(UIKit.mono(title, UITokens.TEXT_ON_LIGHT))
	box.add_child(UIKit.label(value, &"h2", UITokens.TEXT_ON_LIGHT))
	return box


## Инверсия Primary: чернильная кнопка на янтарном фоне.
func _invert(button: GlowButton) -> void:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = UITokens.INK_900
	box.set_corner_radius_all(UITokens.R14)
	box.border_width_bottom = 4
	box.border_color = Color(UITokens.INK_900, 0.6).lightened(0.2)
	for state: StringName in [&"normal", &"hover", &"pressed", &"focus"]:
		button.add_theme_stylebox_override(state, box)
	for key: StringName in [&"font_color", &"font_hover_color", &"font_pressed_color", &"font_focus_color"]:
		button.add_theme_color_override(key, UITokens.LIGHT_500)
