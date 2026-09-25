class_name PlayerVisual
extends Node2D
## Визуал Огонька (Art Direction §02, GDD 7.2): hi-res слои src/assets/hero — тело (белое, цвет скина через
## modulate), раскалённое ядро, 4 эмоции глаз. Огонёк сам источник света — слои unshaded.
## Дыхание 1.2 с, squash & stretch по скорости, остывание и мерцание при HP < 25%, вспышка при уроне.

enum Mood { CALM, FOCUSED, SCARED, HAPPY }

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
var _body: Sprite2D
var _core: Sprite2D
var _eyes: Sprite2D

const BODY_TEX: Texture2D = preload("res://src/assets/hero/hero_body.png")
const CORE_TEX: Texture2D = preload("res://src/assets/hero/hero_core.png")
const EYES_TEX: Dictionary = {
	Mood.CALM: preload("res://src/assets/hero/hero_eyes_calm.png"),
	Mood.FOCUSED: preload("res://src/assets/hero/hero_eyes_focused.png"),
	Mood.SCARED: preload("res://src/assets/hero/hero_eyes_scared.png"),
	Mood.HAPPY: preload("res://src/assets/hero/hero_eyes_happy.png"),
}
## Геометрия исходника 170×170: центр круга тела (85, 104), радиус 50 px.
const SRC_BODY_R: float = 50.0
const SRC_BODY_CENTER_Y: float = 104.0


func _ready() -> void:
	var unshaded: CanvasItemMaterial = CanvasItemMaterial.new()
	unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_body = _layer(BODY_TEX, unshaded)
	_core = _layer(CORE_TEX, unshaded)
	_eyes = _layer(EYES_TEX[Mood.CALM], unshaded)


func _layer(tex: Texture2D, mat: Material) -> Sprite2D:
	var sprite: Sprite2D = Sprite2D.new()
	sprite.texture = tex
	sprite.material = mat
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(sprite)
	return sprite


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
	_update_layers()


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


## Цвет тела, остывание при HP < 25%, вспышка урона, эмоция глаз; масштаб слоёв под body_radius.
func _update_layers() -> void:
	if _body == null:
		return
	var color: Color = light_color
	if danger:
		var flicker: float = 0.75 + 0.25 * sin(Time.get_ticks_msec() * 0.037) * sin(Time.get_ticks_msec() * 0.011)
		color = light_color.lerp(COLD_COLOR, 0.7) * Color(flicker, flicker, flicker, 1.0)
	if _hurt_left > 0.0:
		color = color.lerp(Color.WHITE, 0.6)
	var k: float = body_radius / SRC_BODY_R
	var offset: Vector2 = Vector2(0, -(SRC_BODY_CENTER_Y - 85.0) + body_radius * 0.15 / k)
	for layer: Sprite2D in [_body, _core, _eyes]:
		layer.scale = Vector2.ONE * k
		layer.offset = offset
	_body.modulate = color
	_eyes.texture = EYES_TEX[_current_mood()]
