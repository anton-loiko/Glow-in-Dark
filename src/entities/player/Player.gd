extends CharacterBody2D

signal light_changed(new_value: float)

const GAME_OVER_SFX = preload("res://src/assets/audio/lose_powerUp10.ogg")
const SPEED: float = 300.0
const MAX_LIGHT_SCALE: float = 1.0
const MIN_LIGHT_SCALE: float = 0.0
const LIGHT_FADE_RATE: float = 0.05
const DANGER_THRESHOLD: float = 0.25

var target_position: Vector2 = Vector2.ZERO
var is_touching: bool = false
var is_dead: bool = false

var current_light_health: float = MAX_LIGHT_SCALE

@onready var light: PointLight2D = $PointLight2D
@onready var sprite: Sprite2D = $Sprite2D
@onready var camera: Camera2D = $Camera2D

func _ready() -> void:
	target_position = global_position
	current_light_health = MAX_LIGHT_SCALE
	light_changed.emit(current_light_health)
	
	var skin_color: Color = GameManager.get_equipped_skin_color()
	light.color = skin_color
	sprite.modulate = skin_color

func _input(event: InputEvent) -> void:
	if is_dead: return

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
	if is_dead: return

	current_light_health -= LIGHT_FADE_RATE * delta
	current_light_health = clampf(current_light_health, MIN_LIGHT_SCALE, MAX_LIGHT_SCALE)
	light_changed.emit(current_light_health)
	
	var pulse: float = 1.0 + sin(Time.get_ticks_msec() * 0.005) * 0.05
	light.texture_scale = current_light_health * pulse
	
	if current_light_health < DANGER_THRESHOLD:
		var shake_intensity = (DANGER_THRESHOLD - current_light_health) * 20.0
		camera.offset = Vector2(randf_range(-shake_intensity, shake_intensity), randf_range(-shake_intensity, shake_intensity))
	else:
		camera.offset = Vector2.ZERO
	
	if is_zero_approx(current_light_health) or current_light_health <= MIN_LIGHT_SCALE:
		die()

func _physics_process(_delta: float) -> void:
	if is_dead:
		velocity = Vector2.ZERO
		move_and_slide()
		return

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

func add_light(amount: float) -> void:
	if is_dead: return

	current_light_health += amount
	current_light_health = clampf(current_light_health, MIN_LIGHT_SCALE, MAX_LIGHT_SCALE)
	light_changed.emit(current_light_health)

func die() -> void:
	is_dead = true
	is_touching = false
	camera.offset = Vector2.ZERO
	AudioManager.play_sfx(GAME_OVER_SFX)
	set_process(false)
	set_physics_process(false)

	var ui = get_tree().current_scene.find_child("UIControl", true, false)
	if ui and ui.has_method("show_game_over"):
		ui.show_game_over()

func revive() -> void:
	is_dead = false
	current_light_health = 0.5
	light_changed.emit(current_light_health)
	target_position = global_position
	set_process(true)
	set_physics_process(true)