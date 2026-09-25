class_name ToastHost
extends CanvasLayer
## Тосты DS §02: сверху под безопасной зоной, 2.4 с, не больше одного одновременно.
## В бою тосты запрещены — копятся в очереди до выхода из забега.

const SHOW_S: float = 2.4

var _queue: Array[String] = []
var _showing: bool = false


func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	EventBus.toast_requested.connect(_on_toast)
	EventBus.screen_changed.connect(_on_screen_changed)


func _on_toast(text: String, _icon: StringName) -> void:
	_queue.append(text)
	_try_show()


func _on_screen_changed(_id: StringName) -> void:
	_try_show()


func _try_show() -> void:
	if _showing or _queue.is_empty() or GameManager.is_run_active():
		return
	_showing = true
	var text: String = _queue.pop_front()
	var pill: PanelContainer = UIKit.panel(&"PanelPill")
	pill.add_child(UIKit.label(text, &"body_s", UITokens.TEXT_PRIMARY, HORIZONTAL_ALIGNMENT_CENTER))
	pill.set_anchors_preset(Control.PRESET_CENTER_TOP)
	pill.position = Vector2(-120, UITokens.SAFE_TOP + UITokens.S2)
	pill.custom_minimum_size = Vector2(240, 36)
	add_child(pill)
	UIMotion.appear(pill, UITokens.T_BASE_S)
	await get_tree().create_timer(SHOW_S, true, false, true).timeout
	var out: Tween = UIMotion.tween(pill)
	out.tween_property(pill, ^"modulate:a", 0.0, UITokens.T_FAST_S)
	await out.finished
	pill.queue_free()
	_showing = false
	_try_show()
