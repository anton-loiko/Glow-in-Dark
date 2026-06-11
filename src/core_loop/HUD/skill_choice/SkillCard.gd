extends Button
class_name SkillCard

signal card_selected(id: String)

var skill_id: String = ""

@onready var bg_color: Panel = %BgColor
@onready var icon_rect: TextureRect = %IconRect
@onready var title_label: Label = %TitleLabel
@onready var highlight: Panel = %Highlight

func _ready() -> void:
	pressed.connect(_on_pressed)
	#highlight.hide()
	
	# Устанавливаем точку трансформации в центр для красивого масштабирования
	pivot_offset = size / 2.0

func setup(id: String, data: Dictionary) -> void:
	skill_id = id
	title_label.text = data["title"]
	
	# Дублируем StyleBoxFlat, чтобы изменение цвета одной карточки не ломало остальные
	var base_style = highlight.get_theme_stylebox("panel")
	if base_style:
		var new_style = base_style.duplicate() as StyleBoxFlat
		new_style.bg_color = data["bg_color"]
		highlight.add_theme_stylebox_override("panel", new_style)
	
	if ResourceLoader.exists(data["icon"]):
		icon_rect.texture = load(data["icon"])

func _on_pressed() -> void:
	disabled = true 
	
	# Визуальная отдача (вдавливание + неоновый контур)
	#highlight.show()
	var tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	
	# Уменьшаем карточку (эффект нажатия)
	tween.tween_property(self, "scale", Vector2(0.9, 0.9), 0.2)
	# Возвращаем размер
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.1)
	
	# Даем небольшую задержку (0.3с) для завершения анимации перед отправкой сигнала
	tween.tween_interval(0.5)
	tween.tween_callback(func():
		card_selected.emit(skill_id)
	)
