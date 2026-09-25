extends Control
## S07 · Пауза (DS S07): статистика сверху, действия снизу, без центрированного стека кнопок.
## «Продолжить» → отсчёт 3-2-1 по 400 мс поверх S05. «Завершить забег» → подтверждение → S09.
## Тап по навыку раскрывает описание уровней.

const COUNT_STEP_S: float = 0.4

var _actions: VBoxContainer
var _confirm: VBoxContainer
var _countdown: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var column: VBoxContainer = UIKit.screen_root(self, Color(UITokens.INK_900, 0.9))
	var run: RunContext = GameManager.current_run
	column.add_child(UIKit.label(tr("Пауза"), &"h1"))
	if run != null:
		var chapter: ChapterDef = ConfigDB.get_chapter(run.chapter_id)
		column.add_child(UIKit.mono(tr("Глава %d · %s") % [chapter.id, tr(chapter.name_key)]))
		var stats: HBoxContainer = UIKit.hbox(UITokens.S3)
		column.add_child(stats)
		stats.add_child(_stat(tr("Время"), UIKit.format_time(run.elapsed_s)))
		stats.add_child(_stat(tr("Сожжено"), UIKit.format_number(run.kills)))
		stats.add_child(_stat(tr("Искры"), UIKit.format_number(run.run_sparks)))
		column.add_child(UIKit.mono(tr("Навыки забега")))
		for id: StringName in run.skills:
			column.add_child(_skill_row(id, run.skills[id]))
	var toggles: HBoxContainer = UIKit.hbox(UITokens.S4)
	column.add_child(toggles)
	toggles.add_child(_toggle(tr("Звук"), &"sfx"))
	toggles.add_child(_toggle(tr("Вибрация"), &"vibration"))
	column.add_child(UIKit.spacer())
	_actions = UIKit.vbox(UITokens.S2)
	column.add_child(_actions)
	_actions.add_child(UIKit.button(tr("Продолжить"), GlowButton.Variant.PRIMARY, _resume))
	_actions.add_child(UIKit.button(tr("Завершить забег"), GlowButton.Variant.QUIET, _ask_quit))
	_confirm = UIKit.vbox(UITokens.S2)
	_confirm.visible = false
	column.add_child(_confirm)
	_confirm.add_child(UIKit.label(tr("Искры сохранятся, ×3 будет доступно"), &"body", UITokens.TEXT_SECONDARY, HORIZONTAL_ALIGNMENT_CENTER))
	_confirm.add_child(UIKit.button(tr("Завершить"), GlowButton.Variant.SECONDARY, _quit))
	_confirm.add_child(UIKit.button(tr("Отмена"), GlowButton.Variant.QUIET, _cancel_quit))
	_countdown = UIKit.label("", &"display", UITokens.LIGHT_500, HORIZONTAL_ALIGNMENT_CENTER)
	_countdown.set_anchors_preset(Control.PRESET_CENTER)
	_countdown.grow_horizontal = Control.GROW_DIRECTION_BOTH
	add_child(_countdown)


func _stat(title: String, value: String) -> Control:
	var tile: PanelContainer = UIKit.panel(&"PanelCard")
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box: VBoxContainer = UIKit.vbox(UITokens.S1)
	tile.add_child(box)
	box.add_child(UIKit.mono(title))
	box.add_child(UIKit.label(value, &"h2"))
	return tile


func _skill_row(id: StringName, level: int) -> Control:
	var def: SkillDef = SkillsManager.get_def(id)
	var row: VBoxContainer = UIKit.vbox(UITokens.S1)
	var head: Button = Button.new()
	head.theme_type_variation = &"ButtonQuiet"
	head.alignment = HORIZONTAL_ALIGNMENT_LEFT
	head.text = "%s  %d / %d" % [def.display_name, level, def.max_level]
	row.add_child(head)
	var details: Label = UIKit.label("", &"body_s", UITokens.TEXT_MUTED)
	var lines: Array[String] = []
	for lvl: int in range(1, def.max_level + 1):
		lines.append(("● " if lvl <= level else "○ ") + def.level_value(lvl))
	details.text = "\n".join(lines)
	details.visible = false
	row.add_child(details)
	head.pressed.connect(func() -> void: details.visible = not details.visible)
	return row


func _toggle(title: String, key: StringName) -> CheckButton:
	var toggle: CheckButton = CheckButton.new()
	toggle.text = title
	toggle.button_pressed = bool(GameManager.profile.settings.get(key))
	toggle.toggled.connect(func(on: bool) -> void: GameManager.set_setting(key, on))
	return toggle


func _resume() -> void:
	_actions.visible = false
	for n: int in [3, 2, 1]:
		_countdown.text = str(n)
		UIMotion.appear(_countdown, 0.12)
		await get_tree().create_timer(COUNT_STEP_S, true, false, true).timeout
	SceneRouter.close_top()


func _ask_quit() -> void:
	_actions.visible = false
	_confirm.visible = true


func _cancel_quit() -> void:
	_confirm.visible = false
	_actions.visible = true


func _quit() -> void:
	var result: RunResult = RunResult.new()
	result.reason = RunResult.REASON_QUIT
	result.time_s = GameManager.current_run.elapsed_s if GameManager.current_run != null else 0.0
	GameManager.end_run(result)
