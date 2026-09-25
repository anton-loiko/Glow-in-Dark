class_name PickupSystem
extends Node2D
## Все предметы на полу забега (task_2 §5): пулы искр (300), топлива и сундуков, магнит, сбор.
## Один цикл на все предметы вместо Area2D на каждую искру. Если искр на полу больше порога,
## новые вливаются в ближайшую (номинал ×5) — Enemy DS §07.

signal spark_collected(value: int, world_pos: Vector2)
signal fuel_collected(world_pos: Vector2)
signal chest_collected(world_pos: Vector2)

var player: Player
var magnet_radius: float = 60.0
var magnet_pulls_fuel: bool = false ## Магнит ур.4 (task_4)
var collect_radius: float = 18.0
var fly_speed: float = 360.0
var fly_speed_base: float = 360.0
var fly_accel: float = 1400.0
var spark_lifetime: float = 20.0
var merge_threshold: int = 60
var merge_value_mul: int = 5
var bounce_range: Vector2 = Vector2(12, 30)
var magnet_delay: float = 0.15
var fuel_light_budget: int = 4

var _sparks: ObjectPool = ObjectPool.new()
var _fuel: ObjectPool = ObjectPool.new()
var _chests: ObjectPool = ObjectPool.new()
var _fuel_lights_on: int = 0
var _light_texture: GradientTexture2D


func setup(p_player: Player, balance: Dictionary) -> void:
	player = p_player
	var cfg: Dictionary = balance.get("pickups", {}) as Dictionary
	magnet_radius = player.stats.magnet_radius
	collect_radius = float(cfg.get("collect_radius_pt", collect_radius))
	fly_speed = float(cfg.get("fly_speed", fly_speed))
	fly_speed_base = fly_speed
	fly_accel = float(cfg.get("fly_accel", fly_accel))
	spark_lifetime = float(cfg.get("spark_lifetime_s", spark_lifetime))
	merge_threshold = int(cfg.get("spark_merge_threshold", merge_threshold))
	merge_value_mul = int(cfg.get("spark_merge_value_mul", merge_value_mul))
	magnet_delay = float(cfg.get("magnet_delay_s", magnet_delay))
	fuel_light_budget = int(cfg.get("fuel_light_budget", fuel_light_budget))
	var bounce: Array = cfg.get("drop_bounce_pt", [12, 30])
	bounce_range = Vector2(float(bounce[0]), float(bounce[1]))
	_light_texture = _make_light_texture()
	_sparks.prewarm(_make_spark, int(cfg.get("spark_pool", 300)), self)
	_fuel.prewarm(_make_fuel, int(cfg.get("fuel_pool", 24)), self)
	_chests.prewarm(_make_chest, 8, self)


func spawn_spark(pos: Vector2, value: int = 1, bounce: bool = true) -> void:
	if _sparks.active_count() >= merge_threshold:
		var target: Pickup = _nearest_idle_spark(pos)
		if target != null:
			target.value += value * merge_value_mul
			target.queue_redraw()
			return
	var spark: Pickup = _sparks.acquire() as Pickup
	if spark == null:
		spark = _sparks.oldest_active() as Pickup
		_sparks.release(spark)
		spark = _sparks.acquire() as Pickup
	var bounce_pt: float = randf_range(bounce_range.x, bounce_range.y) if bounce else 0.0
	spark.reset(value, pos, bounce_pt, magnet_delay)


func spawn_fuel(pos: Vector2) -> void:
	var fuel: Pickup = _fuel.acquire() as Pickup
	if fuel == null:
		return
	fuel.reset(1, pos, 0.0, 0.0)
	if _fuel_lights_on < fuel_light_budget:
		fuel.glow_light.enabled = true
		_fuel_lights_on += 1


func spawn_chest(pos: Vector2) -> void:
	var chest: Pickup = _chests.acquire() as Pickup
	if chest != null:
		chest.reset(1, pos, randf_range(bounce_range.x, bounce_range.y), magnet_delay)


## Все искры в радиусе летят к игроку (Взрыв Света, «Всасывание» Магнита).
func attract_all(radius: float) -> void:
	if player == null:
		return
	for node: Node in _sparks.active_nodes():
		var spark: Pickup = node as Pickup
		if spark.position.distance_to(player.global_position) <= radius:
			spark.attracted = true


func active_sparks() -> int:
	return _sparks.active_count()


func _physics_process(delta: float) -> void:
	if player == null:
		return
	var target: Vector2 = player.global_position
	_update_pool(_sparks, delta, target, true)
	_update_pool(_fuel, delta, target, magnet_pulls_fuel)
	_update_pool(_chests, delta, target, true)


func _update_pool(pool: ObjectPool, delta: float, target: Vector2, magnetic: bool) -> void:
	var nodes: Array[Node] = pool.active_nodes()
	for i: int in range(nodes.size() - 1, -1, -1):
		var p: Pickup = nodes[i] as Pickup
		p.age += delta
		if p.bounce_left > 0.0:
			p.bounce_left = maxf(0.0, p.bounce_left - delta)
			p.position = p.bounce_from.lerp(p.bounce_to, 1.0 - p.bounce_left / 0.15)
			continue
		var dist: float = p.position.distance_to(target)
		if dist <= collect_radius + (8.0 if p.kind == Pickup.Kind.FUEL else 0.0):
			_collect(pool, p)
			continue
		if magnetic and not p.attracted and p.age >= p.magnet_delay and dist <= magnet_radius:
			p.attracted = true
		if p.attracted:
			p.speed = minf(fly_speed * 2.0, p.speed + fly_accel * delta)
			p.position = p.position.move_toward(target, maxf(fly_speed, p.speed) * delta)
		elif p.kind == Pickup.Kind.SPARK:
			var left: float = spark_lifetime - p.age
			if left <= 0.0:
				pool.release(p)
			elif left < 1.0:
				p.modulate.a = left


func _collect(pool: ObjectPool, p: Pickup) -> void:
	var pos: Vector2 = p.position
	match p.kind:
		Pickup.Kind.SPARK:
			spark_collected.emit(p.value, pos)
		Pickup.Kind.FUEL:
			if p.glow_light.enabled:
				p.glow_light.enabled = false
				_fuel_lights_on -= 1
			fuel_collected.emit(pos)
		Pickup.Kind.CHEST:
			chest_collected.emit(pos)
	pool.release(p)


func _nearest_idle_spark(pos: Vector2) -> Pickup:
	var best: Pickup = null
	var best_dist: float = 160.0
	for node: Node in _sparks.active_nodes():
		var spark: Pickup = node as Pickup
		if spark.attracted:
			continue
		var d: float = spark.position.distance_to(pos)
		if d < best_dist:
			best = spark
			best_dist = d
	return best


func _make_spark() -> Node:
	return Pickup.new(Pickup.Kind.SPARK)


func _make_chest() -> Node:
	return Pickup.new(Pickup.Kind.CHEST)


func _make_fuel() -> Node:
	var fuel: Pickup = Pickup.new(Pickup.Kind.FUEL)
	var light: PointLight2D = PointLight2D.new()
	light.texture = _light_texture
	light.color = Pickup.FUEL_COLOR
	light.energy = 0.8
	light.texture_scale = 0.35
	light.enabled = false
	fuel.add_child(light)
	fuel.glow_light = light
	return fuel


func _make_light_texture() -> GradientTexture2D:
	var gradient: Gradient = Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 1))
	gradient.set_color(1, Color(1, 1, 1, 0))
	var tex: GradientTexture2D = GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 128
	tex.height = 128
	return tex
