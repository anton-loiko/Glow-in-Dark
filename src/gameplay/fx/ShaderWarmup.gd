class_name ShaderWarmup
extends Node2D
## Прогрев шейдеров на сплэше (task_8 §2): шейдер компилируется при первой отрисовке, поэтому все
## боевые материалы рисуются 2 кадра крошечными и почти прозрачными в углу экрана — без фризов при первых врагах и Взрыве.

signal finished

const FRAMES: int = 2


func _ready() -> void:
	# В кадре (иначе culling пропустит отрисовку и компиляции не будет), но крошечно и почти прозрачно.
	modulate = Color(1, 1, 1, 0.02)
	position = Vector2(4, 4)
	scale = Vector2.ONE * 0.02
	for id: StringName in EnemyVisuals.FRAMES:
		var tex: CanvasTexture = EnemyVisuals.texture_for(id)
		if tex == null:
			continue
		var sprite: Sprite2D = Sprite2D.new()
		sprite.texture = tex
		sprite.hframes = EnemyVisuals.frame_count(id)
		sprite.material = EnemyVisuals.material_for(id)
		add_child(sprite)
	_finish_later()


func _finish_later() -> void:
	for i: int in FRAMES:
		await get_tree().process_frame
	finished.emit()
	queue_free()
