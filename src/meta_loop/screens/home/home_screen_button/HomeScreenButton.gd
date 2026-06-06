extends Button


@export_category("Props")
@export var default_text: String
@export var default_icon: Texture2D
@export var default_border_color: Color = Color("BCBCBE")

@onready var custom_text: Label = %Text
@onready var custom_icon: TextureRect = %Icon
@onready var badge = %Badge



func _ready() -> void:
	badge.hide()
	
	var normal_style: StyleBoxFlat = get_theme_stylebox("normal").duplicate()
	add_theme_stylebox_override("normal", normal_style)
	
	normal_style.border_color = default_border_color
	
	custom_text.text = default_text
	custom_icon.texture = default_icon
	
	custom_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	custom_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	
	show_badge()


func show_badge() -> void:
	badge.show()

func hide_badge() -> void:
	badge.hide()
