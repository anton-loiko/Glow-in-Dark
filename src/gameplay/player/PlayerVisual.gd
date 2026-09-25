class_name PlayerVisual
extends Node2D
## Визуал Огонька (Art Direction §02, GDD 7.2). Временная процедурная отрисовка до hi-res арта:
## капля с раскалённым ядром и двумя глазами, дыхание 1.2 с, squash & stretch по скорости,
## 4 эмоции глаз, остывание и мерцание при HP < 25%, моргание при уроне.

enum Mood { CALM, FOCUSED, SCARED, HAPPY }

const EYE_COLOR: Color = Color("#07090F")
const CORE_COLOR: Color = Color("#FFFDF5")
const COLD_COLOR: Color = Color("#8FA3C0")

@export var body_radius: float = 20.0

var light_color: Color = Color("#FFB547")
var mood: Mood = Mood.CALM
var velocity: Vector2 = Vector2.ZERO
var max_speed: float = 110.0
var stretch_bonus: float = 0.0 ## +4% за уровень Ускорения (task_4)
var danger: bool = false

var _hurt_left: float = 0.0
var _happy_left: float = 0.0


func _process(delta: float) -> void:
	_hurt_left = maxf(0.0, _hurt_left - delta)
	_happy_left = maxf(0.0, _happy_left - delta)
	var breath: float = TimeService.breath_phase()
	var speed_ratio: float = clampf(velocity.length() / maxf(1.0, max_speed), 0.0, 1.0)
	var stretch: float = 1.0 + speed_ratio * (0.12 + stretch_bonus)
	var squash: float = 1.0 / stretch
	var base_scale: float = 1.0 + 0.04 * breath
	if speed_ratio > 0.05:
		rotation = velocity.angle() + PI * 0.5
		scale = Vector2(squash, stretch) * base_scale
	else:
		rotation = lerp_angle(rotation, 0.0, minf(1.0, delta * 8.0))
		scale = Vector2.ONE * base_scale
	queue_redraw()


func play_hurt() -> void:
	_hurt_left = 0.12


func play_happy(seconds: float = 1.0) -> void:
	_happy_left = seconds


func _current_mood() -> Mood:
	if _happy_left > 0.0:
		return Mood.HAPPY
	if danger:
		return Mood.SCARED
	return mood


func _draw() -> void:
	var color: Color = light_color
	if danger:
		var flicker: float = 0.75 + 0.25 * sin(Time.get_ticks_msec() * 0.037) * sin(Time.get_ticks_msec() * 0.011)
		color = light_color.lerp(COLD_COLOR, 0.7) * Color(flicker, flicker, flicker, 1.0)
	if _hurt_left > 0.0:
		color = color.lerp(Color.WHITE, 0.6)
	var r: float = body_radius
	# Капля: круг + заострённая макушка.
	draw_circle(Vector2(0, r * 0.15), r, color)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-r * 0.72, -r * 0.35), Vector2(0, -r * 1.45), Vector2(r * 0.72, -r * 0.35),
	]), color)
	draw_circle(Vector2(0, r * 0.35), r * 0.42, CORE_COLOR)
	_draw_eyes(r)


func _draw_eyes(r: float) -> void:
	var spacing: float = r * 0.38
	var y: float = -r * 0.05
	for side: float in [-1.0, 1.0]:
		var center: Vector2 = Vector2(side * spacing, y)
		match _current_mood():
			Mood.HAPPY:
				draw_arc(center + Vector2(0, r * 0.08), r * 0.16, PI * 1.1, PI * 1.9, 8, EYE_COLOR, r * 0.09)
			Mood.FOCUSED:
				draw_rect(Rect2(center - Vector2(r * 0.14, r * 0.07), Vector2(r * 0.28, r * 0.14)), EYE_COLOR)
			Mood.SCARED:
				draw_circle(center, r * 0.22, EYE_COLOR)
				draw_circle(center + Vector2(-r * 0.06, -r * 0.07), r * 0.06, CORE_COLOR)
			_:
				draw_circle(center, r * 0.16, EYE_COLOR)
				draw_circle(center + Vector2(-r * 0.05, -r * 0.05), r * 0.045, CORE_COLOR)
