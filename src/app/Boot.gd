extends Node
## Точка входа: передаёт управление SceneRouter (S01 — сплэш/синхронизация).


func _ready() -> void:
	set_process(false)
	SceneRouter.go.call_deferred(&"S01")
