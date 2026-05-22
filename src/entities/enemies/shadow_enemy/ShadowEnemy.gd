extends Area2D

const DAMAGE_AMOUNT: float = -0.3
const HIT_SFX = preload("res://src/assets/audio/error_008.ogg")
const SPEED: float = 40.0

var target: Node2D = null

@onready var detection_zone: Area2D = $DetectionZone
@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	detection_zone.body_entered.connect(_on_detection_entered)
	detection_zone.body_exited.connect(_on_detection_exited)

func _process(delta: float) -> void:
	if target and not target.is_dead:
		global_position = global_position.move_toward(target.global_position, SPEED * delta)

func _on_detection_entered(body: Node2D) -> void:
	if body.name == "Player":
		target = body

func _on_detection_exited(body: Node2D) -> void:
	if body.name == "Player":
		target = null

func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		if body.has_method("add_light"):
			# Наносим урон (передаем отрицательное значение в функцию лечения)
			body.add_light(DAMAGE_AMOUNT)
			AudioManager.play_sfx(HIT_SFX)
			
			# Отключаем логику, чтобы враг не нанес урон дважды
			set_process(false)
			detection_zone.set_deferred("monitoring", false)
			set_deferred("monitoring", false)
			
			# Анимация "растворения" во тьме
			var tween = create_tween()
			tween.tween_property(sprite, "scale", Vector2.ZERO, 0.2)
			tween.tween_callback(queue_free)
