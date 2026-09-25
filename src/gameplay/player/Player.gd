class_name Player
extends CharacterBody2D
## Контроллер Огонька (task_2 §2). Ввод — действия move_* (их выставляет встроенный VirtualJoystick
## и клавиатура в редакторе). Радиус света = свет × px_per_light × множители; отображаемый радиус
## догоняет целевой пружиной (упругий откат при уроне, перелёт при Взрыве Света).

enum State { IDLE, MOVE, DEAD }

const LIGHT_TEXTURE_RADIUS_PX: float = 256.0
const LIGHT_WHITE_MIX: float = 0.45

@export var light_node: PointLight2D
@export var light_area_shape: CollisionShape2D
@export var visual: PlayerVisual
@export var light_model: PlayerLight
@export var trail: GPUParticles2D

var state: State = State.IDLE
var stats: StatBlock
var move_speed: float = 110.0
var acceleration: float = 12.0
var friction: float = 16.0
var px_per_light: float = 1.0
## Множитель радиуса от эффектов (перелёт Взрыва Света, Полнолуние Лунного и т.п.).
var radius_boost: float = 1.0
## Свет, «съеденный» аурой Гасителя (1.0 — нет ауры). Выставляет EnemyManager каждый кадр.
var aura_radius_mult: float = 1.0

var _shown_radius: float = 0.0


func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	light_model.depleted.connect(_on_depleted)
	EventBus.player_damaged.connect(_on_damaged)


func setup(p_stats: StatBlock, balance: Dictionary, skin: SkinDef) -> void:
	stats = p_stats
	var player_cfg: Dictionary = balance.get("player", {}) as Dictionary
	move_speed = stats.move_speed
	acceleration = float(player_cfg.get("acceleration", 12.0))
	friction = float(player_cfg.get("friction", 16.0))
	var viewport_width: float = float(ProjectSettings.get_setting("display/window/size/viewport_width", 390))
	var base_max: float = float(player_cfg.get("max_light", 100.0))
	px_per_light = float(player_cfg.get("light_radius_screen_pct", 0.55)) * viewport_width * 0.5 / base_max
	visual.body_radius = float(player_cfg.get("body_radius_pt", 20.0))
	visual.max_speed = move_speed
	light_model.setup(stats, balance)
	if skin != null:
		# Мир освещается тёплым белым в оттенке скина: чистый янтарь по холодному полу даёт «олив».
		light_node.color = skin.light_color.lerp(Color.WHITE, LIGHT_WHITE_MIX)
		visual.light_color = skin.light_color
		trail.modulate = skin.light_color
	_build_light_texture()
	_build_trail()
	_shown_radius = target_radius()
	_apply_radius()


func _physics_process(delta: float) -> void:
	var input: Vector2 = Vector2.ZERO
	if state != State.DEAD:
		input = Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	match state:
		State.IDLE:
			velocity = velocity.lerp(Vector2.ZERO, minf(1.0, friction * delta))
			if input != Vector2.ZERO:
				state = State.MOVE
		State.MOVE:
			if input == Vector2.ZERO:
				state = State.IDLE
			velocity = velocity.lerp(input * move_speed, minf(1.0, acceleration * delta))
		State.DEAD:
			velocity = velocity.lerp(Vector2.ZERO, minf(1.0, friction * delta))
	move_and_slide()
	visual.velocity = velocity
	visual.danger = light_model.is_in_danger()
	trail.emitting = state == State.MOVE
	_shown_radius = lerpf(_shown_radius, target_radius(), minf(1.0, delta * 12.0))
	_apply_radius()


func target_radius() -> float:
	var mult: float = (stats.light_radius_mult * stats.area_scale if stats != null else 1.0) * radius_boost * aura_radius_mult
	return light_model.current * px_per_light * mult


func light_radius() -> float:
	return _shown_radius


func is_dead() -> bool:
	return state == State.DEAD


func revive(pct: float, invulnerable_s: float) -> void:
	light_model.revive(pct)
	light_model.grant_invulnerability(invulnerable_s)
	state = State.IDLE
	visual.modulate = Color.WHITE


func _apply_radius() -> void:
	light_node.texture_scale = maxf(0.01, _shown_radius / LIGHT_TEXTURE_RADIUS_PX)
	var circle: CircleShape2D = light_area_shape.shape as CircleShape2D
	circle.radius = maxf(1.0, _shown_radius)


func _build_light_texture() -> void:
	var gradient: Gradient = Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 1))
	gradient.set_color(1, Color(1, 1, 1, 0))
	gradient.add_point(0.7, Color(1, 1, 1, 0.55))
	var tex: GradientTexture2D = GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = int(LIGHT_TEXTURE_RADIUS_PX * 2)
	tex.height = int(LIGHT_TEXTURE_RADIUS_PX * 2)
	light_node.texture = tex


func _build_trail() -> void:
	if trail.process_material != null:
		return
	var particles: ParticleProcessMaterial = ParticleProcessMaterial.new()
	particles.direction = Vector3(0, 1, 0)
	particles.spread = 35.0
	particles.initial_velocity_min = 8.0
	particles.initial_velocity_max = 22.0
	particles.gravity = Vector3.ZERO
	particles.scale_min = 1.5
	particles.scale_max = 3.0
	var fade: Gradient = Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0.9))
	fade.set_color(1, Color(1, 1, 1, 0))
	var ramp: GradientTexture1D = GradientTexture1D.new()
	ramp.gradient = fade
	particles.color_ramp = ramp
	trail.process_material = particles
	trail.local_coords = false


func _on_damaged(_amount: float, _source: StringName) -> void:
	visual.play_hurt()
	_shown_radius *= 0.92


func _on_depleted() -> void:
	state = State.DEAD
	visual.modulate = Color(0.55, 0.62, 0.75, 0.85)
