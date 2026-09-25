class_name CurrencyPill
extends PanelContainer
## Пилюля валюты (DS §02, 32pt): Искры — круг spark, Кристаллы — ромб crystal. «+» только у Кристаллов
## и ведёт в Магазин. При изменении число прокручивается 400 мс, иконка вздрагивает (scale 1.2).

@export var currency: StringName = &"sparks"

var _value: int = 0
var _label: Label
var _icon: Control
var _tween: Tween


func _ready() -> void:
	theme_type_variation = &"PanelPill"
	custom_minimum_size.y = 32
	var row: HBoxContainer = UIKit.hbox(UITokens.S1 + 2)
	add_child(row)
	_icon = Control.new()
	_icon.custom_minimum_size = Vector2(14, 14)
	_icon.pivot_offset = Vector2(7, 7)
	_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_icon.draw.connect(_draw_icon)
	row.add_child(_icon)
	_label = UIKit.label("0", &"number")
	row.add_child(_label)
	if currency == GameManager.CRYSTALS:
		var plus: Button = Button.new()
		plus.theme_type_variation = &"ButtonQuiet"
		plus.text = "+"
		plus.custom_minimum_size = Vector2(28, 28)
		plus.pressed.connect(SceneRouter.go.bind(&"S10"))
		row.add_child(plus)
	_value = GameManager.get_balance(currency)
	_label.text = UIKit.format_number(_value)
	EventBus.currency_changed.connect(_on_currency_changed)
	EventBus.profile_loaded.connect(_on_profile_loaded)


func _on_profile_loaded() -> void:
	_value = GameManager.get_balance(currency)
	_label.text = UIKit.format_number(_value)


func _on_currency_changed(changed: StringName, total: int, _delta: int) -> void:
	if changed != currency:
		return
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = UIMotion.tween(self)
	_tween.tween_method(_set_shown, _value, total, 0.4)
	_tween.parallel().tween_property(_icon, ^"scale", Vector2.ONE * 1.2, 0.1)
	_tween.parallel().tween_property(_icon, ^"scale", Vector2.ONE, 0.2).set_delay(0.1)
	_value = total


func _set_shown(value: int) -> void:
	_label.text = UIKit.format_number(value)


func _draw_icon() -> void:
	var c: Vector2 = _icon.size * 0.5
	if currency == GameManager.CRYSTALS:
		_icon.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -7), c + Vector2(6, 0), c + Vector2(0, 7), c + Vector2(-6, 0)]), UITokens.CRYSTAL_500)
	else:
		_icon.draw_circle(c, 6.0, UITokens.SPARK)
