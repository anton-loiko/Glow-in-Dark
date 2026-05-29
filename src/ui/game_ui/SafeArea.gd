class_name SafeArea
extends MarginContainer

func _ready() -> void:
	_update_safe_area()
	get_tree().root.size_changed.connect(_update_safe_area)

func _update_safe_area() -> void:
	var safe_area: Rect2i = DisplayServer.get_display_safe_area()
	var window_size: Vector2i = DisplayServer.window_get_size()
	
	if safe_area.size == window_size or safe_area.size == Vector2i.ZERO:
		add_theme_constant_override("margin_top", 0)
		add_theme_constant_override("margin_bottom", 0)
		add_theme_constant_override("margin_left", 0)
		add_theme_constant_override("margin_right", 0)
		return

	# Переводим физические пиксели экрана в логические координаты Viewport
	var scale_factor: Vector2 = get_viewport().get_canvas_transform().get_scale()
	
	var top_margin: float = safe_area.position.y / scale_factor.y
	var bottom_margin: float = (window_size.y - safe_area.end.y) / scale_factor.y
	var left_margin: float = safe_area.position.x / scale_factor.x
	var right_margin: float = (window_size.x - safe_area.end.x) / scale_factor.x

	add_theme_constant_override("margin_top", int(top_margin))
	add_theme_constant_override("margin_bottom", int(bottom_margin))
	add_theme_constant_override("margin_left", int(left_margin))
	add_theme_constant_override("margin_right", int(right_margin))
