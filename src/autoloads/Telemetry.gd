extends Node
## Фасад аналитики. Весь код игры логирует события только через него; бэкенд подменяемый.

var backend: TelemetryBackend = DebugTelemetryBackend.new()


func _ready() -> void:
	set_process(false)


func log_event(event_name: StringName, params: Dictionary = {}) -> void:
	backend.log_event(event_name, params)


func screen_view(screen_id: StringName) -> void:
	backend.log_event(&"screen_view", {"screen_id": String(screen_id)})


## Стандартные события Firebase earn_/spend_virtual_currency.
func log_economy(currency: StringName, delta: int, reason: StringName, balance: int) -> void:
	var event_name: StringName = &"earn_virtual_currency" if delta >= 0 else &"spend_virtual_currency"
	backend.log_event(event_name, {
		"virtual_currency_name": String(currency),
		"value": absi(delta),
		"reason": String(reason),
		"balance": balance,
	})


func set_user_property(property: StringName, value: Variant) -> void:
	backend.set_user_property(property, str(value))
