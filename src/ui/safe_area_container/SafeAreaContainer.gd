extends MarginContainer

func _ready() -> void:
	# Проверяем операционную систему. Вырезы актуальны только для мобильных устройств.
	var os_name: String = OS.get_name()
	if os_name == "Android" or os_name == "iOS":
		_update_margins_for_safe_area()

func _update_margins_for_safe_area() -> void:
	# 1. Получаем безопасную зону в физических пикселях устройства.
	var safe_area: Rect2i = DisplayServer.get_display_safe_area()
	
	# 2. Получаем общий физический размер всего экрана телефона.
	var screen_size: Vector2i = DisplayServer.screen_get_size()
	
	# 3. Вычисляем масштаб (отношение логических пикселей Godot к физическим).
	var scale_x: float = size.x / screen_size.x
	var scale_y: float = size.y / screen_size.y
	
	# 4. Вычисляем отступы для всех четырех сторон экрана.
	# Левый отступ: позиция безопасной зоны по X, умноженная на масштаб.
	var margin_left: int = roundi(safe_area.position.x * scale_x)
	
	# Верхний отступ: позиция безопасной зоны по Y, умноженная на масштаб.
	var margin_top: int = roundi(safe_area.position.y * scale_y)
	
	# Правый отступ: (Общая ширина) минус (Конец безопасной зоны по X). Умножаем на масштаб.
	var margin_right: int = roundi((screen_size.x - (safe_area.position.x + safe_area.size.x)) * scale_x)
	
	# Нижний отступ: (Общая высота) минус (Конец безопасной зоны по Y). Умножаем на масштаб.
	var margin_bottom: int = roundi((screen_size.y - (safe_area.position.y + safe_area.size.y)) * scale_y)
	
	# 5. Применяем вычисленные отступы к MarginContainer через переопределение темы.
	#add_theme_constant_override("margin_left", margin_left)
	add_theme_constant_override("margin_top", margin_top)
	#add_theme_constant_override("margin_right", margin_right)
	#add_theme_constant_override("margin_bottom", margin_bottom)
