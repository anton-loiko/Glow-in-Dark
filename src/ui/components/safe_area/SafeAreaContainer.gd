class_name SafeAreaContainer
extends MarginContainer
## Безопасная зона устройства (вырез, Dynamic Island, home indicator) + боковые поля экрана.
## Отступы пересчитываются при изменении размера окна.

@export var side_margin: int = 0
@export var extra_top: int = 8
@export var extra_bottom: int = 8


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_viewport().size_changed.connect(_update)
	_update()


func _update() -> void:
	var insets: Dictionary = {"left": 0, "top": 0, "right": 0, "bottom": 0}
	var os_name: String = OS.get_name()
	if os_name == "Android" or os_name == "iOS":
		var safe: Rect2i = DisplayServer.get_display_safe_area()
		var screen: Vector2i = DisplayServer.screen_get_size()
		var visible_size: Vector2 = get_viewport().get_visible_rect().size
		var scale_factor: Vector2 = visible_size / Vector2(maxi(1, screen.x), maxi(1, screen.y))
		insets["left"] = roundi(safe.position.x * scale_factor.x)
		insets["top"] = roundi(safe.position.y * scale_factor.y)
		insets["right"] = roundi((screen.x - safe.end.x) * scale_factor.x)
		insets["bottom"] = roundi((screen.y - safe.end.y) * scale_factor.y)
	add_theme_constant_override(&"margin_left", int(insets["left"]) + side_margin)
	add_theme_constant_override(&"margin_right", int(insets["right"]) + side_margin)
	add_theme_constant_override(&"margin_top", int(insets["top"]) + extra_top)
	add_theme_constant_override(&"margin_bottom", int(insets["bottom"]) + extra_bottom)
