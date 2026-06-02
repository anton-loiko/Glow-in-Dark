extends Panel

const TOP_Y = -3.5
const CENTER_Y = 0
const SPEED = 0.8

func _ready() -> void:
	_badge_animmation()

func _badge_animmation() -> void:
	var tween = create_tween()
	
	tween.set_loops()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	tween.tween_property(self, "position:y", TOP_Y, SPEED)
	tween.tween_property(self, "position:y", CENTER_Y, SPEED)
