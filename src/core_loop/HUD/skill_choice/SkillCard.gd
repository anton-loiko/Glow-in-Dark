extends Button
class_name SkillCard

signal card_selected(id: String)

var skill_id: String = ""

@onready var bg_color: ColorRect = %BgColor
@onready var icon_rect: TextureRect = %IconRect
@onready var title_label: Label = %TitleLabel
@onready var highlight: ReferenceRect = %Highlight

func _ready() -> void:
	pressed.connect(_on_pressed)
	highlight.hide()
	
	# Устанавливаем точку трансформации в центр для красивого масштабирования
	pivot_offset = size / 2.0

func setup(id: String, data: Dictionary) -> void:
	skill_id = id
	title_label.text = data["title"]
	bg_color.color = data["color"]
	
	if ResourceLoader.exists(data["icon"]):
		icon_rect.texture = load(data["icon"])

func _on_pressed() -> void:
	disabled = true 
	
	# Визуальная отдача (вдавливание + белый контур)
	highlight.show()
	var tween = create_tween().set_trans(Tween.TRANS_QUAD)
	
	# Уменьшаем карточку
	tween.tween_property(self, "scale", Vector2(0.9, 0.9), 0.1)
	# Возвращаем размер
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.1)
	
	# Даем небольшую задержку (0.3с), чтобы игрок успел насладиться эффектом нажатия
	tween.tween_interval(0.3)
	tween.tween_callback(func():
		card_selected.emit(skill_id)
	)
