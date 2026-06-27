class_name Player
extends CharacterBody2D

signal light_changed(new_value: float)
signal died

enum State { IDLE, MOVE, DEAD }

const SPEED: float = 80.0
const ACCELERATION: float = 15.0
const FRICTION: float = 20.0
const MAX_LIGHT_SCALE: float = 1.0
const MIN_LIGHT_SCALE: float = 0.0
const LIGHT_FADE_RATE: float = 0.01 
const DANGER_THRESHOLD: float = 0.25

var current_state: State = State.IDLE
var current_light_health: float = MAX_LIGHT_SCALE

var extra_light_scale: float = 1.0
var shake_time_left: float = 0.0
var impact_shake_intensity: float = 0.0

@onready var light: PointLight2D = $PointLight2D
@onready var camera: Camera2D = $Camera2D
@onready var trail_particles: GPUParticles2D = %TrailParticles
@onready var animatedSprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	current_state = State.IDLE
	animatedSprite.play("idle")
	
	current_light_health = MAX_LIGHT_SCALE
	light_changed.emit(current_light_health)
	
	var skin_color: Color = GameManager.get_equipped_skin_color()
	light.color = skin_color
	animatedSprite.modulate = skin_color
	
	if trail_particles:
		trail_particles.modulate = skin_color

func _process(delta: float) -> void:
	if current_state == State.DEAD: 
		return
	
	current_light_health -= LIGHT_FADE_RATE * delta
	current_light_health = clampf(current_light_health, MIN_LIGHT_SCALE, MAX_LIGHT_SCALE)
	light_changed.emit(current_light_health)
	
	var pulse: float = 1.0 + sin(Time.get_ticks_msec() * 0.005) * 0.05
	light.texture_scale = current_light_health * pulse * extra_light_scale
	
	if shake_time_left > 0:
		shake_time_left -= delta
		camera.offset = Vector2(randf_range(-impact_shake_intensity, impact_shake_intensity), randf_range(-impact_shake_intensity, impact_shake_intensity))
	elif current_light_health < DANGER_THRESHOLD:
		var shake_intensity = (DANGER_THRESHOLD - current_light_health) * 20.0
		camera.offset = Vector2(randf_range(-shake_intensity, shake_intensity), randf_range(-shake_intensity, shake_intensity))
	else:
		camera.offset = Vector2.ZERO
	
	if is_zero_approx(current_light_health) or current_light_health <= MIN_LIGHT_SCALE:
		die()

func _physics_process(delta: float) -> void:
	match current_state:
		State.IDLE:
			_state_idle(delta)
		State.MOVE:
			_state_move(delta)
		State.DEAD:
			_state_dead(delta)

	move_and_slide()

func _state_idle(delta: float) -> void:
	if animatedSprite.animation != &"idle":
		animatedSprite.play(&"idle")
		
	velocity = velocity.lerp(Vector2.ZERO, FRICTION * delta)
	
	var input_direction = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if input_direction != Vector2.ZERO:
		current_state = State.MOVE

func _state_move(delta: float) -> void:
	var input_direction = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	
	if input_direction == Vector2.ZERO:
		current_state = State.IDLE
		return

	animatedSprite.flip_h = false

	if input_direction.y > 0:
		animatedSprite.play("move_down")
	elif input_direction.y < 0:
		animatedSprite.play("move_up")
	elif input_direction.x > 0:
		animatedSprite.play("move_right")
	elif input_direction.x < 0:
		animatedSprite.flip_h = true
		animatedSprite.play("move_right")
	
	velocity = velocity.lerp(input_direction * SPEED, ACCELERATION * delta)

func _state_dead(delta: float) -> void:
	velocity = velocity.lerp(Vector2.ZERO, FRICTION * delta)

func add_light(amount: float) -> void:
	if current_state == State.DEAD: 
		return

	current_light_health += amount
	current_light_health = clampf(current_light_health, MIN_LIGHT_SCALE, MAX_LIGHT_SCALE)
	light_changed.emit(current_light_health)
	
	# Резкий скачок радиуса и плавное пружинящее затухание (Bounce)
	var tween = create_tween()
	extra_light_scale = 1.5
	tween.tween_property(self, "extra_light_scale", 1.0, 0.5).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	
	# Тряска камеры на 0.15 секунды
	shake_time_left = 0.15
	impact_shake_intensity = 3.0

func take_damage(amount: float) -> bool:
	if current_state == State.DEAD: 
		return false
		
	var actual_damage = amount
	# Применение навыка "ЩИТ СВЕТА"
	if GameManager.active_skills.has("light_shield"):
		actual_damage *= SkillsManager.SKILL_SHIELD_DAMAGE_REDUCTION
		
	current_light_health -= actual_damage
	current_light_health = clampf(current_light_health, MIN_LIGHT_SCALE, MAX_LIGHT_SCALE)
	light_changed.emit(current_light_health)
	
	# Небольшая тряска камеры при получении урона для импакта
	shake_time_left = 0.2
	impact_shake_intensity = 4.0
	
	return true

func die() -> void:
	if current_state == State.DEAD:
		return
		
	current_state = State.DEAD
	camera.offset = Vector2.ZERO
	animatedSprite.play("die")
	
	var tween = create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	tween.tween_property(animatedSprite, "scale", Vector2(0.22, 0.22), 1.0)
	if trail_particles:
		tween.tween_property(trail_particles, "amount", 1, 1.2)
		tween.tween_property(trail_particles, "amount_ratio", 0, 1.2)
	
	call_delay_die(2)

func call_delay_die(delay_time: float) -> void:
	var timer = Timer.new()
	add_child(timer)
	
	timer.wait_time = delay_time
	timer.one_shot = true
	
	timer.timeout.connect(call_delay_die_callback)
	timer.timeout.connect(timer.queue_free) 
	
	timer.start()

func call_delay_die_callback():
	if trail_particles:
		trail_particles.emitting = false
	set_process(false)
	died.emit()

func revive() -> void:
	current_state = State.IDLE
	animatedSprite.play("idle")
	animatedSprite.scale = Vector2(1.0, 1.0)
	
	if trail_particles:
		trail_particles.amount = 25
		trail_particles.amount_ratio = 1.0
		trail_particles.emitting = true
	
	current_light_health = 0.5
	light_changed.emit(current_light_health)
		
	set_process(true)
