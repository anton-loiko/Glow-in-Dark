extends CharacterBody2D

const SPEED: float = 300.0

# Константы для механики затухания света
const MAX_LIGHT_SCALE: float = 1.0
const MIN_LIGHT_SCALE: float = 0.0
const LIGHT_FADE_RATE: float = 0.05

var target_position: Vector2 = Vector2.ZERO
var is_touching: bool = false

# Получаем ссылку на дочерний узел PointLight2D
@onready var light: PointLight2D = $PointLight2D

func _ready() -> void:
	target_position = global_position
	# При старте игры устанавливаем максимальный радиус света
	light.texture_scale = MAX_LIGHT_SCALE

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton or event is InputEventScreenTouch:
		if event.is_pressed():
			target_position = get_global_mouse_position()
			is_touching = true
		else:
			is_touching = false
			
	if event is InputEventMouseMotion or event is InputEventScreenDrag:
		if is_touching:
			target_position = get_global_mouse_position()

# _process вызывается каждый кадр при отрисовке графики
func _process(delta: float) -> void:
	# Вычитаем из текущего масштаба света фиксированное значение
	light.texture_scale -= LIGHT_FADE_RATE * delta
	
	# Не даём масштабу выйти за установленные границы
	light.texture_scale = clampf(light.texture_scale, MIN_LIGHT_SCALE, MAX_LIGHT_SCALE)

func _physics_process(_delta: float) -> void:
	if is_touching:
		var direction: Vector2 = global_position.direction_to(target_position)
		var distance: float = global_position.distance_to(target_position)
		
		if distance > 10.0:
			velocity = direction * SPEED
		else:
			velocity = Vector2.ZERO
	else:
		velocity = Vector2.ZERO

	move_and_slide()
