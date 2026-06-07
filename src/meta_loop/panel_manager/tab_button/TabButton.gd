extends Button

const HUB_BUTTON_GROUP = preload("res://src/meta_loop/panel_manager/tab_button/hub_button_group.tres")

@export_category("Props")
@export var default_text: String
@export var default_icon: Texture2D

@onready var custom_text: Label = %Text
@onready var custom_icon: TextureRect = %Icon
@onready var locked_icon: TextureRect = %IconLocked
@onready var background: Panel = %Background
@onready var background_active: Panel = %BackgroundActive

const TOP_Y = -12.0
const CENTER_Y = 9.0
const TOP_SCALE = Vector2(1.2, 1.2)
const CENTER_SCALE = Vector2(1, 1)

func _ready() -> void:
	button_group = HUB_BUTTON_GROUP
	
	custom_text.text = default_text
	custom_icon.texture = default_icon
	
	custom_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	custom_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	
	custom_text.show()
	locked_icon.hide()
	
	if button_pressed:
		background_active.modulate.a = 1.0
	
		custom_text.modulate.a = 1.0
		custom_icon.scale = TOP_SCALE
		custom_icon.position.y = TOP_Y  
	else:
		background_active.modulate.a = 0.0
	
		custom_text.modulate.a = 0.0
		custom_icon.scale = CENTER_SCALE
		custom_icon.position.y = CENTER_Y 
		
	toggled.connect(_on_button_toggled)

func lock():
	disabled = true
	background_active.modulate.a = 0.0
	background.modulate.a = 0.8
	
	custom_icon.hide()
	custom_text.hide()
	locked_icon.show()

func unlock():
	disabled = false
	background.modulate.a = 1.0
	
	custom_icon.show()
	custom_text.show()
	locked_icon.hide()

func _on_button_toggled(_is_pressed: bool) -> void:
	if not disabled:
		var tween = create_tween().set_parallel(true)
		tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		
		if _is_pressed:
			tween.tween_property(background_active, 'modulate:a', 1.0, 0.4)

			tween.tween_property(custom_text, "modulate:a", 1.0, 0.3)
			tween.tween_property(custom_icon, "scale", TOP_SCALE, 0.3)
			tween.tween_property(custom_icon, "position:y", TOP_Y, 0.3)
		else:
			tween.tween_property(background_active, 'modulate:a', 0.0, 0.4)
			
			tween.tween_property(custom_text, "modulate:a", 0.0, 0.3)
			tween.tween_property(custom_icon, "scale", CENTER_SCALE, 0.3)
			tween.tween_property(custom_icon, "position:y", CENTER_Y, 0.3)
