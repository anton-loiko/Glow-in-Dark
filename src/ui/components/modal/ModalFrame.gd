class_name ModalFrame
extends Control
## Модальное окно DS §02 (r22): ink.700, контур line.strong, тёплый блик 1pt сверху — будто панель освещена
## Огоньком. Фон под модалом — ink.900 70%. Закрытие — ✕ 32pt справа сверху и тап вне окна (если closable).
## content — контейнер для содержимого экрана-модала.

signal closed

var content: VBoxContainer
var closable: bool = true
var _panel: PanelContainer


func build(title: String, p_closable: bool = true, eyebrow: String = "") -> VBoxContainer:
	closable = p_closable
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(UITokens.INK_900, 0.7)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(_on_dim_input)
	add_child(dim)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_panel = UIKit.panel(&"PanelModal")
	var max_width: float = get_viewport_rect().size.x - UITokens.S4 * 2.0 if is_inside_tree() else 350.0
	_panel.custom_minimum_size = Vector2(minf(350.0, max_width), 0)
	_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_panel.draw.connect(_draw_highlight)
	center.add_child(_panel)
	content = UIKit.vbox(UITokens.S4)
	_panel.add_child(content)
	var header: HBoxContainer = UIKit.hbox()
	content.add_child(header)
	var titles: VBoxContainer = UIKit.vbox(UITokens.S1)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(titles)
	if not eyebrow.is_empty():
		titles.add_child(UIKit.mono(eyebrow, UITokens.SPARK))
	titles.add_child(UIKit.label(title, &"h1"))
	if closable:
		var close: Button = Button.new()
		close.theme_type_variation = &"ButtonQuiet"
		close.text = "✕"
		close.custom_minimum_size = Vector2(32, 32)
		close.pressed.connect(close_modal)
		header.add_child(close)
	UIMotion.appear(_panel)
	return content


func close_modal() -> void:
	closed.emit()
	SceneRouter.close_top()


func _on_dim_input(event: InputEvent) -> void:
	var tapped: bool = (event is InputEventMouseButton and (event as InputEventMouseButton).pressed) \
		or (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed)
	if tapped and closable:
		close_modal()


func _draw_highlight() -> void:
	var w: float = _panel.size.x
	_panel.draw_line(Vector2(UITokens.R22, 0.5), Vector2(w - UITokens.R22, 0.5), Color(UITokens.LIGHT_500, 0.45), 1.0)
