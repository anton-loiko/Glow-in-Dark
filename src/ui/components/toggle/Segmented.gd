class_name Segmented
extends PanelContainer
## Segmented DS §02: подложка ink.600, активный сегмент — line.strong, текст Manrope 13.
## Компактный: ширина по содержимому, чтобы помещаться в строку настройки 52pt рядом с подписью.

signal selected(index: int)

var _group: ButtonGroup = ButtonGroup.new()
var _row: HBoxContainer


func _init(options: PackedStringArray = PackedStringArray(), current: int = 0) -> void:
	var bg: StyleBoxFlat = StyleBoxFlat.new()
	bg.bg_color = UITokens.INK_600
	bg.set_corner_radius_all(UITokens.R14)
	bg.set_content_margin_all(3)
	bg.anti_aliasing = true
	add_theme_stylebox_override(&"panel", bg)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_row = UIKit.hbox(2)
	add_child(_row)
	for i: int in options.size():
		_row.add_child(_segment(options[i], i == current, i))


func _segment(text: String, active: bool, index: int) -> Button:
	var b: Button = Button.new()
	b.text = text
	b.toggle_mode = true
	b.button_group = _group
	b.button_pressed = active
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 38)
	var idle: StyleBoxEmpty = StyleBoxEmpty.new()
	idle.content_margin_left = 10
	idle.content_margin_right = 10
	var on: StyleBoxFlat = StyleBoxFlat.new()
	on.bg_color = UITokens.LINE_STRONG
	on.set_corner_radius_all(11)
	on.content_margin_left = 10
	on.content_margin_right = 10
	on.anti_aliasing = true
	for state: StringName in [&"normal", &"hover", &"focus", &"disabled"]:
		b.add_theme_stylebox_override(state, idle)
	for state: StringName in [&"pressed", &"hover_pressed"]:
		b.add_theme_stylebox_override(state, on)
	UIFonts.apply(b, &"body_s", UITokens.TEXT_MUTED)
	for key: StringName in [&"font_pressed_color", &"font_hover_pressed_color"]:
		b.add_theme_color_override(key, UITokens.TEXT_PRIMARY)
	b.pressed.connect(func() -> void: selected.emit(index))
	return b


func set_current(index: int) -> void:
	for i: int in _row.get_child_count():
		(_row.get_child(i) as Button).set_pressed_no_signal(i == index)
