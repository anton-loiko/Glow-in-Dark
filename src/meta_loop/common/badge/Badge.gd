extends Panel

#const TOP_Y = -3
#const CENTER_Y = 0

const SCALE_UP = Vector2(1.05, 1.05)
const SCALE = Vector2(0.95, 0.95)
const SPEED = 1

func _ready() -> void:
	_badge_animmation()

func _badge_animmation() -> void:
	var tween = create_tween()
	
	tween.set_loops()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	tween.tween_property(self, "scale", SCALE_UP, SPEED)
	tween.tween_property(self, "scale", SCALE, SPEED)
