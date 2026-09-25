class_name ParticleFx
extends Node2D
## Частицы боя (task_8 §1, VFX): пул одноразовых CPUParticles2D (без instantiate в бою).
## Смерть врага — пепел + раскалённые искры (число по размеру), Взрыв Света — кольцо угольков цвета скина,
## подбор топлива — искорки. Текстуры src/assets/vfx (белые, цвет — color_ramp). Слушает только факты EventBus.

const POOL_SIZE: int = 16
const EMBER: Texture2D = preload("res://src/assets/vfx/ember.png")
const ASH: Texture2D = preload("res://src/assets/vfx/ash.png")
const SPARK: Texture2D = preload("res://src/assets/vfx/spark.png")
const SIZE_AMOUNT: Dictionary = {&"S": 8, &"M": 14, &"L": 22, &"XL": 32}

var light_color: Color = UITokens.LIGHT_500
var _pool: Array[CPUParticles2D] = []
var _next: int = 0


func _ready() -> void:
	for i: int in POOL_SIZE:
		var p: CPUParticles2D = CPUParticles2D.new()
		p.one_shot = true
		p.emitting = false
		p.explosiveness = 0.9
		p.local_coords = false
		var unshaded: CanvasItemMaterial = CanvasItemMaterial.new()
		unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		unshaded.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		p.material = unshaded
		add_child(p)
		_pool.append(p)
	EventBus.enemy_killed.connect(_on_enemy_killed)
	EventBus.light_burst_triggered.connect(_on_light_burst)
	EventBus.fuel_collected.connect(_on_fuel_collected)


func _emitter() -> CPUParticles2D:
	var p: CPUParticles2D = _pool[_next]
	_next = (_next + 1) % _pool.size()
	return p


func _ramp(from: Color, to: Color) -> Gradient:
	var g: Gradient = Gradient.new()
	g.set_color(0, from)
	g.set_color(1, Color(to, 0.0))
	return g


func burst(pos: Vector2, tex: Texture2D, amount: int, lifetime: float, speed: Vector2, from: Color, to: Color, gravity: float = 0.0, scale_range: Vector2 = Vector2(0.3, 0.6)) -> void:
	var p: CPUParticles2D = _emitter()
	p.global_position = pos
	p.texture = tex
	p.amount = maxi(1, amount)
	p.lifetime = lifetime
	p.spread = 180.0
	p.direction = Vector2.UP
	p.initial_velocity_min = speed.x
	p.initial_velocity_max = speed.y
	p.gravity = Vector2(0, gravity)
	p.damping_min = speed.x * 0.5
	p.damping_max = speed.y * 0.8
	p.scale_amount_min = scale_range.x
	p.scale_amount_max = scale_range.y
	p.angular_velocity_min = -180.0
	p.angular_velocity_max = 180.0
	p.color_ramp = _ramp(from, to)
	p.restart()
	p.emitting = true


func _on_enemy_killed(archetype: StringName, pos: Vector2, is_elite: bool) -> void:
	var def: EnemyDef = ConfigDB.get_enemy(archetype)
	var n: int = int(SIZE_AMOUNT.get(def.size_class if def != null else &"S", 8)) * (2 if is_elite else 1)
	# Пепел оседает вниз, искры разлетаются раскалёнными (HOT → янтарь), без красного.
	burst(pos, ASH, n, 0.9, Vector2(20, 60), Color(0.62, 0.64, 0.7, 0.9), Color(0.3, 0.32, 0.38), 40.0, Vector2(0.25, 0.55))
	burst(pos, EMBER, maxi(4, floori(n * 0.5)), 0.45, Vector2(60, 140), Color("#FFF1D0"), UITokens.LIGHT_700, 0.0, Vector2(0.15, 0.35))


func _on_light_burst(origin: Vector2) -> void:
	burst(origin, EMBER, 40, 0.7, Vector2(220, 380), Color(light_color.lerp(Color.WHITE, 0.4), 1.0), light_color, 0.0, Vector2(0.25, 0.6))


func _on_fuel_collected(_amount: float, pos: Vector2) -> void:
	burst(pos, SPARK, 10, 0.5, Vector2(40, 90), UITokens.SPARK_FLASH, UITokens.LIGHT_500, -20.0, Vector2(0.2, 0.4))
