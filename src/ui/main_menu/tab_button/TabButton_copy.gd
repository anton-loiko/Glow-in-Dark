extends Button

const HUB_BUTTON_GROUP = preload("res://src/ui/main_menu/tab_button/hub_button_group.tres")

@export_category("Props")
@export var default_text: String
@export var default_icon: Texture2D

@onready var custom_text: Label = %Text
@onready var custom_icon: TextureRect = %Icon

func _ready() -> void:
	button_group = HUB_BUTTON_GROUP
	
	custom_text.text = default_text
	custom_icon.texture = default_icon
	
	# Устанавливаем начальное состояние (без анимации) при загрузке игры
	if button_pressed:
		custom_text.show()
		custom_text.modulate.a = 1.0 # Полностью непрозрачный
		custom_icon.custom_minimum_size = Vector2(40, 40)
	else:
		custom_text.hide()
		custom_text.modulate.a = 0.0 # Полностью прозрачный
		custom_icon.custom_minimum_size = Vector2(0, 0)
		
	toggled.connect(_on_button_toggled)


func _on_button_toggled(is_pressed: bool) -> void:
	# Создаем Tween и заставляем анимации выполняться одновременно
	var tween = create_tween().set_parallel(true)
	
	# Делаем анимацию чуть более "мягкой" (опционально)
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	
	if is_pressed:
		# Перед началом появления текста обязательно включаем его видимость
		custom_text.show() 
		
		# Плавно меняем альфа-канал (a) от текущего до 1.0 (видимый)
		tween.tween_property(custom_text, "modulate:a", 1.0, 0.3)
		tween.tween_property(custom_icon, "custom_minimum_size", Vector2(40, 40), 0.3)
	else:
		# Плавно меняем альфа-канал до 0.0 (невидимый)
		tween.tween_property(custom_text, "modulate:a", 0.0, 0.3)
		tween.tween_property(custom_icon, "custom_minimum_size", Vector2(0, 0), 0.3)
		
		# Выключаем 'set_parallel', чтобы следующее действие произошло ПОСЛЕ анимаций
		tween.chain().tween_callback(custom_text.hide)
