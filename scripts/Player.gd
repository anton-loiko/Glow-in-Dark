extends CharacterBody2D

signal light_changed(new_value: float)

const GAME_OVER_SFX = preload("res://assets/audio/lose_powerUp10.ogg")

const SPEED: float = 300.0
const MAX_LIGHT_SCALE: float = 1.0
const MIN_LIGHT_SCALE: float = 0.0
const LIGHT_FADE_RATE: float = 0.05

var target_position: Vector2 = Vector2.ZERO
var is_touching: bool = false

@onready var light: PointLight2D = $PointLight2D

func _ready() -> void:
	target_position = global_position
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

func _process(delta: float) -> void:
	light.texture_scale -= LIGHT_FADE_RATE * delta
	light.texture_scale = clampf(light.texture_scale, MIN_LIGHT_SCALE, MAX_LIGHT_SCALE)
	light_changed.emit(light.texture_scale)
	
	if is_zero_approx(light.texture_scale):
		AudioManager.play_sfx(GAME_OVER_SFX)

		# Выключаем процесс, чтобы эта проверка не срабатывала 60 раз в секунду
		set_process(false)
		# "Кричим" всем узлам в группе UI, чтобы они запустили функцию show_game_over
		get_tree().call_group("UI", "show_game_over")


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


# Функция, которую будет вызывать топливо при подборе
func add_light(amount: float) -> void:
	# Прибавляем полученное количество к текущему размеру света
	light.texture_scale += amount
	# Снова проверяем, чтобы свет не стал больше максимума (1.0)
	light.texture_scale = clampf(light.texture_scale, MIN_LIGHT_SCALE, MAX_LIGHT_SCALE)
	light_changed.emit(light.texture_scale)



func revive() -> void:
	# Восстанавливаем свет на 50%
	light.texture_scale = 0.5
	light_changed.emit(light.texture_scale)
	
	# Снова включаем функцию _process, которую мы отключали при смерти
	set_process(true)
