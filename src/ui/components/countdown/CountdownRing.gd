class_name CountdownRing
extends Control
## Кольцо таймера (S08): янтарное кольцо — надежда на фоне остывшего экрана; число секунд в центре.

@export var duration_s: float = 5.0
@export var diameter: float = 120.0

var _left: float = 0.0


func start(seconds: float) -> void:
	duration_s = seconds
	_left = seconds


func _ready() -> void:
	custom_minimum_size = Vector2(diameter, diameter)
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	_left = maxf(0.0, _left - delta)
	queue_redraw()


func _draw() -> void:
	var c: Vector2 = size * 0.5
	var r: float = diameter * 0.5 - 4.0
	draw_arc(c, r, 0.0, TAU, 64, Color(UITokens.COLD, 0.3), 4.0)
	var t: float = _left / maxf(0.001, duration_s)
	draw_arc(c, r, -PI * 0.5, -PI * 0.5 + TAU * t, 64, UITokens.LIGHT_500, 5.0)
	var font: Font = UIFonts.font(&"display")
	var text: String = str(ceili(_left))
	var w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, 34).x
	draw_string(font, c + Vector2(-w * 0.5, 12), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 34, UITokens.TEXT_PRIMARY)
