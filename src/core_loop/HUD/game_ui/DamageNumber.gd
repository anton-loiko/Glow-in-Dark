class_name DamageNumber
extends Node2D

var label: Label

func _ready() -> void:
	label = Label.new()
	add_child(label)
	
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_CENTER)
	
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 2)
	
	# Делаем текст светящимся во тьме (игнорирует CanvasModulate)
	var unshaded_mat = CanvasItemMaterial.new()
	unshaded_mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	label.material = unshaded_mat
	
	hide()

func play(amount: int, start_global_pos: Vector2, is_lethal: bool) -> void:
	show()
	var random_offset = Vector2(randf_range(-20.0, 20.0), randf_range(-20.0, 20.0))
	global_position = start_global_pos + random_offset
	
	if is_lethal:
		label.text = str(amount) + "!"
		label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.1)) 
		label.add_theme_font_size_override("font_size", 28)
		z_index = 10 
	else:
		label.text = str(amount)
		label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.8)) 
		label.add_theme_font_size_override("font_size", 16)
		z_index = 5
		
	modulate.a = 1.0
	scale = Vector2.ZERO
	
	var tween = create_tween()
	
	tween.tween_property(self, "scale", Vector2(1.2, 1.2), 0.1).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2.ONE, 0.1).set_trans(Tween.TRANS_LINEAR)
	
	tween.parallel().tween_property(self, "global_position", global_position + Vector2(0, -40.0), 0.6).set_trans(Tween.TRANS_LINEAR)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.5).set_trans(Tween.TRANS_LINEAR).set_delay(0.1)
	
	tween.tween_callback(_on_animation_finished)

func _on_animation_finished() -> void:
	hide()
