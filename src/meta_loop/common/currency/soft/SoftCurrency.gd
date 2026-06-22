class_name SoftCurrency
extends Panel

@export var is_core_loop: bool = false
@onready var currency: Label = %Currency

func _ready() -> void:

	if not is_core_loop:
		GameManager.sparks_changed.connect(_on_sparks_changed)
		_on_sparks_changed(GameManager.sparks)

func _on_sparks_changed(new_amount: int) -> void:
	set_amount(new_amount)

func set_amount(new_amount: int) -> void:
	if new_amount > 9999:
		currency.text = "+9999"
	elif new_amount <= 0:
		currency.text = "0"
	else:
		currency.text = str(new_amount)
