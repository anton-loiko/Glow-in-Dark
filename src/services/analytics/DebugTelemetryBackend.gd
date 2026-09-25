class_name DebugTelemetryBackend
extends TelemetryBackend
## Печатает события в консоль и хранит последние 20 для debug-оверлея.

const HISTORY_SIZE: int = 20

var history: Array[String] = []
var verbose: bool = true


func log_event(name: StringName, params: Dictionary) -> void:
	var line: String = "%s %s" % [name, JSON.stringify(params)]
	history.append(line)
	if history.size() > HISTORY_SIZE:
		history.pop_front()
	if verbose:
		print("[Telemetry] ", line)


func set_user_property(name: StringName, value: String) -> void:
	if verbose:
		print("[Telemetry] user_property %s=%s" % [name, value])
