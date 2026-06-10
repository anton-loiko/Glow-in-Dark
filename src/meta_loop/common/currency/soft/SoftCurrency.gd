extends Panel

@onready var currency: Label = %Currency

func _ready() -> void:
	GameManager.sparks_changed.connect(_on_sparks_changed)

	_on_sparks_changed(GameManager.sparks)

func _on_sparks_changed(new_amount: int) -> void:
	if new_amount > 9999:
		currency.text = "+9999"
	else:
		currency.text = str(new_amount)
