class_name Pickup
extends Node2D
## Предмет на полу: искра (круг spark), топливо (янтарная капсула, видна сквозь тьму) или сундук забега.
## Движение и сбор ведёт PickupSystem — у самого узла нет процесса (дёшево при сотнях искр).

enum Kind { SPARK, FUEL, CHEST }

const SPARK_COLOR: Color = Color("#FFD166")
const FUEL_COLOR: Color = Color("#FFB547")
const CHEST_COLOR: Color = Color("#8F98AB")

var kind: Kind = Kind.SPARK
var value: int = 1
var age: float = 0.0
var magnet_delay: float = 0.0
var attracted: bool = false
var speed: float = 0.0
var bounce_from: Vector2
var bounce_to: Vector2
var bounce_left: float = 0.0
var glow_light: PointLight2D


func _init(p_kind: Kind = Kind.SPARK) -> void:
	kind = p_kind
	var unshaded: CanvasItemMaterial = CanvasItemMaterial.new()
	unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = unshaded


func _ready() -> void:
	set_process(false)
	set_physics_process(false)


func reset(p_value: int, pos: Vector2, bounce_pt: float, delay_s: float) -> void:
	value = p_value
	age = 0.0
	attracted = false
	speed = 0.0
	magnet_delay = delay_s
	position = pos
	bounce_from = pos
	bounce_left = 0.0
	if bounce_pt > 0.0:
		bounce_to = pos + Vector2.from_angle(randf() * TAU) * bounce_pt
		bounce_left = 0.15
	modulate.a = 1.0
	queue_redraw()


func is_big() -> bool:
	return kind == Kind.SPARK and value > 1


func _draw() -> void:
	match kind:
		Kind.SPARK:
			var r: float = 5.0 if is_big() else 3.0
			draw_circle(Vector2.ZERO, r + 2.0, Color(SPARK_COLOR, 0.25))
			draw_circle(Vector2.ZERO, r, SPARK_COLOR)
		Kind.FUEL:
			draw_circle(Vector2.ZERO, 16.0, Color(FUEL_COLOR, 0.18))
			var rect: Rect2 = Rect2(Vector2(-6, -10), Vector2(12, 20))
			draw_rect(rect, FUEL_COLOR)
			draw_circle(Vector2(0, -10), 6.0, FUEL_COLOR)
			draw_circle(Vector2(0, 10), 6.0, FUEL_COLOR)
			draw_rect(Rect2(Vector2(-2, -8), Vector2(4, 16)), Color("#FFF1D0"))
		Kind.CHEST:
			draw_rect(Rect2(Vector2(-9, -7), Vector2(18, 14)), CHEST_COLOR)
			draw_line(Vector2(-9, -1), Vector2(9, -1), Color("#FFB547", 0.5), 2.0)
