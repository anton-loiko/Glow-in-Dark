class_name ScreenStub
extends Control
## Временный экран-заглушка (до реализации экранов в task_5/task_6/task_7).
## Показывает код экрана и кнопки переходов из таблицы DS §04 — для проверки навигации
## и Android «назад». Переходы забега идут через API GameManager, как у настоящих экранов.

var screen_id: StringName
var info: Dictionary


func _init(p_screen_id: StringName = &"", p_info: Dictionary = {}) -> void:
	screen_id = p_screen_id
	info = p_info
	name = "Stub_%s" % screen_id
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _ready() -> void:
	set_process(false)
	var is_modal: bool = info.get("kind", &"screen") != &"screen"
	var background: ColorRect = ColorRect.new()
	background.color = Color(0.03, 0.035, 0.06, 0.8 if is_modal else 1.0)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var box: VBoxContainer = VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.add_theme_constant_override(&"separation", 12)
	add_child(box)

	var title: Label = Label.new()
	title.text = "%s · %s" % [screen_id, info.get("title", "")]
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	if screen_id == &"EXIT":
		_add_button(box, "Выйти", SceneRouter.quit_game)
		_add_button(box, "Остаться", SceneRouter.close_top)
		return
	match screen_id:
		&"S06":
			_add_button(box, "Продолжить (выбор навыка — task_4)", SceneRouter.close_top)
		&"S08":
			_add_button(box, "▶ Разжечь снова", AdManager.show_rewarded.bind(&"revive"))
			_add_button(box, "Разжечь за 30 ◆", GameManager.request_revive.bind(&"crystal"))
	for target: StringName in info.get("links", []):
		_add_button(box, "→ %s · %s" % [target, SceneRouter.SCREENS[target]["title"]], _open.bind(target))
	if info.get("back", &"none") != &"none":
		_add_button(box, "‹ Назад", SceneRouter.handle_back)


func _add_button(parent: Control, text: String, action: Callable) -> void:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(260, 48)
	button.pressed.connect(action)
	parent.add_child(button)


func _open(target: StringName) -> void:
	match target:
		&"S05":
			GameManager.start_run(GameManager.profile.current_chapter)
		&"S09":
			var result: RunResult = RunResult.new()
			result.reason = {
				&"S07": RunResult.REASON_QUIT,
				&"S08": RunResult.REASON_DEATH,
			}.get(screen_id, RunResult.REASON_CHAPTER_CLEARED)
			GameManager.end_run(result)
		&"S02" when screen_id == &"S09":
			GameManager.apply_run_rewards(1)
			SceneRouter.go(&"S02")
		_:
			SceneRouter.go(target)
