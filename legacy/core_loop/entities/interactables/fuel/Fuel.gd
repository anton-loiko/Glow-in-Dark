extends Area2D

const LIGHT_RESTORE_AMOUNT: float = 0.4
const PICKUP_SFX = preload("res://src/assets/audio/pickup_impactWood_light_001.ogg")

@onready var animatedSprite = $AnimatedSprite2D

func _ready() -> void:
	if animatedSprite:
		animatedSprite.play()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player") or body.name == "Player":
		if body.has_method("add_light"):
			set_deferred("monitoring", false)
			
			body.add_light(LIGHT_RESTORE_AMOUNT)
			if AudioManager.has_method("play_sfx"):
				AudioManager.play_sfx(PICKUP_SFX)
			
			var tween = create_tween()
			
			if has_node("PointLight2D"):
				tween.tween_property($PointLight2D, "texture_scale", 1.5, 0.2)
				tween.parallel().tween_property($PointLight2D, "energy", 0.0, 0.2)
				
			if animatedSprite:
				tween.parallel().tween_property(animatedSprite, "scale", Vector2(1.5, 1.5), 0.2)
				tween.parallel().tween_property(animatedSprite, "modulate:a", 0.0, 0.2)
			
			tween.tween_callback(queue_free)
