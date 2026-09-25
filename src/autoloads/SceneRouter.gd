extends Node
## Навигация по экранам S01–S17 (Design System §03–§05).
## screen — полноэкранная сцена (заменяет текущую), modal/sheet — поверх текущей.
## Пока у экрана нет своей сцены, показывается ScreenStub с переходами из таблицы DS §04.
## Правила Android «назад» (DS §04) задаются полем back:
##   none — игнор · close — закрыть модал · hub — в S02 · pause — открыть S07 · exit — диалог выхода.

const SCREENS: Dictionary = {
	&"S01": {"title": "Сплэш", "kind": &"screen", "back": &"none", "path": "", "links": [&"S02", &"S03"]},
	&"S02": {"title": "Хаб · Маяк", "kind": &"screen", "back": &"exit", "path": "", "links": [&"S05", &"S04", &"S03", &"S10", &"S11", &"S12", &"S13"]},
	&"S03": {"title": "Дар дня", "kind": &"modal", "back": &"close", "path": "", "links": []},
	&"S04": {"title": "Выбор главы", "kind": &"screen", "back": &"hub", "path": "", "links": [&"S05"]},
	&"S05": {"title": "Забег · HUD", "kind": &"screen", "back": &"pause", "path": "res://src/gameplay/run/RunScene.tscn", "transition_ms": 600, "links": [&"S06", &"S07", &"S08", &"S09"]},
	&"S06": {"title": "Левел-ап", "kind": &"modal", "back": &"none", "pauses_world": true, "path": "", "links": []},
	&"S07": {"title": "Пауза", "kind": &"modal", "back": &"close", "pauses_world": true, "path": "", "links": [&"S09"]},
	&"S08": {"title": "Свет угас", "kind": &"modal", "back": &"none", "pauses_world": true, "path": "", "links": [&"S09"]},
	&"S09": {"title": "Итоги забега", "kind": &"screen", "back": &"none", "path": "", "links": [&"S02"]},
	&"S10": {"title": "Магазин", "kind": &"screen", "back": &"hub", "tab": true, "path": "", "links": []},
	&"S11": {"title": "Навыки · Архив", "kind": &"screen", "back": &"hub", "tab": true, "path": "", "links": []},
	&"S12": {"title": "Экипировка", "kind": &"screen", "back": &"hub", "tab": true, "path": "", "links": [&"S14", &"S15", &"S16", &"S17"]},
	&"S13": {"title": "Настройки", "kind": &"screen", "back": &"hub", "path": "", "links": []},
	&"S14": {"title": "Новый Огонёк", "kind": &"modal", "back": &"close", "path": "", "links": []},
	&"S15": {"title": "Лист предмета", "kind": &"sheet", "back": &"close", "path": "", "links": [&"S16"]},
	&"S16": {"title": "Слияние", "kind": &"modal", "back": &"close", "path": "", "links": []},
	&"S17": {"title": "Открытие сундука", "kind": &"modal", "back": &"close", "path": "", "links": []},
	&"EXIT": {"title": "Выйти из игры?", "kind": &"modal", "back": &"close", "path": "", "links": []},
}

## Длительности переходов (DS §05): вкладки — t.fast, экраны — t.slow.
const T_FAST_MS: int = 160
const T_SLOW_MS: int = 400

var current_screen_id: StringName = &""

var _modal_stack: Array[StringName] = []
var _modal_nodes: Array[Node] = []
var _modal_layer: CanvasLayer
var _fade_layer: CanvasLayer
var _fade_rect: ColorRect
var _transitioning: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)
	_modal_layer = CanvasLayer.new()
	_modal_layer.layer = 50
	add_child(_modal_layer)
	_fade_layer = CanvasLayer.new()
	_fade_layer.layer = 100
	add_child(_fade_layer)
	_fade_rect = ColorRect.new()
	_fade_rect.color = Color("#07090F")
	_fade_rect.modulate.a = 0.0
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade_layer.add_child(_fade_rect)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		handle_back()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_back"):
		handle_back()
		get_viewport().set_input_as_handled()


## Смена полноэкранного экрана. Все модалы закрываются.
func go(screen_id: StringName, params: Dictionary = {}) -> void:
	if not _check(screen_id):
		return
	if SCREENS[screen_id]["kind"] != &"screen":
		open_modal(screen_id, params)
		return
	if _transitioning:
		await _wait_transition()
	_transitioning = true
	close_all_modals()
	var info: Dictionary = SCREENS[screen_id]
	var duration_ms: int = int(info.get("transition_ms", T_FAST_MS if info.get("tab", false) else T_SLOW_MS))
	if current_screen_id != &"":
		await _fade(1.0, duration_ms * 0.5)
	_swap_scene(screen_id, params)
	await _fade(0.0, duration_ms * 0.5)
	_transitioning = false


func open_modal(screen_id: StringName, params: Dictionary = {}) -> void:
	if not _check(screen_id):
		return
	if _modal_stack.has(screen_id):
		return
	var node: Node = _instantiate(screen_id)
	_modal_layer.add_child(node)
	_modal_stack.append(screen_id)
	_modal_nodes.append(node)
	if _info(screen_id).get("pauses_world", false):
		TimeService.pause_world(screen_id)
	_enter(node, params)
	EventBus.screen_changed.emit(screen_id)
	Telemetry.screen_view(screen_id)


func close_top() -> void:
	if _modal_stack.is_empty():
		return
	var screen_id: StringName = _modal_stack.pop_back()
	var node: Node = _modal_nodes.pop_back()
	node.queue_free()
	if _info(screen_id).get("pauses_world", false):
		TimeService.resume_world(screen_id)
	EventBus.screen_changed.emit(top_screen_id())


func close_all_modals() -> void:
	while not _modal_stack.is_empty():
		close_top()


## Экран, который сейчас видит игрок (верхний модал или текущий экран).
func top_screen_id() -> StringName:
	return current_screen_id if _modal_stack.is_empty() else _modal_stack.back()


func modal_stack() -> Array[StringName]:
	return _modal_stack.duplicate()


func is_transitioning() -> bool:
	return _transitioning


## Кнопка «назад» по таблице DS §04.
func handle_back() -> void:
	if _transitioning:
		return
	match resolve_back_action(top_screen_id()):
		&"close":
			close_top()
		&"hub":
			go(&"S02")
		&"pause":
			open_modal(&"S07")
		&"exit":
			open_modal(&"EXIT")
		_:
			pass


## Что делает «назад» на экране screen_id: none | close | hub | pause | exit.
func resolve_back_action(screen_id: StringName) -> StringName:
	if not SCREENS.has(screen_id):
		return &"none"
	return _info(screen_id).get("back", &"none")


func quit_game() -> void:
	SaveManager.flush()
	get_tree().quit()


func _swap_scene(screen_id: StringName, params: Dictionary) -> void:
	var tree: SceneTree = get_tree()
	var old_scene: Node = tree.current_scene
	var node: Node = _instantiate(screen_id)
	tree.root.add_child(node)
	tree.current_scene = node
	if old_scene != null:
		old_scene.queue_free()
	current_screen_id = screen_id
	_enter(node, params)
	EventBus.screen_changed.emit(screen_id)
	Telemetry.screen_view(screen_id)


func _instantiate(screen_id: StringName) -> Node:
	var path: String = SCREENS[screen_id]["path"]
	if not path.is_empty() and ResourceLoader.exists(path):
		var scene: PackedScene = load(path) as PackedScene
		return scene.instantiate()
	return ScreenStub.new(screen_id, SCREENS[screen_id])


func _enter(node: Node, params: Dictionary) -> void:
	if node.has_method(&"on_screen_enter"):
		node.call(&"on_screen_enter", params)


func _fade(target_alpha: float, duration_ms: float) -> void:
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP if target_alpha > 0.0 else Control.MOUSE_FILTER_IGNORE
	var tween: Tween = create_tween().set_ignore_time_scale(true)
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(_fade_rect, ^"modulate:a", target_alpha, duration_ms / 1000.0)
	await tween.finished


func _wait_transition() -> void:
	while _transitioning:
		await get_tree().process_frame


func _info(screen_id: StringName) -> Dictionary:
	return SCREENS[screen_id]


func _check(screen_id: StringName) -> bool:
	if SCREENS.has(screen_id):
		return true
	push_error("[SceneRouter] unknown screen '%s'" % screen_id)
	return false
