extends Button
class_name SkillCard

signal card_selected(id: String)

var skill_id: String = ""

@onready var icon_rect: TextureRect = %IconRect
@onready var title_label: Label = %TitleLabel
@onready var cost_label: Label = %CostLabel

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS 

	pressed.connect(_on_pressed)
	
	# Устанавливаем точку трансформации в центр для красивого масштабирования
	pivot_offset = size / 2.0

func setup(id: String, data: Dictionary) -> void:
	skill_id = id
	title_label.text = data["title"]
	cost_label.text = str(data["price_sparks"])
	
	if ResourceLoader.exists(data["icon"]):
		icon_rect.texture = load(data["icon"])

func _on_pressed() -> void:
	disabled = true 
	
	# Визуальная отдача (вдавливание + неоновый контур)
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
