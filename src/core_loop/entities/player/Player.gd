class_name Player
extends CharacterBody2D

signal light_changed(new_value: float)
signal died

const SPEED: float = 80.0 # 300.0
const ACCELERATION: float = 15.0
const FRICTION: float = 20.0
const MAX_LIGHT_SCALE: float = 1.0
const MIN_LIGHT_SCALE: float = 0.0
const LIGHT_FADE_RATE: float = 0.05
const DANGER_THRESHOLD: float = 0.25

var is_dead: bool = false
var current_light_health: float = MAX_LIGHT_SCALE

@onready var light: PointLight2D = $PointLight2D
@onready var camera: Camera2D = $Camera2D
@onready var trail_particles: GPUParticles2D = %TrailParticles
@onready var animatedSprite = $AnimatedSprite2D

func _ready() -> void:
	animatedSprite.play('idle')
	
	current_light_health = MAX_LIGHT_SCALE
	light_changed.emit(current_light_health)
	
	var skin_color: Color = GameManager.get_equipped_skin_color()
	light.color = skin_color
	animatedSprite.modulate = skin_color
	
	if trail_particles:
		trail_particles.modulate = skin_color

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

func _physics_process(delta: float) -> void:
	if is_dead:
		velocity = velocity.lerp(Vector2.ZERO, FRICTION * delta)
		move_and_slide()
		return
	
	# TODO: Rewrite to state machine
	var input_direction = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if input_direction != Vector2.ZERO:
		animatedSprite.flip_h = false

		if input_direction.y > 0: # Down
			animatedSprite.play('move_down')
		elif input_direction.y < 0: # UP
			animatedSprite.play('move_up')
		elif input_direction.x > 0: # Right
			animatedSprite.play('move_right')
		elif input_direction.x < 0: # Left
			animatedSprite.flip_h = true
			animatedSprite.play('move_right')
		
		velocity = velocity.lerp(input_direction * SPEED, ACCELERATION * delta)
	else:
		# Включаем idle только если мы уже не находимся в этом состоянии
		if animatedSprite.animation != &"idle":
			animatedSprite.play(&"idle")
		
		velocity = velocity.lerp(Vector2.ZERO, FRICTION * delta)
		velocity = velocity.lerp(Vector2.ZERO, FRICTION * delta)

	move_and_slide()

func add_light(amount: float) -> void:
	if is_dead: return

	current_light_health += amount
	current_light_health = clampf(current_light_health, MIN_LIGHT_SCALE, MAX_LIGHT_SCALE)
	light_changed.emit(current_light_health)

func take_damage(amount: float) -> bool:
	if is_dead: 
		return false
		
	current_light_health -= amount
	current_light_health = clampf(current_light_health, MIN_LIGHT_SCALE, MAX_LIGHT_SCALE)
	light_changed.emit(current_light_health)
	return true

func die() -> void:
	is_dead = true
	camera.offset = Vector2.ZERO

		
		
		
	animatedSprite.play("die")
	var tween = create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	tween.tween_property(animatedSprite, "scale", Vector2(0.22, 0.22), 1.0)
	tween.tween_property(trail_particles, "amount", 1, 1.2)
	tween.tween_property(trail_particles, "amount_ratio", 0, 1.2)
	
	call_delay_die(2)

func call_delay_die(delay_time: float) -> void:
	var timer = Timer.new()
	add_child(timer)
	
	timer.wait_time = delay_time
	timer.one_shot = true
	
	# Connect to the target function, and automatically queue_free the timer
	timer.timeout.connect(call_delay_die_callback)
	timer.timeout.connect(timer.queue_free) 
	
	timer.start()

func call_delay_die_callback():
	trail_particles.emitting = false
	set_process(false)
	died.emit()

func revive() -> void:
	animatedSprite.play("idle")
	animatedSprite.scale= Vector2(1.0, 1.0)
	trail_particles.amount= 25
	trail_particles.amount_ratio = 1.0
	
	is_dead = false
	current_light_health = 0.5
	light_changed.emit(current_light_health)
	trail_particles.emitting = true
		
	set_process(true)
