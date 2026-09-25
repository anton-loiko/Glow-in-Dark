class_name HeroGlyph
extends Control
## Огонёк в UI (кукла S12, S14, лента скинов): ядро hero.core + пламя цвета скина + ореол G-уровня.
## Временная процедурная отрисовка до спрайтов task_8.

var color: Color = UITokens.LIGHT_500
var diameter: float = 62.0
var glow: int = UITokens.G2
var breathe: bool = true
var squash: float = 1.0 ## «кивок» после надевания (0.95 → 1)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(diameter, diameter) * 1.6


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var c: Vector2 = size * 0.5 + Vector2(0, diameter * 0.1)
	var breath: float = TimeService.breath_phase() if breathe else 0.5
	var r: float = diameter * 0.5 * (1.0 + 0.03 * breath)
	for i: int in 5:
		var k: float = 1.0 - i / 5.0
		draw_circle(c, r + glow * k * 1.2, Color(color, 0.05 + 0.03 * breath))
	draw_set_transform(c, 0.0, Vector2(1.0 / squash, squash))
	draw_colored_polygon(PackedVector2Array([Vector2(-r * 0.72, -r * 0.2), Vector2(0, -r * 1.35), Vector2(r * 0.72, -r * 0.2)]), color)
	draw_circle(Vector2.ZERO, r * 0.78, color)
	draw_circle(Vector2(0, -r * 0.05), r * 0.42, Color(UITokens.HERO_CORE, 0.9))
	draw_set_transform(Vector2.ZERO)
