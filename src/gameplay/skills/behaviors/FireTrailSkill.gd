extends SkillBehavior
## ▲ Огненный след: сегмент пламени на каждые 24pt пути, живёт 1.5–3 с, урон по тикам 0.25 с;
## ур.5 — угасающий хвост взрывается (40 урона).

const SEGMENT_PT: float = 24.0
const TICK_S: float = 0.25

var _segments: Array[Vector2] = []
var _ages: Array[float] = []
var _last: Vector2 = Vector2.INF
var _tick: float = 0.0
var _explode_cd: float = 0.0


func setup(p_host: SkillHost, p_def: SkillDef) -> void:
	super.setup(p_host, p_def)
	z_index = -2
	top_level = true


func _physics_process(delta: float) -> void:
	var pos: Vector2 = host.player.global_position
	if _last == Vector2.INF or pos.distance_to(_last) >= SEGMENT_PT:
		_segments.append(pos)
		_ages.append(0.0)
		_last = pos
	var life: float = float(param("life_s", 1.5))
	_explode_cd = maxf(0.0, _explode_cd - delta)
	for i: int in range(_ages.size() - 1, -1, -1):
		_ages[i] += delta
		if _ages[i] >= life:
			if i == 0 and float(param("tail_explosion", 0)) > 0.0 and _explode_cd <= 0.0:
				_explode(_segments[0])
			_segments.remove_at(i)
			_ages.remove_at(i)
	_tick += delta
	if _tick >= TICK_S:
		_tick = 0.0
		_damage_tick()
	queue_redraw()


func _damage_tick() -> void:
	var half: float = float(param("width_pt", 10)) * 0.5
	var hit: Dictionary = {}
	for point: Vector2 in _segments:
		for enemy: Enemy in host.enemies.enemies_in_radius(point, half):
			if not hit.has(enemy):
				hit[enemy] = true
				enemy.take_damage(float(param("damage", 8)))


func _explode(at: Vector2) -> void:
	_explode_cd = 1.0
	for enemy: Enemy in host.enemies.enemies_in_radius(at, 40.0):
		enemy.take_damage(float(param("tail_explosion", 40)))


func _draw() -> void:
	if _segments.size() < 2:
		return
	var life: float = float(param("life_s", 1.5))
	var width: float = float(param("width_pt", 10))
	for i: int in range(1, _segments.size()):
		var t: float = clampf(_ages[i] / life, 0.0, 1.0)
		var color: Color = Color("#FFF1D0").lerp(Color("#FFB547"), minf(1.0, t * 2.0)).lerp(Color("#C2461A"), maxf(0.0, t * 2.0 - 1.0))
		draw_line(_segments[i - 1], _segments[i], Color(color, 1.0 - t), width * (1.0 - t * 0.5))
