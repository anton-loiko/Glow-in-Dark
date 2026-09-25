class_name EmberDots
extends Control
## Три «тлеющие» точки вместо спиннера (DS S01): 600 мс на цикл.

const CYCLE_S: float = 0.6


func _ready() -> void:
	custom_minimum_size = Vector2(48, 12)
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var t: float = fmod(Time.get_ticks_msec() / 1000.0, CYCLE_S) / CYCLE_S
	for i: int in 3:
		var phase: float = fmod(t + 1.0 - i / 3.0, 1.0)
		var glow: float = 0.3 + 0.7 * pow(1.0 - phase, 2.0)
		draw_circle(Vector2(8 + i * 16, size.y * 0.5), 4.0, Color(UITokens.LIGHT_500, glow))
