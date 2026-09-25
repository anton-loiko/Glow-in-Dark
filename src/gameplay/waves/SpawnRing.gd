class_name SpawnRing
extends RefCounted
## Точка спавна (Enemy DS §05): кольцо ~1.2 экрана от игрока, никогда в кадре и в свете,
## не больше 40% спавна с одной стороны (8 секторов), по направлению движения ×1.5, не в стене.

const SECTORS: int = 8
const HISTORY: int = 40

var ring_screens: float = 1.2
var max_side_share: float = 0.4
var movement_bias: float = 1.5
var _history: Array[int] = []


func setup(waves_cfg: Dictionary) -> void:
	ring_screens = float(waves_cfg.get("spawn_ring_screens", ring_screens))
	max_side_share = float(waves_cfg.get("max_side_share", max_side_share))
	movement_bias = float(waves_cfg.get("movement_bias", movement_bias))


## Радиус кольца: за краем экрана и за краем света.
func ring_radius(screen_half: Vector2, zoom: float, light_radius: float) -> float:
	return maxf((screen_half / zoom).length() * ring_screens, light_radius + 80.0)


func pick(center: Vector2, velocity: Vector2, radius: float, rng: RandomNumberGenerator, is_blocked: Callable) -> Vector2:
	var weights: Array[float] = []
	var total: float = 0.0
	for s: int in SECTORS:
		var w: float = 1.0
		if _share(s) >= max_side_share:
			w = 0.0
		elif velocity.length() > 10.0 and absf(angle_difference(velocity.angle(), _sector_angle(s))) < PI / SECTORS * 1.5:
			w *= movement_bias
		weights.append(w)
		total += w
	for attempt: int in 6:
		var sector: int = _weighted(weights, total, rng)
		var angle: float = _sector_angle(sector) + rng.randf_range(-PI / SECTORS, PI / SECTORS)
		var pos: Vector2 = center + Vector2.from_angle(angle) * radius * rng.randf_range(1.0, 1.15)
		if not bool(is_blocked.call(pos)):
			_remember(sector)
			return pos
	return Vector2.INF


func _share(sector: int) -> float:
	if _history.size() < SECTORS:
		return 0.0
	return float(_history.count(sector)) / _history.size()


func _remember(sector: int) -> void:
	_history.append(sector)
	if _history.size() > HISTORY:
		_history.pop_front()


func _sector_angle(sector: int) -> float:
	return TAU * sector / SECTORS


func _weighted(weights: Array[float], total: float, rng: RandomNumberGenerator) -> int:
	if total <= 0.0:
		return rng.randi_range(0, SECTORS - 1)
	var roll: float = rng.randf() * total
	for i: int in weights.size():
		roll -= weights[i]
		if roll <= 0.0:
			return i
	return weights.size() - 1
