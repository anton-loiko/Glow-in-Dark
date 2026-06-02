extends Label

 
func _ready() -> void:
	GameManager.sparks_changed.connect(_on_sparks_changed)

	_on_sparks_changed(GameManager.sparks)

func _on_sparks_changed(new_amount: int) -> void:
	text = "Sparks: " + str(new_amount)
